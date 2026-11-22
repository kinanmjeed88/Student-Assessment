import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:almoktaber/core/services/guardian_send_coordinator.dart';

void main() {
  test('يمنع تنفيذ عملية ثانية أثناء العملية الأولى', () async {
    final coordinator = GuardianSendCoordinator();
    final gate = Completer<void>();

    final first = coordinator.run(() => gate.future);
    expect(coordinator.isRunning, isTrue);
    expect(
      () => coordinator.run(() async => 'ثانية'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('ALREADY_IN_PROGRESS'),
        ),
      ),
    );

    gate.complete();
    await expectLater(first, completes);
    expect(coordinator.isRunning, isFalse);
  });

  test('يعيد السماح بالمحاولة بعد الفشل', () async {
    final coordinator = GuardianSendCoordinator();

    await expectLater(
      coordinator.run<void>(() async => throw StateError('فشل')),
      throwsStateError,
    );
    expect(coordinator.isRunning, isFalse);
    await expectLater(coordinator.run(() async => 'نجاح'), completion('نجاح'));
  });
}
