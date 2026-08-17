import { describe, expect, it } from "vitest";
import { revertStudentImport } from "../lib/import-history";

const data = {
  settings: { schoolName: "", teacherName: "", academicYear: "", stage: "", behavior: { dismissalThreshold: 50, warningThreshold: 40, penalties: { absence: 5, lessonDisruption: 10, seriousMisconduct: 20, other: 5 } } },
  classes: [], sections: [], gradeFields: [],
  students: [{ id: "imported", fullName: "أحمد علي" }, { id: "manual", fullName: "باسم حسن" }],
  attendance: [{ id: "a1", studentId: "imported" }, { id: "a2", studentId: "manual" }],
  grades: [{ id: "g1", studentId: "imported" }, { id: "g2", studentId: "manual" }],
  behaviors: [{ id: "b1", studentId: "imported" }, { id: "b2", studentId: "manual" }],
  notes: [{ id: "n1", studentId: "imported" }, { id: "n2", studentId: "manual" }],
  importHistory: [{ id: "import-1", createdAt: "2026-08-18T08:00:00.000Z", classId: "c1", sectionId: "s1", sourceFilename: "students.xlsx", sourceFormat: "excel", studentIds: ["imported"], addedCount: 1 }],
} as never;

describe("التراجع عن استيراد الطلاب", () => {
  it("يحذف فقط الطلاب وسجلاتهم التابعة لعملية الاستيراد المحددة", () => {
    const outcome = revertStudentImport(data, "import-1", "2026-08-18T09:00:00.000Z");
    expect(outcome.removedStudentIds).toEqual(["imported"]);
    expect(outcome.data.students.map((item) => item.id)).toEqual(["manual"]);
    expect(outcome.data.attendance.map((item) => item.studentId)).toEqual(["manual"]);
    expect(outcome.data.grades.map((item) => item.studentId)).toEqual(["manual"]);
    expect(outcome.data.behaviors.map((item) => item.studentId)).toEqual(["manual"]);
    expect(outcome.data.notes.map((item) => item.studentId)).toEqual(["manual"]);
    expect(outcome.data.importHistory[0].revertedAt).toBe("2026-08-18T09:00:00.000Z");
  });

  it("لا يعيد تنفيذ التراجع لعملية سبق التراجع عنها", () => {
    const first = revertStudentImport(data, "import-1", "2026-08-18T09:00:00.000Z");
    const second = revertStudentImport(first.data, "import-1");
    expect(second.removedStudentIds).toEqual([]);
  });
});
