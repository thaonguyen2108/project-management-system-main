import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String receiverId;
  final String type;
  final String title;
  final String body;
  final String targetType;
  final String? targetId;
  final String? projectId;
  final String? taskId;
  final String? actorId;
  final bool isRead;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? readAt;
  final DateTime? deletedAt;

  const NotificationModel({
    required this.id,
    required this.receiverId,
    required this.type,
    required this.title,
    required this.body,
    required this.targetType,
    this.targetId,
    this.projectId,
    this.taskId,
    this.actorId,
    this.isRead = false,
    this.isDeleted = false,
    this.createdAt,
    this.readAt,
    this.deletedAt,
  });

  Map<String, dynamic> toJson({bool useServerCreatedAt = false}) {
    return {
      "id": id,
      "receiverId": receiverId,
      "type": type,
      "title": title,
      "body": body,
      "targetType": targetType,
      "targetId": targetId,
      "projectId": projectId,
      "taskId": taskId,
      "actorId": actorId,
      "isRead": isRead,
      "isDeleted": isDeleted,
      "createdAt": useServerCreatedAt || createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      "readAt": readAt == null ? null : Timestamp.fromDate(readAt!),
      "deletedAt": deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: _stringFromJson(json["id"]),
      receiverId: _stringFromJson(json["receiverId"]),
      type: _stringFromJson(json["type"]),
      title: _stringFromJson(json["title"]),
      body: _stringFromJson(json["body"]),
      targetType: _targetTypeFromJson(json["targetType"]),
      targetId: _nullableStringFromJson(json["targetId"]),
      projectId: _nullableStringFromJson(json["projectId"]),
      taskId: _nullableStringFromJson(json["taskId"]),
      actorId: _nullableStringFromJson(json["actorId"]),
      isRead: _boolFromJson(json["isRead"]),
      isDeleted: _boolFromJson(json["isDeleted"]),
      createdAt: _dateTimeFromJson(json["createdAt"]),
      readAt: _dateTimeFromJson(json["readAt"]),
      deletedAt: _dateTimeFromJson(json["deletedAt"]),
    );
  }

  NotificationModel copyWith({
    String? id,
    String? receiverId,
    String? type,
    String? title,
    String? body,
    String? targetType,
    String? targetId,
    String? projectId,
    String? taskId,
    String? actorId,
    bool? isRead,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? readAt,
    DateTime? deletedAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      receiverId: receiverId ?? this.receiverId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      projectId: projectId ?? this.projectId,
      taskId: taskId ?? this.taskId,
      actorId: actorId ?? this.actorId,
      isRead: isRead ?? this.isRead,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  static String _targetTypeFromJson(dynamic value) {
    final targetType = _stringFromJson(value).trim();
    return targetType.isEmpty ? "none" : targetType;
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

  static bool _boolFromJson(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase().trim() == "true";
    return false;
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
