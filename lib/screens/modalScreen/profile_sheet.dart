import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:todo/controllers/project_Controller.dart';
import 'package:todo/controllers/task_Controller.dart';
import 'package:todo/core/app_notification_service.dart';
import 'package:todo/core/app_style.dart';
import 'package:todo/core/theme_controller.dart';
import 'package:todo/models/project.dart';
import 'package:todo/models/task.dart';
import 'package:todo/models/user.dart';
import 'package:todo/screens/modalScreen/friends_sheet.dart';
import 'package:todo/services/userService.dart';

class ProfileSheet extends StatefulWidget {
  const ProfileSheet({super.key});

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  final ProjectController _projectController = ProjectController();
  final TaskController _taskController = TaskController();
  late Future<UserModel?> _profileFuture;
  bool isSavingProfile = false;
  bool isConfiguringNotification = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<UserModel?> _loadProfile() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return null;

    final data = await UserService().getUser();
    if (data == null) return null;

    return UserModel.fromJson({...data, 'uid': authUser.uid});
  }

  Future<void> _editDisplayName(User authUser, UserModel? profile) async {
    final controller = TextEditingController(
      text: profile?.name.trim().isNotEmpty == true
          ? profile!.name.trim()
          : authUser.displayName ?? '',
    );

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cập nhật tên hiển thị'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Tên người dùng',
              hintText: 'Nhập tên của bạn',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                Navigator.pop(context, value);
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (newName == null || newName.trim().isEmpty) return;

    setState(() {
      isSavingProfile = true;
    });

    try {
      await UserService().updateDisplayName(newName);
      await authUser.updateDisplayName(newName);
      if (!mounted) return;

      setState(() {
        _profileFuture = _loadProfile();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật hồ sơ thành công')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không thể cập nhật hồ sơ')));
    } finally {
      if (mounted) {
        setState(() {
          isSavingProfile = false;
        });
      }
    }
  }

  Future<void> _showThemeModePicker() async {
    final currentMode = ThemeController.notifier.value;
    final selectedMode = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: const Text('Theo hệ thống'),
                value: ThemeMode.system,
                groupValue: currentMode,
                onChanged: (value) => Navigator.pop(context, value),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Sáng'),
                value: ThemeMode.light,
                groupValue: currentMode,
                onChanged: (value) => Navigator.pop(context, value),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Tối'),
                value: ThemeMode.dark,
                groupValue: currentMode,
                onChanged: (value) => Navigator.pop(context, value),
              ),
            ],
          ),
        );
      },
    );

    if (selectedMode == null) return;
    await ThemeController.setMode(selectedMode);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã cập nhật chế độ giao diện')),
    );
  }

  Future<void> _configureDeviceNotifications() async {
    if (isConfiguringNotification) return;

    setState(() {
      isConfiguringNotification = true;
    });

    try {
      final permissionGranted = await AppNotificationService.instance
          .configureCurrentUserDevice();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            permissionGranted
                ? 'Đã cấu hình thông báo thiết bị.'
                : 'Đã lưu thiết bị. Bạn có thể cần bật quyền thông báo trong cài đặt.',
          ),
        ),
      );

      final openBatterySettings = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Cài đặt thông báo thiết bị'),
            content: const Text(
              'Để nhận thông báo ổn định hơn khi ứng dụng chạy nền, bạn có thể cho phép ứng dụng không bị tối ưu pin. Tùy dòng máy, hệ thống vẫn có thể tự giới hạn ứng dụng nền.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Để sau'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Mở cài đặt pin'),
              ),
            ],
          );
        },
      );

      if (openBatterySettings == true) {
        await AppNotificationService.instance.openBatteryOptimizationSettings();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể cấu hình thông báo thiết bị: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isConfiguringNotification = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;

    if (authUser == null) {
      return _stateMessage(
        iconData: Icons.lock_outline,
        title: 'Bạn chưa đăng nhập',
        message: 'Vui lòng đăng nhập để xem hồ sơ cá nhân.',
      );
    }

    return FutureBuilder<UserModel?>(
      future: _profileFuture,
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        final isProfileLoading =
            profileSnapshot.connectionState == ConnectionState.waiting;

        return StreamBuilder<List<ProjectModel>>(
          stream: _projectController.getMyProjects(authUser.uid),
          builder: (context, projectSnapshot) {
            return StreamBuilder<List<TaskModel>>(
              stream: _taskController.getTasksByUser(authUser.uid),
              builder: (context, taskSnapshot) {
                final isStatsLoading =
                    projectSnapshot.connectionState ==
                        ConnectionState.waiting ||
                    taskSnapshot.connectionState == ConnectionState.waiting;
                final hasStatsError =
                    projectSnapshot.hasError || taskSnapshot.hasError;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _profileHeader(
                      authUser: authUser,
                      profile: profile,
                      isLoading: isProfileLoading,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _sectionTitle('Thống kê nhanh'),
                    const SizedBox(height: AppSpacing.sm),
                    if (isStatsLoading)
                      _loadingCard()
                    else if (hasStatsError)
                      _stateMessage(
                        iconData: Icons.error_outline,
                        title: 'Không thể tải thống kê',
                        message:
                            'Vui lòng thử lại sau hoặc kiểm tra quyền Firestore.',
                      )
                    else
                      _statsGrid(
                        projects: projectSnapshot.data ?? <ProjectModel>[],
                        tasks: taskSnapshot.data ?? <TaskModel>[],
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    _sectionTitle('Cài đặt chung'),
                    const SizedBox(height: AppSpacing.sm),
                    _settingsCard(),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _profileHeader({
    required User authUser,
    required UserModel? profile,
    required bool isLoading,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = profile?.name.trim().isNotEmpty == true
        ? profile!.name.trim()
        : authUser.displayName?.trim().isNotEmpty == true
        ? authUser.displayName!.trim()
        : 'Người dùng ToDo';
    final email = profile?.email.trim().isNotEmpty == true
        ? profile!.email.trim()
        : authUser.email ?? 'Chưa có email';
    final photoUrl = profile?.photoUrl.trim().isNotEmpty == true
        ? profile!.photoUrl.trim()
        : authUser.photoURL?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: colors.primary,
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null || photoUrl.isEmpty
                    ? Text(
                        _initial(authUser, profile),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoading ? 'Đang tải hồ sơ...' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onPrimaryContainer.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Chỉnh sửa tên',
                onPressed: isLoading || isSavingProfile
                    ? null
                    : () => _editDisplayName(authUser, profile),
                icon: isSavingProfile
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _profileChip(
                iconData: Icons.calendar_month_outlined,
                label: 'Tham gia ${_formatDate(profile?.createdAt)}',
              ),
              _profileChip(
                iconData: authUser.emailVerified
                    ? Icons.verified_outlined
                    : Icons.mark_email_unread_outlined,
                label: authUser.emailVerified
                    ? 'Email đã xác thực'
                    : 'Email chưa xác thực',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statsGrid({
    required List<ProjectModel> projects,
    required List<TaskModel> tasks,
  }) {
    final activeProjects = projects.where((project) => !project.isArchived);
    final archivedProjects = projects.where((project) => project.isArchived);
    final completedTasks = tasks.where(_isDone).length;
    final archivedTasks = tasks.where((task) => task.isArchived).length;
    final overdueTasks = tasks.where(_isOverdue).length;
    final completionRate = tasks.isEmpty
        ? 0
        : (completedTasks / tasks.length * 100).round();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.15,
      children: [
        _statCard(
          iconData: Icons.folder_open_outlined,
          title: 'Dự án đang quản lý',
          value: '${activeProjects.length}',
          color: AppColors.primary,
        ),
        _statCard(
          iconData: Icons.inventory_2_outlined,
          title: 'Dự án đã lưu trữ',
          value: '${archivedProjects.length}',
          color: AppColors.success,
        ),
        _statCard(
          iconData: Icons.assignment_outlined,
          title: 'Công việc được giao',
          value: '${tasks.length}',
          color: AppColors.info,
        ),
        _statCard(
          iconData: Icons.archive_outlined,
          title: 'Công việc đã lưu trữ',
          value: '$archivedTasks',
          color: AppColors.textSecondary,
        ),
        _statCard(
          iconData: Icons.check_circle_outline,
          title: 'Đã hoàn thành',
          value: '$completedTasks',
          color: AppColors.success,
        ),
        _statCard(
          iconData: Icons.warning_amber_rounded,
          title: 'Quá hạn',
          value: '$overdueTasks',
          color: AppColors.danger,
        ),
        _statCard(
          iconData: Icons.percent_rounded,
          title: 'Tỷ lệ hoàn thành',
          value: '$completionRate%',
          color: AppColors.warning,
        ),
      ],
    );
  }

  Widget _settingsCard() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? AppShadows.darkCard
            : AppShadows.card,
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(
              Icons.people_alt_outlined,
              color: AppColors.primary,
            ),
            title: const Text('Bạn bè'),
            subtitle: const Text('Xem bạn bè, lời mời đến và lời mời đã gửi.'),
            onTap: () => showFriendsSheet(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(
              Icons.notifications_active_outlined,
              color: AppColors.info,
            ),
            title: const Text('Thông báo thiết bị'),
            subtitle: const Text(
              'Xin quyền thông báo, lưu FCM token và mở cài đặt pin nếu cần.',
            ),
            trailing: isConfiguringNotification
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right_rounded),
            onTap: isConfiguringNotification
                ? null
                : _configureDeviceNotifications,
          ),
          const Divider(height: 1),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.notifier,
            builder: (context, mode, _) {
              return ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: const Text('Chế độ giao diện'),
                subtitle: Text(ThemeController.labelOf(mode)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _showThemeModePicker,
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
            title: const Text(
              'Đăng xuất',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
            onTap: () async {
              Navigator.of(context).pop();
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _profileChip({required IconData iconData, required String label}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 16, color: colors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }

  Widget _statCard({
    required IconData iconData,
    required String title,
    required String value,
    required Color color,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? AppShadows.darkCard
            : AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(iconData, color: color, size: 20),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _loadingCard() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _stateMessage({
    required IconData iconData,
    required String title,
    required String message,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(iconData, size: 34, color: colors.onSurfaceVariant),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  bool _isDone(TaskModel task) {
    return task.status.trim().toLowerCase() == 'done';
  }

  bool _isOverdue(TaskModel task) {
    if (_isDone(task) || task.isArchived) return false;
    final now = _dateOnly(DateTime.now());
    final deadline = _dateOnly(task.deadline);
    return now.isAfter(deadline);
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chưa có dữ liệu';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _initial(User? authUser, UserModel? profile) {
    final name = (profile?.name.trim().isNotEmpty ?? false)
        ? profile!.name.trim()
        : authUser?.displayName?.trim();
    final email = (profile?.email.trim().isNotEmpty ?? false)
        ? profile!.email.trim()
        : authUser?.email?.trim();
    final source = (name != null && name.isNotEmpty) ? name : email ?? '';
    if (source.isEmpty) return '?';
    return source.substring(0, 1).toUpperCase();
  }
}
