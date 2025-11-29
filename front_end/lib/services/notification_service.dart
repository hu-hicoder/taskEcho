import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:permission_handler/permission_handler.dart';

// ★ 条件付きインポート: Webの場合のみ dart:html をインポート
import 'notification_service_stub.dart'
    if (dart.library.html) 'notification_service_web.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'taskecho_default';
  static const String _channelName = '一般通知';

  static Future<void> init() async {
    if (kIsWeb) {
      await initWebNotifications();
      return;
    }
    
    // Android版の初期化（既存のコード）
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      android: androidInit
    );
    await _plugin.initialize(
      initSettings, 
      onDidReceiveNotificationResponse: (resp) {
        debugPrint('Notification tapped: ${resp.payload}');
      }
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'キーワード検出通知',
      importance: Importance.high,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);

    try {
      final bool enabled = (await androidPlugin?.areNotificationsEnabled()) ?? false;
      debugPrint('Notifications enabled (before request): $enabled');

      if (!enabled) {
        try {
          final status = await Permission.notification.status;
          debugPrint('Permission.notification status: $status');
          if (!status.isGranted) {
            final result = await Permission.notification.request();
            debugPrint('Permission.notification request result: $result');
          }
        } catch (e) {
          debugPrint('permission_handler notification request failed: $e');
        }

        final bool enabledAfter = (await androidPlugin?.areNotificationsEnabled()) ?? false;
        debugPrint('Notifications enabled (after request): $enabledAfter');
        if (!enabledAfter) {
          debugPrint('通知が有効化されていません。設定画面を開きます。');
          try {
            await openAppSettings();
          } catch (e) {
            debugPrint('openAppSettings failed: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Notification permission check/request failed: $e');
    }

    debugPrint('NotificationService initialized');
  }

  static Future<void> showLocal(String title, String body) async {
    debugPrint('showLocal called: $title / $body');

    if (kIsWeb) {
      await showWebNotification(title, body);
      return;
    }

    // Android版の通知
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'キーワード検出通知',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: 'keyword_detected',
    );
    debugPrint('local notification shown');
  }
}