import 'dart:convert';
import '../../../core/services/file_storage_service.dart';

class BackupService {
  Future<String?> saveJson(String json) async {
    return const FileStorageService().saveBytes(
      dialogTitle: 'حفظ النسخة الاحتياطية',
      fileName: 'almoktaber-backup.json',
      bytes: utf8.encode(json),
    );
  }
}
