import 'package:flutter/material.dart';

/// نوع المركبة
enum VehicleType { car, moto }

VehicleType vehicleTypeFrom(String? s) =>
    s == 'moto' ? VehicleType.moto : VehicleType.car;

String vehicleTypeKey(VehicleType t) => t == VehicleType.moto ? 'moto' : 'car';

String vehicleTypeLabel(VehicleType t) =>
    t == VehicleType.moto ? 'موتوسيكل' : 'عربية';

IconData vehicleTypeIcon(VehicleType t) =>
    t == VehicleType.moto ? Icons.two_wheeler : Icons.directions_car;

int? _toInt(Object? v) => v == null ? null : (v as num).toInt();
double _toDouble(Object? v) => v == null ? 0 : (v as num).toDouble();
DateTime? _toDate(Object? v) =>
    v == null ? null : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());
int? _fromDate(DateTime? d) => d?.millisecondsSinceEpoch;

// ---------------------------------------------------------------------------
// المركبة
// ---------------------------------------------------------------------------
class Vehicle {
  int? id;
  VehicleType type;
  String name;
  String brand;
  String model;
  int? year;
  String plate;
  String color;
  String fuelType;
  int odometer;
  DateTime? licenseExpiry;
  DateTime? insuranceExpiry;
  String notes;
  DateTime createdAt;

