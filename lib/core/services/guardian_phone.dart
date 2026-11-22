/// توحيد وتحقق من رقم هاتف ولي الأمر قبل استخدامه في رابط واتساب.
///
/// واتساب يقبل في رابط `wa.me` الأرقام الدولية دون إشارة `+` ولا مسافات،
/// لذلك تُحوَّل الأرقام العربية إلى اللاتينية ويُضاف رمز الدولة عند الحاجة.
abstract final class GuardianPhone {
  /// الرمز المستخدم للأرقام المحلية التي تبدأ بصفر (العراق).
  static const String defaultCountryCode = '964';

  /// الحدود المقبولة لرقم E.164 بعد التحويل.
  static const int minLength = 8;
  static const int maxLength = 15;

  /// يعيد صيغة دولية صالحة لـ wa.me، أو سلسلة فارغة إذا تعذر ذلك.
  static String normalize(String raw) {
    final digits = _toLatinDigits(raw).replaceAll(RegExp(r'\D'), '');
    final withoutInternationalPrefix =
        digits.startsWith('00') ? digits.substring(2) : digits;
    if (withoutInternationalPrefix.startsWith(defaultCountryCode)) {
      return withoutInternationalPrefix;
    }

    var local = withoutInternationalPrefix;
    if (local.startsWith('0')) local = local.substring(1);
    if (local.length == 9 && local.startsWith('7')) {
      return '$defaultCountryCode$local';
    }
    return local;
  }

  /// رسالة خطأ بالعربية، أو `null` عندما يكون الرقم قابلاً للاستخدام.
  static String? validationError(String raw) {
    final normalized = normalize(raw);
    if (normalized.isEmpty) return 'أضف رقم هاتف ولي الأمر في ملف الطالب أولاً.';
    if (normalized.length < minLength || normalized.length > maxLength) {
      return 'رقم ولي الأمر غير صالح. أدخل الرقم مع رمز الدولة.';
    }
    return null;
  }

  /// رابط محادثة مع نص جاهز; واتساب لا يدعم إرفاق ملفات عبر هذا الرابط.
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
