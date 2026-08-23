import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show RootIsolateToken, BackgroundIsolateBinaryMessenger;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:crypto/crypto.dart' as crypto_lib;
import 'package:encrypt/encrypt.dart' as encrypt_lib;

/// An isolated, cross-platform QuickJS runtime that executes CloudStream `.cs3`
/// provider scripts.
///
/// It is deliberately SEPARATE from MixStream's own `.mix` engine
/// (`JsEngineService`) so installing/running CloudStream plugins can never
/// interfere with the existing providers. The runtime boots the same JS
/// polyfills MixStream uses (HTTP, DOM, crypto, timers) plus a CloudStream
/// compatibility layer (`Java.type`, `Jsoup`, `okhttp3`, `Settings`,
/// `registerMainAPI`, …) and runs each plugin's `registerMainAPI(new X())`
/// to capture its `MainAPI` instance.
class CloudStreamRuntime {
  CloudStreamRuntime._(this._sendPort, this._ready);

  final SendPort _sendPort;
  final Future<void> _ready;
  int _nextId = 1;
  final Map<int, Completer<dynamic>> _pending = {};

  /// Spawns the background isolate and waits for it to be ready.
  static Future<CloudStreamRuntime> create() async {
    final rx = ReceivePort();
    final ready = Completer<void>();
    final token = RootIsolateToken.instance;
    final isolate = await Isolate.spawn(
      _entry,
      [rx.sendPort, token],
      errorsAreFatal: false,
    );
    late final CloudStreamRuntime rt;
    rx.listen((msg) {
      if (msg is SendPort) {
        rt = CloudStreamRuntime._(msg, ready.future);
        ready.complete();
        return;
      }
      if (msg is! Map) return;
      final id = msg['id'] as int?;
      final completer = rt._pending.remove(id);
      if (completer == null) return;
      if (msg['error'] != null) {
        completer.completeError(msg['error'].toString());
      } else {
        completer.complete(msg['result']);
      }
    });
    await ready.future;
    return rt;
  }

  Future<dynamic> _send(String type, Map<String, dynamic> payload) {
    final id = _nextId++;
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    _sendPort.send({'id': id, 'type': type, ...payload});
    return completer.future;
  }

  /// Loads a plugin's `plugin.js` source into the runtime. Captures the
  /// `MainAPI` instance via `registerMainAPI`.
  Future<void> load(String sourceId, String code) =>
      _send('load', {'sourceId': sourceId, 'code': code});

  /// Invokes a captured MainAPI method and returns the raw JSON result string.
  Future<String> invoke(String method, List<dynamic> args) async {
    final res = await _send('invoke', {
      'method': method,
      'args': jsonEncode(args),
    });
    return res?.toString() ?? '[]';
  }

  Future<void> dispose() => _send('dispose', {});
}

void _entry(List<Object?> args) {
  final mainPort = args[0] as SendPort;
  final token = args[1] as RootIsolateToken?;
  if (token != null) {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  }
  final rx = ReceivePort();
  mainPort.send(rx.sendPort);
  final runner = _CsRunner();
  rx.listen((msg) {
    if (msg is! Map) return;
    runner.handle(msg);
  });
}

