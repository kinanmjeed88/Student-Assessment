import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../behavior/behavior_summary.dart';
import '../database/app_snapshot.dart';
import '../database/isar_models.dart';
import '../utils/iterable_extensions.dart';
import 'excel_report_builder.dart';

class ReportService {
  /// وصف الصف الدراسي المستخدم كاسم ورقة عمل مستقلة.
  ///
  /// يضم الصف والشعبة معاً كي تُفصل «الأول أ» عن «الأول ب» في أوراق مختلفة.
  String _groupName(AppSnapshot snapshot, String? classUuid, String? sectionUuid) {
    final className = classUuid == null ? '' : _className(snapshot, classUuid);
    final sectionName = sectionUuid == null ? '' : _sectionName(snapshot, sectionUuid);
    if (className.isEmpty && sectionName.isEmpty) return kUnassignedGroupName;
    if (sectionName.isEmpty) return className;
    if (className.isEmpty) return sectionName;
    return '$className - $sectionName';
  }

  String _studentGroup(AppSnapshot snapshot, Student? student) =>
      student == null ? kUnassignedGroupName : _groupName(snapshot, student.classUuid, student.sectionUuid);

  /// كل الصفوف والشعب المعرّفة في التطبيق، لضمان إنشاء ورقة لكل صف ولو كان فارغاً.
  List<String> _allGroups(AppSnapshot snapshot) {
    final groups = <String>[];
    for (final schoolClass in snapshot.classes) {
      final sections = snapshot.sections.where((section) => section.classUuid == schoolClass.uuid).toList(growable: false);
      if (sections.isEmpty) {
        groups.add(_groupName(snapshot, schoolClass.uuid, null));
        continue;
      }
      for (final section in sections) {
        groups.add(_groupName(snapshot, schoolClass.uuid, section.uuid));
      }
      // بعض الطلاب قد لا يُسندون إلى شعبة، فتُضاف ورقة الصف بلا شعبة أيضاً.
      if (snapshot.students.any((student) => student.classUuid == schoolClass.uuid && _sectionName(snapshot, student.sectionUuid).isEmpty)) {
        groups.add(_groupName(snapshot, schoolClass.uuid, null));
      }
    }
    return groups;
  }

  Uint8List exportStudentsXlsx(AppSnapshot snapshot) {
    const columns = [
      ReportColumn('الاسم الكامل', 28),
      ReportColumn('رقم الطالب', 16),
      ReportColumn('الصف', 18),
      ReportColumn('الشعبة', 18),
      ReportColumn('الجنس', 12),
      ReportColumn('الحالة', 16),
      ReportColumn('ولي الأمر', 24),
      ReportColumn('هاتف ولي الأمر', 18),
      ReportColumn('نقاط السلوك', 14),
      ReportColumn('حالة المتابعة', 20),
    ];
    final rows = <ReportRow>[];
    for (final student in snapshot.students) {
      final summary = _behaviorSummary(snapshot, student.uuid);
      rows.add(ReportRow(
        group: _studentGroup(snapshot, student),
        cells: [
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
        ],
      ));
    }

    final builder = ExcelReportBuilder()
      ..addGroupedSection(
        sheetBaseName: 'الطلاب',
        title: 'تقرير الطلاب',
        subtitle: 'قائمة الطلاب مع الصف والشعبة والحالة وملخص السلوك',
        columns: columns,
        rows: rows,
        totalLabel: 'عدد الطلاب',
        groupOrder: _allGroups(snapshot),
      );
    return builder.save();
  }

