import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/audit_model.dart';
import '../models/question_model.dart';
import '../models/nonconformity_model.dart';
import 'storage_service.dart';
import 'database_helper.dart';

/// Çevrimdışı tamamlanan denetimleri yerel olarak kuyruğa alır
/// ve internet gelince otomatik olarak yükler.
class PendingUploadService {
  static const String _storageKey = 'pending_audit_uploads';
  static bool _isProcessing = false;

  // ─── Kuyruğa ekleme ───

  /// Tamamlanan bir denetimi yükleme kuyruğuna ekler.
  /// [answers] içindeki fotoğraflar base64 (data:) formatında olabilir.
  static Future<void> enqueue({
    required AuditModel audit,
    required List<AuditAnswer> answers,
    required List<QuestionModel> questions,
    String? taskId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_storageKey) ?? [];

      final entry = jsonEncode({
        'audit': audit.toMap(),
        'answers': answers.map((a) => a.toMap()).toList(),
        'questions': questions.map((q) => q.toJson()).toList(),
        'taskId': taskId,
        'enqueuedAt': DateTime.now().toIso8601String(),
      });

      existing.add(entry);
      await prefs.setStringList(_storageKey, existing);
      debugPrint('📥 PendingUpload: Kuyruk +1 (toplam: ${existing.length})');
    } catch (e) {
      debugPrint('PendingUpload enqueue error: $e');
    }
  }

  /// Kuyrukta bekleyen denetim sayısını döndürür.
  static Future<int> get pendingCount async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_storageKey) ?? []).length;
    } catch (_) {
      return 0;
    }
  }

  // ─── Kuyruğu işleme (sync) ───

  /// Kuyrukta bekleyen denetimleri işler:
  /// 1. Fotoğrafları Cloudinary'ye yükler
  /// 2. Firestore'a güncel URL'lerle yazar
  /// 3. Başarılı kayıtları kuyruktan çıkarır
  ///
  /// İnternet yoksa sessizce çıkar, hata fırlatmaz.
  static Future<void> processPendingUploads() async {
    if (_isProcessing) return; // çift çalışmayı engelle
    _isProcessing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = prefs.getStringList(_storageKey) ?? [];
      if (entries.isEmpty) {
        _isProcessing = false;
        return;
      }

      debugPrint('🔄 PendingUpload: ${entries.length} bekleyen denetim işleniyor...');

      final failedEntries = <String>[];

      for (final entryJson in entries) {
        try {
          final data = jsonDecode(entryJson) as Map<String, dynamic>;
          await _processEntry(data).timeout(const Duration(seconds: 90), onTimeout: () {
            throw Exception('processEntry timeout: Total upload took too long');
          });
          debugPrint('✅ PendingUpload: 1 denetim başarıyla yüklendi');
        } catch (e) {
          debugPrint('❌ PendingUpload: İşlem başarısız: $e');
          failedEntries.add(entryJson);
        }
      }

      // Başarısız olanları geri yaz, başarılı olanları sil
      await prefs.setStringList(_storageKey, failedEntries);

      final processed = entries.length - failedEntries.length;
      if (processed > 0) {
        debugPrint('📤 PendingUpload: $processed denetim yüklendi, ${failedEntries.length} bekliyor');
      }
    } catch (e) {
      debugPrint('PendingUpload process error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // ─── Tek bir kuyruk kaydını işle ───

  static Future<void> _processEntry(Map<String, dynamic> data) async {
    final auditMap = Map<String, dynamic>.from(data['audit'] as Map);
    final audit = AuditModel.fromMap(auditMap);
    final answers = (data['answers'] as List)
        .map((a) => AuditAnswer.fromMap(Map<String, dynamic>.from(a as Map)))
        .toList();
    final questions = (data['questions'] as List)
        .map((q) => QuestionModel.fromJson(Map<String, dynamic>.from(q as Map)))
        .toList();
    final taskId = data['taskId'] as String?;

    // 1. Fotoğrafları yükle (base64 → Cloudinary)
    debugPrint('⏳ _processEntry: Fotoğraflar yükleniyor...');
    final uploadedAnswers = await Future.wait(
      answers.map((answer) async {
        final hasUploadablePhotos = answer.allPhotoUrls.any((p) =>
            p.isNotEmpty &&
            !p.startsWith('http://') &&
            !p.startsWith('https://') &&
            !p.startsWith('assets/') &&
            !p.startsWith('mock_'));

        if (!hasUploadablePhotos) return answer;

        try {
          final photoUrls = await StorageService.uploadPhotoPaths(
            paths: answer.allPhotoUrls,
            auditId: audit.id,
            questionId: answer.questionId,
          );
          final uploadedPhotos = photoUrls
              .map((url) => AnswerPhoto(id: 'photo-${url.hashCode.abs()}', url: url))
              .toList();
          return AuditAnswer(
            questionId: answer.questionId,
            questionText: answer.questionText,
            categoryId: answer.categoryId,
            categoryName: answer.categoryName,
            orderIndex: answer.orderIndex,
            score: answer.score,
            comment: answer.comment,
            additionalComments: answer.additionalComments,
            photoPaths: photoUrls,
            photos: uploadedPhotos,
            isNonconformity: answer.isNonconformity,
            answerType: answer.answerType,
            value: answer.value,
            weightedScore: answer.weightedScore,
            isCorrect: answer.isCorrect,
          );
        } catch (e) {
          debugPrint('Photo upload failed for ${answer.questionId}: $e');
          rethrow; // bu entry'yi failed olarak işaretle
        }
      }),
    );
    debugPrint('⏳ _processEntry: Fotoğraflar yüklendi.');

    // 2. Denetçi unvanı
    debugPrint('⏳ _processEntry: Denetçi ünvanı çözülüyor...');
    final responsibleTitle = await _resolveAuditorTitle(audit);
    debugPrint('⏳ _processEntry: Denetçi ünvanı çözüldü: $responsibleTitle');

    // 3. Final audit
    final finalAudit = audit.copyWith(answers: uploadedAnswers);

    // 4. SQLite (non-web)
    if (!kIsWeb) {
      try {
        await DatabaseHelper.instance.insertAudit(finalAudit);
        if (taskId != null) {
          final db = await DatabaseHelper.instance.database;
          await db.update('tasks', {'isCompleted': 1}, where: 'id = ?', whereArgs: [taskId]);
        }
        for (var answer in uploadedAnswers) {
          if (answer.isNonconformity) {
            final qi = questions.indexWhere((q) => q.id == answer.questionId);
            if (qi != -1) {
              final question = questions[qi];
              final nc = NonconformityModel(
                id: 'NC-${finalAudit.id}-${answer.questionId}',
                auditId: finalAudit.id,
                auditTypeId: finalAudit.auditTypeId,
                auditType: finalAudit.auditType,
                questionId: answer.questionId,
                questionText: question.questionText,
                category: question.categoryName,
                station: finalAudit.station,
                line: finalAudit.line,
                score: answer.score,
                auditorComment: [
                  if (answer.comment != null && answer.comment!.trim().isNotEmpty) answer.comment!.trim(),
                  if (answer.additionalComments.isNotEmpty) ...answer.additionalComments.map((c) => '• $c')
                ].join('\n\n'),
                auditorPhotoPaths: answer.allPhotoUrls,
                detectionDate: finalAudit.date,
                auditorName: finalAudit.auditorName,
                responsiblePerson: responsibleTitle,
                status: NonconformityStatus.open,
              );
              await DatabaseHelper.instance.insertNonconformity(nc);
            }
          }
        }
      } catch (e) {
        debugPrint('SQLite insert failed: $e');
      }
    }

    // 5. Firestore yazma (Sıralı Beklemeli - Timeout Hatasını İzole Etmek İçin)
    debugPrint('⏳ _processEntry: Firestore sıralı yazma işlemleri başlıyor... (${finalAudit.id})');
    
    try {
      debugPrint('⏳ 1. Audit yazılıyor...');
      await FirebaseFirestore.instance.collection('audits').doc(finalAudit.id).set(finalAudit.toMap()).timeout(const Duration(seconds: 15));
      debugPrint('✅ Audit başarıyla yazıldı.');

      if (taskId != null) {
        debugPrint('⏳ 2. Plan güncelleniyor...');
        await FirebaseFirestore.instance.collection('plans').doc(taskId).set(
          {'isCompleted': true},
          SetOptions(merge: true),
        ).timeout(const Duration(seconds: 10));
        debugPrint('✅ Plan güncellendi.');
      }

      for (var answer in uploadedAnswers) {
        if (answer.isNonconformity) {
          final qi = questions.indexWhere((q) => q.id == answer.questionId);
          if (qi != -1) {
            final question = questions[qi];
            final nc = NonconformityModel(
              id: 'NC-${finalAudit.id}-${answer.questionId}',
              auditId: finalAudit.id,
              auditTypeId: finalAudit.auditTypeId,
              auditType: finalAudit.auditType,
              questionId: answer.questionId,
              questionText: question.questionText,
              category: question.categoryName,
              station: finalAudit.station,
              line: finalAudit.line,
              score: answer.score,
              auditorComment: [
                if (answer.comment != null && answer.comment!.trim().isNotEmpty) answer.comment!.trim(),
                if (answer.additionalComments.isNotEmpty) ...answer.additionalComments.map((c) => '• $c')
              ].join('\n\n'),
              auditorPhotoPaths: answer.allPhotoUrls,
              detectionDate: finalAudit.date,
              auditorName: finalAudit.auditorName,
              responsiblePerson: responsibleTitle,
              status: NonconformityStatus.open,
            );
            
            debugPrint('⏳ 3. Uygunsuzluk yazılıyor... (${nc.id})');
            await FirebaseFirestore.instance.collection('nonconformities').doc(nc.id).set(nc.toMap()).timeout(const Duration(seconds: 10));
            debugPrint('✅ Uygunsuzluk yazıldı: ${nc.id}');
          }
        }
      }
    } catch (e, stack) {
      debugPrint('❌ _processEntry Sıralı Yazma Hatası: $e');
      throw Exception('Firestore sıralı yazma hatası: $e');
    }
    
    debugPrint('⏳ _processEntry: Firestore yazma işlemleri tamamlandı.');
  }

  // ─── Yardımcı metotlar ───

  /// Basit bağlantı kontrolü: Firestore'a küçük bir istek atarak
  /// internetin olup olmadığını anlar.
  static Future<bool> _checkConnectivity() async {
    try {
      await FirebaseFirestore.instance
          .collection('audits')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 3));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Denetçi unvanını çözer (timeout ile).
  static Future<String> _resolveAuditorTitle(AuditModel audit) async {
    const fallback = 'Tanımlanmadı';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(audit.auditorId)
          .get()
          .timeout(const Duration(milliseconds: 500));
      final title = doc.data()?['title']?.toString();
      if (title != null && title.isNotEmpty) return title;

      final byName = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: audit.auditorName)
          .limit(1)
          .get()
          .timeout(const Duration(milliseconds: 500));
      if (byName.docs.isNotEmpty) {
        final t = byName.docs.first.data()['title']?.toString();
        if (t != null && t.isNotEmpty) return t;
      }
    } catch (_) {}
    return fallback;
  }

  /// Kuyruktaki bekleyen denetimleri döndürür (UI'da göstermek için)
  static Future<List<AuditModel>> getPendingAudits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = prefs.getStringList(_storageKey) ?? [];
      final list = <AuditModel>[];
      for (final entryJson in entries) {
        try {
          final data = jsonDecode(entryJson) as Map<String, dynamic>;
          final auditMap = Map<String, dynamic>.from(data['audit'] as Map);
          list.add(AuditModel.fromMap(auditMap));
        } catch (e, stack) {
          debugPrint('🚨 getPendingAudits Parse Error: $e');
        }
      }
      return list;
    } catch (e, stack) {
      debugPrint('🚨 getPendingAudits Global Error: $e');
      return [];
    }
  }

  /// Kuyruktaki bekleyen uygunsuzlukları döndürür (UI'da göstermek için)
  static Future<List<NonconformityModel>> getPendingNonconformities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = prefs.getStringList(_storageKey) ?? [];
      final list = <NonconformityModel>[];
      for (final entryJson in entries) {
        try {
          final data = jsonDecode(entryJson) as Map<String, dynamic>;
          final auditMap = Map<String, dynamic>.from(data['audit'] as Map);
          final audit = AuditModel.fromMap(auditMap);
          final answers = (data['answers'] as List)
              .map((a) => AuditAnswer.fromMap(Map<String, dynamic>.from(a as Map)))
              .toList();
          final questions = (data['questions'] as List)
              .map((q) => QuestionModel.fromJson(Map<String, dynamic>.from(q as Map)))
              .toList();

          for (var answer in answers) {
            if (answer.isNonconformity) {
              final qi = questions.indexWhere((q) => q.id == answer.questionId);
              if (qi != -1) {
                final question = questions[qi];
                list.add(NonconformityModel(
                  id: 'NC-${audit.id}-${answer.questionId}',
                  auditId: audit.id,
                  auditTypeId: audit.auditTypeId,
                  auditType: audit.auditType,
                  questionId: answer.questionId,
                  questionText: question.questionText,
                  category: question.categoryName,
                  station: audit.station,
                  line: audit.line,
                  score: answer.score,
                  auditorComment: [
                    if (answer.comment != null && answer.comment!.trim().isNotEmpty) answer.comment!.trim(),
                    if (answer.additionalComments.isNotEmpty) ...answer.additionalComments.map((c) => '• $c')
                  ].join('\n\n'),
                  auditorPhotoPaths: answer.allPhotoUrls,
                  detectionDate: audit.date,
                  auditorName: audit.auditorName,
                  responsiblePerson: 'Bekliyor', // Placeholder for pending UI
                  status: NonconformityStatus.open,
                ));
              }
            }
          }
        } catch (e, stack) {
          debugPrint('🚨 getPendingNonconformities Parse Error: $e');
        }
      }
      return list;
    } catch (e, stack) {
      debugPrint('🚨 getPendingNonconformities Global Error: $e');
      return [];
    }
  }
}
