import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:todo/controllers/chat_Controller.dart';
import 'package:todo/controllers/notification_Controller.dart';
import 'package:todo/core/app_notification_service.dart';
import 'package:todo/core/app_style.dart';
import 'package:todo/screens/modalScreen/ai_assistant_sheet.dart';
import 'package:todo/screens/modalScreen/chat_list_sheet.dart';
import 'package:todo/screens/modalScreen/profile_sheet.dart';
import 'package:todo/screens/sub_screens/sub_CongViec.dart';
import 'package:todo/screens/sub_screens/sub_DuAn.dart';
import 'package:todo/screens/sub_screens/sub_ThongBao.dart';
import 'package:todo/screens/sub_screens/sub_ThongKe.dart';
import 'package:todo/widgets/ui.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int selectedIndex;
  Offset _tapPosition = Offset.zero;
  final chatController = ChatController();
  final notificationController = NotificationController();

  final Map<int, Widget> subScreens = const {
    0: Sub_DuAn_Screen(),
    1: Sub_CongViec_Screen(),
    2: Sub_ThongKe_Screen(),
    3: Sub_ThongBao_Screen(),
  };

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex.clamp(0, 3).toInt();
    AppNotificationService.instance.openNotificationsTabSignal.addListener(
      _handleOpenNotificationsTabSignal,
    );
    if (AppNotificationService.instance.consumeOpenNotificationsTabRequest()) {
      selectedIndex = 3;
    }
  }

  @override
  void dispose() {
    AppNotificationService.instance.openNotificationsTabSignal.removeListener(
      _handleOpenNotificationsTabSignal,
    );
    super.dispose();
  }

  void _handleOpenNotificationsTabSignal() {
    if (!AppNotificationService.instance.consumeOpenNotificationsTabRequest()) {
      return;
    }
    if (!mounted) return;
    setState(() {
      selectedIndex = 3;
    });
  }

  void _openProfile() {
    showAppModal(
      context: context,
      title: 'Hồ sơ cá nhân',
      initialSize: 0.82,
      minSize: 0.5,
      maxSize: 0.95,
      child: const ProfileSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL?.trim();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return screen(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: false,
      appBar: appBar(
        title: 'ToDo',
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        elevation: 2,
        borderRadius: 18,
        actions: [
          padding(
            right: 8,
            child: pressable(
              borderRadius: BorderRadius.circular(24),
              onTap: () => showAiAssistantSheet(context),
              child: containerBox(
                width: 40,
                height: 40,
                radius: BorderRadius.circular(20),
                color: colors.primaryContainer,
                child: Center(
                  child: Icon(Icons.auto_awesome, color: colors.primary),
                ),
              ),
            ),
          ),
          padding(
            right: 8,
            child: pressable(
              borderRadius: BorderRadius.circular(24),
              onTap: () => showChatListSheet(context),
              child: containerBox(
                width: 40,
                height: 40,
                radius: BorderRadius.circular(20),
                color: colors.surfaceContainerHighest,
                child: Center(child: _chatIcon(user?.uid)),
              ),
            ),
          ),
          padding(
            right: 15,
            child: pressable(
              child: avatar(
                imageUrl: photoUrl != null && photoUrl.isNotEmpty
                    ? photoUrl
                    : null,
                child: Icon(Icons.person, color: colors.onPrimaryContainer),
                backgroundColor: colors.primaryContainer,
              ),
              onTapDown: (details) {
                _tapPosition = details.globalPosition;
              },
              onTap: () {
                menu(
                  context: context,
                  tapPosition: _tapPosition,
                  options: [
                    MenuOption(
                      label: user?.displayName?.trim().isNotEmpty == true
                          ? user!.displayName!.trim()
                          : 'Hồ sơ cá nhân',
                      icon: Icons.account_circle_outlined,
                      onTap: _openProfile,
                    ),
                    MenuOption(
                      label: 'Đăng xuất',
                      icon: Icons.logout_rounded,
                      color: AppColors.danger,
                      onTap: () async {
                        await FirebaseAuth.instance.signOut();
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            return subScreens[selectedIndex] ??
                const Center(child: Text('Chưa hỗ trợ'));
          },
        ),
      ),
      bottomNav: bottomNav(
        currentIndex: selectedIndex,
        selectedColor: colors.primary,
        backgroundColor: colors.surface,
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: 'Dự án',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_rounded),
            label: 'Công việc',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Thống kê',
          ),
          BottomNavigationBarItem(
            icon: _notificationIcon(user?.uid),
            label: 'Thông báo',
          ),
        ],
      ),
    );
  }

  Widget _notificationIcon(String? uid) {
    final normalizedUid = uid?.trim();
    if (normalizedUid == null || normalizedUid.isEmpty) {
      return const Icon(Icons.notifications);
    }

    return StreamBuilder<int>(
      stream: notificationController.streamUnreadCount(normalizedUid),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return badge(
          label: count > 0 ? (count > 99 ? "99+" : "$count") : null,
          child: const Icon(Icons.notifications),
        );
      },
    );
  }

  Widget _chatIcon(String? uid) {
    final normalizedUid = uid?.trim();
    if (normalizedUid == null || normalizedUid.isEmpty) {
      return const Icon(Icons.forum_outlined);
    }

    return StreamBuilder<int>(
      stream: chatController.streamUnreadConversationCount(normalizedUid),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return badge(
          label: count > 0 ? (count > 99 ? "99+" : "$count") : null,
          child: const Icon(Icons.forum_outlined),
        );
      },
    );
  }
}
