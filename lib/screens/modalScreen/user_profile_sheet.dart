import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:todo/controllers/chat_Controller.dart';
import 'package:todo/controllers/friend_Controller.dart';
import 'package:todo/controllers/task_Controller.dart';
import 'package:todo/core/app_style.dart';
import 'package:todo/models/friend_request.dart';
import 'package:todo/models/task.dart';
import 'package:todo/models/user.dart';
import 'package:todo/screens/modalScreen/chat_room_sheet.dart';
import 'package:todo/services/userService.dart';
import 'package:todo/widgets/ui.dart';

Future<void> showUserProfileSheet(
  BuildContext context, {
  required String userId,
  String? projectId,
}) {
  return showAppModal(
    context: context,
    title: "Hồ sơ người dùng",
    initialSize: 0.64,
    minSize: 0.42,
    maxSize: 0.92,
    child: UserProfileSheet(userId: userId, projectId: projectId),
  );
}

class UserProfileSheet extends StatefulWidget {
  final String userId;
  final String? projectId;

  const UserProfileSheet({super.key, required this.userId, this.projectId});

  @override
  State<UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<UserProfileSheet> {
  final _chatController = ChatController();
  final _friendController = FriendController();
  final _taskController = TaskController();
  late Future<UserModel?> _userFuture;
  late Future<FriendshipStatusResult> _statusFuture;
  bool isWorking = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    _userFuture = UserService().getUserById(widget.userId);
    _statusFuture = _friendController.getFriendshipStatus(
      currentUserId: currentUid,
      targetUserId: widget.userId,
    );
  }

  String _initial(UserModel? user) {
    final source = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim()
        : user?.email.trim() ?? "";
    if (source.isEmpty) return "?";
    return source.substring(0, 1).toUpperCase();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "Chưa có dữ liệu";
    return DateFormat("dd/MM/yyyy").format(date);
  }

  Future<void> _runAction(Future<String?> Function() action) async {
    setState(() {
      isWorking = true;
    });

    final error = await action();
    if (!mounted) return;

    setState(() {
      isWorking = false;
      _reload();
    });

    snack(
      context,
      message: error ?? "Cập nhật quan hệ bạn bè thành công",
      backgroundColor: error == null ? AppColors.primary : AppColors.danger,
    );
  }

