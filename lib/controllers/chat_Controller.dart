import 'package:todo/models/conversation.dart';
import 'package:todo/models/message.dart';
import 'package:todo/models/user.dart';
import 'package:todo/services/chatService.dart';

class ChatController {
  final ChatService _chatService = ChatService();

  String directConversationId(String uidA, String uidB) {
    return _chatService.directConversationId(uidA, uidB);
  }

  Future<ConversationModel> getOrCreateDirectConversation({
    required String currentUid,
    required UserModel otherUser,
  }) {
    return _chatService.getOrCreateDirectConversation(
      currentUid: currentUid,
      otherUser: otherUser,
    );
  }

  Future<ConversationModel?> getConversationById(String conversationId) {
    return _chatService.getConversationById(conversationId);
  }

  Stream<List<ConversationModel>> streamMyConversations(String uid) {
    return _chatService.streamMyConversations(uid);
  }

  Stream<ConversationModel?> streamConversation(String conversationId) {
    return _chatService.streamConversation(conversationId);
  }

  Stream<int> streamUnreadConversationCount(String uid) {
    return _chatService.streamUnreadConversationCount(uid);
  }

  Stream<List<MessageModel>> streamMessages(String conversationId) {
    return _chatService.streamMessages(conversationId);
  }

  Future<String?> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    try {
      await _chatService.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        receiverId: receiverId,
        text: text,
      );
      return null;
    } catch (e) {
      return _friendlyError(e, "Không thể gửi tin nhắn.");
    }
  }

  Future<String?> markConversationRead({
    required String conversationId,
    required String uid,
  }) async {
    try {
      await _chatService.markConversationRead(conversationId, uid);
      return null;
    } catch (e) {
      return _friendlyError(e, "Không thể đánh dấu đã đọc.");
    }
  }

  Future<bool> areFriends(String uidA, String uidB) {
    return _chatService.areFriends(uidA, uidB);
  }

  Future<UserModel?> getOtherMember({
    required ConversationModel conversation,
    required String currentUid,
  }) {
    return _chatService.getOtherMember(
      conversation: conversation,
      currentUid: currentUid,
    );
  }

  String _friendlyError(Object error, String fallback) {
    final message = error.toString();
    if (message.contains("permission-denied")) {
      return "Bạn không có quyền thực hiện thao tác này.";
    }
    if (error is ArgumentError || error is StateError) {
      final normalized = message.replaceFirst(RegExp(r"^[^:]+:\s*"), "");
      return normalized.trim().isEmpty ? fallback : normalized;
    }
    return fallback;
  }
}
