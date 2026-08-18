import 'package:isar/isar.dart';

part 'isar_models.g.dart';

enum StudentGender { male, female }
enum StudentStatus { active, transferred, graduated, suspended }
enum AttendanceStatus { present, absent, excused, late, leave }
enum BehaviorCategory { positive, followup, negative }
enum BehaviorViolationType { absence, lessonDisruption, seriousMisconduct, other }
enum NoteCategory { academic, health, educational, attendance, other }
enum StudentImportFormat { excel, text }

@embedded
class PenaltyRules {
  double absence = 5;
  double lessonDisruption = 10;
  double seriousMisconduct = 20;
  double other = 5;

  double forType(BehaviorViolationType type) => switch (type) {
        BehaviorViolationType.absence => absence,
        BehaviorViolationType.lessonDisruption => lessonDisruption,
        BehaviorViolationType.seriousMisconduct => seriousMisconduct,
        BehaviorViolationType.other => other,
      };

  Map<String, double> toJson() => {
        'absence': absence,
        'lessonDisruption': lessonDisruption,
        'seriousMisconduct': seriousMisconduct,
        'other': other,
      };

  static PenaltyRules fromJson(Map<String, dynamic>? json) {
    final result = PenaltyRules();
    if (json == null) return result;
    result.absence = (json['absence'] as num?)?.toDouble() ?? result.absence;
    result.lessonDisruption =
        (json['lessonDisruption'] as num?)?.toDouble() ?? result.lessonDisruption;
    result.seriousMisconduct =
        (json['seriousMisconduct'] as num?)?.toDouble() ?? result.seriousMisconduct;
    result.other = (json['other'] as num?)?.toDouble() ?? result.other;
    return result;
  }
}

@collection
class AppSettings {
  Id id = 1;
  String schoolName = '';
  String teacherName = '';
  String academicYear = '2026 / 2027';
  String stage = '';
  double dismissalThreshold = 50;
  double warningThreshold = 40;
  PenaltyRules penalties = PenaltyRules();

  Map<String, dynamic> toJson() => {
        'id': id,
        'schoolName': schoolName,
        'teacherName': teacherName,
        'academicYear': academicYear,
        'stage': stage,
        'behavior': {
          'dismissalThreshold': dismissalThreshold,
          'warningThreshold': warningThreshold,
          'penalties': penalties.toJson(),
        },
      };
}

@collection
class SchoolClass {
  Id id = Isar.autoIncrement;
  @Index(unique: true, replace: true)
  late String uuid;
  late String name;
  String stage = '';
  String academicYear = '';
  String notes = '';

  Map<String, dynamic> toJson() => {
        'id': uuid,
        'name': name,
        'stage': stage,
        'academicYear': academicYear,
        'notes': notes,
      };
}

@collection
class Section {
  Id id = Isar.autoIncrement;
  @Index(unique: true, replace: true)
  late String uuid;
  @Index()
  late String classUuid;
  late String name;
  String notes = '';

  Map<String, dynamic> toJson() => {
        'id': uuid,
        'classId': classUuid,
        'name': name,
        'notes': notes,
      };
}

@collection
class Student {
  Id id = Isar.autoIncrement;
  @Index(unique: true, replace: true)
  late String uuid;
  @Index(type: IndexType.value)
  late String fullName;
  String studentNumber = '';
  late String firstName;
  String fatherName = '';
  late String lastName;
  @enumerated
  StudentGender gender = StudentGender.male;
  @Index()
  late String classUuid;
  @Index()
  String sectionUuid = '';
  @enumerated
  StudentStatus status = StudentStatus.active;
  String guardianName = '';
  String guardianPhone = '';
  DateTime createdAt = DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': uuid,
        'studentNumber': studentNumber,
        'firstName': firstName,
        'fatherName': fatherName,
        'lastName': lastName,
        'fullName': fullName,
        'gender': gender.name == 'male' ? 'ذكر' : 'أنثى',
        'classId': classUuid,
        'sectionId': sectionUuid,
        'status': switch (status) {
          StudentStatus.active => 'نشط',
          StudentStatus.transferred => 'منقول',
          StudentStatus.graduated => 'متخرج',
          StudentStatus.suspended => 'موقوف',
        },
        'guardianName': guardianName,
        'guardianPhone': guardianPhone,
        'createdAt': createdAt.toIso8601String(),
      };
}

