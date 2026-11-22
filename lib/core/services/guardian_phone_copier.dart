import 'package:flutter/services.dart';

import 'guardian_phone.dart';

/// ينسخ رقم ولي الأمر بصيغته الدولية دون تغيير البيانات المحفوظة للطالب.
class GuardianPhoneCopier {
  GuardianPhoneCopier({Future<void> Function(String value)? write})
      : _write = write ??
            ((value) => Clipboard.setData(ClipboardData(text: value)));

  final Future<void> Function(String value) _write;

  /// يعيد الرقم المنسوخ، أو `null` إذا كان الإدخال غير صالح.
  Future<String?> copy(String rawPhone) async {
    if (GuardianPhone.validationError(rawPhone) != null) return null;
    final normalized = GuardianPhone.normalize(rawPhone);
    await _write(normalized);
    return normalized;
  }
}
