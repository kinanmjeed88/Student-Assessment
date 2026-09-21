<div dir="rtl" align="right">

# مزامنة إصلاح ترتيب أعمدة التصدير مع فروع ويندوز

## الفروع المعنية

| الفرع | الدور | حالة ملفات التصدير قبل الإصلاح |
| --- | --- | --- |
| `main` | فرع أندرويد (وبناء ويندوز في `build-flutter.yml`) | `excel_plus` 2.14.2 |
| `سجل-الطالب-للوندوز-١٠-و-١١` | بناء ويندوز ١٠/١١ | مطابقة تماماً لـ `main` في `excel_report_builder.dart` و`report_service.dart` و`import_export_service.dart` و`test/report_service_test.dart` |
| `سجل-الطالب-للوندوز-٧` | بناء ويندوز ٧ (Flutter 3.12 beta) | نفسها، مع اختلاف الحزمة: `excel` 4.0.6 بدل `excel_plus`، وحفظ الملفات عبر `FileStorageService` بدل `FilePicker` |

## لماذا التقاط (cherry-pick) وليس دمج `main`؟

فرعا ويندوز يحذفان عمداً أجزاءً موجودة في `main`:

- فرع وندوز ٧ لا يحتوي مجلد `android` إطلاقاً، ويتحقق CI فيه من غيابه، ويرفض
  ظهور `excel_plus` أو `FillPatternType` أو `WidgetStatePropertyAll` أو
  `surfaceContainerHighest` أو `withValues(` في أي ملف داخل `lib`.
- فرع وندوز ١٠/١١ أزال الإشعارات وتنبيهات الطلاب وملخّص الحضور لأسباب
  موثّقة في `WINLATOR_CRASH_FINDINGS.md` داخل الفرع نفسه.

لذلك فإن دمج `main` في أي منهما يكسر بناءه. الحل هو نقل commit الإصلاح وحده.

## ما الذي ينقله الإصلاح

1. `lib/core/services/excel_report_builder.dart` — إلغاء العكس الفيزيائي
   للأعمدة مع إبقاء `sheet.isRTL = true` (كان الانعكاس المزدوج يجعل الجدول
   يُقرأ من اليسار إلى اليمين فيظهر عمود «ت» والاسم الكامل في أقصى اليسار).
2. `lib/core/services/report_service.dart` — إلغاء إعادة الفرز في تصدير أسماء
   صف محدد ليصبح ترتيب الصفوف مطابقاً لترتيب العرض.
3. `lib/core/services/workbook_names_reader.dart` (ملف جديد) — قراءة عمود
   الاسم من الترويسة، بلا أي اعتماد على حزمة Excel، فيعمل على الفروع الثلاثة.
4. `lib/core/services/import_export_service.dart` — استخدام القارئ الجديد.
5. `lib/features/import/presentation/import_students_page.dart` — تحديث النص
   التوضيحي لسلوك القراءة.
6. `test/report_service_test.dart` و`test/workbook_names_reader_test.dart` —
   اختبارات ترتيب الأعمدة وترتيب الصفوف والاستيراد الدائري.
7. `scripts/verify_export_rtl.py` — فحص الثوابت الجديدة بدل علامات قديمة
   لم تعد موجودة.

الملف الجديد والاختبارات لا تستورد أي حزمة Excel، لذا لا تحتاج إلى تعديل عند
نقلها إلى فرع وندوز ٧ الذي يستخدم `package:excel/excel.dart`.

## طريقة التطبيق

بعد دمج الإصلاح في `main`:

```bash
# 1) تطبيق تجريبي: يلتقط الـ commit في كل فرع ويتحقق من قيود وندوز ٧،
#    ويحفظ الرقعة في build/sync-win7.patch و build/sync-win10-11.patch
scripts/sync_windows_branches.sh <commit-ish>

# 2) التطبيق الفعلي مع الدفع إلى الفرعين
scripts/sync_windows_branches.sh <commit-ish> --push
```

`<commit-ish>` هو commit الإصلاح في `main` (أو `origin/main` بعد الدمج).

يعمل السكربت عبر `git worktree` في مجلد مؤقت، فلا يلمس الفرع الذي تعمل عليه
حالياً، ولا ينشئ فروعاً محلية جديدة.

### التطبيق اليدوي (بديل)

```bash
git fetch origin '+refs/heads/سجل-الطالب-للوندوز-٧:refs/remotes/origin/win7'
git worktree add --detach /tmp/win7 origin/win7
cd /tmp/win7
git cherry-pick -x <commit-ish>
git push origin HEAD:refs/heads/سجل-الطالب-للوندوز-٧
cd - && git worktree remove /tmp/win7
```

وتُكرَّر الخطوات نفسها لفرع `سجل-الطالب-للوندوز-١٠-و-١١`.

## التحقق بعد النقل

| الفرع | أمر التحقق |
| --- | --- |
| `main` | `flutter analyze` ثم `flutter test` (يقوم بهما `build-flutter.yml`) |
| وندوز ١٠/١١ | `flutter analyze` ثم `flutter test` ثم `flutter build windows --release` |
| وندوز ٧ | `flutter analyze --no-fatal-infos` ثم `flutter build windows --release` (CI هذا الفرع لا يشغّل الاختبارات، لكن ملفاتها تُحلَّل) |

ويمكن في كل فرع تشغيل `python3 scripts/verify_export_rtl.py` للتأكد من ثوابت
التصدير دون الحاجة إلى أدوات Flutter.

</div>
