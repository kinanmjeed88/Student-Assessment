import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import 'app_snapshot.dart';
import 'database_service.dart';
import 'isar_models.dart';
import 'local_store.dart';

class LocalRepository implements LocalStore {
  LocalRepository(this._databaseService);

  final DatabaseService _databaseService;
  static const _uuid = Uuid();

  Future<Isar> get _db => _databaseService.open();

  Future<AppSnapshot> loadSnapshot() async {
    final db = await _db;
    final settings = await db.appSettings.get(1) ?? AppSettings();
    if (settings.id != 1) {
      settings.id = 1;
      await db.writeTxn(() => db.appSettings.put(settings));
    }

    final classes = await db.schoolClasss.where().findAll();
    final sections = await db.sections.where().findAll();
    final students = await db.students.where().findAll();
    final gradeFields = await db.gradeFields.where().findAll();

    classes.sort((a, b) => a.name.compareTo(b.name));
    sections.sort((a, b) => a.name.compareTo(b.name));
    students.sort((a, b) => a.fullName.compareTo(b.fullName));
    gradeFields.sort((a, b) => b.date.compareTo(a.date));

    return AppSnapshot(
      settings: settings,
      classes: classes,
      sections: sections,
      students: students,
      gradeFields: gradeFields,
    );
  }

  Future<SchoolClass> createClass({
    required String name,
    String stage = '',
    String academicYear = '',
    String notes = '',
  }) async {
    final db = await _db;
    final schoolClass = SchoolClass()
      ..uuid = _uuid.v4()
      ..name = name.trim()
      ..stage = stage.trim()
      ..academicYear = academicYear.trim()
      ..notes = notes.trim();
    await db.writeTxn(() => db.schoolClasss.put(schoolClass));
    return schoolClass;
  }

  Future<Section> createSection({
    required String classUuid,
    required String name,
    String notes = '',
  }) async {
    final db = await _db;
    final section = Section()
      ..uuid = _uuid.v4()
      ..classUuid = classUuid
      ..name = name.trim()
      ..notes = notes.trim();
    await db.writeTxn(() => db.sections.put(section));
    return section;
  }

  Future<Student> createStudent({
    required String firstName,
    required String lastName,
    required String classUuid,
    String studentNumber = '',
    String fatherName = '',
    String sectionUuid = '',
    StudentGender gender = StudentGender.male,
    String guardianName = '',
    String guardianPhone = '',
  }) async {
    final db = await _db;
    final student = Student()
      ..uuid = _uuid.v4()
      ..firstName = firstName.trim()
      ..fatherName = fatherName.trim()
      ..lastName = lastName.trim()
      ..fullName = [firstName, fatherName, lastName]
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .join(' ')
      ..studentNumber = studentNumber.trim()
      ..classUuid = classUuid
      ..sectionUuid = sectionUuid
      ..gender = gender
      ..guardianName = guardianName.trim()
      ..guardianPhone = guardianPhone.trim();
    await db.writeTxn(() => db.students.put(student));
    return student;
  }

  Future<void> setAttendance({
    required String studentUuid,
    required DateTime date,
    required AttendanceStatus status,
    String reason = '',
  }) async {
    final db = await _db;
    final normalized = DateTime(date.year, date.month, date.day);
    await db.writeTxn(() async {
      final existing = await db.attendanceRecords
          .filter()
          .studentUuidEqualTo(studentUuid)
          .and()
          .dateEqualTo(normalized)
          .findFirst();
      final record = existing ?? (AttendanceRecord()
        ..studentUuid = studentUuid
        ..date = normalized);
      record
        ..status = status
        ..reason = reason.trim()
        ..updatedAt = DateTime.now();
      await db.attendanceRecords.put(record);
    });
  }

  @override
  Future<void> restoreBackupJson(String json) async {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('تنسيق النسخة الاحتياطية غير صالح.');
    }
    final schemaVersion = (decoded['schemaVersion'] as num?)?.toInt() ?? 1;
    if (schemaVersion > 1) {
      throw FormatException('إصدار النسخة $schemaVersion غير مدعوم.');
    }

