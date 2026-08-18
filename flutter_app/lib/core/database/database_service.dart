import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'isar_models.dart';

class DatabaseService {
  Isar? _isar;

  Future<Isar> open() async {
    final existing = _isar;
    if (existing != null && existing.isOpen) return existing;

    final directory = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [
        AppSettingsSchema,
        SchoolClassSchema,
        SectionSchema,
        StudentSchema,
        AttendanceRecordSchema,
        GradeFieldSchema,
        GradeSchema,
        BehaviorRecordSchema,
        StudentNoteSchema,
        StudentImportRecordSchema,
      ],
      directory: directory.path,
      name: 'almoktaber',
      inspector: false,
    );
    return _isar!;
  }

  Future<void> close() async {
    final database = _isar;
    if (database != null && database.isOpen) {
      await database.close(deleteFromDisk: false);
    }
    _isar = null;
  }
}
