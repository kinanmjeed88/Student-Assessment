import 'package:flutter_test/flutter_test.dart';

import 'package:almoktaber/core/alerts/student_alerts.dart';
import 'package:almoktaber/core/database/isar_models.dart';

Student _student(String uuid, String name) => Student()
  ..uuid = uuid
  ..fullName = name
  ..firstName = name
  ..lastName = name
  ..classUuid = 'class-1';

BehaviorRecord _behavior(
  String uuid, {
  required String studentUuid,
  required double points,
  BehaviorCategory category = BehaviorCategory.negative,
}) =>
    BehaviorRecord()
      ..uuid = uuid
      ..studentUuid = studentUuid
      ..category = category
      ..title = 'سلوك'
      ..details = 'تفاصيل'
      ..penaltyPoints = points;

AttendanceRecord _attendance(
  String studentUuid,
  int day, {
  AttendanceStatus status = AttendanceStatus.absent,
}) =>
    AttendanceRecord()
      ..studentUuid = studentUuid
      ..date = DateTime(2026, 9, day)
      ..status = status;

void main() {
  test('does not add absence alerts before reaching the configured threshold', () {
    final settings = AppSettings()..absenceDismissalThreshold = 3;
    final students = [_student('s1', 'أحمد'), _student('s2', 'خالد')];
    final attendance = [
      _attendance('s1', 1),
      _attendance('s1', 2),
      _attendance('s2', 1),
    ];

    final alerts = buildStudentAlerts(
      students: students,
      settings: settings,
      behaviors: const [],
      attendance: attendance,
    );

    // الطالب s1 لديه يومان فقط والطالب s2 يوماً واحداً — لا أحد بلغ الحد.
    expect(alerts, isEmpty);
  });

  test('flags a student who reaches or exceeds the absence threshold', () {
    final settings = AppSettings()..absenceDismissalThreshold = 3;
    final attendance = [
      _attendance('s1', 1),
      _attendance('s1', 2),
      _attendance('s1', 3),
    ];

    final alerts = buildStudentAlerts(
      students: [_student('s1', 'أحمد')],
      settings: settings,
      behaviors: const [],
      attendance: attendance,
    );

    expect(alerts, hasLength(1));
    expect(alerts.single.primaryType, StudentAlertType.absenceThreshold);
    expect(alerts.single.absenceCount, 3);
  });

  test('excused absences do not count toward the absence threshold', () {
    final settings = AppSettings()..absenceDismissalThreshold = 2;
    final attendance = [
      _attendance('s1', 1, status: AttendanceStatus.excused),
      _attendance('s1', 2, status: AttendanceStatus.late),
      _attendance('s1', 3, status: AttendanceStatus.present),
    ];

    final alerts = buildStudentAlerts(
      students: [_student('s1', 'أحمد')],
      settings: settings,
      behaviors: const [],
      attendance: attendance,
    );

    expect(alerts, isEmpty);
  });

  test('keeps behavior alerts and merges multiple reasons per student', () {
    final settings = AppSettings()
      ..warningThreshold = 10
      ..dismissalThreshold = 20
      ..absenceDismissalThreshold = 3;
    final students = [
      _student('s1', 'أحمد'),
      _student('s2', 'خالد'),
      _student('s3', 'عمر'),
    ];

    final alerts = buildStudentAlerts(
      students: students,
      settings: settings,
      behaviors: [
        _behavior('b1', studentUuid: 's1', points: 22),
        _behavior('b2', studentUuid: 's2', points: 12),
      ],
      attendance: [
        _attendance('s2', 1),
        _attendance('s2', 2),
        _attendance('s2', 3),
        _attendance('s3', 1),
        _attendance('s3', 2),
        _attendance('s3', 3),
      ],
    );

    expect(alerts, hasLength(3));
    expect(alerts[0].student.uuid, 's1');
    expect(alerts[0].primaryType, StudentAlertType.behaviorDismissal);
    expect(alerts[1].student.uuid, 's2');
    expect(alerts[1].types, containsAll(<StudentAlertType>[
      StudentAlertType.behaviorWarning,
      StudentAlertType.absenceThreshold,
    ]));
    expect(alerts[1].behaviorSummary?.totalPoints, 12);
    expect(alerts[2].primaryType, StudentAlertType.absenceThreshold);
  });

  test('zero threshold disables absence alerts entirely', () {
    final settings = AppSettings()..absenceDismissalThreshold = 0;
    final attendance = [
      _attendance('s1', 1),
      _attendance('s1', 2),
      _attendance('s1', 3),
      _attendance('s1', 4),
    ];

    final alerts = buildStudentAlerts(
      students: [_student('s1', 'أحمد')],
      settings: settings,
      behaviors: const [],
      attendance: attendance,
    );

    expect(alerts, isEmpty);
  });

  test('formats Arabic absence day counts', () {
    expect(absenceDaysLabel(0), 'لا أيام غياب');
    expect(absenceDaysLabel(1), 'يوم واحد');
    expect(absenceDaysLabel(2), 'يومان');
    expect(absenceDaysLabel(5), '5 أيام');
    expect(absenceDaysLabel(15), '15 يوماً');
  });
}
