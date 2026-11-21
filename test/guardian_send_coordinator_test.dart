import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:almoktaber/core/services/guardian_send_coordinator.dart';

void main() {
  test('يمنع تنفيذ عملية ثانية أثناء العملية الأولى', () async {
    final coordinator = GuardianSendCoordinator();
    final gate = Completer<void>();

    final first = coordinator.run(() => gate.future);
    expect(coordinator.isSending, isTrue);
    expect(
      () => coordinator.run(() async => 'ثانية'),
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('SEND_ALREADY_IN_PROGRESS'),
      )),
    );

    gate.complete();
    await expectLater(first, completes);
    expect(coordinator.isSending, isFalse);
  });

  test('يعيد السماح بالإرسال بعد فشل العملية الأولى', () async {
    final coordinator = GuardianSendCoordinator();

    await expectLater(
      coordinator.run<void>(() async => throw StateError('فشل')),
      throwsA(isA<StateError>()),
    );
    expect(coordinator.isSending, isFalse);
    await expectLater(coordinator.run(() async => 'نجاح'), completion('نجاح'));
  });
}
