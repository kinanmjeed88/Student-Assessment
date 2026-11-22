import 'package:flutter_test/flutter_test.dart';

import 'package:almoktaber/core/services/guardian_phone.dart';

void main() {
  test('يوحّد الأرقام المحلية والدولية والعربية إلى صيغة wa.me', () {
    expect(GuardianPhone.normalize('0700123456'), '964700123456');
    expect(GuardianPhone.normalize('+964 700 123 456'), '964700123456');
    expect(GuardianPhone.normalize('00964-700-123-456'), '964700123456');
    expect(GuardianPhone.normalize('٠٧٠٠١٢٣٤٥٦'), '964700123456');
    expect(GuardianPhone.normalize('۹۶۴۷۰۰۱۲۳۴۵۶'), '964700123456');
  });

  test('يرفض الأرقام الناقصة ويفبل الرقم المثبت الصالح', () {
    expect(GuardianPhone.validationError(''), isNotNull);
    expect(GuardianPhone.validationError('123'), isNotNull);
    expect(GuardianPhone.validationError('0700123456'), isNull);
    expect(GuardianPhone.validationError('+964700123456'), isNull);
  });

  test('يبني رابط محادثة مع نص مشفّر', () {
    final uri = GuardianPhone.chatUri(
      phone: GuardianPhone.normalize('0700123456'),
      text: 'تقرير الطالب أحمد',
    );

    expect(uri.host, 'wa.me');
    expect(uri.path, '/964700123456');
    expect(uri.queryParameters['text'], 'تقرير الطالب أحمد');
    expect(uri.toString(), contains('%D8%AA%D9%82%D8%B1%D9%8A%D8%B1'));
  });

  test('يرمّز النص العربي والأسطر الجديدة وعلامات الترقيم في رابط wa.me', () {
    const message = 'تقرير الطالب\nالحضور: ١٨/٢٠\nالسلوك: ممتاز، بدون ملاحظات.';
    final uri = GuardianPhone.chatUri(
      phone: GuardianPhone.normalize('٠٧٠٠١٢٣٤٥٦'),
      text: message,
    );

    expect(uri.path, '/964700123456');
    expect(uri.queryParameters['text'], message);
    expect(uri.toString(), contains('%0A'));
    expect(uri.path, isNot(contains('+')));
    expect(uri.path, isNot(contains(' ')));
    expect(uri.queryParameters['text'], message);
  });
}
