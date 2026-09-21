import '../database/isar_models.dart';

class BehaviorSummary {
  const BehaviorSummary({
    required this.totalPoints,
    required this.negativeCount,
    required this.followUpCount,
    required this.positiveCount,
    required this.warningThreshold,
    required this.dismissalThreshold,
  });

  final double totalPoints;
  final int negativeCount;
  final int followUpCount;
  final int positiveCount;
  final double warningThreshold;
  final double dismissalThreshold;

  bool get dismissed => totalPoints >= dismissalThreshold;
  bool get warning => !dismissed && totalPoints >= warningThreshold;
  bool get hasAlert => dismissed || warning;
  String get label => dismissed ? 'حد الفصل' : warning ? 'تنبيه' : 'مستقر';
}

BehaviorSummary calculateBehaviorSummary({
  required Iterable<BehaviorRecord> records,
  required AppSettings settings,
}) {
  final studentRecords = records;
  return BehaviorSummary(
    totalPoints: studentRecords.fold(0, (sum, item) => sum + item.penaltyPoints),
    negativeCount: studentRecords.where((item) => item.category == BehaviorCategory.negative).length,
    followUpCount: studentRecords.where((item) => item.category == BehaviorCategory.followup).length,
    positiveCount: studentRecords.where((item) => item.category == BehaviorCategory.positive).length,
    warningThreshold: settings.warningThreshold,
    dismissalThreshold: settings.dismissalThreshold,
  );
}
