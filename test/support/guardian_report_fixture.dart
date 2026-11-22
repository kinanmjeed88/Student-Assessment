import 'package:almoktaber/core/database/app_snapshot.dart';
import 'package:almoktaber/core/database/isar_models.dart';

/// بيانات اختبار صغيرة تغطي سجلات داخل الشهر وخارجه لتقرير ولي الأمر.
class GuardianReportFixture {
  GuardianReportFixture()
      : now = DateTime(2026, 11, 21, 12),
        previousMonth = DateTime(2026, 10, 31, 10),
        monthStart = DateTime(2026, 11, 1, 8),
        midMonth = DateTime(2026, 11, 10, 9),
        afterNow = DateTime(2026, 11, 22, 9);

  final DateTime now;
  final DateTime previousMonth;
  final DateTime monthStart;
  final DateTime midMonth;
  final DateTime afterNow;

  static const String studentUuid = 'student-1';

  late final AppSettings settings = AppSettings()
    ..schoolName = 'مدرسة الاختبار'
    ..teacherName = 'المعلم';

  late final SchoolClass schoolClass = SchoolClass()
    ..uuid = 'class-1'
    ..name = 'الصف الأول';

  late final Section section = Section()
    ..uuid = 'section-1'
    ..classUuid = schoolClass.uuid
    ..name = 'أ';

  late final Student student = Student()
    ..uuid = studentUuid
    ..firstName = 'أحمد'
    ..lastName = 'الصائغ'
    ..fullName = 'أحمد الصائغ'
    ..studentNumber = '101'
    ..classUuid = schoolClass.uuid
    ..sectionUuid = section.uuid
    ..gender = StudentGender.male
    ..status = StudentStatus.active
    ..guardianName = 'ولي الأمر'
    ..guardianPhone = '0700123456';

  late final GradeField oldField = GradeField()
    ..uuid = 'field-old'
    ..subject = 'الرياضيات'
    ..title = 'اختبار الشهر الماضي'
    ..maxScore = 100
    ..date = previousMonth;

  late final GradeField currentField = GradeField()
    ..uuid = 'field-current'
    ..subject = 'العلوم'
    ..title = 'اختبار الشهر'
    ..maxScore = 100
    ..date = previousMonth;

  late final List<AttendanceRecord> attendance = [
    _attendance(previousMonth, AttendanceStatus.absent),
    _attendance(monthStart, AttendanceStatus.present),
    _attendance(midMonth, AttendanceStatus.absent),
    _attendance(afterNow, AttendanceStatus.absent),
  ];

  late final List<BehaviorRecord> behaviors = [
    _behavior('behavior-old', previousMonth, 20),
    _behavior('behavior-start', monthStart, 0),
    _behavior('behavior-current', midMonth, 5),
    _behavior('behavior-future', afterNow, 30),
  ];

  late final List<StudentNote> notes = [
    _note('note-old', previousMonth),
    _note('note-current', midMonth),
    _note('note-future', afterNow),
  ];

  late final List<Grade> grades = [
    _grade(oldField.uuid, previousMonth),
    _grade(currentField.uuid, midMonth),
    _grade(currentField.uuid, afterNow),
  ];

  late final AppSnapshot snapshot = AppSnapshot(
    settings: settings,
    classes: [schoolClass],
    sections: [section],
    students: [student],
    gradeFields: [oldField, currentField],
    grades: grades,
    attendance: attendance,
    todayAttendance: attendance,
    behaviors: behaviors,
    notes: notes,
    imports: const [],
  );

  AttendanceRecord _attendance(DateTime date, AttendanceStatus status) => AttendanceRecord()
    ..studentUuid = studentUuid
    ..date = date
    ..status = status
    ..reason = ''
    ..notes = '';

  BehaviorRecord _behavior(String uuid, DateTime date, double points) => BehaviorRecord()
    ..uuid = uuid
    ..studentUuid = studentUuid
    ..category = points == 0 ? BehaviorCategory.positive : BehaviorCategory.negative
    ..violationType = points == 0 ? BehaviorViolationType.none : BehaviorViolationType.absence
    ..title = 'سجل'
    ..details = ''
    ..penaltyPoints = points
    ..date = date
    ..actionTaken = ''
    ..followUp = '';

  StudentNote _note(String uuid, DateTime date) => StudentNote()
    ..uuid = uuid
    ..studentUuid = studentUuid
    ..category = NoteCategory.academic
    ..title = 'ملاحظة'
    ..details = ''
    ..date = date;

  Grade _grade(String fieldUuid, DateTime createdAt) => Grade()
    ..studentUuid = studentUuid
    ..fieldUuid = fieldUuid
    ..score = 80
    ..notes = ''
    ..createdAt = createdAt;
}