  /// تصدير أسماء طلاب صف/شعبة محددة في ملف Excel مستقل.
  ///
  /// [sectionUuid] اختياري: عند تركه فارغاً يشمل التقرير كل شعب الصف.
  Uint8List exportClassStudentsXlsx(
    AppSnapshot snapshot, {
    required String classUuid,
    String sectionUuid = '',
  }) {
    final className = _className(snapshot, classUuid);
    if (className.isEmpty) throw const FormatException('الصف المحدد غير موجود.');
    final sectionName = sectionUuid.isEmpty ? '' : _sectionName(snapshot, sectionUuid);
    if (sectionUuid.isNotEmpty && sectionName.isEmpty) {
      throw const FormatException('الشعبة المحددة غير موجودة.');
    }

    // ترتيب الصفوف هو ترتيب العرض في صفحة الطلاب تماماً: المستودع يسلّم
    // الطلاب مرتبين أصلاً، والفرز الإضافي هنا غير مستقر فقد يبدّل مواقع
    // الأسماء المتطابقة ويخالف ما يراه المستخدم على الشاشة.
    final students = snapshot.students
        .where((student) => student.classUuid == classUuid && (sectionUuid.isEmpty || student.sectionUuid == sectionUuid))
        .toList(growable: false);

    const columns = [
      ReportColumn('ت', 8),
      ReportColumn('الاسم الكامل', 30),
      ReportColumn('رقم الطالب', 16),
      ReportColumn('الصف', 18),
      ReportColumn('الشعبة', 18),
      ReportColumn('الجنس', 12),
      ReportColumn('الحالة', 16),
      ReportColumn('ولي الأمر', 24),
      ReportColumn('هاتف ولي الأمر', 18),
    ];

    final label = sectionName.isEmpty ? className : '$className - $sectionName';
    final rows = <List<CellValue?>>[];
    for (var index = 0; index < students.length; index++) {
      final student = students[index];
      rows.add([
        _integer(index + 1),
        _text(student.fullName),
        _text(student.studentNumber),
        _text(_className(snapshot, student.classUuid)),
        _text(_sectionName(snapshot, student.sectionUuid)),
        _text(_genderLabel(student.gender)),
        _text(_studentStatusLabel(student.status)),
        _text(student.guardianName),
        _text(student.guardianPhone),
      ]);
    }

    final builder = ExcelReportBuilder()
      ..addSheet(
        name: label,
        title: 'أسماء طلاب $label',
        subtitle: 'قائمة أسماء الطلاب حسب الترتيب المعروض في التطبيق',
        columns: columns,
        rows: rows,
        totalLabel: 'عدد الطلاب',
      );
    return builder.save();
  }

  /// اسم ملف آمن لتنزيل أسماء طلاب صف/شعبة محددة.
  String classStudentsFileName(AppSnapshot snapshot, {required String classUuid, String sectionUuid = ''}) {
    final className = _className(snapshot, classUuid);
    final sectionName = sectionUuid.isEmpty ? '' : _sectionName(snapshot, sectionUuid);
    final label = sectionName.isEmpty ? className : '$className-$sectionName';
    final safe = label.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').replaceAll(RegExp(r'\s+'), '-').trim();
    return 'students-${safe.isEmpty ? 'class' : safe}.xlsx';
  }

  Uint8List exportAttendanceXlsx(AppSnapshot snapshot) {
    const columns = [
      ReportColumn('الطالب', 28),
      ReportColumn('رقم الطالب', 16),
      ReportColumn('الصف', 18),
      ReportColumn('الشعبة', 18),
      ReportColumn('التاريخ', 15),
      ReportColumn('الحالة', 16),
      ReportColumn('السبب', 28),
      ReportColumn('ملاحظات', 36),
    ];
    final rows = <ReportRow>[];
    for (final record in snapshot.attendance) {
      final student = _student(snapshot, record.studentUuid);
      rows.add(ReportRow(
        group: _studentGroup(snapshot, student),
        cells: [
          _text(student?.fullName ?? record.studentUuid),
          _text(student?.studentNumber ?? ''),
          _text(student == null ? '' : _className(snapshot, student.classUuid)),
          _text(student == null ? '' : _sectionName(snapshot, student.sectionUuid)),
          _text(_date(record.date)),
          _text(_attendanceLabel(record.status)),
          _text(record.reason),
          _text(record.notes),
        ],
      ));
    }

    final builder = ExcelReportBuilder()
      ..addGroupedSection(
        sheetBaseName: 'الحضور',
        title: 'تقرير الحضور والغياب',
        subtitle: 'سجل يومي يتضمن الحضور والغياب والتأخر والأعذار مع الأسباب والملاحظات',
        columns: columns,
        rows: rows,
        totalLabel: 'عدد سجلات الحضور',
        groupOrder: _allGroups(snapshot),
      );
    return builder.save();
  }

