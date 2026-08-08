import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class JobNotificationService {
  JobNotificationService._();

  static final JobNotificationService instance = JobNotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _notificationsAllowed = true;
  bool _exactAlarmsAllowed = true;

  // Prevents the same "ending soon" notification from repeatedly
  // appearing while the app remains open.
  final Set<int> _shownSoonThisSession = <int>{};

  static const String _channelId = 'pcc_job_reminders';
  static const String _channelName = 'Job Reminders';
  static const String _channelDescription =
      'Reminders for workshop jobs approaching or reaching their expected end time.';

  bool get _isAndroid {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  int _endingSoonId(int jobId) {
    return (jobId * 10) + 1;
  }

  int _timeOverId(int jobId) {
    return (jobId * 10) + 2;
  }

  Future<void> initialize() async {
    if (_initialized || !_isAndroid) {
      return;
    }

    // Load timezone database.
    tz.initializeTimeZones();

    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();

      tz.setLocalLocation(
        tz.getLocation(timezoneInfo.identifier),
      );
    } catch (_) {
      // Safe fallback. Scheduling below uses the absolute UTC instant,
      // so notifications still have a valid time if timezone lookup fails.
      tz.setLocalLocation(tz.UTC);
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      settings: initializationSettings,
    );

    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      try {
        final permission = await android.requestNotificationsPermission();

        if (permission != null) {
          _notificationsAllowed = permission;
        }
      } catch (_) {
        // Older Android versions don't require this permission.
        _notificationsAllowed = true;
      }

      try {
        final exactPermission = await android.requestExactAlarmsPermission();

        if (exactPermission != null) {
          _exactAlarmsAllowed = exactPermission;
        }
      } catch (_) {
        // If exact alarms are unavailable, use an inexact reminder.
        _exactAlarmsAllowed = false;
      }
    }

    _initialized = true;
  }

  NotificationDetails get _notificationDetails {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  AndroidScheduleMode get _scheduleMode {
    if (_exactAlarmsAllowed) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> scheduleJobReminders({
    required int jobId,
    required String invoiceNumber,
    required String plateNumber,
    required DateTime? endTime,
    required String status,
  }) async {
    if (!_isAndroid) {
      return;
    }

    await initialize();

    // Always remove old reminders first. This is important if
    // the expected end time or job status has changed.
    await cancelJobReminders(jobId);

    final normalizedStatus = status.trim().toLowerCase();

    // Completed or cancelled jobs must never receive reminders.
    if (normalizedStatus == 'completed' || normalizedStatus == 'cancelled') {
      return;
    }

    if (endTime == null) {
      return;
    }

    if (!_notificationsAllowed) {
      return;
    }

    final now = DateTime.now();
    final expectedEnd = endTime.toLocal();

    // Do not schedule new reminders for an already-expired job.
    if (!expectedEnd.isAfter(now)) {
      return;
    }

    final endingSoonTime = expectedEnd.subtract(
      const Duration(minutes: 30),
    );

    final payload = 'job:$jobId';

    // ---------------------------------------------------------
    // 30 MINUTES BEFORE END TIME
    // ---------------------------------------------------------

    if (endingSoonTime.isAfter(now)) {
      await _schedule(
        id: _endingSoonId(jobId),
        when: endingSoonTime,
        title: 'Job Ending Soon',
        body:
            '$invoiceNumber • $plateNumber\n30 minutes remaining before expected end time.',
        payload: payload,
      );
    } else {
      // The job was loaded when less than 30 minutes remain.
      // Show one immediate warning during this app session.
      if (_shownSoonThisSession.add(jobId)) {
        final difference = expectedEnd.difference(now);

        var minutes = difference.inMinutes;

        if (minutes < 1) {
          minutes = 1;
        }

        await _notifications.show(
          id: _endingSoonId(jobId),
          title: 'Job Ending Soon',
          body:
              '$invoiceNumber • $plateNumber\nAbout $minutes minute${minutes == 1 ? '' : 's'} remaining.',
          notificationDetails: _notificationDetails,
          payload: payload,
        );
      }
    }

    // ---------------------------------------------------------
    // EXACT EXPECTED END TIME
    // ---------------------------------------------------------

    await _schedule(
      id: _timeOverId(jobId),
      when: expectedEnd,
      title: 'Job Time Is Over',
      body:
          '$invoiceNumber • $plateNumber\nThe expected job end time has been reached.',
      payload: payload,
    );
  }

  Future<void> _schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isAndroid || !_notificationsAllowed) {
      return;
    }

    final scheduledDate = tz.TZDateTime.from(
      when.toUtc(),
      tz.local,
    );

    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: _notificationDetails,
      androidScheduleMode: _scheduleMode,
      payload: payload,
    );
  }

  Future<void> cancelJobReminders(int jobId) async {
    if (!_isAndroid) {
      return;
    }

    if (!_initialized) {
      await initialize();
    }

    await _notifications.cancel(
      id: _endingSoonId(jobId),
    );

    await _notifications.cancel(
      id: _timeOverId(jobId),
    );

    _shownSoonThisSession.remove(jobId);
  }

  Future<void> cancelAllJobReminders() async {
    if (!_isAndroid) {
      return;
    }

    if (!_initialized) {
      await initialize();
    }

    await _notifications.cancelAll();

    _shownSoonThisSession.clear();
  }

  Future<void> showTestNotification() async {
    if (!_isAndroid) {
      return;
    }

    await initialize();

    if (!_notificationsAllowed) {
      return;
    }

    await _notifications.show(
      id: 999999,
      title: 'Prime Car Center',
      body: 'Job reminder notifications are working correctly.',
      notificationDetails: _notificationDetails,
      payload: 'test',
    );
  }
}
