import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:almoktaber/core/services/guardian_report_service.dart';
import 'package:almoktaber/core/services/guardian_report_text.dart';
import 'package:almoktaber/core/services/guardian_send_session.dart';
import 'package:almoktaber/core/services/monthly_report_scope.dart';

PreparedGuardianReport _report() => PreparedGuardianReport(
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      fileName: 'تقرير_أحمد.pdf',
      mimeType: GuardianReportFormat.pdf.mimeType,
      text: 'نص المعاينة كما يراه المستخدم\nسطر ثانٍ ٩٨٪',
      period: MonthlyReportPeriod.current(DateTime(2026, 11, 21)),
      guardianPhone: '9647501234567',
      format: GuardianReportFormat.pdf,
    );

Future<File> _tempReport(PreparedGuardianReport report) async {
  final directory = await Directory.systemTemp.createTemp('guardian-session-');
  final file = File(
    '${directory.path}${Platform.pathSeparator}${report.fileName}',
  );
  return file.writeAsBytes(report.bytes);
}

void main() {
  test('يجهز مرة وينسخ مرة ويفصل النص عن الملف ويمنع التكرار', () async {
    final report = _report();
    final file = await _tempReport(report);
    addTearDown(() async {
      if (await file.parent.exists()) await file.parent.delete(recursive: true);
    });
    final session = GuardianSendSession();
    var prepareCalls = 0;
    var writeCalls = 0;
    var copyCalls = 0;
    var textShareCalls = 0;
    var fileShareCalls = 0;
    String? sharedText;
    String? sharedPath;

    Future<void> start() => session.startText(
          prepare: () async {
            prepareCalls++;
            return report;
          },
          writeFile: (_) async {
            writeCalls++;
            return file.path;
          },
          copyPhone: (phone) async {
            copyCalls++;
            expect(phone, report.guardianPhone);
            return true;
          },
          shareText: (prepared) async {
            textShareCalls++;
            sharedText = prepared.text;
            return GuardianShareOutcome.shareUiRequested;
          },
        );

    await start();
    await start();

    expect(prepareCalls, 1);
    expect(writeCalls, 1);
    expect(copyCalls, 1);
    expect(textShareCalls, 1);
    expect(sharedText, report.text);
    expect(session.state.value.stage, GuardianSendStage.fileReady);
    expect(session.autoCopySucceeded, isTrue);

    Future<void> shareFile() => session.shareFile(
          share: (prepared, path) async {
            fileShareCalls++;
            expect(prepared, same(report));
            sharedPath = path;
            return GuardianShareOutcome.shareUiRequested;
          },
        );

    await shareFile();
    await shareFile();

    expect(fileShareCalls, 1);
    expect(sharedPath, file.path);
    expect(session.state.value.stage, GuardianSendStage.completed);
    expect(session.fileShareRequested, isTrue);

    await session.dispose();
    expect(await file.exists(), isTrue,
        reason: 'يبقى الملف بعد تسليمه لواجهة النظام.');
  });

  test('فشل مشاركة النص يعيد المحاولة دون تجهيز أو نسخ جديد', () async {
    final report = _report();
    final file = await _tempReport(report);
    addTearDown(() async {
      if (await file.parent.exists()) await file.parent.delete(recursive: true);
    });
    final session = GuardianSendSession();
    var prepareCalls = 0;
    var writeCalls = 0;
    var copyCalls = 0;
    var shareCalls = 0;

    Future<void> attempt() => session.startText(
          prepare: () async {
            prepareCalls++;
            return report;
          },
          writeFile: (_) async {
            writeCalls++;
            return file.path;
          },
          copyPhone: (_) async {
            copyCalls++;
            return true;
          },
          shareText: (_) async {
            shareCalls++;
            if (shareCalls == 1) throw StateError('تعذر فتح النافذة');
            return GuardianShareOutcome.shareUiRequested;
          },
        );

    await attempt();
    expect(session.state.value.stage, GuardianSendStage.failed);
    expect(session.state.value.retryStep, GuardianRetryStep.text);
    expect(session.hasPreparedFile, isTrue);

    await attempt();
    expect(session.state.value.stage, GuardianSendStage.fileReady);
    expect(prepareCalls, 1);
    expect(writeCalls, 1);
    expect(copyCalls, 1);
    expect(shareCalls, 2);

    await session.dispose();
    expect(await file.exists(), isFalse);
  });

  test('إلغاء أو فشل مشاركة الملف يسمح بإعادة الملف نفسه فقط', () async {
    final report = _report();
    final file = await _tempReport(report);
    addTearDown(() async {
      if (await file.parent.exists()) await file.parent.delete(recursive: true);
    });
    final session = GuardianSendSession();
    var textCalls = 0;
    var fileCalls = 0;

    await session.startText(
      prepare: () async => report,
      writeFile: (_) async => file.path,
      copyPhone: (_) async => true,
      shareText: (_) async {
        textCalls++;
        return GuardianShareOutcome.shareUiRequested;
      },
    );
    await session.shareFile(
      share: (_, path) async {
        fileCalls++;
        expect(path, file.path);
        return GuardianShareOutcome.dismissed;
      },
    );

    expect(session.state.value.stage, GuardianSendStage.fileReady);
    expect(session.hasPreparedFile, isTrue);

    await session.shareFile(
      share: (_, path) async {
        fileCalls++;
        expect(path, file.path);
        return GuardianShareOutcome.shareUiRequested;
      },
    );

    expect(textCalls, 1);
    expect(fileCalls, 2);
    expect(session.state.value.stage, GuardianSendStage.completed);
    await session.dispose();
  });

  test('الضغط المتكرر أثناء العملية لا يبدأ مشاركة ثانية', () async {
    final report = _report();
    final file = await _tempReport(report);
    addTearDown(() async {
      if (await file.parent.exists()) await file.parent.delete(recursive: true);
    });
    final session = GuardianSendSession();
    final gate = Completer<GuardianShareOutcome>();
    var prepareCalls = 0;
    var textCalls = 0;

    Future<void> start() => session.startText(
          prepare: () async {
            prepareCalls++;
            return report;
          },
          writeFile: (_) async => file.path,
          copyPhone: (_) async => true,
          shareText: (_) {
            textCalls++;
            return gate.future;
          },
        );

    final first = start();
    await Future<void>.delayed(Duration.zero);
    await start();

    expect(prepareCalls, 1);
    expect(textCalls, 1);
    gate.complete(GuardianShareOutcome.shareUiRequested);
    await first;
    await session.dispose();
  });

  test('فشل النسخ التلقائي لا يوقف المشاركة ولا يتكرر عند الإعادة', () async {
    final report = _report();
    final file = await _tempReport(report);
    addTearDown(() async {
      if (await file.parent.exists()) await file.parent.delete(recursive: true);
    });
    final session = GuardianSendSession();
    var copyCalls = 0;
    var shareCalls = 0;

    Future<void> attempt() => session.startText(
          prepare: () async => report,
          writeFile: (_) async => file.path,
          copyPhone: (_) async {
            copyCalls++;
            throw StateError('الحافظة غير متاحة');
          },
          shareText: (_) async {
            shareCalls++;
            return shareCalls == 1
                ? GuardianShareOutcome.dismissed
                : GuardianShareOutcome.shareUiRequested;
          },
        );

    await attempt();
    expect(session.state.value.warning, contains('استخدم زر النسخ اليدوي'));
    await attempt();

    expect(copyCalls, 1);
    expect(shareCalls, 2);
    expect(session.state.value.stage, GuardianSendStage.fileReady);
    await session.dispose();
  });
}
