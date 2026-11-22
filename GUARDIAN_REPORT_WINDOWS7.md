# إرسال تقرير ولي الأمر على فرع ويندوز ٧

<div dir="rtl" align="right">

هذا المستند يوثّق نقل ميزة إرسال تقرير ولي الأمر من PR #12 (آخر نسخة فيه:
`b526f6f950dc7a52df3f8d54b118c8d27807a801`) إلى فرع `سجل-الطالب-للوندوز-٧`،
والتعديلات التي فُرضت بمعمارية هذا الفرع ونسخة Flutter فيه
(`3.12.0-1.1.pre` / Dart 3.1) واعتمادياته.

## سلوك الإرسال المعتمد (مرحلتان)

1. زر الرأس «واتساب» يفتح ورقة «إرسال تقرير ولي الأمر»، وزر البدء فيها
   **«إرسال التقرير والملف»**.
2. عند البدء: يُنسخ رقم ولي الأمر الدولي تلقائياً مرة واحدة فقط (مع زر نسخ
   يدوي وملاحظة البحث عن الرقم)، ويُجهَّز نص المعاينة نفسه وملف PDF أو Excel
   **مرة واحدة** من لقطة الشهر الحالي حتى لحظة فتح الورقة (`reportNow`)،
   فيتطابق نص الرسالة مع محتوى الملف حرفياً.
3. تُفتح محادثة واتساب عبر رابط `wa.me` بالنص الجاهز في المتصفح. التطبيق لا
   يدّعي توجيه الرسالة ولا نجاح إرسالها؛ المستخدم يرسل النص بنفسه.
4. بعد ذلك تظهر خطوة واضحة بعنوان **«إرسال ملف التقرير»** لتسليم الملف نفسه
   وحده (من دون نص) عبر نافذة الحفظ، **دون إعادة توليده**؛ ثم يرفقه المستخدم
   في رسالة واتساب يدوياً.
5. الفشل يُعرض مع زر إعادة محاولة مناسب (إعادة تجهيز أو إعادة الملف)، ومنع
   التكرار يضمن عدم تجهيز أو مشاركة مزدوجة أثناء العملية الجارية.

## لماذا لا تُستخدم share_plus على هذا الفرع

- إصدار share_plus المتوافق مع Flutter 3.12 هو السلسلة 7.x (المتطلبات
  `Flutter >=3.3.0` و`Dart >=2.18 <4.0.0`)؛ إصدارات 8.0.1+ تتطلب Dart ≥3.3،
  وإصدارات 10+ تتطلب Flutter ≥3.22، وإصدارات 13+ المتصلة بـ PR #12 تتطلب
  Flutter ≥3.38.1 — كلها خارج نطاق الفرع.
- تنفيذ Windows في share_plus 7.x (`share_plus_windows.dart` في
  `fluttercommunity/plus_plugins`) يعلن صراحةً أن واجهته البديلة تُستخدم
  «لإصدارات ويندوز الأقدم من Windows 10 RS5»، وأن فيها:
  - `share(text)` → فتح رابط `mailto:` (بريد إلكتروني، لا واتساب)، و
  - `shareFiles`/`shareXFiles` → `UnimplementedError`.
- أي محاولة لإضافة share_plus إلى هذا الفرع ستُظهر واجهة مشاركة لا تعمل
  فعلياً على Windows 7، وهي ميزة زائفة. لذلك بُديلت الآلية بما يعمل فعلاً:
  `url_launcher` (معتمد أصلاً في الفرع) لفتح `wa.me`، ونافذة حفظ الملف
  عبر `FilePicker` (نفس نمط تصدير Excel/PDF القائم في الفرع).

## ما نُقل كما هو من PR #12

| الملف | الحالة |
| --- | --- |
| `lib/core/services/guardian_phone.dart` | منقول كما هو (Dart خالص) |
| `lib/core/services/guardian_phone_copier.dart` | منقول كما هو |
| `lib/core/services/monthly_report_scope.dart` | منقول كما هو |
| `lib/core/services/guardian_send_coordinator.dart` | منقول كما هو |
| `lib/core/services/guardian_send_session.dart` | منقول مع تكييف رسائل مرحلة الملف (حفظ بدل ورقة مشاركة) |
| `lib/core/services/guardian_report_text.dart` | مكيّف: احتساب أرقام الحضور الأربعة داخل الملف لأن الفرع لا يضم `attendance_summary.dart` بنص مطابق |
| `lib/core/services/guardian_report_service.dart` | مكيّف: يبقى `prepare()` و`PreparedGuardianReport` و`GuardianShareOutcome` بلا اعتماد share_plus |
| `lib/core/providers.dart` | إضافة `guardianReportServiceProvider` فقط |
| `lib/features/students/presentation/student_details_page.dart` | مكيّف: الورقة والمرحلتان وزر الرأس، بممنوعات الفرع (`MaterialStatePropertyAll` و`surfaceVariant` بدل `WidgetStatePropertyAll` و`surfaceContainerHighest`) |
| الاختبارات السبعة (Fixture/Phone/Copier/Text/Scope/Coordinator/Session + Service) | منقولة، واختبار الخدمة مكيّف بحزمة `excel` بدل `excel_plus` وبدون اختبارات share_plus |

## ما لم يُنقل عمداً

- `whatsapp_direct_share.dart` وقناة `MethodChannel` الأصلية وملفات
  `android/**` (لا يوجد مجلد android في الفرع ويرفضه CI).
- اعتماد `share_plus` الجديد (أدلة أعلاه).
- اختبارا `whatsapp_direct_share_test.dart` و`android_share_contract_test.dart`.
- أي ميزة أُزيلت عمداً من الفرع (`excel_plus`، إشعارات Android، MSIX).

## التحقق

- تحليل: `flutter analyze --no-fatal-infos` في CI.
- اختبارات: أُضيفت خطوة `flutter test` إلى `build-windows-7.yml` (لم تكن
  خطوة الاختبار موجودة في بناء الفرع سابقاً).
- بناء: `flutter build windows --release` + شимات توافق ويندوز ٧ + التغليف.
- اختبارات ميدانية لم تُنفّذ هنا: فتح `wa.me` في متصفح Windows 7 الفعلي،
  نسخ الرقم إلى الحافظة، نافذة الحفظ ومرفقات واتساب اليدوية على جهاز
  Windows 7 SP1.
