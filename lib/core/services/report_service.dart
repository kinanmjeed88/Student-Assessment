import 'dart:convert';

import 'package:excel_plus/excel_plus.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../behavior/behavior_summary.dart';
import '../database/app_snapshot.dart';
import '../database/isar_models.dart';
import '../utils/iterable_extensions.dart';

class ReportService {
  Uint8List exportStudentsXlsx(AppSnapshot snapshot) {
    final workbook = Excel.createExcel();
    final sheet = _createSheet(
      workbook,
      'الطلاب',
      'تقرير الطلاب',
      'قائمة الطلاب مع الصف والشعبة والحالة وملخص السلوك',
      const ['الاسم الكامل', 'رقم الطالب', 'الصف', 'الشعبة', 'الجنس', 'الحالة', 'ولي الأمر', 'هاتف ولي الأمر', 'نقاط السلوك', 'حالة المتابعة'],
      const [28, 16, 18, 18, 12, 16, 24, 18, 14, 20],
    );
    var row = 3;
    for (final student in snapshot.students) {
      final summary = _behaviorSummary(snapshot, student.uuid);
      _appendRow(sheet, row++, [
        _text(student.fullName),
        _text(student.studentNumber),
        _text(_className(snapshot, student.classUuid)),
        _text(_sectionName(snapshot, student.sectionUuid)),
        _text(_genderLabel(student.gender)),
        _text(_studentStatusLabel(student.status)),
        _text(student.guardianName),
        _text(student.guardianPhone),
        _number(summary.totalPoints),
        _text(summary.label),
      ]);
    }
    _addFooter(sheet, row, 'عدد الطلاب', snapshot.students.length.toString());
    return _save(workbook);
  }

  Uint8List exportAttendanceXlsx(AppSnapshot snapshot) {
    final workbook = Excel.createExcel();
    final sheet = _createSheet(
      workbook,
      'الحضور',
      'تقرير الحضور والغياب',
      'سجل يومي يتضمن الحضور والغياب والتأخر والأعذار مع الأسباب والملاحظات',
      const ['الطالب', 'رقم الطالب', 'الصف', 'الشعبة', 'التاريخ', 'الحالة', 'السبب', 'ملاحظات'],
      const [28, 16, 18, 18, 15, 16, 28, 36],
    );
    var row = 3;
    for (final record in snapshot.attendance) {
      final student = _student(snapshot, record.studentUuid);
      _appendRow(sheet, row++, [
        _text(student?.fullName ?? record.studentUuid),
        _text(student?.studentNumber ?? ''),
        _text(student == null ? '' : _className(snapshot, student.classUuid)),
        _text(student == null ? '' : _sectionName(snapshot, student.sectionUuid)),
        _text(_date(record.date)),
        _text(_attendanceLabel(record.status)),
        _text(record.reason),
        _text(record.notes),
      ]);
    }
    _addFooter(sheet, row, 'عدد سجلات الحضور', snapshot.attendance.length.toString());
    return _save(workbook);
  }

  Uint8List exportGradesXlsx(AppSnapshot snapshot) {
    final workbook = Excel.createExcel();
    final sheet = _createSheet(
      workbook,
      'الدرجات',
      'تقرير الدرجات والتقييمات',
      'تفاصيل التقييمات والدرجات والنسب والملاحظات حسب الطالب والمادة',
      const ['الطالب', 'رقم الطالب', 'الصف', 'الشعبة', 'المادة', 'التقييم', 'الفصل', 'الدرجة', 'الحد الأقصى', 'النسبة', 'التقدير', 'ملاحظات'],
      const [26, 16, 16, 16, 20, 24, 18, 13, 15, 13, 16, 34],
    );
    var row = 3;
    for (final grade in snapshot.grades) {
      final field = snapshot.gradeFields.where((item) => item.uuid == grade.fieldUuid).firstOrNull;
      final student = _student(snapshot, grade.studentUuid);
      if (field == null || student == null) continue;
      final percentage = field.maxScore <= 0 ? 0.0 : grade.score / field.maxScore * 100.0;
      _appendRow(sheet, row++, [
        _text(student.fullName),
        _text(student.studentNumber),
        _text(_className(snapshot, student.classUuid)),
        _text(_sectionName(snapshot, student.sectionUuid)),
        _text(field.subject),
        _text(field.title),
        _text(field.term),
        _number(grade.score),
        _number(field.maxScore),
        _number(percentage),
        _text(_gradeLabel(percentage)),
        _text(grade.notes),
      ]);
    }
    _addFooter(sheet, row, 'عدد الدرجات', snapshot.grades.length.toString());
    return _save(workbook);
  }

