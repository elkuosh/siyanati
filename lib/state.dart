import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'db.dart';
import 'models.dart';
import 'notifications.dart';
import 'utils.dart';

enum DueLevel { overdue, soon, ok, unknown }

/// حالة بند صيانة دورية محسوبة
class PlanStatus {
  final MaintenancePlan plan;
  final Vehicle vehicle;
  final DateTime? lastDate;
  final int? lastKm;
  final DateTime? dueDate;
  final int? dueKm;
  final int? remainingKm;
  final int? remainingDays;
  final DueLevel level;

  PlanStatus({
    required this.plan,
    required this.vehicle,
    this.lastDate,
    this.lastKm,
    this.dueDate,
    this.dueKm,
    this.remainingKm,
    this.remainingDays,
    required this.level,
  });

  /// رقم للترتيب: الأقل = الأكثر استعجالاً
  double get urgency {
    if (level == DueLevel.unknown) return 1e9;
    double score = 1e8;
    if (remainingDays != null) score = math.min(score, remainingDays!.toDouble());
    if (remainingKm != null) {
      // نحول الكيلومترات لأيام تقريبية (40 كم/يوم عربية، 25 موتوسيكل)
      final perDay = vehicle.type == VehicleType.car ? 40 : 25;
      score = math.min(score, remainingKm! / perDay);
    }
    return score;
  }

  String get summary {
    if (level == DueLevel.unknown) return 'سجّل آخر مرة اتعملت عشان نحسب الميعاد';
    final parts = <String>[];
    if (remainingKm != null) {
      parts.add(remainingKm! <= 0
          ? 'متأخر ${fmtInt(-remainingKm!)} كم'
          : 'باقي ${fmtInt(remainingKm!)} كم');
    }
    if (remainingDays != null) {
      parts.add(remainingDays! <= 0
          ? (remainingDays == 0 ? 'النهارده' : 'متأخر ${-remainingDays!} يوم')
          : 'باقي ${daysText(remainingDays!)}');
    }
    return parts.join(' • ');
  }
}

/// ميعاد (ترخيص / تأمين)
class DocDue {
  final Vehicle vehicle;
  final String label;
  final DateTime date;
  DocDue(this.vehicle, this.label, this.date);
  int get remainingDays => daysBetween(today(), date);
  DueLevel level(int soonDays) => remainingDays < 0
      ? DueLevel.overdue
      : (remainingDays <= math.max(soonDays, 30) ? DueLevel.soon : DueLevel.ok);
}

class AppSettings {
  bool notifications;
  int reminderHour;
  int daysBefore;
  int soonDays;
  int soonKmCar;
  int soonKmMoto;
  String currency;
  ThemeMode themeMode;

  AppSettings({
    this.notifications = true,
    this.reminderHour = 10,
    this.daysBefore = 7,
    this.soonDays = 14,
    this.soonKmCar = 500,
    this.soonKmMoto = 200,
    this.currency = 'ج.م',
    this.themeMode = ThemeMode.system,
  });

  factory AppSettings.fromMap(Map<String, String> m) => AppSettings(
        notifications: m['notifications'] != '0',
        reminderHour: int.tryParse(m['reminderHour'] ?? '') ?? 10,
        daysBefore: int.tryParse(m['daysBefore'] ?? '') ?? 7,
        soonDays: int.tryParse(m['soonDays'] ?? '') ?? 14,
        soonKmCar: int.tryParse(m['soonKmCar'] ?? '') ?? 500,
        soonKmMoto: int.tryParse(m['soonKmMoto'] ?? '') ?? 200,
        currency: m['currency'] ?? 'ج.م',
        themeMode: switch (m['theme']) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
      );

  Map<String, String> toMap() => {
        'notifications': notifications ? '1' : '0',
        'reminderHour': '$reminderHour',
        'daysBefore': '$daysBefore',
        'soonDays': '$soonDays',
        'soonKmCar': '$soonKmCar',
        'soonKmMoto': '$soonKmMoto',
        'currency': currency,
        'theme': switch (themeMode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          _ => 'system',
        },
      };
}

