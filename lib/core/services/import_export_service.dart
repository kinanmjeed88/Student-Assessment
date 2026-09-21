import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart';

import 'file_storage_service.dart';
import 'workbook_names_reader.dart';

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

  /// يقرأ أسماء الطلاب من مصنّف Excel.
  ///
  /// تُفكّ كل ورقة إلى نصوص ثم تُمرَّر إلى [readStudentNamesFromSheets] الذي
  /// يتعرف على عمود الاسم من الترويسة. هكذا يقرأ الاستيراد ملفات التطبيق
  /// المصدَّرة (حيث العمود الأول هو التسلسل «ت» ثم «الاسم الكامل») كما يقرأ
  /// ملفات المعلم البسيطة ذات العمود الواحد.
  List<String> _readWorkbook(List<int> bytes) {
    final workbook = Excel.decodeBytes(bytes);
    final sheets = <List<List<String>>>[];
    for (final table in workbook.tables.values) {
      final rows = <List<String>>[];
      for (final row in table.rows) {
        rows.add(row.map((cell) => cell?.value?.toString() ?? '').toList());
      }
      sheets.add(rows);
    }
    return readStudentNamesFromSheets(sheets);
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

  /// يوحّد المسافات ويستبعد الترويسات والعناوين والأرقام ويزيل التكرار.
  ///
  /// المنطق موحَّد في [cleanStudentNames] لتشترك فيه مسارات الاستيراد من
  /// Excel وWord والنصوص، وحتى تغطيه الاختبارات دون حاجة إلى منتقي ملفات.
  List<String> _cleanNames(Iterable<String> values) => cleanStudentNames(values);
}
