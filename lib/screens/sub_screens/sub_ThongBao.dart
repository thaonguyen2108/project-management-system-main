import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:todo/controllers/chat_Controller.dart';
import 'package:todo/controllers/notification_Controller.dart';
import 'package:todo/controllers/project_Controller.dart';
import 'package:todo/controllers/task_Controller.dart';
import 'package:todo/core/app_style.dart';
import 'package:todo/core/pref_halper.dart';
import 'package:todo/models/notification.dart';
import 'package:todo/models/project.dart';
import 'package:todo/models/task.dart';
import 'package:todo/screens/modalScreen/chat_room_sheet.dart';
import 'package:todo/screens/modalScreen/projectForm.dart';
import 'package:todo/screens/modalScreen/user_profile_sheet.dart';
import 'package:todo/widgets/ui.dart';

class Sub_ThongBao_Screen extends StatefulWidget {
  const Sub_ThongBao_Screen({super.key});

  @override
  State<Sub_ThongBao_Screen> createState() => _Sub_ThongBao_ScreenState();
}

class _Sub_ThongBao_ScreenState extends State<Sub_ThongBao_Screen> {
  final chatController = ChatController();
  final notificationController = NotificationController();
  final projectController = ProjectController();
  final taskController = TaskController();

  final List<String> filters = const [
    "Tất cả",
    "Chưa đọc",
    "Đã đọc",
    "Nhắc hạn",
    "Công việc",
    "Dự án",
    "Bạn bè",
    "Tin nhắn",
  ];
  String selectedFilter = "Tất cả";

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final savedFilter = PrefHelper.getUiPreference(
      uid,
      'notification_filter',
      selectedFilter,
    );
    if (filters.contains(savedFilter)) selectedFilter = savedFilter;
  }

  bool _isDone(TaskModel task) => task.status.trim().toLowerCase() == "done";

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isOverdue(TaskModel task) {
    return !_isDone(task) &&
        !task.isArchived &&
        _dateOnly(DateTime.now()).isAfter(_dateOnly(task.deadline));
  }

  bool _isDueSoon(TaskModel task) {
    if (_isDone(task) || task.isArchived) return false;
    final deadline = _dateOnly(task.deadline);
    final daysLeft = deadline.difference(_dateOnly(DateTime.now())).inDays;
    return daysLeft >= 0 && daysLeft <= 3;
  }

  List<_NotificationItem> _buildItems({
    required List<NotificationModel> notifications,
    required List<TaskModel> tasks,
  }) {
    final items = <_NotificationItem>[
      for (final notification in notifications)
        _NotificationItem.persistent(notification),
      for (final task in tasks.where(
        (task) => _isDueSoon(task) || _isOverdue(task),
      ))
        _NotificationItem.reminder(task),
    ];

    final filtered = items.where(_matchesSelectedFilter).toList();
    filtered.sort((a, b) => b.sortTime.compareTo(a.sortTime));
    return filtered;
  }

  bool _matchesSelectedFilter(_NotificationItem item) {
    switch (selectedFilter) {
      case "Chưa đọc":
        return !item.isReminder && !(item.notification?.isRead ?? true);
      case "Đã đọc":
        return !item.isReminder && (item.notification?.isRead ?? false);
      case "Nhắc hạn":
        return item.isReminder;
      case "Công việc":
        return item.targetType == "task";
      case "Dự án":
        return item.targetType == "project";
      case "Bạn bè":
        return item.targetType == "user" ||
            item.targetType == "friend_request" ||
            item.type == "friend_request" ||
            item.type == "friend_request_accepted";
      case "Tin nhắn":
        return item.targetType == "conversation" || item.type == "chat_message";
      case "Tất cả":
      default:
        return true;
    }
  }

  Future<void> _markAllAsRead(String uid) async {
    final error = await notificationController.markAllAsRead(uid);
    if (!mounted) return;

    snack(
      context,
      message: error == null
          ? "Đã đánh dấu tất cả thông báo là đã đọc"
          : "Không thể đánh dấu tất cả thông báo",
      backgroundColor: error == null ? AppColors.primary : AppColors.danger,
    );
  }

  Future<void> _softDelete(NotificationModel notification) async {
    final error = await notificationController.softDelete(notification.id);
    if (!mounted) return;

    snack(
      context,
      message: error == null ? "Đã xóa thông báo" : "Không thể xóa thông báo",
      backgroundColor: error == null ? AppColors.primary : AppColors.danger,
    );
  }

  void _confirmDelete(NotificationModel notification) {
    dialog(
      context,
      title: "Xóa thông báo",
      message: "Thông báo sẽ được ẩn khỏi danh sách của bạn.",
      okText: "Xóa",
      okColor: AppColors.danger,
      onOk: () => _softDelete(notification),
    );
  }

  Future<void> _handleTap(_NotificationItem item) async {
    if (item.isReminder && item.task != null) {
      _showTaskDetail(item.task!, sourceLabel: "Nhắc hạn");
      return;
    }

    final notification = item.notification;
    if (notification == null) return;

    if (!notification.isRead) {
      await notificationController.markAsRead(notification.id);
    }

    if (!mounted) return;

    final targetType = notification.targetType.trim();
    if (targetType == "task") {
      await _openTaskTarget(notification);
      return;
    }

    if (targetType == "project") {
      await _openProjectTarget(notification);
      return;
    }

    if (targetType == "user") {
      _openUserTarget(notification);
      return;
    }

    if (targetType == "friend_request") {
      _openFriendRequestTarget(notification);
      return;
    }

    if (targetType == "conversation") {
      await _openConversationTarget(notification);
      return;
    }

    _showNotificationInfo(notification);
  }

  Future<void> _openTaskTarget(NotificationModel notification) async {
    final taskId = notification.taskId ?? notification.targetId;
    if (taskId == null || taskId.trim().isEmpty) {
      _showNotificationInfo(notification);
      return;
    }

    try {
      final task = await taskController.getTaskById(taskId);
      if (!mounted) return;

      if (task == null) {
        snack(
          context,
          message: "Không thể mở công việc này.",
          backgroundColor: AppColors.danger,
        );
        return;
      }

      _showTaskDetail(task, sourceLabel: _typeLabel(notification.type));
    } on FirebaseException catch (error) {
      if (!mounted) return;
      snack(
        context,
        message: error.code == "permission-denied"
            ? "Bạn không có quyền xem công việc này."
            : "Không thể mở công việc này.",
        backgroundColor: AppColors.danger,
      );
    } catch (_) {
      if (!mounted) return;
      snack(
        context,
        message: "Không thể mở công việc này.",
        backgroundColor: AppColors.danger,
      );
    }
  }

  Future<void> _openProjectTarget(NotificationModel notification) async {
    final projectId = notification.projectId ?? notification.targetId;
    if (projectId == null || projectId.trim().isEmpty) {
      _showNotificationInfo(notification);
      return;
    }

    try {
      final project = await projectController.getProjectById(projectId);
      if (!mounted) return;

      if (project == null) {
        snack(
          context,
          message: "Không thể mở dự án này.",
          backgroundColor: AppColors.danger,
        );
        return;
      }

      _showProjectDetail(project);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      snack(
        context,
        message: error.code == "permission-denied"
            ? "Bạn không có quyền xem dự án này."
            : "Không thể mở dự án này.",
        backgroundColor: AppColors.danger,
      );
    } catch (_) {
      if (!mounted) return;
      snack(
        context,
        message: "Không thể mở dự án này.",
        backgroundColor: AppColors.danger,
      );
    }
  }

  void _showProjectDetail(ProjectModel project) {
    showAppModal(
      context: context,
      title: project.isArchived ? "Dự án đã lưu trữ" : "Chi tiết dự án",
      initialSize: 0.82,
      minSize: 0.5,
      maxSize: 0.95,
      child: FormDuAn(project: project),
      listButtons: padding(
        right: 10,
        top: 10,
        bottom: 10,
        child: align(
          alignment: Alignment.bottomRight,
          child: button(
            label: "Đóng",
            onPressed: () => Navigator.pop(context),
            color: AppColors.surfaceMuted,
          ),
        ),
      ),
    );
  }

  void _openUserTarget(NotificationModel notification) {
    final userId = notification.targetId ?? notification.actorId;
    if (userId == null || userId.trim().isEmpty) {
      _showNotificationInfo(notification);
      return;
    }

    showUserProfileSheet(context, userId: userId.trim());
  }

  void _openFriendRequestTarget(NotificationModel notification) {
    final senderId = notification.actorId;
    if (senderId == null || senderId.trim().isEmpty) {
      _showNotificationInfo(notification);
      return;
    }

    showUserProfileSheet(context, userId: senderId.trim());
  }

  Future<void> _openConversationTarget(NotificationModel notification) async {
    final conversationId = notification.targetId;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (conversationId == null ||
        conversationId.trim().isEmpty ||
        currentUid == null ||
        currentUid.trim().isEmpty) {
      _showNotificationInfo(notification);
      return;
    }

    try {
      final conversation = await chatController.getConversationById(
        conversationId,
      );
      if (!mounted) return;
      if (conversation == null ||
          !conversation.memberIds.contains(currentUid.trim())) {
        snack(
          context,
          message: "Không thể mở cuộc trò chuyện này.",
          backgroundColor: AppColors.danger,
        );
        return;
      }

      final otherUser = await chatController.getOtherMember(
        conversation: conversation,
        currentUid: currentUid,
      );
      if (!mounted) return;
      if (otherUser == null) {
        snack(
          context,
          message: "Không thể tải người dùng trong cuộc trò chuyện.",
          backgroundColor: AppColors.danger,
        );
        return;
      }

      showChatRoomSheet(
        context,
        conversation: conversation,
        otherUser: otherUser,
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      snack(
        context,
        message: error.code == "permission-denied"
            ? "Bạn không có quyền xem cuộc trò chuyện này."
            : "Không thể mở cuộc trò chuyện này.",
        backgroundColor: AppColors.danger,
      );
    } catch (_) {
      if (!mounted) return;
      snack(
        context,
        message: "Không thể mở cuộc trò chuyện này.",
        backgroundColor: AppColors.danger,
      );
    }
  }

  void _showNotificationInfo(NotificationModel notification) {
    showAppModal(
      context: context,
      title: "Chi tiết thông báo",
      initialSize: 0.42,
      child: column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          text(notification.title, size: 18, weight: FontWeight.bold),
          box(height: 10),
          text(
            notification.body,
            size: 14,
            color: AppColors.textSecondary,
            maxLines: 8,
          ),
          box(height: 12),
          _detailRow(
            iconData: Icons.label_outline,
            label: "Loại",
            value: _typeLabel(notification.type),
          ),
          box(height: 8),
          _detailRow(
            iconData: Icons.schedule,
            label: "Thời gian",
            value: _formatDateTime(notification.createdAt),
          ),
        ],
      ),
    );
  }

  void _showTaskDetail(TaskModel task, {required String sourceLabel}) {
    final statusColor = _statusColor(task);

    showAppModal(
      context: context,
      title: "Chi tiết công việc",
      initialSize: 0.58,
      child: column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          text(task.title, size: 18, weight: FontWeight.bold, maxLines: 2),
          box(height: 10),
          text(
            task.description.isEmpty ? "Không có mô tả" : task.description,
            size: 14,
            maxLines: 8,
            color: AppColors.textSecondary,
          ),
          box(height: 14),
          _detailRow(
            iconData: Icons.calendar_month,
            label: "Deadline",
            value: DateFormat('dd/MM/yyyy').format(task.deadline),
          ),
          box(height: 8),
          _detailRow(
            iconData: Icons.flag_outlined,
            label: "Trạng thái",
            value: _statusLabel(task),
            valueColor: statusColor,
          ),
          box(height: 8),
          _detailRow(
            iconData: Icons.priority_high_rounded,
            label: "Độ ưu tiên",
            value: _priorityLabel(task.priority),
          ),
          box(height: 12),
          containerBox(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            radius: BorderRadius.circular(AppRadius.md),
            color: AppColors.primarySoft,
            child: text(
              "Nguồn: $sourceLabel. Chi tiết này chỉ dùng để xem nhanh từ thông báo.",
              maxLines: 4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow({
    required IconData iconData,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return row(
      children: [
        icon(iconData, size: 18, color: AppColors.textSecondary),
        box(width: 8),
        text("$label: ", weight: FontWeight.bold),
        flexible(
          child: text(
            value,
            color: valueColor ?? AppColors.textPrimary,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  String _statusLabel(TaskModel task) {
    if (task.isArchived) return "Đã lưu trữ";
    if (_isDone(task)) return "Đã hoàn thành";
    if (_isOverdue(task)) return "Quá hạn";
    if (_isDueSoon(task)) return "Sắp đến hạn";
    return "Chưa hoàn thành";
  }

  Color _statusColor(TaskModel task) {
    if (task.isArchived) return AppColors.textSecondary;
    if (_isDone(task)) return AppColors.success;
    if (_isOverdue(task)) return AppColors.danger;
    if (_isDueSoon(task)) return AppColors.warning;
    return AppColors.primary;
  }

  String _priorityLabel(int priority) {
    if (priority >= 3) return "Ưu tiên cao";
    if (priority == 2) return "Ưu tiên vừa";
    return "Ưu tiên thấp";
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return "Vừa xong";
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _typeLabel(String type) {
    switch (type) {
      case "task_assigned":
        return "Giao việc";
      case "task_updated":
        return "Cập nhật công việc";
      case "task_done":
        return "Hoàn thành công việc";
      case "task_due_soon":
        return "Sắp đến hạn";
      case "task_overdue":
        return "Quá hạn";
      case "project_archived":
        return "Lưu trữ dự án";
      case "project_unarchived":
        return "Khôi phục dự án";
      case "friend_request":
        return "Lời mời kết bạn";
      case "friend_request_accepted":
        return "Kết bạn";
      case "chat_message":
        return "Tin nhắn";
      default:
        return "Thông báo";
    }
  }

  IconData _typeIcon(_NotificationItem item) {
    final type = item.type;
    if (item.isReminder && item.task != null && _isOverdue(item.task!)) {
      return Icons.warning_amber_rounded;
    }

    switch (type) {
      case "task_assigned":
        return Icons.assignment_ind_outlined;
      case "task_updated":
        return Icons.edit_note_outlined;
      case "task_done":
        return Icons.check_circle_outline;
      case "task_due_soon":
        return Icons.timelapse;
      case "task_overdue":
        return Icons.warning_amber_rounded;
      case "project_archived":
        return Icons.archive_outlined;
      case "project_unarchived":
        return Icons.unarchive_outlined;
      case "friend_request":
        return Icons.person_add_alt_1_outlined;
      case "friend_request_accepted":
        return Icons.people_alt_outlined;
      case "chat_message":
        return Icons.forum_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _typeColor(_NotificationItem item) {
    final type = item.type;
    if (item.isReminder && item.task != null && _isOverdue(item.task!)) {
      return AppColors.danger;
    }

    switch (type) {
      case "task_done":
        return AppColors.success;
      case "task_due_soon":
      case "task_overdue":
        return type == "task_overdue" ? AppColors.danger : AppColors.warning;
      case "project_archived":
      case "project_unarchived":
        return AppColors.textSecondary;
      case "friend_request":
      case "friend_request_accepted":
        return AppColors.info;
      case "chat_message":
        return AppColors.primary;
      default:
        return AppColors.primary;
    }
  }

  Widget _notificationCard(_NotificationItem item) {
    final notification = item.notification;
    final isUnread = notification != null && !notification.isRead;
    final color = _typeColor(item);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return pressable(
      onTap: () => _handleTap(item),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        color: isUnread
            ? (isDark
                  ? colors.primaryContainer.withValues(alpha: 0.24)
                  : AppColors.primarySoft)
            : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: isUnread
                ? colors.primary.withValues(alpha: 0.28)
                : colors.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              containerBox(
                width: 40,
                height: 40,
                radius: BorderRadius.circular(AppRadius.md),
                color: color.withValues(alpha: 0.12),
                child: icon(_typeIcon(item), size: 21, color: color),
              ),
              box(width: 12),
              flexible(
                child: column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        flexible(
                          child: text(
                            item.title,
                            weight: FontWeight.bold,
                            size: 16,
                            color: colors.onSurface,
                            maxLines: 2,
                            align: TextAlign.left,
                          ),
                        ),
                        if (isUnread) ...[
                          box(width: 8),
                          containerBox(
                            color: AppColors.danger,
                            width: 9,
                            height: 9,
                            radius: BorderRadius.circular(5),
                          ),
                        ],
                      ],
                    ),
                    box(height: 5),
                    text(
                      item.body,
                      size: 14,
                      maxLines: 2,
                      color: colors.onSurfaceVariant,
                      align: TextAlign.left,
                    ),
                    box(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _chip(
                          label: item.isReminder
                              ? "Nhắc hạn"
                              : _typeLabel(item.type),
                          color: color,
                        ),
                        text(
                          item.timeLabel,
                          size: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (notification != null)
                IconButton(
                  tooltip: "Xóa thông báo",
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmDelete(notification),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip({required String label, required Color color}) {
    return containerBox(
      color: color.withValues(alpha: 0.12),
      radius: BorderRadius.circular(AppRadius.sm),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: text(label, color: color, size: 12, weight: FontWeight.bold),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (currentUser == null) {
      return screen(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const _StateMessage(
          iconData: Icons.lock_outline,
          title: "Bạn chưa đăng nhập",
          message: "Vui lòng đăng nhập để xem thông báo.",
        ),
      );
    }

    return StreamBuilder<List<NotificationModel>>(
      stream: notificationController.streamNotifications(currentUser.uid),
      builder: (context, notificationSnapshot) {
        if (notificationSnapshot.connectionState == ConnectionState.waiting &&
            !notificationSnapshot.hasData) {
          return screen(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: loading(),
          );
        }

        if (notificationSnapshot.hasError) {
          return screen(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: const _StateMessage(
              iconData: Icons.error_outline,
              title: "Không thể tải thông báo",
              message: "Vui lòng thử lại sau hoặc kiểm tra quyền Firestore.",
            ),
          );
        }

        return StreamBuilder<List<TaskModel>>(
          stream: taskController.getTasksByUser(currentUser.uid),
          builder: (context, taskSnapshot) {
            final notifications =
                notificationSnapshot.data ?? <NotificationModel>[];
            final tasks = taskSnapshot.hasError
                ? <TaskModel>[]
                : taskSnapshot.data ?? <TaskModel>[];
            final items = _buildItems(
              notifications: notifications,
              tasks: tasks,
            );
            final unreadCount = notifications
                .where((item) => !item.isRead && !item.isDeleted)
                .length;

            return screen(
              backgroundColor: theme.scaffoldBackgroundColor,
              body: padding(
                left: 12,
                right: 12,
                top: 12,
                child: column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        flexible(
                          child: column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              text(
                                "Trung tâm thông báo",
                                weight: FontWeight.bold,
                                size: 20,
                                color: colors.onSurface,
                                align: TextAlign.left,
                              ),
                              text(
                                unreadCount == 0
                                    ? "${items.length} thông báo"
                                    : "$unreadCount thông báo chưa đọc",
                                size: 12,
                                color: colors.onSurfaceVariant,
                                align: TextAlign.left,
                              ),
                            ],
                          ),
                        ),
                        if (unreadCount > 0)
                          TextButton.icon(
                            onPressed: () => _markAllAsRead(currentUser.uid),
                            icon: const Icon(Icons.done_all, size: 18),
                            label: const Text("Đã đọc"),
                          ),
                      ],
                    ),
                    box(height: 12),
                    dropdown<String>(
                      list: filters,
                      value: selectedFilter,
                      fillColor: AppColors.surface,
                      borderRadius: AppRadius.lg,
                      hint: "Bộ lọc",
                      onChanged: (value) {
                        setState(() {
                          selectedFilter = value ?? "Tất cả";
                        });
                        PrefHelper.setUiPreference(
                          currentUser.uid,
                          'notification_filter',
                          selectedFilter,
                        );
                      },
                    ),
                    box(height: 12),
                    if (items.isEmpty)
                      Flexible(
                        child: _StateMessage(
                          iconData: Icons.notifications_none_rounded,
                          title: notifications.isEmpty
                              ? "Chưa có thông báo nào"
                              : "Không có thông báo phù hợp",
                          message:
                              "Thông báo hệ thống sẽ được lưu tại đây. Nhắc hạn vẫn được tính từ deadline công việc.",
                        ),
                      )
                    else
                      flexible(
                        child: list(
                          children: [
                            for (final item in items) _notificationCard(item),
                            box(height: 20),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _NotificationItem {
  final NotificationModel? notification;
  final TaskModel? task;

  const _NotificationItem._({this.notification, this.task});

  factory _NotificationItem.persistent(NotificationModel notification) {
    return _NotificationItem._(notification: notification);
  }

  factory _NotificationItem.reminder(TaskModel task) {
    return _NotificationItem._(task: task);
  }

  bool get isReminder => task != null;

  String get type {
    final currentTask = task;
    if (currentTask != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final deadline = DateTime(
        currentTask.deadline.year,
        currentTask.deadline.month,
        currentTask.deadline.day,
      );
      return today.isAfter(deadline) ? "task_overdue" : "task_due_soon";
    }
    return notification?.type ?? "";
  }

  String get targetType {
    if (task != null) return "task";
    return notification?.targetType ?? "none";
  }

  String get title {
    final currentTask = task;
    if (currentTask != null) {
      return type == "task_overdue"
          ? "Công việc quá hạn"
          : "Công việc sắp đến hạn";
    }
    return notification?.title ?? "Thông báo";
  }

  String get body {
    final currentTask = task;
    if (currentTask != null) {
      final title = currentTask.title.trim().isEmpty
          ? "Công việc chưa đặt tên"
          : currentTask.title.trim();
      final deadline = DateFormat('dd/MM/yyyy').format(currentTask.deadline);
      return "$title - deadline $deadline";
    }
    return notification?.body ?? "";
  }

  DateTime get sortTime {
    return notification?.createdAt ??
        task?.deadline ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String get timeLabel {
    final currentTask = task;
    if (currentTask != null) {
      return "Deadline ${DateFormat('dd/MM/yyyy').format(currentTask.deadline)}";
    }

    final createdAt = notification?.createdAt;
    if (createdAt == null) return "Vừa xong";
    return DateFormat('dd/MM/yyyy HH:mm').format(createdAt);
  }
}

class _StateMessage extends StatelessWidget {
  final IconData iconData;
  final String title;
  final String message;

  const _StateMessage({
    required this.iconData,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: colors.outlineVariant),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 38, color: colors.onSurfaceVariant),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: AppTextStyles.sectionTitle.copyWith(
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
