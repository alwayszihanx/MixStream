package io.alwayszihan.mixstream.cloudstream

import android.content.Context
import android.util.Log
import com.lagradost.api.setContext as csSetContext
import com.lagradost.cloudstream3.APIHolder
import com.lagradost.cloudstream3.AnimeLoadResponse
import com.lagradost.cloudstream3.Episode
import com.lagradost.cloudstream3.HomePageResponse
import com.lagradost.cloudstream3.LoadResponse
import com.lagradost.cloudstream3.MainAPI
import com.lagradost.cloudstream3.MainPageData
import com.lagradost.cloudstream3.MainPageRequest
import com.lagradost.cloudstream3.MovieLoadResponse
import com.lagradost.cloudstream3.SearchResponse
import com.lagradost.cloudstream3.SubtitleFile
import com.lagradost.cloudstream3.TvSeriesLoadResponse
import com.lagradost.cloudstream3.plugins.BasePlugin
import com.lagradost.cloudstream3.utils.ExtractorLink
import org.json.JSONObject
import dalvik.system.PathClassLoader
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.io.File
import java.lang.ref.WeakReference

/**
 * Native CloudStream bridge. Loads real `.cs3` (DEX) plugins through the
 * bundled CloudStream engine and exposes their `MainAPI`s (search / home /
 * load / loadLinks) as plain Dart maps over a [MethodChannel].
 *
 * This is the Android-only counterpart of [CloudStreamExecutor] on the Dart
 * side; it is what makes CSX-style Kotlin providers work inside MixStream.
 */
class CloudStreamBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val loadedPaths = HashSet<String>()

    init {
        channel.setMethodCallHandler(this)
        try {
            csSetContext(WeakReference<Any>(context))
        } catch (t: Throwable) {
            Log.w(TAG, "CloudStream setContext failed", t)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadPlugin" -> scope.launch { handleLoad(call, result) }
            "unloadPlugin" -> scope.launch { handleUnload(call, result) }
            "unloadAll" -> scope.launch { handleUnloadAll(result) }
            "listProviders" -> scope.launch { handleList(result) }
            "search" -> scope.launch { handleSearch(call, result) }
            "getHome" -> scope.launch { handleHome(call, result) }
            "load" -> scope.launch { handleLoadDetails(call, result) }
            "loadLinks" -> scope.launch { handleLoadLinks(call, result) }
            else -> result.notImplemented()
        }
    }

    private fun providerByName(name: String): MainAPI? =
        APIHolder.allProviders.firstOrNull {
            it.name == name || (it.sourcePlugin ?: "") == name
        }

    private fun err(success: Boolean, message: String?): Map<String, Any?> =
        mapOf("success" to success, "error" to (message ?: ""))

    private suspend fun handleLoad(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        val bytes = call.argument<ByteArray>("bytes")
        if (id.isNullOrEmpty() || bytes == null) {
            result.success(err(false, "missing id or bytes"))
            return
        }
        try {
            val dir = File(context.filesDir, "cloudstream")
            if (!dir.exists()) dir.mkdirs()
            val file = File(dir, "$id.cs3")
            file.writeBytes(bytes)
            // Android refuses to load a dex the app can WRITE to.
            if (file.canWrite()) file.setReadOnly()

            val loader = PathClassLoader(file.absolutePath, context.classLoader)
            val manifestText =
                loader.getResourceAsStream("manifest.json")
                    ?.bufferedReader()
                    ?.use { it.readText() }
                    ?: run {
                        result.success(err(false, "no manifest.json in plugin"))
                        return
                    }
            val manifest = org.json.JSONObject(manifestText)
            val className = manifest.optString("pluginClassName")
            if (className.isEmpty()) {
                result.success(err(false, "manifest missing pluginClassName"))
                return
            }
            val instance =
                loader.loadClass(className).getDeclaredConstructor().newInstance()
                        as BasePlugin
            instance.filename = id
            instance.load()
            loadedPaths.add(file.absolutePath)
            result.success(err(true, null))
        } catch (t: Throwable) {
            Log.e(TAG, "loadPlugin failed", t)
            result.success(err(false, t.message))
        }
    }

    private suspend fun handleUnload(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id") ?: ""
        try {
            val list = APIHolder.allProviders
            list.removeIf { (it.sourcePlugin ?: "") == id }
            loadedPaths.remove(id)
            result.success(err(true, null))
        } catch (t: Throwable) {
            result.success(err(false, t.message))
        }
    }

    private suspend fun handleUnloadAll(result: MethodChannel.Result) {
        try {
            loadedPaths.clear()
            result.success(err(true, null))
        } catch (t: Throwable) {
            result.success(err(false, t.message))
        }
    }

    private suspend fun handleList(result: MethodChannel.Result) {
        try {
            val list =
                APIHolder.allProviders.map { api ->
                    mapOf(
                        "name" to api.name,
                        "sourcePlugin" to (api.sourcePlugin ?: ""),
                        "lang" to (api.lang ?: ""),
                        "hasMainPage" to api.hasMainPage,
                        "mainUrl" to (api.mainUrl ?: ""),
                    )
                }
            result.success(list)
        } catch (t: Throwable) {
            Log.e(TAG, "listProviders failed", t)
            result.success(emptyList<Map<String, Any?>>())
        }
    }

    private suspend fun handleSearch(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("sourceId") ?: ""
        val query = call.argument<String>("query") ?: ""
        try {
            val api = providerByName(name)
            if (api == null) {
                result.success(emptyList<Map<String, Any?>>())
                return
            }
            val items = api.search(query) ?: emptyList<SearchResponse>()
            result.success(items.map { searchResponseToMap(it) })
        } catch (t: Throwable) {
            Log.e(TAG, "search failed", t)
            result.success(emptyList<Map<String, Any?>>())
        }
    }

    private suspend fun handleHome(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("sourceId") ?: ""
        try {
            val api = providerByName(name)
            if (api == null) {
                result.success(emptyList<Map<String, Any?>>())
                return
            }
            val lists = mutableListOf<Map<String, Any?>>()
            for (mpd in api.mainPage) {
                try {
                    val home: HomePageResponse =
                        api.getMainPage(
                            0,
                            MainPageRequest(mpd.name, mpd.data, false),
                        ) ?: continue
                    for (row in home.items) {
                        lists.add(
                            mapOf(
                                "title" to row.name,
                                "items" to row.list.map { searchResponseToMap(it) },
                            ),
                        )
                    }
                } catch (t: Throwable) {
                    Log.w(TAG, "home section failed: ${mpd.name}", t)
                }
            }
            result.success(lists)
        } catch (t: Throwable) {
            Log.e(TAG, "getHome failed", t)
            result.success(emptyList<Map<String, Any?>>())
        }
    }

    private suspend fun handleLoadDetails(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("sourceId") ?: ""
        val url = call.argument<String>("url") ?: ""
        try {
            val api = providerByName(name)
            if (api == null) {
                result.success(emptyMap<String, Any?>())
                return
            }
            val lr = api.load(url) ?: run {
                result.success(emptyMap<String, Any?>())
                return@handleLoadDetails
            }
            result.success(loadResponseToMap(lr))
        } catch (t: Throwable) {
            Log.e(TAG, "load failed", t)
            result.success(emptyMap<String, Any?>())
        }
    }

    private suspend fun handleLoadLinks(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("sourceId") ?: ""
        val url = call.argument<String>("url") ?: ""
        val isCasting = call.argument<Boolean>("isCasting") ?: false
        try {
            val api = providerByName(name)
            if (api == null) {
                result.success(emptyList<Map<String, Any?>>())
                return
            }
            val links = mutableListOf<Map<String, Any?>>()
            val subs = mutableListOf<Map<String, Any?>>()
            api.loadLinks(
                url,
                isCasting,
                { sub -> subs.add(subtitleToMap(sub)) },
                { link -> links.add(extractorLinkToMap(link)) },
            )
            result.success(links.map { it + ("subtitles" to subs) })
        } catch (t: Throwable) {
            Log.e(TAG, "loadLinks failed", t)
            result.success(emptyList<Map<String, Any?>>())
        }
    }

    // ── response → Dart map helpers ──

    private fun searchResponseToMap(sr: SearchResponse): Map<String, Any?> =
        mapOf(
            "name" to sr.name,
            "url" to sr.url,
            "posterUrl" to (sr.posterUrl ?: ""),
            "type" to (sr.type?.name ?: ""),
            "apiName" to (sr.apiName ?: ""),
            "id" to (sr.id ?: 0),
            "quality" to (sr.quality?.name ?: ""),
        )

    private fun loadResponseToMap(lr: LoadResponse): Map<String, Any?> {
        val m =
            mutableMapOf<String, Any?>(
                "name" to lr.name,
                "url" to lr.url,
                "type" to (lr.type?.name ?: ""),
                "posterUrl" to (lr.posterUrl ?: ""),
                "plot" to (lr.plot ?: ""),
                "year" to (lr.year ?: 0),
                "apiName" to (lr.apiName ?: ""),
                "tags" to (lr.tags ?: emptyList<String>()),
                "backgroundPosterUrl" to (lr.backgroundPosterUrl ?: ""),
                "logoUrl" to (lr.logoUrl ?: ""),
            )
        when (lr) {
            is TvSeriesLoadResponse -> {
                m["episodes"] = lr.episodes.map { episodeToMap(it) }
            }
            is AnimeLoadResponse -> {
                m["episodes"] =
                    lr.episodes.flatMap { (status, list) ->
                        list.map { episodeToMap(it, status.name) }
                    }
            }
            else -> m["episodes"] = emptyList<Map<String, Any?>>()
        }
        return m
    }

    private fun episodeToMap(
        ep: Episode,
        dubType: String? = null,
    ): Map<String, Any?> =
        mapOf(
            "name" to (ep.name ?: ""),
            "data" to (ep.data ?: ""),
            "season" to (ep.season ?: 0),
            "episode" to (ep.episode ?: 0),
            "posterUrl" to (ep.posterUrl ?: ""),
            "description" to (ep.description ?: ""),
            "dubType" to (dubType ?: ""),
        )

    private fun extractorLinkToMap(el: ExtractorLink): Map<String, Any?> =
        mapOf(
            "source" to el.source,
            "name" to el.name,
            "url" to el.url,
            "referer" to (el.referer ?: ""),
            "quality" to el.quality,
            "headers" to (el.headers?.toMap() ?: emptyMap<String, String>()),
            "type" to (el.type?.name ?: ""),
        )

    private fun subtitleToMap(sf: SubtitleFile): Map<String, Any?> =
        mapOf(
            "lang" to sf.lang,
            "url" to sf.url,
            "headers" to (sf.headers?.toMap() ?: emptyMap<String, String>()),
        )

    companion object {
        const val CHANNEL = "io.alwayszihan.mixstream/cloudstream"
        private const val TAG = "CloudStreamBridge"
    }
}
