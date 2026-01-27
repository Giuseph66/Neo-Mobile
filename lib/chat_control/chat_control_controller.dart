import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/config/ai_config_store.dart';
import '../ai/providers/provider_registry.dart';
import '../inspector_accessibility/data/inspector_repository_impl.dart';
import '../inspector_accessibility/domain/models/ui_node.dart';
import '../inspector_accessibility/domain/models/ui_snapshot.dart';
import '../inspector_accessibility/domain/models/node_selector.dart';
import '../inspector_accessibility/presentation/accessibility_inspector_controller.dart';
import '../llm/generation_controller.dart';
import 'models/action_plan.dart';
import 'models/executed_action.dart';
import 'models/element_record.dart';
import 'services/action_executor.dart';
import 'services/action_planner.dart';
import 'services/element_storage_service.dart';

class ChatControlState {
  final bool isInspectorActive;
  final UiSnapshot? currentSnapshot;
  final ActionPlan? pendingPlan;
  final bool isGeneratingPlan;
  final bool isExecutingActions;
  final List<ExecutedAction> actionHistory;
  final String? errorMessage;
  final bool showControls;
  final bool showVisualOverlay;
  final List<ElementRecord>? searchResults;
  final String? searchQuery;

  ChatControlState({
    this.isInspectorActive = false,
    this.currentSnapshot,
    this.pendingPlan,
    this.isGeneratingPlan = false,
    this.isExecutingActions = false,
    this.actionHistory = const [],
    this.errorMessage,
    this.showControls = true,
    this.showVisualOverlay = false,
    this.searchResults,
    this.searchQuery,
  });

  ChatControlState copyWith({
    bool? isInspectorActive,
    UiSnapshot? currentSnapshot,
    ActionPlan? pendingPlan,
    bool? isGeneratingPlan,
    bool? isExecutingActions,
    List<ExecutedAction>? actionHistory,
    String? errorMessage,
    bool clearError = false,
    bool? showControls,
    bool? showVisualOverlay,
    List<ElementRecord>? searchResults,
    String? searchQuery,
    bool clearSearch = false,
  }) {
    return ChatControlState(
      isInspectorActive: isInspectorActive ?? this.isInspectorActive,
      currentSnapshot: currentSnapshot ?? this.currentSnapshot,
      pendingPlan: pendingPlan ?? this.pendingPlan,
      isGeneratingPlan: isGeneratingPlan ?? this.isGeneratingPlan,
      isExecutingActions: isExecutingActions ?? this.isExecutingActions,
      actionHistory: actionHistory ?? this.actionHistory,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      showControls: showControls ?? this.showControls,
      showVisualOverlay: showVisualOverlay ?? this.showVisualOverlay,
      searchResults: clearSearch ? null : (searchResults ?? this.searchResults),
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
    );
  }
}

class ChatControlController extends StateNotifier<ChatControlState> {
  final AccessibilityInspectorController _inspectorController;
  final GenerationController _generationController;
  final ProviderRegistry _providerRegistry;
  final AiConfigStore _config;
  final ActionExecutor _actionExecutor;
  final ElementStorageService _storageService = ElementStorageService();

  StreamSubscription<UiSnapshot>? _snapshotSubscription;
  Timer? _snapshotThrottle;

  ChatControlController(
    this._inspectorController,
    this._generationController,
    this._providerRegistry,
    this._config,
  )   : _actionExecutor = ActionExecutor(InspectorRepositoryImpl()),
        super(ChatControlState()) {
    _listenToSnapshots();
  }

  void _listenToSnapshots() {
    _snapshotSubscription?.cancel();
    _snapshotSubscription = _inspectorController.nodesStream.listen((snapshot) {
      // Throttle: atualizar no máximo a cada 500ms
      _snapshotThrottle?.cancel();
      _snapshotThrottle = Timer(const Duration(milliseconds: 500), () {
        state = state.copyWith(currentSnapshot: snapshot);
        // O salvamento é feito automaticamente pelo AccessibilityInspectorController
      });
    });
  }

