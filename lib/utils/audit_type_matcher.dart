import '../models/audit_model.dart';
import '../models/audit_type_model.dart';
import '../models/nonconformity_model.dart';

class AuditTypeMatcher {
  const AuditTypeMatcher._();

  static bool matchesAudit(AuditModel audit, AuditTypeModel type) {
    final auditTypeId = audit.auditTypeId.trim();
    if (auditTypeId.isNotEmpty) {
      return auditTypeId == type.id;
    }

    return _matchesLegacyName(audit.auditType, type);
  }

  static bool matchesNonconformity({
    required AuditModel? audit,
    required NonconformityModel nonconformity,
    required AuditTypeModel type,
  }) {
    final parentTypeId = audit?.auditTypeId.trim() ?? '';
    if (parentTypeId.isNotEmpty) {
      return parentTypeId == type.id;
    }

    final nonconformityTypeId = nonconformity.auditTypeId.trim();
    if (nonconformityTypeId.isNotEmpty) {
      return nonconformityTypeId == type.id;
    }

    final parentTypeName = audit?.auditType.trim() ?? '';
    if (parentTypeName.isNotEmpty) {
      return _matchesLegacyName(parentTypeName, type);
    }

    final nonconformityTypeName = nonconformity.auditType.trim();
    if (nonconformityTypeName.isNotEmpty) {
      return _matchesLegacyName(nonconformityTypeName, type);
    }

    return _containsLegacyNonconformity(type, nonconformity);
  }

  static bool _matchesLegacyName(String value, AuditTypeModel type) {
    final normalizedValue = _normalize(value);
    if (normalizedValue.isEmpty) return false;
    return _typeAliases(type).contains(normalizedValue);
  }

  static Set<String> _typeAliases(AuditTypeModel type) {
    final titleWithoutAudit = type.title
        .replaceAll(RegExp(r'\bdenetimi\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bdenetim\b', caseSensitive: false), '');

    return <String>{
      type.id,
      type.title,
      titleWithoutAudit,
    }.map(_normalize).where((value) => value.isNotEmpty).toSet();
  }

  static bool _containsLegacyNonconformity(
    AuditTypeModel type,
    NonconformityModel nonconformity,
  ) {
    final questionId = _normalize(nonconformity.questionId);
    final questionText = _normalize(nonconformity.questionText);
    final categoryName = _normalize(nonconformity.category);

    for (final category
        in type.categories.where((item) => item.isActive && !item.isDeleted)) {
      if (categoryName.isNotEmpty &&
          _normalize(category.name) == categoryName) {
        return true;
      }

      for (final question in category.questions
          .where((item) => item.isActive && !item.isDeleted)) {
        if (questionId.isNotEmpty && _normalize(question.id) == questionId) {
          return true;
        }
        if (questionText.isNotEmpty &&
            _normalize(question.text) == questionText) {
          return true;
        }
      }
    }

    return false;
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('\u0131', 'i')
        .replaceAll('\u0130', 'i')
        .replaceAll('\u011f', 'g')
        .replaceAll('\u00fc', 'u')
        .replaceAll('\u015f', 's')
        .replaceAll('\u00f6', 'o')
        .replaceAll('\u00e7', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}
