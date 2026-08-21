# تشخيص إغلاق تطبيق Windows على Winlator

## المؤشرات من الكود

في `lib/main.dart` يستدعي التطبيق `await notificationService.initialize()` قبل `runApp()`. لذلك أي فشل في إضافة Windows أو Wine أثناء تهيئة الإشعارات يؤدي إلى إغلاق التطبيق قبل ظهور الواجهة.

في `lib/core/notifications/notification_service.dart` تُمرر إعدادات `WindowsInitializationSettings` إلى `flutter_local_notifications`، وتشمل هوية التطبيق `AlMoktaber.StudentRecord` وGUID. هذا المسار مصمم لإشعارات Windows Toast الأصلية، وقد لا يعمل داخل Wine/Winlator بنفس طريقة Windows 10/11 الحقيقي.

الإصدار المستخدم هو `flutter_local_notifications 22.3.0` مع Flutter `>=3.38.1`. التطبيق مبني كنسخة Windows x64، ويحتاج كامل مجلد الإصدار، وليس EXE منفردًا.

## الاحتمال الأقوى

الاحتمال الأقوى أن Winlator/Wine يفشل في تهيئة Windows Toast/WinRT أو أن التطبيق يفتقد مكوّن Runtime مطلوب، وبما أن التهيئة غير محمية بـtry/catch فإن التطبيق يُغلق قبل `runApp()`.

## اتجاه الإصلاح الآمن

يجب جعل تهيئة الإشعارات غير قاتلة: تشغيل `runApp()` حتى لو فشلت تهيئة إشعارات Windows، مع تسجيل الخطأ وتعطيل الإشعارات فقط على Winlator. لا ينبغي تغيير قنوات أو سلوك Android. كما يجب اختبار تشغيل نسخة بدون `WindowsInitializationSettings` أو بنسخة Windows notifications disabled لتحديد هل الإضافة هي سبب الانهيار.

## المراجع

- https://github.com/brunodev85/winlator
- https://docs.flutter.dev/platform-integration/windows/building
- https://pub.dev/packages/flutter_local_notifications
