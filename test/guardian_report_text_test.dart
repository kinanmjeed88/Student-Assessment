import 'package:flutter_test/flutter_test.dart';

import 'package:almoktaber/core/services/guardian_report_text.dart';
import 'package:almoktaber/core/services/monthly_report_scope.dart';

import 'support/guardian_report_fixture.dart';

void main() {
  test('يعكس النص أرقام اللقطة الشهرية وصيغة الملف', () {
    final fixture = GuardianReportFixture();
    final monthly = scopeToCurrentMonth(fixture.snapshot, now: fixture.now);
    final text = buildGuardianReportText(
      settings: fixture.settings,
      student: fixture.student,
      monthly: monthly,
      format: GuardianReportFormat.pdf,
    );

    expect(text, contains(fixture.student.fullName));
    expect(text, contains('2026-11-01'));
    expect(text, contains('2026-11-21'));
    expect(text, contains('1 يوم غياب بدون عذر'));
    expect(text, contains('الدرجات: 1 تقييم'));
    expect(text, contains('السلوك: 5 نقطة'));
    expect(text, contains('الملاحظات: 1 ملاحظة'));
    expect(text, contains('مدرسة الاختبار'));
    expect(text, contains('رسالة مستقلة بصيغة PDF'));
  });

  test('يذكر Excel ولا يدعي أن الملف أُرسل', () {
    final fixture = GuardianReportFixture();
    final monthly = scopeToCurrentMonth(fixture.snapshot, now: fixture.now);
    final text = buildGuardianReportText(
      settings: fixture.settings,
      student: fixture.student,
      monthly: monthly,
      format: GuardianReportFormat.xlsx,
    );

    expect(GuardianReportFormat.xlsx.mimeType, contains('spreadsheet'));
    expect(text, contains('رسالة مستقلة بصيغة Excel'));
    expect(text, isNot(contains('تم إرسال')));
  });
}
