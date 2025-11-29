import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'dart:html' as html show Notification;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'taskecho_default';
  static const String _channelName = '一般通知';

  static Future<void> init() async {
    if (kIsWeb) {
      await _initWeb();
      return;
    }
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
    const channel = AndroidNotificationChannel(
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

  static Future<void> _initWeb() async {
    if (!html.Notification.supported) {
      debugPrint('⚠️ Web Notifications are not supported in this browser');
      return;
    }

    final permission = html.Notification.permission;
    debugPrint('Web Notification permission: $permission');

    if (permission == 'default') {
      // 権限を要求
      final result = await html.Notification.requestPermission();
      debugPrint('Web Notification permission request result: $result');
    } else if (permission == 'denied') {
      debugPrint('❌ Web Notifications are blocked. Please enable in browser settings.');
    } else if (permission == 'granted') {
      debugPrint('✅ Web Notifications are enabled');
    }
  }

  static Future<void> showLocal(String title, String body) async {
    debugPrint('showLocal called: $title / $body');

    if (kIsWeb) {
      await _showWebNotification(title, body);
      return;
    }

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

  static Future<void> _showWebNotification(String title, String body) async {
    if (!html.Notification.supported) {
      debugPrint('⚠️ Web Notifications not supported');
      return;
    }

    final permission = html.Notification.permission;
    if (permission != 'granted') {
      debugPrint('⚠️ Web Notification permission not granted: $permission');
      return;
    }

    try {
      final notification = html.Notification(
        title,
        body: body,
        icon: '/icons/Icon-192.png', // アプリアイコンを表示
        tag: 'taskecho-keyword', // 同じタグの通知は上書きされる
      );

      // 通知クリック時の処理
      notification.onClick.listen((event) {
        notification.close();
      });

      // 一定時間後に自動で閉じる
      Future.delayed(const Duration(seconds: 5), () {
        notification.close();
      });
      
      debugPrint('✅ Web notification shown: $title');
    } catch (e) {
      debugPrint('❌ Web notification error: $e');
    }
  }
}