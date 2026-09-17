import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_service.g.dart';

@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) {
  return NotificationService();
}

/// The kind of a floating M3 toast, which picks its icon and accent colour.
enum ToastType { info, success, error, extension }

/// One queued toast. Immutable; the service owns the queue and the timers.
class ToastItem {
  final String id;
  final String? title;
  final String message;
  final ToastType type;
  final IconData? icon;
  final Widget? leading;
  final Duration duration;
  final VoidCallback? onAction;
  final String? actionLabel;
  final DateTime createdAt;

  ToastItem({
    required this.id,
    this.title,
    required this.message,
    this.type = ToastType.info,
    this.icon,
    this.leading,
    this.duration = const Duration(milliseconds: 3000),
    this.onAction,
    this.actionLabel,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// Global service managing in-app notifications - Material 3 Expressive
/// floating toasts rendered by [M3ToastOverlay], and platform-level local
/// notifications (download complete/error, etc.).
class NotificationService extends ChangeNotifier {
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

  // ─── In-App Floating Toasts ───────────────────────────────────────────

  final List<ToastItem> _toasts = [];
  List<ToastItem> get toasts => List.unmodifiable(_toasts);

  static const int maxToasts = 4;
  final Map<String, Timer> _dismissTimers = {};

  void showToast({
    String? title,
    required String message,
    ToastType type = ToastType.info,
    IconData? icon,
    Widget? leading,
    Duration duration = const Duration(milliseconds: 3000),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final id = UniqueKey().toString();
    final item = ToastItem(
      id: id,
      title: title,
      message: message,
      type: type,
      icon: icon,
      leading: leading,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );

    if (_toasts.length >= maxToasts) {
      final oldest = _toasts.first;
      dismissToast(oldest.id);
    }

    _toasts.add(item);
    notifyListeners();

    _dismissTimers[id] = Timer(duration, () {
      dismissToast(id);
    });
  }

  void dismissToast(String id) {
    _dismissTimers[id]?.cancel();
    _dismissTimers.remove(id);
    final index = _toasts.indexWhere((t) => t.id == id);
    if (index != -1) {
      _toasts.removeAt(index);
      notifyListeners();
    }
  }

  void pauseTimer(String id) {
    _dismissTimers[id]?.cancel();
  }

  void resumeTimer(
    String id, {
    Duration remaining = const Duration(milliseconds: 1500),
  }) {
    // A hover can end because the card was disposed rather than because the
    // pointer left - the layer stands down whole when the player opens - and
    // by then the toast may already be gone. Re-arming for an id that is no
    // longer in the queue strands a timer in the map that nothing will ever
    // cancel.
    if (!_toasts.any((t) => t.id == id)) return;
    _dismissTimers[id]?.cancel();
    _dismissTimers[id] = Timer(remaining, () {
      dismissToast(id);
    });
  }

  void showSuccess(
    String message, {
    String? title,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 3000),
  }) {
    showToast(
      title: title,
      message: message,
      type: ToastType.success,
      icon: icon ?? Icons.check_circle_rounded,
      duration: duration,
    );
  }

  void showError(
    String message, {
    String? title,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 4000),
  }) {
    showToast(
      title: title,
      message: message,
      type: ToastType.error,
      icon: icon ?? Icons.error_outline_rounded,
      duration: duration,
    );
  }

  void showInfo(
    String message, {
    String? title,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 3000),
  }) {
    showToast(
      title: title,
      message: message,
      type: ToastType.info,
      icon: icon ?? Icons.info_outline_rounded,
      duration: duration,
    );
  }

  void showExtension(
    String message, {
    String? title,
    IconData? icon,
    Widget? leading,
    Duration duration = const Duration(milliseconds: 3200),
  }) {
    showToast(
      title: title,
      message: message,
      type: ToastType.extension,
      icon: icon ?? Icons.extension_rounded,
      leading: leading,
      duration: duration,
    );
  }

  void showSnackBar(
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    showToast(
      message: message,
      type: ToastType.info,
      duration: duration,
      onAction: action?.onPressed,
      actionLabel: action?.label,
    );
  }

  void clearSnackBars() {
    for (final timer in _dismissTimers.values) {
      timer.cancel();
    }
    _dismissTimers.clear();
    _toasts.clear();
    notifyListeners();
    messengerKey.currentState?.clearSnackBars();
  }
}
