# Resumo das Funcionalidades - Neo Mobile

## 1. Chat Local LLM (Módulo Principal)
- Chat estilo ChatGPT com interface moderna e tema neon escuro
- Streaming de tokens em tempo real para modelos locais
- Indicador de velocidade (tokens/segundo) durante geração
- Histórico de conversas com mensagens do usuário e assistente
- Botões de controle: enviar, parar geração, limpar chat
- Suporte a três providers de IA: Local (GGUF), OpenAI e Google Gemini

## 2. Gerenciamento de Modelos Locais (GGUF)
- Lista de modelos recomendados embutida (Qwen, Llama, Gemma, Phi, Mistral)
- Download de modelos por URL com barra de progresso
- Importação de modelos por arquivo local
- Seleção e carregamento de modelos GGUF
- Remoção de modelos com confirmação
- Perfis de desempenho pré-configurados (Rápido, Padrão, Qualidade, A54)
- Integração JNI com llama.cpp compilado para arm64-v8a

## 3. Configurações de API e Modelos
- Configuração de API keys para OpenAI e Gemini (armazenamento seguro)
- Seleção de modelos remotos (GPT-4, GPT-3.5, Gemini Pro, etc.)
- Ativação/desativação de providers
- Status visual de conexão e configuração

## 4. Configurações de Performance
- Ajuste de parâmetros de geração: contexto, threads, temperatura, top-p, top-k
- Perfis de desempenho personalizáveis
- Monitoramento de uso de CPU e memória (PSS e RSS)
- Card de desempenho com estatísticas em tempo real

## 5. Inspector de Widgets Flutter
- Inspeção visual de widgets do próprio app
- Overlay interativo com informações de widgets
- Registro de widgets marcados como "inspectable"
- Categorização de elementos (botões, inputs, cards, listas)
- Painel lateral com detalhes de propriedades
- Hit testing para identificar widgets sob toque

## 6. Inspector de Acessibilidade Android
- Captura de snapshot da UI de apps terceiros via AccessibilityService
- Detecção de elementos clicáveis, scrolláveis e habilitados
- Extração de texto, classes, bounds e caminhos de acessibilidade
- Navegação entre apps (Home, Voltar, Apps Recentes)
- Permissões de acessibilidade com fluxo guiado
- Visualização de elementos detectados com overlay semi-transparente

## 7. Chat Control (IA Controlando Apps)
- Comandos em português para controlar apps terceiros
- Geração de planos de ação via LLM baseados em comandos
- Busca de elementos salvos relacionados ao comando
- Execução automática de ações (cliques, scrolls, digitação)
- Visualização de snapshot atual da tela
- Integração entre chat LLM e inspector de acessibilidade
- Histórico de ações executadas

## 8. Armazenamento de Elementos
- Banco de dados SQLite para elementos de UI capturados
- Agrupamento de elementos por sessão/app
- Busca de elementos salvos por texto ou propriedades
- Visualização detalhada de elementos (bounds, classes, paths)
- Gerenciamento de grupos de elementos nas configurações

## 9. Automação e Workflows
- Gravação de gestos (tap, long press, drag)
- Criação de workflows com múltiplas ações
- Atalhos de teclado personalizáveis (Ctrl+Shift+Key, etc.)
- Execução de workflows gravados
- Editor visual de workflows com lista de ações
- Ajuste de duração de gestos (hold duration, drag duration)
- Captura de atalhos de teclado em tempo real

## 10. Overlay de Tela
- Serviço de overlay Android para desenhar sobre outros apps
- Permissão de sobreposição com solicitação guiada
- Controle de início/parada do serviço de overlay
- Integração com inspector para ativação automática

## 11. Interface e Navegação
- Hub central com módulos principais (Chat, Inspector, Chat Control)
- Tema neon escuro personalizado
- Cards com efeito neon e bordas coloridas
- Badges de status (ATIVADO, PENDENTE, SEM MODELO, etc.)
- Navegação entre telas com rotas nomeadas
- Layout responsivo (mobile e desktop)

## 12. Persistência e Estado
- Hive para armazenamento de configurações
- SharedPreferences para preferências do usuário
- Flutter Secure Storage para API keys
- Riverpod para gerenciamento de estado reativo
- Sincronização automática de estado entre telas

## 13. Comunicação Flutter-Android
- MethodChannel para comandos (listModels, loadModel, generate, etc.)
- EventChannel para eventos (tokens, progresso, erros)
- Callbacks assíncronos para streaming de tokens
- Tratamento de erros e exceções

## 14. Funcionalidades Auxiliares
- Limpeza de chat e histórico
- Exportação/importação de conversas (estrutura preparada)
- Busca em conversas e elementos
- Logs de terminal para debug do inspector
- Refresh manual de status e dados

## 15. Experiência do Usuário
- Feedback visual imediato (snackbars, badges, cores)
- Validação de inputs e estados
- Mensagens de erro descritivas
- Confirmações para ações destrutivas
- Loading states durante operações assíncronas
- Scroll automático para novas mensagens no chat

