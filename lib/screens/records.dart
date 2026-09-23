import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../utils.dart';
import '../widgets.dart';
import 'tiles.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _Entry {
  final DateTime date;
  final double amount;
  final Widget tile;
  _Entry(this.date, this.amount, this.tile);
}

class _RecordsScreenState extends State<RecordsScreen> {
  int? _vehicle; // null = الكل
  String _kind = 'all'; // all | service | fuel | expense
  String _query = '';
  bool _searching = false;

  @override
  Widget build(BuildContext context) {
    final app = AppData.instance;
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'دوّر (ورشة، نوع، ملاحظة...)',
                    border: InputBorder.none,
                    filled: false),
                onChanged: (s) => setState(() => _query = s.trim()),
              )
            : const Text('السجل'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              _query = '';
            }),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final entries = <_Entry>[];
          bool vOk(int id) => _vehicle == null || _vehicle == id;
          bool q(String text) => _query.isEmpty || text.contains(_query);

          if (_kind == 'all' || _kind == 'service') {
            for (final s in app.services) {
              if (!vOk(s.vehicleId)) continue;
              if (!q('${serviceTitle(s)} ${s.title} ${s.workshop} ${s.notes}')) {
                continue;
              }
              entries.add(_Entry(s.date, s.total,
                  ServiceTile(record: s, showVehicle: _vehicle == null)));
            }
          }
          if (_kind == 'all' || _kind == 'fuel') {
            for (final f in app.fuel) {
              if (!vOk(f.vehicleId)) continue;
              if (!q('بنزين ${f.station} ${f.notes}')) continue;
              entries.add(_Entry(f.date, f.cost,
                  FuelTile(log: f, showVehicle: _vehicle == null)));
            }
          }
          if (_kind == 'all' || _kind == 'expense') {
            for (final e in app.expenses) {
              if (!vOk(e.vehicleId)) continue;
              if (!q('${ExpenseCategory.byKey(e.category).label} ${e.notes}')) continue;
              entries.add(_Entry(e.date, e.amount,
                  ExpenseTile(expense: e, showVehicle: _vehicle == null)));
            }
          }
          entries.sort((a, b) => b.date.compareTo(a.date));

          // تجميع بالشهر
          final children = <Widget>[];
          DateTime? month;
          for (var i = 0; i < entries.length; i++) {
            final e = entries[i];
            final m = DateTime(e.date.year, e.date.month);
            if (month == null || m != month) {
              month = m;
              final total = entries
                  .where((x) =>
                      x.date.year == m.year && x.date.month == m.month)
                  .fold<double>(0, (a, x) => a + x.amount);
              children.add(SectionTitle(
                fmtMonth(m),
                trailing: Text(fmtMoney(total, app.cur),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold)),
              ));
            }
            children.add(e.tile);
          }

          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(children: [
                  for (final k in const [
                    ['all', 'الكل'],
                    ['service', 'صيانات'],
                    ['fuel', 'بنزين'],
                    ['expense', 'مصاريف'],
                  ])
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ChoiceChip(
                        label: Text(k[1]),
                        selected: _kind == k[0],
                        onSelected: (_) => setState(() => _kind = k[0]),
                      ),
                    ),
                  if (app.vehicles.length > 1) ...[
                    const SizedBox(width: 8),
                    DropdownButton<int?>(
                      value: _vehicle,
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('كل المركبات')),
                        for (final v in app.vehicles)
                          DropdownMenuItem<int?>(
                              value: v.id, child: Text(v.displayName)),
                      ],
                      onChanged: (id) => setState(() => _vehicle = id),
                    ),
                  ],
                ]),
              ),
              Expanded(
                child: entries.isEmpty
                    ? const EmptyState(
                        icon: Icons.history, text: 'مفيش حاجة متسجلة هنا')
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: children,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
