import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:todo/models/friend.dart';
import 'package:todo/models/friend_request.dart';
import 'package:todo/models/user.dart';
import 'package:todo/services/notificationService.dart';
import 'package:todo/services/userService.dart';

class FriendService {
  final _db = FirebaseFirestore.instance;
  final _requestRef = FirebaseFirestore.instance.collection("friendRequests");
  final _userRef = FirebaseFirestore.instance.collection("users");
  final _userService = UserService();
  final _notificationService = NotificationService();

  String friendshipId(String uidA, String uidB) {
    final ids = [uidA.trim(), uidB.trim()]..sort();
    return "${ids[0]}_${ids[1]}";
  }

  Future<FriendRequestModel> sendFriendRequest({
    required String senderId,
    required String receiverId,
  }) async {
    final sender = senderId.trim();
    final receiver = receiverId.trim();

    if (sender.isEmpty || receiver.isEmpty) {
      throw ArgumentError("Thiếu thông tin người gửi hoặc người nhận.");
    }
    if (sender == receiver) {
      throw ArgumentError("Bạn không thể gửi lời mời kết bạn cho chính mình.");
    }

    final status = await getFriendshipStatus(
      currentUserId: sender,
      targetUserId: receiver,
    );

    if (status.isFriend) {
      throw StateError("Hai người đã là bạn bè.");
    }
    if (status.isOutgoingPending) {
      throw StateError("Bạn đã gửi lời mời kết bạn cho người này.");
    }
    if (status.isIncomingPending) {
      throw StateError("Người này đã gửi lời mời kết bạn cho bạn.");
    }

    final docRef = _requestRef.doc();
    final request = FriendRequestModel(
      id: docRef.id,
      senderId: sender,
      receiverId: receiver,
    );

    await docRef.set(request.toJson(useServerCreatedAt: true));

    final senderProfile = await _userService.getUserById(sender);
    await _ignoreNotificationFailure(() {
      return _notificationService.createFriendRequestNotification(
        requestId: docRef.id,
        senderId: sender,
        receiverId: receiver,
        senderName: senderProfile?.name ?? "",
      );
    });

    return request.copyWith(id: docRef.id);
  }

  Stream<List<FriendRequestModel>> streamIncomingRequests(String uid) {
    return _requestRef
        .where("receiverId", isEqualTo: uid.trim())
        .where("status", isEqualTo: FriendRequestStatus.pending)
        .snapshots()
        .map(_requestsFromSnapshot);
  }

  Stream<List<FriendRequestModel>> streamOutgoingRequests(String uid) {
    return _requestRef
        .where("senderId", isEqualTo: uid.trim())
        .where("status", isEqualTo: FriendRequestStatus.pending)
        .snapshots()
        .map(_requestsFromSnapshot);
  }

