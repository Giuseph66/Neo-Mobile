import '../../inspector_accessibility/domain/models/ui_node.dart';
import '../../inspector_accessibility/domain/models/ui_snapshot.dart';
import '../database/element_database.dart';
import '../models/element_record.dart';
import '../models/element_group.dart';

class ElementStorageService {
  final ElementDatabase _database = ElementDatabase.instance;
  ElementGroup? _currentGroup;
  DateTime? _lastGroupUpdate;
  static const Duration groupTimeout = Duration(seconds: 5);

  /// Salva elementos de um snapshot, agrupando por demanda/tela
  Future<void> saveSnapshot(UiSnapshot snapshot) async {
    if (snapshot.nodes.isEmpty) return;

    // Determinar se precisa criar novo grupo ou usar o atual
    final now = DateTime.now();
    final needsNewGroup = _currentGroup == null ||
        _lastGroupUpdate == null ||
        now.difference(_lastGroupUpdate!) > groupTimeout;

    if (needsNewGroup) {
      // Criar novo grupo para esta demanda/tela
      final packageName = snapshot.nodes.isNotEmpty
          ? snapshot.nodes.first.packageName
          : null;

      _currentGroup = await _database.getOrCreateCurrentGroup(
        packageName: packageName,
        screenName: null, // Pode ser melhorado para detectar nome da tela
        groupTimeout: groupTimeout,
      );
      _lastGroupUpdate = now;
    }

    // Converter UiNodes para ElementRecords
    final elements = snapshot.nodes.map((node) {
      // Criar path único baseado no seletor
      final path = _buildPath(node);

      return ElementRecord(
        groupId: _currentGroup!.id,
        text: node.text,
        path: path,
        positionLeft: node.bounds.left,
        positionTop: node.bounds.top,
        positionRight: node.bounds.right,
        positionBottom: node.bounds.bottom,
        className: node.className,
        viewId: node.viewIdResourceName,
        clickable: node.clickable,
        scrollable: node.scrollable,
        enabled: node.enabled,
        createdAt: DateTime.now(),
      );
    }).toList();

    // Salvar elementos (duplicatas serão ignoradas automaticamente)
    await _database.saveElements(_currentGroup!.id, elements);
  }

  /// Constrói um path único para o elemento baseado no seletor
  /// O path é usado para identificar elementos únicos e evitar duplicatas
  String _buildPath(UiNode node) {
    final parts = <String>[];

    // Priorizar viewId se disponível (mais estável)
    if (node.viewIdResourceName != null && node.viewIdResourceName!.isNotEmpty) {
      parts.add('id:${node.viewIdResourceName}');
    }

    // Adicionar className
    parts.add('class:${node.className}');

    // Adicionar posição para diferenciar elementos similares na mesma tela
    // Usar coordenadas arredondadas para agrupar elementos muito próximos
    final bounds = node.bounds;
    final roundedLeft = (bounds.left / 10).round() * 10;
    final roundedTop = (bounds.top / 10).round() * 10;
    parts.add('pos:$roundedLeft,$roundedTop');

    // Se tiver texto, incluir no path para diferenciar elementos com mesmo ID/classe/posição
    if (node.text != null && node.text!.isNotEmpty) {
      // Usar hash do texto para manter path curto
      final textHash = node.text!.hashCode;
      parts.add('text:$textHash');
    }

    return parts.join('|');
  }

  /// Buscar elementos de um grupo
  Future<List<ElementRecord>> getElementsByGroup(int groupId) async {
    return await _database.getElementsByGroup(groupId);
  }

  /// Buscar todos os grupos
  Future<List<ElementGroup>> getAllGroups() async {
    return await _database.getAllGroups();
  }

  /// Buscar elementos por texto
  Future<List<ElementRecord>> searchElements(String query) async {
    return await _database.searchElements(query);
  }

  /// Resetar grupo atual (forçar novo grupo na próxima vez)
  void resetCurrentGroup() {
    _currentGroup = null;
    _lastGroupUpdate = null;
  }
}

