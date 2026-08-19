from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SERVICE = (ROOT / "lib/core/services/report_service.dart").read_text(encoding="utf-8")

required_assets = [
    "assets/fonts/NotoSansArabic-Regular.ttf",
    "assets/fonts/NotoSansArabic-Bold.ttf",
    "assets/fonts/NotoSans-Regular.ttf",
    "assets/fonts/NotoSans-Bold.ttf",
    "assets/fonts/NotoSansSymbols2-Regular.ttf",
]
for relative in required_assets:
    path = ROOT / relative
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing or empty font asset: {relative}")

required_source_markers = {
    "font fallback": "fontFallback: [latinRegular, latinBold, symbols]",
    "Excel header order": "final rtlHeaders = headers.reversed.toList(growable: false);",
    "Excel row order": "final rtlValues = values.reversed.toList(growable: false);",
    "Excel body alignment": "horizontalAlign: HorizontalAlign.Right",
    "PDF table direction": "tableDirection: pw.TextDirection.rtl",
    "PDF header direction": "headerDirection: pw.TextDirection.rtl",
}
for name, marker in required_source_markers.items():
    if marker not in SERVICE:
        raise SystemExit(f"missing RTL marker: {name}")

# Verify that the selected fonts advertise the expected script ranges.
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

checks = {
    "Arabic": all(codepoint in arabic_charset for codepoint in (0x0627, 0x0639, 0x0644)),
    "Latin": all(codepoint in latin_charset for codepoint in (0x0041, 0x0061, 0x0030)),
    "Symbols": all(codepoint in symbol_charset for codepoint in (0x260E, 0x2611, 0x1F30D)),
}
if not all(checks.values()):
    raise SystemExit(f"font coverage checks failed: {checks}")

print("Export RTL and font coverage checks passed.")
print("Font assets:")
for relative in required_assets:
    print(f"  - {relative}")
print("Coverage:", checks)
