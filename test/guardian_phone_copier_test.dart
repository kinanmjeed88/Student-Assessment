import 'package:flutter_test/flutter_test.dart';

import 'package:almoktaber/core/services/guardian_phone_copier.dart';

void main() {
  test('ينسخ الرقم مرة بالصيغة الدولية الموحدة', () async {
    final copied = <String>[];
    final copier = GuardianPhoneCopier(
      write: (value) async => copied.add(value),
    );

    final result = await copier.copy('+964 750 123 4567');

    expect(result, '9647501234567');
    expect(copied, ['9647501234567']);
  });

  test('لا يكتب إلى الحافظة عند رقم غير صالح', () async {
    final copied = <String>[];
    final copier = GuardianPhoneCopier(
      write: (value) async => copied.add(value),
    );

    expect(await copier.copy('123'), isNull);
    expect(copied, isEmpty);
  });
}
