import 'package:flutter_test/flutter_test.dart';

import 'package:almoktaber/core/services/workbook_names_reader.dart';

void main() {
  group('قراءة أسماء الطلاب من صفوف ورقة عمل', () {
    test('يقرأ عمود «الاسم الكامل» من ورقة تطبيق مُصدَّرة', () {
      final rows = <List<String>>[
        ['أسماء طلاب الصف الأول - أ', '', '', ''],
        ['قائمة أسماء الطلاب حسب الترتيب المعروض في التطبيق', '', '', ''],
        ['ت', 'الاسم الكامل', 'رقم الطالب', 'الصف'],
        ['1', 'زين علي', '001', 'الصف الأول'],
        ['2', 'أحمد كريم', '002', 'الصف الأول'],
        ['', '', '', ''],
        ['عدد الطلاب', '2', '', ''],
      ];

      expect(readStudentNamesFromSheet(rows), ['زين علي', 'أحمد كريم']);
    });

    test('لا يلتقط رقم التسلسل أو رقم الهاتف بدل الاسم', () {
      final rows = <List<String>>[
        ['ت', 'الاسم الكامل', 'هاتف ولي الأمر'],
        ['1', 'زين علي', '07801234567'],
        ['2', 'أحمد كريم', '07709876543'],
      ];

      final names = readStudentNamesFromSheet(rows);
      expect(names, ['زين علي', 'أحمد كريم']);
      expect(names.any((name) => RegExp(r'^[0-9]+$').hasMatch(name)), isFalse);
    });

    test('يتجاوز عمود التسلسل الرقمي عند غياب الترويسة', () {
      final rows = <List<String>>[
        ['1', 'زين علي'],
        ['2', 'أحمد كريم'],
      ];

      expect(readStudentNamesFromSheet(rows), ['زين علي', 'أحمد كريم']);
    });

    test('يقرأ العمود الأول في قائمة أسماء بسيطة ويزيل التكرار', () {
      final rows = <List<String>>[
        ['زين علي'],
        ['  أحمد   كريم '],
        ['أحمد كريم'],
        [''],
      ];

      expect(readStudentNamesFromSheet(rows), ['زين علي', 'أحمد كريم']);
    });

    test('يتعرف على عمود «الطالب» في ورقة الحضور', () {
      final rows = <List<String>>[
        ['تقرير الحضور والغياب', '', ''],
        ['الطالب', 'رقم الطالب', 'الحالة'],
        ['زين علي', '001', 'حاضر'],
      ];

      expect(readStudentNamesFromSheet(rows), ['زين علي']);
    });

    test('يعيد قائمة فارغة لورقة بلا بيانات', () {
      expect(readStudentNamesFromSheet(<List<String>>[]), isEmpty);
      expect(readStudentNamesFromSheet(<List<String>>[['', ''], ['', '']]), isEmpty);
    });
  });

  group('تحديد عمود الاسم من الترويسة', () {
    test('يفضّل عمود الاسم على «رقم الطالب»', () {
      expect(detectNameColumn(['ت', 'رقم الطالب', 'الاسم الكامل']), 2);
    });

    test('يتجاهل ترويسة «هاتف ولي الأمر»', () {
      expect(detectNameColumn(['هاتف ولي الأمر', 'رقم الطالب']), -1);
    });

    test('يدعم الترويسة الإنكليزية', () {
      expect(detectNameColumn(['No', 'Student Number', 'Full Name']), 2);
    });
  });

  group('تنظيف القيم', () {
    test('يستبعد الترويسات والعناوين والأرقام ويوحّد المسافات', () {
      final values = [
        'الاسم الكامل',
        'name',
        'أسماء طلاب الصف الأول - أ',
        'عدد الطلاب',
        'لا توجد سجلات',
        '07801234567',
        '١٢',
        '  زين    علي  ',
        'زين علي',
      ];

      expect(cleanStudentNames(values), ['زين علي']);
    });

    test('يزيل التكرار بين أوراق المصنّف ويحفظ ترتيب أول ظهور', () {
      final sheets = <List<List<String>>>[
        [
          ['الاسم الكامل'],
          ['زين علي'],
          ['أحمد كريم'],
        ],
        [
          ['الاسم الكامل'],
          ['أحمد كريم'],
          ['محمد حسن'],
        ],
      ];

      expect(readStudentNamesFromSheets(sheets), ['زين علي', 'أحمد كريم', 'محمد حسن']);
    });
  });
}
