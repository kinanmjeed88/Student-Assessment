import * as DocumentPicker from "expo-document-picker";
import * as FileSystem from "expo-file-system/legacy";
import { Platform } from "react-native";
import {
  deduplicateStudentNames,
  formatForFilename,
  namesFromDocxBytes,
  namesFromExcelBytes,
  namesFromText,
  type StudentImportFormat,
} from "@/lib/student-import-format";

export { cleanStudentName, deduplicateStudentNames, namesFromDocxBytes, namesFromExcelBytes, namesFromText, namesFromWordDocumentXml, studentNameParts } from "@/lib/student-import-format";
export type { StudentImportFormat } from "@/lib/student-import-format";

export type StudentImportPreview = {
  filename: string;
  format: StudentImportFormat;
  names: string[];
  skippedRows: number;
  duplicateNames: string[];
};

function base64ToBytes(base64: string) {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  const clean = base64.replace(/[^A-Za-z0-9+/=]/g, "");
  const padding = clean.endsWith("==") ? 2 : clean.endsWith("=") ? 1 : 0;
  const result = new Uint8Array(Math.max(0, Math.floor((clean.length * 3) / 4) - padding));
  let buffer = 0;
  let bits = 0;
  let offset = 0;
  for (const character of clean) {
    if (character === "=") break;
    const value = alphabet.indexOf(character);
    if (value < 0) continue;
    buffer = (buffer << 6) | value;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      result[offset] = (buffer >> bits) & 0xff;
      offset += 1;
    }
  }
  return result;
}

async function readText(asset: DocumentPicker.DocumentPickerAsset) {
  if (Platform.OS === "web" && asset.file) return asset.file.text();
  return FileSystem.readAsStringAsync(asset.uri, { encoding: FileSystem.EncodingType.UTF8 });
}

async function readBytes(asset: DocumentPicker.DocumentPickerAsset) {
  if (Platform.OS === "web" && asset.file) return new Uint8Array(await asset.file.arrayBuffer());
  const encoded = await FileSystem.readAsStringAsync(asset.uri, { encoding: FileSystem.EncodingType.Base64 });
  return base64ToBytes(encoded);
}

export async function parseStudentImportFile(asset: DocumentPicker.DocumentPickerAsset, existingNames: string[]): Promise<StudentImportPreview> {
  const format = formatForFilename(asset.name);
  if (!format) throw new Error("الصيغة غير مدعومة. اختر Excel ‏(.xlsx أو .xls) أو Word ‏(.docx) أو ملف نصي ‏(.txt أو .csv).");

  const extracted = format === "text"
    ? namesFromText(await readText(asset))
    : format === "excel"
      ? namesFromExcelBytes(await readBytes(asset))
      : namesFromDocxBytes(await readBytes(asset));
  const { accepted, duplicateNames } = deduplicateStudentNames(extracted.names, existingNames);
  return {
    filename: asset.name,
    format,
    names: accepted,
    skippedRows: Math.max(0, extracted.sourceRows - extracted.names.length),
    duplicateNames,
  };
}

export async function chooseStudentImportFile(existingNames: string[]) {
  const result = await DocumentPicker.getDocumentAsync({
    type: [
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "application/vnd.ms-excel",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "text/plain",
      "text/csv",
      "application/csv",
    ],
    multiple: false,
    copyToCacheDirectory: true,
  });
  if (result.canceled) return { canceled: true as const };
  return { canceled: false as const, preview: await parseStudentImportFile(result.assets[0], existingNames) };
}
