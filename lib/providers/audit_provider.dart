import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/audit_model.dart';
import '../models/question_model.dart';
import '../providers/nonconformity_provider.dart';
import '../data/mock_data.dart';
import 'dart:math';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../services/pending_upload_service.dart';
import '../models/audit_type_model.dart';
import '../services/audit_scoring_service.dart';

class AuditProvider extends ChangeNotifier {
  AuditModel? _currentAudit;
  int _currentQuestionIndex = 0;
  List<AuditAnswer> _currentAnswers = [];
  List<QuestionModel> _activeQuestions = [];
  AuditTypeModel _activeAuditType = AuditTypeModel.stationInspection;
  List<AuditModel> _auditHistory = [];
  List<AuditModel> _pendingAudits = [];
  bool _isLoadingDraft = true;
  bool _isHistoryLoaded = false;
  String? _associatedTaskId;
  Timer? _syncTimer;

  String? get associatedTaskId => _associatedTaskId;

  AuditModel? get currentAudit => _currentAudit;
  int get currentQuestionIndex => _currentQuestionIndex;
  List<AuditAnswer> get currentAnswers => _currentAnswers;
  List<QuestionModel> get activeQuestions => _activeQuestions;
  AuditTypeModel get activeAuditType => _activeAuditType;
  
  List<AuditModel> get auditHistory {
    final Map<String, AuditModel> merged = { for (var a in _auditHistory) a.id: a };
    for (var p in _pendingAudits) {
      merged[p.id] = p; // Pending ones override or append
    }
    final result = merged.values.toList();
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }
  
  bool get isLoadingDraft => _isLoadingDraft;
  bool get isHistoryLoaded => _isHistoryLoaded;
  
  QuestionModel get currentQuestion => _activeQuestions[_currentQuestionIndex];
  bool get isFirstQuestion => _currentQuestionIndex == 0;
  bool get isLastQuestion => _activeQuestions.isEmpty ? true : _currentQuestionIndex == _activeQuestions.length - 1;
  double get progress => _activeQuestions.isEmpty ? 0 : (_currentQuestionIndex + 1) / _activeQuestions.length;

  AuditProvider() {
    _initRealtimeSync();
    _loadActiveDraft();
    _startSyncTimer();
  }

