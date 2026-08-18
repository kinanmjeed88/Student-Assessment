import 'isar_models.dart';

class AppSnapshot {
  const AppSnapshot({
    required this.settings,
    required this.classes,
    required this.sections,
    required this.students,
    required this.gradeFields,
    required this.todayAttendance,
  });

  final AppSettings settings;
  final List<SchoolClass> classes;
  final List<Section> sections;
  final List<Student> students;
  final List<GradeField> gradeFields;
  final List<AttendanceRecord> todayAttendance;
}
