import 'dart:typed_data';

import 'package:excel/excel.dart';

/// اسم الورقة المجمِّعة التي تحتوي كل السجلات بلا استثناء.
const String kAllRecordsSheetName = 'الكل';

/// اسم المجموعة المستخدم عندما لا يمكن نسب السجل إلى صف معروف.
const String kUnassignedGroupName = 'غير محدد';

/// وصف عمود واحد في تقرير Excel.
class ReportColumn {
  const ReportColumn(this.header, this.width);

  final String header;
  final double width;
}

/// صف بيانات واحد ينتمي إلى مجموعة (صف دراسي) محددة.
class ReportRow {
  const ReportRow({required this.group, required this.cells});

  /// اسم المجموعة التي ينتمي إليها الصف، ويقابل عادةً اسم الصف الدراسي.
  final String group;

  /// قيم الخلايا مرتبة حسب ترتيب [ReportColumn] المنطقي.
  ///
  /// هذا الترتيب المنطقي هو نفسه الترتيب البصري من اليمين إلى اليسار، لأن
  /// الورقة تُضبط على `rightToLeft` فتُعرض الخلية الأولى (العمود A) في أقصى
  /// اليمين. لا يُعكس الترتيب فيزيائياً هنا ولا في [ExcelReportBuilder].
  final List<CellValue?> cells;
}

/// باني مصنّفات Excel للتقارير العربية.
///
/// صُمّم ليعالج ثلاث مشكلات كانت تظهر في الملفات المصدَّرة:
///
/// 1. الاعتماد على `Sheet.appendRow` مع مؤشر صف يُدار يدوياً للتنسيق، وهو ما
///    يجعل موضع القيمة ومَوضع التنسيق ينحرفان عن بعضهما. هنا تُكتب كل خلية
///    صراحةً عبر [Sheet.updateCell] بمؤشر واحد لا يتكرر، فلا يضيع أي صف.
/// 2. بقاء الورقة الافتراضية الفارغة `Sheet1` داخل المصنّف، فتفتح أولاً ويبدو
///    الملف وكأنه يحتوي ورقة واحدة فارغة. تُحذف هنا دائماً.
/// 3. اقتصار التقرير على صف دراسي واحد. هنا يُنتج المصنّف ورقة «الكل» تضم كل
///    السجلات، إضافةً إلى ورقة مستقلة لكل صف دراسي بلا استثناء.
/// 4. انقلاب ترتيب الأعمدة في الملف المصدَّر. كانت الأوراق تُضبط على
///    `rightToLeft` وتُعكس أعمدةُها فيزيائياً في الوقت نفسه، فيحصل انعكاس
///    مزدوج يظهر معه الجدول بترتيب إنكليزي من اليسار إلى اليمين (عمود «ت»
///    والاسم الكامل في أقصى اليسار). الآن تُضبط الورقة `rightToLeft` وتُكتب
///    القيم بترتيبها المنطقي فقط، فيبدأ الجدول من اليمين بـ«ت» ثم الاسم.
class ExcelReportBuilder {
  ExcelReportBuilder() : _workbook = Excel.createExcel();

  final Excel _workbook;
  final Set<String> _usedSheetNames = <String>{};
  final List<String> _createdSheets = <String>[];

  /// أسماء الأوراق التي أُنشئت فعلياً بالترتيب.
  List<String> get sheetNames => List<String>.unmodifiable(_createdSheets);

  /// يضيف قسماً كاملاً: ورقة «الكل» ثم ورقة لكل مجموعة.
  ///
  /// [groupOrder] يحدد ترتيب المجموعات وأيضاً المجموعات التي يجب أن تظهر حتى
  /// لو كانت فارغة (مثل صف دراسي لا يحتوي طلاباً بعد)، فلا يُستثنى أي صف.
  void addGroupedSection({
    required String sheetBaseName,
    required String title,
    required String subtitle,
    required List<ReportColumn> columns,
    required List<ReportRow> rows,
    required String totalLabel,
    List<String> groupOrder = const <String>[],
    bool includeAllSheet = true,
  }) {
    if (includeAllSheet) {
      addSheet(
        name: '$sheetBaseName - $kAllRecordsSheetName',
        title: title,
        subtitle: subtitle,
        columns: columns,
        rows: rows.map((row) => row.cells).toList(growable: false),
        totalLabel: totalLabel,
      );
    }

    final grouped = <String, List<ReportRow>>{};
    for (final group in groupOrder) {
      grouped.putIfAbsent(group, () => <ReportRow>[]);
    }
    for (final row in rows) {
      grouped.putIfAbsent(row.group, () => <ReportRow>[]).add(row);
    }

    for (final entry in grouped.entries) {
      addSheet(
        name: entry.key,
        title: '$title - ${entry.key}',
        subtitle: subtitle,
        columns: columns,
        rows: entry.value.map((row) => row.cells).toList(growable: false),
        totalLabel: totalLabel,
      );
    }
  }

