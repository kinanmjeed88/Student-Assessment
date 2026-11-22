import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:almoktaber/core/services/guardian_report_service.dart';
import 'package:almoktaber/core/services/guardian_report_text.dart';
import 'package:almoktaber/core/services/guardian_send_session.dart';
import 'package:almoktaber/core/services/monthly_report_scope.dart';

PreparedGuardianReport _report() => PreparedGuardianReport(
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      fileName: 'تقرير_أحمد.pdf',
      mimeType: GuardianReportFormat.pdf.mimeType,
      text: 'نص المعاينة كما يراه المستخدم\nسطر ثانٍ ٩٨٪',
      period: MonthlyReportPeriod.current(DateTime(2026, 11, 21)),
      guardianPhone: '964700123456',
      format: GuardianReportFormat.pdf,
    );

String _tempFile() =>
    '${Directory.systemTemp.path}/session_${DateTime.now().microsecondsSinceEpoch}.pdf';

void main() {
  test('يجهّز التقرير مرة واحدة ويتابع النص ثم الملف بالمسار نفسه', () async {
    final session = GuardianSendSession();
    final report = _report();
    final path = _tempFile();
    await File(path).writeAsBytes(report.bytes);
    final stages = <GuardianSendStage>[];
    session.state.addListener(() => stages.add(session.state.value.stage));

    var prepareCalls = 0;
    var writeCalls = 0;
    String? openedText;
    PreparedGuardianReport? sharedReport;
    String? sharedPath;

    await session.startMessage(
      prepare: () {
        prepareCalls++;
        return Future.value(report);
      },
      writeFile: (prepared) {
        writeCalls++;
        return Future.value(path);
      },
      openChat: (prepared) {
        openedText = prepared.text;
        return Future.value(true);
      },
    );

    expect(prepareCalls, 1);
    expect(writeCalls, 1);
    expect(openedText, report.text);
    expect(session.hasPreparedFile, isTrue);
    expect(session.normalizedPhone, '964700123456');
    expect(
      stages,
      containsAll(<GuardianSendStage>[
        GuardianSendStage.preparing,
        GuardianSendStage.messageReady,
        GuardianSendStage.messageChatOpened,
        GuardianSendStage.fileReady,
      ]),
    );

    await session.shareFile(share: (prepared, filePath) async {
      sharedReport = prepared;
      sharedPath = filePath;
      return GuardianShareOutcome.completed;
    });

    expect(sharedReport, same(report));
    expect(sharedPath, path);
    expect(prepareCalls, 1);
    expect(writeCalls, 1);
    expect(session.state.value.stage, GuardianSendStage.completed);

    await session.dispose();
    expect(File(path).existsSync(), isFalse);
  });

  test('فشل فتح المحادثة يبقي الملف جاهزاً ويعيد المحاولة بلا إعادة تجهيز', () async {
    final session = GuardianSendSession();
    final report = _report();
    final path = _tempFile();
    await File(path).writeAsBytes(report.bytes);
    var prepareCalls = 0;
    var openCalls = 0;

    Future<void> attempt(bool succeed) => session.startMessage(
          prepare: () {
            prepareCalls++;
            return Future.value(report);
          },
          writeFile: (prepared) => Future.value(path),
          openChat: (prepared) {
            openCalls++;
            return Future.value(succeed);
          },
        );

    await attempt(false);
    expect(session.state.value.stage, GuardianSendStage.failed);
    expect(session.hasPreparedFile, isTrue);
    expect(session.messageChatOpened, isFalse);

    await attempt(true);
    expect(session.state.value.stage, GuardianSendStage.fileReady);
    expect(prepareCalls, 1);
    expect(openCalls, 2);

    await session.dispose();
  });

  test('إلغاء مشاركة الملف يعيد حالة المتابعة دون فقد الملف', () async {
    final session = GuardianSendSession();
    final report = _report();
    final path = _tempFile();
    await File(path).writeAsBytes(report.bytes);

    await session.startMessage(
      prepare: () => Future.value(report),
      writeFile: (prepared) => Future.value(path),
      openChat: (prepared) => Future.value(true),
    );
    await session.shareFile(share: (_, __) async {
      return GuardianShareOutcome.dismissed;
    });

    expect(session.state.value.stage, GuardianSendStage.fileReady);
    expect(session.hasPreparedFile, isTrue);

    GuardianShareOutcome? secondOutcome;
    await session.shareFile(share: (_, __) async {
      secondOutcome = GuardianShareOutcome.completed;
      return secondOutcome!;
    });
    expect(secondOutcome, GuardianShareOutcome.completed);
    expect(session.state.value.stage, GuardianSendStage.completed);

    await session.dispose();
  });

  test('يمنع بدء عملية ثانية أثناء العملية الجارية', () async {
    final session = GuardianSendSession();
    final report = _report();
    final path = _tempFile();
    await File(path).writeAsBytes(report.bytes);
    var prepareCalls = 0;
    final gate = Completer<bool>();

    final first = session.startMessage(
      prepare: () {
        prepareCalls++;
        return Future.value(report);
      },
      writeFile: (prepared) => Future.value(path),
      openChat: (prepared) => gate.future,
    );
    await session.startMessage(
      prepare: () {
        prepareCalls++;
        return Future.value(report);
      },
      writeFile: (prepared) => Future.value(path),
      openChat: (prepared) => Future.value(true),
    );

    expect(prepareCalls, 1);
    gate.complete(true);
    await first;
    await session.dispose();
  });
}
