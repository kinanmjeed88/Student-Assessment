import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/app_snapshot.dart';
import 'database/database_service.dart';
import 'database/local_repository.dart';
import 'database/local_store.dart';
import 'database/isar_models.dart';
import 'notifications/notification_service.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final service = DatabaseService();
  ref.onDispose(service.close);
  return service;
});

final localRepositoryProvider = Provider<LocalStore>((ref) {
  return LocalRepository(ref.watch(databaseServiceProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(FlutterLocalNotificationsPlugin());
});

final appControllerProvider =
    AsyncNotifierProvider<AppController, AppSnapshot>(AppController.new);

class AppController extends AsyncNotifier<AppSnapshot> {
  LocalStore get _repository => ref.read(localRepositoryProvider);

  @override
  Future<AppSnapshot> build() => _repository.loadSnapshot();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.loadSnapshot);
  }

  Future<void> addClass(String name) async {
    if (name.trim().isEmpty) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.createClass(name: name);
      return _repository.loadSnapshot();
    });
  }

  Future<void> addStudent({
    required String firstName,
    required String lastName,
    required String classUuid,
    String studentNumber = '',
  }) async {
    if (firstName.trim().isEmpty ||
        lastName.trim().isEmpty ||
        classUuid.isEmpty) {
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.createStudent(
        firstName: firstName,
        lastName: lastName,
        classUuid: classUuid,
        studentNumber: studentNumber,
      );
      return _repository.loadSnapshot();
    });
  }

  Future<void> restoreBackup(String json) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.restoreBackupJson(json);
      return _repository.loadSnapshot();
    });
  }

  Future<void> saveSettings({
    required String schoolName,
    required String teacherName,
    required String academicYear,
    required String stage,
  }) async {
    await _repository.updateSettings(
      schoolName: schoolName,
      teacherName: teacherName,
      academicYear: academicYear,
      stage: stage,
    );
    await refresh();
  }

  Future<void> setAttendance({
    required String studentUuid,
    required DateTime date,
    required AttendanceStatus status,
  }) async {
    await _repository.setAttendance(
      studentUuid: studentUuid,
      date: date,
      status: status,
    );
    await refresh();
  }

  Future<void> deleteClass(String classUuid) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteClassCascade(classUuid);
      return _repository.loadSnapshot();
    });
  }

  Future<void> deleteStudent(String studentUuid) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteStudentCascade(studentUuid);
      return _repository.loadSnapshot();
    });
  }
}
