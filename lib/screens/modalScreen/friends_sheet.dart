import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:todo/controllers/friend_Controller.dart';
import 'package:todo/core/app_style.dart';
import 'package:todo/models/friend_request.dart';
import 'package:todo/models/user.dart';
import 'package:todo/screens/modalScreen/user_profile_sheet.dart';
import 'package:todo/services/userService.dart';
import 'package:todo/widgets/ui.dart';

Future<void> showFriendsSheet(BuildContext context) {
  return showAppModal(
    context: context,
    title: "Bạn bè",
    initialSize: 0.68,
    minSize: 0.42,
    maxSize: 0.92,
    child: const FriendsSheet(),
  );
}

class FriendsSheet extends StatefulWidget {
  const FriendsSheet({super.key});

  @override
  State<FriendsSheet> createState() => _FriendsSheetState();
}

class _FriendsSheetState extends State<FriendsSheet> {
  final _friendController = FriendController();
  String selectedTab = "friends";
  bool isWorking = false;

  Future<void> _runAction(Future<String?> Function() action) async {
    setState(() {
      isWorking = true;
    });

    final error = await action();
    if (!mounted) return;

    setState(() {
      isWorking = false;
    });

    snack(
      context,
      message: error ?? "Cập nhật bạn bè thành công",
      backgroundColor: error == null ? AppColors.primary : AppColors.danger,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid.isEmpty) {
      return _stateCard(
        iconData: Icons.lock_outline,
        title: "Bạn chưa đăng nhập",
        message: "Vui lòng đăng nhập để xem danh sách bạn bè.",
      );
    }

    return column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _tabChip(label: "Bạn bè", value: "friends"),
            _tabChip(label: "Lời mời đến", value: "incoming"),
            _tabChip(label: "Đã gửi", value: "outgoing"),
          ],
        ),
        box(height: 14),
        if (selectedTab == "friends") _friendsList(currentUid),
        if (selectedTab == "incoming") _incomingRequests(currentUid),
        if (selectedTab == "outgoing") _outgoingRequests(currentUid),
      ],
    );
  }

  Widget _friendsList(String currentUid) {
    return StreamBuilder<List<UserModel>>(
      stream: _friendController.streamFriends(currentUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return loading();
        }
        if (snapshot.hasError) {
          return _stateCard(
            iconData: Icons.error_outline,
            title: "Không thể tải bạn bè",
            message: "Vui lòng kiểm tra quyền Firestore hoặc thử lại sau.",
          );
        }

        final friends = snapshot.data ?? <UserModel>[];
        if (friends.isEmpty) {
          return _stateCard(
            iconData: Icons.people_outline,
            title: "Chưa có bạn bè",
            message:
                "Bạn có thể tìm người dùng bằng email trong form thêm nhân sự.",
          );
        }

        return column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final friend in friends)
              _userRow(
                user: friend,
                trailing: _smallOutlineButton(
                  label: "Hủy",
                  iconData: Icons.person_remove_alt_1_outlined,
                  color: AppColors.danger,
                  onPressed: isWorking
                      ? null
                      : () => _runAction(() {
                          return _friendController.unfriend(
                            currentUserId: currentUid,
                            friendUid: friend.uid,
                          );
                        }),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _incomingRequests(String currentUid) {
    return StreamBuilder<List<FriendRequestModel>>(
      stream: _friendController.streamIncomingRequests(currentUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return loading();
        }
        if (snapshot.hasError) {
          return _stateCard(
            iconData: Icons.error_outline,
            title: "Không thể tải lời mời",
            message: "Vui lòng thử lại sau.",
          );
        }

        final requests = snapshot.data ?? <FriendRequestModel>[];
        if (requests.isEmpty) {
          return _stateCard(
            iconData: Icons.inbox_outlined,
            title: "Không có lời mời mới",
            message: "Các lời mời kết bạn sẽ xuất hiện tại đây.",
          );
        }

        return column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final request in requests)
              _requestRow(
                userId: request.senderId,
                actions: row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _iconAction(
                      tooltip: "Chấp nhận",
                      iconData: Icons.check,
                      color: AppColors.success,
                      onPressed: isWorking
                          ? null
                          : () => _runAction(() {
                              return _friendController.acceptFriendRequest(
                                request: request,
                                currentUserId: currentUid,
                              );
                            }),
                    ),
                    _iconAction(
                      tooltip: "Từ chối",
                      iconData: Icons.close,
                      color: AppColors.danger,
                      onPressed: isWorking
                          ? null
                          : () => _runAction(() {
                              return _friendController.declineFriendRequest(
                                request: request,
                                currentUserId: currentUid,
                              );
                            }),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _outgoingRequests(String currentUid) {
    return StreamBuilder<List<FriendRequestModel>>(
      stream: _friendController.streamOutgoingRequests(currentUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return loading();
        }
        if (snapshot.hasError) {
          return _stateCard(
            iconData: Icons.error_outline,
            title: "Không thể tải lời mời đã gửi",
            message: "Vui lòng thử lại sau.",
          );
        }

        final requests = snapshot.data ?? <FriendRequestModel>[];
        if (requests.isEmpty) {
          return _stateCard(
            iconData: Icons.outbox_outlined,
            title: "Chưa gửi lời mời nào",
            message: "Các lời mời đang chờ phản hồi sẽ xuất hiện tại đây.",
          );
        }

        return column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final request in requests)
              _requestRow(
                userId: request.receiverId,
                actions: _smallOutlineButton(
                  label: "Hủy",
                  iconData: Icons.cancel_outlined,
                  color: AppColors.danger,
                  onPressed: isWorking
                      ? null
                      : () => _runAction(() {
                          return _friendController.cancelFriendRequest(
                            request: request,
                            currentUserId: currentUid,
                          );
                        }),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _requestRow({required String userId, required Widget actions}) {
    return FutureBuilder<UserModel?>(
      future: UserService().getUserById(userId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting &&
            user == null) {
          return _placeholderRow("Đang tải người dùng...");
        }
        if (user == null) {
          return _placeholderRow("Không thể tải hồ sơ người dùng.");
        }

        return _userRow(user: user, trailing: actions);
      },
    );
  }

  Widget _userRow({required UserModel user, required Widget trailing}) {
    final photoUrl = user.photoUrl.trim();
    final name = user.name.trim().isEmpty ? user.email : user.name;

    return pressable(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => showUserProfileSheet(context, userId: user.uid),
      child: containerBox(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        radius: BorderRadius.circular(AppRadius.md),
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        child: row(
          children: [
            avatar(
              imageUrl: photoUrl.isEmpty ? null : photoUrl,
              radius: 23,
              backgroundColor: AppColors.primarySoft,
              child: icon(Icons.person, color: AppColors.primary),
            ),
            box(width: 10),
            flexible(
              child: column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  text(name, weight: FontWeight.bold, maxLines: 1),
                  text(
                    user.email,
                    size: 12,
                    color: AppColors.textSecondary,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            box(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _placeholderRow(String message) {
    return containerBox(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      radius: BorderRadius.circular(AppRadius.md),
      color: AppColors.surfaceMuted,
      child: text(message, color: AppColors.textSecondary),
    );
  }

  Widget _tabChip({required String label, required String value}) {
    final selected = selectedTab == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          selectedTab = value;
        });
      },
      selectedColor: AppColors.primarySoft,
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
    );
  }

  Widget _smallOutlineButton({
    required String label,
    required IconData iconData,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(iconData, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.55)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _iconAction({
    required String tooltip,
    required IconData iconData,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: Icon(iconData, color: color),
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
}
