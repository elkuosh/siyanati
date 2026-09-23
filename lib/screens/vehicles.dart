import 'package:flutter/material.dart';

import '../models.dart';
import '../notifications.dart';
import '../state.dart';
import '../utils.dart';
import '../widgets.dart';
import 'vehicle_detail.dart';

class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppData.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('مركباتي')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addVehicle',
        onPressed: () => openVehicleForm(context),
        icon: const Icon(Icons.add),
        label: const Text('مركبة جديدة'),
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          if (app.vehicles.isEmpty) {
            return EmptyState(
              icon: Icons.garage_outlined,
              text: 'مفيش مركبات لسه.\nضيف عربيتك أو الموتوسيكل بتاعك.',
              actionLabel: 'إضافة مركبة',
              onAction: () => openVehicleForm(context),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: [
              for (final v in app.vehicles) VehicleCard(vehicle: v),
            ],
          );
        },
      ),
    );
  }
}

class VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  const VehicleCard({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final app = AppData.instance;
    final v = vehicle;
    final cs = Theme.of(context).colorScheme;
    final statuses = app.statusesOf(v.id!);
    final overdue = statuses.where((s) => s.level == DueLevel.overdue).length;
    final soon = statuses.where((s) => s.level == DueLevel.soon).length;
    final next = statuses.isEmpty ? null : statuses.first;
    final sub = [
      if (v.brand.isNotEmpty || v.model.isNotEmpty) '${v.brand} ${v.model}'.trim(),
      if (v.year != null) '${v.year}',
      if (v.plate.isNotEmpty) v.plate,
    ].join(' • ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => VehicleDetailScreen(vehicleId: v.id!))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: cs.primaryContainer,
                    child: Icon(vehicleTypeIcon(v.type),
                        color: cs.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.displayName,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                        if (sub.isNotEmpty)
                          Text(sub,
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 13)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${fmtInt(app.odometerOf(v))} كم',
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('العداد',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
              if (next != null) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    Icon(Icons.schedule,
                        size: 18, color: levelColor(next.level, context)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('${next.plan.name}: ${next.summary}',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (overdue > 0) ...[
                      const SizedBox(width: 6),
                      _CountBadge(overdue, levelColor(DueLevel.overdue, context)),
                    ],
                    if (soon > 0) ...[
                      const SizedBox(width: 4),
                      _CountBadge(soon, levelColor(DueLevel.soon, context)),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int n;
  final Color color;
  const _CountBadge(this.n, this.color);

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: 11,
        backgroundColor: color,
        child: Text('$n',
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      );
}

Future<void> openVehicleForm(BuildContext context, {Vehicle? vehicle}) =>
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VehicleFormScreen(vehicle: vehicle)),
    );

class VehicleFormScreen extends StatefulWidget {
  final Vehicle? vehicle;
  const VehicleFormScreen({super.key, this.vehicle});

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _form = GlobalKey<FormState>();
  late Vehicle v;
  late final TextEditingController name, brand, model, year, plate, color,
      odometer, notes;
  bool addPlans = true;

  bool get isNew => widget.vehicle == null;

  @override
  void initState() {
    super.initState();
    final src = widget.vehicle;
    v = src == null ? Vehicle() : Vehicle.fromMap(src.toMap());
    name = TextEditingController(text: v.name);
    brand = TextEditingController(text: v.brand);
    model = TextEditingController(text: v.model);
    year = TextEditingController(text: v.year?.toString() ?? '');
    plate = TextEditingController(text: v.plate);
    color = TextEditingController(text: v.color);
    odometer = TextEditingController(text: isNew ? '' : '${v.odometer}');
    notes = TextEditingController(text: v.notes);
  }

  @override
  void dispose() {
    for (final c in [name, brand, model, year, plate, color, odometer, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    v
      ..name = name.text.trim()
      ..brand = brand.text.trim()
      ..model = model.text.trim()
      ..year = parseInt(year.text)
      ..plate = plate.text.trim()
      ..color = color.text.trim()
      ..odometer = parseInt(odometer.text) ?? 0
      ..notes = notes.text.trim();
    await AppData.instance.saveVehicle(v, addDefaultPlans: isNew && addPlans);
    // أول مركبة: نطلب إذن الإشعارات
    if (isNew && AppData.instance.vehicles.length == 1) {
      await Notifier.instance.requestPermission();
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'مركبة جديدة' : 'تعديل المركبة'),
        actions: [
          TextButton(onPressed: _save, child: const Text('حفظ')),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<VehicleType>(
              segments: const [
                ButtonSegment(
                    value: VehicleType.car,
                    icon: Icon(Icons.directions_car),
                    label: Text('عربية')),
                ButtonSegment(
                    value: VehicleType.moto,
                    icon: Icon(Icons.two_wheeler),
                    label: Text('موتوسيكل')),
              ],
              selected: {v.type},
              onSelectionChanged: (s) => setState(() => v.type = s.first),
            ),
            gap,
            TextFormField(
              controller: name,
              decoration: const InputDecoration(
                  labelText: 'اسم مميز (اختياري)',
                  hintText: 'مثلاً: عربية الشغل',
                  prefixIcon: Icon(Icons.label_outline)),
            ),
            gap,
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: brand,
                  decoration: const InputDecoration(labelText: 'الماركة'),
                  validator: (s) => (s ?? '').trim().isEmpty &&
                          name.text.trim().isEmpty
                      ? 'اكتب الماركة أو اسم'
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: model,
                  decoration: const InputDecoration(labelText: 'الموديل'),
                ),
              ),
            ]),
            gap,
            Row(children: [
              Expanded(
                  child: NumField(controller: year, label: 'سنة الصنع')),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: color,
                  decoration: const InputDecoration(labelText: 'اللون'),
                ),
              ),
            ]),
            gap,
            TextFormField(
              controller: plate,
              decoration: const InputDecoration(
                  labelText: 'رقم اللوحة',
                  prefixIcon: Icon(Icons.pin_outlined)),
            ),
            gap,
            NumField(
              controller: odometer,
              label: 'قراية العداد الحالية',
              suffix: 'كم',
              icon: Icons.speed,
              required: true,
            ),
            gap,
            DropdownButtonFormField<String>(
              value: fuelTypes.contains(v.fuelType) ? v.fuelType : null,
              decoration: const InputDecoration(
                  labelText: 'نوع الوقود',
                  prefixIcon: Icon(Icons.local_gas_station)),
              items: [
                for (final f in fuelTypes)
                  DropdownMenuItem(value: f, child: Text(f)),
              ],
              onChanged: (f) => setState(() => v.fuelType = f ?? ''),
            ),
            const SizedBox(height: 20),
            Text('المواعيد الرسمية',
                style: Theme.of(context).textTheme.titleSmall),
            gap,
            DateField(
              label: 'انتهاء الرخصة',
              value: v.licenseExpiry,
              clearable: true,
              onChanged: (d) => setState(() => v.licenseExpiry = d),
            ),
            gap,
            DateField(
              label: 'انتهاء التأمين',
              value: v.insuranceExpiry,
              clearable: true,
              onChanged: (d) => setState(() => v.insuranceExpiry = d),
            ),
            gap,
            TextFormField(
              controller: notes,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'ملاحظات (رقم الشاسيه، مقاس الكاوتش...)'),
            ),
            if (isNew) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: addPlans,
                onChanged: (b) => setState(() => addPlans = b),
                title: const Text('ضيف جدول صيانة دورية جاهز'),
                subtitle: Text(v.type == VehicleType.car
                    ? 'زيت كل 5000 كم، فلاتر، فرامل، بوجيهات... وتقدر تعدله بعدين'
                    : 'زيت كل 2500 كم، جنزير، فرامل، بوجيه... وتقدر تعدله بعدين'),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
