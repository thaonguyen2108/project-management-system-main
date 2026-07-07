import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:todo/screens/scr_login.dart';
import 'package:todo/screens/scr_home.dart';
import 'package:todo/widgets/light_only_theme.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        Widget currentScreen = const LightOnlyTheme(child: LoginScreen());

        // đang load (lúc app vừa mở)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // đã đăng nhập
        if (snapshot.hasData) {
          final user = snapshot.data;
          // Chỉ cho vào Home nếu đã verify email
          if (user != null && user.emailVerified) {
            currentScreen = const HomeScreen();
          }
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: child,
              ),
            );
          },
          child: currentScreen,
        );

        // chưa đăng nhập
        // return LoginScreen();
      },
    );
  }
}
