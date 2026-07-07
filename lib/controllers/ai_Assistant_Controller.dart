import 'package:todo/models/ai_project_draft.dart';
import 'package:todo/services/aiAssistantService.dart';

class AiAssistantController {
  final AiAssistantService _service = AiAssistantService();

  Future<AiProjectDraft> generateProjectDraft(String prompt) {
    return _service.generateProjectDraft(prompt);
  }
}