  /// ينشئ ورقة واحدة ويكتب كل صفوفها.
  void addSheet({
    required String name,
    required String title,
    required String subtitle,
    required List<ReportColumn> columns,
    required List<List<CellValue?>> rows,
    required String totalLabel,
  }) {
    assert(columns.isNotEmpty, 'يجب تعريف عمود واحد على الأقل.');
    final sheetName = _uniqueSheetName(name);
    final sheet = _workbook[sheetName];
    sheet.isRTL = true;
    _createdSheets.add(sheetName);

    final lastColumn = columns.length - 1;
    // الورقة مضبوطة على `rightToLeft` أعلاه، وهذا وحده يجعل Excel يعرض العمود A
    // في أقصى اليمين. لذلك تُكتب الأعمدة بترتيبها المنطقي دون عكس فيزيائي،
    // وإلا انقلب الترتيب مرتين وظهر الجدول كأنه إنكليزي من اليسار إلى اليمين.

    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: lastColumn, rowIndex: 0),
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: lastColumn, rowIndex: 1),
    );
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      TextCellValue(title),
      cellStyle: titleStyle,
    );
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      TextCellValue(subtitle),
      cellStyle: subtitleStyle,
    );

    for (var column = 0; column < columns.length; column++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: headerRowIndex),
        TextCellValue(columns[column].header),
        cellStyle: headerStyle,
      );
      sheet.setColumnWidth(column, columns[column].width);
    }

    var rowIndex = firstDataRowIndex;
    for (final row in rows) {
      final values = _normalize(row, columns.length);
      for (var column = 0; column < values.length; column++) {
        sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: column, rowIndex: rowIndex),
          values[column],
          cellStyle: bodyStyle,
        );
      }
      sheet.setRowHeight(rowIndex, 24);
      rowIndex++;
    }

    if (rows.isEmpty) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        TextCellValue('لا توجد سجلات'),
        cellStyle: bodyStyle,
      );
      rowIndex++;
    }

    _writeFooter(sheet, rowIndex, lastColumn, totalLabel, rows.length);

    sheet.setRowHeight(0, 28);
    sheet.setRowHeight(1, 22);
    sheet.setRowHeight(headerRowIndex, 30);
  }

  /// يحذف الورقة الافتراضية الفارغة ويعيد بايتات الملف.
  Uint8List save() {
    if (_createdSheets.isEmpty) {
      addSheet(
        name: kAllRecordsSheetName,
        title: 'تقرير فارغ',
        subtitle: 'لا توجد بيانات لعرضها.',
        columns: const [ReportColumn('البيان', 30)],
        rows: const <List<CellValue?>>[],
        totalLabel: 'عدد السجلات',
      );
    }

    // إزالة الورقة الافتراضية `Sheet1` حتى لا تُفتح ورقة فارغة أولاً.
    for (final defaultName in const ['Sheet1', 'Sheet']) {
      if (_workbook.sheets.containsKey(defaultName) && !_createdSheets.contains(defaultName)) {
        _workbook.delete(defaultName);
      }
    }
    _workbook.setDefaultSheet(_createdSheets.first);

    final bytes = _workbook.save();
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('تعذر إنشاء ملف Excel.');
    }
    return Uint8List.fromList(bytes);
  }

  void _writeFooter(Sheet sheet, int rowIndex, int lastColumn, String label, int count) {
    // العمود صفر هو أقصى يمين ورقة RTL، فتُكتب التسمية فيه والقيمة في العمود
    // المجاور له يساراً.
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
      TextCellValue(label),
      cellStyle: footerStyle,
    );
    final valueColumn = lastColumn >= 1 ? 1 : 0;
    if (valueColumn != 0) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: valueColumn, rowIndex: rowIndex),
        IntCellValue(count),
        cellStyle: footerStyle,
      );
    }
    sheet.setRowHeight(rowIndex, 24);
  }

  List<CellValue?> _normalize(List<CellValue?> values, int length) {
    if (values.length == length) return values;
    if (values.length > length) return values.sublist(0, length);
    return [...values, ...List<CellValue?>.filled(length - values.length, null)];
  }

  /// أسماء أوراق Excel لا تتجاوز ٣١ محرفاً ولا تحتوي `[]:*?/\`.
  String _uniqueSheetName(String requested) {
    var base = requested.replaceAll(_invalidSheetNameChars, ' ').replaceAll(_whitespace, ' ').trim();
    if (base.startsWith("'")) base = base.substring(1);
    if (base.endsWith("'")) base = base.substring(0, base.length - 1);
    if (base.isEmpty) base = kUnassignedGroupName;
    if (base.length > 31) base = base.substring(0, 31).trim();

    var candidate = base;
    var index = 2;
    while (_usedSheetNames.contains(candidate)) {
      final suffix = ' ($index)';
      final maxBase = 31 - suffix.length;
      final trimmed = base.length > maxBase ? base.substring(0, maxBase).trim() : base;
      candidate = '$trimmed$suffix';
      index++;
    }
    _usedSheetNames.add(candidate);
    return candidate;
  }

  static final RegExp _invalidSheetNameChars = RegExp(r'[\[\]:*?/\\]');
  static final RegExp _whitespace = RegExp(r'\s+');

  static const int headerRowIndex = 2;
  static const int firstDataRowIndex = 3;

  static final CellStyle titleStyle = CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('1F4E78'),
    fontColorHex: ExcelColor.white,
    fontSize: 16,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  static final CellStyle subtitleStyle = CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('D9EAF7'),
    fontColorHex: ExcelColor.fromHexString('1F2937'),
    fontSize: 10,
    italic: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  static final CellStyle headerStyle = CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('2F75B5'),
    fontColorHex: ExcelColor.white,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
  );

  static final CellStyle bodyStyle = CellStyle(
    fontColorHex: ExcelColor.fromHexString('1F2937'),
    horizontalAlign: HorizontalAlign.Right,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
  );

  static final CellStyle footerStyle = CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('EAF2F8'),
    fontColorHex: ExcelColor.fromHexString('1F2937'),
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );
}
