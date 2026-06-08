import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/audit_provider.dart';
import '../providers/system_provider.dart';
import '../theme/app_colors.dart';

class ManagerMonthlyStatsWidget extends StatefulWidget {
  const ManagerMonthlyStatsWidget({super.key});

  @override
  State<ManagerMonthlyStatsWidget> createState() => _ManagerMonthlyStatsWidgetState();
}

class _ManagerMonthlyStatsWidgetState extends State<ManagerMonthlyStatsWidget> {
  String? _selectedAuditTypeId;

  final List<String> _trMonths = [
    '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];

  @override
  Widget build(BuildContext context) {
    final systemProvider = context.watch<SystemProvider>();
    final auditProvider = context.watch<AuditProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final surface = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final borderColor = primary.withOpacity(isDark ? 0.40 : 0.14);

    final activeAuditTypes = systemProvider.auditTypes
        .where((type) => type.isActive && !type.isDeleted)
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    if (_selectedAuditTypeId == null && activeAuditTypes.isNotEmpty) {
      _selectedAuditTypeId = activeAuditTypes.first.id;
    }
    if (_selectedAuditTypeId != null &&
        activeAuditTypes.isNotEmpty &&
        !activeAuditTypes.any((t) => t.id == _selectedAuditTypeId)) {
      _selectedAuditTypeId = activeAuditTypes.first.id;
    }

    final now = DateTime.now();
    final currentMonthName = _trMonths[now.month];

    // Filter audits
    final monthlyAudits = auditProvider.auditHistory.where((a) {
      return a.date.year == now.year &&
             a.date.month == now.month &&
             a.isCompleted &&
             a.auditTypeId == _selectedAuditTypeId;
    }).toList();

    final totalAudits = monthlyAudits.length;
    double avgScore = 0.0;
    int totalNCs = 0;

    if (totalAudits > 0) {
      final totalScoreSum = monthlyAudits.map((a) => a.score).reduce((a, b) => a + b);
      avgScore = totalScoreSum / totalAudits;
      totalNCs = monthlyAudits.expand((a) => a.answers).where((a) => a.isNonconformity).length;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(isDark ? 0.3 : 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$currentMonthName Ayı Genel Özet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Seçili denetim tipine ait aylık performans istatistikleri',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor.withOpacity(0.58),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (activeAuditTypes.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: primary.withOpacity(isDark ? 0.35 : 0.18),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedAuditTypeId,
                  isExpanded: true,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  icon: Icon(Icons.arrow_drop_down_rounded, color: isDark ? Colors.white70 : primary),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  items: activeAuditTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type.id,
                      child: Text(type.title),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedAuditTypeId = val;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatBox(
                  context: context,
                  title: 'Toplam Denetim',
                  value: totalAudits.toString(),
                  icon: Icons.assignment_turned_in_rounded,
                  color: isDark ? Colors.blueAccent : AppColors.primary,
                ),
                const SizedBox(width: 10),
                _buildStatBox(
                  context: context,
                  title: 'Ortalama',
                  value: '%${avgScore.toStringAsFixed(1)}',
                  icon: Icons.trending_up_rounded,
                  color: AppColors.accentGreen,
                ),
                const SizedBox(width: 10),
                _buildStatBox(
                  context: context,
                  title: 'Uygunsuzluk',
                  value: totalNCs.toString(),
                  icon: Icons.gpp_maybe_rounded,
                  color: AppColors.accentRed,
                ),
              ],
            ),
          ] else
            Text(
              'Aktif denetim tipi bulunamadı.',
              style: TextStyle(
                color: textColor.withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.25 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withOpacity(isDark ? 0.6 : 0.15),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor.withOpacity(0.7),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