  Uint8List exportGradesXlsx(AppSnapshot snapshot) {
    const columns = [
      ReportColumn('الطالب', 26),
      ReportColumn('رقم الطالب', 16),
      ReportColumn('الصف', 16),
      ReportColumn('الشعبة', 16),
      ReportColumn('المادة', 20),
      ReportColumn('التقييم', 24),
      ReportColumn('الفصل', 18),
      ReportColumn('الدرجة', 13),
      ReportColumn('الحد الأقصى', 15),
      ReportColumn('النسبة', 13),
      ReportColumn('التقدير', 16),
      ReportColumn('ملاحظات', 34),
    ];
    final rows = <ReportRow>[];
    for (final grade in snapshot.grades) {
      final field = snapshot.gradeFields.where((item) => item.uuid == grade.fieldUuid).firstOrNull;
      final student = _student(snapshot, grade.studentUuid);
      if (field == null || student == null) continue;
      final percentage = field.maxScore <= 0 ? 0.0 : grade.score / field.maxScore * 100.0;
      rows.add(ReportRow(
        group: _studentGroup(snapshot, student),
        cells: [
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
        ],
      ));
    }

    final builder = ExcelReportBuilder()
      ..addGroupedSection(
        sheetBaseName: 'الدرجات',
        title: 'تقرير الدرجات والتقييمات',
        subtitle: 'تفاصيل التقييمات والدرجات والنسب والملاحظات حسب الطالب والمادة',
        columns: columns,
        rows: rows,
        totalLabel: 'عدد الدرجات',
        groupOrder: _allGroups(snapshot),
      );
    return builder.save();
  }

  Uint8List exportBehaviorXlsx(AppSnapshot snapshot) {
    const columns = [
      ReportColumn('الطالب', 26),
      ReportColumn('رقم الطالب', 16),
      ReportColumn('الصف', 16),
      ReportColumn('الشعبة', 16),
      ReportColumn('التصنيف', 16),
      ReportColumn('نوع المخالفة', 20),
      ReportColumn('العنوان', 26),
      ReportColumn('التفاصيل', 38),
      ReportColumn('النقاط', 13),
      ReportColumn('التاريخ', 15),
      ReportColumn('الإجراء', 30),
      ReportColumn('المتابعة', 30),
    ];
    final rows = <ReportRow>[];
    for (final record in snapshot.behaviors) {
      final student = _student(snapshot, record.studentUuid);
      rows.add(ReportRow(
        group: _studentGroup(snapshot, student),
        cells: [
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
        ],
      ));
    }

    final builder = ExcelReportBuilder()
      ..addGroupedSection(
        sheetBaseName: 'السلوك',
        title: 'تقرير السلوك والمتابعة',
        subtitle: 'السجلات السلوكية والنقاط والإجراءات والمتابعات لكل طالب',
        columns: columns,
        rows: rows,
        totalLabel: 'عدد السجلات السلوكية',
        groupOrder: _allGroups(snapshot),
      );
    return builder.save();
  }

