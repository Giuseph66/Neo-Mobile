import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/config/ai_config_store.dart';
import '../../ai/providers/provider_registry.dart';
import '../../inspector_accessibility/data/inspector_repository_impl.dart';
import '../../inspector_accessibility/presentation/accessibility_inspector_controller.dart';
import '../../llm/generation_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/composer_bar.dart';
import '../../widgets/status_badge.dart';
import '../chat_control_controller.dart';
import '../widgets/search_results_card.dart';
import '../widgets/ui_snapshot_painter.dart';
import '../widgets/action_plan_card.dart';
import '../services/command_detector.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/model_icon.dart';

final chatControlControllerProvider = StateNotifierProvider.autoDispose<
    ChatControlController, ChatControlState>((ref) {
  final inspectorController = AccessibilityInspectorController();
  final generationController = ref.read(generationControllerProvider.notifier);
  final providerRegistry = ref.read(providerRegistryProvider);
  final config = ref.read(aiConfigProvider.notifier);

  return ChatControlController(
    inspectorController,
    generationController,
    providerRegistry,
    config,
  );
});

class ChatControlScreen extends ConsumerStatefulWidget {
  const ChatControlScreen({super.key});

  @override
  ConsumerState<ChatControlScreen> createState() => _ChatControlScreenState();
}

