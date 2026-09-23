import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../utils.dart';
import '../widgets.dart';
import 'forms.dart';

String serviceTitle(ServiceRecord s) {
  final names = s.types.map((k) => ServiceCatalog.byKey(k).label).toList();
  if (names.isEmpty) return s.title.isEmpty ? 'صيانة' : s.title;
  return names.join('، ');
}

class ServiceTile extends StatelessWidget {
  final ServiceRecord record;
  final bool showVehicle;
  const ServiceTile({super.key, required this.record, this.showVehicle = false});

  @override
  Widget build(BuildContext context) {
    final app = AppData.instance;
    final s = record;
    final cs = Theme.of(context).colorScheme;
    final icon = s.types.isEmpty
        ? Icons.build
        : ServiceCatalog.byKey(s.types.first).icon;
    final sub = <String>[
      fmtDate(s.date),
      if (s.odometer != null) '${fmtInt(s.odometer!)} كم',
      if (showVehicle) app.vehicleById(s.vehicleId)?.displayName ?? '',
      if (s.workshop.isNotEmpty) s.workshop,
    ].where((e) => e.isNotEmpty).join(' • ');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.secondaryContainer,
        child: Icon(icon, color: cs.onSecondaryContainer, size: 20),
      ),
      title: Text(serviceTitle(s), maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
          [sub, if (s.types.isNotEmpty && s.title.isNotEmpty) s.title].join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis),
      isThreeLine: s.types.isNotEmpty && s.title.isNotEmpty,
      trailing: Text(fmtMoney(s.total, app.cur),
          style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: () => openServiceForm(context, record: s),
      onLongPress: () => _delete(context),
    );
  }

  Future<void> _delete(BuildContext context) async {
    if (await confirmDialog(context, 'مسح الصيانة دي؟')) {
      await AppData.instance.deleteService(record.id!);
    }
  }
}

class FuelTile extends StatelessWidget {
  final FuelLog log;
  final bool showVehicle;
  const FuelTile({super.key, required this.log, this.showVehicle = false});

  @override
  Widget build(BuildContext context) {
    final app = AppData.instance;
    final f = log;
    final cs = Theme.of(context).colorScheme;
    final sub = <String>[
      fmtDate(f.date),
      if (f.odometer != null) '${fmtInt(f.odometer!)} كم',
      if (showVehicle) app.vehicleById(f.vehicleId)?.displayName ?? '',
      if (f.station.isNotEmpty) f.station,
    ].where((e) => e.isNotEmpty).join(' • ');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.tertiaryContainer,
        child: Icon(Icons.local_gas_station,
            color: cs.onTertiaryContainer, size: 20),
      ),
      title: Text(
          '${fmtNum(f.liters)} لتر${f.fullTank ? ' (فل)' : ''}'
          '${f.pricePerLiter > 0 ? ' • ${fmtNum(f.pricePerLiter)}/لتر' : ''}'),
      subtitle: Text(sub),
      trailing: Text(fmtMoney(f.cost, app.cur),
          style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: () => openFuelForm(context, log: f),
      onLongPress: () async {
        if (await confirmDialog(context, 'مسح التفويلة دي؟')) {
          await app.deleteFuel(f.id!);
        }
      },
    );
  }
}

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final bool showVehicle;
  const ExpenseTile(
      {super.key, required this.expense, this.showVehicle = false});

  @override
  Widget build(BuildContext context) {
    final app = AppData.instance;
    final e = expense;
    final c = ExpenseCategory.byKey(e.category);
    final cs = Theme.of(context).colorScheme;
    final sub = <String>[
      fmtDate(e.date),
      if (showVehicle) app.vehicleById(e.vehicleId)?.displayName ?? '',
      if (e.notes.isNotEmpty) e.notes,
    ].where((x) => x.isNotEmpty).join(' • ');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.surfaceContainerHighest,
        child: Icon(c.icon, color: cs.onSurfaceVariant, size: 20),
      ),
      title: Text(c.label),
      subtitle: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(fmtMoney(e.amount, app.cur),
          style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: () => openExpenseForm(context, expense: e),
      onLongPress: () async {
        if (await confirmDialog(context, 'مسح المصروف ده؟')) {
          await app.deleteExpense(e.id!);
        }
      },
    );
  }
}

class PlanTile extends StatelessWidget {
  final PlanStatus status;
  final bool showVehicle;
  const PlanTile({super.key, required this.status, this.showVehicle = false});

  @override
  Widget build(BuildContext context) {
    final s = status;
    final t = ServiceCatalog.byKey(s.plan.typeKey);
    final color = levelColor(s.level, context);
    final every = [
      if (s.plan.intervalKm != null) '${fmtInt(s.plan.intervalKm!)} كم',
      if (s.plan.intervalMonths != null) '${s.plan.intervalMonths} شهر',
    ].join(' أو ');
    final due = [
      if (s.dueKm != null) 'عند ${fmtInt(s.dueKm!)} كم',
      if (s.dueDate != null) fmtDate(s.dueDate),
    ].join(' / ');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(t.icon, color: color, size: 20),
      ),
      title: Text(showVehicle
          ? '${s.plan.name} — ${s.vehicle.displayName}'
          : s.plan.name),
      subtitle: Text(
        [
          s.summary,
          if (due.isNotEmpty) 'الميعاد: $due',
          if (!showVehicle) 'كل $every',
        ].join('\n'),
      ),
      isThreeLine: true,
      trailing: LevelChip(s.level),
      onTap: () => _actions(context),
    );
  }

  void _actions(BuildContext context) {
    final s = status;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(s.plan.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  'آخر مرة: ${fmtDate(s.lastDate)}${s.lastKm != null ? ' عند ${fmtInt(s.lastKm!)} كم' : ''}'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('اتعملت — سجّل صيانة'),
              onTap: () {
                Navigator.pop(c);
                openServiceForm(context,
                    vehicleId: s.plan.vehicleId, presetTypes: [s.plan.typeKey]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('تعديل البند'),
              onTap: () {
                Navigator.pop(c);
                openPlanForm(context, plan: s.plan, vehicleId: s.plan.vehicleId);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class DocDueTile extends StatelessWidget {
  final DocDue due;
  final bool showVehicle;
  const DocDueTile({super.key, required this.due, this.showVehicle = false});

  @override
  Widget build(BuildContext context) {
    final lvl = due.level(AppData.instance.settings.soonDays);
    final color = levelColor(lvl, context);
    final d = due.remainingDays;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(due.label.contains('رخصة') ? Icons.badge : Icons.shield,
            color: color, size: 20),
      ),
      title: Text(showVehicle
          ? '${due.label} — ${due.vehicle.displayName}'
          : due.label),
      subtitle: Text('${fmtDate(due.date)} • '
          '${d < 0 ? 'منتهي من ${daysText(-d)}' : d == 0 ? 'النهارده' : 'باقي ${daysText(d)}'}'),
      trailing: LevelChip(lvl),
    );
  }
}
