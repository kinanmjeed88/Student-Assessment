# تدقيق أيقونة التطبيق

## النتيجة الأولية

الصورة المطلوبة موجودة فعلياً في `assets/images/app_icon.png` بأبعاد 1920×1920. لكن هذا المسار هو asset عام لتطبيق Flutter، ولا يحدد تلقائياً أيقونة تطبيق Android.

ملف Android Manifest يربط الأيقونة بالاسم `@mipmap/ic_launcher`. موارد Android الحالية تحتوي على `mipmap-anydpi-v26/ic_launcher.xml` الذي يربط foreground فقط بـ `@drawable/ic_launcher_foreground`، كما توجد صور `mipmap-*/ic_launcher.png` مولدة مسبقاً.

السبب المرجح لعدم ظهور صورة `app_icon.png` هو أن صورة التطبيق الكاملة داخل `assets/images` لم تُربط مباشرة بموارد `mipmap` المستخدمة من Manifest. بدلاً من ذلك، يعتمد Android على موارد launcher منفصلة، وقد تكون هذه الموارد قديمة أو adaptive icon غير مكتملة الخلفية.

## المطلوب في الإصلاح

يجب تحويل الصورة المطلوبة إلى موارد launcher واضحة لكل كثافات Android، وربط adaptive icon بخلفية وforeground ثابتين، مع الإبقاء على fallback للأجهزة قبل Android 8. يجب أيضاً التحقق من عدم قص الشعار داخل safe zone الخاصة بـ adaptive icon، ثم بناء APK جديد والتحقق من موارد `@mipmap/ic_launcher` داخل الحزمة.

## نتيجة المعاينة البصرية

المعاينة تؤكد أن `android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png` يحتوي على الشعار الأكاديمي، لكنه يحتوي على مساحة شفافة كبيرة حول صورة مربعة كاملة. هذا يجعل العلامة أصغر عند تطبيق قناع adaptive icon، كما أن الاعتماد على `assets/images/app_icon.png` وحده لا يربط الصورة تلقائياً بـ Android Manifest.

الإصلاح الأنسب هو إعادة توليد الموارد من المصدر نفسه مع ضبط adaptive icon بطريقة صريحة، وإضافة نسخة legacy مرتبطة بالاسم نفسه، ثم فحص APK النهائي للتأكد من احتوائه على الموارد الجديدة.

## مقارنة مصادر الأيقونة

`assets/images/android_icon_foreground.png` يحتوي على رمز كتاب مع علامة تحقق، وهو مختلف بصرياً عن `assets/images/app_icon.png` التي تحتوي على ملف الطالب والشعار الأكاديمي. لذلك لا يجوز استخدامه مصدراً للـ launcher في هذا الطلب؛ المصدر الصحيح للأيقونة المطلوبة هو `app_icon.png`، مع توليد موارد Android منه بشكل موحد.

## التدقيق النهائي لمصادر assets/images

تحتوي `assets/images` على عدة مصادر مختلفة: `android_icon_background.png` هو قالب إرشادي فاتح وليس خلفية launcher نهائية، و`android_icon_monochrome.png` يحتوي علامة رمادية مختلفة، بينما `android_icon_foreground.png` يحتوي رمز كتاب مع علامة تحقق. هذه الملفات لا تطابق الشعار الأكاديمي الموجود في `app_icon.png`. لذلك يجب اعتماد مصدر واحد فقط للـ launcher وعدم خلط هذه الملفات في موارد Android.

الربط الحالي يستخدم `@mipmap/ic_launcher`، لكن مولد الموارد يعتمد على `app_icon.png` ويضع صورة مربعة كاملة داخل foreground شفاف. هذا يترك احتمال قص/تصغير الشعار داخل قناع adaptive icon. الإصلاح النهائي سيستخدم الصورة المطلوبة كمورد launcher مباشر، مع إبقاء adaptive resource متوافقاً، وفحص الحزمة الناتجة نفسها.
