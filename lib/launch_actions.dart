import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:quick_actions/quick_actions.dart';

import 'models.dart';
import 'notifications.dart';
import 'screens/forms.dart';
import 'state.dart';
import 'utils.dart';

/// مفتاح الـ Navigator عشان نفتح شاشات من برّه التطبيق (ويدجيت، اختصار، إشعار)
final navigatorKey = GlobalKey<NavigatorState>();

const _widgetAndroidName = 'com.rovana.garage_log.OdometerWidget';
const _quickActions = QuickActions();

Future<BuildContext?> _readyContext() async {
  for (var i = 0; i < 60; i++) {
    final ctx = navigatorKey.currentState?.overlay?.context;
    if (ctx != null && AppData.instance.loaded) return ctx;
    await Future.delayed(const Duration(milliseconds: 100));
  }
  return null;
}

/// يفتح نافذة تحديث العداد لمركبة معيّنة (أو يسأل عن المركبة)
Future<void> openOdometer(int? vehicleId) async {
  final ctx = await _readyContext();
  if (ctx == null || !ctx.mounted) return;
  final app = AppData.instance;
  if (app.vehicles.isEmpty) return;
  Vehicle? v = vehicleId == null ? null : app.vehicleById(vehicleId);
  v ??= await pickVehicle(ctx);
  if (v != null && ctx.mounted) await showOdometerDialog(ctx, v);
}

Future<void> openNewService() async {
  final ctx = await _readyContext();
  if (ctx == null || !ctx.mounted || AppData.instance.vehicles.isEmpty) return;
  await openServiceForm(ctx);
}

Future<void> openNewFuel() async {
  final ctx = await _readyContext();
  if (ctx == null || !ctx.mounted || AppData.instance.vehicles.isEmpty) return;
  await openFuelForm(ctx);
}

void _handleUri(Uri? uri) {
  if (uri == null) return;
  if (uri.host == 'odometer') {
    openOdometer(int.tryParse(uri.queryParameters['id'] ?? ''));
  }
}

void _handleAction(String? type) {
  if (type == null) return;
  if (type == 'odometer') {
    openOdometer(null);
  } else if (type.startsWith('odo_')) {
    openOdometer(int.tryParse(type.substring(4)));
  } else if (type == 'service') {
    openNewService();
  } else if (type == 'fuel') {
    openNewFuel();
  }
}

/// بيتنادي مرة واحدة بعد runApp
Future<void> initLaunchActions() async {
  // الإشعارات
  Notifier.instance.onTap = _handleAction;
  final p = Notifier.instance.launchPayload;
  if (p != null) _handleAction(p);

  // اختصارات أيقونة التطبيق
  try {
    _quickActions.initialize(_handleAction);
  } catch (e) {
    debugPrint('quick actions init failed: $e');
  }

  // الويدجيت
  try {
    _handleUri(await HomeWidget.initiallyLaunchedFromHomeWidget());
    HomeWidget.widgetClicked.listen(_handleUri);
  } catch (e) {
    debugPrint('home widget init failed: $e');
  }
}

/// بيحدّث الويدجيت والاختصارات بآخر بيانات
Future<void> syncHomeScreen(AppData app) async {
  final vs = app.vehicles.take(4).toList();

  try {
    await HomeWidget.saveWidgetData<String>('count', '${vs.length}');
    for (var i = 0; i < vs.length; i++) {
      final v = vs[i];
      final st = app.statusesOf(v.id!);
      String due = '';
      if (st.isNotEmpty && st.first.level != DueLevel.unknown) {
        final s = st.first;
        final dot = switch (s.level) {
          DueLevel.overdue => '🔴',
          DueLevel.soon => '🟠',
          _ => '🟢',
        };
        due = '$dot ${s.plan.name}: ${s.summary.split(' • ').first}';
      }
      await HomeWidget.saveWidgetData<String>('v${i}_id', '${v.id}');
      await HomeWidget.saveWidgetData<String>(
          'v${i}_name', '${v.type == VehicleType.moto ? '🏍️' : '🚗'} ${v.displayName}');
      await HomeWidget.saveWidgetData<String>(
          'v${i}_km', '${fmtInt(app.odometerOf(v))} كم');
      await HomeWidget.saveWidgetData<String>('v${i}_due', due);
    }
    await HomeWidget.updateWidget(qualifiedAndroidName: _widgetAndroidName);
  } catch (e) {
    debugPrint('widget sync failed: $e');
  }

  try {
    await _quickActions.setShortcutItems([
      for (final v in app.vehicles.take(3))
        ShortcutItem(
          type: 'odo_${v.id}',
          localizedTitle: 'عداد ${v.displayName}',
          icon: 'ic_shortcut_speed',
        ),
      if (app.vehicles.isNotEmpty)
        const ShortcutItem(
          type: 'service',
          localizedTitle: 'تسجيل صيانة',
          icon: 'ic_shortcut_build',
        ),
    ]);
  } catch (e) {
    debugPrint('shortcuts failed: $e');
  }
}
