import { calculateBehaviorSummary } from "./behavior";
import type { AppData } from "./student-store";

export const REPEATED_ABSENCE_THRESHOLD = 3;

export type StudentAttentionFilter = "all" | "behavior-alert" | "repeated-absence";

export function countStudentAbsences(data: AppData, studentId: string) {
  return data.attendance.filter((record) => record.studentId === studentId && record.status === "absent").length;
}

export function filterStudentsByAttention<T extends { id: string }>(
  data: AppData,
  students: readonly T[],
  filter: StudentAttentionFilter,
) {
  if (filter === "all") return [...students];

  return students.filter((student) => {
    if (filter === "behavior-alert") return calculateBehaviorSummary(data, student.id).risk !== "clear";
    return countStudentAbsences(data, student.id) >= REPEATED_ABSENCE_THRESHOLD;
  });
}

export function attentionFilterLabel(filter: StudentAttentionFilter) {
  if (filter === "behavior-alert") return "تنبيه سلوكي";
  if (filter === "repeated-absence") return `غيابات متكررة (${REPEATED_ABSENCE_THRESHOLD} فأكثر)`;
  return "كل الطلاب";
}
