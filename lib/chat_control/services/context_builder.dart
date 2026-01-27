import '../../inspector_accessibility/domain/models/ui_node.dart';
import '../../inspector_accessibility/domain/models/ui_snapshot.dart';
import '../../ai/models/chat_message.dart';
import '../models/element_record.dart';

class ContextBuilder {
  /// Constrói o prompt completo para o LLM com contexto da tela e histórico
  static String buildPrompt(
    UiSnapshot snapshot,
    List<ChatMessage> chatHistory,
    String userCommand, {
    List<ElementRecord>? savedElements,
  }) {
    final elementsText = _formatElements(snapshot);
    final historyText = _formatChatHistory(chatHistory);
    final savedElementsText = savedElements != null && savedElements.isNotEmpty
        ? _formatSavedElements(savedElements)
        : '';

    return '''Você é um assistente que controla apps Android através de comandos do usuário.

ELEMENTOS VISÍVEIS NA TELA:
$elementsText
${savedElementsText.isNotEmpty ? '\nELEMENTOS SALVOS (do banco de dados):\n$savedElementsText\n' : ''}
HISTÓRICO DA CONVERSA:
$historyText

COMANDO DO USUÁRIO:
$userCommand

INSTRUÇÕES:
1. Analise o comando do usuário e os elementos visíveis na tela
2. Crie um plano de ações em JSON
3. Para cada ação, identifique o elemento alvo pelo texto (match parcial é aceito)
4. Tipos de ação disponíveis: click, scroll_forward, scroll_backward, tap, swipe
5. Retorne APENAS o JSON, sem texto adicional ou markdown

FORMATO DE RESPOSTA (JSON):
{
  "actions": [
    {
      "type": "click|scroll_forward|scroll_backward|tap|swipe",
      "target": "texto_do_elemento",
      "description": "descrição clara da ação",
      "confidence": 0.0-1.0
    }
  ]
}

IMPORTANTE:
- Use "click" para clicar em botões ou elementos clicáveis
- Use "scroll_forward" para rolar para baixo
- Use "scroll_backward" para rolar para cima
- Use "tap" apenas se o usuário especificar coordenadas exatas
- Use "swipe" apenas se o usuário especificar um gesto de deslizar
- O campo "target" deve conter o texto exato ou parcial do elemento visível
- Retorne apenas o JSON, sem explicações adicionais''';
  }

  /// Formata elementos visíveis em texto legível
  static String _formatElements(UiSnapshot snapshot) {
    if (snapshot.nodes.isEmpty) {
      return 'Nenhum elemento visível na tela.';
    }

    final buffer = StringBuffer();
    buffer.writeln('Total de elementos: ${snapshot.nodes.length}');
    buffer.writeln('');

    // Agrupar por tipo e mostrar os mais relevantes
    final clickable = <UiNode>[];
    final scrollable = <UiNode>[];
    final others = <UiNode>[];

    for (final node in snapshot.nodes) {
      if (node.clickable) {
        clickable.add(node);
      } else if (node.scrollable) {
        scrollable.add(node);
      } else {
        others.add(node);
      }
    }

    // Mostrar elementos clicáveis (mais relevantes)
    if (clickable.isNotEmpty) {
      buffer.writeln('ELEMENTOS CLICÁVEIS:');
      for (final node in clickable.take(20)) {
        buffer.writeln(_formatNode(node));
      }
      buffer.writeln('');
    }

    // Mostrar elementos scrolláveis
    if (scrollable.isNotEmpty) {
      buffer.writeln('ELEMENTOS SCROLLÁVEIS:');
      for (final node in scrollable.take(10)) {
        buffer.writeln(_formatNode(node));
      }
      buffer.writeln('');
    }

    // Mostrar outros elementos com texto (limitado)
    if (others.isNotEmpty) {
      final withText = others.where((n) => n.text != null && n.text!.isNotEmpty).take(10).toList();
      if (withText.isNotEmpty) {
        buffer.writeln('OUTROS ELEMENTOS COM TEXTO:');
        for (final node in withText) {
          buffer.writeln(_formatNode(node));
        }
      }
    }

    return buffer.toString();
  }

  /// Formata um único elemento
  static String _formatNode(UiNode node) {
    final parts = <String>[];
    
    if (node.text != null && node.text!.isNotEmpty) {
      parts.add('Texto: "${node.text}"');
    }
    
    parts.add('Classe: ${node.className}');
    
    if (node.viewIdResourceName != null) {
      parts.add('ID: ${node.viewIdResourceName}');
    }
    
    final capabilities = <String>[];
    if (node.clickable) capabilities.add('clicável');
    if (node.scrollable) capabilities.add('scrollável');
    if (node.enabled) capabilities.add('habilitado');
    if (capabilities.isNotEmpty) {
      parts.add('Capacidades: ${capabilities.join(", ")}');
    }
    
    return '- ${parts.join(" | ")}';
  }

  /// Formata histórico de chat (últimas N mensagens)
  static String _formatChatHistory(List<ChatMessage> history) {
    if (history.isEmpty) {
      return 'Nenhuma conversa anterior.';
    }

    // Pegar últimas 10 mensagens
    final recent = history.length > 10 
        ? history.sublist(history.length - 10)
        : history;

    final buffer = StringBuffer();
    for (final msg in recent) {
      final role = msg.role == ChatRole.user ? 'Usuário' : 'Assistente';
      buffer.writeln('$role: ${msg.text}');
    }

    return buffer.toString();
  }

  /// Formata elementos salvos do banco de dados
  static String _formatSavedElements(List<ElementRecord> elements) {
    final buffer = StringBuffer();
    buffer.writeln('Total de elementos salvos encontrados: ${elements.length}');
    buffer.writeln('');

    // Mostrar elementos mais relevantes (clicáveis primeiro)
    final clickable = elements.where((e) => e.clickable).toList();
    final others = elements.where((e) => !e.clickable).toList();

    if (clickable.isNotEmpty) {
      buffer.writeln('ELEMENTOS CLICÁVEIS SALVOS:');
      for (final element in clickable.take(15)) {
        buffer.writeln(_formatSavedElement(element));
      }
      buffer.writeln('');
    }

    if (others.isNotEmpty) {
      buffer.writeln('OUTROS ELEMENTOS SALVOS:');
      for (final element in others.take(10)) {
        buffer.writeln(_formatSavedElement(element));
      }
    }

    return buffer.toString();
  }

  /// Formata um elemento salvo
  static String _formatSavedElement(ElementRecord element) {
    final parts = <String>[];

    if (element.text != null && element.text!.isNotEmpty) {
      parts.add('Texto: "${element.text}"');
    }

    if (element.className != null) {
      parts.add('Classe: ${element.className}');
    }

    parts.add('Posição: (${element.positionLeft.toInt()}, ${element.positionTop.toInt()})');

    final capabilities = <String>[];
    if (element.clickable) capabilities.add('clicável');
    if (element.scrollable) capabilities.add('scrollável');
    if (element.enabled) capabilities.add('habilitado');
    if (capabilities.isNotEmpty) {
      parts.add('Capacidades: ${capabilities.join(", ")}');
    }

    return '- ${parts.join(" | ")}';
  }
}

