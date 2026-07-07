import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:todo/core/ai_config.dart';
import 'package:todo/models/ai_project_draft.dart';

class AiAssistantService {
  static const String _model = 'gemini-2.5-flash';
  static const int _maxPromptLength = 2000;
  static const Duration _timeout = Duration(seconds: 30);
  static const bool _debugAi = false;

  final FirebaseAuth _auth;
  final http.Client _client;

  AiAssistantService({FirebaseAuth? auth, http.Client? client})
    : _auth = auth ?? FirebaseAuth.instance,
      _client = client ?? http.Client();

  Future<AiProjectDraft> generateProjectDraft(String prompt) async {
    final normalizedPrompt = prompt.trim();
    if (normalizedPrompt.isEmpty) {
      _logException(
        "validation_empty_prompt",
        ArgumentError("empty prompt"),
        StackTrace.current,
      );
    }
    if (normalizedPrompt.length > _maxPromptLength) {
      _logException(
        "validation_prompt_too_long",
        ArgumentError("prompt length ${normalizedPrompt.length}"),
        StackTrace.current,
      );
    }
    if (normalizedPrompt.isEmpty) {
      throw ArgumentError("Nội dung yêu cầu không được để trống.");
    }
    if (normalizedPrompt.length > _maxPromptLength) {
      throw ArgumentError("Nội dung yêu cầu tối đa $_maxPromptLength ký tự.");
    }

    final apiKey = AiConfig.geminiApiKey.trim();
    if (apiKey.isEmpty) {
      final error = StateError(
        "Chưa cấu hình Gemini API key. Hãy chạy app với --dart-define=GEMINI_API_KEY=...",
      );
      _logException("missing_key", error, StackTrace.current);
      throw error;
    }

    try {
      final responseText = await _generateContent(
        prompt: normalizedPrompt,
        apiKey: apiKey,
      );
      return _draftFromText(responseText, normalizedPrompt);
    } on ArgumentError {
      rethrow;
    } on StateError catch (error, stackTrace) {
      _logException("state_error", error, stackTrace);
      if (error.message.contains("Gemini API key")) rethrow;
      return _fallbackDraft(
        normalizedPrompt,
        parseFailed: false,
        reason: _classifyStateError(error),
      );
    } on TimeoutException catch (error, stackTrace) {
      _logException("timeout", error, stackTrace);
      return _fallbackDraft(
        normalizedPrompt,
        parseFailed: false,
        reason: "timeout: ${error.message ?? error.toString()}",
      );
    } catch (error, stackTrace) {
      _logException("unknown", error, stackTrace);
      return _fallbackDraft(
        normalizedPrompt,
        parseFailed: false,
        reason: "unknown: $error",
      );
    }
  }

  Future<String> _generateContent({
    required String prompt,
    required String apiKey,
  }) async {
    final firstResponse = await _postGemini(
      apiKey: apiKey,
      body: _requestBody(prompt, useJsonMimeType: true),
    );

    if (firstResponse.statusCode == 200) {
      try {
        return _extractText(firstResponse.body);
      } catch (error, stackTrace) {
        _logException("parse_gemini_http_response", error, stackTrace);
        _log("Raw Gemini HTTP response before parse:");
        _log(_preview(firstResponse.body));
        // Some Gemini responses can still be wrapped or malformed even with
        // responseMimeType. Retry once with a simpler request before fallback.
      }
    }

    final fallbackResponse = await _postGemini(
      apiKey: apiKey,
      body: _requestBody(prompt, useJsonMimeType: false),
    );
    if (fallbackResponse.statusCode == 200) {
      return _extractText(fallbackResponse.body);
    }

    final failureType = _classifyHttpFailure(fallbackResponse);
    _log("Gemini failure type = $failureType");
    throw StateError(
      "$failureType: Gemini HTTP ${fallbackResponse.statusCode}",
    );
  }

