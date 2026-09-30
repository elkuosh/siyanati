// سكريبت تجهيز مشروع الأندرويد بعد `flutter create`
// بيضيف صلاحيات الإشعارات، اسم التطبيق بالعربي، الأيقونة، وإعدادات Gradle.
//
// التشغيل (من فولدر المشروع):
//   flutter create --org com.rovana --project-name garage_log --platforms android .
//   dart run tool/setup.dart
import 'dart:io';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) {
    stderr.writeln('مش لاقي فولدر android. شغّل الأول:\n'
        '  flutter create --org com.rovana --project-name garage_log --platforms android .');
    exit(1);
  }
  _patchManifest(manifest);
  _patchGradle();
  _copyIcons();
  _copyWidgetFiles();
  _installSigningKey();
  // flutter create بيضيف تست افتراضي بيشاور على MyApp اللي مش موجود
  final t = File('test/widget_test.dart');
  if (t.existsSync() && t.readAsStringSync().contains('MyApp')) t.deleteSync();
  stdout.writeln('✔ تم تجهيز مشروع الأندرويد. دلوقتي شغّل:\n'
      '  flutter pub get\n  flutter build apk --release');
}

void _patchManifest(File f) {
  var s = f.readAsStringSync();

  s = s.replaceFirst(
      RegExp(r'android:label="[^"]*"'), 'android:label="صيانتي"');

  const perms = [
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.RECEIVE_BOOT_COMPLETED',
    'android.permission.VIBRATE',
  ];
  final permLines = StringBuffer();
  for (final p in perms) {
    if (!s.contains('"$p"')) {
      permLines.writeln('    <uses-permission android:name="$p"/>');
    }
  }
  if (permLines.isNotEmpty) {
    s = s.replaceFirst('<application', '${permLines}    <application');
  }

  if (!s.contains('ScheduledNotificationReceiver')) {
    const receivers = '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
''';
    final i = s.lastIndexOf('</application>');
    s = s.substring(0, i) + receivers + '    ' + s.substring(i);
  }

  // اتجاه عربي
  if (!s.contains('android:supportsRtl')) {
    s = s.replaceFirst('<application', '<application\n        android:supportsRtl="true"');
  }

  // ويدجيت العداد
  if (!s.contains('.OdometerWidget')) {
    const widgetReceiver = '''
        <receiver android:name=".OdometerWidget" android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/odometer_widget_info" />
        </receiver>
''';
    final j = s.lastIndexOf('</application>');
    s = s.substring(0, j) + widgetReceiver + '    ' + s.substring(j);
  }

  // فتح التطبيق من الويدجيت
  if (!s.contains('es.antonborri.home_widget.action.LAUNCH')) {
    const launchFilter = '''
            <intent-filter>
                <action android:name="es.antonborri.home_widget.action.LAUNCH" />
            </intent-filter>
''';
    final k = s.indexOf('</activity>');
    s = s.substring(0, k) + launchFilter + '        ' + s.substring(k);
  }

  f.writeAsStringSync(s);
  stdout.writeln('• AndroidManifest.xml');
}

void _patchGradle() {
  final kts = File('android/app/build.gradle.kts');
  final groovy = File('android/app/build.gradle');
  final isKts = kts.existsSync();
  final f = isKts ? kts : groovy;
  if (!f.existsSync()) {
    stderr.writeln('مش لاقي android/app/build.gradle');
    exit(1);
  }
  var s = f.readAsStringSync();
  if (s.contains('CoreLibraryDesugaring') ||
      s.contains('coreLibraryDesugaringEnabled')) {
    stdout.writeln('• ${f.path} (متعدّل قبل كده)');
    return;
  }

  final enable = isKts
      ? 'isCoreLibraryDesugaringEnabled = true'
      : 'coreLibraryDesugaringEnabled true';
  // AGP 7.x محتاج نسخة 1.2.2، والأحدث بيشتغل مع 2.x
  var libVer = '2.1.4';
  for (final name in ['android/settings.gradle', 'android/settings.gradle.kts']) {
    final sf = File(name);
    if (sf.existsSync() &&
        RegExp(r'com\.android\.application"?\)?\s*version\s*"7\.')
            .hasMatch(sf.readAsStringSync())) {
      libVer = '1.2.2';
    }
  }
  final dep = isKts
      ? 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:$libVer")'
      : "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:$libVer'";

  final m = RegExp(r'compileOptions\s*\{').firstMatch(s);
  if (m != null) {
    s = '${s.substring(0, m.end)}\n        $enable${s.substring(m.end)}';
  } else {
    final a = RegExp(r'android\s*\{').firstMatch(s)!;
    s = '${s.substring(0, a.end)}\n    compileOptions {\n        $enable\n    }'
        '${s.substring(a.end)}';
  }

  final d = RegExp(r'^dependencies\s*\{', multiLine: true).firstMatch(s);
  if (d != null) {
    s = '${s.substring(0, d.end)}\n    $dep${s.substring(d.end)}';
  } else {
    s = '$s\ndependencies {\n    $dep\n}\n';
  }

  f.writeAsStringSync(s);
  stdout.writeln('• ${f.path}');
}

void _copyIcons() {
  const sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  var n = 0;
  sizes.forEach((dpi, px) {
    final src = File('assets/icon/ic_launcher_$px.png');
    final dir = Directory('android/app/src/main/res/mipmap-$dpi');
    if (src.existsSync() && dir.existsSync()) {
      src.copySync('${dir.path}/ic_launcher.png');
      n++;
    }
  });
  stdout.writeln('• الأيقونة ($n مقاسات)');
}

void _copyWidgetFiles() {
  final kotlinDir = Directory('android/app/src/main/kotlin/com/rovana/garage_log');
  kotlinDir.createSync(recursive: true);
  File('tool/android/kotlin/OdometerWidget.kt')
      .copySync('${kotlinDir.path}/OdometerWidget.kt');
  final src = Directory('tool/android/res');
  for (final e in src.listSync(recursive: true)) {
    if (e is! File) continue;
    final rel = e.path.substring(src.path.length + 1);
    final dest = File('android/app/src/main/res/$rel');
    dest.parent.createSync(recursive: true);
    e.copySync(dest.path);
  }
  stdout.writeln('• ملفات الويدجيت');
}

/// مفتاح توقيع ثابت: عشان كل نسخة جديدة تتسطب فوق القديمة من غير ما تمسحها
void _installSigningKey() {
  final key = File('tool/debug.keystore');
  if (!key.existsSync()) return;
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home == null) return;
  final dir = Directory('$home/.android')..createSync(recursive: true);
  key.copySync('${dir.path}/debug.keystore');
  stdout.writeln('• مفتاح التوقيع');
}
