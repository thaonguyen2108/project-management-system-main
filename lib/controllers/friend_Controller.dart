import 'package:todo/models/friend_request.dart';
import 'package:todo/models/user.dart';
import 'package:todo/services/friendService.dart';

class FriendController {
  final FriendService _friendService = FriendService();

  Stream<List<UserModel>> streamFriends(String uid) {
    return _friendService.streamFriends(uid);
  }

  Stream<List<FriendRequestModel>> streamIncomingRequests(String uid) {
    return _friendService.streamIncomingRequests(uid);
  }

  Stream<List<FriendRequestModel>> streamOutgoingRequests(String uid) {
    return _friendService.streamOutgoingRequests(uid);
  }

  Future<FriendshipStatusResult> getFriendshipStatus({
    required String currentUserId,
    required String targetUserId,
  }) {
    return _friendService.getFriendshipStatus(
      currentUserId: currentUserId,
      targetUserId: targetUserId,
    );
  }

  Future<String?> sendFriendRequest({
    required String senderId,
    required String receiverId,
  }) async {
    try {
      await _friendService.sendFriendRequest(
        senderId: senderId,
        receiverId: receiverId,
      );
      return null;
    } catch (e) {
      return _friendlyError(e, "Không thể gửi lời mời kết bạn.");
    }
  }

  Future<String?> acceptFriendRequest({
    required FriendRequestModel request,
    required String currentUserId,
  }) async {
    try {
      await _friendService.acceptFriendRequest(
        request: request,
        currentUserId: currentUserId,
      );
      return null;
    } catch (e) {
      return _friendlyError(e, "Không thể chấp nhận lời mời kết bạn.");
    }
  }

  Future<String?> declineFriendRequest({
    required FriendRequestModel request,
    required String currentUserId,
  }) async {
    try {
      await _friendService.declineFriendRequest(
        request: request,
        currentUserId: currentUserId,
      );
      return null;
    } catch (e) {
      return _friendlyError(e, "Không thể từ chối lời mời kết bạn.");
    }
  }

  Future<String?> cancelFriendRequest({
    required FriendRequestModel request,
    required String currentUserId,
  }) async {
    try {
      await _friendService.cancelFriendRequest(
        request: request,
        currentUserId: currentUserId,
      );
      return null;
    } catch (e) {
      return _friendlyError(e, "Không thể hủy lời mời kết bạn.");
    }
  }

  Future<String?> unfriend({
    required String currentUserId,
    required String friendUid,
  }) async {
    try {
      await _friendService.unfriend(
        currentUserId: currentUserId,
        friendUid: friendUid,
      );
      return null;
    } catch (e) {
      return _friendlyError(e, "Không thể hủy kết bạn.");
    }
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
