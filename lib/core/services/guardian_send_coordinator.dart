/// يمنع تشغيل أكثر من عملية إرسال في آن واحد عند الضغط المتكرر على الزر.
///
/// الفئة صغيرة وخالصة من الواجهة لكي يمكن اختبار سلوك المنع آلياً.
class GuardianSendCoordinator {
  bool _sending = false;

  bool get isSending => _sending;

  /// ينفّذ [action] مرة واحدة فقط طوال فترة نشاطه.
  ///
  /// أي محاولة ثانية أثناء التنفيذ تُرفض بـ `StateError` بدل فتح واتساب مرتين.
  Future<T> run<T>(Future<T> Function() action) {
    if (_sending) {
      throw StateError('SEND_ALREADY_IN_PROGRESS');
    }
    _sending = true;
    return Future<T>.sync(action).whenComplete(() => _sending = false);
  }
}
