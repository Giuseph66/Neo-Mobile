import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../inspector_accessibility/presentation/accessibility_inspector_controller.dart';

class AppSelectorDialog extends StatefulWidget {
  const AppSelectorDialog({super.key});

  @override
  State<AppSelectorDialog> createState() => _AppSelectorDialogState();
}

class _AppSelectorDialogState extends State<AppSelectorDialog> {
  final AccessibilityInspectorController _controller = AccessibilityInspectorController();
  List<Map<String, String>> _allApps = [];
  List<Map<String, String>> _filteredApps = [];
  bool _isLoading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    final apps = await _controller.getInstalledApps();
    if (mounted) {
      setState(() {
        _allApps = apps;
        _filteredApps = apps;
        _isLoading = false;
      });
    }
  }

  void _filter(String q) {
    setState(() {
      _query = q;
      _filteredApps = _allApps.where((app) {
        final name = app['name']?.toLowerCase() ?? '';
        final pkg = app['package']?.toLowerCase() ?? '';
        final search = q.toLowerCase();
        return name.contains(search) || pkg.contains(search);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bg1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.apps, color: AppColors.primary),
                const SizedBox(width: 12),
                const Text(
                  'Selecionar App',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: 'Buscar por nome ou pacote...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredApps.isEmpty
                      ? const Center(child: Text('Nenhum app encontrado.'))
                      : ListView.separated(
                          itemCount: _filteredApps.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final app = _filteredApps[index];
                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.surface2,
                                child: Icon(Icons.android, color: Colors.green, size: 20),
                              ),
                              title: Text(app['name'] ?? 'N/A'),
                              subtitle: Text(
                                app['package'] ?? 'N/A',
                                style: TextStyle(fontSize: 11, color: AppColors.text2.withOpacity(0.6)),
                              ),
                              onTap: () => Navigator.pop(context, app),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
