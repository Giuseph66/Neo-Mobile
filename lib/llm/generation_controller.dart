import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/config/ai_config_store.dart';
import '../ai/models/chat_message.dart';
import '../ai/models/chat_reply.dart';
import '../ai/models/chat_session.dart';
import '../ai/providers/chat_provider.dart';
import '../ai/providers/provider_registry.dart';
import '../ai/storage/chat_store.dart';

class ChatState {
  const ChatState({
    this.messages = const [],
    this.isGenerating = false,
    this.activeProviderId,
    this.activeModelId,
    this.tokensPerSecond = 0,
  });

  final List<ChatMessage> messages;
  final bool isGenerating;
  final String? activeProviderId;
  final String? activeModelId;
  final double tokensPerSecond;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isGenerating,
    String? activeProviderId,
    String? activeModelId,
    double? tokensPerSecond,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      activeProviderId: activeProviderId ?? this.activeProviderId,
      activeModelId: activeModelId ?? this.activeModelId,
      tokensPerSecond: tokensPerSecond ?? this.tokensPerSecond,
    );
  }
}

class GenerationController extends StateNotifier<ChatState> {
  GenerationController(this._registry, this._config)
      : super(const ChatState());

  final ProviderRegistry _registry;
  final AiConfigStore _config;
  StreamSubscription<String>? _streamSub;
  ChatStore? _store;
  ChatSession? _session;
  String? _currentUserText;
  final StringBuffer _replyBuffer = StringBuffer();
  int _tokenCount = 0;
  DateTime? _startTime;
  DateTime? _lastTpsUpdate;
  int _requestToken = 0;

