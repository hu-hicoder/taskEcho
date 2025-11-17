import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'taskecho_default';
  static const String _channelName = '一般通知';

  static Future<void> init() async {
    if (kIsWeb) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      android: androidInit
    );
    await _plugin.initialize(
      initSettings, 
      onDidReceiveNotificationResponse: (resp) {
        // 通知タップ時の処理を必要なら追加
        debugPrint('Notification tapped: ${resp.payload}');
      }
    );

    // チャネルを作成しておく
    final channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'キーワード検出通知',
      importance: Importance.high,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);

    // ランタイム権限要求（Android 13+）
    try {
      final bool enabled = (await androidPlugin?.areNotificationsEnabled()) ?? false;
      debugPrint('Notifications enabled (before request): $enabled');

      if (!enabled) {
        // permission_handler を使ってランタイムで通知権限を要求
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

        // それでも無効ならアプリ設定画面を開く（ユーザーに手動有効化を促す）
        final bool enabledAfter = (await androidPlugin?.areNotificationsEnabled()) ?? false;
        debugPrint('Notifications enabled (after request): $enabledAfter');
        if (!enabledAfter) {
          debugPrint('通知が有効化されていません。設定画面を開きます。');
          try {
            await openAppSettings(); // permission_handler のヘルパー
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
    if (kIsWeb) return;
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'キーワード検出通知',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000), // 一意な id
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: 'keyword_detected',
    );
    debugPrint('local notification shown');
  }
}