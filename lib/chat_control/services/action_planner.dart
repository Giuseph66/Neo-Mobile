import 'dart:convert';

import '../../ai/models/chat_message.dart';
import '../../ai/models/chat_session.dart';
import '../../ai/providers/chat_provider.dart';
import '../../inspector_accessibility/domain/models/ui_snapshot.dart';
import '../models/action_plan.dart';
import '../models/element_record.dart';
import 'context_builder.dart';

class ActionPlanner {
  final IChatProvider _provider;

  ActionPlanner(this._provider);

  /// Cria um plano de ações baseado no comando do usuário
  /// Usa o LLM para interpretar o comando e gerar o plano
  Future<ActionPlan> planActions(
    String userCommand,
    UiSnapshot snapshot,
    List<ChatMessage> chatHistory, {
    List<ElementRecord>? savedElements,
  }) async {
    // Construir prompt com contexto (incluindo elementos salvos se disponíveis)
    final prompt = ContextBuilder.buildPrompt(
      snapshot,
      chatHistory,
      userCommand,
      savedElements: savedElements,
    );

    // Criar sessão temporária para o LLM
    final session = ChatSession(
      id: 'action_planner_${DateTime.now().millisecondsSinceEpoch}',
      providerId: _provider.providerId,
      modelId: '', // Será definido pelo provider
      messages: [
        ChatMessage(
          id: 'system_${DateTime.now().millisecondsSinceEpoch}',
          role: ChatRole.user,
          text: prompt,
          createdAt: DateTime.now(),
        ),
      ],
    );

    try {
      // Enviar prompt ao LLM e aguardar resposta
      final reply = await _provider.sendMessage(session, prompt);
      final responseText = reply.text.trim();

      // Tentar extrair JSON da resposta
      final jsonText = _extractJsonFromResponse(responseText);
      if (jsonText == null) {
        // Se não encontrou JSON, retornar plano vazio
        return ActionPlan(actions: []);
      }

      // Parse do JSON
      final json = jsonDecode(jsonText) as Map<String, dynamic>;
      return ActionPlan.fromJson(json);
    } catch (e) {
      // Em caso de erro, retornar plano vazio
      return ActionPlan(actions: []);
    }
  }

  /// Extrai JSON da resposta do LLM
  /// Tenta encontrar um bloco JSON mesmo que venha com texto adicional
  static String? _extractJsonFromResponse(String response) {
    // Tentar encontrar JSON entre chaves
    final jsonStart = response.indexOf('{');
    if (jsonStart == -1) return null;

    // Encontrar o final do JSON (última chave fechada)
    int braceCount = 0;
    int jsonEnd = -1;

    for (int i = jsonStart; i < response.length; i++) {
      if (response[i] == '{') {
        braceCount++;
      } else if (response[i] == '}') {
        braceCount--;
        if (braceCount == 0) {
          jsonEnd = i + 1;
          break;
        }
      }
    }

    if (jsonEnd == -1) return null;

    return response.substring(jsonStart, jsonEnd);
  }
}

