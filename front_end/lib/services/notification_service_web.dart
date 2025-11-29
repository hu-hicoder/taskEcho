import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kDebugMode;

/// Web版の通知初期化
Future<void> initWebNotifications() async {
  if (!html.Notification.supported) {
    if (kDebugMode) {
      print('⚠️ Web Notifications are not supported in this browser');
    }
    return;
  }

  final permission = html.Notification.permission;
  if (kDebugMode) {
    print('Web Notification permission: $permission');
  }

  if (permission == 'default') {
    final result = await html.Notification.requestPermission();
    if (kDebugMode) {
      print('Web Notification permission request result: $result');
    }
  } else if (permission == 'denied') {
    if (kDebugMode) {
      print('❌ Web Notifications are blocked. Please enable in browser settings.');
    }
  } else if (permission == 'granted') {
    if (kDebugMode) {
      print('✅ Web Notifications are enabled');
    }
  }
}

/// Web版の通知を表示
Future<void> showWebNotification(String title, String body) async {
  if (!html.Notification.supported) {
    if (kDebugMode) {
      print('⚠️ Web Notifications not supported');
    }
    return;
  }

  final permission = html.Notification.permission;
  if (permission != 'granted') {
    if (kDebugMode) {
      print('⚠️ Web Notification permission not granted: $permission');
    }
    return;
  }

  try {
    final notification = html.Notification(
      title,
      body: body,
      icon: '/icons/Icon-192.png',
      tag: 'taskecho-keyword',
    );

    notification.onClick.listen((event) {
      if (kDebugMode) {
        print('Web notification clicked');
      }
      notification.close();
    });

    Future.delayed(const Duration(seconds: 5), () {
      notification.close();
    });

    if (kDebugMode) {
      print('✅ Web notification shown: $title');
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ Web notification error: $e');
    }
  }
}