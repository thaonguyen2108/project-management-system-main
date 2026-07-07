import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:todo/models/conversation.dart';
import 'package:todo/models/message.dart';
import 'package:todo/models/user.dart';
import 'package:todo/services/notificationService.dart';
import 'package:todo/services/userService.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;
  final _conversationRef = FirebaseFirestore.instance.collection(
    "conversations",
  );
  final _userRef = FirebaseFirestore.instance.collection("users");
  final _userService = UserService();
  final _notificationService = NotificationService();

  String directConversationId(String uidA, String uidB) {
    final ids = [uidA.trim(), uidB.trim()]..sort();
    return "${ids[0]}_${ids[1]}";
  }

  Future<ConversationModel> getOrCreateDirectConversation({
    required String currentUid,
    required UserModel otherUser,
  }) async {
    final current = currentUid.trim();
    final other = otherUser.uid.trim();
    if (current.isEmpty || other.isEmpty) {
      throw ArgumentError("Thiếu thông tin người dùng để mở trò chuyện.");
    }
    if (current == other) {
      throw ArgumentError("Bạn không thể nhắn tin với chính mình.");
    }
    debugPrint(
      "[ChatService] check friend before direct chat: $current -> $other",
    );
    if (!await _areFriends(current, other)) {
      debugPrint("[ChatService] users are not friends: $current -> $other");
      throw StateError("Bạn chỉ có thể nhắn tin với bạn bè.");
    }

    final conversationId = directConversationId(current, other);
    final docRef = _conversationRef.doc(conversationId);
    debugPrint("[ChatService] open direct conversation: $conversationId");

    try {
      final existing = await docRef.get();
      final existingData = existing.data();
      if (existing.exists && existingData != null) {
        debugPrint("[ChatService] conversation exists: $conversationId");
        return ConversationModel.fromJson({...existingData, "id": existing.id});
      }

      final currentUser = await _userService.getUserById(current);
      final members = [current, other]..sort();
      final now = DateTime.now();
      final conversation = ConversationModel(
        id: conversationId,
        type: "direct",
        memberIds: members,
        memberInfo: {
          current: _memberInfo(currentUser),
          other: _memberInfo(otherUser),
        },
        lastMessage: "",
        unreadBy: const [],
        isDeletedFor: const [],
        createdAt: now,
        updatedAt: now,
      );

      debugPrint("[ChatService] create direct conversation: $conversationId");
      await docRef.set(conversation.toJson());

      final created = await docRef.get();
      final data = created.data();
      if (!created.exists || data == null) {
        debugPrint(
          "[ChatService] create returned no document: $conversationId",
        );
        throw StateError("Không thể tạo cuộc trò chuyện.");
      }

      debugPrint("[ChatService] created direct conversation: $conversationId");
      return ConversationModel.fromJson({...data, "id": docRef.id});
    } on FirebaseException catch (error) {
      debugPrint(
        "[ChatService] get/create conversation failed: "
        "$conversationId code=${error.code} message=${error.message}",
      );
      rethrow;
    } catch (error) {
      debugPrint(
        "[ChatService] get/create conversation failed: "
        "$conversationId error=$error",
      );
      rethrow;
    }
  }

  Future<ConversationModel?> getConversationById(String conversationId) async {
    final id = conversationId.trim();
    if (id.isEmpty) return null;

    final doc = await _conversationRef.doc(id).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;

    return ConversationModel.fromJson({...data, "id": doc.id});
  }

  Stream<List<ConversationModel>> streamMyConversations(String uid) {
    final current = uid.trim();
    if (current.isEmpty) return Stream.value(<ConversationModel>[]);

    return _conversationRef
        .where("memberIds", arrayContains: current)
        .snapshots()
        .map((snapshot) {
          final conversations = snapshot.docs
              .map(
                (doc) =>
                    ConversationModel.fromJson({...doc.data(), "id": doc.id}),
              )
              .where(
                (conversation) => !conversation.isDeletedFor.contains(current),
              )
              .toList();

          conversations.sort((a, b) {
            final aTime = a.lastMessageAt ?? a.updatedAt ?? a.createdAt;
            final bTime = b.lastMessageAt ?? b.updatedAt ?? b.createdAt;
            final safeA = aTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            final safeB = bTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            return safeB.compareTo(safeA);
          });
          return conversations;
        });
  }

  Stream<ConversationModel?> streamConversation(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) return Stream.value(null);

    return _conversationRef.doc(id).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return ConversationModel.fromJson({...data, "id": doc.id});
    });
  }

  Stream<int> streamUnreadConversationCount(String uid) {
    final current = uid.trim();
    if (current.isEmpty) return Stream.value(0);

    return streamMyConversations(
      current,
    ).map((items) => items.where((item) => item.isUnreadFor(current)).length);
  }

  Stream<List<MessageModel>> streamMessages(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) return Stream.value(<MessageModel>[]);

    return _conversationRef
        .doc(id)
        .collection("messages")
        .orderBy("createdAt", descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => MessageModel.fromJson({...doc.data(), "id": doc.id}),
              )
              .where((message) => !message.isDeleted)
              .toList(),
        );
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    final id = conversationId.trim();
    final sender = senderId.trim();
    final receiver = receiverId.trim();
    final messageText = text.trim();

    if (id.isEmpty || sender.isEmpty || receiver.isEmpty) {
      throw ArgumentError("Thiếu thông tin cuộc trò chuyện.");
    }
    if (sender == receiver) {
      throw ArgumentError("Bạn không thể nhắn tin với chính mình.");
    }
    if (messageText.isEmpty) {
      throw ArgumentError("Nội dung tin nhắn không được rỗng.");
    }

    debugPrint(
      "[ChatService] sendMessage start conversationId=$id "
      "sender=$sender receiver=$receiver textLength=${messageText.length} "
      "preview=${_previewForLog(messageText)}",
    );

    try {
      await _db.runTransaction((transaction) async {
        debugPrint("[ChatService] transaction start conversationId=$id");
        final conversationDoc = await transaction.get(_conversationRef.doc(id));
        final conversationData = conversationDoc.data();
        if (!conversationDoc.exists || conversationData == null) {
          throw StateError("Không tìm thấy cuộc trò chuyện.");
        }

        final conversation = ConversationModel.fromJson({
          ...conversationData,
          "id": conversationDoc.id,
        });
        if (!conversation.memberIds.contains(sender) ||
            !conversation.memberIds.contains(receiver)) {
          throw StateError(
            "Bạn không có quyền gửi tin nhắn trong cuộc trò chuyện này.",
          );
        }

        final friendshipDoc = await transaction.get(
          _friendRef(sender, receiver),
        );
        if (!friendshipDoc.exists) {
          throw StateError("Bạn chỉ có thể nhắn tin với bạn bè.");
        }

        final messageRef = _conversationRef
            .doc(id)
            .collection("messages")
            .doc();
        debugPrint("[ChatService] message doc id=${messageRef.id}");
        final message = MessageModel(
          id: messageRef.id,
          conversationId: id,
          senderId: sender,
          text: messageText,
        );

        final unreadBy = conversation.unreadBy.toSet()
          ..remove(sender)
          ..add(receiver);

        transaction.set(messageRef, message.toJson(useServerCreatedAt: true));
        transaction.update(_conversationRef.doc(id), {
          "lastMessage": _previewText(messageText),
          "lastMessageAt": FieldValue.serverTimestamp(),
          "lastSenderId": sender,
          "updatedAt": FieldValue.serverTimestamp(),
          "unreadBy": unreadBy.toList(),
          "lastReadAtBy.$sender": FieldValue.serverTimestamp(),
        });
        debugPrint("[ChatService] conversation update queued id=$id");
      });
      debugPrint("[ChatService] transaction success conversationId=$id");
    } catch (error, stackTrace) {
      debugPrint(
        "[ChatService] sendMessage failed type=${error.runtimeType} "
        "message=$error\n$stackTrace",
      );
      rethrow;
    }

    await _ignoreNotificationFailure(() {
      return _notificationService.createChatMessageNotification(
        conversationId: id,
        senderId: sender,
        receiverId: receiver,
        text: messageText,
      );
    });
  }

  Future<void> markConversationRead(String conversationId, String uid) async {
    final id = conversationId.trim();
    final current = uid.trim();
    if (id.isEmpty || current.isEmpty) return;

    await _conversationRef.doc(id).update({
      "unreadBy": FieldValue.arrayRemove([current]),
      "lastReadAtBy.$current": FieldValue.serverTimestamp(),
    });
  }

  Future<bool> areFriends(String uidA, String uidB) {
    return _areFriends(uidA, uidB);
  }

  Future<UserModel?> getOtherMember({
    required ConversationModel conversation,
    required String currentUid,
  }) async {
    final otherUid = conversation.otherMemberId(currentUid);
    if (otherUid == null || otherUid.isEmpty) return null;

    final info = conversation.infoFor(otherUid);
    if (info != null) {
      final name = info["name"] ?? "";
      final email = info["email"] ?? "";
      final photoUrl = info["photoUrl"] ?? "";
      if (name.trim().isNotEmpty || email.trim().isNotEmpty) {
        return UserModel(
          uid: otherUid,
          name: name,
          email: email,
          photoUrl: photoUrl,
        );
      }
    }

    return _userService.getUserById(otherUid);
  }

  Future<bool> _areFriends(String uidA, String uidB) async {
    final a = uidA.trim();
    final b = uidB.trim();
    if (a.isEmpty || b.isEmpty || a == b) return false;

    final doc = await _friendRef(a, b).get();
    return doc.exists;
  }

  DocumentReference<Map<String, dynamic>> _friendRef(
    String uid,
    String friendUid,
  ) {
    return _userRef.doc(uid).collection("friends").doc(friendUid);
  }

  Map<String, String> _memberInfo(UserModel? user) {
    return {
      "name": user?.name ?? "",
      "email": user?.email ?? "",
      "photoUrl": user?.photoUrl ?? "",
    };
  }

  String _previewText(String text) {
    final normalized = text.trim().replaceAll(RegExp(r"\s+"), " ");
    if (normalized.length <= 120) return normalized;
    return "${normalized.substring(0, 117)}...";
  }

  String _previewForLog(String text) {
    final normalized = text.trim().replaceAll(RegExp(r"\s+"), " ");
    if (normalized.length <= 50) return normalized;
    return "${normalized.substring(0, 50)}...";
  }

  Future<void> _ignoreNotificationFailure(
    Future<void> Function() action,
  ) async {
    try {
      await action();
      debugPrint("[ChatService] chat notification created");
    } catch (error, stackTrace) {
      debugPrint(
        "[ChatService] chat notification failed type=${error.runtimeType} "
        "message=$error\n$stackTrace",
      );
      // Chat delivery must not fail because notification creation failed.
    }
  }
}
