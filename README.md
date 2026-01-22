# Chat Local LLM + OpenAI + Gemini

Modulo Flutter + Android para chat com 3 providers selecionaveis:
- Local LLM (GGUF) rodando offline no dispositivo.
- OpenAI (texto via API).
- Google Gemini (texto via API).

## Como rodar

```bash
flutter pub get
flutter run
```

## Funcionalidades

- Chat estilo ChatGPT com streaming de tokens no modo local.
- Providers: Local, OpenAI e Gemini.
- Indicador de tokens/s no chat para o LLM local.
- Modelos GGUF locais com perfis de desempenho.
- Lista de modelos recomendados embutida no app.
- Importar modelo por arquivo ou baixar por URL (menu de tres pontos).
- Remocao de modelos locais com confirmacao.

## Como usar

### Local LLM

1) Abra Configuracoes > Modelos locais.
2) Escolha um modelo recomendado e baixe, ou use o menu "..." para importar.
3) Selecione e carregue o modelo.
4) Volte ao chat e envie mensagens.

### OpenAI / Gemini

1) Abra Configuracoes > API e Modelos.
2) Escolha a aba OpenAI ou Google Gemini.
3) Salve a API key e selecione o modelo.
4) Clique em "Ativar Modelo".

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

A integracao usa JNI com llama.cpp compilado para arm64-v8a.

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
- `lib/ai/`: providers (local/openai/gemini) e configuracao.
- `lib/screens/`: hub, chat e settings.
- `lib/widgets/`: cards, badges e componentes.
- `android/app/src/main/kotlin/com/example/neo/llm/`: engine e plugin.
- `android/app/src/main/cpp/`: JNI llama.cpp.

## Limitacoes

- Modelos grandes exigem bastante RAM e podem ser lentos em celulares mais fracos.
- OpenAI/Gemini exigem internet e uma API key valida.
- Modelos grandes exigem bastante RAM.
# Neo-Mobile
