# تدقيق أيقونة التطبيق

## القرار المعتمد

تم اعتماد `assets/images/favicon.png` كمصدر وحيد ورسمي لأيقونة تطبيق «سجل الطالب». الملف عبارة عن صورة مربعة عالية الدقة لدفتر أزرق مع علامة تحقق خضراء، وهي مناسبة للهوية الأكاديمية للتطبيق ولا تحتوي على نص قد يتشوه عند التصغير.

## آلية الربط

يربط `AndroidManifest.xml` أيقونة التطبيق بالاسم `@mipmap/ic_launcher`. يولّد `scripts/generate_android_assets.py` موارد launcher التقليدية من `favicon.png` للكثافات `mdpi` و`hdpi` و`xhdpi` و`xxhdpi` و`xxxhdpi`، كما يولد foreground شفافاً لـ Adaptive Icon داخل `drawable-nodpi/ic_launcher_foreground.png`.

يظل ملف `mipmap-anydpi-v26/ic_launcher.xml` هو مورد Adaptive Icon لأجهزة Android 8 وما بعدها، بينما تستخدم أجهزة Android الأقدم صور `mipmap-*/ic_launcher.png`. بهذه الطريقة يستخدم النظام المصدر نفسه في جميع الحالات دون اختلاف بين كثافات الشاشة أو إصدارات Android.

## إزالة المصادر القديمة

تم حذف `app_icon.png` وملفات `android_icon_background.png` و`android_icon_foreground.png` و`android_icon_monochrome.png` من `assets/images` لأنها لم تعد مصادر معتمدة للأيقونة. بقي `favicon.png` هو المصدر الوحيد للأيقونة، مع إبقاء `splash_icon.png` كأصل مستقل لشاشة البداية وليس كأيقونة launcher.

## التحقق

يتحقق `scripts/verify_android_icon.py` من وجود `favicon.png`، وربط Manifest بالاسم الصحيح، ووجود Adaptive Icon، وسلامة foreground بصيغة RGBA وبأبعاد 1024×1024، ووجود جميع موارد launcher بالأحجام الصحيحة. وقد اجتاز الفحص بعد إعادة التوليد.

## ملاحظة التثبيت

بعد تثبيت APK الجديد، قد يحتفظ بعض مشغلات Android بالأيقونة القديمة في ذاكرة مؤقتة. إذا لم تتحدث الأيقونة مباشرة، يجب حذف النسخة القديمة من الجهاز ثم تثبيت APK الجديد، أو إعادة تشغيل المشغّل/الجهاز.
