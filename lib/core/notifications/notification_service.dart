import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channel = AndroidNotificationChannel(
    'almoktaber_follow_up',
    'المتابعة والتنبيهات',
    description: 'تنبيهات الحضور والمتابعة في سجل الطالب.',
    importance: Importance.high,
  );

  static const _behaviorChannel = AndroidNotificationChannel(
    'student_behavior_alerts',
    'الإشعارات السلوكية',
    description: 'تنبيهات الطلاب الذين تجاوزوا حد التنبيه السلوكي.',
    importance: Importance.max,
  );

  static const _absenceChannel = AndroidNotificationChannel(
    'student_absence_alerts',
    'إشعارات الغياب',
    description: 'تنبيهات الطلاب الذين بلغوا حد الغياب المحدد في الإعدادات.',
    importance: Importance.max,
  );

  static const _windowsInitializationSettings =
      WindowsInitializationSettings(
    appName: 'سجل الطالب',
    appUserModelId: 'AlMoktaber.StudentRecord',
    guid: '7e2c3b7a-3d2c-4e0d-a3d9-0d2c5d2a6b31',
  );

  void Function(String? payload)? onNotificationTap;

  /// معرّف ثابت لإشعار السلوك يعتمد على معرّف الطالب.
  static int behaviorNotificationId(String studentUuid) =>
      _studentNotificationId(studentUuid, 100000);

  /// معرّف ثابت لإشعار الغياب يعتمد على معرّف الطالب.
  ///
  /// يختلف المجال عن إشعار السلوك حتى لا يستبدل إشعارُ غياب إشعارَ سلوك لنفس
  /// الطالب، وحتى يمكن إلغاؤهما بشكل مستقل.
  static int absenceNotificationId(String studentUuid) =>
      _studentNotificationId(studentUuid, 200000);

  static int _studentNotificationId(String studentUuid, int offset) {
    var hash = 17;
    for (final codeUnit in studentUuid.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return offset + (hash % 100000000);
  }

  Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      windows: _windowsInitializationSettings,
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
    await android?.createNotificationChannel(_behaviorChannel);
    await android?.createNotificationChannel(_absenceChannel);
  }

  Future<bool> requestNotificationPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<bool> requestPermissions() async {
    final notifications = await requestNotificationPermission();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
    return notifications;
  }

  /// يعرض إشعاراً فورياً للطالب عند بلوغه حد التنبيه السلوكي أو حد الفصل.
  Future<void> showBehaviorAlert({
    required String studentUuid,
    required String title,
    required String body,
  }) =>
      _showStudentAlert(
        notificationId: behaviorNotificationId(studentUuid),
        channel: _behaviorChannel,
        studentUuid: studentUuid,
        title: title,
        body: body,
      );

  /// يعرض إشعاراً فورياً للطالب عند بلوغه حد التنبيه بالغياب أو حد الفصل.
  Future<void> showAbsenceAlert({
    required String studentUuid,
    required String title,
    required String body,
  }) =>
      _showStudentAlert(
        notificationId: absenceNotificationId(studentUuid),
        channel: _absenceChannel,
        studentUuid: studentUuid,
        title: title,
        body: body,
      );

  Future<void> _showStudentAlert({
    required int notificationId,
    required AndroidNotificationChannel channel,
    required String studentUuid,
    required String title,
    required String body,
  }) async {
    if (!await requestNotificationPermission()) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        playSound: true,
        enableVibration: true,
      ),
      windows: const WindowsNotificationDetails(
        duration: WindowsNotificationDuration.long,
        scenario: WindowsNotificationScenario.reminder,
      ),
    );
    await _plugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: 'student:$studentUuid',
    );
  }

  Future<void> scheduleFollowUp({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
      windows: const WindowsNotificationDetails(
        duration: WindowsNotificationDuration.long,
        scenario: WindowsNotificationScenario.reminder,
      ),
    );
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id: id);

  Future<void> cancelAll() => _plugin.cancelAll();

  void _onNotificationResponse(NotificationResponse response) {
    onNotificationTap?.call(response.payload);
  }
}
