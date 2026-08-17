import AsyncStorage from "@react-native-async-storage/async-storage";
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { deduplicateStudentNames, studentNameParts } from "@/lib/student-import-format";
import { revertStudentImport } from "@/lib/import-history";

export type AttendanceStatus = "present" | "absent" | "excused" | "late" | "leave";
export type BehaviorCategory = "positive" | "followup" | "negative";
export type BehaviorViolationType = "absence" | "lessonDisruption" | "seriousMisconduct" | "other";
export type NoteCategory = "academic" | "health" | "educational" | "attendance" | "other";

export type BehaviorSettings = {
  dismissalThreshold: number;
  warningThreshold: number;
  penalties: Record<BehaviorViolationType, number>;
};
export type Settings = { schoolName: string; teacherName: string; academicYear: string; stage: string; behavior: BehaviorSettings };
export type SchoolClass = { id: string; name: string; stage: string; academicYear: string; notes?: string };
export type Section = { id: string; classId: string; name: string; notes?: string };
export type Student = {
  id: string; studentNumber: string; firstName: string; fatherName: string; lastName: string; fullName: string;
  gender?: "ذكر" | "أنثى"; classId: string; sectionId: string; status: "نشط" | "منقول" | "متخرج" | "موقوف";
  guardianName?: string; guardianPhone?: string; createdAt: string;
};
export type AttendanceRecord = { id: string; studentId: string; date: string; status: AttendanceStatus; reason?: string; notes?: string; updatedAt: string };
export type GradeField = { id: string; subject: string; title: string; maxScore: number; term: string; date: string };
export type Grade = { id: string; studentId: string; fieldId: string; score: number; notes?: string; createdAt: string };
export type BehaviorRecord = { id: string; studentId: string; category: BehaviorCategory; title: string; details: string; actionTaken?: string; followUp?: string; date: string; violationType?: BehaviorViolationType; penaltyPoints?: number };
export type StudentNote = { id: string; studentId: string; category: NoteCategory; title: string; details: string; needsFollowUp: boolean; followUpDate?: string; date: string };
export type StudentImportFormat = "excel" | "word" | "text";
export type StudentImportRecord = { id: string; createdAt: string; classId: string; sectionId: string; sourceFilename: string; sourceFormat: StudentImportFormat; studentIds: string[]; addedCount: number; revertedAt?: string };
export type StudentImportInput = { names: string[]; classId: string; sectionId: string; sourceFilename: string; sourceFormat: StudentImportFormat };
export type StudentImportResult = { addedCount: number; duplicateCount: number; operationId?: string };

export type AppData = {
  settings: Settings; classes: SchoolClass[]; sections: Section[]; students: Student[]; attendance: AttendanceRecord[];
  gradeFields: GradeField[]; grades: Grade[]; behaviors: BehaviorRecord[]; notes: StudentNote[]; importHistory: StudentImportRecord[];
};

const STORE_KEY = "student-attendance-manager/v1";
export const DEFAULT_BEHAVIOR_SETTINGS: BehaviorSettings = {
  dismissalThreshold: 50,
  warningThreshold: 40,
  penalties: { absence: 5, lessonDisruption: 10, seriousMisconduct: 20, other: 5 },
};
const DEFAULT_DATA: AppData = {
  settings: { schoolName: "", teacherName: "", academicYear: "2026 / 2027", stage: "", behavior: DEFAULT_BEHAVIOR_SETTINGS },
  classes: [], sections: [], students: [], attendance: [], gradeFields: [], grades: [], behaviors: [], notes: [], importHistory: [],
};

