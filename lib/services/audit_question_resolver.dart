import '../data/mock_data.dart';
import '../models/audit_model.dart';
import '../models/audit_type_model.dart';
import '../models/question_model.dart';

class ResolvedAuditAnswer {
  final AuditAnswer answer;
  final QuestionModel question;

  const ResolvedAuditAnswer({
    required this.answer,
    required this.question,
  });
}

class ResolvedAuditCategorySection {
  final String categoryName;
  final List<ResolvedAuditAnswer> items;

  const ResolvedAuditCategorySection({
    required this.categoryName,
    required this.items,
  });
}

class AuditQuestionResolver {
  static List<ResolvedAuditAnswer> resolveAnswers(AuditModel audit) {
    return audit.answers.map((answer) => resolveAnswer(audit, answer)).toList();
  }

  static ResolvedAuditAnswer resolveAnswer(AuditModel audit, AuditAnswer answer) {
    final snapshotQuestion = _fromAnswerSnapshot(audit, answer);
    if (snapshotQuestion != null) {
      return ResolvedAuditAnswer(answer: answer, question: snapshotQuestion);
    }

    final question = _findKnownQuestion(audit, answer.questionId) ?? _fallbackQuestion(audit, answer);
    return ResolvedAuditAnswer(answer: answer, question: question);
  }

  static List<ResolvedAuditCategorySection> groupByCategory(AuditModel audit) {
    final sections = <String, List<ResolvedAuditAnswer>>{};
    for (final item in resolveAnswers(audit)) {
      final category = item.question.categoryName.isNotEmpty ? item.question.categoryName : 'Genel';
      sections.putIfAbsent(category, () => []).add(item);
    }

    return sections.entries
        .map((entry) => ResolvedAuditCategorySection(categoryName: entry.key, items: entry.value))
        .toList();
  }

  static QuestionModel? _fromAnswerSnapshot(AuditModel audit, AuditAnswer answer) {
    final questionText = answer.questionText;
    final categoryName = answer.categoryName;
    if (questionText == null || questionText.isEmpty || categoryName == null || categoryName.isEmpty) {
      return null;
    }

    return QuestionModel(
      id: answer.questionId,
      auditTypeId: audit.auditTypeId.isNotEmpty ? audit.auditTypeId : AuditTypeModel.fiveSId,
      groupId: answer.categoryId ?? categoryName,
      categoryName: categoryName,
      questionText: questionText,
      orderIndex: answer.orderIndex ?? 0,
      answerType: answer.answerType,
    );
  }

  static QuestionModel? _findKnownQuestion(AuditModel audit, String questionId) {
    QuestionModel? byAuditType;
    QuestionModel? byId;

    for (final question in MockData.questions) {
      if (question.id != questionId) continue;
      byId ??= question;
      if (audit.auditTypeId.isNotEmpty && question.auditTypeId == audit.auditTypeId) {
        byAuditType = question;
        break;
      }
    }

    return byAuditType ?? byId;
  }

  static QuestionModel _fallbackQuestion(AuditModel audit, AuditAnswer answer) {
    return QuestionModel(
      id: answer.questionId,
      auditTypeId: audit.auditTypeId.isNotEmpty ? audit.auditTypeId : AuditTypeModel.fiveSId,
      groupId: answer.categoryId ?? 'unknown-category',
      categoryName: answer.categoryName ?? 'Genel',
      questionText: answer.questionText ?? 'Soru ${answer.questionId}',
      orderIndex: answer.orderIndex ?? audit.answers.indexWhere((a) => a.questionId == answer.questionId),
      answerType: answer.answerType,
    );
  }
}