  Uint8List exportNotesXlsx(AppSnapshot snapshot) {
    const columns = [
      ReportColumn('الطالب', 26),
      ReportColumn('رقم الطالب', 16),
      ReportColumn('الصف', 16),
      ReportColumn('الشعبة', 16),
      ReportColumn('التصنيف', 18),
      ReportColumn('العنوان', 26),
      ReportColumn('التفاصيل', 42),
      ReportColumn('تحتاج متابعة', 16),
      ReportColumn('تاريخ المتابعة', 18),
      ReportColumn('التاريخ', 15),
    ];
    final rows = <ReportRow>[];
    for (final note in snapshot.notes) {
      final student = _student(snapshot, note.studentUuid);
      rows.add(ReportRow(
        group: _studentGroup(snapshot, student),
        cells: [
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
        ],
      ));
    }

    final builder = ExcelReportBuilder()
      ..addGroupedSection(
        sheetBaseName: 'الملاحظات',
        title: 'تقرير الملاحظات والمتابعة',
        subtitle: 'الملاحظات الأكاديمية والصحية والتربوية ومواعيد المتابعة',
        columns: columns,
        rows: rows,
        totalLabel: 'عدد الملاحظات',
        groupOrder: _allGroups(snapshot),
      );
    return builder.save();
  }

  Uint8List exportImportHistoryXlsx(AppSnapshot snapshot) {
    const columns = [
      ReportColumn('اسم الملف', 34),
      ReportColumn('الصيغة', 16),
      ReportColumn('الصف', 20),
      ReportColumn('الشعبة', 20),
      ReportColumn('عدد الطلاب', 16),
      ReportColumn('تاريخ الاستيراد', 18),
      ReportColumn('الحالة', 18),
      ReportColumn('تاريخ التراجع', 18),
    ];
    final rows = <ReportRow>[];
    for (final record in snapshot.imports) {
      rows.add(ReportRow(
        group: _groupName(snapshot, record.classUuid, record.sectionUuid),
        cells: [
          _text(record.sourceFilename),
          _text(_importFormatLabel(record.sourceFormat)),
          _text(_className(snapshot, record.classUuid)),
          _text(_sectionName(snapshot, record.sectionUuid)),
          _integer(record.addedCount),
          _text(_date(record.createdAt)),
          _text(record.revertedAt == null ? 'نشط' : 'متراجع عنه'),
          _text(record.revertedAt == null ? '' : _date(record.revertedAt!)),
        ],
      ));
    }

    final builder = ExcelReportBuilder()
      ..addGroupedSection(
        sheetBaseName: 'سجل الاستيراد',
        title: 'تقرير سجل استيراد الطلاب',
        subtitle: 'مصادر الملفات وعمليات الإضافة والتراجع وحالة كل عملية',
        columns: columns,
        rows: rows,
        totalLabel: 'عدد عمليات الاستيراد',
        groupOrder: _allGroups(snapshot),
      );
    return builder.save();
  }

