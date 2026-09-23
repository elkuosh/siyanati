import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../utils.dart';
import '../widgets.dart';
import 'forms.dart';
import 'tiles.dart';
import 'vehicles.dart';

class VehicleDetailScreen extends StatefulWidget {
  final int vehicleId;
  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this)
    ..addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _fab(Vehicle v) {
    switch (_tabs.index) {
      case 0:
        openPlanForm(context, vehicleId: v.id!);
        break;
      case 1:
        openServiceForm(context, vehicleId: v.id);
        break;
      case 2:
        openFuelForm(context, vehicleId: v.id);
        break;
      default:
        openExpenseForm(context, vehicleId: v.id);
    }
  }

  static const _fabLabels = ['بند دوري', 'صيانة', 'تفويلة', 'مصروف'];

  @override
  Widget build(BuildContext context) {
    final app = AppData.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final v = app.vehicleById(widget.vehicleId);
        if (v == null) {
          return Scaffold(appBar: AppBar(), body: const SizedBox());
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(v.displayName),
            actions: [
              IconButton(
                tooltip: 'تعديل',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => openVehicleForm(context, vehicle: v),
              ),
              PopupMenuButton<String>(
                onSelected: (k) async {
                  if (k == 'delete') {
                    final ok = await confirmDialog(
                      context,
                      'مسح ${v.displayName}؟',
                      message: 'هيتمسح كل السجل بتاعها (صيانات، بنزين، مصاريف). مفيش رجوع.',
                    );
                    if (ok) {
                      await app.deleteVehicle(v.id!);
                      if (context.mounted) Navigator.pop(context);
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('مسح المركبة')),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              isScrollable: false,
              tabs: const [
                Tab(text: 'المواعيد'),
                Tab(text: 'الصيانات'),
                Tab(text: 'البنزين'),
                Tab(text: 'مصاريف'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'vdFab',
            onPressed: () => _fab(v),
            icon: const Icon(Icons.add),
            label: Text(_fabLabels[_tabs.index]),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              _DueTab(v: v),
              _ServicesTab(v: v),
              _FuelTab(v: v),
              _ExpensesTab(v: v),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final Vehicle v;
  const _Header({required this.v});

  @override
  Widget build(BuildContext context) {
    final app = AppData.instance;
    final cs = Theme.of(context).colorScheme;
    final yearStart = DateTime(DateTime.now().year);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.speed, color: cs.primary, size: 32),
              title: Text('${fmtInt(app.odometerOf(v))} كم',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              subtitle: Text([
                vehicleTypeLabel(v.type),
                if (v.plate.isNotEmpty) v.plate,
                if (v.fuelType.isNotEmpty) v.fuelType,
              ].join(' • ')),
              trailing: FilledButton.tonal(
                onPressed: () => showOdometerDialog(context, v),
                child: const Text('حدّث العداد'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: StatCard(
                label: 'مصاريف السنة دي',
                value: fmtMoney(
                    app.grandTotal(vehicleId: v.id, from: yearStart), app.cur),
                icon: Icons.calendar_today,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'إجمالي الصيانات',
                value: fmtMoney(app.serviceTotal(vehicleId: v.id), app.cur),
                icon: Icons.build,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _DueTab extends StatelessWidget {
  final Vehicle v;
  const _DueTab({required this.v});

  @override
  Widget build(BuildContext context) {
    final app = AppData.instance;
    final statuses = app.statusesOf(v.id!);
    final disabled = app.plansOf(v.id!).where((p) => !p.enabled).toList();
    final docs = app.docDues(vehicleId: v.id);
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _Header(v: v),
        if (docs.isNotEmpty) ...[
          const SectionTitle('الرخصة والتأمين'),
          for (final d in docs) DocDueTile(due: d),
        ],
        SectionTitle('الصيانة الدورية',
            trailing: Text('${statuses.length} بند',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant))),
        if (statuses.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
                'مفيش بنود دورية. دوس "بند دوري" عشان تضيف (زي تغيير الزيت كل 5000 كم).',
                textAlign: TextAlign.center),
          ),
        for (final s in statuses) PlanTile(status: s),
        if (disabled.isNotEmpty) ...[
          const SectionTitle('بنود متوقفة'),
          for (final p in disabled)
            ListTile(
              leading: const Icon(Icons.pause_circle_outline),
              title: Text(p.name),
              onTap: () => openPlanForm(context, plan: p, vehicleId: v.id!),
            ),
        ],
        if (v.notes.isNotEmpty) ...[
          const SectionTitle('ملاحظات'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(v.notes),
          ),
        ],
      ],
    );
  }
}

class _ServicesTab extends StatelessWidget {
  final Vehicle v;
  const _ServicesTab({required this.v});

  @override
  Widget build(BuildContext context) {
    final list = AppData.instance.servicesOf(v.id!);
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.build_outlined,
        text: 'مفيش صيانات متسجلة لسه',
        actionLabel: 'سجّل صيانة',
        onAction: () => openServiceForm(context, vehicleId: v.id),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96, top: 8),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (_, i) => ServiceTile(record: list[i]),
    );
  }
}

class _FuelTab extends StatelessWidget {
  final Vehicle v;
  const _FuelTab({required this.v});

  @override
  Widget build(BuildContext context) {
    final app = AppData.instance;
    final list = app.fuelOf(v.id!);
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.local_gas_station_outlined,
        text: 'سجّل التفويلات عشان تعرف معدل الاستهلاك',
        actionLabel: 'تفويلة جديدة',
        onAction: () => openFuelForm(context, vehicleId: v.id),
      );
    }
    final avg = app.avgConsumption(v.id!);
    final liters = list.fold<double>(0, (a, f) => a + f.liters);
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: StatCard(
                label: 'معدل الاستهلاك',
                value: avg == null ? '—' : '${avg.toStringAsFixed(1)} كم/لتر',
                icon: Icons.eco_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'لكل 100 كم',
                value: avg == null
                    ? '—'
                    : '${(100 / avg).toStringAsFixed(1)} لتر',
                icon: Icons.route_outlined,
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(
              child: StatCard(
                label: 'إجمالي البنزين',
                value: fmtMoney(app.fuelTotal(vehicleId: v.id), app.cur),
                icon: Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'إجمالي اللترات',
                value: '${fmtNum(liters)} لتر',
                icon: Icons.local_gas_station,
              ),
            ),
          ]),
        ),
        if (avg == null)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
                'المعدل بيتحسب لما يبقى عندك تفويلتين "فل" على الأقل ومسجل فيهم العداد.',
                style: TextStyle(fontSize: 12)),
          ),
        const SizedBox(height: 8),
        for (final f in list) FuelTile(log: f),
      ],
    );
  }
}

class _ExpensesTab extends StatelessWidget {
  final Vehicle v;
  const _ExpensesTab({required this.v});

  @override
  Widget build(BuildContext context) {
    final list = AppData.instance.expensesOf(v.id!);
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        text: 'ترخيص، تأمين، مخالفات، غسيل، جراج...',
        actionLabel: 'مصروف جديد',
        onAction: () => openExpenseForm(context, vehicleId: v.id),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96, top: 8),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (_, i) => ExpenseTile(expense: list[i]),
    );
  }
}
