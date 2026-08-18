import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:uuid/uuid.dart';

import 'app_snapshot.dart';
import 'database_service.dart';
import 'isar_models.dart';
import 'local_store.dart';
import '../utils/iterable_extensions.dart';

final _uuid = const Uuid();

class LocalRepository implements LocalStore {
  LocalRepository(this._databaseService);

  final DatabaseService _databaseService;
  Future<Isar> get _db => _databaseService.open();

  @override
  Future<AppSnapshot> loadSnapshot() async {
    final db = await _db;
    final settings = await db.appSettings.get(1) ?? AppSettings();
    if (settings.id != 1) {
      settings.id = 1;
      await db.writeTxn(() => db.appSettings.put(settings));
    }

    final classes = await db.schoolClasses.where().findAll();
    final sections = await db.sections.where().findAll();
    final students = await db.students.where().findAll();
    final gradeFields = await db.gradeFields.where().findAll();
    final grades = await db.grades.where().findAll();
    final attendance = await db.attendanceRecords.where().findAll();
    final behaviors = await db.behaviorRecords.where().findAll();
    final notes = await db.studentNotes.where().findAll();
    final imports = await db.studentImportRecords.where().findAll();
    final today = _day(DateTime.now());
    final todayAttendance = attendance.where((item) => _sameDay(item.date, today)).toList();

    classes.sort((a, b) => a.name.compareTo(b.name));
    sections.sort((a, b) => a.name.compareTo(b.name));
    students.sort((a, b) => a.fullName.compareTo(b.fullName));
    gradeFields.sort((a, b) => b.date.compareTo(a.date));
    attendance.sort((a, b) => b.date.compareTo(a.date));
    behaviors.sort((a, b) => b.date.compareTo(a.date));
    notes.sort((a, b) => b.date.compareTo(a.date));
    imports.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return AppSnapshot(
      settings: settings,
      classes: classes,
      sections: sections,
      students: students,
      gradeFields: gradeFields,
      grades: grades,
      attendance: attendance,
      todayAttendance: todayAttendance,
      behaviors: behaviors,
      notes: notes,
      imports: imports,
    );
  }

  @override
  Future<SchoolClass> createClass({
    required String name,
    String stage = '',
    String academicYear = '',
    String notes = '',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const FormatException('يجب إدخال اسم الصف.');
    final db = await _db;
    final schoolClass = SchoolClass()
      ..uuid = _uuid.v4()
      ..name = trimmed
      ..stage = stage.trim()
      ..academicYear = academicYear.trim()
      ..notes = notes.trim();
    await db.writeTxn(() => db.schoolClasses.put(schoolClass));
    return schoolClass;
  }

  @override
  Future<Section> createSection({
    required String classUuid,
    required String name,
    String notes = '',
  }) async {
    final trimmed = name.trim();
    if (classUuid.isEmpty || trimmed.isEmpty) {
      throw const FormatException('يجب تحديد الصف واسم الشعبة.');
    }
    final db = await _db;
    final section = Section()
      ..uuid = _uuid.v4()
      ..classUuid = classUuid
      ..name = trimmed
      ..notes = notes.trim();
    await db.writeTxn(() => db.sections.put(section));
    return section;
  }

  @override
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
    final first = firstName.trim();
    final last = lastName.trim();
    if (first.isEmpty || last.isEmpty || classUuid.isEmpty) {
      throw const FormatException('الاسم الأول واسم العائلة والصف حقول مطلوبة.');
    }
    final db = await _db;
    final student = Student()
      ..uuid = _uuid.v4()
      ..firstName = first
      ..fatherName = fatherName.trim()
      ..lastName = last
      ..fullName = [first, fatherName, last]
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .join(' ')
      ..studentNumber = studentNumber.trim()
      ..classUuid = classUuid
      ..sectionUuid = sectionUuid.trim()
      ..gender = gender
      ..guardianName = guardianName.trim()
      ..guardianPhone = guardianPhone.trim();
    await db.writeTxn(() => db.students.put(student));
    return student;
  }