const _kPolyfillJs = r"""
   var global = globalThis;
   var console = {
     log:  function(msg) { sendMessage('console_log',   JSON.stringify(msg)); },
     error:function(msg) { sendMessage('console_error', JSON.stringify(msg)); },
     warn: function(msg) { sendMessage('console_log', "WARN: " + JSON.stringify(msg)); }
   };
   function log(msg) { console.log(msg); }

   globalThis.executeCallback = function(id, result, error) {
     sendMessage('js_dispatch_callback', JSON.stringify({
       callbackId: id, result: result, error: error
     }));
   };

   const _dartAsyncRegistry = {};
   globalThis._resolveDartAsync = function(id, result, isError) {
     const cb = _dartAsyncRegistry[id];
     if (cb) {
       delete _dartAsyncRegistry[id];
       if (isError) cb.reject(result);
       else cb.resolve(result);
     }
   };

   function _dartAsyncCall(messageId, params) {
     return new Promise((resolve, reject) => {
       const id = "async_" + Math.random().toString(36).substr(2, 9);
       _dartAsyncRegistry[id] = { resolve, reject };
       sendMessage(messageId, JSON.stringify({ id: id, ...params }));
     });
   }

   function _dartHttp(method, url, headers, body) {
     if (method === 'POST' && typeof headers === 'object' && headers !== null && !body && (headers.body || headers.headers)) {
       body = headers.body; headers = headers.headers;
     }
     return _dartAsyncCall('http_request', { method, url, headers: headers || {}, body });
   }

   function _createHybridResponse(res) {
     if (typeof res !== 'object' || res === null) return res;
     var hybrid = new String(res.body || "");
     Object.defineProperty(hybrid, 'status',     { value: res.status,    enumerable: false });
     Object.defineProperty(hybrid, 'statusCode', { value: res.status,    enumerable: false });
     Object.defineProperty(hybrid, 'body',       { value: res.body,      enumerable: false });
     Object.defineProperty(hybrid, 'headers',    { value: res.headers,   enumerable: false });
     return hybrid;
   }

   globalThis.http_get = function(url, headers, cb) {
     return _dartHttp('GET', url, headers, null).then(function(res) {
       if (cb && typeof cb === 'function') cb(res);
       return res;
     });
   };
   globalThis.http_post = function(url, headers, body, cb) {
     return _dartHttp('POST', url, headers, body).then(function(res) {
       if (cb && typeof cb === 'function') cb(res);
       return res;
     });
   };
   globalThis.http_parallel = function(requests) {
     return _dartAsyncCall('http_parallel', { requests: requests });
   };
   globalThis.getAndUnpack = function(js) {
     return _dartAsyncCall('js_unpack', { js: js });
   };
   globalThis.parse_html = function(html, selector, attr) {
     return _dartAsyncCall('parse_html', { html: html, selector: selector, attr: attr });
   };
   async function _fetch(url) { return await http_get(url, {}); }
""";

const _kTimerJs = r"""
   globalThis.timeout_registry = {};

   function setTimeout(callback, delay) {
     var id = "t_" + Date.now() + "_" + Math.random().toString(36).substr(2, 9);
     globalThis.timeout_registry[id] = function() {
       if (!globalThis.timeout_registry[id]) return;
       delete globalThis.timeout_registry[id];
       try { callback(); } catch (e) { console.error('Timeout error:', e); }
     };
     sendMessage('js_set_timeout', JSON.stringify({ id: id, delay: delay || 0 }));
     return id;
   }
   function clearTimeout(id) { if (id) delete globalThis.timeout_registry[id]; }
   function setInterval(cb, d) {
     var id = "i_" + Date.now() + "_" + Math.random().toString(36).substr(2, 9);
     var wrapper = function() {
       if (!globalThis.timeout_registry[id]) return;
       try { cb(); } catch (e) { console.error('Interval error:', e); }
       if (globalThis.timeout_registry[id]) {
         sendMessage('js_set_timeout', JSON.stringify({ id: id, delay: d || 0 }));
       }
     };
     globalThis.timeout_registry[id] = wrapper;
     sendMessage('js_set_timeout', JSON.stringify({ id: id, delay: d || 0 }));
     return id;
   }
   function clearInterval(id) { clearTimeout(id); }

   function setPreference(key, value) {
     sendMessage('set_storage', JSON.stringify({ key: key, value: value }));
   }
   function getPreference(key) {
     return _dartAsyncCall('get_storage', { key: key });
   }
""";

