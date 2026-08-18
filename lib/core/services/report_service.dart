import 'dart:convert';
import 'package:excel_plus/excel_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

import '../behavior/behavior_summary.dart';
import '../database/app_snapshot.dart';
import '../utils/iterable_extensions.dart';

class ReportService {
  Uint8List exportStudentsXlsx(AppSnapshot snapshot) {
    final workbook = Excel.createExcel();
    final sheet = workbook['الطلاب'];
    sheet.appendRow([TextCellValue('الاسم'), TextCellValue('الرقم'), TextCellValue('الصف'), TextCellValue('الشعبة'), TextCellValue('الحالة'), TextCellValue('نقاط السلوك')]);
    for (final student in snapshot.students) {
      final behavior = calculateBehaviorSummary(records: snapshot.behaviorsFor(student.uuid), settings: snapshot.settings);
      sheet.appendRow([
        TextCellValue(student.fullName),
        TextCellValue(student.studentNumber),
        TextCellValue(_className(snapshot, student.classUuid)),
        TextCellValue(_sectionName(snapshot, student.sectionUuid)),
        TextCellValue(student.status.name),
        DoubleCellValue(behavior.totalPoints),
      ]);
    }
    return _save(workbook);
  }

  Uint8List exportAttendanceXlsx(AppSnapshot snapshot) {
    final workbook = Excel.createExcel();
    final sheet = workbook['الحضور'];
    sheet.appendRow([TextCellValue('الطالب'), TextCellValue('التاريخ'), TextCellValue('الحالة'), TextCellValue('السبب'), TextCellValue('ملاحظات')]);
    for (final record in snapshot.attendance) {
      sheet.appendRow([
        TextCellValue(_studentName(snapshot, record.studentUuid)),
        TextCellValue(_date(record.date)),
        TextCellValue(record.status.name),
        TextCellValue(record.reason),
        TextCellValue(record.notes),
      ]);
    }
    return _save(workbook);
  }

  Uint8List exportGradesXlsx(AppSnapshot snapshot) {
    final workbook = Excel.createExcel();
    final sheet = workbook['الدرجات'];
    sheet.appendRow([TextCellValue('الطالب'), TextCellValue('المادة'), TextCellValue('التقييم'), TextCellValue('الفصل'), TextCellValue('الدرجة'), TextCellValue('الحد الأقصى'), TextCellValue('ملاحظات')]);
    for (final grade in snapshot.grades) {
      final field = snapshot.gradeFields.where((item) => item.uuid == grade.fieldUuid).firstOrNull;
      if (field == null) continue;
      sheet.appendRow([
        TextCellValue(_studentName(snapshot, grade.studentUuid)),
        TextCellValue(field.subject),
        TextCellValue(field.title),
        TextCellValue(field.term),
        DoubleCellValue(grade.score),
        DoubleCellValue(field.maxScore),
        TextCellValue(grade.notes),
      ]);
    }
    return _save(workbook);
  }

  Uint8List exportBehaviorXlsx(AppSnapshot snapshot) {
    final workbook = Excel.createExcel();
    final sheet = workbook['السلوك'];
    sheet.appendRow([TextCellValue('الطالب'), TextCellValue('التصنيف'), TextCellValue('العنوان'), TextCellValue('التفاصيل'), TextCellValue('النقاط'), TextCellValue('التاريخ'), TextCellValue('الإجراء'), TextCellValue('المتابعة')]);
    for (final record in snapshot.behaviors) {
      sheet.appendRow([
        TextCellValue(_studentName(snapshot, record.studentUuid)),
        TextCellValue(record.category.name),
        TextCellValue(record.title),
        TextCellValue(record.details),
        DoubleCellValue(record.penaltyPoints),
        TextCellValue(_date(record.date)),
        TextCellValue(record.actionTaken),
        TextCellValue(record.followUp),
      ]);
    }
    return _save(workbook);
  }

  Uint8List exportNotesXlsx(AppSnapshot snapshot) {
    final workbook = Excel.createExcel();
    final sheet = workbook['الملاحظات'];
    sheet.appendRow([TextCellValue('الطالب'), TextCellValue('التصنيف'), TextCellValue('العنوان'), TextCellValue('التفاصيل'), TextCellValue('متابعة'), TextCellValue('تاريخ المتابعة'), TextCellValue('التاريخ')]);
    for (final note in snapshot.notes) {
      sheet.appendRow([
        TextCellValue(_studentName(snapshot, note.studentUuid)),
        TextCellValue(note.category.name),
        TextCellValue(note.title),
        TextCellValue(note.details),
        TextCellValue(note.needsFollowUp ? 'نعم' : 'لا'),
        TextCellValue(note.followUpDate == null ? '' : _date(note.followUpDate!)),
        TextCellValue(_date(note.date)),
      ]);
    }
    return _save(workbook);
  }

  Uint8List exportImportHistoryXlsx(AppSnapshot snapshot) {
    final workbook = Excel.createExcel();
    final sheet = workbook['سجل الاستيراد'];
    sheet.appendRow([TextCellValue('الملف'), TextCellValue('الصيغة'), TextCellValue('الصف'), TextCellValue('الشعبة'), TextCellValue('عدد الطلاب'), TextCellValue('التاريخ'), TextCellValue('الحالة')]);
    for (final record in snapshot.imports) {
      sheet.appendRow([
        TextCellValue(record.sourceFilename),
        TextCellValue(record.sourceFormat.name),
        TextCellValue(_className(snapshot, record.classUuid)),
        TextCellValue(_sectionName(snapshot, record.sectionUuid)),
        IntCellValue(record.addedCount),
        TextCellValue(_date(record.createdAt)),
        TextCellValue(record.revertedAt == null ? 'نشط' : 'متراجع عنه'),
      ]);
    }
    return _save(workbook);
  }