/// الحالة العامة للتطبيق — بتحمّل كل البيانات في الذاكرة
class AppData extends ChangeNotifier {
  AppData._();
  static final AppData instance = AppData._();

  final _db = AppDb.instance;

  bool loaded = false;
  List<Vehicle> vehicles = [];
  List<ServiceRecord> services = [];
  List<MaintenancePlan> plans = [];
  List<FuelLog> fuel = [];
  List<Expense> expenses = [];
  AppSettings settings = AppSettings();

  Future<void> load() async {
    vehicles = await _db.vehicles();
    services = await _db.services();
    plans = await _db.plans();
    fuel = await _db.fuel();
    expenses = await _db.expenses();
    settings = AppSettings.fromMap(await _db.settings());
    loaded = true;
    notifyListeners();
    _rescheduleNotifications();
  }

  String get cur => settings.currency;

  Vehicle? vehicleById(int id) {
    for (final v in vehicles) {
      if (v.id == id) return v;
    }
    return null;
  }

  // ------------------------------------------------------------ CRUD
  Future<int> saveVehicle(Vehicle v, {bool addDefaultPlans = false}) async {
    final isNew = v.id == null;
    final id = await _db.save('vehicles', v.toMap());
    v.id = id;
    if (isNew && addDefaultPlans) {
      for (final t in ServiceCatalog.forType(v.type)) {
        if (!t.hasDefault(v.type)) continue;
        await _db.save(
          'plans',
          MaintenancePlan(
            vehicleId: id,
            typeKey: t.key,
            name: t.label,
            intervalKm: t.defaultKm(v.type),
            intervalMonths: t.defaultMonths(v.type),
          ).toMap(),
        );
      }
    }
    await load();
    return id;
  }

  Future<void> deleteVehicle(int id) async {
    await _db.delete('vehicles', id);
    await load();
  }

  Future<void> saveService(ServiceRecord r) async {
    await _db.save('services', r.toMap());
    await _bumpOdometer(r.vehicleId, r.odometer);
    await load();
  }

  Future<void> deleteService(int id) async {
    await _db.delete('services', id);
    await load();
  }

  Future<void> savePlan(MaintenancePlan p) async {
    await _db.save('plans', p.toMap());
    await load();
  }

  Future<void> deletePlan(int id) async {
    await _db.delete('plans', id);
    await load();
  }

  Future<void> saveFuel(FuelLog f) async {
    await _db.save('fuel', f.toMap());
    await _bumpOdometer(f.vehicleId, f.odometer);
    await load();
  }

  Future<void> deleteFuel(int id) async {
    await _db.delete('fuel', id);
    await load();
  }

  Future<void> saveExpense(Expense e) async {
    await _db.save('expenses', e.toMap());
    await load();
  }

  Future<void> deleteExpense(int id) async {
    await _db.delete('expenses', id);
    await load();
  }

  Future<void> updateOdometer(int vehicleId, int km) async {
    final v = vehicleById(vehicleId);
    if (v == null) return;
    v.odometer = km;
    await _db.save('vehicles', v.toMap());
    await load();
  }

  Future<void> _bumpOdometer(int vehicleId, int? km) async {
    if (km == null) return;
    final v = vehicleById(vehicleId);
    if (v == null || km <= v.odometer) return;
    v.odometer = km;
    await _db.save('vehicles', v.toMap());
  }

  Future<void> saveSettings(AppSettings s) async {
    for (final e in s.toMap().entries) {
      await _db.setSetting(e.key, e.value);
    }
    await load();
  }

  Future<Map<String, Object?>> exportAll() => _db.exportAll();

  Future<void> importAll(Map<String, dynamic> data) async {
    await _db.importAll(data);
    await load();
  }

  Future<void> wipe() async {
    await _db.wipe();
    await load();
  }

