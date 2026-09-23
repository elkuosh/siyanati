import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _intFmt = NumberFormat('#,##0', 'en');
final _moneyFmt = NumberFormat('#,##0.##', 'en');
final _dateFmt = DateFormat('d MMM yyyy', 'ar');
final _monthFmt = DateFormat('MMM yy', 'ar');

String fmtInt(num n) => _intFmt.format(n);
String fmtMoney(num n, [String cur = 'ج.م']) => '${_moneyFmt.format(n)} $cur';
String fmtNum(num n) => _moneyFmt.format(n);
String fmtDate(DateTime? d) => d == null ? '—' : _dateFmt.format(d);
String fmtMonth(DateTime d) => _monthFmt.format(d);

DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int daysBetween(DateTime from, DateTime to) =>
    (dateOnly(to).difference(dateOnly(from)).inHours / 24).round();

DateTime addMonths(DateTime d, int months) {
  final m = d.month - 1 + months;
  final y = d.year + (m ~/ 12);
  final mm = m % 12 + 1;
  final lastDay = DateTime(y, mm + 1, 0).day;
  return DateTime(y, mm, d.day > lastDay ? lastDay : d.day);
}

String daysText(int days) {
  if (days == 1) return 'يوم';
  if (days == 2) return 'يومين';
  if (days >= 3 && days <= 10) return '$days أيام';
  if (days < 60) return '$days يوم';
  final months = (days / 30).round();
  if (months < 24) return months == 2 ? 'شهرين' : '$months شهر';
  return '${(days / 365).toStringAsFixed(1)} سنة';
}

/// بيقبل الأرقام العربي والإنجليزي والفواصل
String normalizeDigits(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = ar.indexOf(ch);
    final j = fa.indexOf(ch);
    if (i >= 0) {
      b.write(i);
    } else if (j >= 0) {
      b.write(j);
    } else if (ch == '٫') {
      b.write('.');
    } else if (ch == ',' || ch == '٬' || ch == ' ') {
      // تجاهل
    } else {
      b.write(ch);
    }
  }
  return b.toString();
}

int? parseInt(String s) {
  final t = normalizeDigits(s.trim());
  if (t.isEmpty) return null;
  return int.tryParse(t) ?? double.tryParse(t)?.round();
}

double? parseDouble(String s) {
  final t = normalizeDigits(s.trim());
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

String numText(num? n) {
  if (n == null) return '';
  if (n is double && n == n.roundToDouble()) return n.toInt().toString();
  return n.toString();
}

void showSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Future<bool> confirmDialog(BuildContext context, String title,
    {String? message, String ok = 'مسح'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
        FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}
