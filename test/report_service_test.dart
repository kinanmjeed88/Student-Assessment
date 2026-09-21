import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:almoktaber/core/database/app_snapshot.dart';
import 'package:almoktaber/core/database/isar_models.dart';
import 'package:almoktaber/core/services/excel_report_builder.dart';
import 'package:almoktaber/core/services/report_service.dart';

/// يقرأ القيم النصية لصف واحد بالترتيب البصري (من اليمين لليسار).
List<String> _rowValues(Sheet sheet, int rowIndex) {
  final rows = sheet.rows;
  if (rowIndex >= rows.length) return const <String>[];
  return rows[rowIndex].map((cell) => cell?.value?.toString().trim() ?? '').toList(growable: false);
}

/// عدد صفوف البيانات في ورقة (بعد العنوان والوصف والترويسة وقبل الإجمالي).
int _dataRowCount(Sheet sheet) {
  final rows = sheet.rows;
  var count = 0;
  for (var index = ExcelReportBuilder.firstDataRowIndex; index < rows.length; index++) {
    final values = _rowValues(sheet, index);
    if (values.every((value) => value.isEmpty)) continue;
    // سطر الإجمالي هو الأخير ويبدأ بتسمية «عدد ...».
    if (index == rows.length - 1 && values.first.startsWith('عدد ')) continue;
    count++;
  }
  return count;
}

AppSnapshot _buildSnapshot({int classCount = 2, int studentsPerSection = 3}) {
  final settings = AppSettings()
    ..schoolName = 'مدرسة الاختبار'
    ..teacherName = 'المعلم';

  final classes = <SchoolClass>[];
  final sections = <Section>[];
  final students = <Student>[];
  final attendance = <AttendanceRecord>[];
  final behaviors = <BehaviorRecord>[];
  final notes = <StudentNote>[];
  final gradeFields = <GradeField>[];
  final grades = <Grade>[];

  final field = GradeField()
    ..uuid = 'field-1'
    ..subject = 'الرياضيات'
    ..title = 'اختبار أول'
    ..term = 'الفصل الأول'
    ..maxScore = 100
    ..date = DateTime(2025, 1, 1);
  gradeFields.add(field);

  const sectionNames = ['أ', 'ب'];
  const classNames = ['الصف الأول', 'الصف الثاني', 'الصف الثالث'];

  for (var c = 0; c < classCount; c++) {
    final classUuid = 'class-$c';
    classes.add(SchoolClass()
      ..uuid = classUuid
      ..name = classNames[c % classNames.length]
      ..stage = ''
      ..academicYear = '2025'
      ..notes = '');

    for (var s = 0; s < sectionNames.length; s++) {
      final sectionUuid = 'section-$c-$s';
      sections.add(Section()
        ..uuid = sectionUuid
        ..classUuid = classUuid
        ..name = sectionNames[s]
        ..notes = '');

      for (var i = 0; i < studentsPerSection; i++) {
        final uuid = 'student-$c-$s-$i';
        students.add(Student()
          ..uuid = uuid
          ..firstName = 'طالب$i'
          ..fatherName = ''
          ..lastName = '${classNames[c % classNames.length]}${sectionNames[s]}'
          ..fullName = 'طالب$i ${classNames[c % classNames.length]}${sectionNames[s]}'
          ..studentNumber = '$c$s$i'
          ..classUuid = classUuid
          ..sectionUuid = sectionUuid
          ..gender = StudentGender.male
          ..status = StudentStatus.active
          ..guardianName = 'ولي$i'
          ..guardianPhone = '0700000000');

        attendance.add(AttendanceRecord()
          ..studentUuid = uuid
          ..date = DateTime(2025, 3, 1)
          ..status = AttendanceStatus.present
          ..reason = ''
          ..notes = '');

        behaviors.add(BehaviorRecord()
          ..uuid = 'beh-$uuid'
          ..studentUuid = uuid
          ..category = BehaviorCategory.positive
          ..violationType = BehaviorViolationType.none
          ..title = 'مشاركة'
          ..details = ''
          ..penaltyPoints = 0
          ..date = DateTime(2025, 3, 2)
          ..actionTaken = ''
          ..followUp = '');

        notes.add(StudentNote()
          ..uuid = 'note-$uuid'
          ..studentUuid = uuid
          ..category = NoteCategory.academic
          ..title = 'ملاحظة'
          ..details = ''
          ..needsFollowUp = false
          ..date = DateTime(2025, 3, 3));

        grades.add(Grade()
          ..studentUuid = uuid
          ..fieldUuid = field.uuid
          ..score = 80
          ..notes = ''
          ..createdAt = DateTime(2025, 3, 4));
      }
    }
  }

  return AppSnapshot(
    settings: settings,
    classes: classes,
    sections: sections,
    students: students,
    gradeFields: gradeFields,
    grades: grades,
    attendance: attendance,
    todayAttendance: const [],
    behaviors: behaviors,
    notes: notes,
    imports: const [],
  );
}

