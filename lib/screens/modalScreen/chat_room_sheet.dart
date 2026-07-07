import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:todo/controllers/chat_Controller.dart';
import 'package:todo/core/app_style.dart';
import 'package:todo/models/conversation.dart';
import 'package:todo/models/message.dart';
import 'package:todo/models/user.dart';
import 'package:todo/widgets/ui.dart';

Future<void> showChatRoomSheet(
  BuildContext context, {
  required ConversationModel conversation,
  required UserModel otherUser,
}) {
  return showAppModal(
    context: context,
    title: "Tin nhắn",
    initialSize: 0.82,
    minSize: 0.55,
    maxSize: 0.95,
    isScrollable: false,
    child: ChatRoomSheet(conversation: conversation, otherUser: otherUser),
  );
}

class ChatRoomSheet extends StatefulWidget {
  final ConversationModel conversation;
  final UserModel otherUser;

  const ChatRoomSheet({
    super.key,
    required this.conversation,
    required this.otherUser,
  });

  @override
  State<ChatRoomSheet> createState() => _ChatRoomSheetState();
}

class _ChatRoomSheetState extends State<ChatRoomSheet> {
  final _chatController = ChatController();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late Future<bool> _friendshipFuture;
  bool isSending = false;
  bool _didInitialScroll = false;
  bool _isNearBottom = true;
  bool _pendingScrollAfterSend = false;
  int _lastMessageCount = 0;
  String? _lastMessageId;

  @override
  void initState() {
    super.initState();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    _friendshipFuture = _chatController.areFriends(
      currentUid,
      widget.otherUser.uid,
    );
    _scrollController.addListener(_handleScrollPosition);
    _markRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScrollPosition() {
    if (!_scrollController.hasClients) return;

    final distanceToBottom =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    _isNearBottom = distanceToBottom <= 120;
  }

  Future<void> _markRead() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid.isEmpty) return;

