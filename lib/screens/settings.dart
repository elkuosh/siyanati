import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../notifications.dart';
import '../state.dart';
import '../utils.dart';
import '../widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final app = AppData.instance;
  late AppSettings s = AppSettings.fromMap(app.settings.toMap());

  Future<void> _update(void Function() change) async {
    setState(change);
    await app.saveSettings(s);
  }

  Future<int?> _pickNumber(String title, int current,
      {String suffix = '', int min = 0, int max = 100000}) async {
    final ctrl = TextEditingController(text: '$current');
    return showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(suffixText: suffix),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final n = parseInt(ctrl.text);
              if (n != null && n >= min && n <= max) Navigator.pop(c, n);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    try {
      final data = await app.exportAll();
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      final file = File(p.join(dir.path, 'siyanati-backup-$stamp.json'));
      await file.writeAsString(const JsonEncoder.withIndent(' ').convert(data));
      await Share.shareXFiles([XFile(file.path)],
          subject: 'نسخة احتياطية - صيانتي', text: 'نسخة احتياطية من صيانتي');
    } catch (e) {
      if (mounted) showSnack(context, 'حصلت مشكلة: $e');
    }
  }

  Future<void> _import() async {
    try {
      final res = await FilePicker.platform.pickFiles(withData: true);
      if (res == null || res.files.isEmpty) return;
      final f = res.files.single;
      final String text;
      if (f.bytes != null) {
        text = utf8.decode(f.bytes!);
      } else if (f.path != null) {
        text = await File(f.path!).readAsString();
      } else {
        return;
      }
      final data = jsonDecode(text) as Map<String, dynamic>;
      if (!mounted) return;
      final ok = await confirmDialog(
        context,
        'استرجاع النسخة الاحتياطية؟',
        message: 'البيانات الحالية هتتمسح وتتبدل بالنسخة دي.',
        ok: 'استرجاع',
      );
      if (!ok) return;
      await app.importAll(data);
      s = AppSettings.fromMap(app.settings.toMap());
      if (mounted) {
        setState(() {});
        showSnack(context, 'تم الاسترجاع ✔');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'الملف مش صالح: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SectionTitle('التنبيهات'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('تنبيهات المواعيد'),
            subtitle: const Text('إشعار قبل الميعاد وفي يومه'),
            value: s.notifications,
            onChanged: (b) async {
              if (b) await Notifier.instance.requestPermission();
              await _update(() => s.notifications = b);
            },
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('ساعة التنبيه'),
            trailing: Text(_hourText(s.reminderHour)),
            enabled: s.notifications,
            onTap: () async {
              final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: s.reminderHour, minute: 0));
              if (t != null) await _update(() => s.reminderHour = t.hour);
            },
          ),
          ListTile(
            leading: const Icon(Icons.event_note_outlined),
            title: const Text('فكّرني قبل الميعاد بـ'),
            trailing: Text('${s.daysBefore} يوم'),
            enabled: s.notifications,
            onTap: () async {
              final n = await _pickNumber('كام يوم قبل الميعاد؟', s.daysBefore,
                  suffix: 'يوم', max: 90);
              if (n != null) await _update(() => s.daysBefore = n);
            },
          ),
          ListTile(
            leading: const Icon(Icons.notification_add_outlined),
            title: const Text('جرّب إشعار'),
            onTap: () async {
              await Notifier.instance.requestPermission();
              await Notifier.instance
                  .showNow('صيانتي', 'الإشعارات شغالة تمام ✔');
            },
          ),
          const SectionTitle('إمتى أعتبر الميعاد "قرّب"'),
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('باقي أيام أقل من'),
            trailing: Text('${s.soonDays} يوم'),
            onTap: () async {
              final n = await _pickNumber('عدد الأيام', s.soonDays,
                  suffix: 'يوم', min: 1, max: 180);
              if (n != null) await _update(() => s.soonDays = n);
            },
          ),
          ListTile(
            leading: const Icon(Icons.directions_car_outlined),
            title: const Text('العربيات: باقي كيلومترات أقل من'),
            trailing: Text('${fmtInt(s.soonKmCar)} كم'),
            onTap: () async {
              final n = await _pickNumber('كيلومترات (عربية)', s.soonKmCar,
                  suffix: 'كم', min: 1);
              if (n != null) await _update(() => s.soonKmCar = n);
            },
          ),
          ListTile(
            leading: const Icon(Icons.two_wheeler_outlined),
            title: const Text('الموتوسيكلات: باقي كيلومترات أقل من'),
            trailing: Text('${fmtInt(s.soonKmMoto)} كم'),
            onTap: () async {
              final n = await _pickNumber('كيلومترات (موتوسيكل)', s.soonKmMoto,
                  suffix: 'كم', min: 1);
              if (n != null) await _update(() => s.soonKmMoto = n);
            },
          ),
          const SectionTitle('العرض'),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: const Text('العملة'),
            trailing: Text(s.currency),
            onTap: () async {
              final ctrl = TextEditingController(text: s.currency);
              final r = await showDialog<String>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('العملة'),
                  content: TextField(controller: ctrl, autofocus: true),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('إلغاء')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, ctrl.text.trim()),
                        child: const Text('حفظ')),
                  ],
                ),
              );
              if (r != null && r.isNotEmpty) {
                await _update(() => s.currency = r);
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto),
                    label: Text('تلقائي')),
                ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode),
                    label: Text('فاتح')),
                ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode),
                    label: Text('غامق')),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => _update(() => s.themeMode = v.first),
            ),
          ),
          const SectionTitle('البيانات'),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('نسخة احتياطية'),
            subtitle: const Text('ابعتها لنفسك على واتساب أو Drive'),
            onTap: _export,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('استرجاع نسخة احتياطية'),
            onTap: _import,
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: cs.error),
            title: Text('مسح كل البيانات', style: TextStyle(color: cs.error)),
            onTap: () async {
              final ok = await confirmDialog(context, 'مسح كل البيانات؟',
                  message: 'كل المركبات والسجلات هتتمسح. خد نسخة احتياطية الأول.');
              if (ok) {
                await app.wipe();
                if (context.mounted) showSnack(context, 'تم المسح');
              }
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('صيانتي • الإصدار 1.0\nكل البيانات محفوظة على موبايلك بس',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _hourText(int h) {
    final period = h < 12 ? 'ص' : 'م';
    final hh = h % 12 == 0 ? 12 : h % 12;
    return '$hh:00 $period';
  }
}
