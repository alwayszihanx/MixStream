import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef SystemDownloadCancellation = Future<void> Function(String taskId);

/// Bridges SkyStream downloads to iOS 26's system-managed continued
/// processing task UI. On older iOS versions the native side returns false
/// and background_downloader continues to work normally.
class DownloadContinuedProcessingService {
  static const MethodChannel _channel = MethodChannel(
    'dev.akash.skystream/download_continued_processing',
  );

  final SystemDownloadCancellation onSystemCancel;
  bool _handlerInstalled = false;

  DownloadContinuedProcessingService({required this.onSystemCancel}) {
    if (_isAvailable) {
      _channel.setMethodCallHandler(_handleNativeCall);
      _handlerInstalled = true;
    }
  }

  bool get _isAvailable => !kIsWeb && Platform.isIOS;

  Future<void> start({
    required String taskId,
    required String displayName,
    double progress = 0.0,
    int totalBytes = -1,
  }) async {
    await _invoke('start', <String, Object>{
      'taskId': taskId,
      'displayName': displayName,
      'progress': progress.clamp(0.0, 1.0).toDouble(),
      'totalBytes': totalBytes,
    });
  }

  Future<void> update({
    required String taskId,
    required double progress,
    required int totalBytes,
  }) async {
    await _invoke('update', <String, Object>{
      'taskId': taskId,
      'progress': progress.clamp(0.0, 1.0).toDouble(),
      'totalBytes': totalBytes,
    });
  }

  Future<void> finish({
    required String taskId,
    required bool success,
    required String status,
  }) async {
    await _invoke('finish', <String, Object>{
      'taskId': taskId,
      'success': success,
      'status': status,
    });
  }

  Future<void> stop({required String taskId}) async {
    await _invoke('stop', <String, Object>{'taskId': taskId});
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method != 'cancel') return false;

    final arguments = call.arguments;
    if (arguments is! Map) return false;

    final taskId = arguments['taskId'];
    if (taskId is! String || taskId.isEmpty) return false;

    await onSystemCancel(taskId);
    return true;
  }

  Future<void> _invoke(String method, Map<String, Object> arguments) async {
    if (!_isAvailable) return;

    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // The current build does not include the iOS 26 bridge.
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[DownloadContinuedProcessing] $method failed: '
          '${error.code} ${error.message}',
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[DownloadContinuedProcessing] $method failed: $error');
      }
    }
  }

  Future<void> dispose() async {
    if (_handlerInstalled) {
      _channel.setMethodCallHandler(null);
      _handlerInstalled = false;
    }
  }
}
