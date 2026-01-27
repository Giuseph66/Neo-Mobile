import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/action_plan.dart';
import '../../theme/app_colors.dart';
import 'element_preview.dart';
import '../services/element_matcher.dart';
import '../../inspector_accessibility/domain/models/ui_snapshot.dart';

class ActionPlanCard extends StatefulWidget {
  final ActionPlan plan;
  final UiSnapshot? snapshot;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final bool isExecuting;

  const ActionPlanCard({
    super.key,
    required this.plan,
    this.snapshot,
    this.onApprove,
    this.onReject,
    this.isExecuting = false,
  });

  @override
  State<ActionPlanCard> createState() => _ActionPlanCardState();
}

class _ActionPlanCardState extends State<ActionPlanCard> {
  bool _showJson = false;


  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.article_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Plano de Ações (${widget.plan.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text1,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _showJson ? Icons.code : Icons.code_off,
                    size: 18,
                    color: AppColors.text2,
                  ),
                  tooltip: 'Ver JSON',
                  onPressed: () {
                    setState(() {
                      _showJson = !_showJson;
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_showJson)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.outline0),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(widget.plan.toJson()),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppColors.text1,
                  ),
                ),
              ),
            )
          else
            ...widget.plan.actions.asMap().entries.map((entry) {
              final index = entry.key;
              final action = entry.value;
              return _ActionItem(
                action: action,
                index: index,
                snapshot: widget.snapshot,
              );
            }),
          if (widget.onApprove != null || widget.onReject != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.onReject != null)
                    TextButton(
                      onPressed: widget.isExecuting ? null : widget.onReject,
                      child: const Text('Rejeitar'),
                    ),
                  const SizedBox(width: 8),
                  if (widget.onApprove != null)
                    ElevatedButton(
                      onPressed: widget.isExecuting ? null : widget.onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: widget.isExecuting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Aprovar e Executar'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final PlannedAction action;
  final int index;
  final UiSnapshot? snapshot;

  const _ActionItem({
    required this.action,
    required this.index,
    this.snapshot,
  });

  IconData _getIcon() {
    switch (action.type) {
      case ActionType.click:
        return Icons.touch_app;
      case ActionType.scrollForward:
        return Icons.arrow_downward;
      case ActionType.scrollBackward:
        return Icons.arrow_upward;
      case ActionType.tap:
        return Icons.radio_button_checked;
      case ActionType.swipe:
        return Icons.swipe;
    }
  }

  Color _getIconColor() {
    switch (action.type) {
      case ActionType.click:
        return AppColors.primary;
      case ActionType.scrollForward:
      case ActionType.scrollBackward:
        return AppColors.primary2;
      case ActionType.tap:
      case ActionType.swipe:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _getIconColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIcon(),
                  size: 18,
                  color: _getIconColor(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.description,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.text1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Confiança: ${(action.confidence * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.text2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (action.target != null && snapshot != null) ...[
            const SizedBox(height: 12),
            _buildTargetPreview(),
          ],
        ],
      ),
    );
  }

  Widget _buildTargetPreview() {
    if (action.target == null || snapshot == null) {
      return const SizedBox.shrink();
    }

    // Tentar encontrar o elemento
    final match = ElementMatcher.findBestMatch(snapshot!, action.target!);
    if (match == null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: AppColors.danger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Elemento "${action.target}" não encontrado',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.danger,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ElementPreview(node: match.node);
  }
}

