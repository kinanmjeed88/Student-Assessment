import { describe, expect, it } from "vitest";
import { BACKUP_FORMAT, BACKUP_VERSION, getBackupSummary, parseStudentBackup, serializeStudentBackup } from "../lib/backup-format";

const data = {
  settings: { schoolName: "مدرسة النور", teacherName: "أحمد", academicYear: "2026/2027", stage: "ابتدائي", behavior: { dismissalThreshold: 50, warningThreshold: 40, penalties: { absence: 5, lessonDisruption: 10, seriousMisconduct: 20, other: 5 } } },
  classes: [{ id: "c1" }], sections: [{ id: "s1" }], students: [{ id: "st1" }, { id: "st2" }], attendance: [{ id: "a1" }], gradeFields: [], grades: [{ id: "g1" }], behaviors: [{ id: "b1" }], notes: [{ id: "n1" }], importHistory: [],
} as never;

describe("صيغة النسخة الاحتياطية", () => {
  it("ينشئ ملفًا قابلاً للقراءة ويحسب ملخصه", () => {
    const backup = parseStudentBackup(serializeStudentBackup(data));
    expect(backup.format).toBe(BACKUP_FORMAT);
    expect(backup.version).toBe(BACKUP_VERSION);
    expect(getBackupSummary(backup)).toMatchObject({ students: 2, classes: 1, attendance: 1, grades: 1, behaviors: 1, notes: 1 });
  });

  it("يرفض الملفات غير التابعة للتطبيق أو الناقصة", () => {
    expect(() => parseStudentBackup("{\"format\":\"unknown\"}")).toThrow("ليس نسخة احتياطية");
    expect(() => parseStudentBackup(JSON.stringify({ format: BACKUP_FORMAT, version: BACKUP_VERSION, createdAt: new Date().toISOString(), data: { settings: {} } }))).toThrow("غير صالح");
  });
});
