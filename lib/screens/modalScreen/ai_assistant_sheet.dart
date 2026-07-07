import 'package:flutter/material.dart';
import 'package:todo/controllers/ai_Assistant_Controller.dart';
import 'package:todo/core/app_style.dart';
import 'package:todo/models/ai_project_draft.dart';
import 'package:todo/screens/modalScreen/projectForm.dart';
import 'package:todo/widgets/ui.dart';

Future<void> showAiAssistantSheet(BuildContext context) {
  return showAppModal(
    context: context,
    title: "Trợ lý AI",
    initialSize: 0.82,
    minSize: 0.55,
    maxSize: 0.95,
    isScrollable: false,
    child: AiAssistantSheet(parentContext: context),
  );
}

class AiAssistantSheet extends StatefulWidget {
  final BuildContext parentContext;

  const AiAssistantSheet({super.key, required this.parentContext});

  @override
  State<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<AiAssistantSheet> {
  final _controller = AiAssistantController();
  final _promptController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_AiMessage> _messages = [
    _AiMessage.ai(
      text:
          "Mình có thể gợi ý dự án và chia công việc thành bản nháp. Bạn vẫn sẽ kiểm tra trong form trước khi lưu.",
    ),
  ];

  bool isLoading = false;

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendPrompt([String? quickPrompt]) async {
    final prompt = (quickPrompt ?? _promptController.text).trim();
    if (prompt.isEmpty || isLoading) return;

    setState(() {
      isLoading = true;
      _promptController.clear();
      _messages.add(_AiMessage.user(text: prompt));
      _messages.add(_AiMessage.ai(text: "AI đang phân tích..."));
    });
    _scrollToBottom();

    try {
      final draft = await _controller.generateProjectDraft(prompt);
      if (!mounted) return;

      setState(() {
        _messages.removeLast();
        _messages.add(_AiMessage.ai(text: draft.replyText, draft: draft));
        isLoading = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _messages.removeLast();
        _messages.add(
          _AiMessage.ai(text: _friendlyError(error), isError: true),
        );
        isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _useDraft(AiProjectDraft draft) async {
    Navigator.of(context).pop();
    await Future<void>.delayed(const Duration(milliseconds: 180));

    final parentContext = widget.parentContext;
    if (!parentContext.mounted) return;

    final projectFormKey = GlobalKey<FormDuAnState>();
    var isSavingProject = false;

    showAppModal(
      context: parentContext,
      title: "Dự án từ AI",
      child: FormDuAn(key: projectFormKey, initialDraft: draft),
      listButtons: StatefulBuilder(
        builder: (context, setModalState) {
          return padding(
            right: 10,
            top: 10,
            bottom: 10,
            child: align(
              alignment: Alignment.bottomRight,
              child: button(
                label: isSavingProject ? "Đang lưu..." : "Thêm",
                onPressed: () async {
                  if (isSavingProject) return;
                  setModalState(() {
                    isSavingProject = true;
                  });

                  final success =
                      await projectFormKey.currentState?.submitProject() ??
                      false;
                  if (!success && context.mounted) {
                    setModalState(() {
                      isSavingProject = false;
                    });
                  }
                },
                color: isSavingProject
                    ? const Color(0xFFB8C0CC)
                    : AppColors.primary,
                textColor: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst(RegExp(r"^[^:]+:\s*"), "");
    return message.trim().isEmpty
        ? "Không thể tạo gợi ý lúc này. Vui lòng thử lại."
        : message;
  }

  @override
  Widget build(BuildContext context) {
    return column(
      children: [
        _quickPrompts(),
        box(height: 10),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            itemCount: _messages.length,
            itemBuilder: (context, index) => _messageBubble(_messages[index]),
          ),
        ),
        _inputBar(),
      ],
    );
  }

  Widget _quickPrompts() {
    final colors = Theme.of(context).colorScheme;
    const prompts = [
      "Tạo kế hoạch dự án",
      "Gợi ý chia task",
      "Tóm tắt công việc hôm nay",
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final prompt in prompts) ...[
            ActionChip(
              label: Text(prompt),
              labelStyle: TextStyle(color: colors.onSurface),
              onPressed: isLoading
                  ? null
                  : () => _sendPrompt(
                      "$prompt cho một dự án mới. Hãy tạo bản nháp project và task phù hợp.",
                    ),
              backgroundColor: colors.primaryContainer.withValues(alpha: 0.35),
              side: BorderSide(color: colors.outlineVariant),
            ),
            box(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _messageBubble(_AiMessage message) {
    final isUser = message.isUser;
    final colors = Theme.of(context).colorScheme;
    final bubbleColor = isUser
        ? colors.primary
        : message.isError
        ? colors.errorContainer
        : colors.surfaceContainerHighest;
    final messageTextColor = isUser
        ? colors.onPrimary
        : message.isError
        ? colors.onErrorContainer
        : colors.onSurface;

    return align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: containerBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        radius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
        color: bubbleColor,
        child: column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            text(
              message.text,
              color: messageTextColor,
              maxLines: 20,
              overflow: TextOverflow.visible,
            ),
            if (message.draft != null && message.draft!.hasProjectContent) ...[
              box(height: 10),
              _draftCard(message.draft!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _draftCard(AiProjectDraft draft) {
    final visibleTasks = draft.tasks.take(5).toList();
    final colors = Theme.of(context).colorScheme;

    return containerBox(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      radius: BorderRadius.circular(AppRadius.md),
      color: colors.surface,
      border: Border.all(color: colors.outlineVariant),
      child: column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          text(
            draft.name.isEmpty ? "Dự án AI đề xuất" : draft.name,
            weight: FontWeight.bold,
            maxLines: 2,
          ),
          if (draft.description.isNotEmpty) ...[
            box(height: 6),
            text(
              draft.description,
              size: 13,
              color: colors.onSurfaceVariant,
              maxLines: 3,
            ),
          ],
          box(height: 8),
          text(
            "${draft.durationDays} ngày • ${draft.tasks.length} công việc",
            size: 12,
            weight: FontWeight.w700,
            color: colors.primary,
          ),
          if (visibleTasks.isNotEmpty) ...[
            box(height: 8),
            for (final task in visibleTasks)
              padding(
                bottom: 5,
                child: text(
                  "• ${task.title}",
                  size: 12,
                  color: colors.onSurfaceVariant,
                  maxLines: 1,
                ),
              ),
          ],
          box(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _useDraft(draft),
              icon: const Icon(Icons.post_add_rounded, size: 18),
              label: const Text("Dùng gợi ý này"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    final colors = Theme.of(context).colorScheme;

    return containerBox(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      color: colors.surface,
      border: Border(top: BorderSide(color: colors.outlineVariant)),
      child: row(
        children: [
          flexible(
            child: TextField(
              controller: _promptController,
              enabled: !isLoading,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendPrompt(),
              decoration: InputDecoration(
                hintText: "Nhập yêu cầu tạo dự án hoặc chia task...",
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          box(width: 8),
          IconButton.filled(
            onPressed: isLoading ? null : () => _sendPrompt(),
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}

class _AiMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final AiProjectDraft? draft;

  const _AiMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.draft,
  });

  factory _AiMessage.user({required String text}) {
    return _AiMessage(text: text, isUser: true);
  }

  factory _AiMessage.ai({
    required String text,
    bool isError = false,
    AiProjectDraft? draft,
  }) {
    return _AiMessage(
      text: text,
      isUser: false,
      isError: isError,
      draft: draft,
    );
  }
}
