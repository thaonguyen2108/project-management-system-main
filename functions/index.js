const { GoogleGenerativeAI } = require("@google/generative-ai");
const { setGlobalOptions } = require("firebase-functions/v2");
const { HttpsError, onCall } = require("firebase-functions/v2/https");

setGlobalOptions({ maxInstances: 10 });

const MODEL_NAMES = ["gemini-1.5-flash", "gemini-2.0-flash", "gemini-2.5-flash"];
const MAX_PROMPT_LENGTH = 2000;
const MAX_TASKS = 10;

exports.generateProjectDraft = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Bạn cần đăng nhập để dùng trợ lý AI.",
    );
  }

  const input = request.data || {};
  const prompt = normalizeString(input.prompt);
  const today = normalizeString(input.today) || new Date().toISOString();
  const userName = normalizeString(input.userName);

  if (!prompt) {
    throw new HttpsError("invalid-argument", "Prompt không được để trống.");
  }
  if (prompt.length > MAX_PROMPT_LENGTH) {
    throw new HttpsError(
      "invalid-argument",
      `Prompt tối đa ${MAX_PROMPT_LENGTH} ký tự.`,
    );
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new HttpsError("failed-precondition", "AI service is not configured.");
  }

  try {
    const text = await generateWithGemini(apiKey, buildPrompt({
      prompt,
      today,
      userName,
    }));
    const parsed = parseJsonResponse(text);
    return sanitizeDraft(parsed, prompt);
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    return fallbackDraft(prompt);
  }
});

async function generateWithGemini(apiKey, prompt) {
  const genAI = new GoogleGenerativeAI(apiKey);
  let lastError;

  for (const modelName of MODEL_NAMES) {
    try {
      const model = genAI.getGenerativeModel({ model: modelName });
      const result = await model.generateContent(prompt);
      return result.response.text();
    } catch (error) {
      lastError = error;
    }
  }

  throw lastError || new Error("Gemini generation failed.");
}

function buildPrompt({ prompt, today, userName }) {
  const displayName = userName ? `Tên người dùng: ${userName}` : "";

  return `
Bạn là trợ lý AI trong app ToDo/quản lý dự án.
Hôm nay: ${today}
${displayName}

Nhiệm vụ: đọc yêu cầu của người dùng và chỉ hỗ trợ nội dung liên quan đến dự án, công việc, kế hoạch, chia task.
Nếu yêu cầu nằm ngoài phạm vi dự án/công việc/quản lý công việc, trả replyText giải thích ngắn gọn rằng bạn chỉ hỗ trợ nội dung liên quan đến dự án và công việc trong ứng dụng, project.tasks phải là [].

Yêu cầu người dùng:
${prompt}

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
- offsetDays là số ngày kể từ ngày bắt đầu dự án.
- priority chỉ là 1, 2 hoặc 3.
- Không tạo assigneeId, ownerId.
- Không tự ghi Firestore.
`;
}

function parseJsonResponse(text) {
  const cleaned = stripCodeFence(normalizeString(text));
  try {
    return JSON.parse(cleaned);
  } catch (_) {
    throw new HttpsError("internal", "Không thể đọc phản hồi AI.");
  }
}

function stripCodeFence(text) {
  let value = text.trim();
  if (value.startsWith("```")) {
    value = value.replace(/^```(?:json)?\s*/i, "");
    value = value.replace(/\s*```$/i, "");
  }

  const firstBrace = value.indexOf("{");
  const lastBrace = value.lastIndexOf("}");
  if (firstBrace >= 0 && lastBrace > firstBrace) {
    value = value.substring(firstBrace, lastBrace + 1);
  }

  return value.trim();
}

function sanitizeDraft(raw, originalPrompt) {
  const root = isObject(raw) ? raw : {};
  const project = isObject(root.project) ? root.project : {};
  const tasks = Array.isArray(project.tasks) ? project.tasks : [];
  const sanitizedTasks = tasks.slice(0, MAX_TASKS).map((task, index) => {
    const source = isObject(task) ? task : {};
    const title = normalizeString(source.title) || `Công việc ${index + 1}`;

    return {
      title,
      description: normalizeString(source.description),
      offsetDays: clampNumber(source.offsetDays, 0, 365, index + 1),
      priority: clampNumber(source.priority, 1, 3, 2),
    };
  });

  const fallbackName = makeFallbackName(originalPrompt);
  const name = normalizeString(project.name) || fallbackName;

  return {
    replyText:
      normalizeString(root.replyText) ||
      "Mình đã tạo một bản gợi ý dự án để bạn xem và chỉnh sửa trước khi lưu.",
    project: {
      name,
      description:
        normalizeString(project.description) ||
        `Bản nháp dự án được tạo từ yêu cầu: ${originalPrompt}`,
      durationDays: clampNumber(project.durationDays, 1, 365, 14),
      tasks: sanitizedTasks,
    },
  };
}

function fallbackDraft(prompt) {
  const name = makeFallbackName(prompt);
  return {
    replyText:
      "AI đang không phản hồi ổn định, nên mình tạo một gợi ý cơ bản để bạn có thể chỉnh sửa tiếp.",
    project: {
      name,
      description: `Bản nháp dự án được tạo từ yêu cầu: ${prompt}`,
      durationDays: 14,
      tasks: [
        {
          title: "Xác định mục tiêu và phạm vi",
          description: "Làm rõ yêu cầu chính, kết quả cần đạt và phạm vi công việc.",
          offsetDays: 1,
          priority: 3,
        },
        {
          title: "Lập kế hoạch thực hiện",
          description: "Chia nhỏ các đầu việc, thời gian và thứ tự ưu tiên.",
          offsetDays: 2,
          priority: 2,
        },
        {
          title: "Triển khai các hạng mục chính",
          description: "Thực hiện những phần việc quan trọng nhất của dự án.",
          offsetDays: 5,
          priority: 3,
        },
        {
          title: "Kiểm tra và hoàn thiện",
          description: "Rà soát kết quả, sửa lỗi và chuẩn bị bàn giao.",
          offsetDays: 12,
          priority: 2,
        },
      ],
    },
  };
}

function makeFallbackName(prompt) {
  const normalized = normalizeString(prompt).replace(/\s+/g, " ");
  if (!normalized) return "Dự án mới";
  if (normalized.length <= 60) return normalized;
  return normalized.substring(0, 57).trimEnd() + "...";
}

function normalizeString(value) {
  if (value === null || value === undefined) return "";
  return String(value).trim();
}

function clampNumber(value, min, max, fallback) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(max, Math.max(min, Math.round(number)));
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
