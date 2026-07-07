import 'package:cloud_firestore/cloud_firestore.dart';

class FriendModel {
  final String uid;
  final String friendUid;
  final String friendshipId;
  final String requestId;
  final String friendName;
  final String friendEmail;
  final String friendPhotoUrl;
  final DateTime? createdAt;

  const FriendModel({
    required this.uid,
    required this.friendUid,
    required this.friendshipId,
    this.requestId = "",
    this.friendName = "",
    this.friendEmail = "",
    this.friendPhotoUrl = "",
    this.createdAt,
  });

  Map<String, dynamic> toJson({bool useServerCreatedAt = false}) {
    return {
      "uid": uid,
      "friendUid": friendUid,
      "friendshipId": friendshipId,
      "requestId": requestId,
      "friendName": friendName,
      "friendEmail": friendEmail,
      "friendPhotoUrl": friendPhotoUrl,
      "createdAt": useServerCreatedAt || createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      uid: _stringFromJson(json["uid"]),
      friendUid: _stringFromJson(json["friendUid"]),
      friendshipId: _stringFromJson(json["friendshipId"]),
      requestId: _stringFromJson(json["requestId"]),
      friendName: _stringFromJson(json["friendName"]),
      friendEmail: _stringFromJson(json["friendEmail"]),
      friendPhotoUrl: _stringFromJson(json["friendPhotoUrl"]),
      createdAt: _dateTimeFromJson(json["createdAt"]),
    );
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