  Uint8List exportBehaviorXlsx(AppSnapshot snapshot) {
    final workbook = Excel.createExcel();
    final sheet = _createSheet(
      workbook,
      'السلوك',
      'تقرير السلوك والمتابعة',
      'السجلات السلوكية والنقاط والإجراءات والمتابعات لكل طالب',
      const ['الطالب', 'رقم الطالب', 'الصف', 'الشعبة', 'التصنيف', 'نوع المخالفة', 'العنوان', 'التفاصيل', 'النقاط', 'التاريخ', 'الإجراء', 'المتابعة'],
      const [26, 16, 16, 16, 16, 20, 26, 38, 13, 15, 30, 30],
    );
    var row = 3;
    for (final record in snapshot.behaviors) {
      final student = _student(snapshot, record.studentUuid);
      _appendRow(sheet, row++, [
        _text(student?.fullName ?? record.studentUuid),
        _text(student?.studentNumber ?? ''),
        _text(student == null ? '' : _className(snapshot, student.classUuid)),
        _text(student == null ? '' : _sectionName(snapshot, student.sectionUuid)),
        _text(_behaviorCategoryLabel(record.category)),
        _text(_violationLabel(record.violationType)),
        _text(record.title),
        _text(record.details),
        _number(record.penaltyPoints),
        _text(_date(record.date)),
        _text(record.actionTaken),
        _text(record.followUp),
      ]);
    }
    _addFooter(sheet, row, 'عدد السجلات السلوكية', snapshot.behaviors.length.toString());
    return _save(workbook);
  }

  Uint8List exportNotesXlsx(AppSnapshot snapshot) {
    final workbook = Excel.createExcel();
    final sheet = _createSheet(
      workbook,
      'الملاحظات',
      'تقرير الملاحظات والمتابعة',
      'الملاحظات الأكاديمية والصحية والتربوية ومواعيد المتابعة',
      const ['الطالب', 'رقم الطالب', 'الصف', 'الشعبة', 'التصنيف', 'العنوان', 'التفاصيل', 'تحتاج متابعة', 'تاريخ المتابعة', 'التاريخ'],
      const [26, 16, 16, 16, 18, 26, 42, 16, 18, 15],
    );
    var row = 3;
    for (final note in snapshot.notes) {
      final student = _student(snapshot, note.studentUuid);
      _appendRow(sheet, row++, [
        _text(student?.fullName ?? note.studentUuid),
        _text(student?.studentNumber ?? ''),
        _text(student == null ? '' : _className(snapshot, student.classUuid)),
        _text(student == null ? '' : _sectionName(snapshot, student.sectionUuid)),
        _text(_noteCategoryLabel(note.category)),
        _text(note.title),
        _text(note.details),
        _text(note.needsFollowUp ? 'نعم' : 'لا'),
        _text(note.followUpDate == null ? '' : _date(note.followUpDate!)),
        _text(_date(note.date)),
      ]);
    }
    _addFooter(sheet, row, 'عدد الملاحظات', snapshot.notes.length.toString());
    return _save(workbook);
  }

  Uint8List exportImportHistoryXlsx(AppSnapshot snapshot) {
    final workbook = Excel.createExcel();
    final sheet = _createSheet(
      workbook,
      'سجل الاستيراد',
      'تقرير سجل استيراد الطلاب',
      'مصادر الملفات وعمليات الإضافة والتراجع وحالة كل عملية',
      const ['اسم الملف', 'الصيغة', 'الصف', 'الشعبة', 'عدد الطلاب', 'تاريخ الاستيراد', 'الحالة', 'تاريخ التراجع'],
      const [34, 16, 20, 20, 16, 18, 18, 18],
    );
    var row = 3;
    for (final record in snapshot.imports) {
      _appendRow(sheet, row++, [
        _text(record.sourceFilename),
        _text(_importFormatLabel(record.sourceFormat)),
        _text(_className(snapshot, record.classUuid)),
        _text(_sectionName(snapshot, record.sectionUuid)),
        _integer(record.addedCount),
        _text(_date(record.createdAt)),
        _text(record.revertedAt == null ? 'نشط' : 'متراجع عنه'),
        _text(record.revertedAt == null ? '' : _date(record.revertedAt!)),
      ]);
    }
    _addFooter(sheet, row, 'عدد عمليات الاستيراد', snapshot.imports.length.toString());
    return _save(workbook);
  }