const _kEntitiesJs = r"""
   class Actor    { constructor(p) { Object.assign(this, p); } }
   class Trailer  { constructor(p) { Object.assign(this, p); } }
   class NextAiring { constructor(p) { Object.assign(this, p); } }
   class MultimediaItem {
     constructor(params) {
       Object.assign(this, {
         type: 'movie', status: 'ongoing', playbackPolicy: 'none',
         isAdult: false, streams: [], syncData: {}, ...params
       });
     }
   }
   class Episode {
     constructor(params) {
       Object.assign(this, {
         season: 0, episode: 0, dubStatus: 'none', playbackPolicy: 'none',
         streams: [], ...params
       });
     }
   }
   class StreamResult {
     constructor(p) {
       this.url = p.url; this.source = p.source || 'Auto'; this.headers = p.headers;
       this.subtitles = p.subtitles; this.drmKid = p.drmKid;
       this.drmKey = p.drmKey; this.licenseUrl = p.licenseUrl;
     }
   }
   globalThis.MultimediaItem = MultimediaItem;
   globalThis.Episode = Episode;
   globalThis.StreamResult = StreamResult;
   globalThis.Actor = Actor;
   globalThis.Trailer = Trailer;
   globalThis.NextAiring = NextAiring;

   globalThis.crypto = {
     decryptAES: function(data, key, iv, options) {
       return _dartAsyncCall('crypto_decrypt_aes', {
         data, key, iv, mode: (options && options.mode) || 'cbc'
       });
     },
     pbkdf2: function(password, salt, iterations, keyLength) {
       return _dartAsyncCall('crypto_pbkdf2', {
         password, salt, iterations: iterations || 10000, keyLength: keyLength || 32
       });
     }
   };

   globalThis.atob = function(str) {
     if (!str) return "";
     try {
       var chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
       var output = ''; str = String(str).replace(/=+$/, '');
       for (var bc=0,bs,buffer,idx=0; buffer=str.charAt(idx++); ~buffer&&(bs=bc%4?bs*64+buffer:buffer, bc++%4)?output+=String.fromCharCode(255&bs>>(-2*bc&6)):0) {
         buffer=chars.indexOf(buffer);
       }
       return output;
     } catch(e) { return ""; }
   };
   globalThis.btoa = function(str) {
     if (!str) return "";
     try {
       var chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
       var output = '';
       for (var block,charCode,bc=0,idx=0,map=chars; str.charAt(idx|0)||(map='=',idx%1); output+=map.charAt(63&block>>8-idx%1*8)) {
         charCode=str.charCodeAt(idx+=3/4);
         if (charCode>0xFF) throw new Error("'btoa' failed");
         block=block<<8|charCode;
       }
       return output;
     } catch(e) { return ""; }
   };
""";