  /// 30 saniyede bir bekleyen yüklemeleri kontrol eder.
  /// İnternet varsa fotoğrafları yükler ve Firestore'a yazar.
  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _loadPendingAudits();
      PendingUploadService.processPendingUploads();
    });
    // İlk açılışta da bir kez çalıştır (5 saniye gecikmeyle, uygulama yüklensin)
    Future.delayed(const Duration(seconds: 5), () async {
      await _loadPendingAudits();
      PendingUploadService.processPendingUploads();
    });
  }

  Future<void> _loadPendingAudits() async {
    _pendingAudits = await PendingUploadService.getPendingAudits();
    notifyListeners();
  }

  void _initRealtimeSync() {
    // Listen for Firestore Audits Real-time safely for the last 45 days only
    // This prevents downloading all 5000+ audits on every mobile app load
    final date45DaysAgo = DateTime.now().subtract(const Duration(days: 45));
    final date45DaysAgoStr = date45DaysAgo.toIso8601String();

    FirebaseFirestore.instance
        .collection('audits')
        .where('date', isGreaterThanOrEqualTo: date45DaysAgoStr)
        .snapshots()
        .listen((snapshot) {
      final List<AuditModel> audits = [];
      for (final doc in snapshot.docs) {
        try {
          audits.add(AuditModel.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Skipping malformed audit doc (${doc.id}): $e');
        }
      }
      // Sort descending by date in-memory
      audits.sort((a, b) => b.date.compareTo(a.date));
      _auditHistory = audits.where((audit) => !_isDemoAudit(audit)).toList();
      _isHistoryLoaded = true;
      for (final audit in audits.where(_isDemoAudit)) {
        try {
          FirebaseFirestore.instance.collection('audits').doc(audit.id).delete();
        } catch (_) {}
      }
      _loadPendingAudits();
    }, onError: (e) {
      debugPrint('Firestore Audits Sync Error: $e');
    });
  }

  Future<void> _saveActiveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentAudit == null) {
        await prefs.remove('active_audit_draft');
      } else {
        final draft = {
          'currentAudit': _currentAudit!.toMap(),
          'currentQuestionIndex': _currentQuestionIndex,
          'currentAnswers': _currentAnswers.map((e) => e.toMap()).toList(),
          'activeQuestions': _activeQuestions.map((e) => e.toJson()).toList(),
          'activeAuditType': _activeAuditType.toJson(),
          'associatedTaskId': _associatedTaskId,
        };
        await prefs.setString('active_audit_draft', jsonEncode(draft));
      }
    } catch (e) {
      debugPrint('Save active draft error: $e');
    }
  }

  Future<void> _loadActiveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftStr = prefs.getString('active_audit_draft');
      if (draftStr != null) {
        final Map<String, dynamic> draft = jsonDecode(draftStr);
        _currentAudit = AuditModel.fromMap(Map<String, dynamic>.from(draft['currentAudit']));
        _currentQuestionIndex = draft['currentQuestionIndex'] ?? 0;
        _currentAnswers = ((draft['currentAnswers'] as List?) ?? [])
            .map((e) => AuditAnswer.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        _activeQuestions = ((draft['activeQuestions'] as List?) ?? [])
            .map((e) => QuestionModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _activeAuditType = AuditTypeModel.fromJson(Map<String, dynamic>.from(draft['activeAuditType'] as Map));
        _associatedTaskId = draft['associatedTaskId'] as String?;
      }
    } catch (e) {
      debugPrint('Load active draft error: $e');
    } finally {
      _isLoadingDraft = false;
      notifyListeners();
    }
  }

  Future<void> _clearActiveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_audit_draft');
      _currentAudit = null;
      _associatedTaskId = null;
    } catch (e) {
      debugPrint('Clear active draft error: $e');
    }
  }

  Future<void> clearDraft() async {
    _currentAudit = null;
    _currentAnswers = [];
    _activeQuestions = [];
    _currentQuestionIndex = 0;
    _isLoadingDraft = false;
    await _clearActiveDraft();
    notifyListeners();
  }

  String? errorMessage;

  bool _isDemoAudit(AuditModel audit) {
    return RegExp(r'^AUD-20\d+$').hasMatch(audit.id);
  }

  Future<void> _loadHistory() async {
    // This is now handled by _initRealtimeSync
  }

  void startNewAudit({
    required String line,
    required String station,
    required String auditorId,
    required String auditorName,
    required String auditType,
    required List<QuestionModel> questions,
    AuditTypeModel? auditTypeConfig,
    String? taskId,
  }) {
    _activeQuestions = List.from(questions);
    _activeAuditType = auditTypeConfig ?? AuditTypeModel.stationInspection;
    _currentAnswers = _buildDefaultAnswers(_activeAuditType, _activeQuestions);
    int nextSeq = _auditHistory.length + 1;
    for (final a in _auditHistory) {
      if (a.auditNo != null && a.auditNo!.startsWith('D-')) {
        final numPart = int.tryParse(a.auditNo!.substring(2));
        if (numPart != null && numPart >= nextSeq) {
          nextSeq = numPart + 1;
        }
      }
    }
    final generatedAuditNo = 'D-${nextSeq.toString().padLeft(5, '0')}';
    _currentAudit = AuditModel(
      id: 'A-${DateTime.now().millisecondsSinceEpoch}',
      auditNo: generatedAuditNo,
      date: DateTime.now(),
      line: line,
      station: station,
      auditorId: auditorId,
      auditorName: auditorName,
      auditType: auditType,
      auditTypeId: _activeAuditType.id,
      startedAt: DateTime.now(),
    );
    _associatedTaskId = taskId;
    _currentQuestionIndex = 0;
    _saveActiveDraft();
    notifyListeners();
  }

  List<AuditAnswer> _buildDefaultAnswers(AuditTypeModel auditType, List<QuestionModel> questions) {
    return questions
        .map((question) => _defaultAnswerForQuestion(auditType: auditType, question: question))
        .whereType<AuditAnswer>()
        .toList();
  }

  AuditAnswer? _defaultAnswerForQuestion({
    required AuditTypeModel auditType,
    required QuestionModel question,
  }) {
    final snapshot = _questionSnapshot(question);
    final defaultValue = auditType.defaultAnswerValue;
    if (defaultValue == null) return null;

    switch (question.answerType) {
      case AnswerType.scale:
      case AnswerType.scale6:
        final score = _defaultNumericValue(defaultValue)?.round();
        if (score == null) return null;
        final answer = AuditAnswer(
          questionId: question.id,
          questionText: snapshot.questionText,
          categoryId: snapshot.categoryId,
          categoryName: snapshot.categoryName,
          orderIndex: snapshot.orderIndex,
          score: score,
          answerType: question.answerType,
          value: score,
          photos: const [],
        );
        return _withNonconformityState(auditType, question, answer);
      case AnswerType.boolean:
        final value = _defaultBooleanValue(defaultValue);
        if (value == null) return null;
        final answer = AuditAnswer(
          questionId: question.id,
          questionText: snapshot.questionText,
          categoryId: snapshot.categoryId,
          categoryName: snapshot.categoryName,
          orderIndex: snapshot.orderIndex,
          score: value ? 1 : 0,
          answerType: question.answerType,
          value: value,
          photos: const [],
        );
        return _withNonconformityState(auditType, question, answer);
      case AnswerType.multiChoice:
      case AnswerType.quiz:
        final score = _defaultNumericValue(defaultValue)?.round() ?? 0;
        final answer = AuditAnswer(
          questionId: question.id,
          questionText: snapshot.questionText,
          categoryId: snapshot.categoryId,
          categoryName: snapshot.categoryName,
          orderIndex: snapshot.orderIndex,
          score: score,
          answerType: question.answerType,
          value: defaultValue,
          isCorrect: score > 0 ? true : null,
          photos: const [],
        );
        return _withNonconformityState(auditType, question, answer);
      case AnswerType.text:
        return AuditAnswer(
          questionId: question.id,
          questionText: snapshot.questionText,
          categoryId: snapshot.categoryId,
          categoryName: snapshot.categoryName,
          orderIndex: snapshot.orderIndex,
          score: 0,
          answerType: question.answerType,
          value: defaultValue.toString(),
          photos: const [],
        );
    }
  }

  AuditAnswer _withNonconformityState(
    AuditTypeModel auditType,
    QuestionModel question,
    AuditAnswer answer,
  ) {
    final isNonconformity = AuditScoringService.isNonconformity(
      auditType: auditType,
      question: question,
      answer: answer,
    );
    return AuditAnswer(
      questionId: answer.questionId,
      questionText: answer.questionText ?? question.questionText,
      categoryId: answer.categoryId ?? question.groupId,
      categoryName: answer.categoryName ?? question.categoryName,
      orderIndex: answer.orderIndex ?? question.orderIndex,
      score: answer.score,
      comment: answer.comment,
      photoPaths: answer.allPhotoUrls,
      photos: answer.photos,
      isNonconformity: isNonconformity,
      answerType: answer.answerType,
      value: answer.value,
      weightedScore: answer.weightedScore,
      isCorrect: answer.isCorrect,
      isOutOfScope: answer.isOutOfScope,
    );
  }

  _QuestionSnapshot _questionSnapshot(QuestionModel question) {
    return _QuestionSnapshot(
      questionText: question.questionText,
      categoryId: question.groupId,
      categoryName: question.categoryName,
      orderIndex: question.orderIndex,
    );
  }

  double? _defaultNumericValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  bool? _defaultBooleanValue(dynamic value) {
    if (value is bool) return value;
    final normalized = value.toString().trim().toLowerCase();
    if (['true', 'yes', 'evet', '1'].contains(normalized)) return true;
    if (['false', 'no', 'hayır', 'hayir', '0'].contains(normalized)) return false;
    return null;
  }

  void nextQuestion() {
    if (_currentQuestionIndex < _activeQuestions.length - 1) {
      _currentQuestionIndex++;
      _saveActiveDraft();
      notifyListeners();
    }
  }

  void previousQuestion() {
    if (_currentQuestionIndex > 0) {
      _currentQuestionIndex--;
      _saveActiveDraft();
      notifyListeners();
    }
  }

  void saveAnswer(AuditAnswer answer) {
    QuestionModel? question;
    for (final item in _activeQuestions) {
      if (item.id == answer.questionId) {
        question = item;
        break;
      }
    }
    final enriched = question == null ? answer : _enrichAnswerWithQuestion(answer, question);
    int index = _currentAnswers.indexWhere((a) => a.questionId == answer.questionId);
    if (index != -1) {
      _currentAnswers[index] = enriched;
    } else {
      _currentAnswers.add(enriched);
    }
    _saveActiveDraft();
    notifyListeners();
  }

  AuditAnswer _enrichAnswerWithQuestion(AuditAnswer answer, QuestionModel question) {
    return AuditAnswer(
      questionId: answer.questionId,
      questionText: answer.questionText ?? question.questionText,
      categoryId: answer.categoryId ?? question.groupId,
      categoryName: answer.categoryName ?? question.categoryName,
      orderIndex: answer.orderIndex ?? question.orderIndex,
      score: answer.score,
      comment: answer.comment,
      additionalComments: answer.additionalComments,
      photoPaths: answer.allPhotoUrls,
      photos: answer.photos,
      isNonconformity: answer.isNonconformity,
      answerType: answer.answerType,
      value: answer.value,
      weightedScore: answer.weightedScore,
      isCorrect: answer.isCorrect,
      isOutOfScope: answer.isOutOfScope,
      additionalNonconformities: answer.additionalNonconformities,
    );
  }

  void addPhotosToAnswer(String questionId, List<String> paths) {
    if (paths.isEmpty) return;

    final existingIndex = _currentAnswers.indexWhere((a) => a.questionId == questionId);
    final existing = existingIndex == -1
        ? AuditAnswer(questionId: questionId, score: 0)
        : _currentAnswers[existingIndex];
    final newPhotos = paths
        .where((path) => path.isNotEmpty)
        .map((path) => AnswerPhoto(
              id: 'photo-${DateTime.now().microsecondsSinceEpoch}-${path.hashCode.abs()}',
              url: path,
            ))
        .toList();
    final existingPhotos = existing.photos.isNotEmpty
        ? existing.photos
        : existing.photoPaths
            .where((path) => path.isNotEmpty)
            .map((path) => AnswerPhoto(id: 'photo-${path.hashCode.abs()}', url: path))
            .toList();
    final updatedPhotos = [...existingPhotos, ...newPhotos];
    final updated = _copyAnswer(existing, photos: updatedPhotos);

    if (existingIndex == -1) {
      _currentAnswers.add(updated);
    } else {
      _currentAnswers[existingIndex] = updated;
    }
    _saveActiveDraft();
    notifyListeners();
  }

  void removePhotoFromAnswer(String questionId, String photoId) {
    final index = _currentAnswers.indexWhere((a) => a.questionId == questionId);
    if (index == -1) return;

    final answer = _currentAnswers[index];
    final existingPhotos = answer.photos.isNotEmpty
        ? answer.photos
        : answer.photoPaths
            .where((path) => path.isNotEmpty)
            .map((path) => AnswerPhoto(id: 'photo-${path.hashCode.abs()}', url: path))
            .toList();
    final updatedPhotos = existingPhotos.where((photo) => photo.id != photoId).toList();
    _currentAnswers[index] = _copyAnswer(answer, photos: updatedPhotos);
    _saveActiveDraft();
    notifyListeners();
  }

  AuditAnswer _copyAnswer(AuditAnswer answer, {List<AnswerPhoto>? photos, List<String>? additionalComments, List<AdditionalNonconformity>? additionalNonconformities}) {
    final nextPhotos = photos ??
        (answer.photos.isNotEmpty
            ? answer.photos
            : answer.photoPaths
                .where((path) => path.isNotEmpty)
                .map((path) => AnswerPhoto(id: 'photo-${path.hashCode.abs()}', url: path))
                .toList());
    return AuditAnswer(
      questionId: answer.questionId,
      questionText: answer.questionText,
      categoryId: answer.categoryId,
      categoryName: answer.categoryName,
      orderIndex: answer.orderIndex,
      score: answer.score,
      comment: answer.comment,
      additionalComments: additionalComments ?? List.from(answer.additionalComments),
      photoPaths: nextPhotos.map((p) => p.url).toList(),
      photos: nextPhotos,
      isNonconformity: answer.isNonconformity,
      answerType: answer.answerType,
      value: answer.value,
      weightedScore: answer.weightedScore,
      isCorrect: answer.isCorrect,
      isOutOfScope: answer.isOutOfScope,
      additionalNonconformities: additionalNonconformities ?? List.from(answer.additionalNonconformities),
    );
  }

  void addAdditionalNonconformityToAnswer(String questionId, String comment, String photoPath) {
    if (comment.trim().isEmpty || photoPath.trim().isEmpty) return;
    final index = _currentAnswers.indexWhere((a) => a.questionId == questionId);
    final newNc = AdditionalNonconformity(
      id: 'unc-${DateTime.now().microsecondsSinceEpoch}',
      photoUrl: photoPath.trim(),
      comment: comment.trim(),
    );
    if (index == -1) {
      final newAnswer = AuditAnswer(
        questionId: questionId,
        score: 0,
        additionalNonconformities: [newNc],
      );
      _currentAnswers.add(newAnswer);
    } else {
      final answer = _currentAnswers[index];
      final newNcs = List<AdditionalNonconformity>.from(answer.additionalNonconformities)..add(newNc);
      _currentAnswers[index] = _copyAnswer(answer, additionalNonconformities: newNcs);
    }
    _saveActiveDraft();
    notifyListeners();
  }

  void removeAdditionalNonconformity(String questionId, String ncId) {
    final index = _currentAnswers.indexWhere((a) => a.questionId == questionId);
    if (index == -1) return;
    final answer = _currentAnswers[index];
    final newNcs = answer.additionalNonconformities.where((n) => n.id != ncId).toList();
    _currentAnswers[index] = _copyAnswer(answer, additionalNonconformities: newNcs);
    _saveActiveDraft();
    notifyListeners();
  }

  void addAdditionalCommentToAnswer(String questionId, String comment) {
    if (comment.trim().isEmpty) return;
    final index = _currentAnswers.indexWhere((a) => a.questionId == questionId);
    if (index == -1) {
      final newAnswer = AuditAnswer(questionId: questionId, score: 0, additionalComments: [comment.trim()]);
      _currentAnswers.add(newAnswer);
    } else {
      final answer = _currentAnswers[index];
      final newComments = List<String>.from(answer.additionalComments)..add(comment.trim());
      _currentAnswers[index] = _copyAnswer(answer, additionalComments: newComments);
    }
    _saveActiveDraft();
    notifyListeners();
  }

  void updateAdditionalComment(String questionId, int commentIndex, String newComment) {
    if (newComment.trim().isEmpty) {
      removeAdditionalComment(questionId, commentIndex);
      return;
    }
    final index = _currentAnswers.indexWhere((a) => a.questionId == questionId);
    if (index == -1) return;
    
    final answer = _currentAnswers[index];
    if (commentIndex < 0 || commentIndex >= answer.additionalComments.length) return;
    
    final newComments = List<String>.from(answer.additionalComments);
    newComments[commentIndex] = newComment.trim();
    _currentAnswers[index] = _copyAnswer(answer, additionalComments: newComments);
    
    _saveActiveDraft();
    notifyListeners();
  }

  void removeAdditionalComment(String questionId, int commentIndex) {
    final index = _currentAnswers.indexWhere((a) => a.questionId == questionId);
    if (index == -1) return;
    
    final answer = _currentAnswers[index];
    if (commentIndex < 0 || commentIndex >= answer.additionalComments.length) return;
    
    final newComments = List<String>.from(answer.additionalComments)..removeAt(commentIndex);
    _currentAnswers[index] = _copyAnswer(answer, additionalComments: newComments);
    
    _saveActiveDraft();
    notifyListeners();
  }

  Future<AuditModel?> completeAudit(NonconformityProvider ncProvider) async {
    if (_currentAudit == null) return null;

    final double finalScore = AuditScoringService.calculate(
      auditType: _activeAuditType,
      questions: _activeQuestions,
      answers: _currentAnswers,
    );

    // Build the completed audit immediately with current photo paths (no network I/O).
    final completedAudit = _currentAudit!.copyWith(
      isCompleted: true,
      answers: List<AuditAnswer>.from(_currentAnswers),
      score: finalScore,
      completedAt: DateTime.now(),
    );

    // Kuyruğa ekle — fotoğraflar base64 olarak saklanır,
    // internet gelince PendingUploadService otomatik yükler.
    await PendingUploadService.enqueue(
      audit: completedAudit,
      answers: List<AuditAnswer>.from(_currentAnswers),
      questions: List<QuestionModel>.from(_activeQuestions),
      taskId: _associatedTaskId,
    );

    // Clear draft and update state so the UI can navigate instantly.
    _currentAudit = completedAudit;
    await _clearActiveDraft();
    notifyListeners();

    // Hemen bir sync denemesi yap (internet varsa anında yüklenir)
    _loadPendingAudits();
    PendingUploadService.processPendingUploads();

    return completedAudit;
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> deleteAudit(String id) async {
    try {
      await DatabaseHelper.instance.deleteAudit(id);
    } catch (_) {}
    _auditHistory.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  Future<void> restoreData(NonconformityProvider ncProvider) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('audits');
    await db.delete('nonconformities');
    
    await _loadHistory();
    await ncProvider.reload(); // ncProvider'da reload metodu eklemeliyim
  }

  Future<void> syncAllData(NonconformityProvider ncProvider) async {
    try {
      // Tüm verileri topla
      final allAudits = await DatabaseHelper.instance.getAudits();
      final allNCs = await ncProvider.getAllNonconformities(); // Provider'da bu metod var varsayıyorum
      
      // Kullanıcıları MockData'dan al (şimdilik)
      final allUsers = MockData.users;

      // Sync servisini çağır
      await SyncService.syncData(
        audits: allAudits,
        nonconformities: allNCs,
        users: allUsers,
      );
    } catch (e) {
      debugPrint('Full sync error: $e');
    }
  }
}

class _QuestionSnapshot {
  final String questionText;
  final String categoryId;
  final String categoryName;
  final int orderIndex;

  const _QuestionSnapshot({
    required this.questionText,
    required this.categoryId,
    required this.categoryName,
    required this.orderIndex,
  });
}
