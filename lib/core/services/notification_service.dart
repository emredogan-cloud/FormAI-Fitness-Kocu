import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../utils/app_logger.dart';

/// Phase 58 · the three states the smart-reminder scheduler picks
/// between when stamping the daily ping. The notifier upstream
/// (`SmartReminderListener`) computes which condition applies from
/// `lastWorkoutAt` + `consumedMacrosProvider.calories` and feeds it
/// here.
///
/// Tokens are intentionally English so they appear stable in
/// analytics breadcrumbs even if the UI strings ever localise.
enum SmartReminderCondition {
  /// User hasn't worked out today.
  noWorkout,

  /// Workout done, no nutrition logged yet.
  workoutNoFood,

  /// Both workout and nutrition logged.
  bothDone,
}

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
  // Phase 58 · smart-reminder variant pools, keyed by the
  // [SmartReminderCondition] the user is in at scheduling time.
  //
  //   • noWorkout       — user hasn't trained today; nudge them in.
  //   • workoutNoFood   — workout done, no nutrition logged; pivot
  //                       the message to recovery / fuel.
  //   • bothDone        — perfect day; switch to celebration +
  //                       hydration / rest tone.
  //
  // Each pool has at least 2 variants so two consecutive days don't
  // surface identical copy. Picking is uniform-random at schedule
  // time. The exact title for `noWorkout` matches the PM's spec
  // verbatim ("Antrenman Vakti! 💪" / "Hedeflerinden uzaklaşma…");
  // the rest of each pool offers tonal variation so the user doesn't
  // see the same string every day.
  static const List<({String title, String body})> _noWorkoutVariants = [
    (
      title: 'Antrenman Vakti! 💪',
      body:
          'Hedeflerinden uzaklaşma. Günün egzersizi seni bekliyor, hemen başla!',
    ),
    (
      title: 'Bugünün antrenmanı seni bekliyor! 💪',
      body: 'Sadece 10–15 dakika. Seriyi koruyalım, bir adım daha at.',
    ),
    (
      title: 'Bir hedefin var, unutma 🎯',
      body: 'Bugün antrenmanı geçersen yarın iki gün geride kalırsın.',
    ),
  ];
  static const List<({String title, String body})> _workoutNoFoodVariants = [
    (
      title: 'Yakıt Gerekli! 🥩',
      body:
          'Harika bir antrenman çıkardın. Şimdi toparlanma vakti, bugünün öğünlerini kaydet!',
    ),
    (
      title: 'Toparlanma zamanı 🥗',
      body: 'Antrenmanı bitirdin — şimdi öğünlerini ekle ve bugünü tamamla.',
    ),
  ];
  static const List<({String title, String body})> _bothDoneVariants = [
    (
      title: 'Günü fethettin! 🏆',
      body: 'Bugün disiplinden kopmadın. Şimdi bol su iç ve dinlenmeye geç.',
    ),
    (
      title: 'Mükemmel bir gün 💧',
      body: 'Antrenman ✅ Beslenme ✅ — kalan tek şey su ve kaliteli uyku.',
    ),
    (
      title: 'Devam et! ⚡',
      body: 'Bugün hedeflerini tutturdun. Yarın da aynı disiplinle devam.',
    ),
  ];

  // Streak warning fires after 48 h of inactivity; intentionally
  // separate from the smart-reminder pools because by definition
  // the user *hasn't* worked out, so it always uses urgency framing.
  static const List<({String title, String body})> _streakVariants = [
    (
      title: 'Seriyi kaybetmek üzeresin! ⚡',
      body: '48 saat oldu. 10 dakikalık bir oturum momentumu kurtarır.',
    ),
    (
      title: 'Geri dönüş zamanı 🔁',
      body: 'Serini bozmadan bugün bir set yap; yarın daha da kolaylaşır.',
    ),
  ];

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
  ///
  /// Exact-alarm decision · the manifest no longer declares
  /// `USE_EXACT_ALARM`/`SCHEDULE_EXACT_ALARM` (Play policy scrutiny for
  /// non-alarm apps) and every schedule below runs
  /// `inexactAllowWhileIdle`, so we don't request the exact-alarm
  /// permission here either. A fitness reminder arriving within the
  /// OS's inexact window (typically ≤ ~15 min) is acceptable; throwing
  /// `exact_alarms_not_permitted` on Android 12+ was not.
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

  /// Phase 58 · smart-reminder scheduler. Evaluates the user's daily
  /// state right now, picks the matching variant pool (Condition A /
  /// B / C per the spec), and schedules the daily ping with that
  /// body. Repeats daily at [time]; consumers re-call this whenever
  /// the user's progress changes (workout completes, meal logged) so
  /// the next-fire body reflects current state.
  ///
  /// "Smart" here is best-effort — `flutter_local_notifications`
  /// can't run a Dart callback at fire time without a heavyweight
  /// background-isolate plugin, so we instead re-schedule on every
  /// state change and let the most recent re-schedule win. In
  /// practice the user's state during their app session matches
  /// their state at the scheduled fire time closely enough that the
  /// notification body reads correctly.
  Future<void> scheduleDailyReminder(
    TimeOfDay time, {
    SmartReminderCondition condition = SmartReminderCondition.noWorkout,
  }) async {
    await init();
    // Cancel any previously scheduled reminder so edits replace instead of
    // stack up. Otherwise a user adjusting the time would start receiving
    // two pings a day.
    await _plugin.cancel(id: _dailyReminderId);

    final scheduled = _nextInstanceOf(time);
    final variant = _pickVariant(_variantsFor(condition));
    // Exact-alarm decision · `inexactAllowWhileIdle` (was
    // `exactAllowWhileIdle`). The manifest no longer declares the
    // exact-alarm permissions, and `exactAllowWhileIdle` without them
    // THROWS `exact_alarms_not_permitted` on Android 12+ — silently
    // killing every reminder. Inexact is Play-policy-safe and fires
    // within the OS batching window (typically ≤ ~15 min), which is
    // fine for a fitness nudge. try/catch belt-and-braces so a
    // platform quirk can never take the caller down with it.
    try {
      await _plugin.zonedSchedule(
        id: _dailyReminderId,
        title: variant.title,
        body: variant.body,
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
    } catch (e, st) {
      AppLogger.error(
        'scheduleDailyReminder failed',
        e,
        stackTrace: st,
        category: 'notifications',
      );
      return;
    }
    AppLogger.info(
      'Scheduled daily reminder',
      category: 'notifications',
      data: {
        'at': scheduled.toIso8601String(),
        'condition': condition.name,
        'title': variant.title,
      },
    );
  }

  List<({String title, String body})> _variantsFor(
      SmartReminderCondition condition) {
    switch (condition) {
      case SmartReminderCondition.noWorkout:
        return _noWorkoutVariants;
      case SmartReminderCondition.workoutNoFood:
        return _workoutNoFoodVariants;
      case SmartReminderCondition.bothDone:
        return _bothDoneVariants;
    }
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
    final variant = _pickVariant(_streakVariants);
    try {
      await _plugin.zonedSchedule(
        id: _streakWarningId,
        title: variant.title,
        body: variant.body,
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
        // Exact-alarm decision · inexact like the daily reminder (see
        // `scheduleDailyReminder`) — a 48 h streak warning arriving a
        // few minutes late is harmless; throwing on Android 12+ (no
        // exact-alarm permission in the manifest) killed it entirely.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e, st) {
      AppLogger.error(
        'scheduleStreakWarning failed',
        e,
        stackTrace: st,
        category: 'notifications',
      );
    }
  }

  /// Phase 57 · cheap pseudo-random variant picker. `Random()` (not
  /// `Random.secure`) is fine here — predictability isn't a concern,
  /// we just want different copy on each scheduling call.
  ({String title, String body}) _pickVariant(
    List<({String title, String body})> pool,
  ) {
    return pool[math.Random().nextInt(pool.length)];
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