/// CloudStream compatibility layer: the JS API surface providers expect.
const _kCloudStreamJs = r"""
   // ── Settings (per-plugin key/value store) ──
   function _csSettingsHolder() {
     var store = {};
     return {
       get: function(key, def) { return (key in store) ? store[key] : def; },
       put: function(key, val) { store[key] = val; },
       getString: function(key, def) { return (key in store) ? store[key] : (def||''); },
       putString: function(key, val) { store[key] = val; }
     };
   }
   var Settings = _csSettingsHolder();
   var APIHolderMap = {};

   // ── Base classes providers extend (CloudStream provides these) ──
   globalThis.MainAPI = class MainAPI {
     getMainPage() { return []; }
     search(query) { return []; }
     load(url) { return {}; }
     loadLinks(url, isCasting) { return []; }
     getEpisodes(url) { return []; }
     getStatus() { return []; }
     getLatestUpdates() { return []; }
   };
   globalThis.Extractor = class Extractor {
     extract(link) { return null; }
   };
   globalThis.LiveTVAPI = class LiveTVAPI { getChannels() { return []; } };
   globalThis.TrackingAPI = class TrackingAPI { search() { return null; } };
   globalThis.Blog = class Blog { getPosts() { return []; } };

   // ── registerMainAPI: capture the provider instance ──
   globalThis.__csApi = null;
   globalThis.registerMainAPI = function(api) { globalThis.__csApi = api; };
   globalThis.registerExtractor = function() {};
   globalThis.registerBlog = function() {};

   // ── Java.type shim: returns JS proxies for common Java classes ──
   function _csRegex(pattern, flags) {
     var rx = new RegExp(pattern, (flags||'').replace('i','i').replace('m','m').replace('s','s'));
     return {
       pattern: pattern,
       matcher: function(input) {
         var m = input.match(rx);
         return {
           find: function() { return !!m; },
           group: function(i) { return m ? m[i||0] : null; },
           groupCount: function() { return m ? m.length-1 : 0; }
         };
       },
       matches: function(input) { return rx.test(input); }
     };
   }
   function _csMd5(input) { return sendMessage('crypto_md5', String(input)) || ''; }
   function _csSha256(input) { return sendMessage('crypto_sha256', String(input)) || ''; }
   function _csBase64Decode(s) { try { return atob(s); } catch(e){ return ''; } }
   function _csBase64Encode(s) { try { return btoa(s); } catch(e){ return ''; } }

   function _csHtmlDoc(html) {
     return {
       select: function(q) { return globalThis.__csSelect(html, q, true); },
       selectFirst: function(q) { var r = globalThis.__csSelect(html, q, false); return r ? r : null; },
       text: function() { return (sendMessage('html_text', html)||'').toString(); },
       body: function() { return this; }
     };
   }

   function _javaType(name) {
     switch (name) {
       case 'java.util.regex.Pattern':
         return { compile: function(p){ return _csRegex(p,''); },
                  matches: function(p,s){ return _csRegex(p,'').matches(s); } };
       case 'java.security.MessageDigest':
         return {
           getInstance: function(alg) {
             var a = (alg||'').toUpperCase();
             return {
               digest: function(bytes) {
                 var s = (bytes instanceof Uint8Array) ? String.fromCharCode.apply(null, bytes) : String(bytes);
                 return a === 'MD5' ? _csMd5(s) : _csSha256(s);
               },
               digestHex: function(s) { return a === 'MD5' ? _csMd5(s) : _csSha256(s); }
             };
           }
         };
       case 'java.util.Base64':
         return { getDecoder: function(){ return { decode: function(s){ return _csBase64Decode(s); } }; },
                  getEncoder: function(){ return { encode: function(s){ return _csBase64Encode(s); } }; } };
       case 'java.lang.Math':
         return { max: Math.max, min: Math.min, abs: Math.abs, floor: Math.floor, ceil: Math.ceil, round: Math.round, pow: Math.pow, sqrt: Math.sqrt };
       case 'java.lang.StringBuilder':
         return function(){ var s=''; return { append: function(x){ s+=x; return this; }, toString: function(){ return s; } }; };
       case 'java.net.URL':
         return function(u){ return new URL(u); };
       case 'java.lang.System':
         return { currentTimeMillis: function(){ return Date.now(); }, getProperty: function(){ return null; } };
       case 'javax.crypto.Cipher':
         return { getInstance: function(){ return { doFinal: function(){ return ''; } }; } };
       case 'kotlin.text.Regex':
       case 'kotlin.text.Strings':
         return { /* best-effort no-op */ };
       case 'org.jsoup.Jsoup':
       case 'Jsoup':
         return {
           connect: function(url) {
             return _dartAsyncCall('http_request', { method:'GET', url:url, headers:{}, body:null })
               .then(function(res){ return _csHtmlDoc(res ? res.body : ''); });
           },
           parse: function(html) { return _csHtmlDoc(html || ''); }
         };
       case 'okhttp3.OkHttpClient':
         return function(){ return {
           newCall: function(req){ return {
             execute: function() {
               return _dartAsyncCall('http_request', {
                 method: (req._method||'GET'), url: req._url, headers: req._headers||{}, body: req._body
               }).then(function(res){ return {
                 body: function(){ return { string: function(){ return res? res.body : ''; }, bytes: function(){ return res? res.body : ''; } }; },
                 code: function(){ return res? res.status : 0; },
                 headers: function(){ return { toMultimap: function(){ return {}; } }; },
                 request: function(){ return req; }
               }; });
             }
           }; }
         }; };
       case 'okhttp3.Request':
         return function(opts){ return {
           _url: opts.url, _method: opts.method, _headers: opts.headers, _body: opts.body,
           newBuilder: function(){ return this; }, build: function(){ return this; }
         }; };
       case 'okhttp3.RequestBody':
         return { create: function(mediaType, content){ return { _content: content }; } };
       case 'okhttp3.Headers':
         return { of: function(map){ return map||{}; } };
       default:
         // Unknown class — return a permissive no-op proxy so providers that
         // touch exotic Java APIs degrade instead of hard-crashing.
         return function(){ return new Proxy(function(){}, {
           get: function(t, p){ if (p==='toString') return function(){ return ''; }; return function(){ return null; }; },
           apply: function(){ return null; }
         }); };
     }
   }
   globalThis.Java = { type: function(name) { return _javaType(name); } };
   globalThis.Jsoup = _javaType('org.jsoup.Jsoup');

   // ── MainPageBrowser ──
   function _csBrowser(opts) {
     opts = opts || {};
     return {
       get: function(url, headers) {
         return _dartAsyncCall('http_request', { method:'GET', url:url, headers:headers||{}, body:null })
           .then(function(res){ return res ? res.body : ''; });
       },
       getJson: function(url, headers) {
         return _dartAsyncCall('http_request', { method:'GET', url:url, headers:headers||{}, body:null })
           .then(function(res){ return res ? JSON.parse(res.body) : null; });
       },
       post: function(url, headers, body) {
         return _dartAsyncCall('http_request', { method:'POST', url:url, headers:headers||{}, body:body })
           .then(function(res){ return res ? res.body : ''; });
       }
     };
   }
   globalThis.newMainPageBrowser = function(opts) { return _csBrowser(opts); };
   globalThis.newDocBrowser = function(opts) { return _csBrowser(opts); };

   // ── Extractors / tracking / misc (stubbed — filled in later) ──
   globalThis.loadExtractor = function(name) { return null; };
   globalThis.APIHolder = { get: function(name) { return null; }, add: function(){}, all: function(){ return []; } };
   globalThis.newGithubContents = function(opts) { return { getFile: function(){ return _dartAsyncCall('http_request',{method:'GET',url:(opts&&opts.rawUrl)||'',headers:{},body:null}).then(function(r){ return r? r.body : null; }); } }; };
   globalThis.newDocs = function(){ return {}; };
   globalThis.newTrackingAPI = function(){ return { search: function(){ return null; }, getEpisode: function(){ return null; } }; };
   globalThis.newMangaAPI = function(){ return { getDetails: function(){ return null; } }; };
   globalThis.newLiveTVAPI = function(){ return { getChannels: function(){ return []; } }; };
   globalThis.newNSFWAPI = function(){ return { search: function(){ return []; } }; };
   globalThis.newAnimeAPI = function(){ return {}; };
   globalThis.Malsync = { getVideo: function(){ return null; }, getPage: function(){ return null; } };
   globalThis.CheckEnv = { isAndroid: false, isBrowser: false };
   globalThis.isContext = function() { return 'app'; };
   globalThis.languages = function() { return ['en']; };
   globalThis.setProviderLang = function() {};
   globalThis.print = function(m){ console.log(m); };
   globalThis.println = function(m){ console.log(m); };

   // ── Method wrappers Dart calls into ──
   globalThis.__csSearch = function(q) { return globalThis.__csApi ? globalThis.__csApi.search(q) : []; };
   globalThis.__csHome   = function() {
     if (!globalThis.__csApi) return [];
     var mp = globalThis.__csApi.getMainPage();
     var rows = Array.isArray(mp) ? mp : (mp && mp.list ? mp.list : []);
     return rows.map(function(r){ return { title: r.name, items: r.list || [] }; });
   };
   globalThis.__csLoad   = function(url){ return globalThis.__csApi ? globalThis.__csApi.load(url) : {}; };
   globalThis.__csLinks  = function(url){
     if (!globalThis.__csApi) return [];
     var r = globalThis.__csApi.loadLinks(url, false);
     // r is array of links, or array of [name, links] pairs.
     if (Array.isArray(r)) {
       var out = [];
       for (var i = 0; i < r.length; i++) {
         if (Array.isArray(r[i]) && r[i].length > 1 && Array.isArray(r[i][1])) {
           out = out.concat(r[i][1]);
         } else { out.push(r[i]); }
       }
       return out;
     }
     return r;
   };
""";

