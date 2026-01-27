import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/neon_card.dart';
import '../models/element_record.dart';
import '../../inspector_accessibility/data/inspector_repository_impl.dart';

class SearchResultsCard extends StatelessWidget {
  final List<ElementRecord> results;
  final String query;
  final Function(ElementRecord)? onElementSelected;

  const SearchResultsCard({
    super.key,
    required this.results,
    required this.query,
    this.onElementSelected,
  });

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Elementos encontrados: ${results.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.text1,
                  ),
                ),
                const Spacer(),
                Text(
                  'Busca: "$query"',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.text2,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...results.take(10).map((element) => _ElementResultItem(
                element: element,
                onTap: onElementSelected != null
                    ? () => onElementSelected!(element)
                    : null,
              )),
          if (results.length > 10)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '... e mais ${results.length - 10} elementos',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.text2,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ElementResultItem extends StatelessWidget {
  final ElementRecord element;
  final VoidCallback? onTap;

  const _ElementResultItem({
    required this.element,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (element.text != null && element.text!.isNotEmpty)
                    Text(
                      element.text!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: AppColors.text1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (element.text != null && element.text!.isNotEmpty)
                    const SizedBox(height: 4),
                  Text(
                    element.className ?? "N/A",
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.text2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (element.clickable)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Clicável',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.success,
                  ),
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.touch_app, size: 20),
                tooltip: 'Clicar neste elemento',
                onPressed: () async {
                  // Converter ElementRecord para coordenadas e clicar
                  final repository = InspectorRepositoryImpl();
                  final centerX = ((element.positionLeft + element.positionRight) / 2).toInt();
                  final centerY = ((element.positionTop + element.positionBottom) / 2).toInt();
                  await repository.tap(centerX, centerY);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}



