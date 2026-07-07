import 'package:cloud_firestore/cloud_firestore.dart';

class FriendRequestStatus {
  static const pending = "pending";
  static const accepted = "accepted";
  static const declined = "declined";
  static const cancelled = "cancelled";
}

class FriendshipStatus {
  static const self = "self";
  static const friends = "friends";
  static const incomingPending = "incoming_pending";
  static const outgoingPending = "outgoing_pending";
  static const none = "none";
}

class FriendshipStatusResult {
  final String status;
  final FriendRequestModel? request;

  const FriendshipStatusResult({required this.status, this.request});

  bool get isSelf => status == FriendshipStatus.self;
  bool get isFriend => status == FriendshipStatus.friends;
  bool get isIncomingPending => status == FriendshipStatus.incomingPending;
  bool get isOutgoingPending => status == FriendshipStatus.outgoingPending;
}

class FriendRequestModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? respondedAt;
  final DateTime? cancelledAt;

  const FriendRequestModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.status = FriendRequestStatus.pending,
    this.createdAt,
    this.updatedAt,
    this.respondedAt,
    this.cancelledAt,
  });

  Map<String, dynamic> toJson({bool useServerCreatedAt = false}) {
    final serverTimestamp = FieldValue.serverTimestamp();
    return {
      "id": id,
      "senderId": senderId,
      "receiverId": receiverId,
      "status": status,
      "createdAt": useServerCreatedAt || createdAt == null
          ? serverTimestamp
          : Timestamp.fromDate(createdAt!),
      "updatedAt": updatedAt == null
          ? serverTimestamp
          : Timestamp.fromDate(updatedAt!),
      "respondedAt": respondedAt == null
          ? null
          : Timestamp.fromDate(respondedAt!),
      "cancelledAt": cancelledAt == null
          ? null
          : Timestamp.fromDate(cancelledAt!),
    };
  }

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      id: _stringFromJson(json["id"]),
      senderId: _stringFromJson(json["senderId"]),
      receiverId: _stringFromJson(json["receiverId"]),
      status: _statusFromJson(json["status"]),
      createdAt: _dateTimeFromJson(json["createdAt"]),
      updatedAt: _dateTimeFromJson(json["updatedAt"]),
      respondedAt: _dateTimeFromJson(json["respondedAt"]),
      cancelledAt: _dateTimeFromJson(json["cancelledAt"]),
    );
  }

  FriendRequestModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? respondedAt,
    DateTime? cancelledAt,
  }) {
    return FriendRequestModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      respondedAt: respondedAt ?? this.respondedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }

  static String _statusFromJson(dynamic value) {
    final status = _stringFromJson(value).trim();
    switch (status) {
      case FriendRequestStatus.accepted:
      case FriendRequestStatus.declined:
      case FriendRequestStatus.cancelled:
      case FriendRequestStatus.pending:
        return status;
      default:
        return FriendRequestStatus.pending;
    }
  }

  static String _stringFromJson(dynamic value) {
    if (value == null) return "";
    if (value is String) return value;
    return value.toString();
  }

  static DateTime? _dateTimeFromJson(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }
}