  @override
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
  }) async {
    final db = await _db;
    final students = await db.students.where().findAll();
    final student = students.where((item) => item.uuid == studentUuid).firstOrNull;
    if (student == null) throw const FormatException('الطالب غير موجود.');
    student
      ..firstName = firstName.trim()
      ..fatherName = fatherName.trim()
      ..lastName = lastName.trim()
      ..fullName = [firstName, fatherName, lastName]
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .join(' ')
      ..studentNumber = studentNumber.trim()
      ..classUuid = classUuid
      ..sectionUuid = sectionUuid.trim()
      ..gender = gender
      ..status = status
      ..guardianName = guardianName.trim()
      ..guardianPhone = guardianPhone.trim();
    await db.writeTxn(() => db.students.put(student));
  }

  @override
  Future<void> updateSettings({
    required String schoolName,
    required String teacherName,
    required String academicYear,
    required String stage,
    double? dismissalThreshold,
    double? warningThreshold,
    PenaltyRules? penalties,
  }) async {
    final db = await _db;
    final settings = await db.appSettings.get(1) ?? AppSettings();
    settings
      ..id = 1
      ..schoolName = schoolName.trim()
      ..teacherName = teacherName.trim()
      ..academicYear = academicYear.trim()
      ..stage = stage.trim();
    if (dismissalThreshold != null) settings.dismissalThreshold = dismissalThreshold;
    if (warningThreshold != null) settings.warningThreshold = warningThreshold;
    if (penalties != null) settings.penalties = penalties;
    if (settings.warningThreshold > settings.dismissalThreshold) {
      throw const FormatException('حد التنبيه يجب أن يكون أقل من حد الفصل.');
    }
    await db.writeTxn(() => db.appSettings.put(settings));
  }

  @override
  Future<void> setAttendance({
    required String studentUuid,
    required DateTime date,
    required AttendanceStatus status,
    String reason = '',
    String notes = '',
  }) async {
    final db = await _db;
    final normalized = _day(date);
    await db.writeTxn(() async {
      final records = await db.attendanceRecords.where().findAll();
      final existing = records.where((item) => item.studentUuid == studentUuid && _sameDay(item.date, normalized)).firstOrNull;
      final record = existing ?? (AttendanceRecord()..studentUuid = studentUuid..date = normalized);
      record
        ..status = status
        ..reason = reason.trim()
        ..notes = notes.trim()
        ..updatedAt = DateTime.now();
      await db.attendanceRecords.put(record);
    });
  }

  @override
  Future<GradeField> createGradeField({
    required String subject,
    required String title,
    required double maxScore,
    required String term,
  }) async {
    if (subject.trim().isEmpty || title.trim().isEmpty || maxScore <= 0) {
      throw const FormatException('بيانات حقل الدرجة غير مكتملة.');
    }
    final db = await _db;
    final field = GradeField()
      ..uuid = _uuid.v4()
      ..subject = subject.trim()
      ..title = title.trim()
      ..maxScore = maxScore
      ..term = term.trim().isEmpty ? 'الفصل الأول' : term.trim();
    await db.writeTxn(() => db.gradeFields.put(field));
    return field;
  }

  @override
  Future<void> saveGrade({
    required String studentUuid,
    required String fieldUuid,
    required double score,
    String notes = '',
  }) async {
    final db = await _db;
    await db.writeTxn(() async {
      final fields = await db.gradeFields.where().findAll();
      final field = fields.where((item) => item.uuid == fieldUuid).firstOrNull;
      if (field == null) throw const FormatException('حقل الدرجة غير موجود.');
      final grades = await db.grades.where().findAll();
      final existing = grades.where((item) => item.studentUuid == studentUuid && item.fieldUuid == fieldUuid).firstOrNull;
      final grade = existing ?? (Grade()..studentUuid = studentUuid..fieldUuid = fieldUuid);
      grade
        ..score = score.clamp(0, field.maxScore)
        ..notes = notes.trim()
        ..createdAt = existing?.createdAt ?? DateTime.now();
      await db.grades.put(grade);
    });
  }

  @override
  Future<void> createGradeEntry({
    required String studentUuid,
    required String subject,
    required String title,
    required double maxScore,
    required String term,
    required double score,
    String notes = '',
  }) async {
    if (studentUuid.trim().isEmpty || subject.trim().isEmpty || title.trim().isEmpty || maxScore <= 0 || score < 0 || score > maxScore) {
      throw const FormatException('بيانات الدرجة غير صحيحة.');
    }
    final db = await _db;
    final field = GradeField()
      ..uuid = _uuid.v4()
      ..subject = subject.trim()
      ..title = title.trim()
      ..maxScore = maxScore
      ..term = term.trim().isEmpty ? 'الفصل الأول' : term.trim();
    final grade = Grade()
      ..studentUuid = studentUuid
      ..fieldUuid = field.uuid
      ..score = score
      ..notes = notes.trim();
    await db.writeTxn(() async {
      await db.gradeFields.put(field);
      await db.grades.put(grade);
    });
  }

  @override
  Future<BehaviorRecord> createBehavior({
    required String studentUuid,
    required BehaviorCategory category,
    required String title,
    required String details,
    required BehaviorViolationType violationType,
    String actionTaken = '',
    String followUp = '',
    DateTime? date,
  }) async {
    if (title.trim().isEmpty || details.trim().isEmpty) {
      throw const FormatException('عنوان السلوك وتفاصيله حقول مطلوبة.');
    }
    final db = await _db;
    final settings = await db.appSettings.get(1) ?? AppSettings();
    final record = BehaviorRecord()
      ..uuid = _uuid.v4()
      ..studentUuid = studentUuid
      ..category = category
      ..title = title.trim()
      ..details = details.trim()
      ..actionTaken = actionTaken.trim()
      ..followUp = followUp.trim()
      ..date = date ?? DateTime.now()
      ..violationType = violationType
      ..penaltyPoints = category == BehaviorCategory.negative ? settings.penalties.forType(violationType) : 0;
    await db.writeTxn(() => db.behaviorRecords.put(record));
    return record;
  }

  @override
  Future<void> deleteBehavior(String behaviorUuid) async {
    final db = await _db;
    final records = await db.behaviorRecords.where().findAll();
    final record = records.where((item) => item.uuid == behaviorUuid).firstOrNull;
    if (record == null) return;
    await db.writeTxn(() => db.behaviorRecords.delete(record.id));
  }

  @override
  Future<StudentNote> createNote({
    required String studentUuid,
    required NoteCategory category,
    required String title,
    required String details,
    bool needsFollowUp = false,
    DateTime? followUpDate,
  }) async {
    if (title.trim().isEmpty || details.trim().isEmpty) {
      throw const FormatException('عنوان الملاحظة وتفاصيلها حقول مطلوبة.');
    }
    final db = await _db;
    final note = StudentNote()
      ..uuid = _uuid.v4()
      ..studentUuid = studentUuid
      ..category = category
      ..title = title.trim()
      ..details = details.trim()
      ..needsFollowUp = needsFollowUp
      ..followUpDate = followUpDate
      ..date = DateTime.now();
    await db.writeTxn(() => db.studentNotes.put(note));
    return note;
  }

  @override
  Future<void> deleteNote(String noteUuid) async {
    final db = await _db;
    final notes = await db.studentNotes.where().findAll();
    final note = notes.where((item) => item.uuid == noteUuid).firstOrNull;
    if (note == null) return;
    await db.writeTxn(() => db.studentNotes.delete(note.id));
  }

  @override
  Future<StudentImportRecord> importStudents({
    required String classUuid,
    required String sectionUuid,
    required String sourceFilename,
    required StudentImportFormat sourceFormat,
    required List<String> names,
  }) async {
    final db = await _db;
    final existing = await db.students.where().findAll();
    final existingKeys = existing.map((item) => _key(item.fullName)).toSet();
    final importedIds = <String>[];
    await db.writeTxn(() async {
      for (final rawName in names) {
        final fullName = rawName.trim().replaceAll(RegExp(r'\\s+'), ' ');
        final key = _key(fullName);
        if (key.isEmpty || existingKeys.contains(key)) continue;
        final parts = fullName.split(' ');
        final firstName = parts.first;
        final lastName = parts.length > 1 ? parts.last : parts.first;
        final fatherName = parts.length > 2 ? parts.sublist(1, parts.length - 1).join(' ') : '';
        final student = Student()
          ..uuid = _uuid.v4()
          ..firstName = firstName
          ..fatherName = fatherName
          ..lastName = lastName
          ..fullName = fullName
          ..classUuid = classUuid
          ..sectionUuid = sectionUuid;
        await db.students.put(student);
        importedIds.add(student.uuid);
        existingKeys.add(key);
      }
      final record = StudentImportRecord()
        ..uuid = _uuid.v4()
        ..classUuid = classUuid
        ..sectionUuid = sectionUuid
        ..sourceFilename = sourceFilename
        ..sourceFormat = sourceFormat
        ..studentUuids = importedIds
        ..addedCount = importedIds.length;
      await db.studentImportRecords.put(record);
    });
    final records = await db.studentImportRecords.where().findAll();
    return records.where((item) => item.studentUuids.join('|') == importedIds.join('|')).last;
  }

  @override
  Future<void> revertImport(String importUuid) async {
    final db = await _db;
    await db.writeTxn(() async {
      final imports = await db.studentImportRecords.where().findAll();
      final record = imports.where((item) => item.uuid == importUuid).firstOrNull;
      if (record == null || record.revertedAt != null) return;
      for (final studentUuid in record.studentUuids) {
        await _deleteStudentInTxn(db, studentUuid);
      }
      record.revertedAt = DateTime.now();
      await db.studentImportRecords.put(record);
    });
  }

  @override
  Future<void> deleteClassCascade(String classUuid) async {
    final db = await _db;
    await db.writeTxn(() async {
      final sections = await db.sections.where().findAll();
      final sectionIds = sections.where((item) => item.classUuid == classUuid).map((item) => item.uuid).toSet();
      final students = await db.students.where().findAll();
      final studentIds = students.where((item) => item.classUuid == classUuid || sectionIds.contains(item.sectionUuid)).map((item) => item.uuid).toSet();
      for (final studentUuid in studentIds) {
        await _deleteStudentInTxn(db, studentUuid);
      }
      for (final section in sections.where((item) => sectionIds.contains(item.uuid))) {
        await db.sections.delete(section.id);
      }
      final classes = await db.schoolClasses.where().findAll();
      final schoolClass = classes.where((item) => item.uuid == classUuid).firstOrNull;
      if (schoolClass != null) await db.schoolClasses.delete(schoolClass.id);
    });
  }

  @override
  Future<void> deleteStudentCascade(String studentUuid) async {
    final db = await _db;
    await db.writeTxn(() => _deleteStudentInTxn(db, studentUuid));
  }

  Future<void> _deleteStudentInTxn(Isar db, String studentUuid) async {
    final students = await db.students.where().findAll();
    final student = students.where((item) => item.uuid == studentUuid).firstOrNull;
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
  }

  @override
  Future<String> exportBackupJson() async {
    final db = await _db;
    final payload = <String, dynamic>{
      'schemaVersion': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': (await db.appSettings.get(1) ?? AppSettings()).toJson(),
      'classes': (await db.schoolClasses.where().findAll()).map((e) => e.toJson()).toList(),
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

  @override
  Future<void> restoreBackupJson(String json) async {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) throw const FormatException('تنسيق النسخة الاحتياطية غير صالح.');
    final schemaVersion = (decoded['schemaVersion'] as num?)?.toInt() ?? 1;
    if (schemaVersion > 2) throw FormatException('إصدار النسخة $schemaVersion غير مدعوم.');
    final db = await _db;
    await db.writeTxn(() async {
      await db.clear();
      await db.appSettings.put(_settingsFromJson(decoded['settings']));
      for (final item in _maps(decoded['classes'])) {
        await db.schoolClasses.put(_classFromJson(item));
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
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String _key(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'\\s+'), ' ');
List<Map<String, dynamic>> _maps(dynamic value) => value is List ? value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false) : const [];
String _string(Map<String, dynamic> json, String key, [String fallback = '']) => json[key]?.toString() ?? fallback;
DateTime _date(Map<String, dynamic> json, String key, [DateTime? fallback]) => DateTime.tryParse(_string(json, key)) ?? fallback ?? DateTime.now();
StudentGender _gender(String value) => value == 'أنثى' || value == 'female' ? StudentGender.female : StudentGender.male;
StudentStatus _studentStatus(String value) => switch (value) { 'منقول' || 'transferred' => StudentStatus.transferred, 'متخرج' || 'graduated' => StudentStatus.graduated, 'موقوف' || 'suspended' => StudentStatus.suspended, _ => StudentStatus.active };
AttendanceStatus _attendanceStatus(String value) => switch (value) { 'absent' || 'غائب' => AttendanceStatus.absent, 'excused' || 'بعذر' => AttendanceStatus.excused, 'late' || 'متأخر' => AttendanceStatus.late, 'leave' || 'إجازة' => AttendanceStatus.leave, _ => AttendanceStatus.present };
BehaviorCategory _behaviorCategory(String value) => switch (value) { 'positive' => BehaviorCategory.positive, 'followup' => BehaviorCategory.followup, _ => BehaviorCategory.negative };
BehaviorViolationType _violationType(String value) => switch (value) { 'absence' => BehaviorViolationType.absence, 'lessonDisruption' => BehaviorViolationType.lessonDisruption, 'seriousMisconduct' => BehaviorViolationType.seriousMisconduct, 'other' => BehaviorViolationType.other, _ => BehaviorViolationType.none };
NoteCategory _noteCategory(String value) => switch (value) { 'health' => NoteCategory.health, 'educational' => NoteCategory.educational, 'attendance' => NoteCategory.attendance, 'other' => NoteCategory.other, _ => NoteCategory.academic };
StudentImportFormat _importFormat(String value) => switch (value) { 'excel' => StudentImportFormat.excel, 'word' => StudentImportFormat.word, _ => StudentImportFormat.text };

AppSettings _settingsFromJson(dynamic value) {
  final json = value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  final settings = AppSettings()..id = 1..schoolName = _string(json, 'schoolName')..teacherName = _string(json, 'teacherName')..academicYear = _string(json, 'academicYear', '2026 / 2027')..stage = _string(json, 'stage');
  final behavior = json['behavior'];
  if (behavior is Map) {
    settings.dismissalThreshold = (behavior['dismissalThreshold'] as num?)?.toDouble() ?? settings.dismissalThreshold;
    settings.warningThreshold = (behavior['warningThreshold'] as num?)?.toDouble() ?? settings.warningThreshold;
    final penalties = behavior['penalties'];
    settings.penalties = PenaltyRules.fromJson(penalties is Map ? Map<String, dynamic>.from(penalties) : null);
  }
  return settings;
}
SchoolClass _classFromJson(Map<String, dynamic> json) => SchoolClass()..uuid = _string(json, 'id', _string(json, 'uuid', _uuid.v4()))..name = _string(json, 'name', 'فصل غير مسمى')..stage = _string(json, 'stage')..academicYear = _string(json, 'academicYear')..notes = _string(json, 'notes');
Section _sectionFromJson(Map<String, dynamic> json) => Section()..uuid = _string(json, 'id', _string(json, 'uuid', _uuid.v4()))..classUuid = _string(json, 'classId', _string(json, 'classUuid'))..name = _string(json, 'name', 'شعبة غير مسماة')..notes = _string(json, 'notes');
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
AttendanceRecord _attendanceFromJson(Map<String, dynamic> json) => AttendanceRecord()..studentUuid = _string(json, 'studentId', _string(json, 'studentUuid'))..date = _date(json, 'date')..status = _attendanceStatus(_string(json, 'status'))..reason = _string(json, 'reason')..notes = _string(json, 'notes')..updatedAt = _date(json, 'updatedAt');
GradeField _gradeFieldFromJson(Map<String, dynamic> json) => GradeField()
  ..uuid = _string(json, 'id', _string(json, 'uuid', _uuid.v4()))
  ..subject = _string(json, 'subject')
  ..title = _string(json, 'title', 'درجة')
  ..maxScore = (json['maxScore'] as num?)?.toDouble() ?? 100
  ..term = _string(json, 'term', 'الفصل الأول')
  ..date = _date(json, 'date');
Grade _gradeFromJson(Map<String, dynamic> json) => Grade()..studentUuid = _string(json, 'studentId', _string(json, 'studentUuid'))..fieldUuid = _string(json, 'fieldId', _string(json, 'fieldUuid'))..score = (json['score'] as num?)?.toDouble() ?? 0..notes = _string(json, 'notes')..createdAt = _date(json, 'createdAt');
BehaviorRecord _behaviorFromJson(Map<String, dynamic> json) => BehaviorRecord()..uuid = _string(json, 'id', _string(json, 'uuid', _uuid.v4()))..studentUuid = _string(json, 'studentId', _string(json, 'studentUuid'))..category = _behaviorCategory(_string(json, 'category'))..title = _string(json, 'title', 'سلوك')..details = _string(json, 'details')..actionTaken = _string(json, 'actionTaken')..followUp = _string(json, 'followUp')..date = _date(json, 'date')..violationType = _violationType(_string(json, 'violationType'))..penaltyPoints = (json['penaltyPoints'] as num?)?.toDouble() ?? 0;
StudentNote _noteFromJson(Map<String, dynamic> json) => StudentNote()..uuid = _string(json, 'id', _string(json, 'uuid', _uuid.v4()))..studentUuid = _string(json, 'studentId', _string(json, 'studentUuid'))..category = _noteCategory(_string(json, 'category'))..title = _string(json, 'title', 'ملاحظة')..details = _string(json, 'details')..needsFollowUp = json['needsFollowUp'] == true..followUpDate = json['followUpDate'] == null ? null : _date(json, 'followUpDate')..date = _date(json, 'date');
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
