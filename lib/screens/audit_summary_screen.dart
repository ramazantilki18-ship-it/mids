import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/audit_provider.dart';
import '../providers/nonconformity_provider.dart';
import '../providers/system_provider.dart';
import '../models/audit_model.dart';
import '../models/user_model.dart';
import '../models/question_model.dart';
import '../models/nonconformity_model.dart';
import '../models/audit_type_model.dart';
import '../theme/app_colors.dart';
import 'package:intl/intl.dart';
import '../services/pdf_service.dart';
import '../services/audit_question_resolver.dart';

class AuditSummaryScreen extends StatelessWidget {
  final AuditModel? audit;

  const AuditSummaryScreen({super.key, this.audit});

  void _showShareOptions(BuildContext context) {
    if (audit == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('PAYLAŞIM SEÇENEKLERİ',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    fontSize: 14)),
            const SizedBox(height: 24),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Color(0xFFD32F2F),
                  child: Icon(Icons.picture_as_pdf, color: Colors.white)),
              title: const Text('PDF Olarak Dışa Aktar',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Profesyonel rapor dosyası oluştur'),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context); // Close bottom sheet
                
                try {
                  final resolvedName = context.read<SystemProvider>().resolveDisplayName(
                    auditorId: audit!.auditorId,
                    auditorName: audit!.auditorName,
                  );
                  await PdfService.exportAndShareAudit(audit!, resolvedAuditorName: resolvedName);
                  messenger.showSnackBar(const SnackBar(
                      content: Text('PDF başarıyla oluşturuldu ve paylaşıldı.')));
                } catch (e) {
                  messenger.showSnackBar(
                      SnackBar(content: Text('PDF oluşturulamadı: $e')));
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    if (audit == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Denetimi Sil'),
        content: Text(
            '${audit!.id} numaralı denetim kaydını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentRed,
                foregroundColor: Colors.white),
            onPressed: () {
              context.read<AuditProvider>().deleteAudit(audit!.id);
              Navigator.pop(context); // Dialog kapat
              context.pop(); // Özet ekranını kapat
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Denetim başarıyla silindi.')),
              );
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (audit == null) {
      return const Scaffold(
          body: Center(child: Text('Denetim verisi bulunamadı.')));
    }

    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!user.canAccessAudit(
      line: audit!.line,
      auditorId: audit!.auditorId,
      auditorName: audit!.auditorName,
    )) {
      return const Scaffold(
        body: Center(child: Text('Bu denetimi goruntuleme yetkiniz yok.')),
      );
    }

    final ncProvider = context.watch<NonconformityProvider>();

    // KATEGORİ BAZLI SKORLARI HESAPLA (Güncel uygunsuzluk durumuna göre)
    Map<String, List<double>> categoryScores = {};
    for (var answer in audit!.answers) {
      final question =
          AuditQuestionResolver.resolveAnswer(audit!, answer).question;

      // Eğer bu soruya ait bir uygunsuzluk varsa ve KAPATILMIŞSA, puanı 5 (tam) say
      double effectiveScore = answer.normalizedScore;
      final ncId = 'NC-${audit!.id}-${answer.questionId}';
      final nc = ncProvider.all.where((n) => n.id == ncId).isNotEmpty
          ? ncProvider.all.firstWhere((n) => n.id == ncId)
          : null;

      if (nc != null && nc.status == NonconformityStatus.completed) {
        effectiveScore = 100.0; // Kapalı uygunsuzluklar başarıyı artırır
      }

      categoryScores
          .putIfAbsent(question.categoryName, () => [])
          .add(effectiveScore);
    }

    final ncAnswers = audit!.answers.where((a) => a.isNonconformity).toList();
    final nonconformities =
        ncProvider.all.where((nc) => nc.auditId == audit!.id).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('DENETİM RAPORU',
            style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
        elevation: 0,
        centerTitle: true,
        actions: [
          if (context.read<AuthProvider>().user?.role == UserRole.superAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.accentRed),
              onPressed: () => _showDeleteConfirmation(context),
            ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () => _showShareOptions(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildOverallScoreCard(context),
            const SizedBox(height: 16),
            _buildAuditDurationCard(context),
            const SizedBox(height: 24),

            // KATEGORİ BAZLI PERFORMANS
            _buildSectionHeader(context, 'BAŞLIK BAZLI ANALİZ'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 20,
                      offset: const Offset(0, 10))
                ],
              ),
              child: Column(
                children: categoryScores.entries.map((entry) {
                  final category = entry.key;
                  final scores = entry.value;
                  final avg =
                      scores.fold(0.0, (sum, s) => sum + s) / scores.length;
                  return _buildCategoryScoreRow(context, category, avg);
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // --- UYGUNSUZLUKLAR BÖLÜMÜ ---
            if (ncAnswers.isNotEmpty) ...[
              _buildNonconformitySection(context, ncAnswers, nonconformities),
              const SizedBox(height: 24),
            ],

            // DENETİM DETAYLARI
            _buildSectionHeader(context, 'DENETİM DETAYLARI'),
            const SizedBox(height: 12),
            ...AuditQuestionResolver.groupByCategory(audit!).expand((section) {
              final category = section.categoryName;
              final answers = section.items;
              return [
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Row(
                    children: [
                      Icon(_getCategoryIcon(category),
                          size: 16, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                ...answers.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final item = entry.value;
                  final ans = item.answer;
                  final question = item.question;
                  final ncId = 'NC-${audit!.id}-${ans.questionId}';
                  final nc =
                      ncProvider.all.where((n) => n.id == ncId).isNotEmpty
                          ? ncProvider.all.firstWhere((n) => n.id == ncId)
                          : null;
                  return _buildAnswerTile(context, ans, question, nc, index: index);
                }),
              ];
            }),

            const SizedBox(height: 40),
            _buildActionButtons(context),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      children: [
        Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF60A5FA)
                    : AppColors.primary,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                letterSpacing: 1.5)),
      ],
    );
  }

  Widget _buildOverallScoreCard(BuildContext context) {
    final scoreColor = audit!.score >= 85
        ? const Color(0xFF16A34A)
        : (audit!.score >= 70
            ? const Color(0xFFEA580C)
            : const Color(0xFFE11D48));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF002B5B), Color(0xFF001F3F)],
        ),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 25,
              offset: const Offset(0, 12))
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: CircleAvatar(
                radius: 80, backgroundColor: Colors.white.withValues(alpha: 0.03)),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          children: [
                            _buildLineLogo(audit!.line),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(audit!.station.toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5)),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          DateFormat('dd MMMM yyyy | HH:mm', 'tr_TR').format(audit!.date),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                       const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          audit!.auditType.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: CircularProgressIndicator(
                        value: audit!.score / 100,
                        strokeWidth: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        color: scoreColor,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('%${audit!.score % 1 == 0 ? audit!.score.toInt().toString() : audit!.score.toStringAsFixed(1)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900)),
                        Text('SKOR',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditDurationCard(BuildContext context) {
    if (audit == null) return const SizedBox.shrink();

    final startedStr = audit!.startedAt != null
        ? DateFormat('HH:mm').format(audit!.startedAt!)
        : '-';
    final completedStr = audit!.completedAt != null
        ? DateFormat('HH:mm').format(audit!.completedAt!)
        : '-';

    String durationStr = '-';
    if (audit!.startedAt != null && audit!.completedAt != null) {
      final diff = audit!.completedAt!.difference(audit!.startedAt!);
      durationStr = '${diff.inMinutes} Dk';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildDurationItem(
            context,
            icon: Icons.play_circle_outline_rounded,
            label: 'BAŞLANGIÇ',
            value: startedStr,
            iconColor: isDark ? const Color(0xFF60A5FA) : AppColors.primary,
          ),
          Container(
            width: 1,
            height: 32,
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
          _buildDurationItem(
            context,
            icon: Icons.stop_circle_outlined,
            label: 'BİTİŞ',
            value: completedStr,
            iconColor: const Color(0xFFEF4444),
          ),
          Container(
            width: 1,
            height: 32,
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
          _buildDurationItem(
            context,
            icon: Icons.timer_outlined,
            label: 'TOPLAM SÜRE',
            value: durationStr,
            iconColor: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryScoreRow(
      BuildContext context, String category, double score) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = score >= 80
        ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))
        : (score >= 60
            ? (isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C))
            : (isDark ? const Color(0xFFF87171) : const Color(0xFFE11D48)));
    final percent = score / 100;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface)),
              Text('%${score % 1 == 0 ? score.toInt().toString() : score.toStringAsFixed(1)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, color: color, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              color: color,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNonconformitySection(BuildContext context,
      List<AuditAnswer> ncAnswers, List<NonconformityModel> nonconformities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'TESPİT EDİLEN UYGUNSUZLUKLAR'),
        const SizedBox(height: 12),
        ...nonconformities.map((nc) {
          final statusColor = _getStatusColor(nc.status);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                onTap: () => context.push('/nonconformity-detail/${nc.id}'),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle),
                  child: Icon(Icons.assignment_late_rounded, color: statusColor),
                ),
                title: Text(nc.questionText,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Theme.of(context).textTheme.titleSmall?.color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    nc.auditorComment.trim().isEmpty 
                        ? 'Açıklama girilmemiş'
                        : nc.auditorComment.trim(),
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.6)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                trailing:
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAnswerTile(BuildContext context, AuditAnswer ans,
      QuestionModel question, NonconformityModel? nc, {int? index}) {
    final double normalized = ans.normalizedScore;
    Color color = ans.isOutOfScope
        ? Colors.blueGrey
        : (normalized >= 80
            ? const Color(0xFF16A34A)
            : (normalized >= 60 ? const Color(0xFFEA580C) : const Color(0xFFE11D48)));
    String scoreText = ans.isOutOfScope
        ? 'K.D.'
        : ((ans.answerType == AnswerType.boolean)
            ? (ans.booleanValue == true ? '100' : '0')
            : ans.score.toString());

    // Eğer uygunsuzluk kapandıysa yeşil göster ve durumu belirt
    if (nc != null && nc.status == NonconformityStatus.completed) {
      color = const Color(0xFF16A34A);
      scoreText = 'KAPALI';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(
                      index != null ? '$index. ${question.questionText}' : question.questionText,
                      style: TextStyle(
                          fontSize: 13,
                          color:
                              Theme.of(context).textTheme.bodyMedium?.color))),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(scoreText,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 10)),
              ),
            ],
          ),
          (() {
            final ncBlocks = <Map<String, dynamic>>[];
            final mainComment = ans.comment?.trim() ?? '';
            final mainPhotos = ans.allPhotoUrls;
            if (mainComment.isNotEmpty || mainPhotos.isNotEmpty || ans.additionalComments.isNotEmpty) {
              ncBlocks.add({
                'title': 'Uygunsuzluk Detayı',
                'comment': [
                  if (mainComment.isNotEmpty) mainComment,
                  if (ans.additionalComments.isNotEmpty) ...ans.additionalComments.map((c) => '• $c')
                ].join('\n\n'),
                'photos': mainPhotos,
              });
            }

            for (var i = 0; i < ans.additionalNonconformities.length; i++) {
              final addNc = ans.additionalNonconformities[i];
              final title = ans.additionalNonconformities.length > 1
                  ? 'İlave Uygunsuzluk ${i + 1}'
                  : 'İlave Uygunsuzluk';
              ncBlocks.add({
                'title': title,
                'comment': addNc.comment.trim(),
                'photos': [if (addNc.photoUrl.isNotEmpty) addNc.photoUrl],
              });
            }

            if (ncBlocks.isEmpty) return const SizedBox.shrink();

            return Column(
              children: ncBlocks.map((block) {
                final title = block['title'] as String;
                final comment = block['comment'] as String;
                final photos = block['photos'] as List<String>;

                return Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade900
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE11D48),
                        ),
                      ),
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          comment,
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                              height: 1.5),
                        ),
                      ],
                      if (photos.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 60,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: photos.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, idx) {
                              final path = photos[idx];
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image(
                                  image: _answerPhotoProvider(path),
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image_outlined,
                                        color: Colors.grey, size: 20),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            );
          })(),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width - 40,
      child: OutlinedButton(
        onPressed: () => context.go('/'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF60A5FA)
                  : AppColors.primary),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: Text('ANASAYFAYA DÖN',
            style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF60A5FA)
                    : AppColors.primary,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  ImageProvider _answerPhotoProvider(String path) {
    if (path.startsWith('data:image')) {
      final base64String = path.split(',').last;
      return MemoryImage(base64Decode(base64String));
    }
    if (path.startsWith('http') ||
        path.startsWith('blob:')) {
      return NetworkImage(path);
    }
    if (path.startsWith('assets/')) {
      return AssetImage(path);
    }
    final cleanPath = path.startsWith('file://') ? path.replaceFirst('file://', '') : path;
    return FileImage(File(cleanPath));
  }

  IconData _getCategoryIcon(String category) {
    if (category.contains('SINIFLANDIRMA')) return Icons.auto_delete_rounded;
    if (category.contains('SIRALAMA')) return Icons.dashboard_customize_rounded;
    if (category.contains('SİLME')) return Icons.cleaning_services_rounded;
    if (category.contains('STANDARTLAŞTIRMA')) return Icons.rule_rounded;
    if (category.contains('SAHİPLENME')) return Icons.model_training_rounded;
    return Icons.category_rounded;
  }

  Color _getStatusColor(NonconformityStatus status) {
    switch (status) {
      case NonconformityStatus.open:
        return const Color(0xFFE11D48);
      case NonconformityStatus.overdue:
        return const Color(0xFFEA580C);
      case NonconformityStatus.completed:
        return const Color(0xFF16A34A);
      case NonconformityStatus.inProgress:
        return const Color(0xFFEA580C);
      case NonconformityStatus.waitingControl:
        return const Color(0xFF0EA5E9);
    }
  }

  Color _getLineColor(String line) {
    switch (line.toUpperCase()) {
      case 'M1':
      case 'M1A':
      case 'M1B':
        return const Color(0xFFE31E24);
      case 'M2':
        return const Color(0xFF009543);
      case 'M3':
        return const Color(0xFF009FE3);
      case 'M4':
        return const Color(0xFFE91E63);
      case 'M5':
        return const Color(0xFF673AB7);
      case 'M6':
        return const Color(0xFFC7B299);
      case 'M7':
        return const Color(0xFFFF4081);
      case 'M8':
        return const Color(0xFF00BCD4);
      case 'M9':
        return const Color(0xFFFFD54F);
      case 'M11':
        return const Color(0xFF9E9E9E);
      case 'T1':
        return const Color(0xFF0054A6);
      case 'T4':
        return const Color(0xFFF07D00);
      case 'T5':
        return const Color(0xFF00A651);
      case 'F1':
      case 'F4':
        return const Color(0xFF795548);
      case 'TF1':
      case 'TF2':
        return const Color(0xFF009688);
      default:
        return const Color(0xFF1E293B);
    }
  }

  Widget _buildLineLogo(String line) {
    final color = _getLineColor(line);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          line,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