@collection
class AttendanceRecord {
  Id id = Isar.autoIncrement;
  @Index(unique: true, replace: true, composite: [CompositeIndex('date')])
  late String studentUuid;
  late DateTime date;
  @enumerated
  AttendanceStatus status = AttendanceStatus.present;
  String reason = '';
  String notes = '';
  DateTime updatedAt = DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': '$studentUuid/${date.toIso8601String().substring(0, 10)}',
        'studentId': studentUuid,
        'date': date.toIso8601String().substring(0, 10),
        'status': status.name,
        'reason': reason,
        'notes': notes,
        'updatedAt': updatedAt.toIso8601String(),
      };
}

@collection
class GradeField {
  Id id = Isar.autoIncrement;
  @Index(unique: true, replace: true)
  late String uuid;
  late String subject;
  late String title;
  double maxScore = 100;
  String term = 'الفصل الأول';
  DateTime date = DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': uuid,
        'subject': subject,
        'title': title,
        'maxScore': maxScore,
        'term': term,
        'date': date.toIso8601String().substring(0, 10),
      };
}

@collection
class Grade {
  Id id = Isar.autoIncrement;
  @Index(unique: true, replace: true, composite: [CompositeIndex('fieldUuid')])
  late String studentUuid;
  late String fieldUuid;
  double score = 0;
  String notes = '';
  DateTime createdAt = DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': '$studentUuid/$fieldUuid',
        'studentId': studentUuid,
        'fieldId': fieldUuid,
        'score': score,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };
}

@collection
class BehaviorRecord {
  Id id = Isar.autoIncrement;
  @Index(unique: true, replace: true)
  late String uuid;
  @Index()
  late String studentUuid;
  @enumerated
  BehaviorCategory category = BehaviorCategory.negative;
  late String title;
  late String details;
  String actionTaken = '';
  String followUp = '';
  DateTime date = DateTime.now();
  @enumerated
  BehaviorViolationType? violationType;
  double penaltyPoints = 0;

  Map<String, dynamic> toJson() => {
        'id': uuid,
        'studentId': studentUuid,
        'category': category.name,
        'title': title,
        'details': details,
        'actionTaken': actionTaken,
        'followUp': followUp,
        'date': date.toIso8601String().substring(0, 10),
        'violationType': violationType?.name,
        'penaltyPoints': penaltyPoints,
      };
}

@collection
class StudentNote {
  Id id = Isar.autoIncrement;
  @Index(unique: true, replace: true)
  late String uuid;
  @Index()
  late String studentUuid;
  @enumerated
  NoteCategory category = NoteCategory.academic;
  late String title;
  late String details;
  bool needsFollowUp = false;
  DateTime? followUpDate;
  DateTime date = DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': uuid,
        'studentId': studentUuid,
        'category': category.name,
        'title': title,
        'details': details,
        'needsFollowUp': needsFollowUp,
        'followUpDate': followUpDate?.toIso8601String().substring(0, 10),
        'date': date.toIso8601String().substring(0, 10),
      };
}

@collection
class StudentImportRecord {
  Id id = Isar.autoIncrement;
  @Index(unique: true, replace: true)
  late String uuid;
  DateTime createdAt = DateTime.now();
  late String classUuid;
  late String sectionUuid;
  late String sourceFilename;
  @enumerated
  StudentImportFormat sourceFormat = StudentImportFormat.text;
  List<String> studentUuids = [];
  int addedCount = 0;
  DateTime? revertedAt;

  Map<String, dynamic> toJson() => {
        'id': uuid,
        'createdAt': createdAt.toIso8601String(),
        'classId': classUuid,
        'sectionId': sectionUuid,
        'sourceFilename': sourceFilename,
        'sourceFormat': sourceFormat.name,
        'studentIds': studentUuids,
        'addedCount': addedCount,
        'revertedAt': revertedAt?.toIso8601String(),
      };
}
