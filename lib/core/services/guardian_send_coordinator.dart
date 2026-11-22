/// يمنع تشغيل أكثر من طلب تجهيز أو مشاركة في الوقت نفسه.
class GuardianSendCoordinator {
  bool _running = false;

  bool get isRunning => _running;

  Future<T> run<T>(Future<T> Function() action) {
    if (_running) throw StateError('GUARDIAN_SEND_ALREADY_IN_PROGRESS');
    _running = true;
    return Future<T>.sync(action).whenComplete(() => _running = false);
  }
}