    try {
      final error = await _chatController.markConversationRead(
        conversationId: widget.conversation.id,
        uid: currentUid,
      );
      if (error != null) {
        debugPrint(
          "[ChatRoom] mark read failed: "
          "${widget.conversation.id} error=$error",
        );
      }
    } catch (error) {
      debugPrint(
        "[ChatRoom] mark read failed: "
        "${widget.conversation.id} error=$error",
      );
    }
  }

  Future<void> _send() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final text = _messageController.text.trim();
    debugPrint(
      "[ChatRoom] send pressed conversationId=${widget.conversation.id} "
      "hasCurrentUid=${currentUid?.trim().isNotEmpty == true} "
      "textLength=${text.length} isSendingBefore=$isSending "
      "preview=${_preview(text)}",
    );
    if (currentUid == null || currentUid.isEmpty) {
      snack(
        context,
        message: "Vui lòng nhập tin nhắn.",
        backgroundColor: AppColors.danger,
      );
      return;
    }
    if (text.isEmpty || isSending) return;

    setState(() {
      isSending = true;
    });
    debugPrint("[ChatRoom] isSendingAfterSet=true");

    String? error;
    try {
      error = await _chatController.sendMessage(
        conversationId: widget.conversation.id,
        senderId: currentUid,
        receiverId: widget.otherUser.uid,
        text: text,
      );
    } catch (exception, stackTrace) {
      debugPrint(
        "[ChatRoom] send exception type=${exception.runtimeType} "
        "message=$exception\n$stackTrace",
      );
      error =
          "Không thể gửi tin nhắn. Vui lòng thử lại.";
    }

    if (!mounted) return;

    setState(() {
      isSending = false;
      if (error == null) {
        _messageController.clear();
        _pendingScrollAfterSend = true;
      }
      _friendshipFuture = _chatController.areFriends(
        currentUid,
        widget.otherUser.uid,
      );
    });
    debugPrint(
      "[ChatRoom] isSendingAfterFinally=false success=${error == null}",
    );

    if (error != null) {
      snack(context, message: error, backgroundColor: AppColors.danger);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottom();
      _pendingScrollAfterSend = false;
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    debugPrint(
      "[ChatRoom] scrollToBottom max=${_scrollController.position.maxScrollExtent}",
    );
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid.isEmpty) {
      return _stateMessage(
        iconData: Icons.lock_outline,
        title: "Bạn chưa đăng nhập",
        message: "Vui lòng đăng nhập để xem cuộc trò chuyện.",
      );
    }

    return column(
      children: [
        _roomHeader(),
        hDivider(height: 16, color: Theme.of(context).dividerColor),
        Expanded(
          child: StreamBuilder<ConversationModel?>(
            stream: _chatController.streamConversation(widget.conversation.id),
            initialData: widget.conversation,
            builder: (context, conversationSnapshot) {
              final liveConversation =
                  conversationSnapshot.data ?? widget.conversation;

              return StreamBuilder<List<MessageModel>>(
                stream: _chatController.streamMessages(widget.conversation.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return loading();
                  }
                  if (snapshot.hasError) {
                    debugPrint(
                      "[ChatRoom] stream messages failed: "
                      "${widget.conversation.id} error=${snapshot.error}",
                    );
                    return _stateMessage(
                      iconData: Icons.error_outline,
                      title: "Không thể tải tin nhắn",
                      message:
                          "Vui lòng kiểm tra quyền Firestore hoặc thử lại.",
                    );
                  }

                  final messages = snapshot.data ?? <MessageModel>[];
                  _handleMessagesChanged(messages, currentUid);

                  if (messages.isEmpty) {
                    return _stateMessage(
                      iconData: Icons.forum_outlined,
                      title: "Chưa có tin nhắn",
                      message:
                          "Hãy gửi lời chào để bắt đầu cuộc trò chuyện.",
                    );
                  }

                  final lastMineIndex = _lastMineIndex(messages, currentUid);
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 12,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMine = message.senderId == currentUid;
                      final showReceipt = isMine && index == lastMineIndex;
                      return _messageBubble(
                        message,
                        isMine: isMine,
                        receiptLabel: showReceipt
                            ? _receiptLabel(liveConversation, message)
                            : null,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        FutureBuilder<bool>(
          future: _friendshipFuture,
          builder: (context, snapshot) {
            final canSend = snapshot.data ?? false;
            if (!canSend) {
              return _disabledInput();
            }
            return _inputBar();
          },
        ),
      ],
    );
  }

  Widget _roomHeader() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final photoUrl = widget.otherUser.photoUrl.trim();
    final name = widget.otherUser.name.trim().isEmpty
        ? widget.otherUser.email
        : widget.otherUser.name;

    return padding(
      left: 16,
      right: 16,
      child: row(
        children: [
          avatar(
            imageUrl: photoUrl.isEmpty ? null : photoUrl,
            radius: 24,
            backgroundColor: colors.primaryContainer,
            child: icon(Icons.person, color: colors.primary),
          ),
          box(width: 10),
          flexible(
            child: column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text(
                  name,
                  size: 16,
                  weight: FontWeight.bold,
                  color: colors.onSurface,
                  maxLines: 1,
                ),
                text(
                  widget.otherUser.email,
                  size: 12,
                  color: colors.onSurfaceVariant,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(
    MessageModel message, {
    required bool isMine,
    String? receiptLabel,
  }) {
    final colors = Theme.of(context).colorScheme;
    final time = message.createdAt == null
        ? ""
        : DateFormat("HH:mm").format(message.createdAt!);

    return align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: containerBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        radius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 16),
        ),
        color: isMine ? colors.primary : colors.surfaceContainerHighest,
        child: column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            text(
              message.text,
              color: isMine ? colors.onPrimary : colors.onSurface,
              maxLines: 20,
              overflow: TextOverflow.visible,
            ),
            if (time.isNotEmpty || receiptLabel != null) ...[
              box(height: 4),
              text(
                [
                  if (time.isNotEmpty) time,
                  if (receiptLabel != null) receiptLabel,
                ].join(" \u2022 "),
                size: 10,
                color: isMine
                    ? colors.onPrimary.withValues(alpha: 0.75)
                    : colors.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _inputBar() {
    final colors = Theme.of(context).colorScheme;
    return containerBox(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      color: colors.surface,
      border: Border(top: BorderSide(color: colors.outlineVariant)),
      child: row(
        children: [
          flexible(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Nhập tin nhắn...",
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          box(width: 8),
          IconButton.filled(
            onPressed: isSending ? null : _send,
            icon: isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }

  Widget _disabledInput() {
    final colors = Theme.of(context).colorScheme;
    return containerBox(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: colors.surfaceContainerHighest,
      border: Border(top: BorderSide(color: colors.outlineVariant)),
      child: text(
        "Bạn chỉ có thể nhận tin với bạn bè.",
        color: colors.onSurfaceVariant,
        align: TextAlign.center,
        maxLines: 2,
      ),
    );
  }

  Widget _stateMessage({
    required IconData iconData,
    required String title,
    required String message,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: padding(
        all: 18,
        child: column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon(iconData, size: 34, color: colors.onSurfaceVariant),
            box(height: 10),
            text(
              title,
              weight: FontWeight.bold,
              size: 16,
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
      ),
    );
  }

  int _lastMineIndex(List<MessageModel> messages, String currentUid) {
    for (var index = messages.length - 1; index >= 0; index--) {
      if (messages[index].senderId == currentUid) return index;
    }
    return -1;
  }

  String _receiptLabel(ConversationModel conversation, MessageModel message) {
    final readAt = conversation.lastReadAtFor(widget.otherUser.uid);
    final createdAt = message.createdAt;
    if (readAt == null || createdAt == null) return "Đã gửi";
    return readAt.isBefore(createdAt) ? "Đã gửi" : "Đã xem";
  }

  void _handleMessagesChanged(List<MessageModel> messages, String currentUid) {
    final nextLastMessageId = messages.isEmpty ? null : messages.last.id;
    final messagesChanged =
        messages.length != _lastMessageCount ||
        nextLastMessageId != _lastMessageId;
    if (!messagesChanged) return;

    final lastMessage = messages.isEmpty ? null : messages.last;
    final lastMessageIsMine = lastMessage?.senderId == currentUid;
    final shouldScroll =
        !_didInitialScroll ||
        _pendingScrollAfterSend ||
        lastMessageIsMine ||
        _isNearBottom;

    debugPrint(
      "[ChatRoom] messages changed count=${messages.length} "
      "lastId=$nextLastMessageId shouldScroll=$shouldScroll "
      "nearBottom=$_isNearBottom initialDone=$_didInitialScroll "
      "pendingAfterSend=$_pendingScrollAfterSend lastMine=$lastMessageIsMine",
    );

    _lastMessageCount = messages.length;
    _lastMessageId = nextLastMessageId;
    _didInitialScroll = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _markRead();
      if (shouldScroll) {
        _scrollToBottom();
        _pendingScrollAfterSend = false;
      }
    });
  }

  String _preview(String value) {
    final normalized = value.trim().replaceAll(RegExp(r"\s+"), " ");
    if (normalized.length <= 50) return normalized;
    return "${normalized.substring(0, 50)}...";
  }
}