  Future<http.Response> _postGemini({
    required String apiKey,
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.https(
      "generativelanguage.googleapis.com",
      "/v1beta/models/$_model:generateContent",
      {"key": apiKey},
    );

    final safeEndpoint = Uri.https(
      "generativelanguage.googleapis.com",
      "/v1beta/models/$_model:generateContent",
    );
    _log("Endpoint = $safeEndpoint");

    final response = await _client
        .post(
          uri,
          headers: const {"Content-Type": "application/json"},
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      _logImportant("Gemini HTTP status = ${response.statusCode}");
      _logImportant("Gemini error body = ${_preview(response.body)}");
    } else {
      _log("HTTP status code = ${response.statusCode}");
    }

    return response;
  }

  Map<String, dynamic> _requestBody(
    String userPrompt, {
    required bool useJsonMimeType,
  }) {
    final generationConfig = <String, dynamic>{"temperature": 0.4};
    if (useJsonMimeType) {
      generationConfig["responseMimeType"] = "application/json";
    }

    return {
      "contents": [
        {
          "role": "user",
          "parts": [
            {"text": _buildPrompt(userPrompt)},
          ],
        },
      ],
      "generationConfig": generationConfig,
    };
  }

  String _buildPrompt(String userPrompt) {
    final userName = _auth.currentUser?.displayName?.trim() ?? "";
    final displayName = userName.isEmpty ? "" : "Tên người dùng: $userName";
    final today = DateTime.now().toIso8601String();

    return """
Bạn là trợ lý AI trong app ToDo/quản lý dự án.
Hôm nay: $today
$displayName

Nhiệm vụ: đọc yêu cầu của người dùng và chỉ hỗ trợ nội dung liên quan đến dự án, công việc, kế hoạch, chia task.
Nếu yêu cầu nằm ngoài phạm vi dự án/công việc/quản lý công việc, trả replyText giải thích ngắn gọn rằng bạn chỉ hỗ trợ nội dung liên quan đến dự án và công việc trong ứng dụng, project.tasks phải là [].

Yêu cầu người dùng:
$userPrompt

Chỉ trả JSON hợp lệ, không markdown, không code fence, không giải thích ngoài JSON.
Schema:
{
  "replyText": "Chuỗi tiếng Việt giải thích ngắn gọn gợi ý dự án",
  "project": {
    "name": "Tên dự án",
    "description": "Mô tả dự án",
    "durationDays": 14,
    "tasks": [
      {
        "title": "Tên công việc",
        "description": "Mô tả công việc",
        "offsetDays": 1,
        "priority": 2
      }
    ]
  }
}

Quy tắc:
- Tên dự án ngắn gọn, rõ nghĩa.
- Mô tả thực tế, không màu mè.
- Tạo 3 đến 8 task nếu yêu cầu phù hợp.
- Task phải rõ và có thể làm được.
- offsetDays là số ngày kể từ ngày bắt đầu dự án, trong khoảng 0..365.
- priority chỉ là 1, 2 hoặc 3.
- Không tạo assigneeId, ownerId.
- Không tự ghi Firestore.
""";
  }

  String _extractText(String responseBody) {
    final decoded = jsonDecode(responseBody);
    final candidates = decoded is Map ? decoded["candidates"] : null;
    if (candidates is! List || candidates.isEmpty) {
      throw StateError("Gemini không trả về nội dung.");
    }

    final firstCandidate = candidates.first;
    if (firstCandidate is! Map) {
      throw StateError("Gemini trả về nội dung không hợp lệ.");
    }

    final content = firstCandidate["content"];
    final parts = content is Map ? content["parts"] : null;
    if (parts is! List || parts.isEmpty) {
      throw StateError("Gemini không trả về nội dung dạng text.");
    }

    final firstPart = parts.first;
    final text = firstPart is Map ? firstPart["text"] : null;
    if (text is! String || text.trim().isEmpty) {
      throw StateError("Gemini không trả về nội dung dạng text.");
    }

    return text;
  }

  AiProjectDraft _draftFromText(String responseText, String originalPrompt) {
    try {
      final jsonText = _stripCodeFence(responseText);
      final decoded = jsonDecode(jsonText);
      final normalizedJson = _normalizeDraftJson(_mapFromJson(decoded));
      return AiProjectDraft.fromJson(normalizedJson);
    } catch (error, stackTrace) {
      _logException("parse_ai_draft_json", error, stackTrace);
      _log("Raw Gemini text before draft JSON parse:");
      _logImportant(_preview(responseText));
      return _fallbackDraft(
        originalPrompt,
        parseFailed: true,
        reason: "parse: $error",
      );
    }
  }

  Map<String, dynamic> _normalizeDraftJson(Map<String, dynamic> json) {
    final project = _mapFromJson(json["project"]);
    final tasks = _listFromJson(
      project["tasks"],
    ).map((item) => _mapFromJson(item)).take(10).toList();

    return {
      "replyText": json["replyText"],
      "project": {...project, "tasks": tasks},
    };
  }

  String _stripCodeFence(String text) {
    var value = text.trim();
    if (value.startsWith("```")) {
      value = value.replaceFirst(
        RegExp(r"^```(?:json)?\s*", caseSensitive: false),
        "",
      );
      value = value.replaceFirst(RegExp(r"\s*```$"), "");
    }

    final firstBrace = value.indexOf("{");
    final lastBrace = value.lastIndexOf("}");
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      value = value.substring(firstBrace, lastBrace + 1);
    }

    return value.trim();
  }

