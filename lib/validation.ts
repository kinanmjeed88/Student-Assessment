export function required(value: string, label: string): string | null {
  return value.trim() ? null : `يرجى إدخال ${label}.`;
}

export function validScore(score: string, maximum: string): string | null {
  const scoreValue = Number(score);
  const maxValue = Number(maximum);
  if (!Number.isFinite(maxValue) || maxValue <= 0) return "يجب أن تكون الدرجة العظمى رقمًا موجبًا.";
  if (!Number.isFinite(scoreValue) || scoreValue < 0) return "يرجى إدخال درجة صحيحة.";
  if (scoreValue > maxValue) return "لا يمكن أن تتجاوز درجة الطالب الدرجة العظمى.";
  return null;
}

export function validPhone(value: string): string | null {
  if (!value.trim()) return null;
  return /^[0-9+()\-\s]{7,20}$/.test(value) ? null : "رقم الهاتف غير صحيح.";
}
