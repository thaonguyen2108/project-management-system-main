import 'package:flutter/material.dart';
// import 'package:todo/screens/scr_login.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:todo/core/app_notification_service.dart';
import 'package:todo/core/app_style.dart';
import 'package:todo/core/pref_halper.dart';
import 'package:todo/core/theme_controller.dart';
import 'firebase_options.dart';
// import 'package:todo/screens/authGate.dart';
import 'package:todo/screens/scr_splash.dart';
import 'package:todo/widgets/light_only_theme.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[AppNotification] background FCM messageId=${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await PrefHelper.init();
  await ThemeController.load();
  await AppNotificationService.instance.init();

  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.notifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          home: const LightOnlyTheme(child: SplashScreen()),
        );
      },
    );
  }
}
