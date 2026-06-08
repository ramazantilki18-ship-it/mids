import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/audit_type_model.dart';
import '../providers/system_provider.dart';
import '../theme/app_colors.dart';

class QuestionManagementScreen extends StatelessWidget {
  const QuestionManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final system = context.watch<SystemProvider>();
    final auditTypes = system.auditTypes.where((type) => type.isActive && !type.isDeleted).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Denetim Tipleri ve Sorular'),
        elevation: 0,
      ),
      body: auditTypes.isEmpty
          ? const Center(child: Text('Tanımlı denetim tipi bulunamadı.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: auditTypes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) => _AuditTypeCard(auditType: auditTypes[index]),
            ),
    );
  }
}

class _AuditTypeCard extends StatelessWidget {
  final AuditTypeModel auditType;

  const _AuditTypeCard({required this.auditType});

  @override
  Widget build(BuildContext context) {
    final categories = auditType.categories.where((category) => category.isActive && !category.isDeleted).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final questionCount = categories.fold<int>(
      0,
      (sum, category) => sum + category.questions.where((q) => q.isActive && !q.isDeleted).length,
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: auditType.id == AuditTypeModel.stationInspectionId,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.fact_check_rounded, color: Theme.of(context).primaryColor),
          ),
          title: Text(auditType.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          subtitle: Text(
            '${categories.length} kategori | $questionCount soru',
            style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7)),
          ),
          children: [
            const Divider(height: 1),
            if (categories.isEmpty)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'Bu denetim tipinde kategori bulunmuyor.',
                  style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                ),
              ),
            ...categories.map((category) => _CategoryTile(category: category)),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final AuditCategoryModel category;

  const _CategoryTile({required this.category});

  @override
  Widget build(BuildContext context) {
    final questions = category.questions.where((q) => q.isActive && !q.isDeleted).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 20),
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      leading: Icon(Icons.segment_rounded, size: 18, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFB923C) : AppColors.accentOrange),
      title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text('${questions.length} soru', style: const TextStyle(fontSize: 11)),
      children: questions.asMap().entries.map((entry) {
        final question = entry.value;
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 13,
            backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.08),
            child: Text('${entry.key + 1}', style: TextStyle(fontSize: 11, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
          ),
          title: Text(question.text, style: const TextStyle(fontSize: 13)),
          trailing: Text(
            question.type == 'yes-no' ? 'E/H' : '1-5',
            style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7)),
          ),
        );
      }).toList(),
    );
  }
}
