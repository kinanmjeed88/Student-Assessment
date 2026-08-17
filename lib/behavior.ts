import type { AppData, BehaviorRecord, BehaviorViolationType } from "./student-store";

export type BehaviorRisk = "clear" | "warning" | "dismissed";

export type BehaviorSummary = {
  totalPoints: number;
  warningThreshold: number;
  dismissalThreshold: number;
  remainingPoints: number;
  risk: BehaviorRisk;
  violations: BehaviorRecord[];
};

export function calculateBehaviorSummary(data: AppData, studentId: string): BehaviorSummary {
  const violations = data.behaviors
    .filter((item) => item.studentId === studentId && item.category === "negative")
    .sort((a, b) => b.date.localeCompare(a.date));
  const totalPoints = violations.reduce((total, item) => total + Math.max(0, Number(item.penaltyPoints ?? 0)), 0);
  const { warningThreshold, dismissalThreshold } = data.settings.behavior;
  const risk: BehaviorRisk = totalPoints >= dismissalThreshold ? "dismissed" : totalPoints >= warningThreshold ? "warning" : "clear";
  return { totalPoints, warningThreshold, dismissalThreshold, remainingPoints: Math.max(0, dismissalThreshold - totalPoints), risk, violations };
}

export function getConfiguredPenalty(data: AppData, violationType: BehaviorViolationType) {
  return data.settings.behavior.penalties[violationType];
}

export function isBehaviorAlert(data: AppData, studentId: string) {
  return calculateBehaviorSummary(data, studentId).risk !== "clear";
}
