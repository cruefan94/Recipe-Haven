import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

/// Single oven timer with optional progress and post-finish reminders.
/// Notifications are scheduled with the OS, not an in-app running isolate.
class KitchenTimerSettings {
  const KitchenTimerSettings({
    required this.label,
    required this.durationSeconds,
    this.progressMinutes = 0,
    this.overdueMinutes = 0,
    this.finishAlert = true,
    this.sound = true,
    this.vibrate = true,
  });
  final String label;
  final int durationSeconds;
  final int progressMinutes;
  final int overdueMinutes;
  final bool finishAlert;
  final bool sound;
  final bool vibrate;
  bool get hasAlerts => finishAlert || progressMinutes > 0 || overdueMinutes > 0;

  Map<String, dynamic> toJson() => {
    'label': label, 'durationSeconds': durationSeconds,
    'progressMinutes': progressMinutes, 'overdueMinutes': overdueMinutes,
    'finishAlert': finishAlert, 'sound': sound, 'vibrate': vibrate,
  };

  factory KitchenTimerSettings.fromJson(Map<String, dynamic> data) =>
      KitchenTimerSettings(
        label: data['label'] as String? ?? 'Oven timer',
        durationSeconds: data['durationSeconds'] as int? ?? 600,
        progressMinutes: data['progressMinutes'] as int? ?? 0,
        overdueMinutes: data['overdueMinutes'] as int? ?? 0,
        finishAlert: data['finishAlert'] as bool? ?? true,
        sound: data['sound'] as bool? ?? true,
        vibrate: data['vibrate'] as bool? ?? true,
      );
}

class KitchenTimerEvent {
  const KitchenTimerEvent(this.offsetSeconds, this.title, this.message);
  final int offsetSeconds;
  final String title;
  final String message;
}

class KitchenTimerPlan {
  /// Cap to 60 total notifications (Android OEM/iOS pending alarm limits).
  static List<KitchenTimerEvent> build(KitchenTimerSettings settings) {
    if (settings.durationSeconds < 1 || settings.durationSeconds > 4 * 3600) {
      throw ArgumentError('Timer must be between one second and four hours');
    }
    final events = <KitchenTimerEvent>[];
    if (settings.progressMinutes > 0) {
      final step = settings.progressMinutes * 60;
      for (var t = step; t < settings.durationSeconds && events.length < 48; t += step) {
        final minutesLeft = ((settings.durationSeconds - t) / 60).ceil();
        events.add(KitchenTimerEvent(t, 'Kitchen timer update',
            settings.label + ': ' + minutesLeft.toString() + ' min remaining.'));
      }
    }
    if (settings.finishAlert) {
      events.add(KitchenTimerEvent(settings.durationSeconds,
          'Oven timer finished', settings.label + ' is ready. Check your food.'));
    }
    if (settings.overdueMinutes > 0) {
      final step = settings.overdueMinutes * 60;
      for (var elapsed = step; elapsed <= 60 * 60 && events.length < 60;
          elapsed += step) {
        events.add(KitchenTimerEvent(settings.durationSeconds + elapsed,
            'Kitchen timer still finished',
            settings.label + ' finished ' + (elapsed ~/ 60).toString() +
                ' min ago. Check your oven.'));
      }
    }
    return events;
  }
}

class KitchenTimerSaved {
  const KitchenTimerSaved({
    required this.settings,
    required this.endAt,
    required this.pausedSeconds,
    required this.paused,
    required this.alertStatus,
  });
  final KitchenTimerSettings settings;
  final DateTime endAt;
  final int pausedSeconds;
  final bool paused;
  final String alertStatus;

  int remainingAt(DateTime now) =>
      paused ? pausedSeconds
          : endAt.difference(now).inSeconds.clamp(0, 4 * 3600);

  String serialize() => jsonEncode({
    'settings': settings.toJson(),
    'endAt': endAt.toIso8601String(),
    'pausedSeconds': pausedSeconds,
    'paused': paused,
    'alertStatus': alertStatus,
  });

  static KitchenTimerSaved? parse(String? data) {
    if (data == null || data.isEmpty) return null;
    try {
      final map = jsonDecode(data) as Map<String, dynamic>;
      return KitchenTimerSaved(
        settings: KitchenTimerSettings.fromJson(
            Map<String, dynamic>.from(map['settings'] as Map)),
        endAt: DateTime.parse(map['endAt'] as String),
        pausedSeconds: map['pausedSeconds'] as int? ?? 0,
        paused: map['paused'] as bool? ?? false,
        alertStatus: map['alertStatus'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

class KitchenTimerStorage {
  KitchenTimerStorage({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();
  static const key = 'recipe_haven_kitchen_timer_v1';
  final SharedPreferencesAsync _preferences;
  Future<KitchenTimerSaved?> read() async =>
      KitchenTimerSaved.parse(await _preferences.getString(key));
  Future<void> save(KitchenTimerSaved state) =>
      _preferences.setString(key, state.serialize());
  Future<void> clear() => _preferences.remove(key);
}

class KitchenTimerNotifications {
  KitchenTimerNotifications({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  static const baseId = 67000;
  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  Future<void> initialize() async {
    if (_ready) return;
    timezone_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
    _ready = true;
  }

  Future<void> cancel() async {
    await initialize();
    for (var id = baseId; id < baseId + 60; id++) {
      await _plugin.cancel(id: id);
    }
  }

  /// Returns a user-facing explanation; warning when permissions were denied.
  Future<String> schedule(KitchenTimerSettings config, DateTime startedAt) async {
    await initialize();
    await cancel();
    if (!config.hasAlerts) return 'Timer running without phone notifications.';

    var allowed = true;
    var precise = true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      allowed = await android.requestNotificationsPermission() ?? false;
      if (allowed) {
        try {
          precise = await android.requestExactAlarmsPermission() ?? false;
        } catch (_) {
          precise = false;
        }
      }
    } else {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        allowed = await ios.requestPermissions(
          alert: true, badge: true, sound: true) ?? false;
      }
    }
    if (!allowed) {
      return 'Phone notifications are disabled. The timer will show in the app, '
          'but it cannot alert you when the app is closed.';
    }

    final mode = precise ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final events = KitchenTimerPlan.build(config);
    var scheduled = 0;
    for (final event in events) {
      final scheduledAt = startedAt.add(
          Duration(seconds: event.offsetSeconds));
      if (!scheduledAt.isAfter(DateTime.now())) continue;
      final channel = config.sound
          ? (config.vibrate ? 'rh_timer_sound_vibrate' : 'rh_timer_sound')
          : (config.vibrate ? 'rh_timer_vibrate' : 'rh_timer_silent');
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          'Recipe Haven kitchen timers',
          channelDescription: 'Oven timer alerts and optional reminders',
          importance: Importance.max,
          priority: Priority.high,
          playSound: config.sound,
          enableVibration: config.vibrate,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true, presentSound: config.sound),
      );
      await _plugin.zonedSchedule(
        id: baseId + scheduled,
        title: event.title,
        body: event.message,
        scheduledDate: tz.TZDateTime.from(scheduledAt.toUtc(), tz.UTC),
        notificationDetails: details,
        androidScheduleMode: mode,
      );
      scheduled++;
    }
    if (scheduled == 0) return 'Timer active; no future reminders were selected.';
    if (!precise) {
      return 'Notifications scheduled, but precise alarms are not allowed. '
          'Android may deliver them late. You can enable Alarms & reminders '
          'in Android app settings.';
    }
    return 'Phone alerts scheduled (' + scheduled.toString() +
        '). Check your notification sound and volume.';
  }
}
