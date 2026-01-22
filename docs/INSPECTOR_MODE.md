# Inspector Mode - Documentação

## Visão Geral

O Inspector Mode é uma ferramenta de inspeção visual e teste para desenvolvedores que permite visualizar elementos da interface de apps terceiros e executar ações de teste de forma explícita e controlada.

## Como Ativar Permissões

### 1. Permissão de Acessibilidade

1. Abra o app e navegue até a tela "Permissões" (rota `/permissions`)
2. Toque em "Abrir Configurações de Acessibilidade"
3. Na tela de configurações do Android, encontre "Inspector Mode" na lista de serviços
4. Ative o serviço
5. Confirme o aviso de segurança (se aparecer)
6. Volte ao app e verifique se o status mostra "Acessibilidade ON"

### 2. Permissão de Overlay

1. Na tela "Permissões", toque em "Solicitar Permissão de Overlay"
2. Na tela de configurações, encontre o app "neo" na lista
3. Ative a permissão "Desenhar sobre outros apps"
4. Volte ao app e verifique se o status mostra "Overlay ON"

## O que o app faz

- ✅ Inspeciona elementos da UI (metadados: classe, bounds, clickable, enabled, scrollable)
- ✅ Desenha bounding boxes sobre elementos detectados
- ✅ Permite selecionar elementos visualmente
- ✅ Executa ações de teste (clique, scroll, swipe) quando o usuário solicita explicitamente
- ✅ Permite tap manual por coordenadas quando elementos não estão disponíveis

## O que o app NÃO faz

- ❌ NÃO captura texto digitado (senhas, OTP, campos de entrada)
- ❌ NÃO automatiza ações em background
- ❌ NÃO envia dados para servidores externos
- ❌ NÃO faz keylogging
- ❌ NÃO loga árvores completas de acessibilidade em produção

## Como Usar

### Iniciar o Inspector Mode

1. Abra a tela "Inspector Home" (rota `/inspector`)
2. Toque em "Iniciar Inspector Mode"
3. Se o serviço de acessibilidade não estiver habilitado, você será redirecionado para as configurações

### Inspecionar Elementos

1. Com o Inspector Mode ativo, abra qualquer app terceiro
2. Os elementos detectados aparecerão na lista do Inspector Home
3. Ative "Desenhar boxes" para ver retângulos sobre os elementos na tela
4. Use "Ativar Mira" para arrastar e destacar elementos sob o cursor

### Selecionar e Executar Ações

1. Toque em um elemento na lista ou use a mira para selecionar
2. O elemento selecionado será destacado em verde
3. Toque em "Executar agora" e escolha a ação:
   - **Clique**: Executa `ACTION_CLICK` no elemento
   - **Scroll para Baixo/Cima**: Executa scroll no elemento
   - **Swipe Manual**: Permite configurar um swipe personalizado

### Tap Manual

Quando nenhum elemento está disponível (apps protegidos):

1. Toque em "Tap Manual por Coordenadas"
2. Digite as coordenadas X e Y
3. Toque em "Executar" para realizar o tap na posição especificada

### Parar o Inspector

- Toque no botão **STOP** (vermelho) sempre visível no canto inferior direito
- Ou use o botão de parar na AppBar

## Troubleshooting

### Android 12+

- **Problema**: Permissão de notificação não concedida
- **Solução**: Vá em Configurações > Apps > neo > Notificações e ative

### Android 13+

- **Problema**: Foreground Service não inicia
- **Solução**: Verifique se a permissão `FOREGROUND_SERVICE_SPECIAL_USE` está configurada (já está no manifest)

### Android 14+

- **Problema**: AccessibilityService não acessa apps protegidos
- **Solução**: Isso é esperado. Apps bancários e outros apps protegidos podem não expor elementos. Use "Tap Manual por Coordenadas" como alternativa.

### Problemas Comuns

1. **"Conteúdo indisponível" aparece sempre**
   - Verifique se o serviço de acessibilidade está realmente habilitado
   - **IMPORTANTE**: Se você atualizou o app, desative e reative o serviço de acessibilidade nas configurações
   - Alguns apps podem bloquear acesso por segurança
   - Tente com um app diferente para testar

2. **Inspector só funciona no próprio app, não em apps terceiros**
   - Desative o serviço de acessibilidade nas Configurações
   - Reinstale o app ou faça rebuild
   - Reative o serviço de acessibilidade
   - Isso é necessário quando a configuração XML do serviço é alterada

2. **Bounding boxes não aparecem**
   - Verifique se "Desenhar boxes" está ativado
   - Verifique se a permissão de overlay está concedida
   - Reinicie o app se necessário

3. **Ações não funcionam**
   - Verifique se um elemento está selecionado
   - Alguns elementos podem não suportar certas ações
   - Tente com outro elemento

## Roteiro de Teste Manual (APK)

### Pré-requisitos

1. Instale o APK no dispositivo Android
2. Certifique-se de que o dispositivo está em modo desenvolvedor (se necessário)

### Teste 1: Ativação Básica

1. Abra o app
2. Navegue para `/permissions`
3. Ative a permissão de Acessibilidade
4. Ative a permissão de Overlay
5. Verifique que ambos os status mostram "ON"

**Resultado esperado**: Ambas as permissões ativadas

### Teste 2: Detecção de Elementos

1. Navegue para `/inspector`
2. Toque em "Iniciar Inspector Mode"
3. Abra um app simples (ex: Calculadora)
4. Volte ao Inspector Home
5. Verifique se elementos aparecem na lista

**Resultado esperado**: Lista de elementos detectados aparece

### Teste 3: Bounding Boxes

1. Com o Inspector ativo, ative "Desenhar boxes"
2. Abra um app terceiro
3. Verifique se retângulos roxos aparecem sobre elementos

**Resultado esperado**: Retângulos visíveis sobre elementos

### Teste 4: Seleção e Clique

1. Selecione um elemento na lista
2. Verifique se o elemento é destacado em verde no overlay
3. Toque em "Executar agora" > "Clique"
4. Verifique se a ação foi executada no app terceiro

**Resultado esperado**: Elemento clicado no app terceiro

### Teste 5: Scroll

1. Selecione um elemento scrollable (ex: lista)
2. Toque em "Executar agora" > "Scroll para Baixo"
3. Verifique se a lista rolou

**Resultado esperado**: Lista rola para baixo

### Teste 6: Apps Protegidos

1. Abra um app bancário ou protegido
2. Verifique se aparece "Conteúdo indisponível"
3. Use "Tap Manual por Coordenadas"
4. Execute um tap em uma coordenada conhecida

**Resultado esperado**: Tap executado na coordenada especificada

### Teste 7: STOP

1. Com o Inspector ativo, toque no botão STOP
2. Verifique se o Inspector para
3. Verifique se o overlay desaparece

**Resultado esperado**: Inspector desativado, overlay removido

## Como Desativar

### Desativar o Serviço de Acessibilidade

1. Vá em Configurações > Acessibilidade
2. Encontre "Inspector Mode" na lista
3. Desative o serviço

### Desativar Permissão de Overlay

1. Vá em Configurações > Apps > neo
2. Toque em "Permissões"
3. Desative "Desenhar sobre outros apps"

## Notas de Segurança

- O app **nunca** captura texto digitado
- O app **nunca** automatiza ações sem comando explícito do usuário
- Todas as ações requerem interação do usuário
- O botão STOP está sempre acessível
- Dados permanecem locais no dispositivo

## Suporte

Para problemas ou dúvidas, consulte o código-fonte ou abra uma issue no repositório.

