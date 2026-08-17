import { strFromU8, unzipSync } from "fflate";
import * as XLSX from "xlsx";

export type StudentImportFormat = "excel" | "word" | "text";

const HEADER_LABELS = new Set([
  "الاسم",
  "اسم الطالب",
  "اسم الطالبه",
  "اسم الطالب الكامل",
  "الاسم الكامل",
  "اسم",
  "student name",
  "full name",
  "name",
]);

function decodeXml(value: string) {
  return value
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#x([0-9a-f]+);/gi, (_, code: string) => String.fromCodePoint(parseInt(code, 16)))
    .replace(/&#(\d+);/g, (_, code: string) => String.fromCodePoint(parseInt(code, 10)));
}

function normalizeWhitespace(value: string) {
  return value.replace(/\u00a0/g, " ").replace(/[\r\n\t]+/g, " ").replace(/\s+/g, " ").trim();
}

function hasLetters(value: string) {
  return /\p{L}/u.test(value);
}

function isHeader(value: string) {
  return HEADER_LABELS.has(normalizeNameIdentity(value));
}

/** Converts a name into a comparison key while preserving its visible spelling. */
export function normalizeNameIdentity(value: string) {
  return normalizeWhitespace(value)
    .replace(/[ـ]/g, "")
    .replace(/[\u064B-\u065F\u0670]/g, "")
    .replace(/[أإآ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .toLocaleLowerCase();
}

/** Removes common Arabic/Latin list numbering before extracting a student name. */
export function cleanStudentName(value: string) {
  let result = normalizeWhitespace(decodeXml(value));
  result = result.replace(/^\s*(?:[٠-٩0-9]+\s*(?:[.)،,:؛\-–—]+\s*|\s+)|[\-–—•*]\s*)/, "");
  result = result.replace(/^\s*(?:[٠-٩0-9]+\s*(?:[.)،,:؛\-–—]+\s*|\s+)|[\-–—•*]\s*)/, "");
  return normalizeWhitespace(result.replace(/[،,:؛]+$/g, ""));
}

export function isStudentName(value: string) {
  const name = cleanStudentName(value);
  return name.split(" ").filter(Boolean).length >= 2 && hasLetters(name) && !isHeader(name);
}

export function namesFromLines(lines: string[]) {
  return lines.map(cleanStudentName).filter(isStudentName);
}

export function deduplicateStudentNames(names: string[], existingNames: string[]) {
  const seen = new Set(existingNames.map(normalizeNameIdentity));
  const accepted: string[] = [];
  const duplicateNames: string[] = [];

  for (const candidate of names) {
    const name = cleanStudentName(candidate);
    const identity = normalizeNameIdentity(name);
    if (!identity || seen.has(identity)) {
      duplicateNames.push(name);
      continue;
    }
    seen.add(identity);
    accepted.push(name);
  }

  return { accepted, duplicateNames };
}

export function studentNameParts(fullName: string) {
  const parts = cleanStudentName(fullName).split(" ").filter(Boolean);
  return {
    firstName: parts[0] ?? "",
    fatherName: parts.length > 2 ? parts[1] : "",
    lastName: parts.length > 2 ? parts.slice(2).join(" ") : parts[1] ?? "",
  };
}

function findNameColumn(rows: string[][]) {
  for (const row of rows.slice(0, 8)) {
    const index = row.findIndex((cell) => isHeader(cell));
    if (index >= 0) return index;
  }
  return -1;
}

function rowCandidate(row: string[], nameColumn: number) {
  if (nameColumn >= 0) return row[nameColumn] ?? "";
  return row
    .map((cell) => normalizeWhitespace(cell))
    .filter((cell) => hasLetters(cell))
    .sort((left, right) => right.length - left.length)[0] ?? "";
}

/** Extracts the explicit name column, or the longest text cell when no header is present. */
export function namesFromExcelBytes(bytes: Uint8Array) {
  const workbook = XLSX.read(bytes, { type: "array", cellText: true, cellDates: false });
  const names: string[] = [];
  let sourceRows = 0;

  for (const sheetName of workbook.SheetNames) {
    const sheet = workbook.Sheets[sheetName];
    const rows = XLSX.utils.sheet_to_json<string[]>(sheet, { header: 1, defval: "", raw: false })
      .map((row) => row.map((cell) => String(cell ?? "")));
    const nameColumn = findNameColumn(rows);
    for (const row of rows) {
      const candidate = rowCandidate(row, nameColumn);
      if (!candidate || isHeader(candidate)) continue;
      sourceRows += 1;
      if (isStudentName(candidate)) names.push(cleanStudentName(candidate));
    }
  }

  return { names, sourceRows };
}

/** Extracts visible paragraphs from the XML contained in a modern .docx Word document. */
export function namesFromWordDocumentXml(documentXml: string) {
  const paragraphs = documentXml.match(/<w:p\b[^>]*>[\s\S]*?<\/w:p>/g) ?? [];
  const lines = paragraphs.map((paragraph) => {
    const withBreaks = paragraph.replace(/<w:(?:br|cr)\s*\/?>/g, "\n").replace(/<w:tab\s*\/?>/g, " ");
    const texts = [...withBreaks.matchAll(/<w:t\b[^>]*>([\s\S]*?)<\/w:t>/g)].map((match) => decodeXml(match[1]));
    return texts.join("");
  });
  return { names: namesFromLines(lines), sourceRows: lines.filter((line) => normalizeWhitespace(line)).length };
}

export function namesFromDocxBytes(bytes: Uint8Array) {
  let files: Record<string, Uint8Array>;
  try {
    files = unzipSync(bytes);
  } catch {
    throw new Error("تعذر فتح ملف Word. يرجى اختيار ملف بصيغة DOCX حديثة.");
  }
  const document = files["word/document.xml"];
  if (!document) throw new Error("ملف Word لا يحتوي على محتوى قابل للقراءة.");
  return namesFromWordDocumentXml(strFromU8(document));
}

export function namesFromText(text: string) {
  const lines = text.replace(/^\uFEFF/, "").split(/\r?\n/);
  return { names: namesFromLines(lines), sourceRows: lines.filter((line) => normalizeWhitespace(line)).length };
}

export function formatForFilename(filename: string): StudentImportFormat | null {
  const extension = filename.trim().toLocaleLowerCase().split(".").pop() ?? "";
  if (extension === "xlsx" || extension === "xls") return "excel";
  if (extension === "docx") return "word";
  if (extension === "txt" || extension === "csv") return "text";
  return null;
}
