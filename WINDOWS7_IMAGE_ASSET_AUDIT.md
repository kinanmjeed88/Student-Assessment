# Windows 7 image asset audit

تمت معاينة أصول Android المشتركة في 21 Aug 2026:

- `assets/images/splash_icon.png`: الشعار الكامل لسجل الطالب، أبعاده 1024×1024، وهو مطابق للأصل الموجود في `main`.
- `android/app/src/main/res/drawable-nodpi/launch_image.png`: نسخة 384×384 من الشعار نفسه تقريباً، مخصصة لشاشة الإقلاع في Android.
- `assets/images/favicon.png` و`assets/images/splash_icon.png` لهما البصمة نفسها في فرع Windows الحالي وفرع `main`.

القرار المبدئي: استخدام `assets/images/splash_icon.png` كصورة هوية داخل واجهة Windows، لأنها الأصل المشترك عالي الدقة المستخدم في المشروع، مع إبقاء عنوان التطبيق الظاهر `سجل الطالب` بالعربية.
