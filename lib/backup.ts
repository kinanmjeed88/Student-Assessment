import { Platform } from "react-native";
import * as DocumentPicker from "expo-document-picker";
import * as FileSystem from "expo-file-system/legacy";
import * as Sharing from "expo-sharing";
import type { AppData } from "@/lib/student-store";
import { getBackupSummary, parseStudentBackup, serializeStudentBackup, type BackupSummary, type StudentBackup } from "@/lib/backup-format";

export type BackupImportResult = { canceled: true } | { canceled: false; backup: StudentBackup; summary: BackupSummary; filename: string };

function backupFilename() {
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  return `student-record-backup-${stamp}.json`;
}

export async function exportBackupToDevice(data: AppData): Promise<string> {
  if (Platform.OS === "web") {
    throw new Error("تصدير النسخة الاحتياطية متاح من تطبيق الهاتف.");
  }

  const filename = backupFilename();
  const uri = `${FileSystem.cacheDirectory}${filename}`;
  await FileSystem.writeAsStringAsync(uri, serializeStudentBackup(data), { encoding: FileSystem.EncodingType.UTF8 });

  if (!(await Sharing.isAvailableAsync())) {
    throw new Error("تعذر فتح خيارات الحفظ على هذا الجهاز.");
  }
  await Sharing.shareAsync(uri, {
    mimeType: "application/json",
    dialogTitle: "حفظ النسخة الاحتياطية لسجل الطالب",
    UTI: "public.json",
  });
  return filename;
}

async function readPickedFile(asset: DocumentPicker.DocumentPickerAsset): Promise<string> {
  if (Platform.OS === "web" && asset.file) {
    return asset.file.text();
  }
  return FileSystem.readAsStringAsync(asset.uri, { encoding: FileSystem.EncodingType.UTF8 });
}

export async function pickBackupFromDevice(): Promise<BackupImportResult> {
  const result = await DocumentPicker.getDocumentAsync({
    type: ["application/json", "text/json", "text/plain"],
    multiple: false,
    copyToCacheDirectory: true,
  });
  if (result.canceled) return { canceled: true };

  const asset = result.assets[0];
  const backup = parseStudentBackup(await readPickedFile(asset));
  return { canceled: false, backup, summary: getBackupSummary(backup), filename: asset.name };
}
