import '../models/audit_model.dart';
import '../models/audit_type_model.dart';
import '../models/question_model.dart';

class AuditScoringService {
  const AuditScoringService._();

  static double calculate({
    required AuditTypeModel auditType,
    required List<QuestionModel> questions,
    required List<AuditAnswer> answers,
  }) {
    switch (auditType.scoringStrategy) {
      case ScoringStrategy.scaleAverage:
        return _scaleAverage(auditType, answers);
      case ScoringStrategy.booleanAverage:
        return _booleanAverage(answers);
      case ScoringStrategy.booleanPenalty:
        return _booleanPenalty(auditType, answers);
      case ScoringStrategy.mixedWeighted:
        return _mixedWeighted(questions, answers);
      case ScoringStrategy.quizAccuracy:
        return _quizAccuracy(answers);
      case ScoringStrategy.none:
        return 0;
    }
  }

  static bool isNonconformity({
    required AuditTypeModel auditType,
    required QuestionModel question,
    required AuditAnswer answer,
  }) {
    if (answer.isOutOfScope) return false;
    final threshold = (question.scoringRule?['nonconformityThreshold'] ??
            auditType.config['nonconformityThreshold'])
        as num?;

    switch (question.answerType) {
      case AnswerType.scale:
      case AnswerType.scale6:
        return answer.numericScore <= (threshold?.toDouble() ?? 3);
      case AnswerType.boolean:
        return answer.booleanValue == false;
      case AnswerType.multiChoice:
      case AnswerType.quiz:
        return answer.numericScore < 1;
      case AnswerType.text:
        return false;
    }
  }

  static bool requiresEvidencePhoto({
    required AuditTypeModel auditType,
    required QuestionModel question,
    required AuditAnswer answer,
  }) {
    if (answer.isOutOfScope) return false;
    if (!auditType.evidenceRequired) return false;
    if (auditType.evidenceRule == 'none') return false;

    final selectedValues = auditType.evidenceRequiredValues.toSet();
    if (selectedValues.isNotEmpty) {
      final answerValue = _evidenceAnswerValue(question, answer);
      return answerValue != null && selectedValues.contains(answerValue);
    }

    if (auditType.evidenceRule == 'always') return true;
    return isNonconformity(
      auditType: auditType,
      question: question,
      answer: answer,
    );
  }

  static bool requiresComment({
    required AuditTypeModel auditType,
    required QuestionModel question,
    required AuditAnswer answer,
  }) {
    if (answer.isOutOfScope) return false;
    if (!auditType.commentRequired) return false;
    
    final selectedValues = auditType.commentRequiredValues.toSet();
    if (selectedValues.isNotEmpty) {
      final answerValue = _evidenceAnswerValue(question, answer);
      return answerValue != null && selectedValues.contains(answerValue);
    }

    return false; // For now, if no values selected, we don't force comment
  }

  static String? _evidenceAnswerValue(QuestionModel question, AuditAnswer answer) {
    switch (question.answerType) {
      case AnswerType.scale:
      case AnswerType.scale6:
        return answer.numericScore.round().toString();
      case AnswerType.boolean:
        final value = answer.booleanValue ?? (answer.score == 1 ? true : answer.score == 0 ? false : null);
        return value?.toString();
      case AnswerType.multiChoice:
      case AnswerType.quiz:
        return answer.value?.toString() ?? answer.score.toString();
      case AnswerType.text:
        return null;
    }
  }

  static double _scaleAverage(AuditTypeModel auditType, List<AuditAnswer> answers) {
    if (answers.isEmpty) return 0;
    
    final categoryMap = <String, List<AuditAnswer>>{};
    for (final answer in answers) {
      final catId = answer.categoryId ?? '';
      categoryMap.putIfAbsent(catId, () => []).add(answer);
    }
    
    double weightedTotal = 0;
    double totalWeight = 0;
    
    categoryMap.forEach((catId, catAnswers) {
      final activeAnswers = catAnswers.where((a) => a.isOutOfScope != true).toList();
      if (activeAnswers.isEmpty) return;
      
      final categoryTotal = activeAnswers.fold<double>(0, (sum, a) => sum + a.normalizedScore);
      final categoryAvg = categoryTotal / activeAnswers.length;
      
      final category = auditType.categories.firstWhere(
        (c) => c.id == catId || c.name == catId,
        orElse: () => AuditCategoryModel(id: catId, name: catId, weight: 1.0),
      );
      
      final weight = category.weight;
      weightedTotal += categoryAvg * weight;
      totalWeight += weight;
    });
    
    if (totalWeight == 0) return 100.0;
    return weightedTotal / totalWeight;
  }

  static double _booleanAverage(List<AuditAnswer> answers) {
    if (answers.isEmpty) return 0;
    final yesCount = answers.where((a) => a.booleanValue == true || a.score == 1).length;
    return (yesCount / answers.length) * 100;
  }

  static double _booleanPenalty(AuditTypeModel auditType, List<AuditAnswer> answers) {
    if (answers.isEmpty) return 0;
    final penalty = (auditType.config['noPenalty'] as num?)?.toDouble() ?? 10;
    final noCount = answers.where((a) => a.booleanValue == false).length;
    return (100 - (noCount * penalty)).clamp(0, 100).toDouble();
  }

  static double _mixedWeighted(List<QuestionModel> questions, List<AuditAnswer> answers) {
    if (answers.isEmpty) return 0;
    double weightedScore = 0;
    double totalWeight = 0;

    for (final answer in answers) {
      final question = questions.firstWhere(
        (q) => q.id == answer.questionId,
        orElse: () => QuestionModel(id: answer.questionId, groupId: '', categoryName: '', questionText: '', orderIndex: 0),
      );
      final weight = question.weight <= 0 ? 1.0 : question.weight;
      weightedScore += answer.normalizedScore * weight;
      totalWeight += weight;
    }

    return totalWeight == 0 ? 0 : weightedScore / totalWeight;
  }

  static double _quizAccuracy(List<AuditAnswer> answers) {
    if (answers.isEmpty) return 0;
    final correct = answers.where((a) => a.isCorrect == true || a.numericScore > 0).length;
    return (correct / answers.length) * 100;
  }
}
