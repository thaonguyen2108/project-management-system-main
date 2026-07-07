import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String? projectId;

  final List<String>? dependsOnTaskID;

  final String title;
  final String description;

  final String status; // todo / doing / done / later
  final int priority; // 1-low 2-medium 3-high

  final DateTime deadline;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isArchived;
  final DateTime? archivedAt;
  final String? archivedBy;

  final String ownerId;
  final String assigneeId;

  TaskModel({
    required this.id,
    this.projectId,
    this.dependsOnTaskID,
    required this.title,
    required this.description,
    this.status = "todo",
    this.priority = 1,
    required this.deadline,
    this.createdAt,
    this.updatedAt,
    this.isArchived = false,
    this.archivedAt,
    this.archivedBy,
    required this.ownerId,
    required this.assigneeId,
  });

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "projectId": projectId,
      "dependsOnTaskID": dependsOnTaskID ?? [],
      "title": title,
      "description": description,
      "status": status,
      "priority": priority,
      "deadline": Timestamp.fromDate(deadline),
      "createdAt": _timestampOrServer(createdAt),
      "updatedAt": FieldValue.serverTimestamp(),
      "isArchived": isArchived,
      "archivedAt": archivedAt == null ? null : Timestamp.fromDate(archivedAt!),
      "archivedBy": archivedBy,
      "ownerId": ownerId,
      "assigneeId": assigneeId,
    };
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final createdAt = _dateTimeFromJson(json["createdAt"]);

    return TaskModel(
      id: _stringFromJson(json["id"]),
      projectId: _nullableStringFromJson(json["projectId"]),
      dependsOnTaskID: _stringListFromJson(json["dependsOnTaskID"]),
      title: _stringFromJson(json["title"]),
      description: _stringFromJson(json["description"]),
      status: _statusFromJson(json["status"]),
      priority: _intFromJson(json["priority"], fallback: 1),
      deadline:
          _dateTimeFromJson(json["deadline"]) ?? createdAt ?? DateTime.now(),
      createdAt: createdAt,
      updatedAt: _dateTimeFromJson(json["updatedAt"]),
      isArchived: _boolFromJson(json["isArchived"]),
      archivedAt: _dateTimeFromJson(json["archivedAt"]),
      archivedBy: _nullableStringFromJson(json["archivedBy"]),
      ownerId: _stringFromJson(json["ownerId"]),
      assigneeId: _stringFromJson(json["assigneeId"]),
    );
  }

  TaskModel copyWith({
    String? id,
    String? projectId,
    List<String>? dependsOnTaskID,
    @Deprecated("Use dependsOnTaskID instead.") List<String>? ndsOnTaskID,
    String? title,
    String? description,
    String? status,
    int? priority,
    DateTime? deadline,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
    DateTime? archivedAt,
    String? archivedBy,
    String? ownerId,
    String? assigneeId,
  }) {
    return TaskModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      dependsOnTaskID: dependsOnTaskID ?? ndsOnTaskID ?? this.dependsOnTaskID,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
      archivedBy: archivedBy ?? this.archivedBy,
      ownerId: ownerId ?? this.ownerId,
      assigneeId: assigneeId ?? this.assigneeId,
    );
  }

  // tạo factory model rỗng với các tham số mặc định
  factory TaskModel.empty() {
    return TaskModel(
      id: FirebaseFirestore.instance.collection('tasks').doc().id,
      projectId: null,
      dependsOnTaskID: null,
      title: "",
      description: "",
      status: "todo",
      priority: 1,
      deadline: DateTime.now(),
      createdAt: null,
      updatedAt: null,
      isArchived: false,
      archivedAt: null,
      archivedBy: null,
      ownerId: "",
      assigneeId: "",
    );
  }

  static Object _timestampOrServer(DateTime? value) {
    return value == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(value);
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

  static int _intFromJson(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
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

  static String _statusFromJson(dynamic value) {
    final status = _stringFromJson(value).trim();
    return status.isEmpty ? "todo" : status;
  }

  static bool _boolFromJson(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase().trim() == "true";
    return false;
  }
}