    final db = await _db;
    await db.writeTxn(() async {
      await db.clear();
      await db.appSettings.put(_settingsFromJson(decoded['settings']));
      for (final item in _maps(decoded['classes'])) {
        await db.schoolClasss.put(_classFromJson(item));
      }
      for (final item in _maps(decoded['sections'])) {
        await db.sections.put(_sectionFromJson(item));
      }
      for (final item in _maps(decoded['students'])) {
        await db.students.put(_studentFromJson(item));
      }
      for (final item in _maps(decoded['attendance'])) {
        await db.attendanceRecords.put(_attendanceFromJson(item));
      }
      for (final item in _maps(decoded['gradeFields'])) {
        await db.gradeFields.put(_gradeFieldFromJson(item));
      }
      for (final item in _maps(decoded['grades'])) {
        await db.grades.put(_gradeFromJson(item));
      }
      for (final item in _maps(decoded['behaviors'])) {
        await db.behaviorRecords.put(_behaviorFromJson(item));
      }
      for (final item in _maps(decoded['notes'])) {
        await db.studentNotes.put(_noteFromJson(item));
      }
      for (final item in _maps(decoded['imports'])) {
        await db.studentImportRecords.put(_importFromJson(item));
      }
    });
  }

  Future<void> updateSettings({
    required String schoolName,
    required String teacherName,
    required String academicYear,
    required String stage,
  }) async {
    final db = await _db;
    final settings = await db.appSettings.get(1) ?? AppSettings();
    settings
      ..id = 1
      ..schoolName = schoolName.trim()
      ..teacherName = teacherName.trim()
      ..academicYear = academicYear.trim()
      ..stage = stage.trim();
    await db.writeTxn(() => db.appSettings.put(settings));
  }

  Future<void> deleteClassCascade(String classUuid) async {
    final db = await _db;
    await db.writeTxn(() async {
      final sections = await db.sections.where().findAll();
      final students = await db.students.where().findAll();
      final sectionIds = sections
          .where((section) => section.classUuid == classUuid)
          .map((section) => section.uuid)
          .toSet();
      final studentIds = students
          .where((student) =>
              student.classUuid == classUuid || sectionIds.contains(student.sectionUuid))
          .map((student) => student.uuid)
          .toSet();

      final attendance = await db.attendanceRecords.where().findAll();
      final grades = await db.grades.where().findAll();
      final behaviors = await db.behaviorRecords.where().findAll();
      final notes = await db.studentNotes.where().findAll();
      final imports = await db.studentImportRecords.where().findAll();

      for (final item in attendance.where((item) => studentIds.contains(item.studentUuid))) {
        await db.attendanceRecords.delete(item.id);
      }
      for (final item in grades.where((item) => studentIds.contains(item.studentUuid))) {
        await db.grades.delete(item.id);
      }
      for (final item in behaviors.where((item) => studentIds.contains(item.studentUuid))) {
        await db.behaviorRecords.delete(item.id);
      }
      for (final item in notes.where((item) => studentIds.contains(item.studentUuid))) {
        await db.studentNotes.delete(item.id);
      }
      for (final item in imports.where((item) => item.classUuid == classUuid)) {
        await db.studentImportRecords.delete(item.id);
      }
      for (final student in students.where((item) => studentIds.contains(item.uuid))) {
        await db.students.delete(student.id);
      }
      for (final section in sections.where((item) => sectionIds.contains(item.uuid))) {
        await db.sections.delete(section.id);
      }

      final schoolClass = await db.schoolClasss
          .filter()
          .uuidEqualTo(classUuid)
          .findFirst();
      if (schoolClass != null) await db.schoolClasss.delete(schoolClass.id);
    });
  }

  Future<void> deleteStudentCascade(String studentUuid) async {
    final db = await _db;
    await db.writeTxn(() async {
      final student = await db.students.filter().uuidEqualTo(studentUuid).findFirst();
      if (student == null) return;
      final attendance = await db.attendanceRecords.where().findAll();
      final grades = await db.grades.where().findAll();
      final behaviors = await db.behaviorRecords.where().findAll();
      final notes = await db.studentNotes.where().findAll();
      for (final item in attendance.where((item) => item.studentUuid == studentUuid)) {
        await db.attendanceRecords.delete(item.id);
      }
      for (final item in grades.where((item) => item.studentUuid == studentUuid)) {
        await db.grades.delete(item.id);
      }
      for (final item in behaviors.where((item) => item.studentUuid == studentUuid)) {
        await db.behaviorRecords.delete(item.id);
      }
      for (final item in notes.where((item) => item.studentUuid == studentUuid)) {
        await db.studentNotes.delete(item.id);
      }
      await db.students.delete(student.id);
    });
  }

  Future<String> exportBackupJson() async {
    final db = await _db;
    final payload = <String, dynamic>{
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': (await db.appSettings.get(1) ?? AppSettings()).toJson(),
      'classes': (await db.schoolClasss.where().findAll()).map((e) => e.toJson()).toList(),
      'sections': (await db.sections.where().findAll()).map((e) => e.toJson()).toList(),
      'students': (await db.students.where().findAll()).map((e) => e.toJson()).toList(),
      'attendance': (await db.attendanceRecords.where().findAll()).map((e) => e.toJson()).toList(),
      'gradeFields': (await db.gradeFields.where().findAll()).map((e) => e.toJson()).toList(),
      'grades': (await db.grades.where().findAll()).map((e) => e.toJson()).toList(),
      'behaviors': (await db.behaviorRecords.where().findAll()).map((e) => e.toJson()).toList(),
      'notes': (await db.studentNotes.where().findAll()).map((e) => e.toJson()).toList(),
      'imports': (await db.studentImportRecords.where().findAll()).map((e) => e.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false);
}

String _string(Map<String, dynamic> json, String key, [String fallback = '']) =>
    json[key]?.toString() ?? fallback;

DateTime _date(Map<String, dynamic> json, String key, [DateTime? fallback]) =>
    DateTime.tryParse(_string(json, key)) ?? fallback ?? DateTime.now();

StudentGender _gender(String value) => value == 'أنثى' || value == 'female'
    ? StudentGender.female
    : StudentGender.male;

StudentStatus _studentStatus(String value) => switch (value) {
      'منقول' || 'transferred' => StudentStatus.transferred,
      'متخرج' || 'graduated' => StudentStatus.graduated,
      'موقوف' || 'suspended' => StudentStatus.suspended,
      _ => StudentStatus.active,
    };

AttendanceStatus _attendanceStatus(String value) => switch (value) {
      'absent' || 'غائب' => AttendanceStatus.absent,
      'excused' || 'بعذر' => AttendanceStatus.excused,
      'late' || 'متأخر' => AttendanceStatus.late,
      'leave' || 'إجازة' => AttendanceStatus.leave,
      _ => AttendanceStatus.present,
    };

BehaviorCategory _behaviorCategory(String value) => switch (value) {
      'positive' => BehaviorCategory.positive,
      'followup' => BehaviorCategory.followup,
      _ => BehaviorCategory.negative,
    };

BehaviorViolationType? _violationType(String value) => switch (value) {
      'absence' => BehaviorViolationType.absence,
      'lessonDisruption' => BehaviorViolationType.lessonDisruption,
      'seriousMisconduct' => BehaviorViolationType.seriousMisconduct,
      'other' => BehaviorViolationType.other,
      _ => null,
    };

NoteCategory _noteCategory(String value) => switch (value) {
      'health' => NoteCategory.health,
      'educational' => NoteCategory.educational,
      'attendance' => NoteCategory.attendance,
      'other' => NoteCategory.other,
      _ => NoteCategory.academic,
    };

StudentImportFormat _importFormat(String value) =>
    value == 'excel' ? StudentImportFormat.excel : StudentImportFormat.text;

AppSettings _settingsFromJson(dynamic value) {
  final json = value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  final settings = AppSettings()
    ..id = 1
    ..schoolName = _string(json, 'schoolName')
    ..teacherName = _string(json, 'teacherName')
    ..academicYear = _string(json, 'academicYear', '2026 / 2027')
    ..stage = _string(json, 'stage');
  final behavior = json['behavior'];
  if (behavior is Map) {
    settings.dismissalThreshold = (behavior['dismissalThreshold'] as num?)?.toDouble() ?? settings.dismissalThreshold;
    settings.warningThreshold = (behavior['warningThreshold'] as num?)?.toDouble() ?? settings.warningThreshold;
    settings.penalties = PenaltyRules.fromJson(behavior['penalties'] is Map ? Map<String, dynamic>.from(behavior['penalties']) : null);
  }
  return settings;
}

SchoolClass _classFromJson(Map<String, dynamic> json) => SchoolClass()
  ..uuid = _string(json, 'id', _string(json, 'uuid', _uuid.v4()))
  ..name = _string(json, 'name', 'فصل غير مسمى')
  ..stage = _string(json, 'stage')
  ..academicYear = _string(json, 'academicYear')
  ..notes = _string(json, 'notes');

Section _sectionFromJson(Map<String, dynamic> json) => Section()
  ..uuid = _string(json, 'id', _string(json, 'uuid', _uuid.v4()))
  ..classUuid = _string(json, 'classId', _string(json, 'classUuid'))
  ..name = _string(json, 'name', 'شعبة غير مسماة')
  ..notes = _string(json, 'notes');

Student _studentFromJson(Map<String, dynamic> json) {
  final firstName = _string(json, 'firstName');
  final fatherName = _string(json, 'fatherName');
  final lastName = _string(json, 'lastName');
  final fullName = _string(json, 'fullName', [firstName, fatherName, lastName].where((e) => e.isNotEmpty).join(' '));
  return Student()
    ..uuid = _string(json, 'id', _string(json, 'uuid', _uuid.v4()))
    ..studentNumber = _string(json, 'studentNumber')
    ..firstName = firstName.isEmpty ? fullName : firstName
    ..fatherName = fatherName
    ..lastName = lastName.isEmpty ? fullName : lastName
    ..fullName = fullName.isEmpty ? 'طالب غير مسمى' : fullName
    ..gender = _gender(_string(json, 'gender'))
    ..classUuid = _string(json, 'classId', _string(json, 'classUuid'))
    ..sectionUuid = _string(json, 'sectionId', _string(json, 'sectionUuid'))
    ..status = _studentStatus(_string(json, 'status'))
    ..guardianName = _string(json, 'guardianName')
    ..guardianPhone = _string(json, 'guardianPhone')
    ..createdAt = _date(json, 'createdAt');
}

AttendanceRecord _attendanceFromJson(Map<String, dynamic> json) => AttendanceRecord()
  ..studentUuid = _string(json, 'studentId', _string(json, 'studentUuid'))
  ..date = _date(json, 'date')
  ..status = _attendanceStatus(_string(json, 'status'))
  ..reason = _string(json, 'reason')
  ..notes = _string(json, 'notes')
  ..updatedAt = _date(json, 'updatedAt');

GradeField _gradeFieldFromJson(Map<String, dynamic> json) => GradeField()
  ..uuid = _string(json, 'id', _string(json, 'uuid', _uuid.v4()))
  ..subject = _string(json, 'subject')
  ..title = _string(json, 'title', 'درجة')
  ..maxScore = (json['maxScore'] as num?)?.toDouble() ?? 100
  ..term = _string(json, 'term', 'الفصل الأول')
  ..date = _date(json, 'date');

Grade _gradeFromJson(Map<String, dynamic> json) => Grade()
  ..studentUuid = _string(json, 'studentId', _string(json, 'studentUuid'))
  ..fieldUuid = _string(json, 'fieldId', _string(json, 'fieldUuid'))
  ..score = (json['score'] as num?)?.toDouble() ?? 0
  ..notes = _string(json, 'notes')
  ..createdAt = _date(json, 'createdAt');

BehaviorRecord _behaviorFromJson(Map<String, dynamic> json) => BehaviorRecord()
  ..uuid = _string(json, 'id', _string(json, 'uuid', _uuid.v4()))
  ..studentUuid = _string(json, 'studentId', _string(json, 'studentUuid'))
  ..category = _behaviorCategory(_string(json, 'category'))
  ..title = _string(json, 'title', 'سلوك')
  ..details = _string(json, 'details')
  ..actionTaken = _string(json, 'actionTaken')
  ..followUp = _string(json, 'followUp')
  ..date = _date(json, 'date')
  ..violationType = _violationType(_string(json, 'violationType'))
  ..penaltyPoints = (json['penaltyPoints'] as num?)?.toDouble() ?? 0;

StudentNote _noteFromJson(Map<String, dynamic> json) => StudentNote()
  ..uuid = _string(json, 'id', _string(json, 'uuid', _uuid.v4()))
  ..studentUuid = _string(json, 'studentId', _string(json, 'studentUuid'))
  ..category = _noteCategory(_string(json, 'category'))
  ..title = _string(json, 'title', 'ملاحظة')
  ..details = _string(json, 'details')
  ..needsFollowUp = json['needsFollowUp'] == true
  ..followUpDate = json['followUpDate'] == null ? null : _date(json, 'followUpDate')
  ..date = _date(json, 'date');

StudentImportRecord _importFromJson(Map<String, dynamic> json) => StudentImportRecord()
  ..uuid = _string(json, 'id', _string(json, 'uuid', _uuid.v4()))
  ..createdAt = _date(json, 'createdAt')
  ..classUuid = _string(json, 'classId', _string(json, 'classUuid'))
  ..sectionUuid = _string(json, 'sectionId', _string(json, 'sectionUuid'))
  ..sourceFilename = _string(json, 'sourceFilename', 'backup')
  ..sourceFormat = _importFormat(_string(json, 'sourceFormat'))
  ..studentUuids = (json['studentIds'] as List? ?? const []).map((e) => e.toString()).toList()
  ..addedCount = (json['addedCount'] as num?)?.toInt() ?? 0
  ..revertedAt = json['revertedAt'] == null ? null : _date(json, 'revertedAt');
