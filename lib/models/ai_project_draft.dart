class AiProjectDraft {
  final String replyText;
  final String name;
  final String description;
  final int durationDays;
  final List<AiTaskDraft> tasks;

  const AiProjectDraft({
    required this.replyText,
    required this.name,
    required this.description,
    required this.durationDays,
    required this.tasks,
  });

  bool get hasProjectContent =>
      name.trim().isNotEmpty ||
      description.trim().isNotEmpty ||
      tasks.isNotEmpty;

  factory AiProjectDraft.fromJson(Map<String, dynamic> json) {
    final project = _mapFromJson(json["project"]);
    final tasks = _listFromJson(
      project["tasks"],
    ).map((item) => AiTaskDraft.fromJson(_mapFromJson(item))).toList();

    return AiProjectDraft(
      replyText: _stringFromJson(json["replyText"]),
      name: _stringFromJson(project["name"]),
      description: _stringFromJson(project["description"]),
      durationDays: _clampInt(project["durationDays"], 1, 365, 14),
      tasks: tasks,
    );
  }

  static Map<String, dynamic> _mapFromJson(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  static List<dynamic> _listFromJson(dynamic value) {
    if (value is List) return value;
    if (value is Iterable) return value.toList();
    return <dynamic>[];
  }

  static String _stringFromJson(dynamic value) {
    if (value == null) return "";
    if (value is String) return value.trim();
    return value.toString().trim();
  }

  static int _clampInt(dynamic value, int min, int max, int fallback) {
    int? parsed;
    if (value is int) parsed = value;
    if (value is num) parsed = value.round();
    if (value is String) parsed = int.tryParse(value.trim());
    final result = parsed ?? fallback;
    if (result < min) return min;
    if (result > max) return max;
    return result;
  }
}

class AiTaskDraft {
  final String title;
  final String description;
  final int offsetDays;
  final int priority;

  const AiTaskDraft({
    required this.title,
    required this.description,
    required this.offsetDays,
    required this.priority,
  });

  factory AiTaskDraft.fromJson(Map<String, dynamic> json) {
    return AiTaskDraft(
      title: AiProjectDraft._stringFromJson(json["title"]),
      description: AiProjectDraft._stringFromJson(json["description"]),
      offsetDays: AiProjectDraft._clampInt(json["offsetDays"], 0, 365, 0),
      priority: AiProjectDraft._clampInt(json["priority"], 1, 3, 2),
    );
  }
}