  AiProjectDraft _fallbackDraft(
    String prompt, {
    required bool parseFailed,
    required String reason,
  }) {
    _logFallback(reason);

    final replyText = parseFailed
        ? "AI chưa trả về đúng định dạng, hệ thống tạo gợi ý cơ bản để bạn chỉnh sửa."
        : "Không thể kết nối AI ổn định, hệ thống tạo gợi ý cơ bản để bạn chỉnh sửa.";

    return AiProjectDraft.fromJson({
      "replyText": replyText,
      "project": {
        "name": _fallbackName(prompt),
        "description": "Dự án được tạo từ yêu cầu: $prompt",
        "durationDays": 14,
        "tasks": [
          {
            "title": "Phân tích yêu cầu",
            "description": "Làm rõ mục tiêu, phạm vi và kết quả cần đạt.",
            "offsetDays": 1,
            "priority": 2,
          },
          {
            "title": "Lập kế hoạch thực hiện",
            "description": "Chia nhỏ đầu việc, thời gian và thứ tự ưu tiên.",
            "offsetDays": 2,
            "priority": 2,
          },
          {
            "title": "Thiết kế chức năng chính",
            "description": "Xác định cấu trúc, màn hình và luồng xử lý chính.",
            "offsetDays": 4,
            "priority": 2,
          },
          {
            "title": "Triển khai các công việc cốt lõi",
            "description": "Thực hiện các hạng mục quan trọng nhất của dự án.",
            "offsetDays": 7,
            "priority": 2,
          },
          {
            "title": "Kiểm tra và hoàn thiện",
            "description": "Rà soát lỗi, chỉnh sửa và chuẩn bị bàn giao.",
            "offsetDays": 12,
            "priority": 2,
          },
        ],
      },
    });
  }

  String _fallbackName(String prompt) {
    final normalized = prompt.trim().replaceAll(RegExp(r"\s+"), " ");
    if (normalized.isEmpty) return "Dự án mới";
    if (normalized.length <= 60) return normalized;
    return "${normalized.substring(0, 57).trimRight()}...";
  }

  Map<String, dynamic> _mapFromJson(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  List<dynamic> _listFromJson(dynamic value) {
    if (value is List) return value;
    if (value is Iterable) return value.toList();
    return <dynamic>[];
  }

  String _classifyStateError(StateError error) {
    final message = error.message.toLowerCase();
    if (message.contains("quota") ||
        message.contains("429") ||
        message.contains("rate limit")) {
      return "quota: ${error.message}";
    }
    if (message.contains("http")) {
      return "http: ${error.message}";
    }
    return "state_error: ${error.message}";
  }

  String _classifyHttpFailure(http.Response response) {
    final body = response.body.toLowerCase();
    if (response.statusCode == 429 ||
        body.contains("quota") ||
        body.contains("rate limit") ||
        body.contains("resource_exhausted")) {
      return "quota";
    }
    return "http";
  }

  void _logException(String phase, Object error, StackTrace stackTrace) {
    _logImportant("[AI EXCEPTION]");
    _logImportant("phase = $phase");
    _logImportant("exception = $error");
    _logImportant("stacktrace = $stackTrace");
  }

  void _logFallback(String reason) {
    _logImportant("[AI FALLBACK]");
    _logImportant("reason = $reason");
  }

  void _log(String message) {
    if (_debugAi) {
      debugPrint("[AI DEBUG] $message");
    }
  }

  void _logImportant(String message) {
    debugPrint(message);
  }

  String _preview(String value) {
    if (value.length <= 1000) return value;
    return "${value.substring(0, 1000)}...";
  }
}
