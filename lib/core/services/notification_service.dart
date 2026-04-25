import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper around flutter_local_notifications for the daily FOMO
/// reminder. Singleton so the plugin instance (and init flag) survives
/// hot reload and rebuilds of the Profile tab.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const int _dailyReminderId = 1001;
  static const int _streakWarningId = 1002;
  static const String _channelId = 'formai_daily_reminder';
  static const String _channelName = 'Günlük Hatırlatıcı';
  static const String _channelDesc =
      'FormAI günlük antrenman hatırlatmaları için kullanılır.';
  // Phase 52 · streak-protection ping fires 48 h after the last workout
  // and shares the same Android notification channel because the OS
  // settings UI groups by channel name; users would be confused by a
  // separate "Streak Warning" toggle when the intent is the same
  // ("FormAI is reminding me to train").
  static const String _streakChannelId = 'formai_streak_warning';
  static const String _streakChannelName = 'Seri Koruma';
  static const String _streakChannelDesc =
      'Antrenman serini kaybetmek üzereyken bilgilendirici uyarı.';
  static const String _title = 'Antrenman Vakti! 🔥';
  static const String _body =
      'Günlük meydan okumanı tamamlamak için harika bir zaman. '
      'Serini bozma, hedefine bir adım daha yaklaş!';
  static const String _streakWarningTitle = 'Seriyi Kaybetme! ⚡';
  static const String _streakWarningBody =
      'Hey, seriyi bozmak üzereyiz! 10 dakikalık bir antrenmanla '
      'momentumu koru.';

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    // FormAI's primary audience is in Turkey. `tz.local` would otherwise
    // default to UTC on most devices, which silently shifts scheduled times
    // by the user's actual offset. Istanbul is a safe default — the only
    // thing at risk if the user is elsewhere is a time-of-day mismatch,
    // which showTimePicker already lets them tune.
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    } catch (_) {
      // Location database missing — fall through to UTC.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _plugin.initialize(settings: initSettings);
    _initialized = true;
  }

  /// Request runtime notification permission. On Android 13+ this shows the
  /// POST_NOTIFICATIONS prompt; on iOS it triggers the UN system dialog.
  /// Returns true when the user grants (or when the platform doesn't need
  /// an explicit grant).
  Future<bool> requestPermissions() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    var granted = true;
    if (android != null) {
      granted = (await android.requestNotificationsPermission()) ?? true;
    }
    if (ios != null) {
      granted = (await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          )) ??
          true;
    }
    return granted;
  }

  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await init();
    // Cancel any previously scheduled reminder so edits replace instead of
    // stack up. Otherwise a user adjusting the time would start receiving
    // two pings a day.
    await _plugin.cancel(id: _dailyReminderId);

    final scheduled = _nextInstanceOf(time);
    await _plugin.zonedSchedule(
      id: _dailyReminderId,
      title: _title,
      body: _body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() async {
    await init();
    await _plugin.cancel(id: _dailyReminderId);
  }

  /// Phase 52 · momentum retention. Schedules a single one-shot
  /// notification 48 h from the moment a workout completes; called from
  /// `WorkoutRepository.markDayCompleted` so every successful set
  /// extends the warning further into the future.
  ///
  /// Cancel-and-replace is critical: the user finishing day 5 should
  /// reset the warning, not stack a second one onto day 4's pending
  /// reminder. We use a fixed [_streakWarningId] so the cancel hits the
  /// previous schedule cleanly.
  ///
  /// Permission is *not* requested here — the daily-reminder flow on
  /// the Profile tab already prompts for permission, and we don't want
  /// every workout completion to re-trigger the OS dialog. If the user
  /// hasn't granted permission yet, `zonedSchedule` becomes a no-op on
  /// most platforms (the system silently drops the notification rather
  /// than throwing).
  Future<void> scheduleStreakWarning({
    Duration delay = const Duration(hours: 48),
  }) async {
    await init();
    // Replace any pending warning so the timer always reflects the most
    // recent activity. Without this, two completions in the same day
    // would queue two warnings 48 h after each.
    await _plugin.cancel(id: _streakWarningId);

    final scheduled = tz.TZDateTime.now(tz.local).add(delay);
    await _plugin.zonedSchedule(
      id: _streakWarningId,
      title: _streakWarningTitle,
      body: _streakWarningBody,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _streakChannelId,
          _streakChannelName,
          channelDescription: _streakChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Drops any pending streak warning. Called from `resetProgress` so
  /// a user who wipes their plan doesn't get a stale 48 h ping for a
  /// streak they just discarded.
  Future<void> cancelStreakWarning() async {
    await init();
    await _plugin.cancel(id: _streakWarningId);
  }

  tz.TZDateTime _nextInstanceOf(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