class _CsRunner {
  late final JavascriptRuntime _rt;
  final _dom = <String, html_dom.Node>{};
  int _domCnt = 0;
  int _cbCnt = 0;
  int _asyncCnt = 0;
  final _inv = <int, String>{};
  final _cbInv = <String, int>{};
  final _prefs = <String, String>{};
  final _pending = <int, Completer<dynamic>>{};

  _CsRunner() {
    _rt = getJavascriptRuntime(
      xhr: false,
      extraArgs: {
        'stackSize': 2 * 1024 * 1024,
        'memoryLimit': 256 * 1024 * 1024,
      },
    );
    _initBridges();
    _eval(_kPolyfillJs, 'polyfill');
    _eval(_kTimerJs, 'timer');
    _eval(_kEntitiesJs, 'entities');
    _eval(_kCloudStreamJs, 'cloudstream');
  }

  void handle(Map msg) {
    final id = msg['id'] as int;
    final type = msg['type'] as String;
    if (type == 'load') {
      _load(id, msg['sourceId'] as String, msg['code'] as String);
    } else if (type == 'invoke') {
      _invoke(id, msg['method'] as String, msg['args'] as String);
    } else if (type == 'dispose') {
      _pending.remove(id)?.complete(null);
    }
  }

  void _eval(String js, String name) {
    final res = _rt.evaluate(js);
    if (res.isError) {
      debugPrint('[cloudstream] bootstrap "$name" error: ${res.stringResult}');
    }
  }

