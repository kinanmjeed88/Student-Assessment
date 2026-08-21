/// Windows 7 build intentionally disables notifications.
///
/// The public API remains available so feature code can keep calling it safely,
/// while this target avoids Windows Toast APIs and old notification plugins.
class NotificationService {
  void Function(String? payload)? onNotificationTap;

  static int behaviorNotificationId(String studentUuid) {
    var hash = 17;
    for (final codeUnit in studentUuid.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return 100000 + (hash % 100000000);
  }

  Future<void> initialize() async {}

  Future<bool> requestNotificationPermission() async => false;

  Future<bool> requestPermissions() async => false;

  Future<void> showBehaviorAlert({
    required String studentUuid,
    required String title,
    required String body,
  }) async {}

  Future<void> scheduleFollowUp({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {}

  Future<void> cancel(int id) async {}

  Future<void> cancelAll() async {}
}
