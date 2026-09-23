import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// طبقة قاعدة البيانات المحلية (SQLite على الموبايل)
class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'garage_log.db'),
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE vehicles(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT, name TEXT, brand TEXT, model TEXT, year INTEGER,
            plate TEXT, color TEXT, fuel_type TEXT, odometer INTEGER,
            license_expiry INTEGER, insurance_expiry INTEGER,
            notes TEXT, created_at INTEGER)''');
        await db.execute('''
          CREATE TABLE services(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            vehicle_id INTEGER REFERENCES vehicles(id) ON DELETE CASCADE,
            date INTEGER, odometer INTEGER, types TEXT, title TEXT,
            parts_cost REAL, labor_cost REAL, workshop TEXT, notes TEXT)''');
        await db.execute('''
          CREATE TABLE plans(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            vehicle_id INTEGER REFERENCES vehicles(id) ON DELETE CASCADE,
            type_key TEXT, name TEXT, interval_km INTEGER,
            interval_months INTEGER, base_date INTEGER, base_km INTEGER,
            enabled INTEGER)''');
        await db.execute('''
          CREATE TABLE fuel(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            vehicle_id INTEGER REFERENCES vehicles(id) ON DELETE CASCADE,
            date INTEGER, odometer INTEGER, liters REAL, cost REAL,
            full_tank INTEGER, station TEXT, notes TEXT)''');
        await db.execute('''
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            vehicle_id INTEGER REFERENCES vehicles(id) ON DELETE CASCADE,
            date INTEGER, category TEXT, amount REAL, notes TEXT)''');
        await db.execute(
            'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');
      },
    );
  }

  static const tables = ['vehicles', 'services', 'plans', 'fuel', 'expenses'];

  Future<List<Map<String, Object?>>> all(String table,
      {String orderBy = 'id'}) async {
    final d = await db;
    return d.query(table, orderBy: orderBy);
  }

  /// إضافة أو تعديل. بيرجع الـ id
  Future<int> save(String table, Map<String, Object?> map) async {
    final d = await db;
    final id = map['id'];
    if (id == null) {
      final m = Map<String, Object?>.from(map)..remove('id');
      return d.insert(table, m);
    }
    await d.update(table, map, where: 'id = ?', whereArgs: [id]);
    return id as int;
  }

  Future<void> delete(String table, int id) async {
    final d = await db;
    await d.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, String>> settings() async {
    final d = await db;
    final rows = await d.query('settings');
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  Future<void> setSetting(String key, String value) async {
    final d = await db;
    await d.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ------------------------------------------------------------------ backup
  Future<Map<String, Object?>> exportAll() async {
    final out = <String, Object?>{
      'app': 'garage_log',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
    };
    for (final t in tables) {
      out[t] = await all(t);
    }
    out['settings'] = await settings();
    return out;
  }

  /// بيمسح البيانات الحالية ويحط النسخة الاحتياطية مكانها
  Future<void> importAll(Map<String, dynamic> data) async {
    if (data['app'] != 'garage_log') {
      throw const FormatException('الملف ده مش نسخة احتياطية من صيانتي');
    }
    final d = await db;
    await d.transaction((txn) async {
      for (final t in tables.reversed) {
        await txn.delete(t);
      }
      for (final t in tables) {
        final rows = (data[t] as List?) ?? const [];
        for (final r in rows) {
          await txn.insert(t, Map<String, Object?>.from(r as Map));
        }
      }
      final s = data['settings'];
      if (s is Map) {
        await txn.delete('settings');
        for (final e in s.entries) {
          await txn.insert('settings', {'key': '${e.key}', 'value': '${e.value}'});
        }
      }
    });
  }

  Future<void> wipe() async {
    final d = await db;
    await d.transaction((txn) async {
      for (final t in tables.reversed) {
        await txn.delete(t);
      }
    });
  }

  // helpers typed
  Future<List<Vehicle>> vehicles() async =>
      (await all('vehicles')).map(Vehicle.fromMap).toList();
  Future<List<ServiceRecord>> services() async =>
      (await all('services', orderBy: 'date DESC'))
          .map(ServiceRecord.fromMap)
          .toList();
  Future<List<MaintenancePlan>> plans() async =>
      (await all('plans')).map(MaintenancePlan.fromMap).toList();
  Future<List<FuelLog>> fuel() async =>
      (await all('fuel', orderBy: 'date DESC')).map(FuelLog.fromMap).toList();
  Future<List<Expense>> expenses() async =>
      (await all('expenses', orderBy: 'date DESC'))
          .map(Expense.fromMap)
          .toList();
}
