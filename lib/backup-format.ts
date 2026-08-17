import type { AppData } from "@/lib/student-store";

export const BACKUP_FORMAT = "student-attendance-manager.backup";
export const BACKUP_VERSION = 1;

export type StudentBackup = {
  format: typeof BACKUP_FORMAT;
  version: typeof BACKUP_VERSION;
  createdAt: string;
  data: AppData;
};

export type BackupSummary = {
  createdAt: string;
  students: number;
  classes: number;
  sections: number;
  attendance: number;
  grades: number;
  behaviors: number;
  notes: number;
};

const DATA_ARRAY_KEYS = ["classes", "sections", "students", "attendance", "gradeFields", "grades", "behaviors", "notes"] as const;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function assertBackupData(value: unknown): asserts value is AppData {
  if (!isRecord(value) || !isRecord(value.settings)) {
    throw new Error("ملف النسخة الاحتياطية لا يحتوي على إعدادات صالحة.");
  }

  for (const key of DATA_ARRAY_KEYS) {
    if (!Array.isArray(value[key])) {
      throw new Error(`ملف النسخة الاحتياطية غير صالح: حقل «${key}» مفقود أو غير صحيح.`);
    }
  }
}

export function createStudentBackup(data: AppData): StudentBackup {
  return {
    format: BACKUP_FORMAT,
    version: BACKUP_VERSION,
    createdAt: new Date().toISOString(),
    data,
  };
}

export function serializeStudentBackup(data: AppData): string {
  return JSON.stringify(createStudentBackup(data), null, 2);
}

export function parseStudentBackup(content: string): StudentBackup {
  let value: unknown;
  try {
    value = JSON.parse(content);
  } catch {
    throw new Error("تعذر قراءة الملف. اختر ملف نسخة احتياطية بصيغة JSON.");
  }

  if (!isRecord(value) || value.format !== BACKUP_FORMAT) {
    throw new Error("هذا الملف ليس نسخة احتياطية صادرة من تطبيق سجل الطالب.");
  }
  if (value.version !== BACKUP_VERSION) {
    throw new Error("إصدار النسخة الاحتياطية غير مدعوم في هذا الإصدار من التطبيق.");
  }
  if (typeof value.createdAt !== "string" || Number.isNaN(Date.parse(value.createdAt))) {
    throw new Error("تاريخ إنشاء النسخة الاحتياطية غير صالح.");
  }

  assertBackupData(value.data);
  return value as StudentBackup;
}

export function getBackupSummary(backup: StudentBackup): BackupSummary {
  const { data } = backup;
  return {
    createdAt: backup.createdAt,
    students: data.students.length,
    classes: data.classes.length,
    sections: data.sections.length,
    attendance: data.attendance.length,
    grades: data.grades.length,
    behaviors: data.behaviors.length,
    notes: data.notes.length,
  };
}