  Uint8List exportStudentXlsx(AppSnapshot snapshot, String studentUuid) {
    final student = snapshot.students.where((item) => item.uuid == studentUuid).firstOrNull;
    if (student == null) throw const FormatException('الطالب غير موجود.');
    final workbook = Excel.createExcel();
    final profile = workbook['الملف الشخصي'];
    profile.appendRow([TextCellValue('الحقل'), TextCellValue('القيمة')]);
    profile.appendRow([TextCellValue('الاسم'), TextCellValue(student.fullName)]);
    profile.appendRow([TextCellValue('رقم الطالب'), TextCellValue(student.studentNumber)]);
    profile.appendRow([TextCellValue('الصف'), TextCellValue(_className(snapshot, student.classUuid))]);
    profile.appendRow([TextCellValue('الشعبة'), TextCellValue(_sectionName(snapshot, student.sectionUuid))]);
    profile.appendRow([TextCellValue('ولي الأمر'), TextCellValue(student.guardianName)]);
    profile.appendRow([TextCellValue('هاتف ولي الأمر'), TextCellValue(student.guardianPhone)]);

    final gradesSheet = workbook['الدرجات'];
    gradesSheet.appendRow([TextCellValue('المادة'), TextCellValue('التقييم'), TextCellValue('الدرجة'), TextCellValue('الحد الأقصى'), TextCellValue('ملاحظات')]);
    for (final grade in snapshot.gradesFor(studentUuid)) {
      final field = snapshot.gradeFields.where((item) => item.uuid == grade.fieldUuid).firstOrNull;
      if (field == null) continue;
      gradesSheet.appendRow([TextCellValue(field.subject), TextCellValue(field.title), DoubleCellValue(grade.score), DoubleCellValue(field.maxScore), TextCellValue(grade.notes)]);
    }

    final behaviorSheet = workbook['السلوك'];
    behaviorSheet.appendRow([TextCellValue('التصنيف'), TextCellValue('العنوان'), TextCellValue('التفاصيل'), TextCellValue('النقاط'), TextCellValue('التاريخ'), TextCellValue('الإجراء')]);
    for (final record in snapshot.behaviorsFor(studentUuid)) {
      behaviorSheet.appendRow([TextCellValue(record.category.name), TextCellValue(record.title), TextCellValue(record.details), DoubleCellValue(record.penaltyPoints), TextCellValue(_date(record.date)), TextCellValue(record.actionTaken)]);
    }

    final notesSheet = workbook['الملاحظات'];
    notesSheet.appendRow([TextCellValue('التصنيف'), TextCellValue('العنوان'), TextCellValue('التفاصيل'), TextCellValue('التاريخ')]);
    for (final note in snapshot.notesFor(studentUuid)) {
      notesSheet.appendRow([TextCellValue(note.category.name), TextCellValue(note.title), TextCellValue(note.details), TextCellValue(_date(note.date))]);
    }
    return _save(workbook);
  }

  Uint8List exportBackupJson(String json) => Uint8List.fromList(utf8.encode(json));

  Future<Uint8List> exportStudentsPdf(AppSnapshot snapshot) async {
    final theme = await _arabicPdfTheme();
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Header(level: 0, text: snapshot.settings.schoolName.isEmpty ? 'تقرير الطلاب' : snapshot.settings.schoolName),
          pw.Text('إجمالي الطلاب: ${snapshot.students.length}'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const ['الطالب', 'الصف', 'الحالة', 'نقاط السلوك'],
            data: snapshot.students.map((student) {
              final behavior = calculateBehaviorSummary(records: snapshot.behaviorsFor(student.uuid), settings: snapshot.settings);
              return [student.fullName, _className(snapshot, student.classUuid), student.status.name, behavior.totalPoints.toStringAsFixed(1)];
            }).toList(),
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<Uint8List> exportStudentPdf(AppSnapshot snapshot, String studentUuid) async {
    final student = snapshot.students.where((item) => item.uuid == studentUuid).firstOrNull;
    if (student == null) throw const FormatException('الطالب غير موجود.');
    final behavior = calculateBehaviorSummary(records: snapshot.behaviorsFor(studentUuid), settings: snapshot.settings);
    final theme = await _arabicPdfTheme();
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Header(level: 0, text: 'ملف الطالب'),
          pw.Text('الاسم: ${student.fullName}'),
          pw.Text('رقم الطالب: ${student.studentNumber}'),
          pw.Text('الصف: ${_className(snapshot, student.classUuid)}'),
          pw.Text('سجلات الحضور: ${snapshot.attendanceFor(studentUuid).length}'),
          pw.Text('الدرجات: ${snapshot.gradesFor(studentUuid).length}'),
          pw.Text('نقاط السلوك: ${behavior.totalPoints.toStringAsFixed(1)}'),
          pw.Text('الملاحظات: ${snapshot.notesFor(studentUuid).length}'),
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

  Uint8List _save(Excel workbook) => Uint8List.fromList(workbook.save() ?? const <int>[]);

  String _studentName(AppSnapshot snapshot, String uuid) => snapshot.students.where((item) => item.uuid == uuid).firstOrNull?.fullName ?? uuid;
  String _className(AppSnapshot snapshot, String uuid) => snapshot.classes.where((item) => item.uuid == uuid).firstOrNull?.name ?? '';
  String _sectionName(AppSnapshot snapshot, String uuid) => snapshot.sections.where((item) => item.uuid == uuid).firstOrNull?.name ?? '';
  String _date(DateTime value) => value.toIso8601String().substring(0, 10);
}
