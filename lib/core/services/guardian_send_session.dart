import 'dart:io';

import 'package:flutter/foundation.dart';

import 'guardian_report_service.dart';
import 'guardian_send_coordinator.dart';

/// المرحلة التي نفذها التطبيق فقط؛ لا تعني أن المستلم استلم الرسالة.
enum GuardianSendStage {
  idle,
  preparing,
  textSharing,
  fileReady,
  fileSharing,
  completed,
  failed,
}

enum GuardianRetryStep { text, file }

class GuardianSendSnapshot {
  const GuardianSendSnapshot({
    required this.stage,
    this.message = '',
    this.error = '',
    this.warning = '',
    this.retryStep,
  });

  final GuardianSendStage stage;
  final String message;
  final String error;
  final String warning;
  final GuardianRetryStep? retryStep;

  bool get isBusy =>
      stage == GuardianSendStage.preparing ||
      stage == GuardianSendStage.textSharing ||
      stage == GuardianSendStage.fileSharing;
}

/// يدير تجهيزاً واحداً، ثم مشاركة النص والملف في طلبين منفصلين.
class GuardianSendSession {
  GuardianSendSession({
    GuardianSendCoordinator? coordinator,
    Future<void> Function(String path)? removeFile,
  })  : _coordinator = coordinator ?? GuardianSendCoordinator(),
        _removeFile = removeFile ?? _deleteFile;

  final GuardianSendCoordinator _coordinator;
  final Future<void> Function(String path) _removeFile;
  final ValueNotifier<GuardianSendSnapshot> state = ValueNotifier(
    const GuardianSendSnapshot(stage: GuardianSendStage.idle),
  );

  PreparedGuardianReport? _report;
  String? _filePath;
  bool _autoCopyAttempted = false;
  bool _autoCopySucceeded = false;
  bool _textShareRequested = false;
  bool _fileShareRequested = false;
  bool _disposed = false;
  String _copyWarning = '';

  PreparedGuardianReport? get report => _report;
  String? get filePath => _filePath;
  bool get autoCopyAttempted => _autoCopyAttempted;
  bool get autoCopySucceeded => _autoCopySucceeded;
  bool get textShareRequested => _textShareRequested;
  bool get fileShareRequested => _fileShareRequested;
  bool get isBusy => _coordinator.isRunning;

  bool get hasPreparedFile {
    final path = _filePath;
    return _report != null && path != null && File(path).existsSync();
  }

  /// يجهّز التقرير والملف مرة واحدة، ينسخ الرقم مرة واحدة، ثم يشارك النص.
  /// تعيد المحاولة استخدام التقرير والملف المخزنين ولا تعيد نسخ الرقم تلقائياً.
  Future<void> startText({
    required Future<PreparedGuardianReport> Function() prepare,
    required Future<String> Function(PreparedGuardianReport report) writeFile,
    required Future<bool> Function(String normalizedPhone) copyPhone,
    required Future<GuardianShareOutcome> Function(
      PreparedGuardianReport report,
    ) shareText,
  }) async {
    if (_disposed || _coordinator.isRunning || _textShareRequested) return;

    try {
      await _coordinator.run(() async {
        _emit(
          GuardianSendStage.preparing,
          _report == null
              ? 'جارٍ تجهيز نص المعاينة وملف التقرير مرة واحدة...'
              : 'جارٍ استخدام التقرير المجهز للمحاولة مرة أخرى...',
          retryStep: GuardianRetryStep.text,
        );

        if (_report == null) _report = await prepare();
        await _copyPhoneOnce(copyPhone);

        final existingPath = _filePath;
        if (existingPath == null || !File(existingPath).existsSync()) {
          _filePath = await writeFile(_report!);
        }
        if (!hasPreparedFile) {
          throw const FormatException('تعذر حفظ ملف التقرير المجهز.');
        }

        _emit(
          GuardianSendStage.textSharing,
          'جارٍ طلب نافذة مشاركة النص وحده...',
          retryStep: GuardianRetryStep.text,
        );
        final outcome = await shareText(_report!);
        if (outcome == GuardianShareOutcome.dismissed) {
          _emit(
            GuardianSendStage.failed,
            'أُغلقت نافذة مشاركة النص قبل اختيار وجهة.',
            error: 'يمكنك إعادة مشاركة النص دون إعادة تجهيز التقرير.',
            retryStep: GuardianRetryStep.text,
          );
          return;
        }

        _textShareRequested = true;
        _emit(
          GuardianSendStage.fileReady,
          'طُلب فتح مشاركة النص. اختر المستلم وأكد الإرسال بنفسك، ثم شارك ملف التقرير في الخطوة التالية.',
        );
      });
    } catch (error) {
      _emit(
        GuardianSendStage.failed,
        'تعذر تجهيز التقرير أو فتح مشاركة النص.',
        error: _errorText(error),
        retryStep: GuardianRetryStep.text,
      );
    }
  }

