import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../utils.dart';
import '../widgets.dart';

// ===========================================================================
// نموذج زيارة صيانة
// ===========================================================================
Future<void> openServiceForm(BuildContext context,
        {ServiceRecord? record, int? vehicleId, List<String>? presetTypes}) =>
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceFormScreen(
            record: record, vehicleId: vehicleId, presetTypes: presetTypes),
      ),
    );

class ServiceFormScreen extends StatefulWidget {
  final ServiceRecord? record;
  final int? vehicleId;
  final List<String>? presetTypes;
  const ServiceFormScreen(
      {super.key, this.record, this.vehicleId, this.presetTypes});

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final _form = GlobalKey<FormState>();
  late ServiceRecord r;
  late final TextEditingController odo, title, parts, labor, workshop, notes;

  bool get isNew => widget.record == null;

  @override
  void initState() {
    super.initState();
    final app = AppData.instance;
    final src = widget.record;
    final firstId = app.vehicles.isNotEmpty ? app.vehicles.first.id! : 0;
    r = src == null
        ? ServiceRecord(
            vehicleId: widget.vehicleId ?? firstId,
            date: today(),
            types: List.of(widget.presetTypes ?? const []),
          )
        : ServiceRecord.fromMap(src.toMap());
    final v = app.vehicleById(r.vehicleId);
    odo = TextEditingController(
        text: r.odometer?.toString() ??
            (isNew && v != null ? '${app.odometerOf(v)}' : ''));
    title = TextEditingController(text: r.title);
    parts = TextEditingController(text: numText(isNew ? null : r.partsCost));
    labor = TextEditingController(text: numText(isNew ? null : r.laborCost));
    workshop = TextEditingController(text: r.workshop);
    notes = TextEditingController(text: r.notes);
  }

  @override
  void dispose() {
    for (final c in [odo, title, parts, labor, workshop, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  VehicleType get _vType =>
      AppData.instance.vehicleById(r.vehicleId)?.type ?? VehicleType.car;

  double get _total =>
      (parseDouble(parts.text) ?? 0) + (parseDouble(labor.text) ?? 0);

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (r.types.isEmpty && title.text.trim().isEmpty) {
      showSnack(context, 'اختار نوع الصيانة أو اكتب وصف');
      return;
    }
    r
      ..odometer = parseInt(odo.text)
      ..title = title.text.trim()
      ..partsCost = parseDouble(parts.text) ?? 0
      ..laborCost = parseDouble(labor.text) ?? 0
      ..workshop = workshop.text.trim()
      ..notes = notes.text.trim();
    await AppData.instance.saveService(r);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    final app = AppData.instance;
    final cs = Theme.of(context).colorScheme;
    final workshops = {
      for (final s in app.services)
        if (s.workshop.isNotEmpty) s.workshop
    }.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'تسجيل صيانة' : 'تعديل الصيانة'),
        actions: [TextButton(onPressed: _save, child: const Text('حفظ'))],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            VehicleDropdown(
              value: app.vehicleById(r.vehicleId) == null ? null : r.vehicleId,
              onChanged: (id) => setState(() => r.vehicleId = id ?? r.vehicleId),
            ),
            gap,
            Row(children: [
              Expanded(
                child: DateField(
                  label: 'التاريخ',
                  value: r.date,
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  onChanged: (d) => setState(() => r.date = d ?? r.date),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NumField(
                    controller: odo, label: 'العداد', suffix: 'كم'),
              ),
            ]),
            const SizedBox(height: 16),
            Text('اتعمل إيه؟', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in ServiceCatalog.forType(_vType))
                  FilterChip(
                    avatar: Icon(t.icon, size: 18),
                    label: Text(t.label),
                    selected: r.types.contains(t.key),
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        r.types.add(t.key);
                      } else {
                        r.types.remove(t.key);
                      }
                    }),
                  ),
              ],
            ),
            gap,
            TextFormField(
              controller: title,
              decoration: const InputDecoration(
                  labelText: 'وصف / تفاصيل',
                  hintText: 'مثلاً: زيت 5W-30 شل هيلكس 4 لتر'),
            ),
            gap,
            Row(children: [
              Expanded(
                child: NumField(
                  controller: parts,
                  label: 'قطع الغيار',
                  suffix: app.cur,
                  decimal: true,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NumField(
                  controller: labor,
                  label: 'المصنعية',
                  suffix: app.cur,
                  decimal: true,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('الإجمالي: ${fmtMoney(_total, app.cur)}',
                  style: TextStyle(
                      color: cs.primary, fontWeight: FontWeight.bold)),
            ),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: workshop.text),
              optionsBuilder: (v) => v.text.isEmpty
                  ? const Iterable<String>.empty()
                  : workshops.where((w) => w.contains(v.text)),
              onSelected: (s) => workshop.text = s,
              fieldViewBuilder: (context, ctrl, focus, onSubmit) {
                return TextFormField(
                  controller: ctrl,
                  focusNode: focus,
                  onChanged: (s) => workshop.text = s,
                  decoration: const InputDecoration(
                      labelText: 'الورشة / الميكانيكي',
                      prefixIcon: Icon(Icons.store_outlined)),
                );
              },
            ),
            gap,
            TextFormField(
              controller: notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('حفظ')),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// نموذج بند صيانة دورية
// ===========================================================================
Future<void> openPlanForm(BuildContext context,
        {MaintenancePlan? plan, required int vehicleId}) =>
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => PlanFormScreen(plan: plan, vehicleId: vehicleId)),
    );

