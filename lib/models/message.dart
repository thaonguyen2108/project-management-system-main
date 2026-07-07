import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime? createdAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    this.createdAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  Map<String, dynamic> toJson({bool useServerCreatedAt = false}) {
    return {
      "id": id,
      "conversationId": conversationId,
      "senderId": senderId,
      "text": text,
      "createdAt": useServerCreatedAt || createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      "isDeleted": isDeleted,
      "deletedAt": deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
    };
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: _stringFromJson(json["id"]),
      conversationId: _stringFromJson(json["conversationId"]),
      senderId: _stringFromJson(json["senderId"]),
      text: _stringFromJson(json["text"]),
      createdAt: _dateTimeFromJson(json["createdAt"]),
      isDeleted: _boolFromJson(json["isDeleted"]),
      deletedAt: _dateTimeFromJson(json["deletedAt"]),
    );
  }

  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? text,
    DateTime? createdAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  static String _stringFromJson(dynamic value) {
    if (value == null) return "";
    if (value is String) return value;
    return value.toString();
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
