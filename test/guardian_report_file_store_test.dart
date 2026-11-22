import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:almoktaber/core/services/guardian_report_file_store.dart';
import 'package:almoktaber/core/services/guardian_report_service.dart';
import 'package:almoktaber/core/services/guardian_report_text.dart';
import 'package:almoktaber/core/services/monthly_report_scope.dart';

PreparedGuardianReport _report() => PreparedGuardianReport(
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      fileName: 'تقرير_أحمد.pdf',
      mimeType: GuardianReportFormat.pdf.mimeType,
      text: 'نص التقرير',
      period: MonthlyReportPeriod.current(DateTime(2026, 11, 21)),
      guardianPhone: '9647501234567',
      format: GuardianReportFormat.pdf,
    );

void main() {
  test('يكتب الملف مرة باسم التقرير نفسه ثم يحذفه عند الطلب', () async {
    final temporary = await Directory.systemTemp.createTemp('guardian-store-');
    addTearDown(() async {
      if (await temporary.exists()) await temporary.delete(recursive: true);
    });
    final store = GuardianReportFileStore(
      temporaryDirectory: () async => temporary,
      now: () => DateTime(2026, 11, 21, 12),
    );

    final path = await store.write(_report());
    final file = File(path);

    expect(await file.readAsBytes(), [1, 2, 3, 4]);
    expect(path.split(Platform.pathSeparator).last, 'تقرير_أحمد.pdf');
    expect(file.parent.parent.path, endsWith('guardian_reports'));

    await store.remove(path);
    expect(await file.exists(), isFalse);
    expect(await file.parent.exists(), isFalse);
  });

  test('يرفض التقرير الفارغ قبل لمس نظام الملفات', () async {
    var directoryRequested = false;
    final store = GuardianReportFileStore(
      temporaryDirectory: () async {
        directoryRequested = true;
        return Directory.systemTemp;
      },
    );
    final empty = PreparedGuardianReport(
      bytes: Uint8List(0),
      fileName: 'empty.pdf',
      mimeType: GuardianReportFormat.pdf.mimeType,
      text: 'نص',
      period: MonthlyReportPeriod.current(DateTime(2026, 11, 21)),
      guardianPhone: '9647501234567',
      format: GuardianReportFormat.pdf,
    );

    await expectLater(store.write(empty), throwsFormatException);
    expect(directoryRequested, isFalse);
  });
}
