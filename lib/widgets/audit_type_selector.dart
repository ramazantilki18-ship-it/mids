import 'package:flutter/material.dart';

import '../models/audit_type_model.dart';

class AuditTypeSelector extends StatelessWidget {
  final List<AuditTypeModel> auditTypes;
  final String? selectedAuditTypeId;
  final ValueChanged<String> onChanged;
  final bool dense;
  final bool onDark;

  const AuditTypeSelector({
    super.key,
    required this.auditTypes,
    required this.selectedAuditTypeId,
    required this.onChanged,
    this.dense = false,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    if (auditTypes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: onDark ? Colors.white.withValues(alpha: 0.12) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: onDark ? Colors.white24 : Theme.of(context).dividerColor.withValues(alpha: 0.16)),
        ),
        child: Text(
          'Aktif denetim tipi bulunamad\u0131',
          style: TextStyle(
            color: onDark ? Colors.white70 : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: auditTypes.asMap().entries.map((entry) {
          final index = entry.key;
          final type = entry.value;
          final selected = type.id == selectedAuditTypeId;
          final color = _colorForType(type, index);
          return Padding(
            padding: EdgeInsets.only(right: index == auditTypes.length - 1 ? 0 : 10),
            child: _AuditTypePill(
              auditType: type,
              color: color,
              selected: selected,
              dense: dense,
              onDark: onDark,
              onTap: () => onChanged(type.id),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _colorForType(AuditTypeModel type, int index) {
    const palette = [
      Color(0xFF0F766E),
      Color(0xFF1D4ED8),
      Color(0xFF7C3AED),
      Color(0xFFBE123C),
      Color(0xFFB45309),
      Color(0xFF0369A1),
      Color(0xFF15803D),
    ];
    final hash = type.id.codeUnits.fold<int>(index, (value, unit) => value + unit);
    return palette[hash.abs() % palette.length];
  }
}

class _AuditTypePill extends StatelessWidget {
  final AuditTypeModel auditType;
  final Color color;
  final bool selected;
  final bool dense;
  final bool onDark;
  final VoidCallback onTap;

  const _AuditTypePill({
    required this.auditType,
    required this.color,
    required this.selected,
    required this.dense,
    required this.onDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final questionCount = auditType.categories.fold<int>(
      0,
      (total, category) => total + category.questions.where((q) => q.isActive && !q.isDeleted).length,
    );
    final background = selected
        ? LinearGradient(colors: [color, Color.alphaBlend(Colors.black.withValues(alpha: 0.18), color)])
        : null;
    final cardColor = onDark ? Colors.white.withValues(alpha: 0.12) : Theme.of(context).cardColor;
    final textColor = selected ? Colors.white : (onDark ? Colors.white : Theme.of(context).colorScheme.onSurface);
    final mutedColor = selected ? Colors.white.withValues(alpha: 0.72) : (onDark ? Colors.white70 : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: dense ? 164 : 208,
        padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 14, vertical: dense ? 10 : 12),
        decoration: BoxDecoration(
          color: selected ? null : cardColor,
          gradient: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? Colors.white.withValues(alpha: 0.18) : color.withValues(alpha: onDark ? 0.35 : 0.22)),
          boxShadow: [
            if (selected)
              BoxShadow(color: color.withValues(alpha: 0.32), blurRadius: 18, offset: const Offset(0, 8))
            else
              BoxShadow(color: Colors.black.withValues(alpha: onDark ? 0.10 : 0.05), blurRadius: 12, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: dense ? 34 : 38,
              height: dense ? 34 : 38,
              decoration: BoxDecoration(
                color: selected ? Colors.white.withValues(alpha: 0.18) : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconForType(auditType), color: selected ? Colors.white : color, size: dense ? 18 : 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    auditType.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: dense ? 12 : 13),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$questionCount soru',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: mutedColor, fontWeight: FontWeight.w700, fontSize: dense ? 10 : 11),
                  ),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(AuditTypeModel type) {
    if (type.allowedAnswerTypes.contains(AnswerType.boolean)) return Icons.fact_check_rounded;
    if (type.scoringStrategy == ScoringStrategy.none) return Icons.article_rounded;
    if (type.scoringStrategy == ScoringStrategy.mixedWeighted) return Icons.tune_rounded;
    if (type.scoringStrategy == ScoringStrategy.quizAccuracy) return Icons.quiz_rounded;
    return Icons.assignment_turned_in_rounded;
  }
}
