import { describe, expect, it } from "vitest";
import { required, validPhone, validScore } from "../lib/validation";

describe("validation", () => {
  it("يرفض القيمة الإلزامية الفارغة", () => expect(required("   ", "اسم الطالب")).toContain("اسم الطالب"));
  it("يمنع الدرجة الأعلى من الدرجة العظمى", () => expect(validScore("21", "20")).toContain("تتجاوز"));
  it("يقبل رقم هاتف مناسب", () => expect(validPhone("+964 770 123 4567")).toBeNull());
});
