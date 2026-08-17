export type NamedStudent = { fullName: string };

/** Returns a new Arabic-alphabetical list without changing the saved order. */
export function sortStudentsArabic<T extends NamedStudent>(students: T[]): T[] {
  return [...students].sort((left, right) => left.fullName.localeCompare(right.fullName, "ar", { sensitivity: "base", numeric: true }));
}
