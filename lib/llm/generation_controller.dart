import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'llm_prefs.dart';
import 'local_llm_service.dart';
import 'model_registry.dart';

enum MessageRole { user, assistant }

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.streaming = false,
  });

  final String id;
  final MessageRole role;
  final String text;
  final bool streaming;

  ChatMessage copyWith({String? text, bool? streaming}) {
    return ChatMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      streaming: streaming ?? this.streaming,
    );
  }
}

class ChatState {
  const ChatState({
    this.messages = const [],
    this.isGenerating = false,
    this.activeRequestId,
    this.tokensPerSecond = 0,
  });

  final List<ChatMessage> messages;
  final bool isGenerating;
  final String? activeRequestId;
  final double tokensPerSecond;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isGenerating,
    String? activeRequestId,
    double? tokensPerSecond,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      activeRequestId: activeRequestId ?? this.activeRequestId,
      tokensPerSecond: tokensPerSecond ?? this.tokensPerSecond,
    );
  }
}

class GenerationController extends StateNotifier<ChatState> {
  GenerationController(this._service, this._prefs) : super(const ChatState());

  final LocalLlmService _service;
  final LlmPrefsController _prefs;
  StreamSubscription<Map<String, dynamic>>? _sub;
  int _tokenCount = 0;
  DateTime? _startTime;
  DateTime? _lastTpsUpdate;

  void attach() {
    _sub ??= _service.events.listen(_handleEvent);
  }

  Future<void> sendPrompt(String text) async {
    if (state.isGenerating || text.trim().isEmpty) {
      return;
    }

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.user,
      text: text.trim(),
    );
    final assistantMessage = ChatMessage(
      id: 'assistant_${userMessage.id}',
      role: MessageRole.assistant,
      text: '',
      streaming: true,
    );
    state = state.copyWith(
      messages: [...state.messages, userMessage, assistantMessage],
      isGenerating: true,
      tokensPerSecond: 0,
    );
    _tokenCount = 0;
    _startTime = DateTime.now();
    _lastTpsUpdate = _startTime;

    final requestId = await _service.generate(
      text.trim(),
      _prefs.state.toGenerationParams(),
    );
    state = state.copyWith(activeRequestId: requestId);
  }

  Future<void> stop() async {
    final requestId = state.activeRequestId;
    if (requestId == null) {
      return;
    }
    await _service.stopGeneration(requestId);
    _finalize(interrupted: true);
  }

  void clear() {
    state = const ChatState();
  }

  void _handleEvent(Map<String, dynamic> event) {
    final type = event['type'];
    if (type == 'token') {
      final requestId = event['requestId']?.toString();
      if (requestId == null || requestId != state.activeRequestId) {
        return;
      }
      final chunk = event['textChunk']?.toString() ?? '';
      final tps = (event['tps'] as num?)?.toDouble();
      final messages = [...state.messages];
      final index = messages.lastIndexWhere(
        (message) => message.role == MessageRole.assistant && message.streaming,
      );
      if (index >= 0) {
        final current = messages[index];
        messages[index] = current.copyWith(text: current.text + chunk);
        state = state.copyWith(
          messages: messages,
          tokensPerSecond: tps != null && tps > 0 ? tps : state.tokensPerSecond,
        );
        if (tps == null || tps <= 0) {
          _updateTokensPerSecond();
        }
      }
    } else if (type == 'done') {
      _finalize();
    } else if (type == 'error') {
      _finalize(error: event['message']?.toString());
    }
  }

  void _finalize({String? error, bool interrupted = false}) {
    final messages = [...state.messages];
    final index = messages.lastIndexWhere(
      (message) => message.role == MessageRole.assistant && message.streaming,
    );
    if (index >= 0) {
      final current = messages[index];
      final text = error == null
          ? (interrupted && current.text.isEmpty
              ? '[Interrompido]'
              : current.text)
          : '${current.text}\n\n[Erro] $error';
      messages[index] = current.copyWith(text: text, streaming: false);
    }
    state = state.copyWith(
      messages: messages,
      isGenerating: false,
      activeRequestId: null,
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

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final generationControllerProvider =
    StateNotifierProvider<GenerationController, ChatState>((ref) {
  return GenerationController(
    ref.read(localLlmServiceProvider),
    ref.read(llmPrefsProvider.notifier),
  );
});
