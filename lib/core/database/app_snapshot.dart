import 'isar_models.dart';

class AppSnapshot {
  const AppSnapshot({
    required this.settings,
    required this.classes,
    required this.sections,
    required this.students,
    required this.gradeFields,
    required this.grades,
    required this.attendance,
    required this.todayAttendance,
    required this.behaviors,
    required this.notes,
    required this.imports,
  });

  final AppSettings settings;
  final List<SchoolClass> classes;
  final List<Section> sections;
  final List<Student> students;
  final List<GradeField> gradeFields;
  final List<Grade> grades;
  final List<AttendanceRecord> attendance;
  final List<AttendanceRecord> todayAttendance;
  final List<BehaviorRecord> behaviors;
  final List<StudentNote> notes;
  final List<StudentImportRecord> imports;

  List<AttendanceRecord> attendanceFor(String studentUuid) =>
      attendance.where((item) => item.studentUuid == studentUuid).toList(growable: false);

  List<Grade> gradesFor(String studentUuid) =>
      grades.where((item) => item.studentUuid == studentUuid).toList(growable: false);

  List<BehaviorRecord> behaviorsFor(String studentUuid) =>
      behaviors.where((item) => item.studentUuid == studentUuid).toList(growable: false);

  List<StudentNote> notesFor(String studentUuid) =>
      notes.where((item) => item.studentUuid == studentUuid).toList(growable: false);
}
