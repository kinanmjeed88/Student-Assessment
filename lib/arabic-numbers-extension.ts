const ARABIC_DIGITS = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"] as const;

export function toArabicDigits(value: string | number | null | undefined): string {
  if (value === null || value === undefined) return "";
  return String(value).replace(/[0-9]/g, (digit) => ARABIC_DIGITS[Number(digit)]);
}

export function toArabicDigitsOrDash(value: string | number | null | undefined): string {
  const converted = toArabicDigits(value);
  return converted || "—";
}

declare global {
  interface String {
    toArabicDigits(): string;
  }
}

if (!String.prototype.toArabicDigits) {
  Object.defineProperty(String.prototype, "toArabicDigits", {
    configurable: true,
    value: function arabicDigitsExtension(this: string) {
      return toArabicDigits(this);
    },
    writable: true,
  });
}

export {};
