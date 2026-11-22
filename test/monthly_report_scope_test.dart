import 'package:flutter_test/flutter_test.dart';

import 'package:almoktaber/core/services/monthly_report_scope.dart';

import 'support/guardian_report_fixture.dart';

void main() {
  test('يقتصر التقرير على بداية الشهر حتى لحظة الإنشاء', () {
    final fixture = GuardianReportFixture();
    final monthly = scopeToCurrentMonth(fixture.snapshot, now: fixture.now);

    expect(monthly.period.startLabel, '2026-11-01');
    expect(monthly.period.endLabel, '2026-11-21');
    expect(monthly.snapshot.attendance.map((record) => record.date), [
      fixture.monthStart,
      fixture.midMonth,
    ]);
    expect(monthly.snapshot.behaviors.map((record) => record.date), [
      fixture.monthStart,
      fixture.midMonth,
    ]);
    expect(monthly.snapshot.notes.map((record) => record.date), [fixture.midMonth]);
    expect(monthly.snapshot.grades, hasLength(1));
    expect(monthly.snapshot.grades.single.createdAt, fixture.midMonth);
    expect(monthly.snapshot.gradeFields.map((field) => field.uuid), ['field-current']);
  });

  test('لا يعدّل اللقطة الأصلية', () {
    final fixture = GuardianReportFixture();
    scopeToCurrentMonth(fixture.snapshot, now: fixture.now);

    expect(fixture.snapshot.attendance, hasLength(4));
    expect(fixture.snapshot.behaviors, hasLength(4));
    expect(fixture.snapshot.notes, hasLength(3));
    expect(fixture.snapshot.grades, hasLength(3));
    expect(fixture.snapshot.gradeFields, hasLength(2));
  });

  test('حدود الفترة مغلقة من الطرفين', () {
    final period = MonthlyReportPeriod.current(DateTime(2026, 11, 21, 12));

    expect(period.contains(DateTime(2026, 11, 1)), isTrue);
    expect(period.contains(DateTime(2026, 10, 31, 23, 59)), isFalse);
    expect(period.contains(DateTime(2026, 11, 21, 12)), isTrue);
    expect(period.contains(DateTime(2026, 11, 21, 12, 1)), isFalse);
  });
}
