import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BuildConfigService {
  static const _channel = MethodChannel('io.alwayszihan.mixstream/build_config');

  static Future<Map<String, String>> getBuildConfig() async {
    if (!Platform.isAndroid) {
      return {
        'BUILD_TYPE': kDebugMode ? 'debug' : kReleaseMode ? 'release' : 'profile',
        'APPLICATION_ID': 'io.alwayszihan.mixstream',
        'VERSION_CODE': '',
        'VERSION_NAME': '',
        'COMPILE_SDK_VERSION': '',
        'MIN_SDK_VERSION': '',
        'TARGET_SDK_VERSION': '',
      };
    }
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getAllBuildConfig',
      );
      if (result == null) return {};
      return result.map((key, value) => MapEntry(key.toString(), value.toString()));
    } catch (e) {
      return {};
    }
  }

  static Future<int> getAppSize() async {
    if (!Platform.isAndroid) return 0;
    try {
      final result = await _channel.invokeMethod<String>('getAppSize');
      return int.tryParse(result ?? '0') ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static String getBuildType() {
    if (kDebugMode) return 'Debug';
    if (kProfileMode) return 'Profile';
    return 'Release';
  }
}
