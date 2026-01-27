import '../../inspector_accessibility/domain/models/ui_node.dart';
import '../../inspector_accessibility/domain/models/ui_snapshot.dart';

class MatchedElement {
  final UiNode node;
  final double similarity; // 0.0 a 1.0

  MatchedElement({
    required this.node,
    required this.similarity,
  });
}

class ElementMatcher {
  static const double defaultThreshold = 0.6;

  /// Encontra elementos que correspondem ao texto de busca usando match fuzzy
  /// Retorna lista ordenada por relevância (similaridade)
  static List<MatchedElement> findByText(
    UiSnapshot snapshot,
    String query, {
    double threshold = defaultThreshold,
  }) {
    if (query.trim().isEmpty) {
      return [];
    }

    final queryLower = query.toLowerCase().trim();
    final matches = <MatchedElement>[];

    for (final node in snapshot.nodes) {
      final nodeText = node.text?.toLowerCase().trim();
      if (nodeText == null || nodeText.isEmpty) {
        continue;
      }

      final similarity = _calculateSimilarity(queryLower, nodeText);
      if (similarity >= threshold) {
        matches.add(MatchedElement(
          node: node,
          similarity: similarity,
        ));
      }
    }

    // Ordenar por similaridade (maior primeiro) e priorizar clickable/scrollable
    matches.sort((a, b) {
      // Primeiro por similaridade
      final similarityDiff = b.similarity.compareTo(a.similarity);
      if (similarityDiff != 0) return similarityDiff;

      // Depois priorizar clickable > scrollable > enabled
      final aPriority = _getPriority(a.node);
      final bPriority = _getPriority(b.node);
      return bPriority.compareTo(aPriority);
    });

    return matches;
  }

  /// Calcula similaridade entre duas strings usando Jaro-Winkler
  /// Retorna valor entre 0.0 e 1.0
  static double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    // Match exato (case-insensitive já foi feito)
    if (s1 == s2) return 1.0;

    // Match parcial (uma string contém a outra)
    if (s1.contains(s2) || s2.contains(s1)) {
      final longer = s1.length > s2.length ? s1 : s2;
      final shorter = s1.length > s2.length ? s2 : s1;
      return shorter.length / longer.length;
    }

    // Usar Jaro-Winkler distance
    return _jaroWinkler(s1, s2);
  }

  /// Implementação simplificada de Jaro-Winkler
  static double _jaroWinkler(String s1, String s2) {
    if (s1 == s2) return 1.0;

    final jaro = _jaro(s1, s2);
    final prefixLength = _commonPrefixLength(s1, s2, 4);
    final p = 0.1; // Scaling factor

    return jaro + (prefixLength * p * (1 - jaro));
  }

  /// Jaro distance
  static double _jaro(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final matchWindow = (s1.length > s2.length ? s1.length : s2.length) ~/ 2;
    final s1Matches = List<bool>.filled(s1.length, false);
    final s2Matches = List<bool>.filled(s2.length, false);

    int matches = 0;
    int transpositions = 0;

    // Encontrar matches
    for (int i = 0; i < s1.length; i++) {
      final start = (i >= matchWindow) ? i - matchWindow : 0;
      final end = (i + matchWindow <= s2.length)
          ? i + matchWindow
          : s2.length;

      for (int j = start; j < end; j++) {
        if (s2Matches[j] || s1[i] != s2[j]) continue;
        s1Matches[i] = true;
        s2Matches[j] = true;
        matches++;
        break;
      }
    }

    if (matches == 0) return 0.0;

    // Encontrar transposições
    int k = 0;
    for (int i = 0; i < s1.length; i++) {
      if (!s1Matches[i]) continue;
      while (!s2Matches[k]) k++;
      if (s1[i] != s2[k]) transpositions++;
      k++;
    }

    final jaro = (matches / s1.length +
            matches / s2.length +
            (matches - transpositions / 2) / matches) /
        3.0;

    return jaro;
  }

  /// Comprimento do prefixo comum (máximo 4)
  static int _commonPrefixLength(String s1, String s2, int maxLength) {
    int prefix = 0;
    for (int i = 0; i < s1.length && i < s2.length && i < maxLength; i++) {
      if (s1[i] == s2[i]) {
        prefix++;
      } else {
        break;
      }
    }
    return prefix;
  }

  /// Calcula prioridade do elemento para ordenação
  /// Retorna valor maior para elementos mais relevantes
  static int _getPriority(UiNode node) {
    int priority = 0;
    if (node.clickable) priority += 10;
    if (node.scrollable) priority += 5;
    if (node.enabled) priority += 2;
    return priority;
  }

  /// Encontra o melhor match para um texto
  /// Retorna null se nenhum match acima do threshold for encontrado
  static MatchedElement? findBestMatch(
    UiSnapshot snapshot,
    String query, {
    double threshold = defaultThreshold,
  }) {
    final matches = findByText(snapshot, query, threshold: threshold);
    return matches.isNotEmpty ? matches.first : null;
  }
}