  Vehicle({
    this.id,
    this.type = VehicleType.car,
    this.name = '',
    this.brand = '',
    this.model = '',
    this.year,
    this.plate = '',
    this.color = '',
    this.fuelType = 'بنزين 92',
    this.odometer = 0,
    this.licenseExpiry,
    this.insuranceExpiry,
    this.notes = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    final s = '$brand $model'.trim();
    return s.isEmpty ? vehicleTypeLabel(type) : s;
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'type': vehicleTypeKey(type),
        'name': name,
        'brand': brand,
        'model': model,
        'year': year,
        'plate': plate,
        'color': color,
        'fuel_type': fuelType,
        'odometer': odometer,
        'license_expiry': _fromDate(licenseExpiry),
        'insurance_expiry': _fromDate(insuranceExpiry),
        'notes': notes,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Vehicle.fromMap(Map<String, Object?> m) => Vehicle(
        id: _toInt(m['id']),
        type: vehicleTypeFrom(m['type'] as String?),
        name: (m['name'] as String?) ?? '',
        brand: (m['brand'] as String?) ?? '',
        model: (m['model'] as String?) ?? '',
        year: _toInt(m['year']),
        plate: (m['plate'] as String?) ?? '',
        color: (m['color'] as String?) ?? '',
        fuelType: (m['fuel_type'] as String?) ?? '',
        odometer: _toInt(m['odometer']) ?? 0,
        licenseExpiry: _toDate(m['license_expiry']),
        insuranceExpiry: _toDate(m['insurance_expiry']),
        notes: (m['notes'] as String?) ?? '',
        createdAt: _toDate(m['created_at']) ?? DateTime.now(),
      );
}

// ---------------------------------------------------------------------------
// زيارة صيانة
// ---------------------------------------------------------------------------
class ServiceRecord {
  int? id;
  int vehicleId;
  DateTime date;
  int? odometer;
  List<String> types; // مفاتيح من ServiceCatalog
  String title;
  double partsCost;
  double laborCost;
  String workshop;
  String notes;

  ServiceRecord({
    this.id,
    required this.vehicleId,
    required this.date,
    this.odometer,
    List<String>? types,
    this.title = '',
    this.partsCost = 0,
    this.laborCost = 0,
    this.workshop = '',
    this.notes = '',
  }) : types = types ?? [];

  double get total => partsCost + laborCost;

  Map<String, Object?> toMap() => {
        'id': id,
        'vehicle_id': vehicleId,
        'date': date.millisecondsSinceEpoch,
        'odometer': odometer,
        'types': types.join(','),
        'title': title,
        'parts_cost': partsCost,
        'labor_cost': laborCost,
        'workshop': workshop,
        'notes': notes,
      };

  factory ServiceRecord.fromMap(Map<String, Object?> m) => ServiceRecord(
        id: _toInt(m['id']),
        vehicleId: _toInt(m['vehicle_id'])!,
        date: _toDate(m['date'])!,
        odometer: _toInt(m['odometer']),
        types: ((m['types'] as String?) ?? '')
            .split(',')
            .where((e) => e.isNotEmpty)
            .toList(),
        title: (m['title'] as String?) ?? '',
        partsCost: _toDouble(m['parts_cost']),
        laborCost: _toDouble(m['labor_cost']),
        workshop: (m['workshop'] as String?) ?? '',
        notes: (m['notes'] as String?) ?? '',
      );
}

// ---------------------------------------------------------------------------
// جدول صيانة دورية (كل كام كيلو / كل كام شهر)
// ---------------------------------------------------------------------------
class MaintenancePlan {
  int? id;
  int vehicleId;
  String typeKey;
  String name;
  int? intervalKm;
  int? intervalMonths;
  DateTime? baseDate; // آخر مرة اتعملت (يدوي) قبل ما تبدأ تسجل
  int? baseKm;
  bool enabled;

  MaintenancePlan({
    this.id,
    required this.vehicleId,
    required this.typeKey,
    required this.name,
    this.intervalKm,
    this.intervalMonths,
    this.baseDate,
    this.baseKm,
    this.enabled = true,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'vehicle_id': vehicleId,
        'type_key': typeKey,
        'name': name,
        'interval_km': intervalKm,
        'interval_months': intervalMonths,
        'base_date': _fromDate(baseDate),
        'base_km': baseKm,
        'enabled': enabled ? 1 : 0,
      };

  factory MaintenancePlan.fromMap(Map<String, Object?> m) => MaintenancePlan(
        id: _toInt(m['id']),
        vehicleId: _toInt(m['vehicle_id'])!,
        typeKey: (m['type_key'] as String?) ?? 'other',
        name: (m['name'] as String?) ?? '',
        intervalKm: _toInt(m['interval_km']),
        intervalMonths: _toInt(m['interval_months']),
        baseDate: _toDate(m['base_date']),
        baseKm: _toInt(m['base_km']),
        enabled: (_toInt(m['enabled']) ?? 1) == 1,
      );
}

// ---------------------------------------------------------------------------
// تفويل بنزين
// ---------------------------------------------------------------------------
class FuelLog {
  int? id;
  int vehicleId;
  DateTime date;
  int? odometer;
  double liters;
  double cost;
  bool fullTank;
  String station;
  String notes;

  FuelLog({
    this.id,
    required this.vehicleId,
    required this.date,
    this.odometer,
    this.liters = 0,
    this.cost = 0,
    this.fullTank = true,
    this.station = '',
    this.notes = '',
  });

  double get pricePerLiter => liters > 0 ? cost / liters : 0;

  Map<String, Object?> toMap() => {
        'id': id,
        'vehicle_id': vehicleId,
        'date': date.millisecondsSinceEpoch,
        'odometer': odometer,
        'liters': liters,
        'cost': cost,
        'full_tank': fullTank ? 1 : 0,
        'station': station,
        'notes': notes,
      };

  factory FuelLog.fromMap(Map<String, Object?> m) => FuelLog(
        id: _toInt(m['id']),
        vehicleId: _toInt(m['vehicle_id'])!,
        date: _toDate(m['date'])!,
        odometer: _toInt(m['odometer']),
        liters: _toDouble(m['liters']),
        cost: _toDouble(m['cost']),
        fullTank: (_toInt(m['full_tank']) ?? 1) == 1,
        station: (m['station'] as String?) ?? '',
        notes: (m['notes'] as String?) ?? '',
      );
}

// ---------------------------------------------------------------------------
// مصاريف تانية (ترخيص، تأمين، مخالفات، غسيل...)
// ---------------------------------------------------------------------------
class Expense {
  int? id;
  int vehicleId;
  DateTime date;
  String category;
  double amount;
  String notes;

  Expense({
    this.id,
    required this.vehicleId,
    required this.date,
    this.category = 'other',
    this.amount = 0,
    this.notes = '',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'vehicle_id': vehicleId,
        'date': date.millisecondsSinceEpoch,
        'category': category,
        'amount': amount,
        'notes': notes,
      };

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
        id: _toInt(m['id']),
        vehicleId: _toInt(m['vehicle_id'])!,
        date: _toDate(m['date'])!,
        category: (m['category'] as String?) ?? 'other',
        amount: _toDouble(m['amount']),
        notes: (m['notes'] as String?) ?? '',
      );
}

// ---------------------------------------------------------------------------
// كتالوج أنواع الصيانة
// ---------------------------------------------------------------------------
class ServiceType {
  final String key;
  final String label;
  final IconData icon;
  final int? carKm;
  final int? carMonths;
  final int? motoKm;
  final int? motoMonths;
  final bool forCar;
  final bool forMoto;

  const ServiceType(
    this.key,
    this.label,
    this.icon, {
    this.carKm,
    this.carMonths,
    this.motoKm,
    this.motoMonths,
    this.forCar = true,
    this.forMoto = true,
  });

  bool appliesTo(VehicleType t) => t == VehicleType.car ? forCar : forMoto;
  int? defaultKm(VehicleType t) => t == VehicleType.car ? carKm : motoKm;
  int? defaultMonths(VehicleType t) =>
      t == VehicleType.car ? carMonths : motoMonths;
  bool hasDefault(VehicleType t) =>
      appliesTo(t) && (defaultKm(t) != null || defaultMonths(t) != null);
}

class ServiceCatalog {
  static const List<ServiceType> all = [
    ServiceType('oil', 'تغيير زيت الموتور', Icons.oil_barrel,
        carKm: 5000, carMonths: 6, motoKm: 2500, motoMonths: 3),
    ServiceType('oil_filter', 'فلتر زيت', Icons.filter_alt,
        carKm: 10000, carMonths: 12, motoKm: 5000, motoMonths: 6),
    ServiceType('air_filter', 'فلتر هوا', Icons.air,
        carKm: 15000, carMonths: 12, motoKm: 6000, motoMonths: 12),
    ServiceType('ac_filter', 'فلتر تكييف', Icons.ac_unit,
        carKm: 15000, carMonths: 12, forMoto: false),
    ServiceType('fuel_filter', 'فلتر بنزين', Icons.local_gas_station,
        carKm: 40000, carMonths: 24, motoKm: 12000),
    ServiceType('spark_plugs', 'بوجيهات', Icons.bolt,
        carKm: 40000, carMonths: 24, motoKm: 8000, motoMonths: 12),
    ServiceType('brakes', 'فرامل (تيل/طنابير)', Icons.album,
        carKm: 20000, carMonths: 12, motoKm: 6000, motoMonths: 6),
    ServiceType('brake_fluid', 'زيت فرامل', Icons.water_drop,
        carMonths: 24, motoMonths: 24),
    ServiceType('coolant', 'مياه الردياتير', Icons.thermostat,
        carKm: 40000, carMonths: 24, motoMonths: 24),
    ServiceType('gear_oil', 'زيت فتيس', Icons.settings,
        carKm: 60000, carMonths: 48),
    ServiceType('timing_belt', 'سير كاتينة', Icons.link,
        carKm: 60000, carMonths: 48, forMoto: false),
    ServiceType('belts', 'سيور', Icons.linear_scale,
        carKm: 40000, carMonths: 24, forMoto: false),
    ServiceType('tires', 'كاوتش', Icons.tire_repair,
        carKm: 50000, carMonths: 48, motoKm: 15000, motoMonths: 36),
    ServiceType('tire_rotation', 'تبديل الكاوتش', Icons.sync,
        carKm: 10000, forMoto: false),
    ServiceType('alignment', 'ترصيص وضبط زوايا', Icons.straighten,
        carKm: 10000, carMonths: 12, forMoto: false),
    ServiceType('battery', 'بطارية', Icons.battery_charging_full,
        carMonths: 24, motoMonths: 24),
    ServiceType('chain', 'تشحيم وشد الجنزير', Icons.all_inclusive,
        motoKm: 700, motoMonths: 1, forCar: false),
    ServiceType('chain_kit', 'طقم جنزير وترس', Icons.settings_input_component,
        motoKm: 20000, forCar: false),
    ServiceType('valves', 'ضبط بلوف', Icons.tune,
        motoKm: 12000, forCar: false),
    ServiceType('clutch', 'دبرياج', Icons.swap_horiz),
    ServiceType('suspension', 'عفشة ومساعدين', Icons.car_repair),
    ServiceType('ac', 'تكييف (شحن فريون)', Icons.mode_fan_off, forMoto: false),
    ServiceType('electric', 'كهربا', Icons.electrical_services),
    ServiceType('body', 'سمكرة ودهان', Icons.format_paint),
    ServiceType('inspection', 'كشف عام', Icons.fact_check,
        carMonths: 12, motoMonths: 12),
    ServiceType('other', 'أخرى', Icons.build),
  ];

  static ServiceType byKey(String key) =>
      all.firstWhere((e) => e.key == key, orElse: () => all.last);

  static List<ServiceType> forType(VehicleType t) =>
      all.where((e) => e.appliesTo(t)).toList();
}

class ExpenseCategory {
  final String key;
  final String label;
  final IconData icon;
  const ExpenseCategory(this.key, this.label, this.icon);

  static const List<ExpenseCategory> all = [
    ExpenseCategory('license', 'ترخيص', Icons.badge),
    ExpenseCategory('insurance', 'تأمين', Icons.shield),
    ExpenseCategory('fines', 'مخالفات', Icons.gavel),
    ExpenseCategory('wash', 'غسيل', Icons.local_car_wash),
    ExpenseCategory('parking', 'جراج / ركنة', Icons.local_parking),
    ExpenseCategory('tolls', 'كارتة / رسوم طرق', Icons.toll),
    ExpenseCategory('accessories', 'إكسسوارات', Icons.shopping_bag),
    ExpenseCategory('installment', 'قسط', Icons.account_balance),
    ExpenseCategory('other', 'أخرى', Icons.receipt_long),
  ];

  static ExpenseCategory byKey(String key) =>
      all.firstWhere((e) => e.key == key, orElse: () => all.last);
}

const List<String> fuelTypes = [
  'بنزين 80',
  'بنزين 92',
  'بنزين 95',
  'سولار',
  'غاز طبيعي',
  'كهربا',
  'هايبرد',
];
