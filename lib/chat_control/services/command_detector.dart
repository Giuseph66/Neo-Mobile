/// Detecta se uma mensagem é um comando de controle ou apenas uma conversa normal
class CommandDetector {
  /// Palavras-chave que indicam comandos de controle
  static const List<String> _controlKeywords = [
    'abrir',
    'abre',
    'poderia abrir',
    'pode abrir',
    'poder abrir',
    'clicar',
    'clique',
    'clicar em',
    'tocar',
    'toca',
    'tocar em',
    'enviar',
    'envia',
    'enviar mensagem',
    'digitar',
    'digite',
    'escrever',
    'escreva',
    'rolar',
    'role',
    'scroll',
    'deslizar',
    'deslize',
    'swipe',
    'buscar',
    'busca',
    'pesquisar',
    'pesquise',
    'voltar',
    'volta',
    'avançar',
    'avança',
    'ir para',
    'ir em',
    'navegar',
    'navega',
    'selecionar',
    'selecione',
    'escolher',
    'escolha',
    'confirmar',
    'confirma',
    'cancelar',
    'cancela',
    'apagar',
    'apaga',
    'deletar',
    'deleta',
    'salvar',
    'salva',
    'editar',
    'edita',
    'adicionar',
    'adiciona',
    'remover',
    'remove',
  ];

  /// Detecta se a mensagem é um comando de controle
  /// Retorna true se parecer um comando, false se for conversa normal
  static bool isControlCommand(String message) {
    final lowerMessage = message.toLowerCase().trim();
    
    print('[CommandDetector] Analisando mensagem: "$message"');
    
    // Se a mensagem for muito curta (menos de 3 caracteres), provavelmente não é comando
    if (lowerMessage.length < 3) {
      print('[CommandDetector] Mensagem muito curta (< 3 caracteres), não é comando');
      return false;
    }

    // PRIMEIRO: Verificar se contém palavras-chave de controle
    // Se tiver, é comando (mesmo que seja uma pergunta como "poderia abrir?")
    bool hasControlKeyword = false;
    String? matchedKeyword;
    for (final keyword in _controlKeywords) {
      // Usar word boundary para evitar matches parciais
      final regex = RegExp(r'\b' + RegExp.escape(keyword) + r'\b', caseSensitive: false);
      if (regex.hasMatch(lowerMessage)) {
        hasControlKeyword = true;
        matchedKeyword = keyword;
        break;
      }
    }

    // Se tem palavra-chave de controle, é comando (mesmo com interrogação)
    if (hasControlKeyword) {
      print('[CommandDetector] ✓ PALAVRA-CHAVE DETECTADA: "$matchedKeyword" → É COMANDO DE CONTROLE');
      return true;
    }

    // Verificar padrões de comando
    // Ex: "fazer X", "realizar Y", "executar Z"
    final commandPatterns = [
      RegExp(r'\b(fazer|realizar|executar|efetuar)\s+\w+', caseSensitive: false),
      RegExp(r'\b(no|na|em|para)\s+\w+', caseSensitive: false), // "no WhatsApp", "na tela"
      RegExp(r'\b(com|para)\s+\w+', caseSensitive: false), // "com João", "para Maria"
    ];

    for (final pattern in commandPatterns) {
      if (pattern.hasMatch(lowerMessage)) {
        // Se tem padrão de comando, verificar se não é apenas uma pergunta genérica
        if (!_isGenericQuestion(lowerMessage)) {
          return true;
        }
      }
    }

    // Se não tem palavras-chave de controle e não é padrão de comando,
    // verificar se é saudação ou pergunta genérica
    if (_isGreetingOrQuestion(lowerMessage)) {
      print('[CommandDetector] É saudação ou pergunta genérica → NÃO é comando');
      return false;
    }

    print('[CommandDetector] Não é comando de controle → Conversa normal');
    return false;
  }

  /// Verifica se é uma pergunta genérica (sem palavras de ação)
  static bool _isGenericQuestion(String message) {
    // Perguntas genéricas que não são comandos
    final genericQuestions = [
      'o que é',
      'o que são',
      'o que significa',
      'como funciona',
      'como é',
      'quem é',
      'quem são',
      'onde fica',
      'quando foi',
      'por que',
      'porque',
    ];

    for (final question in genericQuestions) {
      if (message.startsWith(question)) {
        return true;
      }
    }

    return false;
  }

  /// Verifica se a mensagem é uma saudação ou pergunta (não é comando)
  static bool _isGreetingOrQuestion(String message) {
    final greetings = [
      'olá',
      'oi',
      'bom dia',
      'boa tarde',
      'boa noite',
      'tudo bem',
      'como vai',
      'e aí',
      'eai',
      'opa',
      'eae',
    ];

    final questionWords = [
      'como',
      'quando',
      'onde',
      'quem',
      'qual',
      'quais',
      'por que',
      'porque',
      'por quê',
      'o que',
      'que',
      'qual é',
      'qual a',
    ];

    // Verificar se contém ou começa com saudação
    for (final greeting in greetings) {
      if (message == greeting || 
          message.startsWith(greeting + ' ') || 
          message.endsWith(' ' + greeting) ||
          message.contains(' ' + greeting + ' ')) {
        return true;
      }
    }

    // Verificar se começa com palavra de pergunta
    // MAS: se contém palavra-chave de controle, não é pergunta genérica
    for (final questionWord in questionWords) {
      if (message.startsWith(questionWord)) {
        // Verificar se tem palavra-chave de controle antes de considerar como pergunta
        for (final keyword in _controlKeywords) {
          final regex = RegExp(r'\b' + RegExp.escape(keyword) + r'\b', caseSensitive: false);
          if (regex.hasMatch(message)) {
            return false; // Tem palavra-chave, não é pergunta genérica
          }
        }
        return true; // Começa com palavra de pergunta e não tem palavra-chave
      }
    }

    // Verificar se termina com interrogação
    // MAS: se contém palavra-chave de controle, não é pergunta genérica
    if (message.endsWith('?')) {
      // Verificar se tem palavra-chave de controle antes de considerar como pergunta
      for (final keyword in _controlKeywords) {
        final regex = RegExp(r'\b' + RegExp.escape(keyword) + r'\b', caseSensitive: false);
        if (regex.hasMatch(message)) {
          return false; // Tem palavra-chave, não é pergunta genérica
        }
      }
      // Se termina com ? mas não tem palavra-chave de controle, verificar se é pergunta genérica
      // Perguntas que começam com "poderia", "pode", "você pode" sem ação são genéricas
      if (message.startsWith('poderia ') || 
          message.startsWith('pode ') ||
          message.startsWith('você pode ') ||
          message.startsWith('vc pode ')) {
        // Se não tem palavra-chave de ação, é pergunta genérica
        return true;
      }
      // Outras perguntas com ? são genéricas
      return true;
    }

    return false;
  }
}

