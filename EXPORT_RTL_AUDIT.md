# تدقيق تصدير Excel وPDF

## الحالة الحالية

تم فحص `lib/core/services/report_service.dart` و`pubspec.yaml` ومجلد `assets/fonts/`.

## النتائج المؤكدة

1. خدمة PDF تحمل `NotoSansArabic-Regular.ttf` و`NotoSansArabic-Bold.ttf` من assets، وتستخدم `pw.ThemeData.withFont` مع `textDirection: pw.TextDirection.rtl` على `pw.MultiPage`.
2. دالة `_pdfTable` الحالية تستخدم `pw.TableHelper.fromTextArray` مع `cellAlignment: pw.Alignment.centerRight`، لكنها لا تعكس ترتيب `headers` و`rows` صراحة. لذلك لا يكفي ضبط اتجاه النص لإجبار ترتيب الأعمدة المرئي من اليمين إلى اليسار؛ يجب بناء البيانات بترتيب RTL صريح.
3. دالة `_pdfInfoTable` الحالية لا تضبط `textDirection` على الجدول نفسه، كما أن ترتيب خانة الحقل والقيمة يحتاج إلى تعريف صريح للعرض RTL.
4. جداول Excel الحالية تكتب الرؤوس والبيانات بالترتيب المنطقي المعتاد من العمود 0 إلى النهاية، ولا تضبط `horizontalAlign` على نمط الجسم، ولا تطبق عكس ترتيب الأعمدة. هذا يفسر ظهور الأعمدة من اليسار إلى اليمين رغم كون النص عربياً.
5. `excel_plus` يدعم CellStyle والمحاذاة، لكن لم يظهر في وثائقه العامة دعم مباشر لاتجاه ورقة RTL؛ الحل الآمن هو عكس ترتيب الأعمدة والبيانات في التصدير، مع ضبط المحاذاة إلى اليمين للخلايا النصية.
6. الخطان الموجودان هما Noto Sans Arabic Regular/Bold. فحص بيانات الخط أظهر دعمه للعربية، الأرقام اللاتينية الأساسية، ASCII الأساسي، وعلامات الترقيم والرموز الشائعة. لا توجد في المشروع حالياً عائلة fallback منفصلة.
7. ملفات assets/fonts مضافة في `pubspec.yaml`، لذلك التحميل عبر `rootBundle` صحيح من حيث المسار. يلزم إضافة fallback احتياطي أو التحقق المنطقي من سلامة الخط عند بناء الثيم حتى لا تظهر مربعات عند ورود رمز خارج نطاق الخط.

## خطة الإصلاح

- إنشاء مسار موحد لترتيب RTL في Excel يعكس الرؤوس والبيانات وعروض الأعمدة معاً.
- استخدام أنماط Excel منفصلة للنصوص والأرقام، بحيث تكون الخلايا النصية إلى اليمين والأرقام والتواريخ إلى الوسط أو اليمين دون كسر ترتيب الأعمدة.
- جعل كل جدول PDF يمر عبر دالة تطبق `pw.TextDirection.rtl` صراحة، وتعكس الرؤوس والصفوف، وتضع المحاذاة المناسبة لكل خلية.
- تحسين الثيم ليستخدم Noto Sans Arabic كخط أساسي، وإضافة fallback آمن من الخطين المتاحين لتقليل احتمال الرموز غير المعرفة.
- توليد عينات XLSX وPDF وفحص بنية XLSX والنص المستخرج من PDF، ثم تشغيل الفحص الساكن والتحقق من البناء عبر GitHub Actions.

## نتائج التوثيق الرسمي

- توثيق `pdf 3.13.0` يثبت أن `TableHelper.fromTextArray` يدعم `tableDirection` و`headerDirection` بشكل مباشر، لذلك سيتم ضبطهما على `pw.TextDirection.rtl` بدلاً من الاعتماد على اتجاه الصفحة فقط.
- `ThemeData.withFont` يدعم `fontFallback`، لذا سيتم استخدام Noto Sans Arabic كخط أساسي مع Noto Sans اللاتيني وNoto Sans Symbols2 كخطوط fallback.
- وثائق `excel_plus` تؤكد دعم CellStyle والمحاذاة والتنسيق، لكنها لا تقدم في الواجهة الموثقة خاصية عامة لاتجاه الورقة RTL؛ لذلك سيُطبق عكس الأعمدة صراحة في البيانات والرؤوس والعروض.
- أضيفت ملفات `NotoSans-Regular.ttf` و`NotoSans-Bold.ttf` و`NotoSansSymbols2-Regular.ttf` من مستودع Noto الرسمي كمكملات fallback، مع إبقاء Noto Sans Arabic للعربية.

## تدقيق تنفيذ PDF الداخلي

- مصدر `dart_pdf` يوضح أن `TableHelper.fromTextArray` يبني خلايا الجدول بترتيب القوائم كما هو، بينما `tableDirection` يمرر `TextDirection` إلى نصوص الخلايا ويؤثر في محاذاة النص؛ لا يعكس قائمة الخلايا تلقائياً.
- لذلك عكس `headers` و`rows` في `_pdfTable` مع ضبط `tableDirection: rtl` هو قرار مقصود: ترتيب الأعمدة يصبح RTL في البيانات، واتجاه تشكيل النص العربي يصبح RTL داخل الخلايا. لا يوجد عكس تلقائي ثانٍ داخل TableHelper.
- `headerDirection: rtl` و`tableDirection: rtl` مدعومان في إصدار `pdf 3.13.0` المثبت بالمشروع.

المصادر:
- https://pub.dev/documentation/pdf/3.13.0/widgets/TableHelper/fromTextArray.html
- https://raw.githubusercontent.com/DavBfr/dart_pdf/master/pdf/lib/src/widgets/table_helper.dart
- https://raw.githubusercontent.com/DavBfr/dart_pdf/master/pdf/lib/src/widgets/table.dart

## نتائج التحقق المحلي

أظهر فحص Unicode أن Noto Sans Arabic يغطي نقاطاً عربية فعلية، وأن Noto Sans يغطي الحروف اللاتينية والأرقام، بينما يغطي Noto Sans Symbols2 الرموز الشائعة. كما اجتاز فاحص RTL الداخلي والفحص الساكن المحلي وفحص `git diff --check`.

تعذر تشغيل `flutter analyze` داخل هذه البيئة لأن أدوات `flutter` و`dart` غير مثبتة محلياً؛ لذلك سيُعتمد تحقق GitHub Actions بعد الرفع كاختبار الترجمة والبناء الرسمي.
