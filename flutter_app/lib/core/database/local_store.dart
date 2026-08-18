import 'app_snapshot.dart';
import 'isar_models.dart';

abstract interface class LocalStore {
  Future<AppSnapshot> loadSnapshot();

  Future<SchoolClass> createClass({
    required String name,
    String stage,
    String academicYear,
    String notes,
  });

  Future<Student> createStudent({
    required String firstName,
    required String lastName,
    required String classUuid,
    String studentNumber,
    String fatherName,
    String sectionUuid,
    StudentGender gender,
    String guardianName,
    String guardianPhone,
  });

  Future<void> updateSettings({
    required String schoolName,
    required String teacherName,
    required String academicYear,
    required String stage,
  });

  Future<void> setAttendance({
    required String studentUuid,
    required DateTime date,
    required AttendanceStatus status,
    String reason,
  });

  Future<void> deleteClassCascade(String classUuid);

  Future<void> deleteStudentCascade(String studentUuid);

  Future<String> exportBackupJson();

  Future<void> restoreBackupJson(String json);
}
