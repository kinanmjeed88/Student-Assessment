import { describe, expect, it } from "vitest";
import { formatArabicDate, isolateBidiText } from "../lib/text-direction";

describe("اتجاه النصوص المختلطة", () => {
  it("يعزل قيمة مختلطة حتى لا تغيّر ترتيب الجملة العربية", () => {
    expect(isolateBidiText("2026-08-18")).toBe("\u20682026-08-18\u2069");
  });

  it("ينسق التاريخ المحفوظ ضمن عزل ثنائي الاتجاه", () => {
    const formatted = formatArabicDate("2026-08-18");
    expect(formatted.startsWith("\u2068")).toBe(true);
    expect(formatted.endsWith("\u2069")).toBe(true);
  });
});
