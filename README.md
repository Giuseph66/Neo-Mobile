# Chat Local LLM (Offline)

Modulo Flutter + Android para chat local com LLM rodando offline no dispositivo.

## Como rodar

```bash
flutter pub get
flutter run
```

## Funcionalidades

- Chat estilo ChatGPT com streaming de tokens.
- Modelos GGUF locais com perfis de desempenho.
- Lista de modelos recomendados embutida no app.
- Importar modelo por arquivo ou baixar por URL (menu de tres pontos).
- Remocao de modelos locais com confirmacao.

## Como usar

1) Abra Configuracoes > Modelos locais.
2) Escolha um modelo recomendado e baixe, ou use o menu "..." para importar.
3) Selecione e carregue o modelo.
4) Volte ao chat e envie mensagens.

## Modelos recomendados

Leves:
- Qwen2.5 0.5B Instruct (Q4_K_M)
- Llama 3.2 1B Instruct (Q4_K_M)
- Qwen2.5 1.5B Instruct (Q4_0_4_4)

Dia a dia:
- Gemma 2 2B IT (Q4_K_M)
- Llama 3.2 3B Instruct (Q4_K_M)
- Phi-3.5 Mini Instruct (Q4_K_M)
- Phi-3 Mini 4K Instruct (q4)

No limite:
- Mistral 7B Instruct v0.3 (Q4_K_M)
- Qwen2.5 7B Instruct (Q4_K_M)
- Meta Llama 3.1 8B Instruct (Q4_K_M)

## Android (LLM local)

A integracao usa JNI com stub local. Para ativar inferencia real:

1) Adicione o codigo do llama.cpp em `android/llama/`.
2) Atualize `android/app/src/main/cpp/CMakeLists.txt` para compilar o llama.cpp.
3) Implemente as funcoes nativas em `llama_jni.cpp` para carregar e gerar tokens.

## Canais Flutter <-> Android

MethodChannel: `local_llm`
- getDeviceInfo
- listModels
- setActiveModel
- getActiveModel
- importModel
- downloadModel
- loadModel
- unloadModel
- deleteModel
- generate
- stopGeneration

EventChannel: `local_llm_events`
- download_progress
- download_error
- model_loaded
- model_error
- token
- done
- error

## Estrutura

- `lib/theme/`: cores e tema neon.
- `lib/llm/`: service, registry, prefs, generation.
- `lib/screens/`: hub, chat e settings.
- `lib/widgets/`: cards, badges e componentes.
- `android/app/src/main/kotlin/com/example/neo/llm/`: engine e plugin.
- `android/app/src/main/cpp/`: JNI stub.

## Limitacoes

- Stub JNI apenas ecoa o prompt. Necessario integrar llama.cpp para inferencia real.
- Modelos grandes exigem bastante RAM.
# Neo-Mobile
