import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class BackupService {
  Future<String?> saveJson(String json) async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'حفظ النسخة الاحتياطية',
      fileName: 'almoktaber-backup.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: Uint8List.fromList(utf8.encode(json)),
    );
    return path?.toString();
  }
}
