import 'package:flutter_test/flutter_test.dart';

import 'package:almoktaber/core/services/guardian_phone_copier.dart';

void main() {
  test('ينسخ الرقم بالصيغة الدولية الموحدة', () async {
    final copied = <String>[];
    final copier = GuardianPhoneCopier(
      write: (value) async => copied.add(value),
    );

    final result = await copier.copy('+964 700 123 456');

    expect(result, '964700123456');
    expect(copied, ['964700123456']);
  });

  test('لا ينسخ رقماً غير صالح', () async {
    final copied = <String>[];
    final copier = GuardianPhoneCopier(
      write: (value) async => copied.add(value),
    );

    expect(await copier.copy('123'), isNull);
    expect(copied, isEmpty);
  });
}
