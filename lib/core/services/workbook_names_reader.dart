/// قراءة أسماء الطلاب من صفوف أوراق العمل بعد فك ترميزها إلى نصوص.
///
/// تعمل هذه الأدوات على نصوص مجردة (قوائم صفوف) بدل بايتات الملف، حتى تبقى
/// مستقلة عن حزمة Excel المستخدمة في كل فرع: الحزمة الحديثة في الفرع
/// الرئيسي وفرع وندوز ١٠/١١، والحزمة الأقدم في فرع وندوز ٧. هكذا يعمل
/// المنطق نفسه والاختبارات نفسها على الفروع الثلاثة دون أي تعديل.
///
/// سبب وجودها أن ملفات التصدير العربية تُكتب بترتيب منطقي يبدأ بعمود
/// التسلسل «ت» ثم «الاسم الكامل»، بينما كان القارئ القديم يلتقط أول خلية غير
/// فارغة في كل صف، فيقرأ رقم الهاتف أو رقم التسلسل أو عنوان الورقة بدل الاسم
/// عند استيراد ملف أسماء مُصدَّر من التطبيق نفسه.
library;

/// ترويسات عمود الاسم المحتملة مرتبة حسب الأولوية: الأقوى دلالة أولاً حتى لا
/// يسبق «رقم الطالب» أو «الطالب» عمودَ الاسم الصريح في ورقة التقارير.
const List<String> kNameHeaderCandidates = <String>[
  'الاسم الكامل',
  'الاسم الثلاثي',
  'اسم الطالب',
  'اسم الطالبة',
  'الاسم',
  'full name',
  'student name',
  'name',
  'الطالب',
  'student',
];

/// كلمات تدل على أن الترويسة المطابقة ليست عمود اسم وإن وردت فيها كلمة من
/// [kNameHeaderCandidates]، مثل «رقم الطالب» أو «هاتف ولي الأمر».
const List<String> kNonNameHeaderMarkers = <String>[
  'رقم',
  'هاتف',
  'number',
  'phone',
];

/// قيم تُستبعد من نتائج القراءة: ترويسات وعناوين وأسطر إجماليات في ملفات
/// التصدير، أو أرقام تسلسل وأرقام هواتف تُلتقط من عمود خاطئ.
const List<String> kIgnoredNameMarkers = <String>[
  'الاسم',
  'اسم الطالب',
  'full name',
  'student name',
  'name',
  'الطلاب',
  'أسماء طلاب',
  'اسماء طلاب',
  'قائمة أسماء',
  'قائمة اسماء',
  'لا توجد سجلات',
  'عدد الطلاب',
  'عدد السجلات',
  'تقرير',
];

/// أرقام فقط (تسلسل أو هاتف) بأشكالها اللاتينية والعربية.
final RegExp _digitsOnly = RegExp(r'^[0-9٠-٩۰-۹][0-9٠-٩۰-۹+ -]*$');

/// يقرأ أسماء الطلاب من عدة أوراق عمل ويزيل التكرار بينها.
///
/// كل ورقة تُقرأ وتُنقّى على حدة عبر [readStudentNamesFromSheet]، ثم تُنقّى
/// النتيجة المجمعة مرة أخرى لإزالة الأسماء المكررة بين الأوراق، لأن تقارير
/// التطبيق تحتوي ورقة «الكل» إضافة إلى ورقة لكل صف دراسي.
///
/// [sheets] كل ورقة منها قائمة صفوف، وكل صف قائمة قيم نصية.
List<String> readStudentNamesFromSheets(Iterable<Iterable<Iterable<String>>> sheets) {
  final collected = <String>[];
  for (final sheet in sheets) {
    collected.addAll(readStudentNamesFromSheet(sheet));
  }
  return cleanStudentNames(collected);
}