function uid(prefix: string) { return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`; }
function today() { return new Date().toISOString().slice(0, 10); }
export function normalizeAppData(raw: Partial<AppData>): AppData {
  const behavior = raw.settings?.behavior;
  return {
    ...DEFAULT_DATA,
    ...raw,
    settings: {
      ...DEFAULT_DATA.settings,
      ...raw.settings,
      behavior: {
        ...DEFAULT_BEHAVIOR_SETTINGS,
        ...behavior,
        penalties: { ...DEFAULT_BEHAVIOR_SETTINGS.penalties, ...behavior?.penalties },
      },
    },
  };
}

type Store = {
  data: AppData; hydrated: boolean; successMessage: string | null; clearSuccess: () => void; showSuccess: (message: string) => void;
  updateSettings: (settings: Settings) => void;
  addClass: (input: Omit<SchoolClass, "id">) => string;
  addSection: (input: Omit<Section, "id">) => string;
  deleteClass: (classId: string) => void;
  deleteSection: (sectionId: string) => void;
  addStudent: (input: Omit<Student, "id" | "fullName" | "createdAt">) => string;
  importStudents: (input: StudentImportInput) => StudentImportResult;
  undoStudentImport: (importId: string) => number;
  updateStudent: (id: string, input: Partial<Student>) => void;
  deleteStudent: (id: string) => void;
  saveAttendance: (entries: Omit<AttendanceRecord, "id" | "updatedAt">[]) => void;
  addGradeField: (input: Omit<GradeField, "id">) => string;
  addGrade: (input: Omit<Grade, "id" | "createdAt">) => void;
  deleteGrade: (id: string) => void;
  addBehavior: (input: Omit<BehaviorRecord, "id">) => void;
  deleteBehavior: (id: string) => void;
  addNote: (input: Omit<StudentNote, "id">) => void;
  deleteNote: (id: string) => void;
  replaceAllData: (input: AppData) => Promise<void>;
  resetAll: () => void;
};

const StudentStoreContext = createContext<Store | null>(null);

export function StudentStoreProvider({ children }: { children: ReactNode }) {
  const [data, setData] = useState<AppData>(DEFAULT_DATA);
  const [hydrated, setHydrated] = useState(false);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  useEffect(() => {
    AsyncStorage.getItem(STORE_KEY)
      .then((raw) => { if (raw) setData(normalizeAppData(JSON.parse(raw) as Partial<AppData>)); })
      .catch(() => undefined)
      .finally(() => setHydrated(true));
  }, []);

  const commit = useCallback((recipe: (current: AppData) => AppData, success?: string) => {
    setData((current) => {
      const next = recipe(current);
      void AsyncStorage.setItem(STORE_KEY, JSON.stringify(next));
      return next;
    });
    if (success) setSuccessMessage(success);
  }, []);

  const replaceAllData = useCallback(async (input: AppData) => {
    const next = normalizeAppData(input);
    await AsyncStorage.setItem(STORE_KEY, JSON.stringify(next));
    setData(next);
    setSuccessMessage("تمت استعادة النسخة الاحتياطية بنجاح.");
  }, []);

  const value = useMemo<Store>(() => ({
    data, hydrated, successMessage, clearSuccess: () => setSuccessMessage(null), showSuccess: (message) => setSuccessMessage(message),
    updateSettings: (settings) => commit((current) => ({ ...current, settings }), "تم حفظ الإعدادات بنجاح."),
    addClass: (input) => {
      const id = uid("class");
      commit((current) => ({ ...current, classes: [...current.classes, { ...input, id }] }), "تمت إضافة الصف بنجاح.");
      return id;
    },
    addSection: (input) => {
      const id = uid("section");
      commit((current) => ({ ...current, sections: [...current.sections, { ...input, id }] }), "تمت إضافة الشعبة بنجاح.");
      return id;
    },
    deleteClass: (classId) => commit((current) => {
      const sectionIds = current.sections.filter((section) => section.classId === classId).map((section) => section.id);
      const studentIds = current.students.filter((student) => student.classId === classId).map((student) => student.id);
      return {
        ...current,
        classes: current.classes.filter((item) => item.id !== classId),
        sections: current.sections.filter((item) => !sectionIds.includes(item.id)),
        students: current.students.filter((item) => !studentIds.includes(item.id)),
        attendance: current.attendance.filter((item) => !studentIds.includes(item.studentId)),
        grades: current.grades.filter((item) => !studentIds.includes(item.studentId)),
        behaviors: current.behaviors.filter((item) => !studentIds.includes(item.studentId)),
        notes: current.notes.filter((item) => !studentIds.includes(item.studentId)),
      };
    }),
    deleteSection: (sectionId) => commit((current) => {
      const studentIds = current.students.filter((student) => student.sectionId === sectionId).map((student) => student.id);
      return {
        ...current,
        sections: current.sections.filter((item) => item.id !== sectionId),
        students: current.students.filter((item) => !studentIds.includes(item.id)),
        attendance: current.attendance.filter((item) => !studentIds.includes(item.studentId)),
        grades: current.grades.filter((item) => !studentIds.includes(item.studentId)),
        behaviors: current.behaviors.filter((item) => !studentIds.includes(item.studentId)),
        notes: current.notes.filter((item) => !studentIds.includes(item.studentId)),
      };
    }),
    addStudent: (input) => {
      const id = uid("student");
      const fullName = [input.firstName, input.fatherName, input.lastName].filter(Boolean).join(" ");
      commit((current) => ({ ...current, students: [...current.students, { ...input, id, fullName, createdAt: new Date().toISOString() }] }), "تم حفظ الطالب بنجاح.");
      return id;
    },
    importStudents: ({ names, classId, sectionId, sourceFilename, sourceFormat }) => {
      const { accepted, duplicateNames } = deduplicateStudentNames(names, data.students.map((student) => student.fullName));
      if (!accepted.length) return { addedCount: 0, duplicateCount: duplicateNames.length };
      const operationId = uid("import");
      const createdAt = new Date().toISOString();
      commit((current) => {
        const fresh = deduplicateStudentNames(accepted, current.students.map((student) => student.fullName)).accepted;
        const imported = fresh.map((fullName) => {
          const parts = studentNameParts(fullName);
          return {
            id: uid("student"),
            studentNumber: "",
            ...parts,
            fullName,
            classId,
            sectionId,
            status: "نشط" as const,
            createdAt,
          };
        });
        if (!imported.length) return current;
        const historyEntry: StudentImportRecord = { id: operationId, createdAt, classId, sectionId, sourceFilename, sourceFormat, studentIds: imported.map((student) => student.id), addedCount: imported.length };
        return { ...current, students: [...current.students, ...imported], importHistory: [historyEntry, ...current.importHistory] };
      });
      return { addedCount: accepted.length, duplicateCount: duplicateNames.length, operationId };
    },
    undoStudentImport: (importId) => {
      const outcome = revertStudentImport(data, importId);
      if (!outcome.removedStudentIds.length) return 0;
      commit(() => outcome.data, `تم التراجع عن الاستيراد وحذف ${outcome.removedStudentIds.length} طالبًا من هذه العملية.`);
      return outcome.removedStudentIds.length;
    },
    updateStudent: (id, input) => commit((current) => ({
      ...current,
      students: current.students.map((student) => student.id === id ? { ...student, ...input, fullName: [input.firstName ?? student.firstName, input.fatherName ?? student.fatherName, input.lastName ?? student.lastName].filter(Boolean).join(" ") } : student),
    }), "تم تحديث بيانات الطالب بنجاح."),
    deleteStudent: (id) => commit((current) => ({
      ...current,
      students: current.students.filter((item) => item.id !== id),
      attendance: current.attendance.filter((item) => item.studentId !== id),
      grades: current.grades.filter((item) => item.studentId !== id),
      behaviors: current.behaviors.filter((item) => item.studentId !== id),
      notes: current.notes.filter((item) => item.studentId !== id),
    })),
    saveAttendance: (entries) => commit((current) => {
      const keys = new Set(entries.map((entry) => `${entry.studentId}/${entry.date}`));
      const retained = current.attendance.filter((item) => !keys.has(`${item.studentId}/${item.date}`));
      return { ...current, attendance: [...retained, ...entries.map((entry) => ({ ...entry, id: uid("att"), updatedAt: new Date().toISOString() }))] };
    }, "تم حفظ سجل الحضور بنجاح."),
    addGradeField: (input) => {
      const id = uid("field");
      commit((current) => ({ ...current, gradeFields: [...current.gradeFields, { ...input, id }] }), "تمت إضافة حقل الدرجات بنجاح.");
      return id;
    },
    addGrade: (input) => commit((current) => ({ ...current, grades: [...current.grades.filter((grade) => !(grade.studentId === input.studentId && grade.fieldId === input.fieldId)), { ...input, id: uid("grade"), createdAt: new Date().toISOString() }] }), "تم حفظ الدرجة بنجاح."),
    deleteGrade: (id) => commit((current) => ({ ...current, grades: current.grades.filter((item) => item.id !== id) })),
    addBehavior: (input) => commit((current) => ({ ...current, behaviors: [{ ...input, id: uid("behavior") }, ...current.behaviors] }), "تم حفظ سجل السلوك بنجاح."),
    deleteBehavior: (id) => commit((current) => ({ ...current, behaviors: current.behaviors.filter((item) => item.id !== id) })),
    addNote: (input) => commit((current) => ({ ...current, notes: [{ ...input, id: uid("note") }, ...current.notes] }), "تم حفظ الملاحظة بنجاح."),
    deleteNote: (id) => commit((current) => ({ ...current, notes: current.notes.filter((item) => item.id !== id) })),
    replaceAllData,
    resetAll: () => { void AsyncStorage.removeItem(STORE_KEY); setData(DEFAULT_DATA); setSuccessMessage("تم حذف جميع البيانات بنجاح."); },
  }), [commit, data, hydrated, replaceAllData, successMessage]);

  return <StudentStoreContext.Provider value={value}>{children}</StudentStoreContext.Provider>;
}

export function useStudentStore() {
  const context = useContext(StudentStoreContext);
  if (!context) throw new Error("useStudentStore must be used inside StudentStoreProvider");
  return context;
}

export const attendanceLabels: Record<AttendanceStatus, string> = { present: "حاضر", absent: "غائب", excused: "بعذر", late: "متأخر", leave: "إجازة" };
export const behaviorLabels: Record<BehaviorCategory, string> = { positive: "إيجابي", followup: "يحتاج متابعة", negative: "مخالفة" };
export const behaviorViolationLabels: Record<BehaviorViolationType, string> = { absence: "غياب غير مبرر", lessonDisruption: "إخلال بسير الدرس", seriousMisconduct: "مخالفة جسيمة", other: "مخالفة أخرى" };
export const noteLabels: Record<NoteCategory, string> = { academic: "أكاديمية", health: "صحية", educational: "تربوية", attendance: "حضور", other: "أخرى" };
export const isoToday = today;
