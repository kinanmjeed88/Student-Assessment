import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:almoktaber/core/database/app_snapshot.dart';
import 'package:almoktaber/core/database/isar_models.dart';
import 'package:almoktaber/core/services/guardian_phone.dart';
import 'package:almoktaber/core/services/guardian_phone_copier.dart';
import 'package:almoktaber/core/services/guardian_report_file_store.dart';
import 'package:almoktaber/core/services/guardian_report_service.dart';
import 'package:almoktaber/core/services/guardian_report_text.dart';
import 'package:almoktaber/core/services/monthly_report_scope.dart';
import 'package:almoktaber/features/students/presentation/guardian_report_sheet.dart';

import 'support/guardian_report_fixture.dart';

class _FakeGuardianReportService extends GuardianReportService {
  int prepareCalls = 0;
  int textShareCalls = 0;
  int fileShareCalls = 0;
  PreparedGuardianReport? preparedReport;
  PreparedGuardianReport? textReport;
  PreparedGuardianReport? fileReport;
  String? sharedFilePath;

  @override
  Future<PreparedGuardianReport> prepare({
    required AppSnapshot snapshot,
    required String studentUuid,
    required String guardianPhone,
    required GuardianReportFormat format,
    DateTime? now,
    String? text,
  }) async {
    prepareCalls++;
    final report = PreparedGuardianReport(
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      fileName: 'تقرير_اختبار.${format.extension}',
      mimeType: format.mimeType,
      text: text ?? '',
      period: MonthlyReportPeriod.current(now ?? DateTime(2026, 11, 22)),
      guardianPhone: GuardianPhone.normalize(guardianPhone),
      format: format,
    );
    preparedReport = report;
    return report;
  }

  @override
  Future<GuardianShareOutcome> shareTextOnly(
    PreparedGuardianReport report,
  ) async {
    textShareCalls++;
    textReport = report;
    return GuardianShareOutcome.shareUiRequested;
  }

  @override
  Future<GuardianShareOutcome> shareFileOnly(
    PreparedGuardianReport report, {
    required String filePath,
  }) async {
    fileShareCalls++;
    fileReport = report;
    sharedFilePath = filePath;
    return GuardianShareOutcome.shareUiRequested;
  }
}

class _FakeReportFileStore extends GuardianReportFileStore {
  _FakeReportFileStore(this.path);

  final String path;
  int writeCalls = 0;

  @override
  Future<String> write(PreparedGuardianReport report) async {
    writeCalls++;
    return path;
  }

  @override
  Future<void> remove(String filePath) async {}
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('لم يظهر العنصر المطلوب خلال ثانية واحدة.');
}

void main() {
  testWidgets('تربط الواجهة مشاركة النص ثم الملف المجهز نفسه', (tester) async {
    final fixture = GuardianReportFixture();
    final temporary = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'guardian-sheet-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final preparedFile = File(
      '${temporary.path}${Platform.pathSeparator}guardian-report.pdf',
    )..writeAsBytesSync([1, 2, 3, 4], flush: true);
    addTearDown(() {
      if (temporary.existsSync()) temporary.deleteSync(recursive: true);
    });

    final shared = _FakeGuardianReportService();
    final store = _FakeReportFileStore(preparedFile.path);
    final copied = <String>[];
    final copier = GuardianPhoneCopier(
      write: (value) async => copied.add(value),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuardianReportSheet(
            snapshot: fixture.snapshot,
            student: fixture.student,
            reportService: shared,
            fileStore: store,
            phoneCopier: copier,
          ),
        ),
      ),
    );

    expect(find.text(guardianReportStartLabel), findsOneWidget);
    expect(find.textContaining('لا يختار التطبيق المستلم'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FilledButton, guardianReportStartLabel),
    );
    await _pumpUntilFound(
      tester,
      find.widgetWithText(FilledButton, guardianReportFileStepTitle),
    );

    expect(shared.prepareCalls, 1);
    expect(shared.textShareCalls, 1);
    expect(shared.fileShareCalls, 0);
    expect(shared.textReport, same(shared.preparedReport));
    expect(shared.textReport?.text, isNotEmpty);
    expect(store.writeCalls, 1);
    expect(copied, ['964700123456']);

    await tester.tap(
      find.widgetWithText(FilledButton, guardianReportFileStepTitle),
    );
    await _pumpUntilFound(tester, find.text('طُلبت مشاركة ملف التقرير'));

    expect(shared.prepareCalls, 1);
    expect(shared.textShareCalls, 1);
    expect(shared.fileShareCalls, 1);
    expect(shared.fileReport, same(shared.preparedReport));
    expect(shared.sharedFilePath, preparedFile.path);
    expect(store.writeCalls, 1);
    expect(copied, hasLength(1));
    expect(
      find.widgetWithText(FilledButton, guardianReportFileStepTitle),
      findsNothing,
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
  });
}
