import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class PickedFileBytes {
  const PickedFileBytes({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class FileStorageService {
  const FileStorageService();

  Future<PickedFileBytes?> pickFile({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw const FormatException('تعذر قراءة محتوى الملف المحدد.');
    }
    return PickedFileBytes(name: file.name, bytes: bytes);
  }

  Future<String?> saveBytes({
    required List<int> bytes,
    required String fileName,
    String? dialogTitle,
    List<String>? allowedExtensions,
  }) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: allowedExtensions == null ? FileType.any : FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (path == null) return null;
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }
}
