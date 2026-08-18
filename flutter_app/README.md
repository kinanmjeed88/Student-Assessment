# حليف القرآن — Flutter migration baseline

هذا المجلد هو أساس الهجرة الأصلي إلى Flutter، بينما يبقى مشروع React Native/Expo في جذر المستودع للمقارنة المرجعية. يعتمد الأساس على Feature-First مع فصل واضح بين `core`, `data`, `domain`, و`presentation`. التخزين محلي بالكامل عبر Isar، وإدارة الحالة عبر Riverpod، والواجهة عربية RTL من جذور `MaterialApp`.

## التشغيل الأول

يتطلب التشغيل Flutter SDK حديثاً وAndroid SDK. بعد الدخول إلى هذا المجلد شغّل `flutter pub get`، ثم ولّد ملفات Isar المشتقة بالأمر `dart run build_runner build --delete-conflicting-outputs`. الملف `lib/core/database/isar_models.g.dart` لا يُكتب يدوياً؛ فهو ناتج حتمي من `isar_community_generator` ويجب أن يبقى ضمن ملفات البناء المولدة أو يُحفظ في المستودع وفق سياسة الفريق.

بعد ذلك شغّل `flutter analyze` ثم `flutter test`. لا يُسمح بإنشاء Release قبل نجاح التحليل والاختبارات واختبار استعادة نسخة JSON على جهاز Android تجريبي. لبناء APK وAAB استخدم `flutter build apk --release` و`flutter build appbundle --release` بعد إدخال إعدادات التوقيع من البيئة الخارجية.

## سياسة التوقيع

لا تُحفظ كلمات مرور keystore أو ملفه داخل المستودع. يعتمد إعداد Android النهائي على متغيرات بيئة أو GitHub Actions secrets، ويجب إدخال `key.properties` من خارج Git قبل البناء. يجب الحفاظ على package name `com.almoktaber` في كل بيئات debug وrelease حتى لا تنقطع هوية التطبيق.

## ملاحظة بيئية

لم يكن Flutter/Dart SDK متاحاً في بيئة الاستقصاء الحالية؛ لذلك أُنجزت مراجعة ساكنة للملفات ولم يُدّعَ نجاح `flutter analyze` أو إصدار APK داخل هذه الجلسة. يجب تنفيذ أمر التوليد والتحليل والبناء في بيئة Flutter CI قبل اعتماد الإصدار.
