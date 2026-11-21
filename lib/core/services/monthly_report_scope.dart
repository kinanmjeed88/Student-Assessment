import '../database/app_snapshot.dart';

/// الفترة الزمنية لتقرير ولي الأمر: من بداية الشهر الحالي حتى لحظة التوليد.
///
/// تُحفظ الأطراف كقيم محلية حتى تبقى حدود المقارنة هي نفسها التي يراها
/// المستخدم على جهازه، بغض النظر عن المنطقة الزمنية لأي خادم خارجي.
class MonthlyReportPeriod {
  const MonthlyReportPeriod({required this.start, required this.end});

  factory MonthlyReportPeriod.current([DateTime? now]) {
    final moment = now ?? DateTime.now();
    return MonthlyReportPeriod(
      start: DateTime(moment.year, moment.month),
      end: moment,
    );
  }

  final DateTime start;
  final DateTime end;

  bool contains(DateTime value) =>
      !value.isBefore(start) && !value.isAfter(end);

  /// صيغة تاريخ واضحة وغير مرتبطة بإعدادات اللغة أو التقويم في الجهاز.
  String get startLabel => _isoDate(start);
  String get endLabel => _isoDate(end);

  @override
  String toString() => '$startLabel — $endLabel';

  static String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

/// لقطة بيانات مقيّدة بالفترة الشهرية، جاهزة للتمرير إلى باني التقارير الحالي.
class MonthlyStudentReport {
  const MonthlyStudentReport({required this.snapshot, required this.period});

  final AppSnapshot snapshot;
  final MonthlyReportPeriod period;
}

/// ينشئ نسخة من [source] تحتوي سجلات الفترة من بداية الشهر حتى [now] فقط.
///
/// لا تعديل على اللقطة الأصلية، ولا تغيير في بنية التقرير: تُمرَّر النسخة
/// الناتجة إلى [ReportService.exportStudentXlsx] أو `exportStudentPdf`
/// فيخرج الملف بنفس تنسيق ملف الطالب المعتاد مع بيانات الشهر فقط.
MonthlyStudentReport scopeToCurrentMonth(AppSnapshot source, {DateTime? now}) {
  final period = MonthlyReportPeriod.current(now);
  bool inPeriod(DateTime value) => period.contains(value);

  final attendance =
      source.attendance.where((record) => inPeriod(record.date)).toList(growable: false);
  final behaviors =
      source.behaviors.where((record) => inPeriod(record.date)).toList(growable: false);
  final notes =
      source.notes.where((record) => inPeriod(record.date)).toList(growable: false);

  // تاريخ الدرجة هو تاريخ تسجيلها في ملف الطالب؛ تاريخ حقل التقييم قد يكون
  // أقدم من الشهر ولا يمثل نشاطاً حقيقياً خلال الفترة المطلوبة.
  final grades =
      source.grades.where((grade) => inPeriod(grade.createdAt)).toList(growable: false);
  final usedFieldUuids = grades.map((grade) => grade.fieldUuid).toSet();
  final gradeFields = source.gradeFields
      .where((field) => usedFieldUuids.contains(field.uuid))
      .toList(growable: false);

  final scoped = AppSnapshot(
    settings: source.settings,
    classes: source.classes,
    sections: source.sections,
    students: source.students,
    gradeFields: gradeFields,
    grades: grades,
    attendance: attendance,
    todayAttendance: source.todayAttendance.where((record) => inPeriod(record.date)).toList(growable: false),
    behaviors: behaviors,
    notes: notes,
    imports: source.imports,
  );

  return MonthlyStudentReport(snapshot: scoped, period: period);
}