class PlanFormScreen extends StatefulWidget {
  final MaintenancePlan? plan;
  final int vehicleId;
  const PlanFormScreen({super.key, this.plan, required this.vehicleId});

  @override
  State<PlanFormScreen> createState() => _PlanFormScreenState();
}

class _PlanFormScreenState extends State<PlanFormScreen> {
  final _form = GlobalKey<FormState>();
  late MaintenancePlan p;
  late final TextEditingController name, km, months, baseKm;

  bool get isNew => widget.plan == null;

  @override
  void initState() {
    super.initState();
    final src = widget.plan;
    p = src == null
        ? MaintenancePlan(
            vehicleId: widget.vehicleId, typeKey: 'other', name: '')
        : MaintenancePlan.fromMap(src.toMap());
    name = TextEditingController(text: p.name);
    km = TextEditingController(text: p.intervalKm?.toString() ?? '');
    months = TextEditingController(text: p.intervalMonths?.toString() ?? '');
    baseKm = TextEditingController(text: p.baseKm?.toString() ?? '');
  }

  @override
  void dispose() {
    for (final c in [name, km, months, baseKm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _pickType(String key) {
    final v = AppData.instance.vehicleById(widget.vehicleId);
    final t = ServiceCatalog.byKey(key);
    setState(() {
      final oldLabel = ServiceCatalog.byKey(p.typeKey).label;
      p.typeKey = key;
      if (name.text.trim().isEmpty || name.text == oldLabel) {
        name.text = key == 'other' ? '' : t.label;
      }
      if (v != null && isNew) {
        final dk = t.defaultKm(v.type);
        final dm = t.defaultMonths(v.type);
        if (km.text.isEmpty && dk != null) km.text = '$dk';
        if (months.text.isEmpty && dm != null) months.text = '$dm';
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ik = parseInt(km.text);
    final im = parseInt(months.text);
    if ((ik == null || ik == 0) && (im == null || im == 0)) {
      showSnack(context, 'حدد كل كام كيلو أو كل كام شهر');
      return;
    }
    p
      ..name = name.text.trim()
      ..intervalKm = (ik == null || ik == 0) ? null : ik
      ..intervalMonths = (im == null || im == 0) ? null : im
      ..baseKm = parseInt(baseKm.text);
    await AppData.instance.savePlan(p);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    final v = AppData.instance.vehicleById(widget.vehicleId);
    final types = ServiceCatalog.forType(v?.type ?? VehicleType.car);
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'بند صيانة دورية' : 'تعديل البند'),
        actions: [
          if (!isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirmDialog(context, 'مسح البند ده؟')) {
                  await AppData.instance.deletePlan(p.id!);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          TextButton(onPressed: _save, child: const Text('حفظ')),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: types.any((t) => t.key == p.typeKey) ? p.typeKey : 'other',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'نوع الصيانة'),
              items: [
                for (final t in types)
                  DropdownMenuItem(
                    value: t.key,
                    child: Row(children: [
                      Icon(t.icon, size: 20),
                      const SizedBox(width: 8),
                      Text(t.label),
                    ]),
                  ),
              ],
              onChanged: (k) => _pickType(k ?? 'other'),
            ),
            gap,
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'الاسم'),
              validator: (s) =>
                  (s ?? '').trim().isEmpty ? 'اكتب اسم للبند' : null,
            ),
            const SizedBox(height: 16),
            Text('يتعمل كل:', style: Theme.of(context).textTheme.titleSmall),
            gap,
            Row(children: [
              Expanded(
                  child: NumField(controller: km, label: 'كيلومتر', suffix: 'كم')),
              const SizedBox(width: 10),
              const Text('أو'),
              const SizedBox(width: 10),
              Expanded(
                  child: NumField(
                      controller: months, label: 'شهور', suffix: 'شهر')),
            ]),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('اللي ييجي الأول فيهم هو الميعاد.',
                  style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 20),
            Text('آخر مرة اتعملت (لو قبل ما تبدأ تسجل في التطبيق)',
                style: Theme.of(context).textTheme.titleSmall),
            gap,
            Row(children: [
              Expanded(
                child: DateField(
                  label: 'التاريخ',
                  value: p.baseDate,
                  clearable: true,
                  lastDate: DateTime.now(),
                  onChanged: (d) => setState(() => p.baseDate = d),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: NumField(
                      controller: baseKm, label: 'العداد', suffix: 'كم')),
            ]),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                  'لما تسجل صيانة من النوع ده، التطبيق بيحدّث الميعاد لوحده.',
                  style: TextStyle(fontSize: 12)),
            ),
            gap,
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('مفعّل'),
              value: p.enabled,
              onChanged: (b) => setState(() => p.enabled = b),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('حفظ')),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// نموذج تفويلة
// ===========================================================================
Future<void> openFuelForm(BuildContext context, {FuelLog? log, int? vehicleId}) =>
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => FuelFormScreen(log: log, vehicleId: vehicleId)),
    );

class FuelFormScreen extends StatefulWidget {
  final FuelLog? log;
  final int? vehicleId;
  const FuelFormScreen({super.key, this.log, this.vehicleId});

