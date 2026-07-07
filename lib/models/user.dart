import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;

  final int totalTasks;
  final int completedTasks;
  final int ownedProjects;
  final int joinedProjects;

  final DateTime? createdAt;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl = '',
    this.totalTasks = 0,
    this.completedTasks = 0,
    this.ownedProjects = 0,
    this.joinedProjects = 0,
    this.createdAt,
  });

  // Firebase
  Map<String, dynamic> toJson({bool isCreate = false}) {
    return {
      "uid": uid,
      "name": name,
      "email": email,
      "photoUrl": photoUrl,
      "totalTasks": totalTasks,
      "completedTasks": completedTasks,
      "ownedProjects": ownedProjects,
      "joinedProjects": joinedProjects,
      "createdAt": isCreate ? FieldValue.serverTimestamp() : createdAt,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: _stringFromJson(json["uid"]),
      name: _stringFromJson(json["name"]),
      email: _stringFromJson(json["email"]),
      photoUrl: _stringFromJson(json["photoUrl"]),
      totalTasks: _intFromJson(json["totalTasks"]),
      completedTasks: _intFromJson(json["completedTasks"]),
      ownedProjects: _intFromJson(json["ownedProjects"]),
      joinedProjects: _intFromJson(json["joinedProjects"]),
      createdAt: _dateTimeFromJson(json["createdAt"]),
    );
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? photoUrl,
    int? totalTasks,
    int? completedTasks,
    int? ownedProjects,
    int? joinedProjects,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      totalTasks: totalTasks ?? this.totalTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      ownedProjects: ownedProjects ?? this.ownedProjects,
      joinedProjects: joinedProjects ?? this.joinedProjects,
      createdAt: createdAt,
    );
  }

  double get completionRate =>
      totalTasks == 0 ? 0 : completedTasks / totalTasks;

  double get performanceScore {
    double score = completionRate * 100;
    score += ownedProjects * 2;
    score += joinedProjects * 1;
    return score;
  }

  // tạo factory model rỗng với các tham số mặc định
  factory UserModel.empty() {
    return UserModel(
      uid: "",
      name: "",
      email: "",
      photoUrl: "",
      totalTasks: 0,
      completedTasks: 0,
      ownedProjects: 0,
      joinedProjects: 0,
      createdAt: null,
    );
  }

  static String _stringFromJson(dynamic value) {
    if (value == null) return "";
    if (value is String) return value;
    return value.toString();
  }

  static int _intFromJson(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
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