void main() {
  final service = ReportService();

  group('تصدير التقارير يشمل جميع الصفوف', () {
    test('تقرير الطلاب يحتوي كل الطلاب في ورقة «الكل» وورقة لكل صف', () {
      final snapshot = _buildSnapshot();
      final workbook = Excel.decodeBytes(service.exportStudentsXlsx(snapshot));

      expect(workbook.sheets.containsKey('Sheet1'), isFalse, reason: 'يجب حذف الورقة الافتراضية الفارغة.');

      final allSheet = workbook.sheets['الطلاب - $kAllRecordsSheetName'];
      expect(allSheet, isNotNull);
      expect(_dataRowCount(allSheet!), snapshot.students.length);

      for (final schoolClass in snapshot.classes) {
        for (final section in snapshot.sections.where((item) => item.classUuid == schoolClass.uuid)) {
          final name = '${schoolClass.name} - ${section.name}';
          final sheet = workbook.sheets[name];
          expect(sheet, isNotNull, reason: 'يجب وجود ورقة للصف $name');
          expect(_dataRowCount(sheet!), 3);
        }
      }
    });

    test('كل تقارير Excel تصدّر كامل السجلات', () {
      final snapshot = _buildSnapshot();
      final cases = <String, (List<int>, int)>{
        'الحضور': (service.exportAttendanceXlsx(snapshot), snapshot.attendance.length),
        'الدرجات': (service.exportGradesXlsx(snapshot), snapshot.grades.length),
        'السلوك': (service.exportBehaviorXlsx(snapshot), snapshot.behaviors.length),
        'الملاحظات': (service.exportNotesXlsx(snapshot), snapshot.notes.length),
      };

      cases.forEach((base, value) {
        final workbook = Excel.decodeBytes(value.$1);
        final sheet = workbook.sheets['$base - $kAllRecordsSheetName'];
        expect(sheet, isNotNull, reason: 'الورقة المجمعة مفقودة في تقرير $base');
        expect(_dataRowCount(sheet!), value.$2, reason: 'عدد الصفوف غير مطابق في تقرير $base');
        expect(workbook.sheets.length, greaterThan(1), reason: 'تقرير $base يجب أن يحتوي أكثر من ورقة');
      });
    });

    test('ورقة كل صف تحتوي بيانات ذلك الصف فقط', () {
      final snapshot = _buildSnapshot();
      final workbook = Excel.decodeBytes(service.exportStudentsXlsx(snapshot));
      final sheet = workbook.sheets['الصف الأول - أ']!;

      for (var index = ExcelReportBuilder.firstDataRowIndex; index < sheet.rows.length - 1; index++) {
        final values = _rowValues(sheet, index);
        if (values.every((value) => value.isEmpty)) continue;
        expect(values.contains('الصف الأول'), isTrue);
        expect(values.contains('أ'), isTrue);
      }
    });

    test('ملف الطالب يحتوي كل الأوراق الخمس', () {
      final snapshot = _buildSnapshot();
      final workbook = Excel.decodeBytes(service.exportStudentXlsx(snapshot, 'student-0-0-0'));
      for (final name in ['الملف الشخصي', 'الدرجات', 'الحضور', 'السلوك', 'الملاحظات']) {
        expect(workbook.sheets.containsKey(name), isTrue, reason: 'ورقة $name مفقودة');
      }
      expect(workbook.sheets.containsKey('Sheet1'), isFalse);
    });

    test('التقرير لا يفشل عند غياب البيانات', () {
      final empty = AppSnapshot(
        settings: AppSettings(),
        classes: [],
        sections: [],
        students: [],
        gradeFields: [],
        grades: [],
        attendance: [],
        todayAttendance: [],
        behaviors: [],
        notes: [],
        imports: [],
      );
      expect(() => service.exportStudentsXlsx(empty), returnsNormally);
    });
  });

  group('تنزيل أسماء طلاب صف محدد', () {
    test('يصدّر طلاب الشعبة المحددة فقط', () {
      final snapshot = _buildSnapshot();
      final bytes = service.exportClassStudentsXlsx(snapshot, classUuid: 'class-0', sectionUuid: 'section-0-0');
      final workbook = Excel.decodeBytes(bytes);
      final sheet = workbook.sheets['الصف الأول - أ'];
      expect(sheet, isNotNull);
      expect(_dataRowCount(sheet!), 3);
      expect(workbook.sheets.containsKey('Sheet1'), isFalse);
    });

    test('عند عدم تحديد شعبة يصدّر كل شعب الصف', () {
      final snapshot = _buildSnapshot();
      final workbook = Excel.decodeBytes(service.exportClassStudentsXlsx(snapshot, classUuid: 'class-0'));
      final sheet = workbook.sheets['الصف الأول']!;
      expect(_dataRowCount(sheet), 6);
    });

    test('يرفض الصف غير الموجود', () {
      final snapshot = _buildSnapshot();
      expect(() => service.exportClassStudentsXlsx(snapshot, classUuid: 'missing'), throwsFormatException);
      expect(
        () => service.exportClassStudentsXlsx(snapshot, classUuid: 'class-0', sectionUuid: 'missing'),
        throwsFormatException,
      );
    });

    test('اسم الملف آمن ويعكس الصف والشعبة', () {
      final snapshot = _buildSnapshot();
      final name = service.classStudentsFileName(snapshot, classUuid: 'class-0', sectionUuid: 'section-0-0');
      expect(name.endsWith('.xlsx'), isTrue);
      expect(RegExp(r'[\\/:*?"<>|]').hasMatch(name), isFalse);
    });
  });

  group('باني أوراق Excel', () {
    test('يقصّ أسماء الأوراق الطويلة ويمنع التكرار', () {
      final builder = ExcelReportBuilder();
      const longName = 'اسم طويل جداً لصف دراسي يتجاوز الحد المسموح به في إكسل';
      for (var index = 0; index < 3; index++) {
        builder.addSheet(
          name: longName,
          title: 'عنوان',
          subtitle: 'وصف',
          columns: const [ReportColumn('أ', 10), ReportColumn('ب', 10)],
          rows: const <List<CellValue?>>[],
          totalLabel: 'عدد السجلات',
        );
      }
      expect(builder.sheetNames.length, 3);
      expect(builder.sheetNames.toSet().length, 3);
      for (final name in builder.sheetNames) {
        expect(name.length, lessThanOrEqualTo(31));
      }
    });

    test('يكتب كل الصفوف دون فقدان أي صف', () {
      final builder = ExcelReportBuilder()
        ..addSheet(
          name: 'بيانات',
          title: 'عنوان',
          subtitle: 'وصف',
          columns: const [ReportColumn('الاسم', 20), ReportColumn('الرقم', 10)],
          rows: [
            for (var index = 0; index < 250; index++) [TextCellValue('اسم $index'), IntCellValue(index)],
          ],
          totalLabel: 'عدد السجلات',
        );
      final workbook = Excel.decodeBytes(builder.save());
      expect(_dataRowCount(workbook.sheets['بيانات']!), 250);
    });
  });
}