  @override
  State<FuelFormScreen> createState() => _FuelFormScreenState();
}

class _FuelFormScreenState extends State<FuelFormScreen> {
  final _form = GlobalKey<FormState>();
  late FuelLog f;
  late final TextEditingController odo, liters, cost, price, station, notes;
  bool isNew = true;

  @override
  void initState() {
    super.initState();
    final app = AppData.instance;
    final src = widget.log;
    isNew = src == null;
    final firstId = app.vehicles.isNotEmpty ? app.vehicles.first.id! : 0;
    f = src == null
        ? FuelLog(vehicleId: widget.vehicleId ?? firstId, date: today())
        : FuelLog.fromMap(src.toMap());
    odo = TextEditingController(text: f.odometer?.toString() ?? '');
    liters = TextEditingController(text: isNew ? '' : numText(f.liters));
    cost = TextEditingController(text: isNew ? '' : numText(f.cost));
    // آخر سعر لتر متسجل
    double? lastPrice;
    for (final x in app.fuel) {
      if (x.pricePerLiter > 0) {
        lastPrice = x.pricePerLiter;
        break;
      }
    }
    price = TextEditingController(
        text: isNew
            ? (lastPrice == null ? '' : lastPrice.toStringAsFixed(2))
            : f.pricePerLiter.toStringAsFixed(2));
    station = TextEditingController(text: f.station);
    notes = TextEditingController(text: f.notes);
  }

