import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path_provider/path_provider.dart';
import '../../shared/widgets/app_icon.dart';

part 'notification_service.g.dart';

@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) {
  return NotificationService();
}

/// Global service managing both in-app SnackBar notifications and
/// platform-level local notifications (download complete/error, etc.).
class NotificationService {
  final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  static const int _downloadCompleteId = 1000;
  static const int _downloadErrorId = 2000;

  // ─── Initialization ───────────────────────────────────────────────────

  Future<void> initLocalNotifications() async {
    if (_isInitialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for downloads
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'mixstream_downloads',
        'Downloads',
        description: 'Shows download progress and completion status',
        importance: Importance.high,
      );
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(channel);
    }

    _isInitialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Could route to downloads tab here if needed
  }

  // ─── System Notifications ─────────────────────────────────────────────

  Future<void> showDownloadComplete(String title, String filePath) async {
    await initLocalNotifications();

    final androidDetails = AndroidNotificationDetails(
      'mixstream_downloads',
      'Downloads',
      channelDescription: 'Shows download completion status',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF00E676),
      styleInformation: BigTextStyleInformation(
        'File saved to: ${filePath.split('/').last}',
        contentTitle: title,
      ),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      _downloadCompleteId + title.hashCode,
      'Download Complete',
      '$title is ready to play',
      details,
    );
  }

  Future<void> showDownloadError(String title, String error) async {
    await initLocalNotifications();

    final androidDetails = AndroidNotificationDetails(
      'mixstream_downloads',
      'Downloads',
      channelDescription: 'Shows download errors',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFFF5252),
      styleInformation: BigTextStyleInformation(
        error,
        contentTitle: title,
      ),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      _downloadErrorId + title.hashCode,
      'Download Failed',
      '$title could not be downloaded',
      details,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // ─── In-App SnackBar Notifications ────────────────────────────────────

  void showSnackBar(
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void showError(String message) {
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            AppIcon('error_outline', color: Colors.red.shade700, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFFF0F0),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void showSuccess(String message) {
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            AppIcon('check_circle_outline', color: Colors.green.shade700, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFF0FFF0),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void showInfo(String message) {
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void clearSnackBars() {
    messengerKey.currentState?.clearSnackBars();
  }
}