  void _load(int id, String sourceId, String code) {
    try {
      // Most CloudStream plugins are written as ES classes; wrap defensively.
      final wrapped = '''
        (function() {
          try {
            $code
            return { ok: true };
          } catch (e) {
            return { ok: false, error: (e && e.toString ? e.toString() : String(e)) };
          }
        })();
      ''';
      final res = _rt.evaluate(wrapped);
      if (res.isError) {
        _pending[id]?.completeError(res.stringResult);
      } else {
        _pending[id]?.complete(res.stringResult);
      }
    } catch (e) {
      _pending[id]?.completeError(e.toString());
    }
    _pending.remove(id);
  }

  void _invoke(int id, String method, String argsJson) {
    final jsCbId = 'cb_${_cbCnt++}';
    final wrapper = '''
      (function() {
        try {
          var dart_cb = function(res) {
            executeCallback('$jsCbId', res !== undefined ? res : "__dart_void__", null);
          };
          var fn = globalThis['__cs${method[0].toUpperCase()}${method.substring(1)}'];
          if (typeof fn !== 'function') throw "Method $method not found";
          var args = $argsJson;
          args.push(dart_cb);
          var res = fn.apply(null, args);
          if (res && (typeof res.then === 'function' || res instanceof Promise)) {
            res.then(dart_cb).catch(function(err) { executeCallback('$jsCbId', null, err.toString()); });
          } else if (res !== undefined) {
            dart_cb(res);
          }
        } catch(e) {
          executeCallback('$jsCbId', null, e.toString());
        }
      })();
    ''';
    _rt.evaluate(wrapper);
    // Result delivered via js_dispatch_callback -> _pending[id].
    _cbInv[jsCbId] = id;
    _inv[id] = jsCbId;
  }

  void _resolveInvoke(String jsCbId, dynamic result, bool isError) {
    final invId = _cbInv.remove(jsCbId);
    if (invId == null) return;
    _inv.remove(invId);
    final completer = _pending.remove(invId);
    if (completer == null) return;
    if (isError) {
      completer.completeError(result.toString());
    } else {
      completer.complete(result);
    }
  }

