import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import 'package:almoktaber/core/database/app_snapshot.dart';
import 'package:almoktaber/core/services/guardian_report_service.dart';
import 'package:almoktaber/core/services/guardian_report_text.dart';
import 'package:almoktaber/core/services/monthly_report_scope.dart';
import 'package:almoktaber/core/services/report_service.dart';

import 'support/guardian_report_fixture.dart';

class _CapturingReportService extends ReportService {
  AppSnapshot? captured;

  @override
  Uint8List exportStudentXlsx(AppSnapshot snapshot, String studentUuid) {
    captured = snapshot;
    return Uint8List.fromList([1, 2, 3, 4]);
  }

  @override
  Future<Uint8List> exportStudentPdf(AppSnapshot snapshot, String studentUuid) async {
    captured = snapshot;
    return Uint8List.fromList([5, 6, 7]);
  }
}

List<String> _rowValues(Sheet sheet, int rowIndex) => sheet.rows[rowIndex]
    .map((cell) => cell?.value?.toString().trim() ?? '')
    .toList(growable: false);

void main() {
  ShareParams? capturedParams;

  test('يمرّر لقطة الشهر إلى باني Excel ويجهّز الاسم والنص والرقم', () async {
    final fixture = GuardianReportFixture();
    final builder = _CapturingReportService();
    final service = GuardianReportService(reportService: builder);

    final report = await service.prepare(
      snapshot: fixture.snapshot,
      studentUuid: GuardianReportFixture.studentUuid,
      guardianPhone: fixture.student.guardianPhone,
      format: GuardianReportFormat.xlsx,
      now: fixture.now,
    );

    expect(report.bytes.toList(), [1, 2, 3, 4]);
    expect(report.guardianPhone, '964700123456');
    expect(report.period.startLabel, '2026-11-01');
    expect(report.period.endLabel, '2026-11-21');
    expect(report.fileName, contains('أحمد_الصائغ'));
    expect(report.fileName, endsWith('_2026-11-01_2026-11-21.xlsx'));
    expect(report.text, contains('بصيغة Excel'));
    expect(builder.captured!.attendance, hasLength(2));
    expect(builder.captured!.grades, hasLength(1));
  });

  test('يستخدم باني PDF عند اختيار صيغة PDF', () async {
    final fixture = GuardianReportFixture();
    final builder = _CapturingReportService();
    final service = GuardianReportService(reportService: builder);

    final report = await service.prepare(
      snapshot: fixture.snapshot,
      studentUuid: GuardianReportFixture.studentUuid,
      guardianPhone: '+964700123456',
      format: GuardianReportFormat.pdf,
      now: fixture.now,
    );

    expect(report.bytes.toList(), [5, 6, 7]);
    expect(report.mimeType, 'application/pdf');
    expect(report.fileName, endsWith('.pdf'));
    expect(report.text, contains('بصيغة PDF'));
    expect(builder.captured!.behaviors, hasLength(2));
  });

  test('يستخدم نص المعاينة حرفياً دون إعادة بنائه عند PDF أو Excel', () async {
    final fixture = GuardianReportFixture();
    final service = GuardianReportService(reportService: _CapturingReportService());
    const preview = 'نص المعاينة كما يراه المستخدم\nسطر ثانٍ ٩٨٪';

    for (final format in GuardianReportFormat.values) {
      final report = await service.prepare(
        snapshot: fixture.snapshot,
        studentUuid: GuardianReportFixture.studentUuid,
        guardianPhone: fixture.student.guardianPhone,
        format: format,
        now: fixture.now,
        text: preview,
      );
      expect(report.text, same(preview));
      expect(report.mimeType, format.mimeType);
      expect(report.fileName, endsWith('.${format.extension}'));
    }
  });

  test('مرحلة النص تمرر النص وحدها ومرحلة الملف تمرر الملف وحده', () async {
    final fixture = GuardianReportFixture();
    final service = GuardianReportService(
      reportService: _CapturingReportService(),
      sharer: (params) async {
        capturedParams = params;
        return GuardianShareOutcome.completed;
      },
    );
    final report = await service.prepare(
      snapshot: fixture.snapshot,
      studentUuid: GuardianReportFixture.studentUuid,
      guardianPhone: fixture.student.guardianPhone,
      format: GuardianReportFormat.xlsx,
      now: fixture.now,
      text: 'نص المعاينة',
    );

    await service.shareTextOnly(report);
    expect(capturedParams?.text, 'نص المعاينة');
    expect(capturedParams?.files?.isEmpty ?? true, isTrue);

    await service.shareFileOnly(report);
    expect(capturedParams?.text, isNull);
    expect(capturedParams?.files, hasLength(1));
    expect(capturedParams?.fileNameOverrides, [report.fileName]);
  });

  test('يرفض نص المعاينة الفارغ', () async {
    final fixture = GuardianReportFixture();
    final service = GuardianReportService(reportService: _CapturingReportService());

    expect(
      service.prepare(
        snapshot: fixture.snapshot,
        studentUuid: GuardianReportFixture.studentUuid,
        guardianPhone: fixture.student.guardianPhone,
        format: GuardianReportFormat.pdf,
        now: fixture.now,
        text: '   ',
      ),
      throwsA(isA<FormatException>().having(
        (error) => error.message,
        'message',
        contains('فارغ'),
      )),
    );
  });

  test('يرفض رقم ولي الأمر الناقص والطالب غير الموجود', () async {
    final fixture = GuardianReportFixture();
    final service = GuardianReportService(reportService: _CapturingReportService());

    expect(
      service.prepare(
        snapshot: fixture.snapshot,
        studentUuid: GuardianReportFixture.studentUuid,
        guardianPhone: '123',
        format: GuardianReportFormat.pdf,
        now: fixture.now,
      ),
      throwsA(isA<FormatException>().having((error) => error.message, 'message', contains('غير صالح'))),
    );
    expect(
      service.prepare(
        snapshot: fixture.snapshot,
        studentUuid: 'missing',
        guardianPhone: fixture.student.guardianPhone,
        format: GuardianReportFormat.pdf,
        now: fixture.now,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('ملف الشهر نفس تنسيق ملف الطالب المعتاد', () {
    final fixture = GuardianReportFixture();
    final monthly = scopeToCurrentMonth(fixture.snapshot, now: fixture.now);
    final standard = Excel.decodeBytes(
      ReportService().exportStudentXlsx(fixture.snapshot, GuardianReportFixture.studentUuid),
    );
    final scoped = Excel.decodeBytes(
      ReportService().exportStudentXlsx(monthly.snapshot, GuardianReportFixture.studentUuid),
    );

    expect(scoped.tables.keys, standard.tables.keys);
    final standardSheet = standard.tables.values.first;
    final scopedSheet = scoped.tables.values.first;
    expect(_rowValues(scopedSheet, 2), _rowValues(standardSheet, 2));
    expect(_rowValues(scopedSheet, 0), _rowValues(standardSheet, 0));
  });
}
