import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'guardian_report_service.dart';

/// يكتب نسخة واحدة من التقرير في مجلد مؤقت باسم الملف النهائي نفسه.
class GuardianReportFileStore {
  GuardianReportFileStore({
    Future<Directory> Function()? temporaryDirectory,
    DateTime Function()? now,
  })  : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
        _now = now ?? DateTime.now;

  final Future<Directory> Function() _temporaryDirectory;
  final DateTime Function() _now;

  Future<String> write(PreparedGuardianReport report) async {
    if (report.bytes.isEmpty) {
      throw const FormatException('تعذر إنشاء ملف التقرير لأنه فارغ.');
    }

    final temporary = await _temporaryDirectory();
    final root = Directory(
      '${temporary.path}${Platform.pathSeparator}guardian_reports',
    );
    await root.create(recursive: true);
    await _removeExpired(root);

    final sessionDirectory = await _createSessionDirectory(root);
    final safeName = _safeFileName(report.fileName);
    final file = File(
      '${sessionDirectory.path}${Platform.pathSeparator}$safeName',
    );
    await file.writeAsBytes(report.bytes, flush: true);
    if (!await file.exists() || await file.length() != report.bytes.length) {
      throw const FileSystemException('تعذر حفظ ملف التقرير المؤقت.');
    }
    return file.path;
  }

  /// يحذف الملف إذا لم تبدأ مشاركته، ويترك الملفات التي سلمت لواجهة النظام
  /// حتى لا تختفي قبل أن يختار المستخدم المستلم. تنظف المحاولة التالية
  /// المجلدات الأقدم من يوم واحد.
  Future<void> remove(String filePath) async {
    final file = File(filePath);
    try {
      if (await file.exists()) await file.delete();
      final parent = file.parent;
      if (await parent.exists() && await parent.list().isEmpty) {
        await parent.delete();
      }
    } catch (_) {
      // ملفات مؤقتة؛ لا ينبغي أن يمنع تعذر حذفها إغلاق نافذة التقرير.
    }
  }

  Future<Directory> _createSessionDirectory(Directory root) async {
    final stamp = _now().microsecondsSinceEpoch;
    var attempt = 0;
    while (true) {
      final suffix = attempt == 0 ? '$stamp' : '${stamp}_$attempt';
      final directory = Directory(
        '${root.path}${Platform.pathSeparator}$suffix',
      );
      if (!await directory.exists()) {
        await directory.create();
        return directory;
      }
      attempt++;
    }
  }

  Future<void> _removeExpired(Directory root) async {
    final cutoff = _now().subtract(const Duration(days: 1));
    try {
      await for (final entity in root.list()) {
        if (entity is! Directory) continue;
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          await entity.delete(recursive: true);
        }
      }
    } catch (_) {
      // التنظيف استباقي ولا يجب أن يعطل تجهيز تقرير جديد.
    }
  }

  String _safeFileName(String value) {
    final safe = value
        .replaceAll(RegExp(r'[\\/:*?"<>|\r\n]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return safe.isEmpty ? 'guardian_report.bin' : safe;
  }
}
