import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:almoktaber/core/services/guardian_report_text.dart';
import 'package:almoktaber/core/services/whatsapp_direct_share.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(whatsappDirectChannel);
  Map<String, Object?>? lastArguments;
  Object? handlerError;

  setUp(() {
    lastArguments = null;
    handlerError = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (handlerError != null) throw handlerError!;
      lastArguments = (call.arguments as Map?)?.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
      return switch (call.method) {
        'availablePackages' => <String>[
            'com.whatsapp',
            'com.whatsapp.w4b',
            'com.unknown.app',
          ],
        'shareToChat' => <String, Object?>{
            'status': 'launched',
            'package': 'com.whatsapp',
            'jid': '964700123456@s.whatsapp.net',
          },
        _ => null,
      };
    });
  });

  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  String tempReport(String suffix) =>
      '${Directory.systemTemp.path}/guardian_${DateTime.now().microsecondsSinceEpoch}_$suffix';

  test('يبني JID من الرقم المطبّع ويرفض الرقم الفارغ', () {
    expect(
      WhatsAppDirectJid.fromPhone('964700123456'),
      '964700123456@s.whatsapp.net',
    );
    expect(() => WhatsAppDirectJid.fromPhone(''), throwsArgumentError);
  });

  test('طلب المشاركة الواحد يحمل النص والملف وJID والحزمة مع MIME صحيح', () {
    final payload = WhatsAppDirectPayload(
      phone: '964700123456',
      text: 'تقرير الطالب',
      filePath: '/cache/shared_reports/report.pdf',
      fileName: 'report.pdf',
      mimeType: GuardianReportFormat.pdf.mimeType,
      package: WhatsAppPackage.whatsappBusiness,
    );
    final arguments = payload.toArguments();

    expect(arguments['jid'], '964700123456@s.whatsapp.net');
    expect(arguments['text'], 'تقرير الطالب');
    expect(arguments['filePath'], '/cache/shared_reports/report.pdf');
    expect(arguments['mimeType'], 'application/pdf');
    expect(arguments['package'], 'com.whatsapp.w4b');
  });

  test('MIME يطابق امتداد PDF وExcel', () {
    expect(GuardianReportFormat.pdf.mimeType, 'application/pdf');
    expect(
      GuardianReportFormat.xlsx.mimeType,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    expect(GuardianReportFormat.pdf.extension, 'pdf');
    expect(GuardianReportFormat.xlsx.extension, 'xlsx');
  });

  test('يكتشف الحزمتين المعروفين فقط ويقصر المسار على Android', () async {
    expect(
      await WhatsappDirectShareService().availablePackages(),
      [WhatsAppPackage.whatsapp, WhatsAppPackage.whatsappBusiness],
    );
    expect(WhatsAppPackage.fromPackageName('com.unknown.app'), isNull);
    expect(
      WhatsAppDirectSupport.shouldOfferDirectSend(TargetPlatform.android),
      isTrue,
    );
    expect(
      WhatsAppDirectSupport.shouldOfferDirectSend(TargetPlatform.windows),
      isFalse,
    );
  });

  test('يمرّر نص المعاينة حرفياً مع الملف في استدعاء واحد', () async {
    final report = File(tempReport('shared.txt'));
    await report.writeAsBytes(<int>[1, 2, 3, 4]);
    const preview = 'تقرير الطالب\nالشهر الحالي\nالدرجات: ٩٨٪';

    final result = await WhatsappDirectShareService().shareToChat(
      phone: '0700123456',
      text: preview,
      filePath: report.path,
      fileName: 'تقرير_أحمد.pdf',
      mimeType: GuardianReportFormat.pdf.mimeType,
      package: WhatsAppPackage.whatsapp,
    );

    expect(result.status, WhatsAppDirectStatus.launched);
    expect(lastArguments?['text'], preview);
    expect(lastArguments?['filePath'], report.path);
    expect(lastArguments, containsPair('mimeType', 'application/pdf'));
    expect(lastArguments?['phone'], '964700123456');
    expect(lastArguments?['jid'], '964700123456@s.whatsapp.net');
  });

  test('مشاركة الملف وحدها لا تمرر نصاً إضافياً في طلب المشاركة', () async {
    final report = File(tempReport('file-only.pdf'));
    await report.writeAsBytes(<int>[1, 2, 3]);

    final result = await WhatsappDirectShareService().shareFile(
      phone: '0700123456',
      filePath: report.path,
      fileName: 'report.pdf',
      mimeType: GuardianReportFormat.pdf.mimeType,
      package: WhatsAppPackage.whatsappBusiness,
    );

    expect(result.status, WhatsAppDirectStatus.launched);
    expect(lastArguments?['text'], '');
    expect(lastArguments?['filePath'], report.path);
    expect(lastArguments?['mimeType'], 'application/pdf');
    expect(lastArguments?['package'], 'com.whatsapp.w4b');
  });

  test('لا يستدعي المنصة عند رقم غير صالح أو ملف مفقود أو فارغ', () async {
    final service = WhatsappDirectShareService();
    final invalid = await service.shareToChat(
      phone: '123',
      text: 'تقرير',
      filePath: tempReport('never.pdf'),
      fileName: 'report.pdf',
      mimeType: 'application/pdf',
      package: WhatsAppPackage.whatsapp,
    );
    expect(invalid.status, WhatsAppDirectStatus.failed);
    expect(lastArguments, isNull);

    final missing = await service.shareToChat(
      phone: '964700123456',
      text: 'تقرير',
      filePath: tempReport('missing.pdf'),
      fileName: 'report.pdf',
      mimeType: 'application/pdf',
      package: WhatsAppPackage.whatsapp,
    );
    expect(missing.status, WhatsAppDirectStatus.failed);
    expect(lastArguments, isNull);

    final empty = File(tempReport('empty.pdf'));
    await empty.writeAsBytes(<int>[]);
    final emptyResult = await service.shareToChat(
      phone: '964700123456',
      text: 'تقرير',
      filePath: empty.path,
      fileName: 'report.pdf',
      mimeType: 'application/pdf',
      package: WhatsAppPackage.whatsapp,
    );
    expect(emptyResult.status, WhatsAppDirectStatus.failed);
    expect(lastArguments, isNull);
  });

  test('يعالج عدم تثبيت واتساب أثناء المشاركة دون ادعاء الإرسال', () async {
    handlerError = PlatformException(
      code: 'WHATSAPP_NOT_FOUND',
      message: 'No WhatsApp',
    );
    final report = File(tempReport('not-installed.pdf'));
    await report.writeAsBytes(<int>[1]);

    final result = await WhatsappDirectShareService().shareToChat(
      phone: '964700123456',
      text: 'تقرير',
      filePath: report.path,
      fileName: 'report.pdf',
      mimeType: 'application/pdf',
      package: WhatsAppPackage.whatsapp,
    );

    expect(result.status, WhatsAppDirectStatus.notFound);
    expect(result.launched, isFalse);
    expect(result.statusMessage, isNot(contains('تم الإرسال')));
  });

  test('يعالج فشل فتح التطبيق أو رفض المشاركة كفشل صريح', () async {
    handlerError = PlatformException(code: 'SHARE_FAILED', message: 'رفض النظام');
    final report = File(tempReport('failed.xlsx'));
    await report.writeAsBytes(<int>[1]);

    final result = await WhatsappDirectShareService().shareToChat(
      phone: '964700123456',
      text: 'تقرير',
      filePath: report.path,
      fileName: 'report.xlsx',
      mimeType: GuardianReportFormat.xlsx.mimeType,
      package: WhatsAppPackage.whatsappBusiness,
    );

    expect(result.status, WhatsAppDirectStatus.failed);
    expect(result.message, contains('رفض النظام'));
    expect(result.statusMessage, contains('تعذر فتح واتساب'));
  });

  test('حالة الإقلاع لا تعني وصول الرسالة أو ضغط إرسال', () {
    final result = WhatsAppDirectResult.fromMap(<String, Object?>{
      'status': 'launched',
      'package': 'com.whatsapp',
    });
    expect(result.launched, isTrue);
    expect(result.statusMessage, contains('راجع المستلم'));
    expect(result.statusMessage, isNot(contains('تم الإرسال')));

    final unknown = WhatsAppDirectResult.fromMap(<String, Object?>{
      'status': 'activity_started_but_unknown',
      'package': 'com.whatsapp',
    });
    expect(unknown.status, WhatsAppDirectStatus.failed);
    expect(unknown.launched, isFalse);
  });
}