  Stream<List<UserModel>> streamFriends(String uid) {
    final userId = uid.trim();
    if (userId.isEmpty) {
      return Stream.value(<UserModel>[]);
    }

    return _userRef
        .doc(userId)
        .collection("friends")
        .orderBy("createdAt", descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final friendIds = snapshot.docs
              .map((doc) {
                final data = doc.data();
                final friendUid = (data["friendUid"] ?? doc.id).toString();
                return friendUid.trim();
              })
              .where((id) => id.isNotEmpty)
              .toList();

          final profiles = await _userService.getUsersByIds(friendIds);
          profiles.sort((a, b) {
            final aName = a.name.trim().isEmpty ? a.email : a.name;
            final bName = b.name.trim().isEmpty ? b.email : b.name;
            return aName.toLowerCase().compareTo(bName.toLowerCase());
          });
          return profiles;
        });
  }

  Future<FriendshipStatusResult> getFriendshipStatus({
    required String currentUserId,
    required String targetUserId,
  }) async {
    final current = currentUserId.trim();
    final target = targetUserId.trim();

    if (current.isEmpty || target.isEmpty) {
      return const FriendshipStatusResult(status: FriendshipStatus.none);
    }
    if (current == target) {
      return const FriendshipStatusResult(status: FriendshipStatus.self);
    }

    final friendDoc = await _userRef
        .doc(current)
        .collection("friends")
        .doc(target)
        .get();
    if (friendDoc.exists) {
      return const FriendshipStatusResult(status: FriendshipStatus.friends);
    }

    final outgoing = await _pendingRequest(
      senderId: current,
      receiverId: target,
    );
    if (outgoing != null) {
      return FriendshipStatusResult(
        status: FriendshipStatus.outgoingPending,
        request: outgoing,
      );
    }

    final incoming = await _pendingRequest(
      senderId: target,
      receiverId: current,
    );
    if (incoming != null) {
      return FriendshipStatusResult(
        status: FriendshipStatus.incomingPending,
        request: incoming,
      );
    }

    return const FriendshipStatusResult(status: FriendshipStatus.none);
  }

  Future<void> acceptFriendRequest({
    required FriendRequestModel request,
    required String currentUserId,
  }) async {
    final current = currentUserId.trim();
    if (current.isEmpty || current != request.receiverId.trim()) {
      throw StateError("Bạn không có quyền chấp nhận lời mời này.");
    }
    if (request.status != FriendRequestStatus.pending) {
      throw StateError("Lời mời kết bạn không còn hiệu lực.");
    }

    final sender = request.senderId.trim();
    final receiver = request.receiverId.trim();
    final friendship = friendshipId(sender, receiver);
    final senderProfile = await _userService.getUserById(sender);
    final receiverProfile = await _userService.getUserById(receiver);
    final now = FieldValue.serverTimestamp();
    final batch = _db.batch();

    batch.update(_requestRef.doc(request.id), {
      "status": FriendRequestStatus.accepted,
      "updatedAt": now,
      "respondedAt": now,
    });

    batch.set(
      _friendRef(sender, receiver),
      _friendData(
        uid: sender,
        friendUid: receiver,
        friendshipId: friendship,
        requestId: request.id,
        friend: receiverProfile,
      ),
      SetOptions(merge: true),
    );
    batch.set(
      _friendRef(receiver, sender),
      _friendData(
        uid: receiver,
        friendUid: sender,
        friendshipId: friendship,
        requestId: request.id,
        friend: senderProfile,
      ),
      SetOptions(merge: true),
    );

    await batch.commit();

    await _ignoreNotificationFailure(() {
      return _notificationService.createFriendRequestAcceptedNotification(
        receiverId: sender,
        actorId: receiver,
        actorName: receiverProfile?.name ?? "",
      );
    });
  }

  Future<void> declineFriendRequest({
    required FriendRequestModel request,
    required String currentUserId,
  }) async {
    final current = currentUserId.trim();
    if (current.isEmpty || current != request.receiverId.trim()) {
      throw StateError("Bạn không có quyền từ chối lời mời này.");
    }

    await _requestRef.doc(request.id).update({
      "status": FriendRequestStatus.declined,
      "updatedAt": FieldValue.serverTimestamp(),
      "respondedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelFriendRequest({
    required FriendRequestModel request,
    required String currentUserId,
  }) async {
    final current = currentUserId.trim();
    if (current.isEmpty || current != request.senderId.trim()) {
      throw StateError("Bạn không có quyền hủy lời mời này.");
    }

    await _requestRef.doc(request.id).update({
      "status": FriendRequestStatus.cancelled,
      "updatedAt": FieldValue.serverTimestamp(),
      "cancelledAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> unfriend({
    required String currentUserId,
    required String friendUid,
  }) async {
    final current = currentUserId.trim();
    final friend = friendUid.trim();
    if (current.isEmpty || friend.isEmpty || current == friend) return;

    final batch = _db.batch();
    batch.delete(_friendRef(current, friend));
    batch.delete(_friendRef(friend, current));
    await batch.commit();
  }

  List<FriendRequestModel> _requestsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final requests = snapshot.docs
        .map(
          (doc) => FriendRequestModel.fromJson({...doc.data(), "id": doc.id}),
        )
        .toList();
    requests.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return requests;
  }

  Future<FriendRequestModel?> _pendingRequest({
    required String senderId,
    required String receiverId,
  }) async {
    final snapshot = await _requestRef
        .where("senderId", isEqualTo: senderId.trim())
        .where("receiverId", isEqualTo: receiverId.trim())
        .where("status", isEqualTo: FriendRequestStatus.pending)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return FriendRequestModel.fromJson({...doc.data(), "id": doc.id});
  }

  DocumentReference<Map<String, dynamic>> _friendRef(
    String uid,
    String friendUid,
  ) {
    return _userRef.doc(uid).collection("friends").doc(friendUid);
  }

  Map<String, dynamic> _friendData({
    required String uid,
    required String friendUid,
    required String friendshipId,
    required String requestId,
    required UserModel? friend,
  }) {
    return FriendModel(
      uid: uid,
      friendUid: friendUid,
      friendshipId: friendshipId,
      requestId: requestId,
      friendName: friend?.name ?? "",
      friendEmail: friend?.email ?? "",
      friendPhotoUrl: friend?.photoUrl ?? "",
    ).toJson(useServerCreatedAt: true);
  }

  Future<void> _ignoreNotificationFailure(
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      // Friend actions should not fail because the notification write failed.
    }
  }
}