  @override
  void dispose() {
    for (final c in [odo, liters, cost, price, station, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fromLiters(String _) {
    final l = parseDouble(liters.text);
    final p = parseDouble(price.text);
    if (l != null && p != null) cost.text = (l * p).toStringAsFixed(2);
    setState(() {});
  }

  void _fromCost(String _) {
    final c = parseDouble(cost.text);
    final p = parseDouble(price.text);
    if (c != null && p != null && p > 0) {
      liters.text = (c / p).toStringAsFixed(2);
    }
    setState(() {});
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    f
      ..odometer = parseInt(odo.text)
      ..liters = parseDouble(liters.text) ?? 0
      ..cost = parseDouble(cost.text) ?? 0
      ..station = station.text.trim()
      ..notes = notes.text.trim();
    await AppData.instance.saveFuel(f);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    final app = AppData.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'تفويلة بنزين' : 'تعديل التفويلة'),
        actions: [TextButton(onPressed: _save, child: const Text('حفظ'))],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            VehicleDropdown(
              value: app.vehicleById(f.vehicleId) == null ? null : f.vehicleId,
              onChanged: (id) => setState(() => f.vehicleId = id ?? f.vehicleId),
            ),
            gap,
            Row(children: [
              Expanded(
                child: DateField(
                  label: 'التاريخ',
                  value: f.date,
                  onChanged: (d) => setState(() => f.date = d ?? f.date),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: NumField(controller: odo, label: 'العداد', suffix: 'كم')),
            ]),
            gap,
            NumField(
              controller: price,
              label: 'سعر اللتر',
              suffix: app.cur,
              decimal: true,
              icon: Icons.sell_outlined,
              onChanged: _fromLiters,
            ),
            gap,
            Row(children: [
              Expanded(
                child: NumField(
                  controller: liters,
                  label: 'اللترات',
                  suffix: 'لتر',
                  decimal: true,
                  onChanged: _fromLiters,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NumField(
                  controller: cost,
                  label: 'المبلغ',
                  suffix: app.cur,
                  decimal: true,
                  required: true,
                  onChanged: _fromCost,
                ),
              ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('فوّلت تانك فل'),
              subtitle: const Text('مهم لحساب معدل الاستهلاك بدقة'),
              value: f.fullTank,
              onChanged: (b) => setState(() => f.fullTank = b),
            ),
            TextFormField(
              controller: station,
              decoration: const InputDecoration(
                  labelText: 'البنزينة', prefixIcon: Icon(Icons.place_outlined)),
            ),
            gap,
            TextFormField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('حفظ')),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// نموذج مصروف
// ===========================================================================
Future<void> openExpenseForm(BuildContext context,
        {Expense? expense, int? vehicleId}) =>
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              ExpenseFormScreen(expense: expense, vehicleId: vehicleId)),
    );

class ExpenseFormScreen extends StatefulWidget {
  final Expense? expense;
  final int? vehicleId;
  const ExpenseFormScreen({super.key, this.expense, this.vehicleId});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _form = GlobalKey<FormState>();
  late Expense e;
  late final TextEditingController amount, notes;
  bool isNew = true;

  @override
  void initState() {
    super.initState();
    final app = AppData.instance;
    final src = widget.expense;
    isNew = src == null;
    final firstId = app.vehicles.isNotEmpty ? app.vehicles.first.id! : 0;
    e = src == null
        ? Expense(vehicleId: widget.vehicleId ?? firstId, date: today())
        : Expense.fromMap(src.toMap());
    amount = TextEditingController(text: isNew ? '' : numText(e.amount));
    notes = TextEditingController(text: e.notes);
  }

  @override
  void dispose() {
    amount.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    e
      ..amount = parseDouble(amount.text) ?? 0
      ..notes = notes.text.trim();
    await AppData.instance.saveExpense(e);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    final app = AppData.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'مصروف جديد' : 'تعديل المصروف'),
        actions: [TextButton(onPressed: _save, child: const Text('حفظ'))],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            VehicleDropdown(
              value: app.vehicleById(e.vehicleId) == null ? null : e.vehicleId,
              onChanged: (id) => setState(() => e.vehicleId = id ?? e.vehicleId),
            ),
            gap,
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in ExpenseCategory.all)
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 18),
                    label: Text(c.label),
                    selected: e.category == c.key,
                    onSelected: (_) => setState(() => e.category = c.key),
                  ),
              ],
            ),
            gap,
            DateField(
              label: 'التاريخ',
              value: e.date,
              onChanged: (d) => setState(() => e.date = d ?? e.date),
            ),
            gap,
            NumField(
              controller: amount,
              label: 'المبلغ',
              suffix: app.cur,
              decimal: true,
              required: true,
              icon: Icons.payments_outlined,
            ),
            gap,
            TextFormField(
              controller: notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('حفظ')),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// تحديث العداد
// ===========================================================================
Future<void> showOdometerDialog(BuildContext context, Vehicle v) async {
  final app = AppData.instance;
  final current = app.odometerOf(v);
  final ctrl = TextEditingController(text: '$current');
  final formKey = GlobalKey<FormState>();
  final km = await showDialog<int>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('عداد ${v.displayName}'),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'القراية الحالية', suffixText: 'كم'),
          validator: (s) {
            final n = parseInt(s ?? '');
            if (n == null) return 'اكتب رقم';
            if (n < current) return 'أقل من آخر قراية (${fmtInt(current)})';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(c, parseInt(ctrl.text));
            }
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
  if (km != null) await app.updateOdometer(v.id!, km);
}