  Uint8List exportStudentXlsx(AppSnapshot snapshot, String studentUuid) {
    final student = _student(snapshot, studentUuid);
    if (student == null) throw const FormatException('الطالب غير موجود.');
    final behavior = _behaviorSummary(snapshot, studentUuid);
    final builder = ExcelReportBuilder();

    builder.addSheet(
      name: 'الملف الشخصي',
      title: 'ملف الطالب',
      subtitle: 'البيانات الأساسية وملخص المتابعة السلوكية',
      columns: const [ReportColumn('الحقل', 26), ReportColumn('القيمة', 46)],
      rows: <List<CellValue?>>[
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
      ],
      totalLabel: 'عدد الحقول',
    );

    final gradeRows = <List<CellValue?>>[];
    for (final grade in snapshot.gradesFor(studentUuid)) {
      final field = snapshot.gradeFields.where((item) => item.uuid == grade.fieldUuid).firstOrNull;
      if (field == null) continue;
      final percentage = field.maxScore <= 0 ? 0.0 : grade.score / field.maxScore * 100.0;
      gradeRows.add([
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
    builder.addSheet(
      name: 'الدرجات',
      title: 'درجات الطالب',
      subtitle: 'التقييمات والدرجات والنسب والملاحظات',
      columns: const [
        ReportColumn('المادة', 22),
        ReportColumn('التقييم', 26),
        ReportColumn('الفصل', 18),
        ReportColumn('الدرجة', 13),
        ReportColumn('الحد الأقصى', 15),
        ReportColumn('النسبة', 13),
        ReportColumn('التقدير', 16),
        ReportColumn('ملاحظات', 36),
      ],
      rows: gradeRows,
      totalLabel: 'عدد التقييمات',
    );

    builder.addSheet(
      name: 'الحضور',
      title: 'حضور الطالب',
      subtitle: 'سجل الحضور والغياب والتأخر والأعذار',
      columns: const [
        ReportColumn('التاريخ', 18),
        ReportColumn('الحالة', 18),
        ReportColumn('السبب', 34),
        ReportColumn('ملاحظات', 42),
      ],
      rows: [
        for (final record in snapshot.attendanceFor(studentUuid))
          [_text(_date(record.date)), _text(_attendanceLabel(record.status)), _text(record.reason), _text(record.notes)],
      ],
      totalLabel: 'عدد سجلات الحضور',
    );

    builder.addSheet(
      name: 'السلوك',
      title: 'سجل سلوك الطالب',
      subtitle: 'المخالفات والإيجابيات والإجراءات والمتابعات',
      columns: const [
        ReportColumn('التصنيف', 18),
        ReportColumn('نوع المخالفة', 20),
        ReportColumn('العنوان', 26),
        ReportColumn('التفاصيل', 38),
        ReportColumn('النقاط', 13),
        ReportColumn('التاريخ', 15),
        ReportColumn('الإجراء', 30),
        ReportColumn('المتابعة', 30),
      ],
      rows: [
        for (final record in snapshot.behaviorsFor(studentUuid))
          [
            _text(_behaviorCategoryLabel(record.category)),
            _text(_violationLabel(record.violationType)),
            _text(record.title),
            _text(record.details),
            _number(record.penaltyPoints),
            _text(_date(record.date)),
            _text(record.actionTaken),
            _text(record.followUp),
          ],
      ],
      totalLabel: 'عدد سجلات السلوك',
    );

    builder.addSheet(
      name: 'الملاحظات',
      title: 'ملاحظات الطالب',
      subtitle: 'الملاحظات الأكاديمية والصحية والتربوية والمتابعة',
      columns: const [
        ReportColumn('التصنيف', 18),
        ReportColumn('العنوان', 26),
        ReportColumn('التفاصيل', 42),
        ReportColumn('تحتاج متابعة', 16),
        ReportColumn('تاريخ المتابعة', 18),
        ReportColumn('التاريخ', 15),
      ],
      rows: [
        for (final note in snapshot.notesFor(studentUuid))
          [
            _text(_noteCategoryLabel(note.category)),
            _text(note.title),
            _text(note.details),
            _text(note.needsFollowUp ? 'نعم' : 'لا'),
            _text(note.followUpDate == null ? '' : _date(note.followUpDate!)),
            _text(_date(note.date)),
          ],
      ],
      totalLabel: 'عدد الملاحظات',
    );

    return builder.save();
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
          pw.Text('قائمة الطلاب', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
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
          pw.Text(student.fullName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
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
          pw.Text('الدرجات والتقييمات', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _pdfTable(headers: const ['المادة', 'التقييم', 'الدرجة', 'الحد الأقصى', 'النسبة', 'التقدير'], rows: snapshot.gradesFor(studentUuid).map((grade) {
            final field = snapshot.gradeFields.where((item) => item.uuid == grade.fieldUuid).firstOrNull;
            if (field == null) return <String>[];
            final percentage = field.maxScore <= 0 ? 0.0 : grade.score / field.maxScore * 100.0;
            return [field.subject, field.title, grade.score.toStringAsFixed(1), field.maxScore.toStringAsFixed(1), '${percentage.toStringAsFixed(1)}%', _gradeLabel(percentage)];
          }).where((row) => row.isNotEmpty).toList()),
          pw.SizedBox(height: 18),
          pw.Text('الحضور', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _pdfTable(headers: const ['التاريخ', 'الحالة', 'السبب', 'ملاحظات'], rows: snapshot.attendanceFor(studentUuid).map((record) => [_date(record.date), _attendanceLabel(record.status), record.reason, record.notes]).toList()),
          pw.SizedBox(height: 18),
          pw.Text('السلوك والمتابعة', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _pdfTable(headers: const ['التصنيف', 'العنوان', 'النقاط', 'التاريخ', 'الإجراء', 'المتابعة'], rows: snapshot.behaviorsFor(studentUuid).map((record) => [_behaviorCategoryLabel(record.category), record.title, record.penaltyPoints.toStringAsFixed(1), _date(record.date), record.actionTaken, record.followUp]).toList()),
          pw.SizedBox(height: 18),
          pw.Text('الملاحظات', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _pdfTable(headers: const ['التصنيف', 'العنوان', 'التفاصيل', 'المتابعة', 'التاريخ'], rows: snapshot.notesFor(studentUuid).map((note) => [_noteCategoryLabel(note.category), note.title, note.details, note.needsFollowUp ? 'نعم' : 'لا', _date(note.date)]).toList()),
        ],
      ),
    );
    return document.save();
  }

  Future<pw.ThemeData> _arabicPdfTheme() async {
    final arabicRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'),
    );
    final arabicBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'),
    );
    final latinRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final latinBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    final symbols = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansSymbols2-Regular.ttf'),
    );

    return pw.ThemeData.withFont(
      base: arabicRegular,
      bold: arabicBold,
      fontFallback: [latinRegular, latinBold, symbols],
    );
  }

  CellValue _text(String value) => TextCellValue(value.trim());
  CellValue _number(double value) => DoubleCellValue(value);
  CellValue _integer(int value) => IntCellValue(value);

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

  pw.Widget _pdfHeader(AppSettings settings, String title) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Text(settings.schoolName.isEmpty ? 'سجل الطالب' : settings.schoolName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        if (settings.teacherName.isNotEmpty) pw.Text(settings.teacherName, style: pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 4),
        pw.Divider(color: PdfColors.blueGrey300),
        pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
      ]);

  pw.Widget _pdfFooter(pw.Context context) => pw.Align(alignment: pw.Alignment.center, child: pw.Text('صفحة ${context.pageNumber} من ${context.pagesCount}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)));

  pw.Widget _pdfSummaryCards(List<List<String>> values) => pw.Row(children: [for (var index = 0; index < values.length; index++) pw.Expanded(child: pw.Container(margin: const pw.EdgeInsets.all(3), padding: const pw.EdgeInsets.all(8), decoration: const pw.BoxDecoration(color: PdfColors.blue50), child: pw.Column(children: [pw.Text(values[index][0], style: pw.TextStyle(fontSize: 9)), pw.SizedBox(height: 3), pw.Text(values[index][1], style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))]))) ]);

  pw.Widget _pdfInfoTable(List<List<String>> rows) => pw.Table(
        border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: .6),
        columnWidths: const {
          0: pw.FlexColumnWidth(2),
          1: pw.FlexColumnWidth(1),
        },
        children: [
          for (final row in rows)
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    row[1],
                    textDirection: pw.TextDirection.rtl,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    row[0],
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textDirection: pw.TextDirection.rtl,
                  ),
                ),
              ],
            ),
        ],
      );

  pw.Widget _pdfTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final rtlHeaders = headers.reversed.toList(growable: false);
    final rtlRows = rows.isEmpty
        ? <List<dynamic>>[
            [
              for (var index = 0; index < headers.length; index++)
                index == headers.length - 1 ? 'لا توجد سجلات' : '',
            ],
          ]
        : [
            for (final row in rows) row.reversed.toList(growable: false),
          ];

    return pw.TableHelper.fromTextArray(
      headers: rtlHeaders,
      data: rtlRows,
      tableDirection: pw.TextDirection.rtl,
      headerDirection: pw.TextDirection.rtl,
      headerStyle: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: pw.TextStyle(fontSize: 8),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      cellAlignment: pw.Alignment.centerRight,
      headerAlignment: pw.Alignment.center,
      border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: .5),
      rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
    );
  }
}
