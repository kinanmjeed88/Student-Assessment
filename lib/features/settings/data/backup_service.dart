import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class BackupService {
  Future<String?> saveJson(String json) async {
    return FilePicker.saveFile(
      dialogTitle: 'حفظ النسخة الاحتياطية',
      fileName: 'almoktaber-backup.json',
      bytes: Uint8List.fromList(utf8.encode(json)),
    ).then((uri) => uri?.toFilePath());
  }
}