  // ------------------------------------------------------------ computed
  List<ServiceRecord> servicesOf(int vehicleId) =>
      services.where((s) => s.vehicleId == vehicleId).toList();
  List<MaintenancePlan> plansOf(int vehicleId) =>
      plans.where((p) => p.vehicleId == vehicleId).toList();
  List<FuelLog> fuelOf(int vehicleId) =>
      fuel.where((f) => f.vehicleId == vehicleId).toList();
  List<Expense> expensesOf(int vehicleId) =>
      expenses.where((e) => e.vehicleId == vehicleId).toList();

  /// أعلى عداد متسجل للمركبة
  int odometerOf(Vehicle v) {
    var km = v.odometer;
    for (final s in services) {
      if (s.vehicleId == v.id && (s.odometer ?? 0) > km) km = s.odometer!;
    }
    for (final f in fuel) {
      if (f.vehicleId == v.id && (f.odometer ?? 0) > km) km = f.odometer!;
    }
    return km;
  }

  PlanStatus planStatus(MaintenancePlan p) {
    final v = vehicleById(p.vehicleId)!;
    DateTime? lastDate = p.baseDate;
    int? lastKm = p.baseKm;
    // آخر زيارة فيها النوع ده (الخدمات مترتبة من الأحدث)
    for (final s in services) {
      if (s.vehicleId != p.vehicleId || !s.types.contains(p.typeKey)) continue;
      if (lastDate == null || !s.date.isBefore(lastDate)) {
        lastDate = s.date;
        lastKm = s.odometer ?? lastKm;
      }
      break;
    }

    DateTime? dueDate;
    int? dueKm, remKm, remDays;
    if (p.intervalMonths != null && lastDate != null) {
      dueDate = addMonths(lastDate, p.intervalMonths!);
      remDays = daysBetween(today(), dueDate);
    }
    if (p.intervalKm != null && lastKm != null) {
      dueKm = lastKm + p.intervalKm!;
      remKm = dueKm - odometerOf(v);
    }

    DueLevel level;
    if (remKm == null && remDays == null) {
      level = DueLevel.unknown;
    } else if ((remKm != null && remKm <= 0) ||
        (remDays != null && remDays <= 0)) {
      level = DueLevel.overdue;
    } else {
      final soonKm = v.type == VehicleType.car
          ? settings.soonKmCar
          : settings.soonKmMoto;
      final kmThreshold = p.intervalKm == null
          ? soonKm
          : math.max(soonKm, (p.intervalKm! * 0.1).round());
      if ((remKm != null && remKm <= kmThreshold) ||
          (remDays != null && remDays <= settings.soonDays)) {
        level = DueLevel.soon;
      } else {
        level = DueLevel.ok;
      }
    }

    return PlanStatus(
      plan: p,
      vehicle: v,
      lastDate: lastDate,
      lastKm: lastKm,
      dueDate: dueDate,
      dueKm: dueKm,
      remainingKm: remKm,
      remainingDays: remDays,
      level: level,
    );
  }

  List<PlanStatus> statusesOf(int vehicleId) {
    final l = plansOf(vehicleId)
        .where((p) => p.enabled)
        .map(planStatus)
        .toList()
      ..sort((a, b) => a.urgency.compareTo(b.urgency));
    return l;
  }

  List<PlanStatus> allStatuses() {
    final l = plans
        .where((p) => p.enabled && vehicleById(p.vehicleId) != null)
        .map(planStatus)
        .toList()
      ..sort((a, b) => a.urgency.compareTo(b.urgency));
    return l;
  }

  List<DocDue> docDues({int? vehicleId}) {
    final l = <DocDue>[];
    for (final v in vehicles) {
      if (vehicleId != null && v.id != vehicleId) continue;
      if (v.licenseExpiry != null) l.add(DocDue(v, 'تجديد الرخصة', v.licenseExpiry!));
      if (v.insuranceExpiry != null) {
        l.add(DocDue(v, 'تجديد التأمين', v.insuranceExpiry!));
      }
    }
    l.sort((a, b) => a.date.compareTo(b.date));
    return l;
  }

