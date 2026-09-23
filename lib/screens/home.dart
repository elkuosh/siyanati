import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../utils.dart';
import '../widgets.dart';
import 'forms.dart';
import 'records.dart';
import 'reports.dart';
import 'settings.dart';
import 'tiles.dart';
import 'vehicle_detail.dart';
import 'vehicles.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          DashboardScreen(),
          VehiclesScreen(),
          RecordsScreen(),
          ReportsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'الرئيسية'),
          NavigationDestination(
              icon: Icon(Icons.garage_outlined),
              selectedIcon: Icon(Icons.garage),
              label: 'مركباتي'),
          NavigationDestination(
              icon: Icon(Icons.history),
              selectedIcon: Icon(Icons.history_toggle_off),
              label: 'السجل'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'التقارير'),
        ],
      ),
    );
  }
}

/// قائمة الإضافة السريعة
Future<void> showQuickAdd(BuildContext context, {int? vehicleId}) async {
  final app = AppData.instance;
  if (app.vehicles.isEmpty) {
    openVehicleForm(context);
    return;
  }
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.build),
            title: const Text('صيانة'),
            subtitle: const Text('زيت، فلاتر، فرامل، تصليح...'),
            onTap: () {
              Navigator.pop(c);
              openServiceForm(context, vehicleId: vehicleId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_gas_station),
            title: const Text('تفويلة بنزين'),
            onTap: () {
              Navigator.pop(c);
              openFuelForm(context, vehicleId: vehicleId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('مصروف تاني'),
            subtitle: const Text('ترخيص، تأمين، مخالفة، غسيل...'),
            onTap: () {
              Navigator.pop(c);
              openExpenseForm(context, vehicleId: vehicleId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('تحديث العداد'),
            onTap: () async {
              Navigator.pop(c);
              final v = vehicleId != null
                  ? app.vehicleById(vehicleId)
                  : await _pickVehicle(context);
              if (v != null && context.mounted) showOdometerDialog(context, v);
            },
          ),
        ],
      ),
    ),
  );
}

Future<Vehicle?> _pickVehicle(BuildContext context) async {
  final app = AppData.instance;
  if (app.vehicles.length == 1) return app.vehicles.first;
  return showDialog<Vehicle>(
    context: context,
    builder: (c) => SimpleDialog(
      title: const Text('اختار المركبة'),
      children: [
        for (final v in app.vehicles)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, v),
            child: Row(children: [
              Icon(vehicleTypeIcon(v.type)),
              const SizedBox(width: 10),
              Text(v.displayName),
            ]),
          ),
      ],
    ),
  );
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppData.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('صيانتي'),
        actions: [
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'quickAdd',
        onPressed: () => showQuickAdd(context),
        icon: const Icon(Icons.add),
        label: const Text('تسجيل'),
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          if (app.vehicles.isEmpty) {
            return EmptyState(
              icon: Icons.two_wheeler,
              text: 'أهلاً بيك في صيانتي 👋\n'
                  'ضيف عربيتك أو الموتوسيكل، والتطبيق هيفكرك بمواعيد الزيت والفلاتر والترخيص ويحسبلك المصاريف.',
              actionLabel: 'إضافة أول مركبة',
              onAction: () => openVehicleForm(context),
            );
          }
          return _DashboardBody();
        },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = AppData.instance;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final yearStart = DateTime(now.year);
    final statuses = app.allStatuses();
    final soonDays = app.settings.soonDays;
    final attentionPlans = statuses
        .where((s) => s.level == DueLevel.overdue || s.level == DueLevel.soon)
        .toList();
    final attentionDocs = app
        .docDues()
        .where((d) => d.level(soonDays) != DueLevel.ok)
        .toList();
    final overdue = attentionPlans.where((s) => s.level == DueLevel.overdue).length +
        attentionDocs.where((d) => d.level(soonDays) == DueLevel.overdue).length;
    final soon = attentionPlans.length + attentionDocs.length - overdue;
    final upcoming = statuses.where((s) => s.level == DueLevel.ok).take(5).toList();

    // آخر نشاط
    final recent = <_Activity>[
      for (final s in app.services.take(5))
        _Activity(s.date, ServiceTile(record: s, showVehicle: true)),
      for (final f in app.fuel.take(5))
        _Activity(f.date, FuelTile(log: f, showVehicle: true)),
      for (final e in app.expenses.take(5))
        _Activity(e.date, ExpenseTile(expense: e, showVehicle: true)),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: StatCard(
                  label: 'مصاريف الشهر ده',
                  value: fmtMoney(app.grandTotal(from: monthStart), app.cur),
                  icon: Icons.calendar_month,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatCard(
                  label: 'مصاريف السنة دي',
                  value: fmtMoney(app.grandTotal(from: yearStart), app.cur),
                  icon: Icons.date_range,
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: StatCard(
                  label: 'مواعيد متأخرة',
                  value: '$overdue',
                  icon: Icons.warning_amber_rounded,
                  color: levelColor(DueLevel.overdue, context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatCard(
                  label: 'مواعيد قرّبت',
                  value: '$soon',
                  icon: Icons.notifications_active_outlined,
                  color: levelColor(DueLevel.soon, context),
                ),
              ),
            ]),
          ]),
        ),
        if (attentionPlans.isNotEmpty || attentionDocs.isNotEmpty) ...[
          const SectionTitle('محتاج انتباه'),
          for (final d in attentionDocs) DocDueTile(due: d, showVehicle: true),
          for (final s in attentionPlans) PlanTile(status: s, showVehicle: true),
        ] else
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Card(
              child: ListTile(
                leading: Icon(Icons.verified,
                    color: levelColor(DueLevel.ok, context)),
                title: const Text('كله تمام'),
                subtitle: const Text('مفيش صيانات متأخرة أو قرّبت'),
              ),
            ),
          ),
        const SectionTitle('مركباتي'),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final v in app.vehicles) _MiniVehicleCard(v: v),
            ],
          ),
        ),
        if (upcoming.isNotEmpty) ...[
          const SectionTitle('الجاي'),
          for (final s in upcoming) PlanTile(status: s, showVehicle: true),
        ],
        if (recent.isNotEmpty) ...[
          const SectionTitle('آخر حاجات اتسجلت'),
          for (final a in recent.take(6)) a.widget,
        ],
      ],
    );
  }
}

class _Activity {
  final DateTime date;
  final Widget widget;
  _Activity(this.date, this.widget);
}

class _MiniVehicleCard extends StatelessWidget {
  final Vehicle v;
  const _MiniVehicleCard({required this.v});

  @override
  Widget build(BuildContext context) {
    final app = AppData.instance;
    final cs = Theme.of(context).colorScheme;
    final st = app.statusesOf(v.id!);
    final worst = st.isEmpty ? DueLevel.unknown : st.first.level;
    return SizedBox(
      width: 170,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => VehicleDetailScreen(vehicleId: v.id!))),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(vehicleTypeIcon(v.type), color: cs.primary),
                  const Spacer(),
                  if (worst != DueLevel.unknown)
                    Icon(Icons.circle, size: 12, color: levelColor(worst, context)),
                ]),
                const Spacer(),
                Text(v.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${fmtInt(app.odometerOf(v))} كم',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
