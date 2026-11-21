import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'guardian_phone.dart';

/// قناة المنصة الأصلية المخصصة لتجربة التوجيه المباشر إلى واتساب.
const String whatsappDirectChannel = 'com.almoktaber/whatsapp_report';

/// الحزم التي يمكن اكتشافها صراحةً عبر `<queries>` في Manifest.
enum WhatsAppPackage {
  whatsapp('com.whatsapp'),
  whatsappBusiness('com.whatsapp.w4b');

  const WhatsAppPackage(this.packageName);

  final String packageName;

  static WhatsAppPackage? fromPackageName(String? value) => switch (value) {
        'com.whatsapp' => WhatsAppPackage.whatsapp,
        'com.whatsapp.w4b' => WhatsAppPackage.whatsappBusiness,
        _ => null,
      };
}

/// نتيجة تشغيل Intent فقط؛ لا تعني وصول الرسالة أو ضغط المستخدم على إرسال.
enum WhatsAppDirectStatus { launched, notFound, failed }

class WhatsAppDirectResult {
  const WhatsAppDirectResult({
    required this.status,
    this.package,
    this.message = '',
  });

  final WhatsAppDirectStatus status;
  final WhatsAppPackage? package;
  final String message;

  bool get launched => status == WhatsAppDirectStatus.launched;

  /// رسالة واضحة لا تدّعي أن المستخدم أرسل الرسالة فعلاً.
  String get statusMessage => switch (status) {
        WhatsAppDirectStatus.launched =>
          'تم فتح واتساب فقط؛ تأكد من المحادثة ثم اضغط إرسال داخل التطبيق.',
        WhatsAppDirectStatus.notFound =>
          'واتساب غير مثبت على الجهاز.',
        WhatsAppDirectStatus.failed =>
          message.isEmpty ? 'تعذر فتح واتساب.' : 'تعذر فتح واتساب: $message',
      };

  static WhatsAppDirectResult fromMap(Map<String, Object?>? response) {
    final status = switch (response?['status']) {
      'launched' => WhatsAppDirectStatus.launched,
      _ => WhatsAppDirectStatus.failed,
    };
    return WhatsAppDirectResult(
      status: status,
      package: WhatsAppPackage.fromPackageName(response?['package']?.toString()),
      message: response?['message']?.toString() ?? '',
    );
  }
}

/// بيانات Intent التي تُرسل إلى الطبقة الأصلية، قابلة للاختبار دون جهاز.
class WhatsAppDirectPayload {
  const WhatsAppDirectPayload({
    required this.phone,
    required this.text,
    required this.filePath,
    required this.fileName,
    required this.mimeType,
    required this.package,
  });

  final String phone;
  final String text;
  final String filePath;
  final String fileName;
  final String mimeType;
  final WhatsAppPackage package;

  String get jid => WhatsAppDirectJid.fromPhone(phone);

  Map<String, Object?> toArguments() => <String, Object?>{
        'phone': phone,
        'jid': jid,
        'text': text,
        'filePath': filePath,
        'fileName': fileName,
        'mimeType': mimeType,
        'package': package.packageName,
      };
}

abstract final class WhatsAppDirectJid {
  /// صيغة JID الداخلية غير الموثقة التي يستخدمها تكامل ACTION_SEND.
  static String fromPhone(String normalizedPhone) {
    if (normalizedPhone.isEmpty) {
      throw ArgumentError.value(normalizedPhone, 'normalizedPhone', 'رقم فارغ');
    }
    return '$normalizedPhone@s.whatsapp.net';
  }
}

abstract final class WhatsAppDirectSupport {
  /// المسار الأصلي متاح على Android فقط؛ Windows يحتفظ بمسار المشاركة العام.
  static bool shouldOfferDirectSend(TargetPlatform platform) =>
      platform == TargetPlatform.android;
}

/// يغلّف استدعاءات MethodChannel ويحوّلها إلى نتائج صريحة غير مضلّلة.
class WhatsappDirectShareService {
  WhatsappDirectShareService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(whatsappDirectChannel);

  final MethodChannel _channel;

  Future<List<WhatsAppPackage>> availablePackages() async {
    final packages = await _channel.invokeListMethod<String>('availablePackages');
    return packages
            ?.map(WhatsAppPackage.fromPackageName)
            .whereType<WhatsAppPackage>()
            .toList(growable: false) ??
        const <WhatsAppPackage>[];
  }

  Future<WhatsAppDirectResult> openChat({
    required String phone,
    required String text,
    WhatsAppPackage? package,
  }) async {
    final phoneError = GuardianPhone.validationError(phone);
    if (phoneError != null) {
      return WhatsAppDirectResult(
        status: WhatsAppDirectStatus.failed,
        message: phoneError,
      );
    }
    final normalized = GuardianPhone.normalize(phone);
    return _invoke(
      'openChat',
      <String, Object?>{
        'phone': normalized,
        'text': text,
        if (package != null) 'package': package.packageName,
      },
    );
  }

  Future<WhatsAppDirectResult> shareToChat({
    required String phone,
    required String text,
    required String filePath,
    required String fileName,
    required String mimeType,
    required WhatsAppPackage package,
  }) async {
    final phoneError = GuardianPhone.validationError(phone);
    if (phoneError != null) {
      return WhatsAppDirectResult(
        status: WhatsAppDirectStatus.failed,
        message: phoneError,
      );
    }
    final file = File(filePath);
    if (!await file.exists()) {
      return const WhatsAppDirectResult(
        status: WhatsAppDirectStatus.failed,
        message: 'ملف التقرير غير موجود.',
      );
    }
    if (await file.length() == 0) {
      return const WhatsAppDirectResult(
        status: WhatsAppDirectStatus.failed,
        message: 'ملف التقرير فارغ.',
      );
    }

    final payload = WhatsAppDirectPayload(
      phone: GuardianPhone.normalize(phone),
      text: text,
      filePath: filePath,
      fileName: fileName,
      mimeType: mimeType,
      package: package,
    );
    return _invoke('shareToChat', payload.toArguments());
  }

  /// يكتب التقرير في cache-path الذي يسمح به FileProvider فقط.
  ///
  /// البادئة الزمنية تمنع استبدال ملف ما زال واتساب يقرؤه في محاولة سابقة.
  Future<String> writeReportFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.isEmpty) {
      throw const FormatException('تعذر إنشاء ملف التقرير.');
    }
    final directory = await getTemporaryDirectory();
    final safeName = fileName
        .replaceAll(RegExp(r'[\\/:*?"<>|\r\n]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    final file = File(
      '${directory.path}${Platform.pathSeparator}${DateTime.now().microsecondsSinceEpoch}_$safeName',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<WhatsAppDirectResult> _invoke(
    String method,
    Map<String, Object?> arguments,
  ) async {
    try {
      final response = await _channel.invokeMapMethod<String, Object?>(
        method,
        arguments,
      );
      return WhatsAppDirectResult.fromMap(response);
    } on PlatformException catch (error) {
      return switch (error.code) {
        'WHATSAPP_NOT_FOUND' => const WhatsAppDirectResult(
            status: WhatsAppDirectStatus.notFound,
          ),
        _ => WhatsAppDirectResult(
            status: WhatsAppDirectStatus.failed,
            message: error.message ?? error.code,
          ),
      };
    } catch (error) {
      return WhatsAppDirectResult(
        status: WhatsAppDirectStatus.failed,
        message: error.toString(),
      );
    }
  }
}
