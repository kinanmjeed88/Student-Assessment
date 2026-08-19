import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/app_snapshot.dart';
import 'database/database_service.dart';
import 'database/isar_models.dart';
import 'database/local_repository.dart';
import 'database/local_store.dart';
import 'notifications/notification_service.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final service = DatabaseService();
  ref.onDispose(service.close);
  return service;
});

final localRepositoryProvider = Provider<LocalStore>((ref) {
  return LocalRepository(ref.watch(databaseServiceProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(FlutterLocalNotificationsPlugin());
});

final appControllerProvider = AsyncNotifierProvider<AppController, AppSnapshot>(AppController.new);

class AppController extends AsyncNotifier<AppSnapshot> {
  LocalStore get _repository => ref.read(localRepositoryProvider);

  @override
  Future<AppSnapshot> build() => _repository.loadSnapshot();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.loadSnapshot);
  }

  Future<void> _mutate(Future<void> Function() operation) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await operation();
      return _repository.loadSnapshot();
    });
  }

  Future<void> addClass({required String name, String stage = '', String academicYear = '', String notes = ''}) =>
      _mutate(() => _repository.createClass(name: name, stage: stage, academicYear: academicYear, notes: notes));

  Future<void> addSection({required String classUuid, required String name, String notes = ''}) =>
      _mutate(() => _repository.createSection(classUuid: classUuid, name: name, notes: notes));

  Future<void> updateClass({required String classUuid, required String name, String stage = '', String notes = ''}) =>
      _mutate(() => _repository.updateClass(classUuid: classUuid, name: name, stage: stage, notes: notes));

  Future<void> updateSection({required String sectionUuid, required String name, String notes = ''}) =>
      _mutate(() => _repository.updateSection(sectionUuid: sectionUuid, name: name, notes: notes));

  Future<void> deleteSection(String sectionUuid) => _mutate(() => _repository.deleteSection(sectionUuid));

  Future<void> addStudent({
    required String firstName,
    required String lastName,
    required String classUuid,
    String studentNumber = '',
    String fatherName = '',
    String sectionUuid = '',
    StudentGender gender = StudentGender.male,
    String guardianName = '',
    String guardianPhone = '',
  }) => _mutate(() => _repository.createStudent(
        firstName: firstName,
        lastName: lastName,
        classUuid: classUuid,
        studentNumber: studentNumber,
        fatherName: fatherName,
        sectionUuid: sectionUuid,
        gender: gender,
        guardianName: guardianName,
        guardianPhone: guardianPhone,
      ));

  Future<void> updateStudent({
    required String studentUuid,
    required String firstName,
    required String lastName,
    required String classUuid,
    String studentNumber = '',
    String fatherName = '',
    String sectionUuid = '',
    StudentGender gender = StudentGender.male,
    StudentStatus status = StudentStatus.active,
    String guardianName = '',
    String guardianPhone = '',
  }) => _mutate(() => _repository.updateStudent(
        studentUuid: studentUuid,
        firstName: firstName,
        lastName: lastName,
        classUuid: classUuid,
        studentNumber: studentNumber,
        fatherName: fatherName,
        sectionUuid: sectionUuid,
        gender: gender,
        status: status,
        guardianName: guardianName,
        guardianPhone: guardianPhone,
      ));

  Future<void> saveSettings({
    required String schoolName,
    required String teacherName,
    required String academicYear,
    required String stage,
    double? dismissalThreshold,
    double? warningThreshold,
    PenaltyRules? penalties,
    bool? institutionLineAnimated,
    double? institutionLineSpeed,
  }) => _mutate(() => _repository.updateSettings(
        schoolName: schoolName,
        teacherName: teacherName,
        academicYear: academicYear,
        stage: stage,
        dismissalThreshold: dismissalThreshold,
        warningThreshold: warningThreshold,
        penalties: penalties,
        institutionLineAnimated: institutionLineAnimated,
        institutionLineSpeed: institutionLineSpeed,
      ));

  Future<void> setAttendance({
    required String studentUuid,
    required DateTime date,
    required AttendanceStatus status,
    String reason = '',
    String notes = '',
  }) => _mutate(() => _repository.setAttendance(studentUuid: studentUuid, date: date, status: status, reason: reason, notes: notes));

  Future<void> updateAttendance({
    required String studentUuid,
    required DateTime date,
    required AttendanceStatus status,
    String reason = '',
    String notes = '',
  }) => _mutate(() => _repository.updateAttendance(studentUuid: studentUuid, date: date, status: status, reason: reason, notes: notes));

  Future<void> deleteAttendance({required String studentUuid, required DateTime date}) =>
      _mutate(() => _repository.deleteAttendance(studentUuid: studentUuid, date: date));

  Future<void> createGradeField({required String subject, required String title, required double maxScore, required String term}) =>
      _mutate(() => _repository.createGradeField(subject: subject, title: title, maxScore: maxScore, term: term));

  Future<void> saveGrade({required String studentUuid, required String fieldUuid, required double score, String notes = ''}) =>
      _mutate(() => _repository.saveGrade(studentUuid: studentUuid, fieldUuid: fieldUuid, score: score, notes: notes));

  Future<void> updateGrade({
    required String studentUuid,
    required String fieldUuid,
    required String subject,
    required String title,
    required double maxScore,
    required String term,
    required double score,
    String notes = '',
  }) => _mutate(() => _repository.updateGrade(studentUuid: studentUuid, fieldUuid: fieldUuid, subject: subject, title: title, maxScore: maxScore, term: term, score: score, notes: notes));

  Future<void> deleteGrade({required String studentUuid, required String fieldUuid}) =>
      _mutate(() => _repository.deleteGrade(studentUuid: studentUuid, fieldUuid: fieldUuid));

  Future<void> createGradeEntry({
    required String studentUuid,
    required String subject,
    required String title,
    required double maxScore,
    required String term,
    required double score,
    String notes = '',
  }) => _mutate(() => _repository.createGradeEntry(
        studentUuid: studentUuid,
        subject: subject,
        title: title,
        maxScore: maxScore,
        term: term,
        score: score,
        notes: notes,
      ));

  Future<void> addBehavior({
    required String studentUuid,
    required BehaviorCategory category,
    required String title,
    required String details,
    required BehaviorViolationType violationType,
    String actionTaken = '',
    String followUp = '',
    DateTime? date,
  }) => _mutate(() => _repository.createBehavior(
        studentUuid: studentUuid,
        category: category,
        title: title,
        details: details,
        violationType: violationType,
        actionTaken: actionTaken,
        followUp: followUp,
        date: date ?? DateTime.now(),
      ));

  Future<void> updateBehavior({
    required String behaviorUuid,
    required BehaviorCategory category,
    required String title,
    required String details,
    required BehaviorViolationType violationType,
    String actionTaken = '',
    String followUp = '',
  }) => _mutate(() => _repository.updateBehavior(behaviorUuid: behaviorUuid, category: category, title: title, details: details, violationType: violationType, actionTaken: actionTaken, followUp: followUp));

  Future<void> deleteBehavior(String behaviorUuid) => _mutate(() => _repository.deleteBehavior(behaviorUuid));

  Future<void> addNote({
    required String studentUuid,
    required NoteCategory category,
    required String title,
    required String details,
    bool needsFollowUp = false,
    DateTime? followUpDate,
  }) => _mutate(() => _repository.createNote(
        studentUuid: studentUuid,
        category: category,
        title: title,
        details: details,
        needsFollowUp: needsFollowUp,
        followUpDate: followUpDate,
      ));

  Future<void> updateNote({
    required String noteUuid,
    required NoteCategory category,
    required String title,
    required String details,
    bool needsFollowUp = false,
    DateTime? followUpDate,
  }) => _mutate(() => _repository.updateNote(noteUuid: noteUuid, category: category, title: title, details: details, needsFollowUp: needsFollowUp, followUpDate: followUpDate));

  Future<void> deleteNote(String noteUuid) => _mutate(() => _repository.deleteNote(noteUuid));

  Future<void> importStudents({
    required String classUuid,
    required String sectionUuid,
    required String sourceFilename,
    required StudentImportFormat sourceFormat,
    required List<String> names,
  }) => _mutate(() => _repository.importStudents(
        classUuid: classUuid,
        sectionUuid: sectionUuid,
        sourceFilename: sourceFilename,
        sourceFormat: sourceFormat,
        names: names,
      ));

  Future<void> revertImport(String importUuid) => _mutate(() => _repository.revertImport(importUuid));

  Future<void> restoreBackup(String json) => _mutate(() => _repository.restoreBackupJson(json));

  Future<void> deleteClass(String classUuid) => _mutate(() => _repository.deleteClassCascade(classUuid));

  Future<void> deleteStudent(String studentUuid) => _mutate(() => _repository.deleteStudentCascade(studentUuid));
}
