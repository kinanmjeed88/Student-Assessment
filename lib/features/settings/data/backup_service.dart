import 'dart:convert';

import 'package:file_picker/file_picker.dart';

class BackupService {
  Future<String?> saveJson(String json) async {
    return FilePicker.platform.saveFile(
      dialogTitle: 'حفظ النسخة الاحتياطية',
      fileName: 'almoktaber-backup.json',
      bytes: utf8.encode(json),
    );
  }
}
