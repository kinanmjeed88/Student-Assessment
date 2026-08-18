import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channel = AndroidNotificationChannel(
    'almoktaber_follow_up',
    'المتابعة والتنبيهات',
    description: 'تنبيهات الحضور والمتابعة السلوكية في حليف القرآن.',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
  }

  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final notifications = await android?.requestNotificationsPermission() ?? true;
    await android?.requestExactAlarmsPermission();
    return notifications;
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
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();

  void _onNotificationResponse(NotificationResponse response) {
    // يتم تمرير payload إلى Router في طبقة التنسيق عند إضافة Workflow فعلي.
  }
}
