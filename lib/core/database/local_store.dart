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

  Future<Section> createSection({
    required String classUuid,
    required String name,
    String notes,
  });

  Future<void> updateClass({
    required String classUuid,
    required String name,
    String stage,
    String notes,
  });

  Future<void> updateSection({
    required String sectionUuid,
    required String name,
    String notes,
  });

  Future<void> deleteSection(String sectionUuid);

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

  Future<void> updateStudent({
    required String studentUuid,
    required String firstName,
    required String lastName,
    required String classUuid,
    String studentNumber,
    String fatherName,
    String sectionUuid,
    StudentGender gender,
    StudentStatus status,
    String guardianName,
    String guardianPhone,
  });

  Future<void> updateSettings({
    required String schoolName,
    required String teacherName,
    required String academicYear,
    required String stage,
    double? dismissalThreshold,
    double? warningThreshold,
    PenaltyRules? penalties,
    bool? institutionLineAnimated,
    double? institutionLineSpeed,
  });

  Future<void> setAttendance({
    required String studentUuid,
    required DateTime date,
    required AttendanceStatus status,
    String reason,
    String notes,
  });

  Future<void> updateAttendance({
    required String studentUuid,
    required DateTime date,
    required AttendanceStatus status,
    String reason,
    String notes,
  });

  Future<void> deleteAttendance({required String studentUuid, required DateTime date});

  Future<GradeField> createGradeField({
    required String subject,
    required String title,
    required double maxScore,
    required String term,
  });

  Future<void> updateGradeField({
    required String fieldUuid,
    required String subject,
    required String title,
    required double maxScore,
    required String term,
  });

  Future<void> deleteGradeField(String fieldUuid);

  Future<void> saveGrade({
    required String studentUuid,
    required String fieldUuid,
    required double score,
    String notes,
  });

  Future<void> updateGrade({
    required String studentUuid,
    required String fieldUuid,
    required String subject,
    required String title,
    required double maxScore,
    required String term,
    required double score,
    String notes,
  });

  Future<void> deleteGrade({required String studentUuid, required String fieldUuid});

  Future<void> createGradeEntry({
    required String studentUuid,
    required String subject,
    required String title,
    required double maxScore,
    required String term,
    required double score,
    String notes,
  });

  Future<BehaviorRecord> createBehavior({
    required String studentUuid,
    required BehaviorCategory category,
    required String title,
    required String details,
    required BehaviorViolationType violationType,
    String actionTaken,
    String followUp,
    DateTime date,
  });

  Future<void> updateBehavior({
    required String behaviorUuid,
    required BehaviorCategory category,
    required String title,
    required String details,
    required BehaviorViolationType violationType,
    String actionTaken,
    String followUp,
  });

  Future<void> deleteBehavior(String behaviorUuid);

  Future<StudentNote> createNote({
    required String studentUuid,
    required NoteCategory category,
    required String title,
    required String details,
    bool needsFollowUp,
    DateTime? followUpDate,
  });

  Future<void> updateNote({
    required String noteUuid,
    required NoteCategory category,
    required String title,
    required String details,
    bool needsFollowUp,
    DateTime? followUpDate,
  });

  Future<void> deleteNote(String noteUuid);

  Future<StudentImportRecord> importStudents({
    required String classUuid,
    required String sectionUuid,
    required String sourceFilename,
    required StudentImportFormat sourceFormat,
    required List<String> names,
  });

  Future<void> revertImport(String importUuid);

  Future<void> deleteClassCascade(String classUuid);

  Future<void> deleteStudentCascade(String studentUuid);

  Future<String> exportBackupJson();

  Future<void> restoreBackupJson(String json);
}
