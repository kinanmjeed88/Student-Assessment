import { describe, expect, it } from "vitest";
import { filterStudentsByAttention, REPEATED_ABSENCE_THRESHOLD } from "../lib/student-attention-filter";
import type { AppData } from "../lib/student-store";

const data = {
  settings: {
    behavior: {
      warningThreshold: 40,
      dismissalThreshold: 50,
      penalties: { absence: 5, lessonDisruption: 10, seriousMisconduct: 20, other: 5 },
    },
  },
  behaviors: [
    { id: "b-1", studentId: "warning", category: "negative", penaltyPoints: 40, date: "2026-08-01", title: "مخالفة", details: "" },
    { id: "b-2", studentId: "clear", category: "positive", penaltyPoints: 50, date: "2026-08-01", title: "إيجابي", details: "" },
  ],
  attendance: [
    { id: "a-1", studentId: "frequent", status: "absent", date: "2026-08-01", updatedAt: "2026-08-01" },
    { id: "a-2", studentId: "frequent", status: "absent", date: "2026-08-02", updatedAt: "2026-08-02" },
    { id: "a-3", studentId: "frequent", status: "absent", date: "2026-08-03", updatedAt: "2026-08-03" },
    { id: "a-4", studentId: "excused", status: "excused", date: "2026-08-01", updatedAt: "2026-08-01" },
    { id: "a-5", studentId: "excused", status: "excused", date: "2026-08-02", updatedAt: "2026-08-02" },
    { id: "a-6", studentId: "excused", status: "excused", date: "2026-08-03", updatedAt: "2026-08-03" },
  ],
} as AppData;

const students = [
  { id: "warning", fullName: "أحمد" },
  { id: "frequent", fullName: "باسل" },
  { id: "clear", fullName: "جمال" },
  { id: "excused", fullName: "دانية" },
];

describe("تصفية الحالات التي تحتاج متابعة", () => {
  it("يعرض التنبيهات السلوكية وفق حدود السلوك المضبوطة فقط", () => {
    expect(filterStudentsByAttention(data, students, "behavior-alert").map((student) => student.id)).toEqual(["warning"]);
  });

  it("يعتبر ثلاثة غيابات غير مبررة أو أكثر غيابًا متكررًا، ولا يحسب الغياب بعذر", () => {
    expect(REPEATED_ABSENCE_THRESHOLD).toBe(3);
    expect(filterStudentsByAttention(data, students, "repeated-absence").map((student) => student.id)).toEqual(["frequent"]);
  });

  it("يحافظ على الطلاب دون تعديل عند اختيار الكل", () => {
    expect(filterStudentsByAttention(data, students, "all")).toEqual(students);
    expect(filterStudentsByAttention(data, students, "all")).not.toBe(students);
  });
});
