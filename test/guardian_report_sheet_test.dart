import 'package:flutter_test/flutter_test.dart';

import 'package:almoktaber/features/students/presentation/guardian_report_sheet.dart';

void main() {
  test('يثبت عنواني البدء وخطوة إرسال الملف في الواجهة', () {
    expect(guardianReportStartLabel, 'إرسال التقرير والملف');
    expect(guardianReportFileStepTitle, 'إرسال ملف التقرير');
  });
}
