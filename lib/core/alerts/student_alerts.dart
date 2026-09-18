import '../database/app_snapshot.dart';
import '../database/isar_models.dart';
import '../behavior/behavior_summary.dart';

/// أنواع التنبيهات التي تظهر داخل زر الإشعارات في الرئيسية.
enum StudentAlertType {
  /// تجاوز الطالب حد التنبيه السلوكي دون حد الفصل.
  behaviorWarning,

  /// وصلت الدرجة السلوكية للطالب إلى حد الفصل أو تجاوزتها.
  behaviorDismissal,

  /// بلغ الطالب عدد أيام الغياب المحدد في الإعدادات أو تجاوزه.
  absenceThreshold,
}

/// تنبيه موحّد لطالب واحد يجمع أسباب ظهوره داخل زر الإشعارات.
///
/// يظهر الطالب مرة واحدة فقط حتى لو تجاوز أكثر من حد في آنٍ واحد،
/// وتحمل [types] جميع الأسباب معاً.
class StudentAlert {
  const StudentAlert({
    required this.student,
    required this.types,
    required this.absenceCount,
    required this.absenceThreshold,
    this.behaviorSummary,
  });

  final Student student;

  /// أسباب ظهور التنبيه مرتبة من الأعلى خطورة إلى الأدنى.
  final List<StudentAlertType> types;

  /// ملخص السجل السلوكي عند وجود تنبيه سلوكي، وإلا null.
  final BehaviorSummary? behaviorSummary;

  /// عدد أيام الغياب المسجلة للطالب (الحالة «غائب» فقط).
  final int absenceCount;

  /// حد الغياب المضبوط في الإعدادات لحظة بناء التنبيه.
  final double absenceThreshold;

  bool hasType(StudentAlertType type) => types.contains(type);

  /// أخطر سبب في التنبيه؛ يستخدم للتلوين والترتيب.
  StudentAlertType get primaryType => types.first;
}

/// يبني تنبيهات جميع الطلاب من بيانات اللقطة الحالية.
///
/// الدالة نقية (لا تعتمد على أي حالة خارجية) لتسهيل اختبارها
/// وإعادة استخدامها من الواجهات ومنطق الإشعارات النظامية معاً.
List<StudentAlert> buildStudentAlerts({
  required Iterable<Student> students,
  required AppSettings settings,
  required Iterable<BehaviorRecord> behaviors,
  required Iterable<AttendanceRecord> attendance,
}) {
  final behaviorsByStudent = <String, List<BehaviorRecord>>{};
  for (final record in behaviors) {
    behaviorsByStudent.putIfAbsent(record.studentUuid, () => []).add(record);
  }

  final absencesByStudent = <String, int>{};
  for (final record in attendance) {
    if (record.status == AttendanceStatus.absent) {
      absencesByStudent.update(record.studentUuid, (value) => value + 1,
          ifAbsent: () => 1);
    }
  }

  final absenceThreshold = settings.absenceDismissalThreshold;
  final alerts = <StudentAlert>[];

  for (final student in students) {
    final types = <StudentAlertType>[];
    BehaviorSummary? summary;

    final records = behaviorsByStudent[student.uuid];
    if (records != null && records.isNotEmpty) {
      summary = calculateBehaviorSummary(records: records, settings: settings);
      if (summary.dismissed) {
        types.add(StudentAlertType.behaviorDismissal);
      } else if (summary.warning) {
        types.add(StudentAlertType.behaviorWarning);
      }
    }

    final absenceCount = absencesByStudent[student.uuid] ?? 0;
    if (absenceThreshold > 0 && absenceCount >= absenceThreshold) {
      types.add(StudentAlertType.absenceThreshold);
    }

    if (types.isEmpty) continue;
    // إبقاء الأسباب مرتبة من الأعلى خطورة إلى الأدنى.
    types.sort((a, b) => _severity(b) - _severity(a));
    alerts.add(StudentAlert(
      student: student,
      types: types,
      behaviorSummary: summary,
      absenceCount: absenceCount,
      absenceThreshold: absenceThreshold,
    ));
  }

  // الأعلى خطورة أولاً (حد الفصل قبل الغياب قبل التنبيه)، ثم أبجدياً بالاسم
  // لضمان ترتيب ثابت مستقل عن ترتيب المصدر.
  alerts.sort((a, b) {
    final bySeverity = _severity(b.primaryType) - _severity(a.primaryType);
    if (bySeverity != 0) return bySeverity;
    return a.student.fullName.compareTo(b.student.fullName);
  });
  return alerts;
}

int _severity(StudentAlertType type) => switch (type) {
      StudentAlertType.behaviorDismissal => 3,
      StudentAlertType.absenceThreshold => 2,
      StudentAlertType.behaviorWarning => 1,
    };

/// صياغة عربية سليمة لعدد أيام الغياب.
String absenceDaysLabel(int count) {
  if (count <= 0) return 'لا أيام غياب';
  if (count == 1) return 'يوم واحد';
  if (count == 2) return 'يومان';
  if (count <= 10) return '$count أيام';
  return '$count يوماً';
}

/// ينشئ تنبيهات الطلاب انطلاقاً من لقطة التطبيق الحالية.
List<StudentAlert> buildStudentAlertsFromSnapshot(AppSnapshot snapshot) =>
    buildStudentAlerts(
      students: snapshot.students,
      settings: snapshot.settings,
      behaviors: snapshot.behaviors,
      attendance: snapshot.attendance,
    );
