import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/audit_provider.dart';
import '../providers/nonconformity_provider.dart';
import '../models/question_model.dart';
import '../models/audit_model.dart';
import '../models/audit_type_model.dart';
import '../services/audit_scoring_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';

class AuditQuestionScreen extends StatelessWidget {
  const AuditQuestionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audit = Provider.of<AuditProvider>(context);
    
    if (audit.isLoadingDraft) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final questions = audit.activeQuestions;
    final answers = audit.currentAnswers;
    
    if (questions.isEmpty) {
      return const Scaffold(body: Center(child: Text('Soru listesi yüklenemedi.')));
    }

    final isAllAnswered = questions.length == answers.length;
    final canComplete = isAllAnswered && _hasRequiredPhotos(audit.activeAuditType, questions, answers);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Denetim Formu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ..._buildQuestionSections(questions).expand((section) {
            final categoryQuestions = section.questions;
            return [
              _buildGroupHeader(context, section),
              const SizedBox(height: 12),
              ...categoryQuestions.map((q) {
                AuditAnswer? ans;
                try {
                  ans = answers.firstWhere((a) => a.questionId == q.id);
                } catch (_) {
                  ans = null;
                }
                final questionNumber = questions.indexWhere((item) => item.id == q.id) + 1;
                return _buildQuestionCard(context, q, ans, audit, questionNumber);
              }),
              const SizedBox(height: 24),
            ];
          }),
          ],
        ),
      ),
      bottomNavigationBar: _buildNavigationBars(audit, canComplete, context),
    );
  }

  bool _hasRequiredPhotos(AuditTypeModel auditType, List<QuestionModel> questions, List<AuditAnswer> answers) {
    for (final question in questions) {
      final answerIndex = answers.indexWhere((answer) => answer.questionId == question.id);
      if (answerIndex == -1) return false;
      final answer = answers[answerIndex];
      final requiresPhoto = AuditScoringService.requiresEvidencePhoto(
        auditType: auditType,
        question: question,
        answer: answer,
      );
      if (requiresPhoto && answer.allPhotoUrls.isEmpty) return false;
    }
    return true;
  }



  Widget _buildNavigationBars(AuditProvider audit, bool canComplete, BuildContext context) {
    bool isSubmitting = false;
    return StatefulBuilder(
      builder: (context, setState) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))],
            ),
            child: ElevatedButton(
              onPressed: (!canComplete || isSubmitting) ? null : () async {
                setState(() {
                  isSubmitting = true;
                });
                try {
                  final ncProvider = Provider.of<NonconformityProvider>(context, listen: false);
                  final completedAudit = await audit.completeAudit(ncProvider);
                  if (completedAudit != null && context.mounted) {
                    context.push('/audit-summary/${completedAudit.id}', extra: completedAudit);
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Denetim tamamlandı ancak yönlendirme yapılamadı (taslak bulunamadı).')),
                    );
                  }
                } catch (e, stack) {
                  debugPrint('Denetim tamamlama hatası: $e\n$stack');
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Hata', style: TextStyle(fontWeight: FontWeight.bold)),
                        content: SingleChildScrollView(
                          child: Text('Denetim tamamlanırken bir hata oluştu. Lütfen bu hata mesajını iletin:\n\n$e'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('KAPAT'),
                          ),
                        ],
                      ),
                    );
                  }
                } finally {
                  if (context.mounted) {
                    setState(() {
                      isSubmitting = false;
                    });
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('DENETİMİ BİTİR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
          ),
        );
      }
    );
  }

  Widget _buildQuestionCard(BuildContext context, QuestionModel q, AuditAnswer? ans, AuditProvider audit, int questionNumber) {
    final bool isAnswered = ans != null;
    final score = ans?.score ?? 0;
    final answerColor = isAnswered ? _scoreColor(score) : AppColors.primary;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          )
        ],
        border: Border.all(
          color: isAnswered ? Theme.of(context).primaryColor.withValues(alpha: 0.3) : Theme.of(context).dividerColor.withValues(alpha: 0.12),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: isAnswered ? answerColor : Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  child: Text(
                    questionNumber.toString(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: isAnswered ? Colors.white : Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    q.questionText,
                    style: TextStyle(
                      fontWeight: FontWeight.w600, 
                      fontSize: 12, 
                      color: Theme.of(context).textTheme.titleMedium?.color, 
                      height: 1.30
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildAnswerControl(context, q, ans, audit),
            if (ans != null) ...[
              const SizedBox(height: 8),
              _buildAnswerPhotoSection(context, q, ans, audit),
              _buildAdditionalCommentsSection(context, q, ans, audit),
            ],
            if (ans != null || q.answerType == AnswerType.scale || q.answerType == AnswerType.scale6) ...[
              const SizedBox(height: 8),
              _buildActionButtons(context, q, ans, audit),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerPhotoSection(BuildContext context, QuestionModel q, AuditAnswer ans, AuditProvider audit) {
    final photos = ans.photos.isNotEmpty
        ? ans.photos
        : ans.photoPaths
            .where((path) => path.isNotEmpty)
            .map((path) => AnswerPhoto(id: 'photo-${path.hashCode.abs()}', url: path))
            .toList();
    final isRequired = AuditScoringService.requiresEvidencePhoto(
      auditType: audit.activeAuditType,
      question: q,
      answer: ans,
    );

    if (photos.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? 'Kanıt fotoğrafları' : 'Fotoğraflar',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
            itemBuilder: (context, index) {
              if (index == photos.length) {
                return _addPhotoTile(context, q, audit);
              }
              final photo = photos[index];
              return SizedBox(
                width: 48,
                child: Stack(
                  children: [
                    Positioned.fill(child: PositionBox(path: photo.url)),
                    Positioned(
                      right: 1,
                      top: 1,
                      child: InkWell(
                        onTap: () => audit.removePhotoFromAnswer(q.id, photo.id),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(1),
                          decoration: const BoxDecoration(color: Color(0xFFE11D48), shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 9, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _addPhotoTile(BuildContext context, QuestionModel q, AuditProvider audit) {
    return InkWell(
      onTap: () => _showPhotoSourcePicker(context, q, audit),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.3), width: 1.0),
          color: Theme.of(context).primaryColor.withValues(alpha: 0.04),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_rounded, color: Theme.of(context).primaryColor, size: 14),
            const SizedBox(height: 1),
            Text('+ Fotoğraf', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
          ],
        ),
      ),
    );
  }

  Future<void> _showPhotoSourcePicker(BuildContext context, QuestionModel q, AuditProvider audit) async {
    final picker = ImagePicker();

    Future<void> pick(ImageSource source) async {
      try {
        final photo = await picker.pickImage(
          source: source, 
          imageQuality: 50,
          maxWidth: 1080,
        );
        if (photo != null && context.mounted) {
          final persistentPath = await StorageService.savePhotoPersistently(photo.path);
          audit.addPhotosToAnswer(q.id, [persistentPath]);
        }
      } catch (e) {
        debugPrint('Image pick error: $e');
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await pick(ImageSource.camera);
                  },
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Kamera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await pick(ImageSource.gallery);
                  },
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Galeri'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerControl(BuildContext context, QuestionModel q, AuditAnswer? ans, AuditProvider audit) {
    switch (q.answerType) {
      case AnswerType.boolean:
        return Row(
          children: [
            Expanded(child: _choiceButton(context, 'Evet', ans?.value == true, () {
              final answer = AuditAnswer(
                questionId: q.id,
                score: 1,
                answerType: q.answerType,
                value: true,
                photoPaths: ans?.allPhotoUrls ?? const [],
                photos: ans?.photos,
                additionalComments: ans?.additionalComments ?? const [],
              );
              _handleAnswerSelection(context, q, audit, answer);
            }, activeColor: Colors.green)),
            const SizedBox(width: 8),
            Expanded(child: _choiceButton(context, 'Hayır', ans?.value == false, () async {
              final answer = AuditAnswer(
                questionId: q.id,
                score: 0,
                answerType: q.answerType,
                value: false,
                isNonconformity: true,
                photoPaths: ans?.allPhotoUrls ?? const [],
                photos: ans?.photos,
                additionalComments: ans?.additionalComments ?? const [],
              );
              _handleAnswerSelection(context, q, audit, answer);
            }, activeColor: const Color(0xFFE11D48))),
          ],
        );
      case AnswerType.text:
        return TextField(
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Yanıtınızı yazın'),
          onChanged: (value) {
            final answer = AuditAnswer(
              questionId: q.id,
              score: 0,
              answerType: q.answerType,
              value: value,
              photoPaths: ans?.allPhotoUrls ?? const [],
              photos: ans?.photos,
              additionalComments: ans?.additionalComments ?? const [],
            );
            // _handleAnswerSelection for TextField is tricky because it fires on every keypress.
            // But text fields don't usually require dialogs, they are the comment themselves!
            // Actually, we should just save it directly for now since it's just a text answer.
            audit.saveAnswer(answer);
          },
        );
      case AnswerType.multiChoice:
      case AnswerType.quiz:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: q.options.map((option) {
            final label = option['label']?.toString() ?? option['title']?.toString() ?? '-';
            final value = option['value'] ?? label;
            final score = (option['score'] as num?)?.toInt() ?? 0;
            final isSelected = ans?.value == value;
            return _choiceButton(context, label, isSelected, () {
              final answer = AuditAnswer(
                questionId: q.id,
                score: score,
                answerType: q.answerType,
                value: value,
                isCorrect: option['isCorrect'] as bool?,
                isNonconformity: score <= 0,
                photoPaths: ans?.allPhotoUrls ?? const [],
                photos: ans?.photos,
                additionalComments: ans?.additionalComments ?? const [],
              );
              _handleAnswerSelection(context, q, audit, answer);
            });
          }).toList(),
        );
      case AnswerType.scale:
      case AnswerType.scale6:
        final scores = const [0, 1, 2, 3, 4, 5];
        final bool isKd = ans?.isOutOfScope == true;
        return Row(
          children: [
            for (int i = 0; i < scores.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    final s = scores[i];
                    final answer = AuditAnswer(
                      questionId: q.id,
                      score: s,
                      answerType: q.answerType,
                      value: s,
                      isOutOfScope: false,
                      isNonconformity: AuditScoringService.isNonconformity(
                        auditType: audit.activeAuditType,
                        question: q,
                        answer: AuditAnswer(questionId: q.id, score: s, value: s, answerType: q.answerType),
                      ),
                      photoPaths: ans?.allPhotoUrls ?? const [],
                      photos: ans?.photos,
                      additionalComments: ans?.additionalComments ?? const [],
                    );
                    _handleAnswerSelection(context, q, audit, answer);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 38,
                    decoration: BoxDecoration(
                      color: (!isKd && ans?.score == scores[i]) ? _scoreColor(scores[i]) : Theme.of(context).dividerColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (!isKd && ans?.score == scores[i]) ? _scoreColor(scores[i]) : Theme.of(context).dividerColor.withValues(alpha: 0.15),
                        width: 1.2,
                      ),
                      boxShadow: (!isKd && ans?.score == scores[i])
                          ? [BoxShadow(color: _scoreColor(scores[i]).withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 2))]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        scores[i].toString(),
                        style: TextStyle(
                          color: (!isKd && ans?.score == scores[i]) ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
    }
  }

  Widget _choiceButton(BuildContext context, String label, bool selected, VoidCallback onTap, {Color? activeColor}) {
    final color = activeColor ?? Theme.of(context).primaryColor;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? color : Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? color : Theme.of(context).dividerColor.withValues(alpha: 0.6)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : null,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }


  Color _scoreColor(int score) {
    switch (score) {
      case 0: return const Color(0xFF9F1239);
      case 1: return const Color(0xFFE11D48);
      case 2: return const Color(0xFFFB923C);
      case 3: return const Color(0xFFFACC15);
      case 4: return const Color(0xFF4ADE80);
      case 5: return const Color(0xFF16A34A);
      default: return Colors.grey;
    }
  }

  List<_QuestionSection> _buildQuestionSections(List<QuestionModel> questions) {
    final grouped = <String, List<QuestionModel>>{};
    for (final question in questions) {
      grouped.putIfAbsent(question.categoryName, () => []).add(question);
    }

    final sections = grouped.entries.map((entry) {
      return _QuestionSection(
        categoryId: entry.key,
        title: entry.key.isNotEmpty ? entry.key : 'Sorular',
        icon: _getCategoryIcon(entry.key),
        orderIndex: questions.indexOf(entry.value.first),
        questions: entry.value..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)),
      );
    }).toList()
      ..sort((a, b) {
        final orderCompare = a.orderIndex.compareTo(b.orderIndex);
        if (orderCompare != 0) return orderCompare;
        return a.title.compareTo(b.title);
      });

    return sections;
  }

  Widget _buildGroupHeader(BuildContext context, _QuestionSection section) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).primaryColor.withValues(alpha: 0.15), width: 1.5)),
      ),
      child: Row(
        children: [
          Icon(section.icon, color: Theme.of(context).primaryColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              section.title.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.0,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    if (category.contains('SINIFLANDIRMA')) return Icons.auto_delete_rounded;
    if (category.contains('SIRALAMA')) return Icons.dashboard_customize_rounded;
    if (category.contains('SİLME')) return Icons.cleaning_services_rounded;
    if (category.contains('STANDARTLAŞTIRMA')) return Icons.rule_rounded;
    if (category.contains('SAHİPLENME')) return Icons.model_training_rounded;
    return Icons.category_rounded;
  }

  Widget _buildAdditionalCommentsSection(BuildContext context, QuestionModel q, AuditAnswer ans, AuditProvider audit) {
    final allComments = <Map<String, dynamic>>[];
    if (ans.comment != null && ans.comment!.trim().isNotEmpty) {
      allComments.add({'isMain': true, 'text': ans.comment!.trim(), 'index': -1});
    }
    for (int i = 0; i < ans.additionalComments.length; i++) {
      if (ans.additionalComments[i].trim().isNotEmpty) {
        allComments.add({'isMain': false, 'text': ans.additionalComments[i].trim(), 'index': i});
      }
    }

    final isRequired = AuditScoringService.requiresComment(
      auditType: audit.activeAuditType,
      question: q,
      answer: ans,
    ) || ans.isNonconformity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (allComments.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Açıklamalar', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8))),
          const SizedBox(height: 4),
          ...allComments.map((item) {
            final isMain = item['isMain'] as bool;
            final text = item['text'] as String;
            final index = item['index'] as int;
            final canDelete = !(isRequired && allComments.length <= 1);

            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(text, style: const TextStyle(fontSize: 11)),
                  ),
                  InkWell(
                    onTap: () {
                      final tc = TextEditingController(text: text);
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Açıklamayı Düzenle', style: TextStyle(fontSize: 16)),
                          content: TextField(
                            controller: tc,
                            maxLines: 3,
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('İPTAL'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                if (isMain) {
                                  audit.saveAnswer(AuditAnswer(
                                    questionId: ans.questionId,
                                    score: ans.score,
                                    answerType: ans.answerType,
                                    value: ans.value,
                                    isCorrect: ans.isCorrect,
                                    isNonconformity: ans.isNonconformity,
                                    comment: tc.text.trim(),
                                    photoPaths: ans.allPhotoUrls,
                                    photos: ans.photos,
                                    additionalComments: ans.additionalComments,
                                    isOutOfScope: ans.isOutOfScope,
                                  ));
                                } else {
                                  audit.updateAdditionalComment(q.id, index, tc.text);
                                }
                                Navigator.pop(context);
                              },
                              child: const Text('KAYDET'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: canDelete ? () {
                      if (isMain) {
                        audit.saveAnswer(AuditAnswer(
                          questionId: ans.questionId,
                          score: ans.score,
                          answerType: ans.answerType,
                          value: ans.value,
                          isCorrect: ans.isCorrect,
                          isNonconformity: ans.isNonconformity,
                          comment: '',
                          photoPaths: ans.allPhotoUrls,
                          photos: ans.photos,
                          additionalComments: ans.additionalComments,
                          isOutOfScope: ans.isOutOfScope,
                        ));
                      } else {
                        audit.removeAdditionalComment(q.id, index);
                      }
                    } : null,
                    child: Icon(Icons.delete_outline_rounded, size: 16, color: canDelete ? Colors.red : Colors.grey.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, QuestionModel q, AuditAnswer? ans, AuditProvider audit) {
    final bool isScale = q.answerType == AnswerType.scale || q.answerType == AnswerType.scale6;
    if (ans == null && !isScale) {
      return const SizedBox();
    }

    final bool isKd = ans?.isOutOfScope == true;
    final photos = ans != null ? (ans.photos.isNotEmpty ? ans.photos : ans.photoPaths.where((path) => path.isNotEmpty).toList()) : const [];
    final requiresPhoto = ans != null ? AuditScoringService.requiresEvidencePhoto(auditType: audit.activeAuditType, question: q, answer: ans) : false;

    return Row(
      children: [
        if (ans != null) ...[
          if (photos.isEmpty) ...[
            ElevatedButton.icon(
              onPressed: () => _showPhotoSourcePicker(context, q, audit),
              icon: const Icon(Icons.add_a_photo_rounded, size: 13),
              label: Text(requiresPhoto ? 'Kanıt Foto' : 'Fotoğraf Ekle', style: const TextStyle(fontSize: 10.5)),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.10),
                foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                minimumSize: const Size(0, 30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 6),
          ],
          ElevatedButton.icon(
            onPressed: () => _showAdditionalCommentDialog(context, q, audit),
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Açıklama Ekle', style: TextStyle(fontSize: 10.5)),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.10),
              foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              minimumSize: const Size(0, 30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
        if (isScale) ...[
          const Spacer(),
          Builder(
            builder: (context) {
              final bool isDark = Theme.of(context).brightness == Brightness.dark;
              final Color activeBg = isDark ? const Color(0xFF1E3A8A) : Theme.of(context).primaryColor;
              final Color activeBorder = isDark ? const Color(0xFF3B82F6) : Theme.of(context).primaryColor;

              return OutlinedButton(
                onPressed: () {
                  final answer = AuditAnswer(
                    questionId: q.id,
                    score: -1,
                    answerType: q.answerType,
                    value: 'KD',
                    isOutOfScope: true,
                    isNonconformity: false,
                    photoPaths: const [],
                    photos: const [],
                    additionalComments: const [],
                  );
                  audit.saveAnswer(answer);
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: isKd ? activeBg : Theme.of(context).dividerColor.withValues(alpha: 0.03),
                  foregroundColor: isKd ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  side: BorderSide(
                    color: isKd ? activeBorder : Theme.of(context).dividerColor.withValues(alpha: 0.15),
                    width: 1.0,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  minimumSize: const Size(0, 30),
                ),
                child: const Text(
                  'Kapsam Dışı',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                  ),
                ),
              );
            }
          ),
        ],
      ],
    );
  }

  Future<void> _showAdditionalCommentDialog(BuildContext context, QuestionModel q, AuditProvider audit, {int? index, String? initialText}) async {
    final controller = TextEditingController(text: initialText);
    final isNew = index == null;
    
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNew ? 'İlave Açıklama Ekle' : 'Açıklamayı Düzenle', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Açıklamanızı yazın...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text), 
            child: const Text('Kaydet')
          ),
        ],
      ),
    );

    if (result != null) {
      if (isNew) {
        audit.addAdditionalCommentToAnswer(q.id, result);
      } else {
        audit.updateAdditionalComment(q.id, index, result);
      }
    }
  }

  Future<void> _handleAnswerSelection(
    BuildContext context,
    QuestionModel q,
    AuditProvider audit,
    AuditAnswer answer,
  ) async {
    final requiresPhoto = AuditScoringService.requiresEvidencePhoto(
      auditType: audit.activeAuditType,
      question: q,
      answer: answer,
    );
    final requiresComment = AuditScoringService.requiresComment(
      auditType: audit.activeAuditType,
      question: q,
      answer: answer,
    );
    final isNonconformity = AuditScoringService.isNonconformity(
      auditType: audit.activeAuditType,
      question: q,
      answer: answer,
    );

    if (requiresPhoto || requiresComment || isNonconformity) {
      final existing = audit.currentAnswers.cast<AuditAnswer?>().firstWhere((a) => a?.questionId == q.id, orElse: () => null);
      final result = await showDialog<AuditAnswer>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _AnswerDetailsDialog(
          question: q,
          tentativeAnswer: answer,
          requiresPhoto: requiresPhoto,
          requiresComment: requiresComment,
          isNonconformity: isNonconformity,
          existing: existing,
        ),
      );
      if (result != null) audit.saveAnswer(result);
    } else {
      audit.saveAnswer(answer);
    }
  }
}

class _QuestionSection {
  final String categoryId;
  final String title;
  final IconData icon;
  final int orderIndex;
  final List<QuestionModel> questions;

  const _QuestionSection({
    required this.categoryId,
    required this.title,
    required this.icon,
    required this.orderIndex,
    required this.questions,
  });
}

class _AnswerDetailsDialog extends StatefulWidget {
  final QuestionModel question;
  final AuditAnswer tentativeAnswer;
  final bool requiresPhoto;
  final bool requiresComment;
  final bool isNonconformity;
  final AuditAnswer? existing;

  const _AnswerDetailsDialog({
    required this.question,
    required this.tentativeAnswer,
    required this.requiresPhoto,
    required this.requiresComment,
    required this.isNonconformity,
    this.existing,
  });

  @override
  State<_AnswerDetailsDialog> createState() => _AnswerDetailsDialogState();
}

class _AnswerDetailsDialogState extends State<_AnswerDetailsDialog> {
  final _commentController = TextEditingController();
  final List<String> _photoPaths = [];
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _commentController.text = widget.existing?.comment ?? '';
    _photoPaths.addAll(widget.existing?.allPhotoUrls ?? const []);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(source: source, imageQuality: 70, maxWidth: 1080);
      if (photo != null) {
        final persistentPath = await StorageService.savePhotoPersistently(photo.path);
        if (mounted) {
          setState(() => _photoPaths.add(persistentPath));
        }
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(widget.isNonconformity ? Icons.warning_amber_rounded : Icons.info_outline_rounded, 
               color: widget.isNonconformity ? const Color(0xFFE11D48) : Theme.of(context).primaryColor),
          const SizedBox(width: 10),
          const Text('Zorunlu Alanlar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.question.questionText, 
                style: TextStyle(
                  fontSize: 13, 
                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8), 
                  fontStyle: FontStyle.italic
                )
              ),
              const SizedBox(height: 20),
              Text('Açıklama${widget.requiresComment ? ' *' : ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                maxLines: 3,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  hintText: 'Lütfen açıklama giriniz...',
                  hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.65)),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              Text('Kanıt Fotoğrafları${widget.requiresPhoto ? ' *' : ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('Kamera', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Theme.of(context).primaryColor),
                        foregroundColor: Theme.of(context).primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_rounded, size: 18),
                      label: const Text('Galeri', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Theme.of(context).primaryColor.withValues(alpha: 0.6)),
                        foregroundColor: Theme.of(context).primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              if (_photoPaths.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photoPaths.length,
                    itemBuilder: (context, index) {
                      final path = _photoPaths[index];
                      return Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            PositionBox(path: path),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: InkWell(
                                onTap: () => setState(() => _photoPaths.removeAt(index)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
        ElevatedButton(
          onPressed: () {
            if (widget.requiresPhoto && _photoPaths.isEmpty) return null;
            if (widget.requiresComment && _commentController.text.trim().isEmpty && widget.tentativeAnswer.additionalComments.isEmpty) return null;
            return () {
              final photos = _photoPaths
                  .where((path) => path.isNotEmpty)
                  .map((path) => AnswerPhoto(
                        id: 'photo-${DateTime.now().millisecondsSinceEpoch}-${path.hashCode.abs()}',
                        url: path,
                      ))
                  .toList();
              Navigator.pop(context, AuditAnswer(
                questionId: widget.tentativeAnswer.questionId,
                score: widget.tentativeAnswer.score,
                answerType: widget.tentativeAnswer.answerType,
                value: widget.tentativeAnswer.value,
                isCorrect: widget.tentativeAnswer.isCorrect,
                isNonconformity: widget.isNonconformity,
                comment: _commentController.text.trim(),
                photoPaths: _photoPaths,
                photos: photos,
                additionalComments: widget.tentativeAnswer.additionalComments,
                isOutOfScope: widget.tentativeAnswer.isOutOfScope,
              ));
            };
          }(),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isNonconformity ? const Color(0xFFE11D48) : Theme.of(context).primaryColor, 
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[300],
            disabledForegroundColor: Colors.grey[800],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            'Kaydet', 
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: ((widget.requiresPhoto && _photoPaths.isEmpty) || (widget.requiresComment && _commentController.text.trim().isEmpty && widget.tentativeAnswer.additionalComments.isEmpty))
                  ? Colors.grey[700]
                  : Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class PositionBox extends StatelessWidget {
  final String path;
  const PositionBox({super.key, required this.path});

  Widget _buildFullSizeImage() {
    if (path.startsWith('data:image')) {
      final base64String = path.split(',').last;
      final bytes = base64Decode(base64String);
      return Image.memory(bytes, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.error, color: Colors.white, size: 50));
    } else if (path.startsWith('http') || path.startsWith('blob:')) {
      return Image.network(path, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.error, color: Colors.white, size: 50));
    } else if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.error, color: Colors.white, size: 50));
    } else if (kIsWeb) {
      return Image.network(path, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.error, color: Colors.white, size: 50));
    } else {
      final cleanPath = path.startsWith('file://') ? path.replaceFirst('file://', '') : path;
      return Image.file(File(cleanPath), fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.error, color: Colors.white, size: 50));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (path.startsWith('data:image')) {
      final base64String = path.split(',').last;
      final bytes = base64Decode(base64String);
      image = Image.memory(
        bytes,
        width: 68,
        height: 68,
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) => Container(color: Colors.grey, child: const Icon(Icons.error)),
      );
    } else if (path.startsWith('http') || path.startsWith('blob:')) {
      image = Image.network(
        path,
        width: 68,
        height: 68,
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) => Container(color: Colors.grey, child: const Icon(Icons.error)),
      );
    } else if (path.startsWith('assets/')) {
      image = Image.asset(
        path,
        width: 68,
        height: 68,
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) => Container(color: Colors.grey, child: const Icon(Icons.error)),
      );
    } else if (kIsWeb) {
      image = Image.network(
        path,
        width: 68,
        height: 68,
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) => Container(color: Colors.grey, child: const Icon(Icons.error)),
      );
    } else {
      final cleanPath = path.startsWith('file://') ? path.replaceFirst('file://', '') : path;
      image = Image.file(
        File(cleanPath),
        width: 68,
        height: 68,
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) => Container(color: Colors.grey, child: const Icon(Icons.error)),
      );
    }

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: Colors.black.withValues(alpha: 0.9),
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 4,
                    child: _buildFullSizeImage(),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 68,
          height: 68,
          color: Colors.grey.shade100,
          alignment: Alignment.center,
          child: image,
        ),
      ),
    );
  }
}
