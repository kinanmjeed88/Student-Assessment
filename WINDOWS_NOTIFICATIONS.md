# دعم Windows 10 وWindows 11 والإشعارات

أضيفت منصة Windows إلى مشروع **سجل الطالب** مع إشعارات Windows مستقلة عن إعدادات Android. يعتمد المسار الجديد على `flutter_local_notifications` مع إعدادات Windows خاصة، بينما بقيت قنوات Android وتفاصيل الأولوية والصوت والاهتزاز والجدولة كما كانت.

## ما تم تغييره

تم إنشاء مجلد `windows/` القياسي بواسطة Flutter، وإضافة إعدادات هوية Windows التالية داخل خدمة الإشعارات:

- اسم التطبيق: `سجل الطالب`
- App User Model ID: `AlMoktaber.StudentRecord`
- GUID ثابت لتفعيل الإشعار: `7e2c3b7a-3d2c-4e0d-a3d9-0d2c5d2a6b31`

تستخدم إشعارات السلوك والمتابعة الآن `NotificationDetails` تحتوي على فرع Android الأصلي وفرع Windows مستقل. يختار Flutter الفرع المناسب حسب المنصة عند التشغيل؛ لذلك لا يتم إرسال تفاصيل Windows إلى Android ولا تفاصيل Android إلى Windows.

تمت إضافة إعداد `msix_config` مع حزمة `msix` حتى يمكن إنشاء نسخة MSIX ذات هوية Windows مستقرة. هذا مهم خصوصًا لإدارة الإشعارات السابقة وإلغائها، إذ إن Windows يفرض قيودًا على التطبيقات غير المغلفة كـMSIX.

## متطلبات البناء

يجب استخدام Flutter 3.38.1 أو أحدث، وDart 3.10 أو أحدث، لأن إصدار حزمة الإشعارات المختار يعتمد هذه الحدود. على جهاز Windows يجب تثبيت Visual Studio مع workload باسم **Desktop development with C++** ثم تشغيل:

```powershell
flutter doctor -v
flutter pub get
flutter build windows
```

لإنشاء نسخة MSIX بعد تجهيز بيئة Windows:

```powershell
flutter pub run msix:create
```

## سلوك Android

لم تتغير قنوات Android أو `AndroidNotificationDetails` أو إعدادات `AndroidScheduleMode.exactAllowWhileIdle` أو طلب أذونات الإشعارات والمنبهات. التغييرات المطلوبة في استدعاءات الحزمة هي تحديث صيغة معاملات API فقط، لأن الإصدارات الحديثة جعلت معاملات `show` و`zonedSchedule` و`cancel` مسماة. إزالة `uiLocalNotificationDateInterpretation` لا تغير سلوك Android؛ فهذا المعامل أصبح غير موجود في الإصدار الحديث وكان مرتبطًا بواجهات iOS القديمة.

## ملاحظات Windows

الإشعار الفوري يعمل عبر Windows Toast Notifications. جدولة الإشعار لموعد واحد مدعومة، بينما لا تدعم Windows الإشعارات المتكررة عبر `periodicallyShow`. كما أن بعض عمليات إدارة الإشعارات السابقة، مثل الإلغاء بعد إعادة التشغيل أو استرجاع الإشعارات النشطة، تكون أكثر موثوقية عندما يكون التطبيق مثبتًا كـMSIX.

يجب اختبار الإشعارات على Windows 10 وWindows 11 فعليًا، بما في ذلك ظهور النص العربي، الإشعار الفوري، الإشعار المجدول، الإلغاء، الضغط على الإشعار أثناء تشغيل التطبيق، وسلوك التطبيق بعد إعادة التشغيل.

## نتائج الفحص المحلي

نجح `flutter analyze` دون أخطاء، ونجحت الاختبارات الموجودة في المشروع. لم يتم تنفيذ `flutter build windows` داخل بيئة Linux الحالية لأن بناء سطح مكتب Windows النهائي يحتاج بيئة Windows وأدوات Visual Studio الخاصة بها.

## المراجع

1. [flutter_local_notifications على pub.dev](https://pub.dev/packages/flutter_local_notifications): المنصات المدعومة، حد Flutter 3.38.1 للإصدارات الحديثة، وطريقة Windows عبر C++/WinRT وToast Notifications.
2. [سجل تغييرات flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications/changelog): تغييرات الإصدارات 20 و21 و22، بما فيها صيغة المعاملات المسماة، وحدود Flutter وDart، وقيود Windows على الإشعارات المتكررة وهوية MSIX.
3. [وثائق Flutter لمنصة Windows](https://docs.flutter.dev/platform-integration/windows/setup): متطلبات Visual Studio وأدوات C++ لبناء تطبيق Windows.
4. [نظرة Microsoft على Toast Notifications](https://learn.microsoft.com/en-us/windows/apps/design/shell/tiles-and-notifications/toast-notifications-overview): آلية إشعارات Windows الأساسية.
5. [حزمة msix على pub.dev](https://pub.dev/packages/msix): إعداد وإنشاء حزم MSIX من مشروع Flutter.
