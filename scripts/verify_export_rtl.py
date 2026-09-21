#!/usr/bin/env python3
"""فحص ثوابت تصدير Excel وPDF العربية.

يتأكد من أن:
  1. أوراق Excel تُضبط على `rightToLeft` وتُكتب أعمدةُها بترتيبها المنطقي دون
     عكس فيزيائي (الجمع بين الأمرين يقلب الترتيب مرتين فيظهر الجدول كأنه
     إنكليزي من اليسار إلى اليمين).
  2. جداول PDF تعكس الرؤوس والصفوف صراحة مع ضبط اتجاه الجدول إلى RTL.
  3. خلايا الجسم في Excel محاذية إلى اليمين.
  4. خطوط العربية وخطوط الاحتياط موجودة وغير فارغة، وتغطي النطاقات المتوقعة
     عند توفّر `fc-query`.
"""

from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BUILDER = ROOT / "lib/core/services/excel_report_builder.dart"
SERVICE = ROOT / "lib/core/services/report_service.dart"
READER = ROOT / "lib/core/services/workbook_names_reader.dart"

failures: list[str] = []


def check(condition: bool, message: str) -> None:
    if condition:
        print(f"  ok   {message}")
    else:
        print(f"  FAIL {message}")
        failures.append(message)


required_assets = [
    "assets/fonts/NotoSansArabic-Regular.ttf",
    "assets/fonts/NotoSansArabic-Bold.ttf",
    "assets/fonts/NotoSans-Regular.ttf",
    "assets/fonts/NotoSans-Bold.ttf",
    "assets/fonts/NotoSansSymbols2-Regular.ttf",
]

print("خطوط التصدير:")
for relative in required_assets:
    path = ROOT / relative
    check(path.is_file() and path.stat().st_size > 0, f"موجود وغير فارغ: {relative}")

print("\nاتجاه أوراق Excel (lib/core/services/excel_report_builder.dart):")
builder = BUILDER.read_text(encoding="utf-8")
check("sheet.isRTL = true;" in builder, "الورقة مضبوطة على rightToLeft")
check("columns.reversed" not in builder, "لا عكس فيزيائياً لأعمدة الترويسة")
check(".reversed.toList" not in builder, "لا عكس فيزيائياً لقيم الصفوف")
check("horizontalAlign: HorizontalAlign.Right" in builder, "محاذاة خلايا الجسم إلى اليمين")
check("TextCellValue(columns[column].header)" in builder, "الترويسة تُكتب بالترتيب المنطقي")

print("\nاتجاه جداول PDF (lib/core/services/report_service.dart):")
service = SERVICE.read_text(encoding="utf-8")
pdf_markers = {
    "عكس رؤوس الجدول": "final rtlHeaders = headers.reversed.toList(growable: false);",
    "عكس صفوف الجدول": "row.reversed.toList(growable: false)",
    "اتجاه الجدول RTL": "tableDirection: pw.TextDirection.rtl",
    "اتجاه الترويسة RTL": "headerDirection: pw.TextDirection.rtl",
    "احتياط الخطوط": "fontFallback: [latinRegular, latinBold, symbols]",
}
for name, marker in pdf_markers.items():
    check(marker in service, name)

print("\nقارئ أسماء الطلاب (lib/core/services/workbook_names_reader.dart):")
reader = READER.read_text(encoding="utf-8")
check("readStudentNamesFromSheets" in reader, "دالة قراءة الأوراق موجودة")
check("detectNameColumn" in reader, "التعرف على عمود الاسم من الترويسة موجود")
check("kNonNameHeaderMarkers" in reader, "استثناء «رقم/هاتف» من أعمدة الاسم موجود")
check("import 'workbook_names_reader.dart';" in (ROOT / "lib/core/services/import_export_service.dart").read_text(encoding="utf-8"),
      "الاستيراد يستخدم القارئ الموحّد")

print("\nتغطية الخطوط:")
if shutil.which("fc-query") is None:
    print("  skip fc-query غير مثبّت، تخطّي فحص نطاقات التغطية")
else:

    def charset(path: Path) -> set[int]:
        raw = subprocess.check_output(
            ["fc-query", "--format=%{charset}", str(path)], text=True
        )
        codepoints: set[int] = set()
        for token in raw.split():
            if "-" in token:
                start, end = token.split("-", maxsplit=1)
                codepoints.update(range(int(start, 16), int(end, 16) + 1))
            else:
                codepoints.add(int(token, 16))
        return codepoints

    arabic_charset = charset(ROOT / "assets/fonts/NotoSansArabic-Regular.ttf")
    latin_charset = charset(ROOT / "assets/fonts/NotoSans-Regular.ttf")
    symbol_charset = charset(ROOT / "assets/fonts/NotoSansSymbols2-Regular.ttf")

    coverage = {
        "Arabic": all(point in arabic_charset for point in (0x0627, 0x0639, 0x0644)),
        "Latin": all(point in latin_charset for point in (0x0041, 0x0061, 0x0030)),
        "Symbols": all(point in symbol_charset for point in (0x260E, 0x2611, 0x1F30D)),
    }
    for name, ok in coverage.items():
        check(ok, f"تغطية {name}")

if failures:
    print(f"\nفشل {len(failures)} فحص:")
    for failure in failures:
        print(f"  - {failure}")
    sys.exit(1)

print("\nجميع فحوص التصدير RTL ناجحة.")
