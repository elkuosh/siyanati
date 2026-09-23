import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../utils.dart';
import '../widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int? _vehicle;
  String _period = 'year'; // month | 3m | year | 12m | all

  (DateTime?, DateTime?) _range() {
    final n = DateTime.now();
    switch (_period) {
      case 'month':
        return (DateTime(n.year, n.month), null);
      case '3m':
        return (DateTime(n.year, n.month - 2), null);
      case 'year':
        return (DateTime(n.year), null);
      case '12m':
        return (DateTime(n.year, n.month - 11), null);
      default:
        return (null, null);
    }
  }

  static const _periods = [
    ['month', 'الشهر ده'],
    ['3m', 'آخر 3 شهور'],
    ['year', 'السنة دي'],
    ['12m', 'آخر 12 شهر'],
    ['all', 'من الأول'],
  ];

  @override
  Widget build(BuildContext context) {
    final app = AppData.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير')),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          if (app.vehicles.isEmpty) {
            return const EmptyState(
                icon: Icons.bar_chart, text: 'ضيف مركبة وسجّل مصاريف عشان تشوف التقارير');
          }
          if (_vehicle != null && app.vehicleById(_vehicle!) == null) {
            _vehicle = null;
          }
          final (from, to) = _range();
          final vid = _vehicle;
          final sTotal = app.serviceTotal(vehicleId: vid, from: from, to: to);
          final fTotal = app.fuelTotal(vehicleId: vid, from: from, to: to);
          final eTotal = app.expenseTotal(vehicleId: vid, from: from, to: to);
          final total = sTotal + fTotal + eTotal;

          bool inRange(DateTime d, int v) =>
              (vid == null || v == vid) &&
              (from == null || !d.isBefore(from)) &&
              (to == null || d.isBefore(to));

          // حسب نوع الصيانة (الزيارة اللي فيها أكتر من نوع بتتقسم بالتساوي)
          final byType = <String, double>{};
          double parts = 0, labor = 0;
          for (final s in app.services) {
            if (!inRange(s.date, s.vehicleId)) continue;
            parts += s.partsCost;
            labor += s.laborCost;
            final keys = s.types.isEmpty ? ['other'] : s.types;
            for (final k in keys) {
              byType[k] = (byType[k] ?? 0) + s.total / keys.length;
            }
          }
          final typeRows = byType.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          final byCat = <String, double>{};
          for (final e in app.expenses) {
            if (!inRange(e.date, e.vehicleId)) continue;
            byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
          }
          final catRows = byCat.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          // آخر 12 شهر
          final n = DateTime.now();
          final months = [
            for (var i = 11; i >= 0; i--) DateTime(n.year, n.month - i)
          ];
          final monthly = [
            for (final m in months)
              app.grandTotal(
                  vehicleId: vid, from: m, to: DateTime(m.year, m.month + 1))
          ];
          final avgMonthly = monthly.fold<double>(0, (a, b) => a + b) / 12;

          // مقارنة المركبات
          final perVehicle = [
            for (final v in app.vehicles)
              MapEntry(v, app.grandTotal(vehicleId: v.id, from: from, to: to))
          ]..sort((a, b) => b.value.compareTo(a.value));

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(children: [
                  for (final p in _periods)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ChoiceChip(
                        label: Text(p[1]),
                        selected: _period == p[0],
                        onSelected: (_) => setState(() => _period = p[0]),
                      ),
                    ),
                ]),
              ),
              if (app.vehicles.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: DropdownButtonFormField<int?>(
                    value: _vehicle,
                    decoration: const InputDecoration(labelText: 'المركبة'),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('كل المركبات')),
                      for (final v in app.vehicles)
                        DropdownMenuItem<int?>(
                            value: v.id, child: Text(v.displayName)),
                    ],
                    onChanged: (id) => setState(() => _vehicle = id),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Card(
                  margin: EdgeInsets.zero,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('إجمالي المصاريف'),
                        const SizedBox(height: 4),
                        Text(fmtMoney(total, app.cur),
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SectionTitle('التوزيع'),
              ShareRow(
                  label: 'صيانات',
                  icon: Icons.build,
                  value: sTotal,
                  total: total,
                  cur: app.cur),
              ShareRow(
                  label: 'بنزين',
                  icon: Icons.local_gas_station,
                  value: fTotal,
                  total: total,
                  cur: app.cur),
              ShareRow(
                  label: 'مصاريف تانية',
                  icon: Icons.receipt_long,
                  value: eTotal,
                  total: total,
                  cur: app.cur),
              if (vid != null) _vehicleMetrics(context, app, vid),
              SectionTitle('آخر 12 شهر',
                  trailing: Text('متوسط ${fmtMoney(avgMonthly, app.cur)}/شهر',
                      style: const TextStyle(fontSize: 12))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: BarChart(
                  labels: [for (final m in months) '${m.month}/${m.year % 100}'],
                  values: monthly,
                  format: (x) => fmtMoney(x, app.cur),
                ),
              ),
              if (typeRows.isNotEmpty) ...[
                SectionTitle('الصيانات حسب النوع',
                    trailing: Text(
                        'قطع ${fmtMoney(parts, app.cur)} • مصنعية ${fmtMoney(labor, app.cur)}',
                        style: const TextStyle(fontSize: 11))),
                for (final r in typeRows)
                  ShareRow(
                      label: ServiceCatalog.byKey(r.key).label,
                      icon: ServiceCatalog.byKey(r.key).icon,
                      value: r.value,
                      total: sTotal,
                      cur: app.cur),
              ],
              if (catRows.isNotEmpty) ...[
                const SectionTitle('المصاريف التانية'),
                for (final r in catRows)
                  ShareRow(
                      label: ExpenseCategory.byKey(r.key).label,
                      icon: ExpenseCategory.byKey(r.key).icon,
                      value: r.value,
                      total: eTotal,
                      cur: app.cur),
              ],
              if (vid == null && app.vehicles.length > 1) ...[
                const SectionTitle('حسب المركبة'),
                for (final e in perVehicle)
                  ShareRow(
                      label: e.key.displayName,
                      icon: vehicleTypeIcon(e.key.type),
                      value: e.value,
                      total: total,
                      cur: app.cur),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _vehicleMetrics(BuildContext context, AppData app, int vid) {
    final avg = app.avgConsumption(vid);
    final cpk = app.costPerKm(vid);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(children: [
        Expanded(
          child: StatCard(
            label: 'التكلفة لكل كيلو',
            value: cpk == null ? '—' : fmtMoney(cpk, app.cur),
            icon: Icons.route,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatCard(
            label: 'معدل الاستهلاك',
            value: avg == null ? '—' : '${avg.toStringAsFixed(1)} كم/لتر',
            icon: Icons.eco_outlined,
          ),
        ),
      ]),
    );
  }
}
