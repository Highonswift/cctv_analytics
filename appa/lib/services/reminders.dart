import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';

/// Payloads carried by reminder taps, so the app opens the right screen.
class ReminderPayload {
  static const checkIn = 'checkin';
  static const medicine = 'medicine';
  static const windDown = 'winddown';
}

/// The three daily reminders, scheduled on the phone itself (no server, no
/// push service, free). The roadmap caps the app at three notifications a
/// day, all of them things he agreed to: these three are the whole budget.
abstract class Reminders {
  Future<void> init({void Function(String payload)? onTap});
  Future<void> schedule(ReminderSettings s);
  Future<void> cancelAll();

  /// Payload of the notification that launched the app, if any.
  Future<String?> launchPayload();
}

/// Builds the three notification texts. Pure, so it is unit-tested.
List<({int id, TimeOfDayMinutes at, String title, String body, String payload})>
reminderPlan(ReminderSettings s) {
  final med = s.medicineName.trim().isEmpty
      ? 'காலை மாத்திரை'
      : s.medicineName.trim();
  return [
    (
      id: 1,
      at: s.morningCheckIn,
      title: 'காலை வணக்கம்',
      body: 'நேற்று இரவு தூக்கம் எப்படி இருந்தது? ஒரு தட்டு போதும்.',
      payload: ReminderPayload.checkIn,
    ),
    (
      id: 2,
      at: s.medicine,
      title: 'மாத்திரை நேரம்',
      body: '$med எடுத்துக்கொள்ளும் நேரம்.',
      payload: ReminderPayload.medicine,
    ),
    (
      id: 3,
      at: s.windDown,
      title: 'ஓய்வு நேரம்',
      body: 'டீ வேண்டாம், டிவியை அணைக்கலாம், போனை படுக்கையறைக்கு வெளியே வைக்கலாம்.',
      payload: ReminderPayload.windDown,
    ),
  ];
}

class DeviceReminders implements Reminders {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'daily_routine',
    'தினசரி நினைவூட்டல்',
    channelDescription: 'காலை தூக்கக் கேள்வி, மாத்திரை, இரவு ஓய்வு',
    importance: Importance.high,
    priority: Priority.high,
    // Nothing disappears on a timer.
    autoCancel: false,
    styleInformation: BigTextStyleInformation(''),
  );

  @override
  Future<void> init({void Function(String payload)? onTap}) async {
    if (_ready || kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) {
        final p = r.payload;
        if (p != null) onTap?.call(p);
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  @override
  Future<String?> launchPayload() async {
    if (kIsWeb) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false)
      return details!.notificationResponse?.payload;
    return null;
  }

  @override
  Future<void> schedule(ReminderSettings s) async {
    if (kIsWeb) return;
    await cancelAll();
    if (!s.enabled) return;
    for (final r in reminderPlan(s)) {
      await _plugin.zonedSchedule(
        id: r.id,
        title: r.title,
        body: r.body,
        payload: r.payload,
        scheduledDate: _next(r.at),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.channelId,
            _channel.channelName,
            channelDescription: _channel.channelDescription,
            importance: _channel.importance,
            priority: _channel.priority,
            autoCancel: false,
            styleInformation: BigTextStyleInformation(r.body),
          ),
        ),
        // Inexact is fine for a routine and needs no exact-alarm permission.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  tz.TZDateTime _next(TimeOfDayMinutes t) {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      t.hour,
      t.minute,
    );
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return at;
  }

  @override
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }
}

class FakeReminders implements Reminders {
  ReminderSettings? scheduled;
  @override
  Future<void> init({void Function(String payload)? onTap}) async {}
  @override
  Future<void> schedule(ReminderSettings s) async => scheduled = s;
  @override
  Future<void> cancelAll() async => scheduled = null;
  @override
  Future<String?> launchPayload() async => null;
}