  Future<void> _sendRequest() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid.isEmpty) {
      snack(
        context,
        message: "Vui lòng đăng nhập để gửi lời mời kết bạn.",
        backgroundColor: AppColors.danger,
      );
      return Future.value();
    }

    return _runAction(() {
      return _friendController.sendFriendRequest(
        senderId: currentUid,
        receiverId: widget.userId,
      );
    });
  }

  Future<void> _accept(FriendRequestModel request) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return _runAction(() {
      return _friendController.acceptFriendRequest(
        request: request,
        currentUserId: currentUid,
      );
    });
  }

  Future<void> _decline(FriendRequestModel request) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return _runAction(() {
      return _friendController.declineFriendRequest(
        request: request,
        currentUserId: currentUid,
      );
    });
  }

  Future<void> _cancel(FriendRequestModel request) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return _runAction(() {
      return _friendController.cancelFriendRequest(
        request: request,
        currentUserId: currentUid,
      );
    });
  }

  Future<void> _unfriend() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return _runAction(() {
      return _friendController.unfriend(
        currentUserId: currentUid,
        friendUid: widget.userId,
      );
    });
  }

  Future<void> _openChat(UserModel user) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid.isEmpty) {
      snack(
        context,
        message: "Vui lòng đăng nhập để nhắn tin.",
        backgroundColor: AppColors.danger,
      );
      return;
    }

    setState(() {
      isWorking = true;
    });

    try {
      debugPrint("[UserProfileSheet] get/create conversation for ${user.uid}");
      final conversation = await _chatController.getOrCreateDirectConversation(
        currentUid: currentUid,
        otherUser: user,
      );
      if (!mounted) return;

      debugPrint("[UserProfileSheet] open chat room: ${conversation.id}");
      showChatRoomSheet(context, conversation: conversation, otherUser: user);
    } catch (error) {
      debugPrint("[UserProfileSheet] open chat failed: $error");
      if (!mounted) return;
      snack(
        context,
        message: _friendlyChatError(error),
        backgroundColor: AppColors.danger,
      );
    } finally {
      if (mounted) {
        setState(() {
          isWorking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid.isEmpty) {
      return _stateCard(
        iconData: Icons.lock_outline,
        title: "Bạn chưa đăng nhập",
        message: "Vui lòng đăng nhập để xem hồ sơ người dùng.",
      );
    }

    return FutureBuilder<UserModel?>(
      future: _userFuture,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return loading();
        }

        final user = userSnapshot.data;
        if (user == null) {
          return _stateCard(
            iconData: Icons.person_off_outlined,
            title: "Không tìm thấy người dùng",
            message: "Hồ sơ này không tồn tại hoặc bạn không có quyền xem.",
          );
        }

        return FutureBuilder<FriendshipStatusResult>(
          future: _statusFuture,
          builder: (context, statusSnapshot) {
            final status = statusSnapshot.data;
            final isStatusLoading =
                statusSnapshot.connectionState == ConnectionState.waiting;

            return column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(user, status, isStatusLoading),
                box(height: 16),
                _friendActionArea(user, status, isStatusLoading),
                if (widget.projectId?.trim().isNotEmpty == true) ...[
                  box(height: 18),
                  text(
                    "Công việc trong dự án",
                    size: 16,
                    weight: FontWeight.bold,
                  ),
                  box(height: 10),
                  _projectTaskSection(user.uid),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _header(
    UserModel user,
    FriendshipStatusResult? status,
    bool isStatusLoading,
  ) {
    final photoUrl = user.photoUrl.trim();
    final name = user.name.trim().isEmpty ? user.email : user.name;

    return containerBox(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: BorderRadius.circular(AppRadius.lg),
      color: AppColors.primarySoft,
      border: Border.all(color: const Color(0xFFD8E8FF)),
      child: column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(
            children: [
              avatar(
                imageUrl: photoUrl.isEmpty ? null : photoUrl,
                radius: 34,
                backgroundColor: AppColors.primary,
                child: text(
                  _initial(user),
                  size: 24,
                  weight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              box(width: 14),
              flexible(
                child: column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    text(name, size: 20, weight: FontWeight.w800, maxLines: 1),
                    box(height: 4),
                    text(
                      user.email.isEmpty ? "Chưa có email" : user.email,
                      size: 13,
                      color: AppColors.textSecondary,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          box(height: 14),
          wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                iconData: Icons.calendar_month_outlined,
                label: "Tham gia ${_formatDate(user.createdAt)}",
                color: AppColors.primary,
              ),
              _chip(
                iconData: Icons.people_alt_outlined,
                label: isStatusLoading
                    ? "Đang kiểm tra..."
                    : _friendshipLabel(status),
                color: _friendshipColor(status),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _friendActionArea(
    UserModel user,
    FriendshipStatusResult? status,
    bool isStatusLoading,
  ) {
    if (isStatusLoading) {
      return _hintCard("Đang kiểm tra quan hệ bạn bè...");
    }
    if (status == null || status.status == FriendshipStatus.none) {
      return _primaryActionButton(
        label: "Gửi lời mời kết bạn",
        iconData: Icons.person_add_alt_1_outlined,
        onPressed: isWorking ? null : _sendRequest,
      );
    }
    if (status.isSelf) {
      return _hintCard("Đây là hồ sơ của bạn.");
    }
    if (status.isFriend) {
      return column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _primaryActionButton(
            label: "Nhắn tin",
            iconData: Icons.forum_outlined,
            onPressed: isWorking ? null : () => _openChat(user),
          ),
          box(height: 10),
          row(
            children: [
              flexible(child: _hintCard("Hai người đã là bạn bè.")),
              box(width: 10),
              _outlineActionButton(
                label: "Hủy kết bạn",
                iconData: Icons.person_remove_alt_1_outlined,
                onPressed: isWorking ? null : _unfriend,
                color: AppColors.danger,
              ),
            ],
          ),
        ],
      );
    }
    if (status.isIncomingPending && status.request != null) {
      return row(
        children: [
          flexible(
            child: _primaryActionButton(
              label: "Chấp nhận",
              iconData: Icons.check_circle_outline,
              onPressed: isWorking ? null : () => _accept(status.request!),
            ),
          ),
          box(width: 10),
          flexible(
            child: _outlineActionButton(
              label: "Từ chối",
              iconData: Icons.close,
              onPressed: isWorking ? null : () => _decline(status.request!),
              color: AppColors.danger,
            ),
          ),
        ],
      );
    }
    if (status.isOutgoingPending && status.request != null) {
      return row(
        children: [
          flexible(child: _hintCard("Đã gửi lời mời kết bạn.")),
          box(width: 10),
          _outlineActionButton(
            label: "Hủy lời mời",
            iconData: Icons.cancel_outlined,
            onPressed: isWorking ? null : () => _cancel(status.request!),
            color: AppColors.danger,
          ),
        ],
      );
    }

    return _hintCard("Chưa có quan hệ bạn bè.");
  }

  Widget _projectTaskSection(String uid) {
    final projectId = widget.projectId?.trim();
    if (projectId == null || projectId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<List<TaskModel>>(
      stream: _taskController.getTasksByProject(projectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _smallLoadingCard();
        }
        if (snapshot.hasError) {
          return _stateCard(
            iconData: Icons.error_outline,
            title: "Không thể tải công việc",
            message: "Vui lòng kiểm tra quyền Firestore hoặc thử lại sau.",
          );
        }

        final assignedTasks = (snapshot.data ?? <TaskModel>[])
            .where((task) => task.assigneeId.trim() == uid.trim())
            .toList();

        if (assignedTasks.isEmpty) {
          return _hintCard("Người này chưa được giao công việc trong dự án.");
        }

        return column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final task in assignedTasks.take(5)) _taskTile(task),
            if (assignedTasks.length > 5)
              padding(
                top: 8,
                child: text(
                  "+${assignedTasks.length - 5} công việc khác",
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _taskTile(TaskModel task) {
    final isDone = task.status.trim().toLowerCase() == "done";
    return containerBox(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      radius: BorderRadius.circular(AppRadius.md),
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      child: row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon(
            isDone ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            color: isDone ? AppColors.success : AppColors.textSecondary,
          ),
          box(width: 10),
          flexible(
            child: column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text(task.title, weight: FontWeight.bold, maxLines: 1),
                box(height: 3),
                text(
                  "Deadline: ${DateFormat("dd/MM/yyyy").format(task.deadline)}",
                  size: 12,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryActionButton({
    required String label,
    required IconData iconData,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: isWorking
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(iconData, size: 18),
        label: Text(label),
      ),
    );
  }

  Widget _outlineActionButton({
    required String label,
    required IconData iconData,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(iconData, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: OutlinedButton.styleFrom(side: BorderSide(color: color)),
    );
  }

  Widget _hintCard(String message) {
    return containerBox(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      radius: BorderRadius.circular(AppRadius.md),
      color: AppColors.surfaceMuted,
      child: text(message, color: AppColors.textSecondary, maxLines: 3),
    );
  }

  Widget _smallLoadingCard() {
    return containerBox(
      width: double.infinity,
      height: 74,
      radius: BorderRadius.circular(AppRadius.md),
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      child: loading(size: 20),
    );
  }

  Widget _stateCard({
    required IconData iconData,
    required String title,
    required String message,
  }) {
    return containerBox(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: BorderRadius.circular(AppRadius.lg),
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      child: column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon(iconData, size: 34, color: AppColors.textSecondary),
          box(height: 10),
          text(title, size: 16, weight: FontWeight.bold),
          box(height: 6),
          text(
            message,
            color: AppColors.textSecondary,
            align: TextAlign.center,
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData iconData,
    required String label,
    required Color color,
  }) {
    return containerBox(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      radius: BorderRadius.circular(AppRadius.sm),
      color: color.withValues(alpha: 0.12),
      child: row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon(iconData, size: 15, color: color),
          box(width: 5),
          text(label, size: 12, color: color, weight: FontWeight.w700),
        ],
      ),
    );
  }

  String _friendshipLabel(FriendshipStatusResult? status) {
    switch (status?.status) {
      case FriendshipStatus.self:
        return "Hồ sơ của bạn";
      case FriendshipStatus.friends:
        return "Bạn bè";
      case FriendshipStatus.incomingPending:
        return "Đã gửi lời mời cho bạn";
      case FriendshipStatus.outgoingPending:
        return "Đang chờ phản hồi";
      default:
        return "Chưa kết bạn";
    }
  }

  Color _friendshipColor(FriendshipStatusResult? status) {
    switch (status?.status) {
      case FriendshipStatus.friends:
        return AppColors.success;
      case FriendshipStatus.incomingPending:
      case FriendshipStatus.outgoingPending:
        return AppColors.warning;
      case FriendshipStatus.self:
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _friendlyChatError(Object error) {
    final message = error.toString();
    if (error is FirebaseException && error.code == "permission-denied") {
      return "Không thể mở cuộc trò chuyện. Vui lòng thử lại.";
    }
    if (message.contains("permission-denied")) {
      return "Không thể mở cuộc trò chuyện. Vui lòng thử lại.";
    }
    if (error is ArgumentError || error is StateError) {
      final normalized = message.replaceFirst(RegExp(r"^[^:]+:\s*"), "");
      return normalized.trim().isEmpty
          ? "Không thể mở cuộc trò chuyện."
          : normalized;
    }
    return "Không thể mở cuộc trò chuyện.";
  }
}