  /// يشارك الملف المجهز نفسه وحده. لا يسمح بتكرار الطلب بعد تسليمه للنظام.
  Future<void> shareFile({
    required Future<GuardianShareOutcome> Function(
      PreparedGuardianReport report,
      String filePath,
    ) share,
  }) async {
    if (_disposed || _coordinator.isRunning || _fileShareRequested) return;
    if (!_textShareRequested) {
      _emit(
        GuardianSendStage.failed,
        'يجب بدء مشاركة النص أولاً.',
        error: 'ابدأ العملية من خطوة النص.',
        retryStep: GuardianRetryStep.text,
      );
      return;
    }
    if (!hasPreparedFile) {
      _emit(
        GuardianSendStage.failed,
        'ملف التقرير المجهز غير موجود.',
        error: 'أغلق النافذة وابدأ عملية جديدة لتجهيز الملف.',
        retryStep: GuardianRetryStep.file,
      );
      return;
    }

    try {
      await _coordinator.run(() async {
        _emit(
          GuardianSendStage.fileSharing,
          'جارٍ طلب نافذة مشاركة ملف التقرير وحده...',
          retryStep: GuardianRetryStep.file,
        );
        final outcome = await share(_report!, _filePath!);
        if (outcome == GuardianShareOutcome.dismissed) {
          _emit(
            GuardianSendStage.fileReady,
            'أُغلقت نافذة مشاركة الملف؛ يمكنك إعادة المحاولة بالملف المجهز نفسه.',
          );
          return;
        }

        _fileShareRequested = true;
        _emit(
          GuardianSendStage.completed,
          'طُلب فتح نافذة مشاركة الملف. اختر التطبيق والمستلم وأكد الإرسال بنفسك.',
        );
      });
    } catch (error) {
      _emit(
        GuardianSendStage.failed,
        'تعذر فتح مشاركة ملف التقرير.',
        error: _errorText(error),
        retryStep: GuardianRetryStep.file,
      );
    }
  }

  Future<void> _copyPhoneOnce(
    Future<bool> Function(String normalizedPhone) copyPhone,
  ) async {
    if (_autoCopyAttempted) return;
    _autoCopyAttempted = true;
    try {
      _autoCopySucceeded = await copyPhone(_report!.guardianPhone);
      if (!_autoCopySucceeded) {
        _copyWarning = 'تعذر نسخ الرقم الدولي تلقائياً؛ استخدم زر النسخ اليدوي.';
      }
    } catch (error) {
      _copyWarning =
          'تعذر نسخ الرقم الدولي تلقائياً؛ استخدم زر النسخ اليدوي. (${_errorText(error)})';
    }
  }

  void _emit(
    GuardianSendStage stage,
    String message, {
    String error = '',
    GuardianRetryStep? retryStep,
  }) {
    if (_disposed) return;
    state.value = GuardianSendSnapshot(
      stage: stage,
      message: message,
      error: error,
      warning: _copyWarning,
      retryStep: retryStep,
    );
  }

  String _errorText(Object error) =>
      error is FormatException ? error.message : error.toString();

  /// لا يحذف ملفاً سُلّم إلى واجهة المشاركة، فقد يظل التطبيق المستقبِل
  /// بحاجة إليه. ينظف مخزن التقارير الملفات القديمة في محاولة لاحقة.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final path = _filePath;
    if (path != null && !_fileShareRequested) await _removeFile(path);
    _filePath = null;
    _report = null;
    state.dispose();
  }

  static Future<void> _deleteFile(String path) async {
    final file = File(path);
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // ملف مؤقت فقط.
    }
  }
}
