import 'dart:io';

import 'package:flutter/foundation.dart';

import 'guardian_report_service.dart';
import 'guardian_send_coordinator.dart';

/// الحالات تصف ما نفّذه التطبيق فقط، ولا تعني أن واتساب أرسل الرسائل فعلياً.
enum GuardianSendStage {
  idle,
  preparing,
  messageReady,
  messageChatOpened,
  fileReady,
  fileSharing,
  completed,
  failed,
}

class GuardianSendSnapshot {
  const GuardianSendSnapshot({
    required this.stage,
    this.message = '',
    this.error = '',
  });

  final GuardianSendStage stage;
  final String message;
  final String error;

  bool get isBusy =>
      stage == GuardianSendStage.preparing ||
      stage == GuardianSendStage.fileSharing;
}

/// يجهّز النص والملف مرة واحدة، ثم يدير مرحلتين منفصلتين:
/// فتح محادثة بالنص عبر رابط wa.me، ثم تسليم الملف وحده (حفظه باختيار
/// المستخدم على ويندوز ٧) دون إعادة توليده.
class GuardianSendSession {
  GuardianSendSession({GuardianSendCoordinator? coordinator})
      : _coordinator = coordinator ?? GuardianSendCoordinator();

  final GuardianSendCoordinator _coordinator;
  final ValueNotifier<GuardianSendSnapshot> state =
      ValueNotifier(const GuardianSendSnapshot(stage: GuardianSendStage.idle));

  PreparedGuardianReport? _report;
  String? _filePath;
  String? _normalizedPhone;
  bool _messageChatOpened = false;

  PreparedGuardianReport? get report => _report;
  String? get filePath => _filePath;
  String? get normalizedPhone => _normalizedPhone;
  bool get isBusy => _coordinator.isSending;
  bool get messageChatOpened => _messageChatOpened;

  bool get hasPreparedFile {
    final path = _filePath;
    return _report != null && path != null && File(path).existsSync();
  }

  /// يجهّز التقرير والنص مرة واحدة إن لم يكونا جاهزين، ثم يفتح محادثة النص.
  ///
  /// يمكن استدعاؤها مجدداً لإعادة المحاولة دون إعادة إنشاء التقرير أو الملف.
  Future<void> startMessage({
    required Future<PreparedGuardianReport> Function() prepare,
    required Future<String> Function(PreparedGuardianReport report) writeFile,
    required Future<bool> Function(PreparedGuardianReport report) openChat,
  }) async {
    if (_coordinator.isSending) return;
    try {
      await _coordinator.run(() async {
        _emit(GuardianSendStage.preparing, 'جارٍ تجهيز التقرير والنص...');
        _report ??= await prepare();
        _normalizedPhone ??= _report!.guardianPhone;
        _filePath ??= await writeFile(_report!);
        _emit(
          GuardianSendStage.messageReady,
          'تم تجهيز النص والملف. فتح محادثة واتساب لإرسال الرسالة.',
        );
        final opened = await openChat(_report!);
        if (!opened) {
          throw const FormatException('تعذر فتح محادثة واتساب.');
        }
        _messageChatOpened = true;
        _emit(
          GuardianSendStage.messageChatOpened,
          'تم فتح المحادثة؛ أرسل النص ثم ارجع إلى التطبيق.',
        );
        _emit(
          GuardianSendStage.fileReady,
          'أرسل النص في واتساب، ثم ارجع إلى التطبيق لإرسال ملف التقرير.',
        );
      });
    } catch (error) {
      _emit(
        GuardianSendStage.failed,
        'تعذر بدء الإرسال.',
        error: _errorText(error),
      );
    }
  }

  /// يسلّم الملف المجهز وحده إلى المستخدم (الحفظ باختياره على ويندوز ٧)،
  /// دون إعادة توليده أو إرفاق نص جديد.
  Future<void> shareFile({
    required Future<GuardianShareOutcome> Function(
      PreparedGuardianReport report,
      String filePath,
    ) share,
  }) async {
    if (!hasPreparedFile) {
      _emit(
        GuardianSendStage.failed,
        'الملف غير جاهز.',
        error: 'أعد بدء العملية لتجهيز التقرير مرة أخرى.',
      );
      return;
    }
    if (_coordinator.isSending) return;
    try {
      await _coordinator.run(() async {
        _emit(GuardianSendStage.fileSharing, 'جارٍ فتح حفظ ملف التقرير...');
        final outcome = await share(_report!, _filePath!);
        if (outcome == GuardianShareOutcome.dismissed) {
          _emit(
            GuardianSendStage.fileReady,
            'تم إلغاء حفظ الملف؛ يمكنك المحاولة مرة أخرى.',
          );
          return;
        }
        _emit(
          GuardianSendStage.completed,
          'تم حفظ ملف التقرير؛ أرفقه في رسالة واتساب لإكمال الإرسال بنفسك.',
        );
      });
    } catch (error) {
      _emit(
        GuardianSendStage.failed,
        'تعذر حفظ الملف.',
        error: _errorText(error),
      );
    }
  }

  void _emit(GuardianSendStage stage, String message, {String error = ''}) {
    state.value = GuardianSendSnapshot(
      stage: stage,
      message: message,
      error: error,
    );
  }

  String _errorText(Object error) => error is FormatException
      ? error.message
      : error.toString();

  /// يُحذف الملف المؤقت عند إغلاق النافذة أو إلغاء العملية فقط،
  /// وليس قبل انتهاء خطوة الملف.
  Future<void> dispose() async {
    final path = _filePath;
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {
          // فشل الحذف المؤقت لا يغيّر بيانات الطالب أو نتيجة الحفظ.
        }
      }
    }
    _filePath = null;
    _report = null;
    _normalizedPhone = null;
    _messageChatOpened = false;
    state.dispose();
  }
}