  void _initBridges() {
    _rt.onMessage('js_dispatch_callback', (args) {
      final data = _toMap(args);
      final jsCbId = data['callbackId'] as String?;
      if (jsCbId != null) _resolveInvoke(jsCbId, data['result'], data['error'] != null);
      return null;
    });
    _rt.onMessage('console_log', (args) {
      debugPrint('[cs] ${_sanitize(args)}');
      return null;
    });
    _rt.onMessage('console_error', (args) {
      debugPrint('[cs:err] ${_sanitize(args)}');
      return null;
    });
    _rt.onMessage('js_set_timeout', (args) {
      final data = _toMap(args);
      final tid = data['id'] as String?;
      final delay = (data['delay'] as num?)?.toInt() ?? 0;
      if (tid != null) {
        Future.delayed(Duration(milliseconds: delay), () {
          _rt.evaluate(
            "if (globalThis.timeout_registry['$tid']) { globalThis.timeout_registry['$tid'](); }",
          );
        });
      }
      return null;
    });
    _rt.onMessage('base64_decode', (args) => _safe(() => utf8.decode(base64.decode(args.toString()))));
    _rt.onMessage('base64_encode', (args) => _safe(() => base64.encode(utf8.encode(args.toString()))));
    _rt.onMessage('crypto_md5', (args) => _safe(() => crypto_lib.md5.convert(utf8.encode(args.toString())).toString()));
    _rt.onMessage('crypto_sha256', (args) => _safe(() => crypto_lib.sha256.convert(utf8.encode(args.toString())).toString()));
    _rt.onMessage('js_unpack', (args) => args.toString());
    _rt.onMessage('html_text', (args) {
      final html = args.toString();
      try {
        return html_parser.parse(html).body?.text ?? '';
      } catch (_) {
        return '';
      }
    });
    _rt.onMessage('http_request', (args) => _handleHttp(_toMap(args)));
    _rt.onMessage('http_parallel', (args) => _handleHttpParallel(_toMap(args)));
    _rt.onMessage('parse_html', (args) => _handleParseHtml(_toMap(args)));
    _rt.onMessage('set_storage', (args) {
      final m = _toMap(args);
      _prefs[m['key']?.toString() ?? ''] = m['value']?.toString() ?? '';
      return null;
    });
    _rt.onMessage('get_storage', (args) {
      final m = _toMap(args);
      final key = m['key']?.toString() ?? '';
      final cbId = m['id'] as String?;
      if (cbId != null) {
        _rt.evaluate("_resolveDartAsync('$cbId', ${jsonEncode(_prefs[key] ?? '')}, false)");
      }
      return _prefs[key] ?? '';
    });
    _rt.onMessage('crypto_decrypt_aes', (args) => _handleAes(_toMap(args)));
    _rt.onMessage('crypto_pbkdf2', (args) => null);
    _rt.onMessage('solve_captcha', (args) => null);
    _rt.onMessage('dom_parse', (args) => _handleDomParse(_toMap(args)));
    _rt.onMessage('dom_query', (args) => _handleDomQuery(_toMap(args)));
    _rt.onMessage('regex_match_all', (args) => _handleRegex(_toMap(args)));
    _rt.onMessage('json_extract', (args) => args);
    _rt.onMessage('dom_parse_and_extract', (args) => _handleParseHtml(_toMap(args)));
    _rt.onMessage('dom_query_batch', (args) => _handleDomQuery(_toMap(args)));
  }