  Uint8List exportStudentXlsx(AppSnapshot snapshot, String studentUuid) {
    final student = _student(snapshot, studentUuid);
    if (student == null) throw const FormatException('الطالب غير موجود.');
    final behavior = _behaviorSummary(snapshot, studentUuid);
    final workbook = Excel.createExcel();

    final profile = _createSheet(
      workbook,
      'الملف الشخصي',
      'ملف الطالب',
      'البيانات الأساسية وملخص المتابعة السلوكية',
      const ['الحقل', 'القيمة'],
      const [26, 46],
    );
    var profileRow = 3;
    final profileData = <List<CellValue?>>[
      [_text('الاسم الكامل'), _text(student.fullName)],
      [_text('رقم الطالب'), _text(student.studentNumber)],
      [_text('الجنس'), _text(_genderLabel(student.gender))],
      [_text('الصف'), _text(_className(snapshot, student.classUuid))],
      [_text('الشعبة'), _text(_sectionName(snapshot, student.sectionUuid))],
      [_text('الحالة'), _text(_studentStatusLabel(student.status))],
      [_text('ولي الأمر'), _text(student.guardianName)],
      [_text('هاتف ولي الأمر'), _text(student.guardianPhone)],
      [_text('نقاط السلوك'), _number(behavior.totalPoints)],
      [_text('حالة المتابعة'), _text(behavior.label)],
    ];
    for (final values in profileData) {
      _appendRow(profile, profileRow++, values);
    }

    final grades = _createSheet(workbook, 'الدرجات', 'درجات الطالب', 'التقييمات والدرجات والنسب والملاحظات', const ['المادة', 'التقييم', 'الفصل', 'الدرجة', 'الحد الأقصى', 'النسبة', 'التقدير', 'ملاحظات'], const [22, 26, 18, 13, 15, 13, 16, 36]);
    var gradeRow = 3;
    for (final grade in snapshot.gradesFor(studentUuid)) {
      final field = snapshot.gradeFields.where((item) => item.uuid == grade.fieldUuid).firstOrNull;
      if (field == null) continue;
      final percentage = field.maxScore <= 0 ? 0.0 : grade.score / field.maxScore * 100.0;
      _appendRow(grades, gradeRow++, [_text(field.subject), _text(field.title), _text(field.term), _number(grade.score), _number(field.maxScore), _number(percentage), _text(_gradeLabel(percentage)), _text(grade.notes)]);
    }
    _addFooter(grades, gradeRow, 'عدد التقييمات', '${gradeRow - 3}');

    final attendance = _createSheet(workbook, 'الحضور', 'حضور الطالب', 'سجل الحضور والغياب والتأخر والأعذار', const ['التاريخ', 'الحالة', 'السبب', 'ملاحظات'], const [18, 18, 34, 42]);
    var attendanceRow = 3;
    for (final record in snapshot.attendanceFor(studentUuid)) {
      _appendRow(attendance, attendanceRow++, [_text(_date(record.date)), _text(_attendanceLabel(record.status)), _text(record.reason), _text(record.notes)]);
    }
    _addFooter(attendance, attendanceRow, 'عدد سجلات الحضور', '${attendanceRow - 3}');

    final behaviorSheet = _createSheet(workbook, 'السلوك', 'سجل سلوك الطالب', 'المخالفات والإيجابيات والإجراءات والمتابعات', const ['التصنيف', 'نوع المخالفة', 'العنوان', 'التفاصيل', 'النقاط', 'التاريخ', 'الإجراء', 'المتابعة'], const [18, 20, 26, 38, 13, 15, 30, 30]);
    var behaviorRow = 3;
    for (final record in snapshot.behaviorsFor(studentUuid)) {
      _appendRow(behaviorSheet, behaviorRow++, [_text(_behaviorCategoryLabel(record.category)), _text(_violationLabel(record.violationType)), _text(record.title), _text(record.details), _number(record.penaltyPoints), _text(_date(record.date)), _text(record.actionTaken), _text(record.followUp)]);
    }
    _addFooter(behaviorSheet, behaviorRow, 'عدد سجلات السلوك', '${behaviorRow - 3}');

    final notes = _createSheet(workbook, 'الملاحظات', 'ملاحظات الطالب', 'الملاحظات الأكاديمية والصحية والتربوية والمتابعة', const ['التصنيف', 'العنوان', 'التفاصيل', 'تحتاج متابعة', 'تاريخ المتابعة', 'التاريخ'], const [18, 26, 42, 16, 18, 15]);
    var noteRow = 3;
    for (final note in snapshot.notesFor(studentUuid)) {
      _appendRow(notes, noteRow++, [_text(_noteCategoryLabel(note.category)), _text(note.title), _text(note.details), _text(note.needsFollowUp ? 'نعم' : 'لا'), _text(note.followUpDate == null ? '' : _date(note.followUpDate!)), _text(_date(note.date))]);
    }
    _addFooter(notes, noteRow, 'عدد الملاحظات', '${noteRow - 3}');

    return _save(workbook);
  }

