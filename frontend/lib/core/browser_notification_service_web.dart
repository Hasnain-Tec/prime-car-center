// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

class BrowserNotificationService {
  BrowserNotificationService._();

  static final BrowserNotificationService instance =
      BrowserNotificationService._();

  bool get permissionGranted {
    if (!html.Notification.supported) {
      return false;
    }

    return html.Notification.permission == 'granted';
  }

  Future<bool> requestPermission() async {
    if (!html.Notification.supported) {
      return false;
    }

    if (html.Notification.permission == 'granted') {
      return true;
    }

    if (html.Notification.permission == 'denied') {
      return false;
    }

    final permission = await html.Notification.requestPermission();
    return permission == 'granted';
  }

  Future<void> show({
    required String title,
    required String body,
    required String tag,
  }) async {
    if (!permissionGranted) {
      return;
    }

    html.Notification(
      title,
      body: body,
      tag: tag,
    );
  }
}
