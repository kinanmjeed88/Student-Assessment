import type { AppData } from "@/lib/student-store";

export type ImportUndoOutcome = {
  data: AppData;
  removedStudentIds: string[];
};

/**
 * Reverts only the students that were created by one still-active bulk import.
 * Any records related to those students are removed with them to preserve the
 * application's referential integrity.
 */
export function revertStudentImport(data: AppData, importId: string, revertedAt = new Date().toISOString()): ImportUndoOutcome {
  const operation = data.importHistory.find((item) => item.id === importId);
  if (!operation || operation.revertedAt) return { data, removedStudentIds: [] };

  const studentIds = new Set(operation.studentIds);
  const removedStudentIds = data.students.filter((student) => studentIds.has(student.id)).map((student) => student.id);
  if (!removedStudentIds.length) {
    return {
      data: { ...data, importHistory: data.importHistory.map((item) => item.id === importId ? { ...item, revertedAt } : item) },
      removedStudentIds,
    };
  }

  const removedIds = new Set(removedStudentIds);
  return {
    data: {
      ...data,
      students: data.students.filter((student) => !removedIds.has(student.id)),
      attendance: data.attendance.filter((record) => !removedIds.has(record.studentId)),
      grades: data.grades.filter((record) => !removedIds.has(record.studentId)),
      behaviors: data.behaviors.filter((record) => !removedIds.has(record.studentId)),
      notes: data.notes.filter((record) => !removedIds.has(record.studentId)),
      importHistory: data.importHistory.map((item) => item.id === importId ? { ...item, revertedAt } : item),
    },
    removedStudentIds,
  };
}
