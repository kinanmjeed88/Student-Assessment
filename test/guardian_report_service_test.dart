import 'dart:io';
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
  Future<Uint8List> exportStudentPdf(
    AppSnapshot snapshot,
    String studentUuid,
  ) async {
    captured = snapshot;
    return Uint8List.fromList([5, 6, 7]);
  }
}

Iterable<String> _workbookValues(Excel workbook) sync* {
  for (final sheet in workbook.tables.values) {
    for (final row in sheet.rows) {
      for (final cell in row) {
        yield cell?.value?.toString() ?? '';
      }
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('يمرر لقطة الشهر إلى باني Excel ويجهز الاسم والنص والرقم', () async {
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
    expect(report.text, contains('رسالة مستقلة بصيغة Excel'));
    expect(builder.captured!.attendance, hasLength(2));
    expect(builder.captured!.grades, hasLength(1));
  });

  test('يستخدم باني PDF عند اختيار PDF', () async {
    final fixture = GuardianReportFixture();
    final builder = _CapturingReportService();
    final service = GuardianReportService(reportService: builder);

    final report = await service.prepare(
      snapshot: fixture.snapshot,
      studentUuid: GuardianReportFixture.studentUuid,
      guardianPhone: fixture.student.guardianPhone,
      format: GuardianReportFormat.pdf,
      now: fixture.now,
    );

    expect(report.bytes.toList(), [5, 6, 7]);
    expect(report.mimeType, 'application/pdf');
    expect(report.fileName, endsWith('.pdf'));
    expect(builder.captured!.behaviors, hasLength(2));
  });

  test('يمرر نص المعاينة حرفيا إلى PDF وExcel', () async {
    final fixture = GuardianReportFixture();
    final service = GuardianReportService(
      reportService: _CapturingReportService(),
    );
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

  test('ينشئ ملف Excel فعليا ببنية ملف الطالب وبيانات الشهر فقط', () async {
    final fixture = GuardianReportFixture();
    final report = await GuardianReportService().prepare(
      snapshot: fixture.snapshot,
      studentUuid: GuardianReportFixture.studentUuid,
      guardianPhone: fixture.student.guardianPhone,
      format: GuardianReportFormat.xlsx,
      now: fixture.now,
    );

    final workbook = Excel.decodeBytes(report.bytes);
    expect(workbook.tables.keys, containsAll([
      'الملف الشخصي',
      'الدرجات',
      'الحضور',
      'السلوك',
      'الملاحظات',
    ]));
    final values = _workbookValues(workbook).toList();
    expect(values, contains('2026-11-01'));
    expect(values, contains('2026-11-10'));
    expect(values, isNot(contains('2026-10-31')));
    expect(values, isNot(contains('2026-11-22')));
  });

  test('ينشئ ملف PDF فعليا وغير فارغ من لقطة الشهر', () async {
    final fixture = GuardianReportFixture();
    final report = await GuardianReportService().prepare(
      snapshot: fixture.snapshot,
      studentUuid: GuardianReportFixture.studentUuid,
      guardianPhone: fixture.student.guardianPhone,
      format: GuardianReportFormat.pdf,
      now: fixture.now,
    );

    expect(report.bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(report.bytes.take(5)), '%PDF-');
  });

  test('يفصل طلب مشاركة النص عن طلب مشاركة الملف نفسه', () async {
    final fixture = GuardianReportFixture();
    final captured = <ShareParams>[];
    final service = GuardianReportService(
      reportService: _CapturingReportService(),
      sharer: (params) async {
        captured.add(params);
        return GuardianShareOutcome.shareUiRequested;
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
    final directory = await Directory.systemTemp.createTemp('guardian-share-');
    final file = File('${directory.path}${Platform.pathSeparator}${report.fileName}');
    await file.writeAsBytes(report.bytes);
    addTearDown(() => directory.delete(recursive: true));

    await service.shareTextOnly(report);
    expect(captured.single.text, 'نص المعاينة');
    expect(captured.single.files?.isEmpty ?? true, isTrue);

    await service.shareFileOnly(report, filePath: file.path);
    expect(captured, hasLength(2));
    expect(captured.last.text, isNull);
    expect(captured.last.files, hasLength(1));
    expect(captured.last.files!.single.path, file.path);
    expect(captured.last.fileNameOverrides, [report.fileName]);
  });

  test('يرفض نصا فارغا ورقما ناقصا وطالبا غير موجود', () async {
    final fixture = GuardianReportFixture();
    final service = GuardianReportService(
      reportService: _CapturingReportService(),
    );

    await expectLater(
      service.prepare(
        snapshot: fixture.snapshot,
        studentUuid: GuardianReportFixture.studentUuid,
        guardianPhone: fixture.student.guardianPhone,
        format: GuardianReportFormat.pdf,
        text: '   ',
      ),
      throwsFormatException,
    );
    await expectLater(
      service.prepare(
        snapshot: fixture.snapshot,
        studentUuid: GuardianReportFixture.studentUuid,
        guardianPhone: '123',
        format: GuardianReportFormat.pdf,
      ),
      throwsFormatException,
    );
    await expectLater(
      service.prepare(
        snapshot: fixture.snapshot,
        studentUuid: 'missing',
        guardianPhone: fixture.student.guardianPhone,
        format: GuardianReportFormat.pdf,
      ),
      throwsFormatException,
    );
  });

  test('يرفض مشاركة ملف مفقود أو فارغ', () async {
    final fixture = GuardianReportFixture();
    final service = GuardianReportService(
      reportService: _CapturingReportService(),
      sharer: (_) async => GuardianShareOutcome.shareUiRequested,
    );
    final report = await service.prepare(
      snapshot: fixture.snapshot,
      studentUuid: GuardianReportFixture.studentUuid,
      guardianPhone: fixture.student.guardianPhone,
      format: GuardianReportFormat.pdf,
    );
    final directory = await Directory.systemTemp.createTemp('guardian-empty-');
    addTearDown(() => directory.delete(recursive: true));

    await expectLater(
      service.shareFileOnly(
        report,
        filePath: '${directory.path}${Platform.pathSeparator}missing.pdf',
      ),
      throwsFormatException,
    );
    final empty = File('${directory.path}${Platform.pathSeparator}empty.pdf');
    await empty.writeAsBytes([]);
    await expectLater(
      service.shareFileOnly(report, filePath: empty.path),
      throwsFormatException,
    );
  });
}
