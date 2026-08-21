import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/notification_service.dart';
import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_scroll_behavior.dart';
import 'features/dashboard/presentation/app_shell.dart';
import 'features/students/presentation/student_details_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notificationService =
      NotificationService(FlutterLocalNotificationsPlugin());
  final navigatorKey = GlobalKey<NavigatorState>();
  String? pendingPayload;

  void openNotificationTarget(String? payload) {
    if (payload == null || !payload.startsWith('student:')) return;
    final studentUuid = payload.substring('student:'.length);
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      pendingPayload = payload;
      return;
    }
    navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => StudentDetailsPage(studentUuid: studentUuid),
      ),
    );
  }

  notificationService.onNotificationTap = openNotificationTarget;
  await notificationService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: AlMoktaberApp(navigatorKey: navigatorKey),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final payload = pendingPayload;
    pendingPayload = null;
    openNotificationTarget(payload);
  });
}

class AlMoktaberApp extends StatelessWidget {
  const AlMoktaberApp({required this.navigatorKey, super.key});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'سجل الطالب',
      theme: AppTheme.light(),
      scrollBehavior: defaultTargetPlatform == TargetPlatform.windows
          ? const AppScrollBehavior()
          : null,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AppShell(),
    );
  }
}
