import 'package:flutter/material.dart';
import 'package:todo/screens/scr_home.dart';
import 'package:todo/screens/scr_login.dart';
import 'package:todo/screens/scr_register.dart';
import 'package:todo/screens/authGate.dart';
import 'package:todo/widgets/light_only_theme.dart';

class AppNav {
  static Route _createFadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // 1. Tạo hiệu ứng trượt nhẹ từ dưới lên (chỉ trượt khoảng 10% màn hình)
        final slideAnimation =
            Tween<Offset>(
              begin: const Offset(0.0, 0.1), // Bắt đầu hơi thấp xuống một chút
              end: Offset.zero, // Kết thúc tại vị trí chuẩn
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves
                    .easeOutCubic, // Đường cong này giúp chuyển động mượt, nhanh lúc đầu và êm lúc cuối
              ),
            );

        // 2. Tạo hiệu ứng mờ dần
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeIn,
        );

        // 3. Kết hợp cả hai: Vừa trượt vừa mờ dần
        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(position: slideAnimation, child: child),
        );
      },
      // Thời gian 500ms - 600ms là khoảng thời gian "vàng" cho hiệu ứng này
      transitionDuration: const Duration(milliseconds: 500),
      // Thêm cái này để lúc nhấn Back nó cũng mượt tương tự
      reverseTransitionDuration: const Duration(milliseconds: 400),
    );
  }

  static void goToLogin(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      _createFadeRoute(const LightOnlyTheme(child: LoginScreen())),
      (route) => false,
    );
  }

  static void goToRegister(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      _createFadeRoute(const LightOnlyTheme(child: RegisterScreen())),
      (route) => false,
    );
  }

  static void goToHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      _createFadeRoute(const HomeScreen()),
      (route) => false,
    );
  }

  static void goToAuthGate(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      _createFadeRoute(const AuthGate()),
      (route) => false,
    );
  }
}
