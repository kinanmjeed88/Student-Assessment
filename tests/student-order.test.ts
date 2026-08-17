import { describe, expect, it } from "vitest";
import { sortStudentsArabic } from "../lib/student-order";

describe("ترتيب أسماء الطلاب", () => {
  it("يرتب الأسماء أبجديًا دون تعديل القائمة الأصلية", () => {
    const students = [{ fullName: "سارة محمد" }, { fullName: "أحمد علي" }, { fullName: "باسم حسن" }];
    expect(sortStudentsArabic(students).map((item) => item.fullName)).toEqual(["أحمد علي", "باسم حسن", "سارة محمد"]);
    expect(students[0].fullName).toBe("سارة محمد");
  });
});
