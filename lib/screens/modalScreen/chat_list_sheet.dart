import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:todo/controllers/chat_Controller.dart';
import 'package:todo/core/app_style.dart';
import 'package:todo/models/conversation.dart';
import 'package:todo/models/user.dart';
import 'package:todo/screens/modalScreen/chat_room_sheet.dart';
import 'package:todo/widgets/ui.dart';

Future<void> showChatListSheet(BuildContext context) {
  return showAppModal(
    context: context,
    title: "Tin nhắn",
    initialSize: 0.72,
    minSize: 0.42,
    maxSize: 0.92,
    child: const ChatListSheet(),
  );
}

class ChatListSheet extends StatefulWidget {
  const ChatListSheet({super.key});

  @override
  State<ChatListSheet> createState() => _ChatListSheetState();
}

class _ChatListSheetState extends State<ChatListSheet> {
  final _chatController = ChatController();

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid.isEmpty) {
      return _stateCard(
        iconData: Icons.lock_outline,
        title: "Bạn chưa đăng nhập",
        message: "Vui lòng đăng nhập để xem tin nhắn.",
      );
    }

    return StreamBuilder<List<ConversationModel>>(
      stream: _chatController.streamMyConversations(currentUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return loading();
        }
        if (snapshot.hasError) {
          return _stateCard(
            iconData: Icons.error_outline,
            title: "Không thể tải tin nhắn",
            message: "Vui lòng kiểm tra quyền Firestore hoặc thử lại sau.",
          );
        }

        final conversations = snapshot.data ?? <ConversationModel>[];
        if (conversations.isEmpty) {
          return _stateCard(
            iconData: Icons.forum_outlined,
            title: "Chưa có cuộc trò chuyện nào",
            message: "Hãy mở hồ sơ bạn bè để bắt đầu nhắn tin.",
          );
        }

        return column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final conversation in conversations)
              _conversationCard(conversation, currentUid),
          ],
        );
      },
    );
  }

  Widget _conversationCard(ConversationModel conversation, String currentUid) {
    return FutureBuilder<UserModel?>(
      future: _chatController.getOtherMember(
        conversation: conversation,
        currentUid: currentUid,
      ),
      builder: (context, snapshot) {
        final colors = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final otherUser = snapshot.data;
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            otherUser == null;

        final unread = conversation.isUnreadFor(currentUid);
        final name = isLoading
            ? "Đang tải..."
            : _displayName(otherUser, conversation, currentUid);
        final email = otherUser?.email ?? "";
        final photoUrl = otherUser?.photoUrl.trim() ?? "";
        final lastMessage = conversation.lastMessage.trim().isEmpty
            ? "Bắt đầu cuộc trò chuyện"
            : conversation.lastMessage.trim();

        return pressable(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: otherUser == null
              ? null
              : () => showChatRoomSheet(
                  context,
                  conversation: conversation,
                  otherUser: otherUser,
                ),
          child: containerBox(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            radius: BorderRadius.circular(AppRadius.lg),
            color: unread
                ? (isDark
                      ? colors.primaryContainer.withValues(alpha: 0.24)
                      : AppColors.primarySoft)
                : colors.surface,
            border: Border.all(
              color: unread
                  ? colors.primary.withValues(alpha: 0.28)
                  : colors.outlineVariant,
            ),
            shadow: AppShadows.card,
            child: row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatar(
                  imageUrl: photoUrl.isEmpty ? null : photoUrl,
                  radius: 24,
                  backgroundColor: colors.primaryContainer,
                  child: icon(Icons.person, color: colors.primary),
                ),
                box(width: 12),
                flexible(
                  child: column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      text(
                        name,
                        weight: FontWeight.bold,
                        size: 15,
                        color: colors.onSurface,
                        maxLines: 1,
                      ),
                      if (email.isNotEmpty)
                        text(
                          email,
                          size: 11,
                          color: colors.onSurfaceVariant,
                          maxLines: 1,
                        ),
                      box(height: 4),
                      text(
                        lastMessage,
                        size: 13,
                        color: unread
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                        weight: unread ? FontWeight.w700 : FontWeight.normal,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                box(width: 8),
                column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    text(
                      _formatLastTime(conversation),
                      size: 11,
                      color: colors.onSurfaceVariant,
                      align: TextAlign.right,
                      maxLines: 1,
                    ),
                    if (unread) ...[
                      box(height: 8),
                      containerBox(
                        width: 10,
                        height: 10,
                        radius: BorderRadius.circular(5),
                        color: AppColors.danger,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _displayName(
    UserModel? user,
    ConversationModel conversation,
    String currentUid,
  ) {
    if (user != null) {
      if (user.name.trim().isNotEmpty) return user.name.trim();
      if (user.email.trim().isNotEmpty) return user.email.trim();
    }

    final otherUid = conversation.otherMemberId(currentUid);
    final info = otherUid == null ? null : conversation.infoFor(otherUid);
    final infoName = info?["name"]?.trim() ?? "";
    final infoEmail = info?["email"]?.trim() ?? "";
    if (infoName.isNotEmpty) return infoName;
    if (infoEmail.isNotEmpty) return infoEmail;
    return "Người dùng";
  }

  String _formatLastTime(ConversationModel conversation) {
    final time =
        conversation.lastMessageAt ??
        conversation.updatedAt ??
        conversation.createdAt;
    if (time == null) return "";
    return DateFormat("HH:mm - dd.MM.yyyy").format(time);
  }

  Widget _stateCard({
    required IconData iconData,
    required String title,
    required String message,
  }) {
    final colors = Theme.of(context).colorScheme;

    return containerBox(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: BorderRadius.circular(AppRadius.lg),
      color: colors.surface,
      border: Border.all(color: colors.outlineVariant),
      child: column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon(iconData, size: 34, color: colors.onSurfaceVariant),
          box(height: 10),
          text(
            title,
            size: 16,
            weight: FontWeight.bold,
            color: colors.onSurface,
          ),
          box(height: 6),
          text(
            message,
            color: colors.onSurfaceVariant,
            align: TextAlign.center,
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}
