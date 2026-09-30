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
  final String? payload;
  ScheduledReminder(this.id, this.title, this.body, this.when, {this.payload});
}

class Notifier {
  Notifier._();
  static final Notifier instance = Notifier._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// بيتنادي لما المستخدم يدوس على إشعار والتطبيق مفتوح
  void Function(String? payload)? onTap;

  /// لو التطبيق اتفتح من إشعار
  String? launchPayload;

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
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload),
      );
      _ready = true;
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        launchPayload = details!.notificationResponse?.payload;
      }
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
  Future<void> reschedule(List<ScheduledReminder> items,
      {ScheduledReminder? weekly}) async {
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
          payload: r.payload,
        );
      }
      // تذكير أسبوعي بتحديث العداد
      if (weekly != null) {
        await _plugin.zonedSchedule(
          weekly.id,
          weekly.title,
          weekly.body,
          tz.TZDateTime.from(weekly.when, tz.UTC),
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: weekly.payload,
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
