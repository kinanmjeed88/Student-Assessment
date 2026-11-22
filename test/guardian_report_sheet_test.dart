import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import 'package:almoktaber/core/database/app_snapshot.dart';
import 'package:almoktaber/core/services/guardian_phone_copier.dart';
import 'package:almoktaber/core/services/guardian_report_file_store.dart';
import 'package:almoktaber/core/services/guardian_report_service.dart';
import 'package:almoktaber/core/services/report_service.dart';
import 'package:almoktaber/features/students/presentation/guardian_report_sheet.dart';

import 'support/guardian_report_fixture.dart';

class _FakeReportService extends ReportService {
  @override
  Uint8List exportStudentXlsx(AppSnapshot snapshot, String studentUuid) =>
      Uint8List.fromList([1, 2, 3, 4]);

  @override
  Future<Uint8List> exportStudentPdf(
    AppSnapshot snapshot,
    String studentUuid,
  ) async =>
      Uint8List.fromList([5, 6, 7, 8]);
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('لم يظهر العنصر المطلوب خلال خمس ثوانٍ.');
}

void main() {
  testWidgets('تعرض خطوتي النص والملف ولا تجمعهما في طلب واحد', (tester) async {
    final fixture = GuardianReportFixture();
    final temporary = await Directory.systemTemp.createTemp('guardian-sheet-');
    addTearDown(() async {
      if (await temporary.exists()) await temporary.delete(recursive: true);
    });
    final shared = <ShareParams>[];
    final copied = <String>[];
    final service = GuardianReportService(
      reportService: _FakeReportService(),
      sharer: (params) async {
        shared.add(params);
        return GuardianShareOutcome.shareUiRequested;
      },
    );
    final store = GuardianReportFileStore(
      temporaryDirectory: () async => temporary,
    );
    final copier = GuardianPhoneCopier(
      write: (value) async => copied.add(value),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showGuardianReportSheet(
                  context: context,
                  snapshot: fixture.snapshot,
                  student: fixture.student,
                  reportService: service,
                  fileStore: store,
                  phoneCopier: copier,
                ),
                child: const Text('فتح'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('فتح'));
    await _pumpUntilFound(tester, find.text(guardianReportStartLabel));
    expect(find.text(guardianReportStartLabel), findsOneWidget);
    expect(find.textContaining('لا يختار التطبيق المستلم'), findsOneWidget);

    await tester.tap(find.text(guardianReportStartLabel));
    await _pumpUntilFound(tester, find.text(guardianReportFileStepTitle));

    expect(shared, hasLength(1));
    expect(shared.single.text, isNotEmpty);
    expect(shared.single.files?.isEmpty ?? true, isTrue);
    expect(copied, ['964700123456']);
    expect(find.text(guardianReportFileStepTitle), findsWidgets);

    await tester.tap(
      find.widgetWithText(FilledButton, guardianReportFileStepTitle),
    );
    await _pumpUntilFound(tester, find.text('طُلبت مشاركة ملف التقرير'));

    expect(shared, hasLength(2));
    expect(shared.last.text, isNull);
    expect(shared.last.files, hasLength(1));
    expect(copied, hasLength(1));
    expect(find.text('طُلبت مشاركة ملف التقرير'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, guardianReportFileStepTitle),
      findsNothing,
    );

    await tester.tap(find.text('إغلاق'));
    await tester.pump(const Duration(seconds: 1));
  });
}
