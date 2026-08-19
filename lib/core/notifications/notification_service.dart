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

  void Function(String? payload)? onNotificationTap;

  static int behaviorNotificationId(String studentUuid) {
    var hash = 17;
    for (final codeUnit in studentUuid.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return 100000 + (hash % 100000000);
  }

  Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
    await android?.createNotificationChannel(_behaviorChannel);
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

  Future<void> showBehaviorAlert({
    required String studentUuid,
    required String title,
    required String body,
  }) async {
    if (!await requestNotificationPermission()) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _behaviorChannel.id,
        _behaviorChannel.name,
        channelDescription: _behaviorChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        playSound: true,
        enableVibration: true,
      ),
    );
    await _plugin.show(
      behaviorNotificationId(studentUuid),
      title,
      body,
      details,
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
    );
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledAt, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();

  void _onNotificationResponse(NotificationResponse response) {
    onNotificationTap?.call(response.payload);
  }
}
