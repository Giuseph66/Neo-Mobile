import 'package:flutter/material.dart';
import '../accessibility_inspector_controller.dart';
import '../../domain/models/ui_node.dart';

class InspectorHomeScreen extends StatefulWidget {
  final bool autoStart;
  
  const InspectorHomeScreen({super.key, this.autoStart = false});

  @override
  State<InspectorHomeScreen> createState() => _InspectorHomeScreenState();
}

class _InspectorHomeScreenState extends State<InspectorHomeScreen> with WidgetsBindingObserver {
  late final AccessibilityInspectorController _controller;
  bool _checkingPermissions = false;
  final TextEditingController _wsController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _nodeSearchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AccessibilityInspectorController();
    _controller.addListener(_onControllerChanged);
    _wsController.text = _controller.streamUrl;
    
    // Verificar permissões e iniciar automaticamente se já estiver habilitado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndStartIfEnabled();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _wsController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Quando o app volta ao foreground, verificar se o usuário habilitou o serviço
    if (state == AppLifecycleState.resumed && !_controller.enabled && widget.autoStart) {
      _checkAndStartIfEnabled();
    }
  }

  Future<void> _checkAndStartIfEnabled() async {
    if (_checkingPermissions) return;
    
    setState(() {
      _checkingPermissions = true;
    });

    try {
      final isEnabled = await _controller.checkAccessibilityEnabled();
      
      if (isEnabled) {
        // Serviço já está habilitado - iniciar automaticamente
        if (widget.autoStart) {
          await _startInspector();
        }
      } else {
        // Serviço não está habilitado - mostrar diálogo
        if (mounted && widget.autoStart) {
          _showPermissionDialog();
        }
      }
    } catch (e) {
      // Ignorar erros na verificação
    } finally {
      if (mounted) {
        setState(() {
          _checkingPermissions = false;
        });
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permissão Necessária'),
        content: const Text(
          'O Accessibility Service precisa ser habilitado para usar o Inspector Mode.\n\n'
          'Por favor, habilite nas configurações do Android.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/permissions');
            },
            child: const Text('Abrir Configurações'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _onControllerChanged() {
    setState(() {});
  }

  Future<void> _startInspector() async {
    try {
      await _controller.start();
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString();
        if (errorMessage.contains('não está habilitado') || errorMessage.contains('NOT_ENABLED')) {
          // Serviço não habilitado - mostrar diálogo para abrir configurações
          _showPermissionDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro: $errorMessage'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _stopInspector() async {
    await _controller.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspector Mode'),
        actions: [
          if (_controller.enabled)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopInspector,
              tooltip: 'Parar Inspector',
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopControls(),
              const Divider(height: 1),
              Expanded(
                child: _buildMainContent(),
              ),
            ],
          ),
          // STOP sempre visível no canto inferior direito
          if (_controller.enabled)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'stop_inspector_fab',
                onPressed: _stopInspector,
                backgroundColor: Colors.red,
                child: const Icon(Icons.stop, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_controller.enabled)
            ElevatedButton.icon(
              onPressed: _startInspector,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar Inspector Mode'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SwitchListTile(
                  title: const Text('Desenhar boxes'),
                  value: _controller.overlayVisible,
                  onChanged: (value) {
                    _controller.setOverlayVisible(value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Desenhar textos'),
                  value: _controller.textVisible,
                  onChanged: (value) {
                    _controller.setTextVisible(value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _controller.setAimMode(!_controller.aimMode);
                  },
                  icon: Icon(_controller.aimMode ? Icons.cancel : Icons.center_focus_strong),
                  label: Text(_controller.aimMode ? 'Desativar Mira' : 'Ativar Mira'),
                ),
                const SizedBox(width: 8),
                _buildGlobalNavButtons(),
              ],
            ),
          const SizedBox(height: 16),
          _buildStreamingControls(),
        ],
      ),
    );
  }

  Widget _buildStreamingControls() {
    final connected = _controller.streamingConnected;
    final connecting = _controller.streamingConnecting;
    final statusLabel = connected
        ? 'Conectado'
        : connecting
            ? 'Conectando...'
            : 'Desconectado';
    final statusColor = connected
        ? Colors.green
        : connecting
            ? Colors.orange
            : Colors.grey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Streaming WebSocket',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(color: statusColor, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _wsController,
          decoration: const InputDecoration(
            labelText: 'URL do WebSocket',
            hintText: 'ws://10.0.2.2:7071',
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) {
            _controller.setStreamUrl(value.trim());
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Switch(
              value: _controller.streamingEnabled,
              onChanged: (value) {
                _controller.setStreamingEnabled(value);
              },
            ),
            const Expanded(
              child: Text(
                'Enviar boxes para o servidor',
                style: TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {
                _controller.setStreamUrl(_wsController.text.trim());
              },
              child: const Text('Aplicar URL'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Use o IP do seu PC (ou 10.0.2.2 no emulador).',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    if (!_controller.enabled) {
      return const Center(
        child: Text('Inicie o Inspector Mode para começar'),
      );
    }

    final snapshot = _controller.lastSnapshot;
    if (snapshot == null || snapshot.nodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Conteúdo indisponível',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nenhum elemento detectado. Isso pode acontecer em apps protegidos.',
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _showTapManualDialog();
              },
              icon: const Icon(Icons.touch_app),
              label: const Text('Tap Manual por Coordenadas'),
            ),
          ],
        ),
      );
    }

    final filteredNodes = snapshot.nodes.where((n) {
      if (_nodeSearchQuery.isEmpty) return true;
      final label = (n.text ?? n.viewIdResourceName ?? n.className).toLowerCase();
      return label.contains(_nodeSearchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _nodeSearchQuery = val),
            decoration: InputDecoration(
              hintText: 'Filtrar por texto ou ID...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _nodeSearchQuery.isNotEmpty 
                ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() {
                  _searchController.clear();
                  _nodeSearchQuery = '';
                }))
                : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ),
        Expanded(
          child: _buildNodesList(filteredNodes),
        ),
        if (_controller.selectedNode != null)
          _buildActionPanel(),
      ],
    );
  }

  Widget _buildNodesList(List<UiNode> nodes) {
    return ListView.builder(
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final node = nodes[index];
        final isSelected = _controller.selectedNode?.id == node.id;
        return InkWell(
          onTap: () {
            _controller.selectNode(node);
          },
          child: Container(
            color: isSelected ? Colors.green.withOpacity(0.15) : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        node.className,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                          color: isSelected ? Colors.green : null,
                        ),
                      ),
                    ),
                    if (node.clickable)
                      const Icon(Icons.touch_app, size: 16, color: Colors.blue),
                    if (node.scrollable)
                      const Icon(Icons.swipe, size: 16, color: Colors.orange),
                    if (node.isTextField)
                      const Icon(Icons.text_fields, size: 16, color: Colors.purple),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Pos: (${node.bounds.left}, ${node.bounds.top})',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                if (node.packageName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    node.packageName,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionPanel() {
    final selectedNode = _controller.selectedNode;
    if (selectedNode == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E26),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, -2))
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.green.withOpacity(0.1),
                child: const Icon(Icons.ads_click, color: Colors.green, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedNode.text ?? selectedNode.className.split('.').last,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      selectedNode.viewIdResourceName ?? 'Sem ID',
                      style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _controller.selectNode(null),
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (selectedNode.clickable)
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.play_arrow,
                    label: 'CLICAR',
                    color: Colors.green,
                    onPressed: () => _executeAction('click'),
                  ),
                ),
              if (selectedNode.scrollable) ...[
                if (selectedNode.clickable) const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.unfold_more,
                    label: 'SCROLL',
                    color: Colors.blue,
                    onPressed: () => _showScrollOptions(context),
                  ),
                ),
              ],
              if (!selectedNode.clickable && !selectedNode.scrollable)
                const Expanded(
                  child: Text(
                    'Elemento informativo - sem ações diretas',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showScrollOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E26),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Direção do Scroll', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.arrow_upward,
                    label: 'Para Cima',
                    color: Colors.blue,
                    onPressed: () {
                      Navigator.pop(context);
                      _executeAction('scrollBackward');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.arrow_downward,
                    label: 'Para Baixo',
                    color: Colors.blue,
                    onPressed: () {
                      Navigator.pop(context);
                      _executeAction('scrollForward');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.2),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: color, width: 2),
          ),
        ),
      ),
    );
  }

  Future<void> _executeAction(String action) async {
    if (_controller.selectedNode == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhum elemento selecionado'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    bool success = false;
    String? errorMessage;
    
    try {
      switch (action) {
        case 'click':
          success = await _controller.clickSelected();
          if (!success) {
            errorMessage = 'Elemento não encontrado ou não é clicável. A tela pode ter mudado.';
          }
          break;
        case 'scrollForward':
          success = await _controller.scrollForward();
          if (!success) {
            errorMessage = 'Elemento não encontrado ou não é scrollable. A tela pode ter mudado.';
          }
          break;
        case 'scrollBackward':
          success = await _controller.scrollBackward();
          if (!success) {
            errorMessage = 'Elemento não encontrado ou não é scrollable. A tela pode ter mudado.';
          }
          break;
      }
    } catch (e) {
      errorMessage = 'Erro: ${e.toString()}';
      success = false;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Ação executada com sucesso' : (errorMessage ?? 'Falha ao executar ação')),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: Duration(seconds: success ? 2 : 4),
        ),
      );
    }
  }

  void _showTapManualDialog() {
    showDialog(
      context: context,
      builder: (context) {
        int x = 0, y = 0;
        return AlertDialog(
          title: const Text('Tap Manual'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'X'),
                keyboardType: TextInputType.number,
                onChanged: (value) => x = int.tryParse(value) ?? 0,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Y'),
                keyboardType: TextInputType.number,
                onChanged: (value) => y = int.tryParse(value) ?? 0,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _controller.tap(x, y);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tap executado')),
                );
              },
              child: const Text('Executar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlobalNavButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildNavIcon(Icons.arrow_back, 'Voltar', _controller.navigateBack),
        const SizedBox(width: 4),
        _buildNavIcon(Icons.circle_outlined, 'Home', _controller.navigateHome),
        const SizedBox(width: 4),
        _buildNavIcon(Icons.menu, 'Recentes', _controller.navigateRecents),
      ],
    );
  }

  Widget _buildNavIcon(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 20, color: Colors.white70),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.1),
        padding: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
