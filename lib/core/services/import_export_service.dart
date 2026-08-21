import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart';

import 'file_storage_service.dart';

class ImportedStudentsFile {
  const ImportedStudentsFile({required this.filename, required this.names, required this.format});

  final String filename;
  final List<String> names;
  final String format;
}

class ImportExportService {
  Future<ImportedStudentsFile?> pickStudentsFile() async {
    final picked = await const FileStorageService().pickFile(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv', 'txt', 'docx'],
    );
    if (picked == null) return null;

    final Uint8List bytes = picked.bytes;
    if (bytes.isEmpty) throw const FormatException('تعذر قراءة الملف المحدد.');

    final extension = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : '';
    final rawNames = switch (extension) {
      'txt' || 'csv' => _readDelimited(bytes),
      'docx' => _readDocx(bytes),
      'xlsx' || 'xls' => _readWorkbook(bytes),
      _ => <String>[],
    };
    final filtered = _cleanNames(rawNames);
    if (filtered.isEmpty) throw const FormatException('لم يتم العثور على أسماء طلاب في الملف.');

    return ImportedStudentsFile(
      filename: picked.name,
      names: filtered,
      format: extension == 'xlsx' || extension == 'xls' ? 'excel' : extension == 'docx' ? 'word' : 'text',
    );
  }

  List<String> _readDelimited(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    return text
        .split(RegExp(r'\r?\n'))
        .expand((line) => line.split(RegExp(r'[,;\t]')).take(1))
        .toList();
  }

  List<String> _readWorkbook(List<int> bytes) {
    final workbook = Excel.decodeBytes(bytes);
    final names = <String>[];
    for (final table in workbook.tables.values) {
      for (final row in table.rows) {
        final values = row
            .map((cell) => cell?.value?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toList();
        if (values.isNotEmpty) names.add(values.first);
      }
    }
    return names;
  }

  List<String> _readDocx(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? documentFile;
    for (final entry in archive) {
      if (entry.isFile && entry.name == 'word/document.xml') {
        documentFile = entry;
        break;
      }
    }
    if (documentFile == null) throw const FormatException('ملف Word لا يحتوي على مستند صالح.');

    final documentBytes = documentFile.content as List<int>;
    final xml = XmlDocument.parse(utf8.decode(documentBytes, allowMalformed: true));
    return xml.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'p')
        .map(
          (paragraph) => paragraph.descendants
              .whereType<XmlElement>()
              .where((element) => element.name.local == 't')
              .map((element) => element.innerText)
              .join(),
        )
        .where((value) => value.trim().isNotEmpty)
        .toList();
  }

  List<String> _cleanNames(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (normalized.isEmpty || _isHeader(normalized)) continue;
      final key = normalized.toLowerCase();
      if (seen.add(key)) result.add(normalized);
    }
    return result;
  }

  bool _isHeader(String value) {
    final normalized = value.toLowerCase();
    return const ['name', 'full name', 'student name', 'الاسم', 'اسم الطالب', 'الطلاب'].any(normalized.contains);
  }
}
