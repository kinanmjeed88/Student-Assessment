import 'package:flutter/services.dart';

import 'guardian_phone.dart';

/// ينسخ رقم ولي الأمر بالصيغة الدولية دون تعديل بيانات الطالب.
class GuardianPhoneCopier {
  GuardianPhoneCopier({Future<void> Function(String value)? write})
      : _write = write ??
            ((value) => Clipboard.setData(ClipboardData(text: value)));

  final Future<void> Function(String value) _write;

  /// لا ينسخ شيئاً عند رقم غير صالح، ويعيد الرقم المنسوخ أو `null`.
  Future<String?> copy(String rawPhone) async {
    if (GuardianPhone.validationError(rawPhone) != null) return null;
    final normalized = GuardianPhone.normalize(rawPhone);
    await _write(normalized);
    return normalized;
  }
}
