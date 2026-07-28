import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/services/build_config_service.dart';

part 'app_info_provider.g.dart';

class DetailedAppInfo {
  final String appName;
  final String packageName;
  final String versionName;
  final String versionCode;
  final String buildType;
  final String targetSdk;
  final String minSdk;
  final String compileSdk;
  final String buildDate;
  final String kotlinVersion;
  final String flutterVersion;
  final String appSize;
  final String androidVersion;

  const DetailedAppInfo({
    required this.appName,
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.buildType,
    required this.targetSdk,
    required this.minSdk,
    required this.compileSdk,
    required this.buildDate,
    required this.kotlinVersion,
    required this.flutterVersion,
    required this.appSize,
    required this.androidVersion,
  });

  List<_InfoEntry> toEntries() {
    return [
      _InfoEntry('App Name', appName),
      _InfoEntry('Package Name', packageName),
      _InfoEntry('Version Name', versionName),
      _InfoEntry('Version Code', versionCode),
      _InfoEntry('Build Type', buildType),
      _InfoEntry('Target SDK', targetSdk),
      _InfoEntry('Min SDK', minSdk),
      _InfoEntry('Compile SDK', compileSdk),
      _InfoEntry('Build Date', buildDate),
      _InfoEntry('Kotlin Version', kotlinVersion),
      _InfoEntry('Flutter Version', flutterVersion),
      _InfoEntry('App Size', appSize),
      _InfoEntry('Android Version', androidVersion),
    ];
  }
}

class _InfoEntry {
  final String label;
  final String value;
  const _InfoEntry(this.label, this.value);
}

@riverpod
Future<DetailedAppInfo> detailedAppInfo(Ref ref) async {
  final info = await PackageInfo.fromPlatform();
  final buildConfig = await BuildConfigService.getBuildConfig();

  final sizeStr = _formatSize(
    int.tryParse(buildConfig['APP_SIZE'] ?? '0') ?? 0,
  );

  final buildDate = _formatBuildDate(buildConfig['BUILD_TIME'] ?? '');

  return DetailedAppInfo(
    appName: info.appName,
    packageName: info.packageName,
    versionName: info.version,
    versionCode: info.buildNumber,
    buildType: BuildConfigService.getBuildType(),
    targetSdk: buildConfig['TARGET_SDK_VERSION'] ?? '36',
    minSdk: buildConfig['MIN_SDK_VERSION'] ?? '21',
    compileSdk: buildConfig['COMPILE_SDK_VERSION'] ?? '36',
    buildDate: buildDate,
    kotlinVersion: '2.2.20',
    flutterVersion: '3.11.4',
    appSize: sizeStr,
    androidVersion: _sdkToVersion(
      int.tryParse(buildConfig['COMPILE_SDK_VERSION'] ?? '36') ?? 36,
    ),
  );
}

String _formatSize(int bytes) {
  if (bytes <= 0) return 'Unknown';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String _formatBuildDate(String buildTime) {
  final timestamp = int.tryParse(buildTime);
  if (timestamp == null || timestamp == 0) return 'Unknown';
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _sdkToVersion(int sdk) {
  switch (sdk) {
    case 35: return 'Android 15';
    case 34: return 'Android 14';
    case 33: return 'Android 13';
    case 32: return 'Android 12L';
    case 31: return 'Android 12';
    case 30: return 'Android 11';
    case 29: return 'Android 10';
    case 28: return 'Android 9';
    case 27: return 'Android 8.1';
    case 26: return 'Android 8';
    case 25: return 'Android 7.1';
    case 24: return 'Android 7';
    case 23: return 'Android 6';
    case 22: return 'Android 5.1';
    case 21: return 'Android 5';
    case 20: return 'Android 4.4W';
    case 19: return 'Android 4.4';
    default: return 'Android $sdk';
  }
}
