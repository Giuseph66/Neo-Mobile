import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../chat_control/database/element_database.dart';
import '../../chat_control/models/element_record.dart';
import '../../chat_control/models/element_group.dart';
import '../../widgets/neon_card.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final ElementDatabase _database = ElementDatabase.instance;
  List<ElementGroup> _groups = [];
  Map<int, List<ElementRecord>> _groupElements = {};
  bool _loading = true;
  int? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });

    try {
      final groups = await _database.getAllGroups();
      final groupElements = <int, List<ElementRecord>>{};

      for (final group in groups) {
        final elements = await _database.getElementsByGroup(group.id);
        groupElements[group.id] = elements;
      }

      setState(() {
        _groups = groups;
        _groupElements = groupElements;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;

                if (isWide) {
                  return Row(
                    children: [
                      // Sidebar: 35%
                      Expanded(
                        flex: 35,
                        child: _buildGroupSidebar(),
                      ),
                      // Details: 65%
                      Expanded(
                        flex: 65,
                        child: _buildMainContent(),
                      ),
                    ],
                  );
                } else {
                  // Single column flow for mobile
                  return _selectedGroupId == null
                      ? _buildGroupSidebar()
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextButton.icon(
                                onPressed: () => setState(() => _selectedGroupId = null),
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Voltar para Grupos'),
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(child: _buildGroupDetails(_selectedGroupId!)),
                          ],
                        );
                }
              },
            ),
    );
  }

  Widget _buildGroupSidebar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface0,
        border: Border(
          right: BorderSide(color: AppColors.outline0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Grupos',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: AppColors.text1,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadData,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _groups.isEmpty
                ? const Center(
                    child: Text(
                      'Sem grupos',
                      style: TextStyle(color: AppColors.text2),
                    ),
                  )
                : ListView.builder(
                    itemCount: _groups.length,
                    itemBuilder: (context, index) {
                      final group = _groups[index];
                      final isSelected = _selectedGroupId == group.id;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: InkWell(
                          onTap: () => setState(() => _selectedGroupId = group.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.primary.withOpacity(0.5) : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary : AppColors.surface1,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${group.id}',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : AppColors.text1,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Grupo ${group.id}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? AppColors.primary : AppColors.text1,
                                        ),
                                      ),
                                      Text(
                                        '${_groupElements[group.id]?.length ?? 0} elementos',
                                        style: const TextStyle(fontSize: 12, color: AppColors.text2),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.chevron_right, color: AppColors.primary)
                                else
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                                    onPressed: () => _deleteGroup(group.id),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return _selectedGroupId == null
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.layers_outlined, size: 64, color: AppColors.text2),
                SizedBox(height: 16),
                Text(
                  'Selecione um grupo para visualizar os detalhes',
                  style: TextStyle(color: AppColors.text2),
                ),
              ],
            ),
          )
        : _buildGroupDetails(_selectedGroupId!);
  }

  Widget _buildGroupDetails(int groupId) {
    final group = _groups.firstWhere((g) => g.id == groupId);
    final elements = _groupElements[groupId] ?? [];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.surface1,
            border: Border(bottom: BorderSide(color: AppColors.outline0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Detalhes do Grupo ${group.id}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text1,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${elements.length} Elementos',
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildLargeInfoCard(group),
            ],
          ),
        ),
        Expanded(
          child: elements.isEmpty
              ? const Center(child: Text('Nenhum elemento neste grupo'))
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: elements.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ElementCard(element: elements[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLargeInfoCard(ElementGroup group) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface0,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline0),
      ),
      child: Column(
        children: [
          _buildInfoItem(Icons.calendar_today, 'Criado em', _formatDate(group.createdAt)),
          if (group.packageName != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            _buildInfoItem(Icons.android, 'Pacote', group.packageName!),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Text('$label:', style: const TextStyle(color: AppColors.text2, fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.text1, fontWeight: FontWeight.w600, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _deleteGroup(int groupId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deletar Grupo'),
        content: Text(
          'Tem certeza que deseja deletar o grupo $groupId e todos os seus elementos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
            ),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _database.deleteGroup(groupId);
        if (mounted) {
          setState(() {
            if (_selectedGroupId == groupId) {
              _selectedGroupId = null;
            }
          });
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao deletar: $e')),
          );
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _ElementCard extends StatelessWidget {
  const _ElementCard({required this.element});

  final ElementRecord element;

  @override
  Widget build(BuildContext context) {
    final size = Size(
      element.positionRight - element.positionLeft,
      element.positionBottom - element.positionTop,
    );

    return NeonCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Text or Class Name
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.code, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    element.text?.isNotEmpty == true ? element.text! : element.className ?? 'Elemento',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.text1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRow('Classe', element.className ?? 'N/A', Icons.class_outlined),
                const SizedBox(height: 12),
                _buildRow(
                  'Bounds',
                  '[${element.positionLeft.toInt()}, ${element.positionTop.toInt()}] - [${element.positionRight.toInt()}, ${element.positionBottom.toInt()}]',
                  Icons.crop_free,
                ),
                const SizedBox(height: 12),
                _buildRow(
                  'Size',
                  '${size.width.toInt()} × ${size.height.toInt()}',
                  Icons.aspect_ratio,
                ),
                const SizedBox(height: 12),
                _buildPathRow(element.path),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (element.clickable) _tag('CLICKABLE', AppColors.success),
                    if (element.scrollable) _tag('SCROLLABLE', AppColors.primary),
                    if (element.enabled) _tag('ENABLED', AppColors.text2),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.text2),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.text2, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.text1, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildPathRow(String path) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.account_tree_outlined, size: 16, color: AppColors.text2),
            SizedBox(width: 8),
            Text(
              'Acessibility Path',
              style: TextStyle(color: AppColors.text2, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            path,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
    );
  }
}


class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

