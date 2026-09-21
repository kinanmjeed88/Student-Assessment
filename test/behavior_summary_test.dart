import 'package:flutter_test/flutter_test.dart';

import 'package:almoktaber/core/behavior/behavior_summary.dart';
import 'package:almoktaber/core/database/isar_models.dart';

void main() {
  test('calculates behavior totals and thresholds', () {
    final settings = AppSettings()
      ..warningThreshold = 10
      ..dismissalThreshold = 20;

    final records = [
      BehaviorRecord()
        ..uuid = 'negative-1'
        ..studentUuid = 'student-1'
        ..category = BehaviorCategory.negative
        ..violationType = BehaviorViolationType.absence
        ..title = 'غياب'
        ..details = 'غياب متكرر'
        ..penaltyPoints = 12,
      BehaviorRecord()
        ..uuid = 'positive-1'
        ..studentUuid = 'student-1'
        ..category = BehaviorCategory.positive
        ..violationType = BehaviorViolationType.none
        ..title = 'انضباط'
        ..details = 'التزام ممتاز'
        ..penaltyPoints = 0,
    ];

    final summary = calculateBehaviorSummary(records: records, settings: settings);

    expect(summary.totalPoints, 12);
    expect(summary.negativeCount, 1);
    expect(summary.positiveCount, 1);
    expect(summary.followUpCount, 0);
    expect(summary.warning, isTrue);
    expect(summary.dismissed, isFalse);
    expect(summary.label, 'تنبيه');
  });

  test('maps penalty rules to the legacy violation types', () {
    final rules = PenaltyRules()
      ..absence = 5
      ..lessonDisruption = 10
      ..seriousMisconduct = 25
      ..other = 7;

    expect(rules.forType(BehaviorViolationType.none), 0);
    expect(rules.forType(BehaviorViolationType.absence), 5);
    expect(rules.forType(BehaviorViolationType.lessonDisruption), 10);
    expect(rules.forType(BehaviorViolationType.seriousMisconduct), 25);
    expect(rules.forType(BehaviorViolationType.other), 7);
  });
}

