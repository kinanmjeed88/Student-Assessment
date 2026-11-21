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
        'openChat' => <String, Object?>{
            'status': 'launched',
            'package': 'com.whatsapp',
          },
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

  test('يبني JID من الرقم المطبّع ويرفض الرقم الفارغ', () {
    expect(
      WhatsAppDirectJid.fromPhone('964700123456'),
      '964700123456@s.whatsapp.net',
    );
    expect(() => WhatsAppDirectJid.fromPhone(''), throwsArgumentError);
  });

  test('يحتوي Intent على النص والملف وJID والحزمة مع MIME صحيح', () {
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
    expect(GuardianReportFormat.xlsx.mimeType, contains('spreadsheetml'));
  });

  test('يختار الحزمة الصحيحة ويقصر المسار المباشر على Android', () {
    expect(
      WhatsAppPackage.fromPackageName('com.whatsapp.w4b'),
      WhatsAppPackage.whatsappBusiness,
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

  test('يكتشف الحزمتين المعروفين فقط', () async {
    final packages = await WhatsappDirectShareService().availablePackages();

    expect(packages, [
      WhatsAppPackage.whatsapp,
      WhatsAppPackage.whatsappBusiness,
    ]);
  });

  test('يمرر الرقم المطبّع إلى فتح المحادثة دون ادعاء الإرسال', () async {
    final result = await WhatsappDirectShareService().openChat(
      phone: '0700123456',
      text: 'تقرير الطالب',
    );

    expect(result.status, WhatsAppDirectStatus.launched);
    expect(result.package, WhatsAppPackage.whatsapp);
    expect(result.statusMessage, contains('تم فتح واتساب فقط'));
    expect(result.statusMessage, isNot(contains('تم الإرسال')));
    expect(lastArguments?['phone'], '964700123456');
    expect(lastArguments?['text'], 'تقرير الطالب');
  });

  test('لا يستدعي المنصة عند رقم غير صالح', () async {
    final result = await WhatsappDirectShareService().openChat(
      phone: '123',
      text: 'تقرير الطالب',
    );

    expect(result.status, WhatsAppDirectStatus.failed);
    expect(lastArguments, isNull);
  });

  test('يرفض مشاركة ملف غير موجود أو فارغ قبل تشغيل Intent', () async {
    final service = WhatsappDirectShareService();
    final missing = await service.shareToChat(
      phone: '964700123456',
      text: 'تقرير',
      filePath: '${Directory.systemTemp.path}/missing-report.pdf',
      fileName: 'report.pdf',
      mimeType: 'application/pdf',
      package: WhatsAppPackage.whatsapp,
    );
    expect(missing.status, WhatsAppDirectStatus.failed);
    expect(lastArguments, isNull);

    final emptyFile = File('${Directory.systemTemp.path}/empty-report.pdf');
    await emptyFile.writeAsBytes(<int>[]);
    final empty = await service.shareToChat(
      phone: '964700123456',
      text: 'تقرير',
      filePath: emptyFile.path,
      fileName: 'report.pdf',
      mimeType: 'application/pdf',
      package: WhatsAppPackage.whatsapp,
    );
    expect(empty.status, WhatsAppDirectStatus.failed);
    expect(lastArguments, isNull);
  });

  test('يمرر الملف الموجود مع النص والـ jid إلى القناة الأصلية', () async {
    final report = File('${Directory.systemTemp.path}/direct-report.xlsx');
    await report.writeAsBytes(<int>[1, 2, 3, 4]);

    final result = await WhatsappDirectShareService().shareToChat(
      phone: '+964700123456',
      text: 'تقرير الطالب',
      filePath: report.path,
      fileName: 'تقرير_أحمد.xlsx',
      mimeType: GuardianReportFormat.xlsx.mimeType,
      package: WhatsAppPackage.whatsappBusiness,
    );

    expect(result.status, WhatsAppDirectStatus.launched);
    expect(result.package, WhatsAppPackage.whatsapp);
    expect(lastArguments?['phone'], '964700123456');
    expect(lastArguments?['jid'], '964700123456@s.whatsapp.net');
    expect(lastArguments?['filePath'], report.path);
    expect(lastArguments?['fileName'], 'تقرير_أحمد.xlsx');
    expect(lastArguments?['package'], 'com.whatsapp.w4b');
  });

  test('يعالج عدم تثبيت واتساب دون ادعاء الإرسال', () async {
    handlerError = PlatformException(
      code: 'WHATSAPP_NOT_FOUND',
      message: 'No WhatsApp',
    );
    final result = await WhatsappDirectShareService().openChat(
      phone: '964700123456',
      text: 'تقرير',
    );

    expect(result.status, WhatsAppDirectStatus.notFound);
    expect(result.launched, isFalse);
  });

  test('أي حالة غير launched تُعد فشلاً وليست إرسالاً ناجحاً', () {
    final result = WhatsAppDirectResult.fromMap(<String, Object?>{
      'status': 'activity_started_but_unknown',
      'package': 'com.whatsapp',
    });

    expect(result.status, WhatsAppDirectStatus.failed);
    expect(result.launched, isFalse);
  });
}