  dynamic _safe(dynamic Function() fn) {
    try {
      return fn();
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _toMap(dynamic args) {
    if (args is Map) return Map<String, dynamic>.from(args);
    final s = args.toString();
    try {
      return Map<String, dynamic>.from(jsonDecode(s) as Map);
    } catch (_) {
      return const {};
    }
  }

  static String _sanitize(dynamic args) {
    final msg = args.toString();
    return msg.length > 3000 ? '${msg.substring(0, 3000)}... [Truncated]' : msg;
  }

  Future<dynamic> _handleHttp(Map<String, dynamic> m) async {
    final method = (m['method'] as String? ?? 'GET').toUpperCase();
    final url = m['url'] as String? ?? '';
    final headers = (m['headers'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {};
    final body = m['body'];
    try {
      final client = HttpClient();
      final req = method == 'POST'
          ? await client.postUrl(Uri.parse(url))
          : await client.getUrl(Uri.parse(url));
      headers.forEach((k, v) => req.headers.set(k, v));
      if (body != null) {
        final bytes = body is List
            ? Uint8List.fromList(body.cast<int>())
            : utf8.encode(body.toString());
        req.add(bytes);
      }
      final resp = await req.close();
      final respBody = await resp.transform(utf8.decoder).join();
      final respHeaders = <String, String>{};
      resp.headers.forEach((k, v) => respHeaders[k] = v.join(','));
      final result = {
        'status': resp.statusCode,
        'body': respBody,
        'headers': respHeaders,
      };
      client.close();
      return jsonEncode(result);
    } catch (e) {
      return jsonEncode({'status': 0, 'body': '', 'headers': {}, 'error': e.toString()});
    }
  }

  Future<dynamic> _handleHttpParallel(Map<String, dynamic> m) async {
    final requests = (m['requests'] as List?) ?? [];
    final out = [];
    for (final r in requests) {
      final rm = r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
      out.add(await _handleHttp(rm));
    }
    return jsonEncode(out);
  }

  dynamic _handleParseHtml(Map<String, dynamic> m) {
    final html = m['html'] as String? ?? '';
    final selector = m['selector'] as String?;
    final attr = m['attr'] as String?;
    try {
      final doc = html_parser.parse(html);
      final els = selector != null ? doc.querySelectorAll(selector) : [doc];
      final result = els
          .map((e) => attr != null ? (e.attributes[attr] ?? '') : (e.text))
          .toList();
      return jsonEncode(result);
    } catch (_) {
      return jsonEncode([]);
    }
  }

  dynamic _handleRegex(Map<String, dynamic> m) {
    final text = m['text'] as String? ?? '';
    final pattern = m['pattern'] as String? ?? '';
    final group = (m['group'] as int?) ?? 0;
    final caseSensitive = m['caseSensitive'] as bool? ?? true;
    try {
      final rx = RegExp(pattern, caseSensitive: caseSensitive);
      final out = rx.allMatches(text).map((mm) => mm.group(group) ?? '').toList();
      return jsonEncode(out);
    } catch (_) {
      return jsonEncode([]);
    }
  }

  dynamic _handleAes(Map<String, dynamic> m) {
    // Best-effort AES-256-CBC via encrypt package.
    try {
      final data = base64.decode(m['data']?.toString() ?? '');
      final key = _keyFrom(m['key']);
      final iv = encrypt_lib.IV.fromBase64(m['iv']?.toString() ?? '');
      final enc = encrypt_lib.Encrypter(encrypt_lib.AES(key, mode: encrypt_lib.AESMode.cbc));
      final decrypted = enc.decryptBytes(encrypt_lib.Encrypted.fromBase64(base64.encode(data)), iv: iv);
      return base64.encode(decrypted);
    } catch (_) {
      return null;
    }
  }

  encrypt_lib.Key _keyFrom(dynamic k) {
    final s = k?.toString() ?? '';
    final bytes = s.length == 32 ? utf8.encode(s) : base64.decode(s);
    return encrypt_lib.Key(Uint8List.fromList(bytes.take(32).toList()));
  }

  dynamic _handleDomParse(Map<String, dynamic> m) {
    final html = m['html'] as String? ?? '';
    final cbId = m['id'] as String?;
    final id = 'doc_${_domCnt++}';
    _dom[id] = html_parser.parse(html);
    if (cbId != null) {
      _rt.evaluate("_resolveDartAsync('$cbId', ${jsonEncode(id)}, false)");
    }
    return id;
  }

  dynamic _handleDomQuery(Map<String, dynamic> m) {
    final nodeId = m['nodeId'] as String?;
    final query = m['query'] as String?;
    final multi = m['multi'] as bool? ?? false;
    final node = _dom[nodeId];
    if (node == null || query == null) return multi ? jsonEncode([]) : null;
    final results = node is html_dom.Document
        ? node.querySelectorAll(query)
        : (node as html_dom.Element).querySelectorAll(query);
    final serialized = results.map(_serializeElement).toList();
    return multi ? jsonEncode(serialized) : (serialized.isNotEmpty ? jsonEncode(serialized.first) : null);
  }

  Map<String, dynamic> _serializeElement(html_dom.Element e) {
    final attrs = <String, String>{};
    e.attributes.forEach((k, v) => attrs[k.toString()] = v.toString());
    return {
      'nodeId': '${_domCnt++}',
      'tagName': e.localName,
      'textContent': e.text,
      'innerHTML': e.innerHtml,
      'outerHTML': e.outerHtml,
      'attributes': attrs,
    };
  }
}
