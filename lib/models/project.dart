import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectModel {
  final String id;
  final String name;
  final String description;
  final String? mainColor;
  final DateTime startTime;
  final DateTime deadline;

  final String ownerId;
  final List<String>? members;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final bool isArchived;

  ProjectModel({
    required this.id,
    required this.name,
    required this.description,
    this.mainColor,
    required this.startTime,
    required this.deadline,
    required this.ownerId,
    this.members,
    this.createdAt,
    this.updatedAt,
    this.isArchived = false,
  });

  // dùng cho Firebase
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "description": description,
      "mainColor": mainColor,
      "startTime": Timestamp.fromDate(startTime),
      "deadline": Timestamp.fromDate(deadline),
      "ownerId": ownerId,
      "members": members ?? [],

      // server time
      "createdAt": _timestampOrServer(createdAt),

      "updatedAt": FieldValue.serverTimestamp(),

      "isArchived": isArchived,
    };
  }

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    final startTime =
        _dateTimeFromJson(json["startTime"]) ??
        _dateTimeFromJson(json["createdAt"]) ??
        DateTime.now();

    return ProjectModel(
      id: _stringFromJson(json["id"]),
      name: _stringFromJson(json["name"]),
      description: _stringFromJson(json["description"]),
      mainColor: _nullableStringFromJson(json["mainColor"]),
      startTime: startTime,
      deadline: _dateTimeFromJson(json["deadline"]) ?? startTime,
      ownerId: _stringFromJson(json["ownerId"]),
      members: _stringListFromJson(json["members"]),

      createdAt: _dateTimeFromJson(json["createdAt"]),

      updatedAt: _dateTimeFromJson(json["updatedAt"]),

      isArchived: _boolFromJson(json["isArchived"]),
    );
  }

  ProjectModel copyWith({
    String? id,
    String? name,
    String? description,
    String? mainColor,
    DateTime? startTime,
    DateTime? deadline,
    String? ownerId,
    List<String>? members,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      mainColor: mainColor ?? this.mainColor,
      startTime: startTime ?? this.startTime,
      deadline: deadline ?? this.deadline,
      ownerId: ownerId ?? this.ownerId,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  // tạo factory model rỗng với các tham số mặc định
  factory ProjectModel.empty() {
    return ProjectModel(
      id: "",
      name: "",
      description: "",
      mainColor: null,
      startTime: DateTime.now(),
      deadline: DateTime.now(),
      ownerId: "",
      members: null,
      createdAt: null,
      updatedAt: null,
      isArchived: false,
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

  static bool _boolFromJson(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase().trim() == "true";
    return false;
  }
}
