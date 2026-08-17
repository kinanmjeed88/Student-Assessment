import { describe, expect, it } from "vitest";
import { calculateBehaviorSummary, getConfiguredPenalty } from "../lib/behavior";
import type { AppData } from "../lib/student-store";

function dataWithPenalties(points: number[]): AppData {
  return {
    settings: { schoolName: "مدرسة الاختبار", teacherName: "معلم", academicYear: "2026 / 2027", stage: "", behavior: { dismissalThreshold: 50, warningThreshold: 40, penalties: { absence: 5, lessonDisruption: 10, seriousMisconduct: 20, other: 5 } } },
    classes: [], sections: [], attendance: [], gradeFields: [], grades: [], notes: [],
    students: [{ id: "student-1", studentNumber: "1", firstName: "أحمد", fatherName: "محمد", lastName: "علي", fullName: "أحمد محمد علي", classId: "class-1", sectionId: "section-1", status: "نشط", createdAt: "2026-01-01" }],
    behaviors: points.map((penaltyPoints, index) => ({ id: `behavior-${index}`, studentId: "student-1", category: "negative", violationType: "absence", penaltyPoints, title: "غياب غير مبرر", details: "سجل اختبار", date: `2026-01-0${index + 1}` })),
  };
}

describe("نظام السلوك التراكمي", () => {
  it("يجمع قيمة الخصم المثبتة في كل مخالفة سالبة فقط", () => {
    const data = dataWithPenalties([5, 10, 20]);
    data.behaviors.push({ id: "positive-1", studentId: "student-1", category: "positive", title: "مبادرة جيدة", details: "سجل إيجابي", date: "2026-01-04", penaltyPoints: 50 });
    const summary = calculateBehaviorSummary(data, "student-1");
    expect(summary.totalPoints).toBe(35);
    expect(summary.risk).toBe("clear");
    expect(summary.remainingPoints).toBe(15);
  });

  it("يصدر تنبيهًا عند بلوغ حد التنبيه وفصلًا عند بلوغ الحد الأعلى", () => {
    expect(calculateBehaviorSummary(dataWithPenalties([20, 20]), "student-1").risk).toBe("warning");
    expect(calculateBehaviorSummary(dataWithPenalties([20, 20, 10]), "student-1").risk).toBe("dismissed");
  });

  it("يعيد قيمة الخصم المعتمدة لنوع المخالفة من الإعدادات", () => {
    const data = dataWithPenalties([]);
    expect(getConfiguredPenalty(data, "absence")).toBe(5);
    expect(getConfiguredPenalty(data, "lessonDisruption")).toBe(10);
    expect(getConfiguredPenalty(data, "seriousMisconduct")).toBe(20);
  });
});