  /// Inicia o Inspector
  Future<void> startInspector() async {
    try {
      await _inspectorController.start();
      state = state.copyWith(isInspectorActive: true);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Para o Inspector
  Future<void> stopInspector() async {
    await _inspectorController.stop();
    // O reset do grupo é feito automaticamente pelo AccessibilityInspectorController
    state = state.copyWith(
      isInspectorActive: false,
      currentSnapshot: null,
      pendingPlan: null,
    );
  }

  /// Busca elementos salvos no banco de dados
  /// Extrai palavras-chave do comando para melhorar a busca
  Future<void> searchElements(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(clearSearch: true);
      return;
    }

    try {
      // Extrair palavras-chave do comando (remover palavras comuns)
      final keywords = _extractKeywords(query);
      print('[ChatControlController] → Palavras-chave extraídas: ${keywords.join(", ")}');
      
      // Buscar por cada palavra-chave e combinar resultados
      final allResults = <ElementRecord>[];
      final seenPaths = <String>{};
      
      for (final keyword in keywords) {
        final results = await _storageService.searchElements(keyword);
        for (final element in results) {
          // Usar path como identificador único (mais confiável que id)
          if (!seenPaths.contains(element.path)) {
            allResults.add(element);
            seenPaths.add(element.path);
          }
        }
      }
      
      // Também buscar pelo comando completo
      final fullQueryResults = await _storageService.searchElements(query);
      for (final element in fullQueryResults) {
        if (!seenPaths.contains(element.path)) {
          allResults.add(element);
          seenPaths.add(element.path);
        }
      }
      
      print('[ChatControlController] → Total de elementos encontrados: ${allResults.length}');
      if (allResults.isNotEmpty) {
        print('[ChatControlController] → Primeiros elementos:');
        for (var i = 0; i < allResults.length && i < 5; i++) {
          final elem = allResults[i];
          print('[ChatControlController]   ${i + 1}. "${elem.text ?? "(sem texto)"}" - ${elem.className} [${elem.positionLeft.toInt()}, ${elem.positionTop.toInt()}, ${elem.positionRight.toInt()}, ${elem.positionBottom.toInt()}]');
        }
      }
      
      state = state.copyWith(
        searchResults: allResults,
        searchQuery: query,
      );
    } catch (e) {
      print('[ChatControlController] ✗ Erro ao buscar elementos: $e');
      state = state.copyWith(
        errorMessage: 'Erro ao buscar elementos: ${e.toString()}',
      );
    }
  }

  /// Extrai palavras-chave relevantes do comando
  List<String> _extractKeywords(String command) {
    final lowerCommand = command.toLowerCase();
    
    // Remover palavras comuns
    final stopWords = {
      'o', 'a', 'os', 'as', 'um', 'uma', 'uns', 'umas',
      'de', 'da', 'do', 'das', 'dos',
      'em', 'na', 'no', 'nas', 'nos',
      'para', 'por', 'com', 'sem',
      'meu', 'minha', 'meus', 'minhas',
      'poderia', 'pode', 'poder', 'você', 'vc',
      'agora', 'por favor', 'pf',
      '?', '!', '.', ',',
    };
    
    // Extrair palavras
    final words = lowerCommand
        .split(RegExp(r'[\s\.,!?]+'))
        .where((word) => word.isNotEmpty && word.length > 2)
        .where((word) => !stopWords.contains(word))
        .toList();
    
    return words;
  }

  void toggleControls() {
    state = state.copyWith(showControls: !state.showControls);
  }

  void toggleVisualOverlay() {
    state = state.copyWith(showVisualOverlay: !state.showVisualOverlay);
  }

  /// Envia um comando e gera um plano de ações
  /// Agora também busca elementos salvos se necessário
  Future<void> sendCommand(String command) async {
    if (command.trim().isEmpty) return;

    print('[ChatControlController] ========================================');
    print('[ChatControlController] 🚀 PROCESSANDO COMANDO: "$command"');
    print('[ChatControlController] ========================================');

    // Primeiro, tentar buscar elementos salvos relacionados ao comando
    print('[ChatControlController] → Buscando elementos salvos relacionados...');
    await searchElements(command);

    // Se não há Inspector ativo, tentar usar elementos salvos
    if (!state.isInspectorActive) {
      print('[ChatControlController] ⚠️  Inspector NÃO está ativo');
      final savedElements = state.searchResults;
      if (savedElements != null && savedElements.isNotEmpty) {
        print('[ChatControlController] ✓ Encontrados ${savedElements.length} elementos salvos');
        print('[ChatControlController] → Criando snapshot a partir dos elementos salvos...');
        // Criar snapshot a partir dos elementos salvos
        final snapshot = _createSnapshotFromSavedElements(savedElements);
        await _generatePlanFromSnapshot(command, snapshot);
        return;
      } else {
        print('[ChatControlController] ✗ Nenhum elemento salvo encontrado');
        print('[ChatControlController] → Enviando para chat normal como fallback...');
        // Não mostrar erro - apenas não gerar plano se não houver elementos
        // O usuário pode estar apenas conversando
        _generationController.sendPrompt(command);
        state = state.copyWith(
          errorMessage: null,
          clearError: true,
        );
        return;
      }
    }

    print('[ChatControlController] ✓ Inspector está ATIVO');
    
    // Forçar atualização do snapshot pegando o último do inspector
    var snapshot = state.currentSnapshot;
    final lastSnapshot = _inspectorController.lastSnapshot;
    
    print('[ChatControlController] → Snapshot atual: ${snapshot?.nodes.length ?? 0} elementos');
    print('[ChatControlController] → Último snapshot do inspector: ${lastSnapshot?.nodes.length ?? 0} elementos');
    
    // Sempre usar o último snapshot se disponível (mais atualizado)
    if (lastSnapshot != null) {
      if (snapshot == null || snapshot.nodes.isEmpty || lastSnapshot.nodes.length > snapshot.nodes.length) {
        print('[ChatControlController] → Usando último snapshot do inspector (${lastSnapshot.nodes.length} elementos)');
        snapshot = lastSnapshot;
        state = state.copyWith(currentSnapshot: lastSnapshot);
      } else {
        print('[ChatControlController] → Mantendo snapshot atual (${snapshot.nodes.length} elementos)');
      }
    }
    
    // Combinar snapshot atual + elementos salvos + elementos de navegação
    final combinedSnapshot = _buildCombinedSnapshot(
      snapshot,
      state.searchResults,
    );
    
    if (combinedSnapshot.nodes.isEmpty) {
      print('[ChatControlController] ✗ Nenhum elemento disponível após combinação');
      print('[ChatControlController] → Enviando para chat normal como fallback...');
      _generationController.sendPrompt(command);
      state = state.copyWith(
        errorMessage: null,
        clearError: true,
      );
      return;
    }

    print('[ChatControlController] ✓ Snapshot combinado com ${combinedSnapshot.nodes.length} elementos');
    print('[ChatControlController]   → Snapshot atual: ${snapshot?.nodes.length ?? 0}');
    print('[ChatControlController]   → Elementos salvos: ${state.searchResults?.length ?? 0}');
    print('[ChatControlController]   → Elementos de navegação: ${combinedSnapshot.nodes.length - (snapshot?.nodes.length ?? 0) - (state.searchResults?.length ?? 0)}');
    print('[ChatControlController] → Gerando plano de ações...');
    await _generatePlanFromSnapshot(command, combinedSnapshot);
  }

  /// Cria um snapshot a partir de elementos salvos
  UiSnapshot _createSnapshotFromSavedElements(List<ElementRecord> elements) {
    final nodes = elements.map((element) {
      return UiNode(
        id: 'saved_${element.id}',
        selector: NodeSelector(
          viewId: element.viewId,
          className: element.className ?? '',
        ),
        bounds: Rect.fromLTRB(
          element.positionLeft,
          element.positionTop,
          element.positionRight,
          element.positionBottom,
        ),
        className: element.className ?? '',
        packageName: '',
        viewIdResourceName: element.viewId,
        clickable: element.clickable,
        enabled: element.enabled,
        scrollable: element.scrollable,
        isTextField: false,
        text: element.text,
      );
    }).toList();

    return UiSnapshot(
      nodes: nodes,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Cria elementos de navegação do sistema (home, back, recents)
  List<UiNode> _createNavigationNodes() {
    return [
      // Botão Home
      UiNode(
        id: 'nav_home',
        selector: NodeSelector(viewId: 'home', className: 'android.widget.Button'),
        bounds: const Rect.fromLTRB(0, 0, 200, 200), // Posição aproximada
        className: 'android.widget.Button',
        packageName: 'android',
        viewIdResourceName: 'home',
        clickable: true,
        enabled: true,
        scrollable: false,
        isTextField: false,
        text: 'Home',
      ),
      // Botão Back
      UiNode(
        id: 'nav_back',
        selector: NodeSelector(viewId: 'back', className: 'android.widget.Button'),
        bounds: const Rect.fromLTRB(0, 0, 200, 200), // Posição aproximada
        className: 'android.widget.Button',
        packageName: 'android',
        viewIdResourceName: 'back',
        clickable: true,
        enabled: true,
        scrollable: false,
        isTextField: false,
        text: 'Voltar',
      ),
      // Botão Recents
      UiNode(
        id: 'nav_recents',
        selector: NodeSelector(viewId: 'recents', className: 'android.widget.Button'),
        bounds: const Rect.fromLTRB(0, 0, 200, 200), // Posição aproximada
        className: 'android.widget.Button',
        packageName: 'android',
        viewIdResourceName: 'recents',
        clickable: true,
        enabled: true,
        scrollable: false,
        isTextField: false,
        text: 'Apps Recentes',
      ),
    ];
  }

  /// Combina snapshot atual + elementos salvos + elementos de navegação
  UiSnapshot _buildCombinedSnapshot(
    UiSnapshot? currentSnapshot,
    List<ElementRecord>? savedElements,
  ) {
    print('[ChatControlController] 📦 _buildCombinedSnapshot()');
    final allNodes = <UiNode>[];
    final seenIds = <String>{};
    int snapshotCount = 0;
    int savedCount = 0;
    int navCount = 0;

    // 1. Adicionar elementos do snapshot atual
    if (currentSnapshot != null && currentSnapshot.nodes.isNotEmpty) {
      print('[ChatControlController]   → Adicionando ${currentSnapshot.nodes.length} elementos do snapshot atual...');
      for (final node in currentSnapshot.nodes) {
        if (!seenIds.contains(node.id)) {
          allNodes.add(node);
          seenIds.add(node.id);
          snapshotCount++;
        }
      }
    }

    // 2. Adicionar elementos salvos (que não estão no snapshot atual)
    if (savedElements != null && savedElements.isNotEmpty) {
      print('[ChatControlController]   → Adicionando ${savedElements.length} elementos salvos...');
      for (final element in savedElements) {
        // Usar path como identificador único
        final nodeId = 'saved_${element.path}_${element.id ?? 0}';
        if (!seenIds.contains(nodeId)) {
          allNodes.add(UiNode(
            id: nodeId,
            selector: NodeSelector(
              viewId: element.viewId,
              className: element.className ?? '',
            ),
            bounds: Rect.fromLTRB(
              element.positionLeft,
              element.positionTop,
              element.positionRight,
              element.positionBottom,
            ),
            className: element.className ?? '',
            packageName: '',
            viewIdResourceName: element.viewId,
            clickable: element.clickable,
            enabled: element.enabled,
            scrollable: element.scrollable,
            isTextField: false,
            text: element.text,
          ));
          seenIds.add(nodeId);
          savedCount++;
        }
      }
    }

    // 3. Adicionar elementos de navegação do sistema
    print('[ChatControlController]   → Adicionando elementos de navegação (Home, Back, Recents)...');
    final navNodes = _createNavigationNodes();
    for (final navNode in navNodes) {
      if (!seenIds.contains(navNode.id)) {
        allNodes.add(navNode);
        seenIds.add(navNode.id);
        navCount++;
      }
    }

    print('[ChatControlController]   ✓ Snapshot combinado:');
    print('[ChatControlController]     → Snapshot atual: $snapshotCount elementos');
    print('[ChatControlController]     → Elementos salvos: $savedCount elementos');
    print('[ChatControlController]     → Navegação: $navCount elementos');
    print('[ChatControlController]     → TOTAL: ${allNodes.length} elementos');

    return UiSnapshot(
      nodes: allNodes,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Gera plano a partir de um snapshot
  Future<void> _generatePlanFromSnapshot(String command, UiSnapshot snapshot) async {
    print('[ChatControlController] 📋 _generatePlanFromSnapshot()');
    print('[ChatControlController]   → Comando: "$command"');
    print('[ChatControlController]   → Snapshot: ${snapshot.nodes.length} elementos');
    
    // Obter histórico do chat
    final chatHistory = _generationController.state.messages;
    print('[ChatControlController]   → Histórico: ${chatHistory.length} mensagens');

    state = state.copyWith(
      isGeneratingPlan: true,
      errorMessage: null,
      clearError: true,
    );

    try {
      // Obter provider atual e criar ActionPlanner
      final currentProvider = _providerRegistry.byId(
        _config.state.activeProvider.name,
      );
      print('[ChatControlController]   → Provider: ${currentProvider.providerId}');
      final planner = ActionPlanner(currentProvider);

      // Gerar plano (incluir elementos salvos se houver resultados de busca)
      final savedElements = state.searchResults;
      print('[ChatControlController]   → Elementos salvos: ${savedElements?.length ?? 0}');
      print('[ChatControlController]   → Chamando planner.planActions()...');
      
      final plan = await planner.planActions(
        command,
        snapshot,
        chatHistory,
        savedElements: savedElements,
      );

      print('[ChatControlController]   → Plano gerado: ${plan.actions.length} ações');
      
      if (plan.isEmpty) {
        print('[ChatControlController] ⚠️  Plano VAZIO gerado');
        print('[ChatControlController] → Enviando para chat normal como fallback...');
        // Se não conseguiu gerar plano, enviar para chat normal como fallback
        // Isso permite que o usuário tenha uma resposta mesmo sem elementos disponíveis
        _generationController.sendPrompt(command);
        
        state = state.copyWith(
          isGeneratingPlan: false,
          errorMessage: null,
          clearError: true,
        );
        return;
      }

      print('[ChatControlController] ✓ Plano gerado com sucesso!');
      print('[ChatControlController]   → Ações: ${plan.actions.map((a) => a.type).join(", ")}');
      
      state = state.copyWith(
        isGeneratingPlan: false,
        pendingPlan: plan,
      );
    } catch (e) {
      print('[ChatControlController] ✗ ERRO ao gerar plano: $e');
      state = state.copyWith(
        isGeneratingPlan: false,
        errorMessage: 'Erro ao gerar plano: ${e.toString()}',
      );
    }
  }

  /// Aprova e executa o plano pendente
  Future<void> approvePlan() async {
    final plan = state.pendingPlan;
    if (plan == null || plan.isEmpty) return;

    state = state.copyWith(
      isExecutingActions: true,
      errorMessage: null,
      clearError: true,
    );

    final executedActions = <ExecutedAction>[];
    final snapshot = state.currentSnapshot;

    if (snapshot == null) {
      state = state.copyWith(
        isExecutingActions: false,
        errorMessage: 'Snapshot não disponível',
      );
      return;
    }

    try {
      // Executar cada ação sequencialmente
      for (final action in plan.actions) {
        final result = await _actionExecutor.execute(action, snapshot);
        executedActions.add(result);

        // Pequeno delay entre ações
        await Future.delayed(const Duration(milliseconds: 300));

        // Aguardar atualização do snapshot (timeout de 3s)
        await _waitForSnapshotUpdate(const Duration(seconds: 3));
      }

      // Adicionar ao histórico
      final newHistory = [...state.actionHistory, ...executedActions];

      state = state.copyWith(
        isExecutingActions: false,
        pendingPlan: null,
        actionHistory: newHistory,
      );
    } catch (e) {
      state = state.copyWith(
        isExecutingActions: false,
        errorMessage: 'Erro ao executar ações: ${e.toString()}',
      );
    }
  }

  /// Rejeita o plano pendente
  void rejectPlan() {
    state = state.copyWith(pendingPlan: null);
  }

  /// Aguarda atualização do snapshot
  Future<void> _waitForSnapshotUpdate(Duration timeout) async {
    final startTime = DateTime.now();
    final initialTimestamp = state.currentSnapshot?.timestamp;

    while (DateTime.now().difference(startTime) < timeout) {
      await Future.delayed(const Duration(milliseconds: 200));
      final currentTimestamp = state.currentSnapshot?.timestamp;
      if (currentTimestamp != null &&
          currentTimestamp != initialTimestamp) {
        return; // Snapshot atualizado
      }
    }
    // Timeout - continuar mesmo sem confirmação visual
  }

  @override
  void dispose() {
    _snapshotSubscription?.cancel();
    _snapshotThrottle?.cancel();
    super.dispose();
  }
}

