import 'package:denetim_app/models/audit_model.dart';
import 'package:denetim_app/models/audit_type_model.dart';
import 'package:denetim_app/models/nonconformity_model.dart';
import 'package:denetim_app/utils/audit_type_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sharedQuestion = AuditQuestionDefinition(
    id: 'shared-question',
    text: 'Ortak kontrol sorusu',
    type: 'yes-no',
  );
  const sharedCategory = AuditCategoryModel(
    id: 'shared-category',
    name: 'ORTAK KATEGORI',
    questions: [sharedQuestion],
  );
  const stationType = AuditTypeModel(
    id: 'station-type',
    title: 'Istasyon Denetimi',
    categories: [sharedCategory],
  );
  const fieldType = AuditTypeModel(
    id: 'field-type',
    title: 'Saha Denetimi',
    categories: [sharedCategory],
  );

  final stationAudit = AuditModel(
    id: 'audit-1',
    date: DateTime(2026, 6, 8),
    line: 'M1',
    station: 'Yenikapi',
    auditorId: 'user-1',
    auditorName: 'Denetci',
    auditType: stationType.title,
    auditTypeId: stationType.id,
  );

  final stationNonconformity = NonconformityModel(
    id: 'nc-1',
    auditId: stationAudit.id,
    auditTypeId: stationType.id,
    auditType: stationType.title,
    questionId: sharedQuestion.id,
    questionText: sharedQuestion.text,
    category: sharedCategory.name,
    station: stationAudit.station,
    line: stationAudit.line,
    score: 0,
    auditorComment: 'Uygunsuz',
    detectionDate: DateTime(2026, 6, 8),
    auditorName: stationAudit.auditorName,
    responsiblePerson: 'Sorumlu',
  );

  test('explicit audit type id prevents cross-type audit matches', () {
    expect(AuditTypeMatcher.matchesAudit(stationAudit, stationType), isTrue);
    expect(AuditTypeMatcher.matchesAudit(stationAudit, fieldType), isFalse);
  });

  test('shared questions do not move a nonconformity to another type', () {
    expect(
      AuditTypeMatcher.matchesNonconformity(
        audit: stationAudit,
        nonconformity: stationNonconformity,
        type: stationType,
      ),
      isTrue,
    );
    expect(
      AuditTypeMatcher.matchesNonconformity(
        audit: stationAudit,
        nonconformity: stationNonconformity,
        type: fieldType,
      ),
      isFalse,
    );
  });

  test('question fallback remains available for records without a type', () {
    final legacyNonconformity = NonconformityModel(
      id: 'legacy-nc',
      auditId: 'missing-audit',
      questionId: sharedQuestion.id,
      questionText: sharedQuestion.text,
      category: sharedCategory.name,
      station: 'Yenikapi',
      line: 'M1',
      score: 0,
      auditorComment: 'Uygunsuz',
      detectionDate: DateTime(2026, 6, 8),
      auditorName: 'Denetci',
      responsiblePerson: 'Sorumlu',
    );

    expect(
      AuditTypeMatcher.matchesNonconformity(
        audit: null,
        nonconformity: legacyNonconformity,
        type: stationType,
      ),
      isTrue,
    );
  });
}
