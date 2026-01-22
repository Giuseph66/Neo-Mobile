class PredefinedModel {
  const PredefinedModel({
    required this.id,
    required this.name,
    required this.url,
    required this.tag,
  });

  final String id;
  final String name;
  final String url;
  final String tag;

  String get fileName {
    final uri = Uri.parse(url);
    return uri.pathSegments.isEmpty ? '$id.gguf' : uri.pathSegments.last;
  }

  String get quantHint {
    final regex = RegExp(r'Q\d+[_A-Z0-9]*');
    final match = regex.firstMatch(fileName);
    return match?.group(0) ?? 'GGUF';
  }
}

const List<PredefinedModel> kPredefinedModels = [
  PredefinedModel(
    id: 'qwen25_0_5b',
    name: 'Qwen2.5 0.5B Instruct',
    url:
        'https://huggingface.co/bartowski/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf',
    tag: 'Leve',
  ),
  PredefinedModel(
    id: 'llama3_2_1b',
    name: 'Llama 3.2 1B Instruct',
    url:
        'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
    tag: 'Leve',
  ),
  PredefinedModel(
    id: 'qwen25_1_5b',
    name: 'Qwen2.5 1.5B Instruct',
    url:
        'https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_0_4_4.gguf',
    tag: 'Leve',
  ),
  PredefinedModel(
    id: 'gemma2_2b',
    name: 'Gemma 2 2B IT',
    url:
        'https://huggingface.co/NexaAI/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-q4_K_M.gguf',
    tag: 'Dia a dia',
  ),
  PredefinedModel(
    id: 'llama3_2_3b',
    name: 'Llama 3.2 3B Instruct',
    url:
        'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
    tag: 'Dia a dia',
  ),
  PredefinedModel(
    id: 'phi3_5_mini',
    name: 'Phi-3.5 Mini Instruct',
    url:
        'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf',
    tag: 'Dia a dia',
  ),
  PredefinedModel(
    id: 'phi3_mini',
    name: 'Phi-3 Mini 4K Instruct',
    url:
        'https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf',
    tag: 'Dia a dia',
  ),
  PredefinedModel(
    id: 'mistral7b',
    name: 'Mistral 7B Instruct v0.3',
    url:
        'https://huggingface.co/bartowski/Mistral-7B-Instruct-v0.3-GGUF/resolve/main/Mistral-7B-Instruct-v0.3-Q4_K_M.gguf',
    tag: 'No limite',
  ),
  PredefinedModel(
    id: 'qwen25_7b',
    name: 'Qwen2.5 7B Instruct',
    url:
        'https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf',
    tag: 'No limite',
  ),
  PredefinedModel(
    id: 'llama3_1_8b',
    name: 'Meta Llama 3.1 8B Instruct',
    url:
        'https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf',
    tag: 'No limite',
  ),
];
