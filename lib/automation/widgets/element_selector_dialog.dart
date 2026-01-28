import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../chat_control/services/element_storage_service.dart';
import '../../chat_control/models/element_record.dart';

class ElementSelectorDialog extends StatefulWidget {
  final String? packageName;

  const ElementSelectorDialog({super.key, this.packageName});

  @override
  State<ElementSelectorDialog> createState() => _ElementSelectorDialogState();
}

class _ElementSelectorDialogState extends State<ElementSelectorDialog> {
  final ElementStorageService _storageService = ElementStorageService();
  List<ElementRecord> _elements = [];
  bool _isLoading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadElements();
  }

  Future<void> _loadElements() async {
    // Para simplificar, buscamos os elementos mais recentes ou via busca
    final elements = await _storageService.searchElements(_query);
    if (mounted) {
      setState(() {
        _elements = elements;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bg1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.ads_click, color: AppColors.primary),
                const SizedBox(width: 12),
                const Text(
                  'Selecionar Elemento',
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
              onChanged: (val) {
                setState(() => _query = val);
                _loadElements();
              },
              decoration: InputDecoration(
                hintText: 'Buscar por texto ou ID...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _elements.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              const Text('Nenhum elemento encontrado.'),
                              const Text(
                                'Use o modo Inspector no app alvo primeiro.',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _elements.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final el = _elements[index];
                            final title = el.text ?? el.viewId ?? el.className ?? 'Elemento';
                            return ListTile(
                              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                'ID: ${el.viewId ?? 'N/A'} | Path: ${el.path.split('|').last}',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                              trailing: el.clickable ? const Icon(Icons.touch_app, size: 16, color: Colors.blue) : null,
                              onTap: () => Navigator.pop(context, el),
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
