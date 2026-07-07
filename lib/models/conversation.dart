import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final String type;
  final List<String> memberIds;
  final Map<String, Map<String, String>> memberInfo;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final List<String> unreadBy;
  final List<String> isDeletedFor;
  final Map<String, DateTime> lastReadAtBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ConversationModel({
    required this.id,
    this.type = "direct",
    this.memberIds = const [],
    this.memberInfo = const {},
    this.lastMessage = "",
    this.lastMessageAt,
    this.lastSenderId,
    this.unreadBy = const [],
    this.isDeletedFor = const [],
    this.lastReadAtBy = const {},
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson({bool useServerTimestamps = false}) {
    final serverTimestamp = FieldValue.serverTimestamp();
    return {
      "id": id,
      "type": type,
      "memberIds": memberIds,
      "memberInfo": memberInfo,
      "lastMessage": lastMessage,
      "lastMessageAt": lastMessageAt == null
          ? null
          : Timestamp.fromDate(lastMessageAt!),
      "lastSenderId": lastSenderId,
      "unreadBy": unreadBy,
      "isDeletedFor": isDeletedFor,
      "lastReadAtBy": lastReadAtBy.map(
        (uid, readAt) => MapEntry(uid, Timestamp.fromDate(readAt)),
      ),
      "createdAt": useServerTimestamps || createdAt == null
          ? serverTimestamp
          : Timestamp.fromDate(createdAt!),
      "updatedAt": useServerTimestamps || updatedAt == null
          ? serverTimestamp
          : Timestamp.fromDate(updatedAt!),
    };
  }

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: _stringFromJson(json["id"]),
      type: _typeFromJson(json["type"]),
      memberIds: _stringListFromJson(json["memberIds"]),
      memberInfo: _memberInfoFromJson(json["memberInfo"]),
      lastMessage: _stringFromJson(json["lastMessage"]),
      lastMessageAt: _dateTimeFromJson(json["lastMessageAt"]),
      lastSenderId: _nullableStringFromJson(json["lastSenderId"]),
      unreadBy: _stringListFromJson(json["unreadBy"]),
      isDeletedFor: _stringListFromJson(json["isDeletedFor"]),
      lastReadAtBy: _readAtMapFromJson(json["lastReadAtBy"]),
      createdAt: _dateTimeFromJson(json["createdAt"]),
      updatedAt: _dateTimeFromJson(json["updatedAt"]),
    );
  }

  ConversationModel copyWith({
    String? id,
    String? type,
    List<String>? memberIds,
    Map<String, Map<String, String>>? memberInfo,
    String? lastMessage,
    DateTime? lastMessageAt,
    String? lastSenderId,
    List<String>? unreadBy,
    List<String>? isDeletedFor,
    Map<String, DateTime>? lastReadAtBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      memberIds: memberIds ?? this.memberIds,
      memberInfo: memberInfo ?? this.memberInfo,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      unreadBy: unreadBy ?? this.unreadBy,
      isDeletedFor: isDeletedFor ?? this.isDeletedFor,
      lastReadAtBy: lastReadAtBy ?? this.lastReadAtBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, String>? infoFor(String uid) {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return null;
    return memberInfo[normalizedUid];
  }

  String? otherMemberId(String currentUid) {
    final normalizedUid = currentUid.trim();
    if (normalizedUid.isEmpty) return null;
    for (final memberId in memberIds) {
      if (memberId.trim().isNotEmpty && memberId.trim() != normalizedUid) {
        return memberId.trim();
      }
    }
    return null;
  }

  bool isUnreadFor(String uid) {
    final normalizedUid = uid.trim();
    return normalizedUid.isNotEmpty && unreadBy.contains(normalizedUid);
  }

  DateTime? lastReadAtFor(String uid) {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return null;
    return lastReadAtBy[normalizedUid];
  }

  static String _typeFromJson(dynamic value) {
    final type = _stringFromJson(value).trim();
    return type.isEmpty ? "direct" : type;
  }

  static Map<String, Map<String, String>> _memberInfoFromJson(dynamic value) {
    if (value is! Map) return {};

    final result = <String, Map<String, String>>{};
    for (final entry in value.entries) {
      final uid = entry.key?.toString().trim() ?? "";
      if (uid.isEmpty || entry.value is! Map) continue;

      final rawInfo = entry.value as Map;
      result[uid] = {
        "name": _stringFromJson(rawInfo["name"]),
        "email": _stringFromJson(rawInfo["email"]),
        "photoUrl": _stringFromJson(rawInfo["photoUrl"]),
      };
    }
    return result;
  }

  static List<String> _stringListFromJson(dynamic value) {
    if (value == null) return [];
    if (value is Iterable) {
      return value
          .map((item) => item?.toString().trim() ?? "")
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return [value.trim()];
    }
    return [];
  }

  static Map<String, DateTime> _readAtMapFromJson(dynamic value) {
    if (value is! Map) return {};

    final result = <String, DateTime>{};
    for (final entry in value.entries) {
      final uid = entry.key?.toString().trim() ?? "";
      final readAt = _dateTimeFromJson(entry.value);
      if (uid.isNotEmpty && readAt != null) {
        result[uid] = readAt;
      }
    }
    return result;
  }

  static String _stringFromJson(dynamic value) {
    if (value == null) return "";
    if (value is String) return value;
    return value.toString();
  }

  static String? _nullableStringFromJson(dynamic value) {
    final result = _stringFromJson(value).trim();
    return result.isEmpty ? null : result;
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
