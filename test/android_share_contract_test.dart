import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// فحص عقد ثابت لملفات Android؛ لا يثبت سلوك واتساب على جهاز،
/// لكنه يمنع الرجوع إلى مسارات ملفات وصلاحيات غير آمنة.
void main() {
  const mainActivity = 'android/app/src/main/kotlin/com/almoktaber/MainActivity.kt';
  const manifest = 'android/app/src/main/AndroidManifest.xml';
  const paths = 'android/app/src/main/res/xml/file_paths.xml';
  const provider = 'android/app/src/main/kotlin/com/almoktaber/GuardianReportFileProvider.kt';

  String read(String path) => File(path).readAsStringSync();

  test('Intent يجمع النص والملف في ACTION_SEND واحد مع منح إذن القراءة', () {
    final source = read(mainActivity);
    expect(source, contains('Intent.ACTION_SEND'));
    expect(source, contains('putExtra(Intent.EXTRA_STREAM, uri)'));
    expect(source, contains('putExtra(Intent.EXTRA_TEXT, text)'));
    expect(source, contains('setPackage(packageName)'));
    expect(source, contains('FLAG_GRANT_READ_URI_PERMISSION'));
    expect(source, contains('ClipData.newUri'));
    expect(source, isNot(contains('Uri.fromFile')));
    expect(source, isNot(contains('file://')));
    expect(source, isNot(contains('"openChat"')));
  });

  test('الملف يمر عبر FileProvider داخل cache-path المسموح فقط', () {
    final source = read(mainActivity);
    final providerConfig = read(paths);
    final manifestSource = read(manifest);

    expect(source, contains('FileProvider.getUriForFile'));
    expect(source, contains('com.almoktaber.fileprovider'));
    expect(source, contains('cacheDir'));
    expect(providerConfig, contains('<cache-path'));
    expect(providerConfig, contains('shared_reports/'));
    expect(providerConfig, isNot(contains('<external-path')));
    expect(manifestSource, contains('android:authorities="com.almoktaber.fileprovider"'));
    expect(manifestSource, contains('android:exported="false"'));
    expect(manifestSource, contains('android:grantUriPermissions="true"'));
    expect(manifestSource, contains('@xml/file_paths'));
    expect(manifestSource, isNot(contains('QUERY_ALL_PACKAGES')));
    expect(read(provider), contains('FileProvider()'));
  });
}