/// يقرأ أسماء الطلاب من ورقة عمل واحدة ويعيدهم منقّين.
///
/// إذا احتوت الورقة على صف ترويسة فيه عمود اسم معروف تُقرأ الأسماء من ذلك
/// العمود ومن الصفوف التي تليه فقط، فتُتجاهل أسطر العنوان والوصف المدمجة في
/// أعلى الورقة وسطر الإجمالي في أسفلها. وإذا لم توجد ترويسة يُقرأ أول عمود
/// ينتج قيماً تصلح أسماءً، حتى تتجاوز القراءة عمود تسلسل أو هاتفاً في ملف
/// أعده المعلم يدوياً بلا ترويسة.
///
/// تُطبَّق [cleanStudentNames] على النتيجة، فتعود الدالة بأسماء جاهزة دون
/// ترويسات أو أرقام أو تكرار أو مسافات زائدة.
List<String> readStudentNamesFromSheet(Iterable<Iterable<String>> rows) {
  final sheetRows = <List<String>>[];
  for (final row in rows) {
    final cells = <String>[];
    for (final cell in row) {
      cells.add(cell.trim());
    }
    sheetRows.add(cells);
  }
  if (sheetRows.isEmpty) return const <String>[];

  var headerRowIndex = -1;
  var nameColumnIndex = 0;
  for (var index = 0; index < sheetRows.length; index++) {
    final detected = detectNameColumn(sheetRows[index]);
    if (detected >= 0) {
      headerRowIndex = index;
      nameColumnIndex = detected;
      break;
    }
  }
  if (headerRowIndex < 0) nameColumnIndex = firstUsableNameColumn(sheetRows);

  final names = <String>[];
  final firstRowIndex = headerRowIndex < 0 ? 0 : headerRowIndex + 1;
  for (var index = firstRowIndex; index < sheetRows.length; index++) {
    final row = sheetRows[index];
    if (row.every((cell) => cell.isEmpty)) continue;
    if (nameColumnIndex >= row.length) continue;
    names.add(row[nameColumnIndex]);
  }
  return cleanStudentNames(names);
}

/// يعيد رقم العمود الذي يحمل ترويسة اسم في [row]، أو `-1` إن لم يوجد.
int detectNameColumn(List<String> row) {
  for (final candidate in kNameHeaderCandidates) {
    for (var index = 0; index < row.length; index++) {
      final cell = row[index].trim().toLowerCase();
      if (cell.isEmpty) continue;
      if (!cell.contains(candidate)) continue;
      if (_matchesAny(cell, kNonNameHeaderMarkers)) continue;
      return index;
    }
  }
  return -1;
}

/// يعيد رقم أول عمود في [sheetRows] يحتوي قيمة تصلح اسماً، أو صفر إن لم يوجد.
int firstUsableNameColumn(List<List<String>> sheetRows) {
  var widest = 0;
  for (final row in sheetRows) {
    if (row.length > widest) widest = row.length;
  }
  for (var column = 0; column < widest; column++) {
    for (final row in sheetRows) {
      if (column >= row.length) continue;
      final value = row[column].trim();
      if (value.isEmpty) continue;
      if (isIgnoredStudentNameValue(value)) continue;
      return column;
    }
  }
  return 0;
}

/// ينظّف قائمة قيم: يوحّد المسافات، ويستبعد الترويسات والعناوين والأرقام،
/// ويزيل التكرار مع الحفاظ على ترتيب أول ظهور لكل اسم.
List<String> cleanStudentNames(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) continue;
    if (isIgnoredStudentNameValue(normalized)) continue;
    if (seen.add(normalized.toLowerCase())) result.add(normalized);
  }
  return result;
}

/// يقرر هل القيمة ترويسة أو عنوان أو رقم وليست اسم طالب.
bool isIgnoredStudentNameValue(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  if (_digitsOnly.hasMatch(normalized)) return true;
  return _matchesAny(normalized, kIgnoredNameMarkers);
}

bool _matchesAny(String value, List<String> markers) {
  for (final marker in markers) {
    if (value.contains(marker)) return true;
  }
  return false;
}
