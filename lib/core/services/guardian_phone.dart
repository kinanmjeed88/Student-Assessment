/// توحيد رقم هاتف ولي الأمر والتحقق منه قبل بدء مشاركة التقرير.
///
/// تستخدم روابط `wa.me` أرقاماً دولية بلا إشارة `+` ولا مسافات. لذلك تُحوَّل
/// الأرقام العربية والفارسية إلى لاتينية، ويُضاف رمز العراق إلى الرقم المحلي.
abstract final class GuardianPhone {
  static const String defaultCountryCode = '964';
  static const int minLength = 8;
  static const int maxLength = 15;

  /// يعيد الرقم الدولي بصيغة أرقام فقط، أو سلسلة فارغة إذا كان الإدخال فارغاً.
  static String normalize(String raw) {
    final digits = _toLatinDigits(raw).replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';

    final withoutInternationalPrefix =
        digits.startsWith('00') ? digits.substring(2) : digits;
    if (withoutInternationalPrefix.startsWith(defaultCountryCode)) {
      return withoutInternationalPrefix;
    }

    var local = withoutInternationalPrefix;
    if (local.startsWith('0')) local = local.substring(1);

    // توجد بيانات قديمة بطول تسعة أرقام بعد الصفر، بينما الرقم العراقي
    // المتداول حالياً يتكون من عشرة أرقام بعده. ندعم الصيغتين بلا تعديل
    // للقيم الدولية التي تخص بلداً آخر.
    if (local.startsWith('7') && (local.length == 9 || local.length == 10)) {
      return '$defaultCountryCode$local';
    }
    return local;
  }

  /// رسالة خطأ عربية، أو `null` عندما يكون الرقم صالحاً للاستخدام الدولي.
  static String? validationError(String raw) {
    final normalized = normalize(raw);
    if (normalized.isEmpty) {
      return 'أضف رقم هاتف ولي الأمر في ملف الطالب أولاً.';
    }
    if (!RegExp(r'^[1-9]\d+$').hasMatch(normalized) ||
        normalized.length < minLength ||
        normalized.length > maxLength) {
      return 'رقم ولي الأمر غير صالح. أدخل الرقم مع رمز الدولة.';
    }
    return null;
  }

  /// رابط محادثة بنص جاهز. لا يدعم هذا الرابط إرفاق ملف التقرير.
  static Uri chatUri({required String phone, required String text}) =>
      Uri.https('wa.me', '/$phone', <String, String>{'text': text});

  static String _toLatinDigits(String value) {
    const arabicStart = 0x0660;
    const persianStart = 0x06F0;
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      if (rune >= arabicStart && rune <= arabicStart + 9) {
        buffer.write(rune - arabicStart);
      } else if (rune >= persianStart && rune <= persianStart + 9) {
        buffer.write(rune - persianStart);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }
}