  // ------------------------------------------------------------ costs
  double serviceTotal({int? vehicleId, DateTime? from, DateTime? to}) =>
      _sum(services, (s) => s.total, (s) => s.vehicleId, (s) => s.date,
          vehicleId, from, to);
  double fuelTotal({int? vehicleId, DateTime? from, DateTime? to}) =>
      _sum(fuel, (f) => f.cost, (f) => f.vehicleId, (f) => f.date, vehicleId,
          from, to);
  double expenseTotal({int? vehicleId, DateTime? from, DateTime? to}) =>
      _sum(expenses, (e) => e.amount, (e) => e.vehicleId, (e) => e.date,
          vehicleId, from, to);
  double grandTotal({int? vehicleId, DateTime? from, DateTime? to}) =>
      serviceTotal(vehicleId: vehicleId, from: from, to: to) +
      fuelTotal(vehicleId: vehicleId, from: from, to: to) +
      expenseTotal(vehicleId: vehicleId, from: from, to: to);

  double _sum<T>(
    List<T> list,
    double Function(T) amount,
    int Function(T) vid,
    DateTime Function(T) date,
    int? vehicleId,
    DateTime? from,
    DateTime? to,
  ) {
    var total = 0.0;
    for (final x in list) {
      if (vehicleId != null && vid(x) != vehicleId) continue;
      final d = date(x);
      if (from != null && d.isBefore(from)) continue;
      if (to != null && !d.isBefore(to)) continue;
      total += amount(x);
    }
    return total;
  }

  /// متوسط الاستهلاك (كم/لتر) من التفويلات الـ "فل"
  double? avgConsumption(int vehicleId) {
    final logs = fuelOf(vehicleId).where((f) => f.odometer != null).toList()
      ..sort((a, b) => a.odometer!.compareTo(b.odometer!));
    // نحسب من أول تفويلة فل لآخر تفويلة فل
    int? firstIdx, lastIdx;
    for (var i = 0; i < logs.length; i++) {
      if (!logs[i].fullTank) continue;
      firstIdx ??= i;
      lastIdx = i;
    }
    if (firstIdx == null || lastIdx == null || lastIdx == firstIdx) return null;
    final km = logs[lastIdx].odometer! - logs[firstIdx].odometer!;
    var liters = 0.0;
    for (var i = firstIdx + 1; i <= lastIdx; i++) {
      liters += logs[i].liters;
    }
    if (km <= 0 || liters <= 0) return null;
    return km / liters;
  }

  /// التكلفة لكل كيلو (كل المصاريف ÷ المسافة المتسجلة)
  double? costPerKm(int vehicleId) {
    final kms = <int>[
      ...servicesOf(vehicleId).map((s) => s.odometer).whereType<int>(),
      ...fuelOf(vehicleId).map((f) => f.odometer).whereType<int>(),
    ];
    if (kms.length < 2) return null;
    final dist = kms.reduce(math.max) - kms.reduce(math.min);
    if (dist <= 0) return null;
    return grandTotal(vehicleId: vehicleId) / dist;
  }

  // ------------------------------------------------------------ notifications
  void _rescheduleNotifications() {
    if (!settings.notifications) {
      Notifier.instance.reschedule(const []);
      return;
    }
    final items = <ScheduledReminder>[];
    var id = 1;
    DateTime at(DateTime d) =>
        DateTime(d.year, d.month, d.day, settings.reminderHour);

    void add(String title, String body, DateTime due) {
      if (settings.daysBefore > 0) {
        items.add(ScheduledReminder(
            id++,
            title,
            'باقي ${daysText(settings.daysBefore)}: $body',
            at(due.subtract(Duration(days: settings.daysBefore)))));
      }
      items.add(ScheduledReminder(id++, title, 'النهارده ميعاد: $body', at(due)));
    }

    for (final s in allStatuses()) {
      if (s.dueDate == null) continue;
      add(s.vehicle.displayName, s.plan.name, s.dueDate!);
    }
    for (final d in docDues()) {
      add(d.vehicle.displayName, d.label, d.date);
    }
    Notifier.instance.reschedule(items);
  }
}
