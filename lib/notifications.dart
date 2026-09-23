import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// تنبيه مجدول
class ScheduledReminder {
  final int id;
  final String title;
  final String body;
  final DateTime when;
  ScheduledReminder(this.id, this.title, this.body, this.when);
}

class Notifier {
  Notifier._();
  static final Notifier instance = Notifier._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'maintenance_reminders',
      'مواعيد الصيانة',
      channelDescription: 'تنبيهات مواعيد الصيانة والترخيص والتأمين',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _plugin.initialize(settings);
      _ready = true;
    } catch (e) {
      debugPrint('notifications init failed: $e');
    }
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final ok = await android?.requestNotificationsPermission();
      return ok ?? true;
    } catch (e) {
      debugPrint('permission request failed: $e');
      return false;
    }
  }

  /// بيلغي كل التنبيهات القديمة ويجدول الجديدة
  Future<void> reschedule(List<ScheduledReminder> items) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      final now = DateTime.now();
      final future = items.where((e) => e.when.isAfter(now)).toList()
        ..sort((a, b) => a.when.compareTo(b.when));
      // أندرويد بيحدد عدد المنبهات، فبناخد أقرب 60 بس
      for (final r in future.take(60)) {
        await _plugin.zonedSchedule(
          r.id,
          r.title,
          r.body,
          tz.TZDateTime.from(r.when, tz.UTC),
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e) {
      debugPrint('reschedule failed: $e');
    }
  }

  Future<void> showNow(String title, String body) async {
    if (!_ready) return;
    try {
      await _plugin.show(999999, title, body, _details);
    } catch (e) {
      debugPrint('show failed: $e');
    }
  }
}