class _ChatControlScreenState extends ConsumerState<ChatControlScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final InspectorRepositoryImpl _repository = InspectorRepositoryImpl();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controlState = ref.watch(chatControlControllerProvider);
    final chatState = ref.watch(generationControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ModelIcon(
              providerId: ref.watch(aiConfigProvider).activeProvider,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text('Chat Control'),
          ],
        ),
        actions: [
          // Toggle Overlay Visual
          IconButton(
            icon: Icon(
              controlState.showVisualOverlay
                  ? Icons.layers
                  : Icons.layers_outlined,
              color: controlState.showVisualOverlay ? AppColors.primary : null,
            ),
            tooltip: 'Visualizar Elementos',
            onPressed: () {
              ref.read(chatControlControllerProvider.notifier).toggleVisualOverlay();
            },
          ),
          // Toggle Controls
          IconButton(
            icon: Icon(
              controlState.showControls ? Icons.unfold_less : Icons.unfold_more,
            ),
            tooltip: controlState.showControls ? 'Ocultar Controles' : 'Mostrar Controles',
            onPressed: () {
              ref.read(chatControlControllerProvider.notifier).toggleControls();
            },
          ),
          // Toggle Inspector
          IconButton(
            icon: Icon(
              controlState.isInspectorActive
                  ? Icons.visibility
                  : Icons.visibility_off,
              color: controlState.isInspectorActive ? AppColors.success : null,
            ),
            tooltip: controlState.isInspectorActive ? 'Inspector Ativo' : 'Inspector Inativo',
            onPressed: () {
              if (controlState.isInspectorActive) {
                ref.read(chatControlControllerProvider.notifier).stopInspector();
              } else {
                ref.read(chatControlControllerProvider.notifier).startInspector();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camada de Fundo (Elementos detectados)
          if (controlState.showVisualOverlay && controlState.currentSnapshot != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.3, // Deixar sutil para não atrapalhar o chat
                child: CustomPaint(
                  painter: UiSnapshotPainter(
                    nodes: controlState.currentSnapshot!.nodes,
                  ),
                ),
              ),
            ),

          // Content
          Column(
            children: [
              // Painel de Status e Navegação (Colapsável)
              AnimatedCrossFade(
                firstChild: _buildDashboard(controlState),
                secondChild: const SizedBox.shrink(),
                crossFadeState: controlState.showControls
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 300),
              ),
              
              // Chat messages e resultados de busca
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    // Mensagens do chat normal (conversas)
                    ...chatState.messages.map((message) => ChatBubble(
                          message: message,
                        )),
                    // Feedback de geração de plano
                    if (controlState.isGeneratingPlan) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Gerando plano de ações...',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.text2,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Plano de ações pendente (apenas para comandos de controle)
                    if (controlState.pendingPlan != null) ...[
                      const SizedBox(height: 16),
                      ActionPlanCard(
                        plan: controlState.pendingPlan!,
                        snapshot: controlState.currentSnapshot,
                        onApprove: () {
                          ref.read(chatControlControllerProvider.notifier).approvePlan();
                        },
                        onReject: () {
                          ref.read(chatControlControllerProvider.notifier).rejectPlan();
                        },
                        isExecuting: controlState.isExecutingActions,
                      ),
                    ],
                    // Resultados de busca
                    if (controlState.searchResults != null &&
                        controlState.searchResults!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSearchResults(controlState),
                    ],
                    // Mensagens de erro
                    if (controlState.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                controlState.errorMessage!,
                                style: TextStyle(color: AppColors.danger, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Composer
              ComposerBar(
                controller: _textController,
                isGenerating: chatState.isGenerating ||
                    controlState.isGeneratingPlan,
                onSend: _onSend,
                onStop: () {
                  ref.read(generationControllerProvider.notifier).stop();
                },
                onClear: () {
                  ref.read(generationControllerProvider.notifier).clear();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    print('[ChatControlScreen] ========================================');
    print('[ChatControlScreen] 📤 MENSAGEM ENVIADA: "$text"');
    print('[ChatControlScreen] ========================================');

    // Detectar se é comando de controle ou conversa normal
    final isControlCommand = CommandDetector.isControlCommand(text);

    if (isControlCommand) {
      print('[ChatControlScreen] 🎯 COMANDO DE CONTROLE DETECTADO!');
      print('[ChatControlScreen] → Adicionando mensagem ao chat...');
      // Mostrar a mensagem do usuário no chat imediatamente (sem chamar o LLM aqui).
      ref.read(generationControllerProvider.notifier).appendLocalUserMessage(text);

      print('[ChatControlScreen] → Buscando elementos salvos relacionados...');
      // É um comando de controle → tentar gerar plano de ações
      // Buscar elementos salvos relacionados
      ref.read(chatControlControllerProvider.notifier).searchElements(text);
      
      print('[ChatControlScreen] → Enviando comando para gerar plano de ações...');
      // Enviar comando para gerar plano (usa prompt especial com contexto da tela)
      ref.read(chatControlControllerProvider.notifier).sendCommand(text);
      
      // Se não conseguir gerar plano (sem elementos), enviar para chat normal como fallback
      // Isso será verificado depois quando o plano não for gerado
    } else {
      print('[ChatControlScreen] 💬 CONVERSA NORMAL detectada');
      print('[ChatControlScreen] → Enviando para o chat normal (LLM padrão)...');
      // É uma conversa normal → enviar para o chat normal (LLM padrão)
      ref.read(generationControllerProvider.notifier).sendPrompt(text);
    }

    _textController.clear();
  }

  Widget _buildDashboard(ChatControlState state) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface0,
        border: Border(bottom: BorderSide(color: AppColors.outline0)),
      ),
      child: Column(
        children: [
          _buildStatusBar(state),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildStatusBar(ChatControlState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          StatusBadge(
            label: state.isInspectorActive ? 'Inspector ON' : 'Inspector OFF',
            color: state.isInspectorActive
                ? AppColors.success
                : AppColors.muted,
          ),
          const SizedBox(width: 8),
          if (state.currentSnapshot != null)
            StatusBadge(
              label: '${state.currentSnapshot!.nodes.length} elementos',
              color: AppColors.primary,
            ),
          const Spacer(),
          if (state.isInspectorActive)
            const Text(
              'Terminal Logs: ON',
              style: TextStyle(fontSize: 10, color: AppColors.text2),
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavButton(
            icon: Icons.home,
            onPressed: () => _repository.navigateHome(),
          ),
          _buildNavButton(
            icon: Icons.arrow_back,
            onPressed: () => _repository.navigateBack(),
          ),
          _buildNavButton(
            icon: Icons.apps,
            onPressed: () => _repository.navigateRecents(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.outline0),
            ),
            child: Icon(icon, size: 20, color: AppColors.text1),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(ChatControlState state) {
    return SearchResultsCard(
      results: state.searchResults!,
      query: state.searchQuery ?? '',
      onElementSelected: (element) {
        // Seleção de elemento salvos
      },
    );
  }
}