  Uint8List exportBackupJson(String json) => Uint8List.fromList(utf8.encode(json));

  Future<Uint8List> exportStudentsPdf(AppSnapshot snapshot) async {
    final theme = await _arabicPdfTheme();
    final document = pw.Document(title: 'تقرير الطلاب');
    final settings = snapshot.settings;
    final alerts = snapshot.students.where((student) => _behaviorSummary(snapshot, student.uuid).hasAlert).length;
    document.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => _pdfHeader(settings, 'تقرير الطلاب'),
        footer: (context) => _pdfFooter(context),
        build: (_) => [
          _pdfSummaryCards([
            ['إجمالي الطلاب', '${snapshot.students.length}'],
            ['الحضور اليوم', '${snapshot.todayAttendance.length}'],
            ['سجلات السلوك', '${snapshot.behaviors.length}'],
            ['التنبيهات', '$alerts'],
          ]),
          pw.SizedBox(height: 18),
          pw.Text('قائمة الطلاب', style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _pdfTable(
            headers: const ['الطالب', 'الرقم', 'الصف', 'الشعبة', 'الحالة', 'النقاط', 'المتابعة'],
            rows: snapshot.students.map((student) {
              final behavior = _behaviorSummary(snapshot, student.uuid);
              return [student.fullName, student.studentNumber, _className(snapshot, student.classUuid), _sectionName(snapshot, student.sectionUuid), _studentStatusLabel(student.status), behavior.totalPoints.toStringAsFixed(1), behavior.label];
            }).toList(),
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<Uint8List> exportStudentPdf(AppSnapshot snapshot, String studentUuid) async {
    final student = _student(snapshot, studentUuid);
    if (student == null) throw const FormatException('الطالب غير موجود.');
    final theme = await _arabicPdfTheme();
    final behavior = _behaviorSummary(snapshot, studentUuid);
    final document = pw.Document(title: 'ملف الطالب - ${student.fullName}');
    document.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => _pdfHeader(snapshot.settings, 'ملف الطالب'),
        footer: (context) => _pdfFooter(context),
        build: (_) => [
          pw.Text(student.fullName, style: const pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _pdfInfoTable([
            ['رقم الطالب', student.studentNumber],
            ['الجنس', _genderLabel(student.gender)],
            ['الصف', _className(snapshot, student.classUuid)],
            ['الشعبة', _sectionName(snapshot, student.sectionUuid)],
            ['الحالة', _studentStatusLabel(student.status)],
            ['ولي الأمر', student.guardianName],
            ['هاتف ولي الأمر', student.guardianPhone],
            ['نقاط السلوك', behavior.totalPoints.toStringAsFixed(1)],
            ['حالة المتابعة', behavior.label],
          ]),
          pw.SizedBox(height: 18),
          pw.Text('الدرجات والتقييمات', style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _pdfTable(headers: const ['المادة', 'التقييم', 'الدرجة', 'الحد الأقصى', 'النسبة', 'التقدير'], rows: snapshot.gradesFor(studentUuid).map((grade) {
            final field = snapshot.gradeFields.where((item) => item.uuid == grade.fieldUuid).firstOrNull;
            if (field == null) return <String>[];
            final percentage = field.maxScore <= 0 ? 0.0 : grade.score / field.maxScore * 100.0;
            return [field.subject, field.title, grade.score.toStringAsFixed(1), field.maxScore.toStringAsFixed(1), '${percentage.toStringAsFixed(1)}%', _gradeLabel(percentage)];
          }).where((row) => row.isNotEmpty).toList()),
          pw.SizedBox(height: 18),
          pw.Text('الحضور', style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _pdfTable(headers: const ['التاريخ', 'الحالة', 'السبب', 'ملاحظات'], rows: snapshot.attendanceFor(studentUuid).map((record) => [_date(record.date), _attendanceLabel(record.status), record.reason, record.notes]).toList()),
          pw.SizedBox(height: 18),
          pw.Text('السلوك والمتابعة', style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _pdfTable(headers: const ['التصنيف', 'العنوان', 'النقاط', 'التاريخ', 'الإجراء', 'المتابعة'], rows: snapshot.behaviorsFor(studentUuid).map((record) => [_behaviorCategoryLabel(record.category), record.title, record.penaltyPoints.toStringAsFixed(1), _date(record.date), record.actionTaken, record.followUp]).toList()),
          pw.SizedBox(height: 18),
          pw.Text('الملاحظات', style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _pdfTable(headers: const ['التصنيف', 'العنوان', 'التفاصيل', 'المتابعة', 'التاريخ'], rows: snapshot.notesFor(studentUuid).map((note) => [_noteCategoryLabel(note.category), note.title, note.details, note.needsFollowUp ? 'نعم' : 'لا', _date(note.date)]).toList()),
        ],
      ),
    );
    return document.save();
  }

  Future<pw.ThemeData> _arabicPdfTheme() async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'));
    return pw.ThemeData.withFont(base: regular, bold: bold);
  }

  Sheet _createSheet(Excel workbook, String name, String title, String subtitle, List<String> headers, List<double> widths) {
    final sheet = workbook[name];
    final lastColumn = headers.length - 1;
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), CellIndex.indexByColumnRow(columnIndex: lastColumn, rowIndex: 0));
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1), CellIndex.indexByColumnRow(columnIndex: lastColumn, rowIndex: 1));
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue(title)
      ..cellStyle = _titleStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      ..value = TextCellValue(subtitle)
      ..cellStyle = _subtitleStyle;
    sheet.appendRow([for (final header in headers) _text(header)]);
    for (var column = 0; column < headers.length; column++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 2)).cellStyle = _headerStyle;
      sheet.setColumnWidth(column, widths[column]);
    }
    sheet.setRowHeight(0, 28);
    sheet.setRowHeight(1, 22);
    sheet.setRowHeight(2, 30);
    return sheet;
  }

