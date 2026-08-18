const FIRST_STRONG_ISOLATE = "\u2068";
const POP_DIRECTIONAL_ISOLATE = "\u2069";

/** Keeps ISO dates, phone numbers and Latin fragments from changing nearby Arabic word order. */
export function isolateBidiText(value: string | number): string {
  return `${FIRST_STRONG_ISOLATE}${String(value)}${POP_DIRECTIONAL_ISOLATE}`;
}

/** Formats a stored ISO day as Arabic while preserving it as an isolated inline value. */
export function formatArabicDate(value: string): string {
  const date = new Date(`${value}T12:00:00`);
  if (Number.isNaN(date.getTime())) return isolateBidiText(value);
  return isolateBidiText(new Intl.DateTimeFormat("ar-IQ", { year: "numeric", month: "long", day: "numeric" }).format(date));
}