  Future<void> initialize() async {
    await _config.load();
    _store = await ChatStore.open();
    final activeSession = await _store?.loadActiveSession();
    if (activeSession != null) {
      _session = activeSession;
    } else {
      final provider = _config.state.activeProvider;
      final modelId =
          _config.state.activeModels[provider] ?? _defaultModel(provider);
      _session = ChatSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        providerId: provider.name,
        modelId: modelId,
        messages: const [],
      );
      await _store?.saveSession(_session!);
    }
    state = state.copyWith(
      messages: _session?.messages ?? const [],
      activeProviderId: _session?.providerId,
      activeModelId: _session?.modelId,
    );
  }

  Future<void> sendPrompt(String text) async {
    if (state.isGenerating || text.trim().isEmpty) {
      return;
    }
    final requestToken = ++_requestToken;
    final providerId = _config.state.activeProvider;
    final modelId =
        _config.state.activeModels[providerId] ?? _defaultModel(providerId);
    final nextSession = _ensureSession(providerId.name, modelId);
    final sessionChanged = _session == null ||
        _session!.providerId != nextSession.providerId ||
        _session!.modelId != nextSession.modelId;
    if (sessionChanged) {
      _session = nextSession;
      state = state.copyWith(messages: nextSession.messages);
    }

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: ChatRole.user,
      text: text.trim(),
      createdAt: DateTime.now(),
    );
    final assistantMessage = ChatMessage(
      id: '${userMessage.id}_assistant',
      role: ChatRole.assistant,
      text: '',
      createdAt: DateTime.now(),
      streaming: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage, assistantMessage],
      isGenerating: true,
      activeProviderId: providerId.name,
      activeModelId: modelId,
      tokensPerSecond: 0,
    );

    _tokenCount = 0;
    _startTime = DateTime.now();
    _lastTpsUpdate = _startTime;

    final provider = _registry.byId(providerId.name);
    final session = _session ?? _fallbackSession(providerId.name, modelId);

    _streamSub?.cancel();
    _currentUserText = text.trim();
    _replyBuffer.clear();

    if (provider.providerId == 'local') {
      _streamSub = provider
          .streamMessage(session, text.trim())
          .listen(_handleChunk, onError: (error) {
        _finalize(error: error.toString());
      }, onDone: () async {
        _commitLocalReply();
        if (_session != null) {
          await _store?.saveSession(_session!);
        }
        _finalize();
      });
    } else {
      try {
        final reply = await provider.sendMessage(session, text.trim());
        if (requestToken != _requestToken) {
          return;
        }
        _applyReply(reply);
      } catch (e) {
        if (requestToken != _requestToken) {
          return;
        }
        _finalize(error: e.toString());
      }
    }
  }

  Future<void> stop() async {
    await _streamSub?.cancel();
    _requestToken++;
    _finalize(interrupted: true);
  }

  void clear() {
    _session = _session?.copyWith(messages: const []);
    state = state.copyWith(messages: const []);
    if (_session != null) {
      _store?.saveSession(_session!);
    }
  }

  void _handleChunk(String chunk) {
    if (chunk.isEmpty) {
      return;
    }
    _replyBuffer.write(chunk);
    final messages = [...state.messages];
    final index = messages.lastIndexWhere(
      (message) => message.role == ChatRole.assistant && message.streaming,
    );
    if (index >= 0) {
      final current = messages[index];
      messages[index] = current.copyWith(text: current.text + chunk);
      state = state.copyWith(messages: messages);
      _updateTokensPerSecond();
    }
  }

  void _finalize({String? error, bool interrupted = false}) {
    final messages = [...state.messages];
    final index = messages.lastIndexWhere(
      (message) => message.role == ChatRole.assistant && message.streaming,
    );
    if (index >= 0) {
      final current = messages[index];
      final text = error == null
          ? (interrupted && current.text.isEmpty ? '[Interrompido]' : current.text)
          : '${current.text}\n\n[Erro] $error';
      messages[index] = current.copyWith(text: text, streaming: false);
    }
    state = state.copyWith(
      messages: messages,
      isGenerating: false,
      tokensPerSecond: 0,
    );
    _tokenCount = 0;
    _startTime = null;
    _lastTpsUpdate = null;
  }

  void _updateTokensPerSecond() {
    final start = _startTime;
    if (start == null) {
      return;
    }
    _tokenCount += 1;
    final now = DateTime.now();
    final elapsedMs = now.difference(start).inMilliseconds;
    if (elapsedMs <= 0) {
      return;
    }
    if (_lastTpsUpdate == null ||
        now.difference(_lastTpsUpdate!).inMilliseconds >= 400) {
      final tps = _tokenCount / (elapsedMs / 1000);
      state = state.copyWith(tokensPerSecond: tps);
      _lastTpsUpdate = now;
    }
  }

  ChatSession _ensureSession(String providerId, String modelId) {
    final current = _session;
    if (current == null ||
        current.providerId != providerId ||
        current.modelId != modelId) {
      return ChatSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        providerId: providerId,
        modelId: modelId,
        messages: const [],
      );
    }
    return current;
  }

  ChatSession _fallbackSession(String providerId, String modelId) {
    return ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      providerId: providerId,
      modelId: modelId,
      messages: const [],
    );
  }

  String _defaultModel(AiProviderId provider) {
    if (provider == AiProviderId.openai) {
      return _registry.openAiProvider.supportedModels.first;
    }
    if (provider == AiProviderId.gemini) {
      return _registry.geminiProvider.supportedModels.first;
    }
    return '';
  }

  void _commitLocalReply() {
    final userText = _currentUserText;
    if (_session == null || userText == null) {
      return;
    }
    final updated = _session!.copyWith(
      messages: [
        ..._session!.messages,
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: ChatRole.user,
          text: userText,
          createdAt: DateTime.now(),
        ),
        ChatMessage(
          id: '${DateTime.now().millisecondsSinceEpoch}_assistant',
          role: ChatRole.assistant,
          text: _replyBuffer.toString(),
          createdAt: DateTime.now(),
        ),
      ],
    );
    _session = updated;
  }

  void _applyReply(ChatReply reply) {
    _session = reply.updatedSession;
    final messages = [...state.messages];
    final index = messages.lastIndexWhere(
      (message) => message.role == ChatRole.assistant && message.streaming,
    );
    if (index >= 0) {
      final current = messages[index];
      messages[index] = current.copyWith(text: reply.text, streaming: false);
    }
    state = state.copyWith(
      messages: messages,
      isGenerating: false,
      tokensPerSecond: 0,
    );
    _store?.saveSession(reply.updatedSession);
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }
}

final generationControllerProvider =
    StateNotifierProvider<GenerationController, ChatState>((ref) {
  return GenerationController(
    ref.read(providerRegistryProvider),
    ref.read(aiConfigProvider.notifier),
  );
});