  void _appendRow(Sheet sheet, int row, List<CellValue?> values) {
    sheet.appendRow(values);
    for (var column = 0; column < values.length; column++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row)).cellStyle = _bodyStyle;
    }
    sheet.setRowHeight(row, 24);
  }

  void _addFooter(Sheet sheet, int row, String label, String value) {
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = TextCellValue(label)
      ..cellStyle = _footerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
      ..value = TextCellValue(value)
      ..cellStyle = _footerStyle;
  }

  CellValue _text(String value) => TextCellValue(value.trim());
  CellValue _number(double value) => DoubleCellValue(value);
  CellValue _integer(int value) => IntCellValue(value);
  Uint8List _save(Excel workbook) => Uint8List.fromList(workbook.save() ?? const <int>[]);

  BehaviorSummary _behaviorSummary(AppSnapshot snapshot, String studentUuid) => calculateBehaviorSummary(records: snapshot.behaviorsFor(studentUuid), settings: snapshot.settings);
  Student? _student(AppSnapshot snapshot, String uuid) => snapshot.students.where((item) => item.uuid == uuid).firstOrNull;
  String _className(AppSnapshot snapshot, String uuid) => snapshot.classes.where((item) => item.uuid == uuid).firstOrNull?.name ?? '';
  String _sectionName(AppSnapshot snapshot, String uuid) => snapshot.sections.where((item) => item.uuid == uuid).firstOrNull?.name ?? '';
  String _date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _genderLabel(StudentGender value) => value == StudentGender.male ? 'ذكر' : 'أنثى';
  String _studentStatusLabel(StudentStatus value) => switch (value) { StudentStatus.active => 'نشط', StudentStatus.transferred => 'منقول', StudentStatus.graduated => 'متخرج', StudentStatus.suspended => 'موقوف' };
  String _attendanceLabel(AttendanceStatus value) => switch (value) { AttendanceStatus.present => 'حاضر', AttendanceStatus.absent => 'غائب', AttendanceStatus.excused => 'معذور', AttendanceStatus.late => 'متأخر', AttendanceStatus.leave => 'إجازة' };
  String _behaviorCategoryLabel(BehaviorCategory value) => switch (value) { BehaviorCategory.positive => 'إيجابي', BehaviorCategory.followup => 'متابعة', BehaviorCategory.negative => 'مخالفة' };
  String _violationLabel(BehaviorViolationType value) => switch (value) { BehaviorViolationType.none => 'غير محدد', BehaviorViolationType.absence => 'غياب', BehaviorViolationType.lessonDisruption => 'تشويش الدرس', BehaviorViolationType.seriousMisconduct => 'سلوك جسيم', BehaviorViolationType.other => 'أخرى' };
  String _noteCategoryLabel(NoteCategory value) => switch (value) { NoteCategory.academic => 'أكاديمية', NoteCategory.health => 'صحية', NoteCategory.educational => 'تربوية', NoteCategory.attendance => 'حضور', NoteCategory.other => 'أخرى' };
  String _importFormatLabel(StudentImportFormat value) => switch (value) { StudentImportFormat.excel => 'Excel', StudentImportFormat.word => 'Word', StudentImportFormat.text => 'نص' };
  String _gradeLabel(double percentage) => percentage >= 90 ? 'ممتاز' : percentage >= 80 ? 'جيد جداً' : percentage >= 70 ? 'جيد' : percentage >= 50 ? 'مقبول' : 'يحتاج متابعة';

  static final _titleStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('1F4E78'), fillPattern: FillPatternType.solid, fontColorHex: ExcelColor.white, fontSize: 16, bold: true, horizontalAlign: HorizontalAlign.Center, verticalAlign: VerticalAlign.Center);
  static final _subtitleStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('D9EAF7'), fillPattern: FillPatternType.solid, fontColorHex: ExcelColor.fromHexString('1F2937'), fontSize: 10, italic: true, horizontalAlign: HorizontalAlign.Center, verticalAlign: VerticalAlign.Center);
  static final _headerStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('2F75B5'), fillPattern: FillPatternType.solid, fontColorHex: ExcelColor.white, bold: true, horizontalAlign: HorizontalAlign.Center, verticalAlign: VerticalAlign.Center, textWrapping: TextWrapping.WrapText);
  static final _bodyStyle = CellStyle(fontColorHex: ExcelColor.fromHexString('1F2937'), verticalAlign: VerticalAlign.Center, textWrapping: TextWrapping.WrapText);
  static final _footerStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('EAF2F8'), fillPattern: FillPatternType.solid, fontColorHex: ExcelColor.fromHexString('1F2937'), bold: true, horizontalAlign: HorizontalAlign.Center, verticalAlign: VerticalAlign.Center);

  pw.Widget _pdfHeader(AppSettings settings, String title) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Text(settings.schoolName.isEmpty ? 'سجل الطالب' : settings.schoolName, style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        if (settings.teacherName.isNotEmpty) pw.Text(settings.teacherName, style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 4),
        pw.Divider(color: PdfColors.blueGrey300),
        pw.Text(title, style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
      ]);

  pw.Widget _pdfFooter(pw.Context context) => pw.Align(alignment: pw.Alignment.center, child: pw.Text('صفحة ${context.pageNumber} من ${context.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)));

  pw.Widget _pdfSummaryCards(List<List<String>> values) => pw.Row(children: [for (var index = 0; index < values.length; index++) pw.Expanded(child: pw.Container(margin: const pw.EdgeInsets.all(3), padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))), child: pw.Column(children: [pw.Text(values[index][0], style: const pw.TextStyle(fontSize: 9)), const pw.SizedBox(height: 3), pw.Text(values[index][1], style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))]))) ]);

  pw.Widget _pdfInfoTable(List<List<String>> rows) => pw.Table(border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: .6), columnWidths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(2)}, children: [for (final row in rows) pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(row[0], style: const pw.TextStyle(fontWeight: pw.FontWeight.bold))), pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(row[1]))])]);

  pw.Widget _pdfTable({required List<String> headers, required List<List<String>> rows}) => pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows.isEmpty
            ? <List<dynamic>>[
                [for (var index = 0; index < headers.length; index++) index == 0 ? 'لا توجد سجلات' : ''],
              ]
            : rows,
        headerStyle: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
        cellStyle: const pw.TextStyle(fontSize: 8),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        cellAlignment: pw.Alignment.centerRight,
        border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: .5),
        rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
        oddRowDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
      );
}
