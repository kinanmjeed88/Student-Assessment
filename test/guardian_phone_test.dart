import 'package:flutter_test/flutter_test.dart';

import 'package:almoktaber/core/services/guardian_phone.dart';

void main() {
  test('يوحّد الصيغ المحلية والدولية والأرقام العربية', () {
    expect(GuardianPhone.normalize('0700123456'), '964700123456');
    expect(GuardianPhone.normalize('0750 123 4567'), '9647501234567');
    expect(GuardianPhone.normalize('+964 750 123 4567'), '9647501234567');
    expect(GuardianPhone.normalize('00964-750-123-4567'), '9647501234567');
    expect(GuardianPhone.normalize('٠٧٥٠١٢٣٤٥٦٧'), '9647501234567');
    expect(GuardianPhone.normalize('۹۶۴۷۵۰۱۲۳۴۵۶۷'), '9647501234567');
  });

  test('يرفض الرقم الفارغ والقصير ويقبل الرقم الدولي', () {
    expect(GuardianPhone.validationError(''), isNotNull);
    expect(GuardianPhone.validationError('123'), isNotNull);
    expect(GuardianPhone.validationError('07501234567'), isNull);
    expect(GuardianPhone.validationError('+9647501234567'), isNull);
  });

  test('يبني رابطاً يرمّز النص العربي والأسطر الجديدة', () {
    const message =
        'تقرير الطالب\nالحضور: ١٨/٢٠\nالسلوك: ممتاز، بدون ملاحظات.';
    final uri = GuardianPhone.chatUri(
      phone: GuardianPhone.normalize('٠٧٥٠١٢٣٤٥٦٧'),
      text: message,
    );

    expect(uri.host, 'wa.me');
    expect(uri.path, '/9647501234567');
    expect(uri.queryParameters['text'], message);
    expect(uri.toString(), contains('%0A'));
    expect(uri.path, isNot(contains('+')));
    expect(uri.path, isNot(contains(' ')));
  });
}
