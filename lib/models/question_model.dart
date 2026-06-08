import 'package:flutter/material.dart';

import 'audit_type_model.dart';

class QuestionGroupModel {
  final String id;
  final String auditTypeId;
  final String name;
  final IconData icon;
  final bool isActive;
  final bool isDeleted;
  final int orderIndex;

  QuestionGroupModel({
    required this.id,
    this.auditTypeId = AuditTypeModel.fiveSId,
    required this.name,
    required this.icon,
    this.isActive = true,
    this.isDeleted = false,
    this.orderIndex = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'auditTypeId': auditTypeId,
        'name': name,
        'title': name,
        'icon': _iconToString(icon),
        'isActive': isActive,
        'isDeleted': isDeleted,
        'orderIndex': orderIndex,
      };

  factory QuestionGroupModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final name = json['name'] as String? ?? json['title'] as String? ?? '';
    final auditTypeId = json['auditTypeId'] as String? ?? _inferAuditTypeId(id, name);

    return QuestionGroupModel(
      id: id,
      auditTypeId: auditTypeId,
      name: name,
      icon: _stringToIcon(json['icon'] as String?, auditTypeId),
      isActive: json['isActive'] as bool? ?? true,
      isDeleted: json['isDeleted'] as bool? ?? false,
      orderIndex: (json['orderIndex'] as num?)?.toInt() ?? 0,
    );
  }

  static String _inferAuditTypeId(String id, String name) {
    final key = '$id $name'.toLowerCase();
    if (key.contains('station') || key.contains('stasyon')) {
      return AuditTypeModel.stationInspectionId;
    }
    return AuditTypeModel.fiveSId;
  }

  static String _iconToString(IconData icon) {
    if (icon == Icons.folder_open) return 'fa-folder-open';
    if (icon == Icons.fact_check_rounded) return 'fa-clipboard-check';
    if (icon == Icons.construction) return 'fa-hard-hat';
    if (icon == Icons.local_fire_department) return 'fa-fire-extinguisher';
    if (icon == Icons.cleaning_services) return 'fa-broom';
    if (icon == Icons.build) return 'fa-tools';
    if (icon == Icons.shield) return 'fa-shield-alt';
    if (icon == Icons.eco) return 'fa-leaf';
    return 'fa-clipboard-check';
  }

  static IconData _stringToIcon(String? iconStr, [String? auditTypeId]) {
    switch (iconStr) {
      case 'fa-clipboard-check':
        return Icons.fact_check_rounded;
      case 'fa-hard-hat':
        return Icons.construction;
      case 'fa-fire-extinguisher':
        return Icons.local_fire_department;
      case 'fa-broom':
        return Icons.cleaning_services;
      case 'fa-tools':
        return Icons.build;
      case 'fa-shield-alt':
        return Icons.shield;
      case 'fa-leaf':
        return Icons.eco;
      case 'fa-folder-open':
        return Icons.folder_open;
      default:
        if (auditTypeId == AuditTypeModel.stationInspectionId) return Icons.domain_rounded;
        return Icons.fact_check_rounded;
    }
  }
}

class QuestionModel {
  final String id;
  final String auditTypeId;
  final String groupId;
  final String categoryName;
  final String questionText;
  final int orderIndex;
  final AnswerType answerType;
  final double weight;
  final String? scoringRuleId;
  final Map<String, dynamic>? scoringRule;
  final List<Map<String, dynamic>> options;
  final bool isActive;
  final bool isDeleted;

  QuestionModel({
    required this.id,
    this.auditTypeId = AuditTypeModel.fiveSId,
    required this.groupId,
    required this.categoryName,
    required this.questionText,
    required this.orderIndex,
    this.answerType = AnswerType.scale,
    this.weight = 1,
    this.scoringRuleId,
    this.scoringRule,
    this.options = const [],
    this.isActive = true,
    this.isDeleted = false,
  });

  QuestionModel copyWith({
    String? auditTypeId,
    AnswerType? answerType,
  }) =>
      QuestionModel(
        id: id,
        auditTypeId: auditTypeId ?? this.auditTypeId,
        groupId: groupId,
        categoryName: categoryName,
        questionText: questionText,
        orderIndex: orderIndex,
        answerType: answerType ?? this.answerType,
        weight: weight,
        scoringRuleId: scoringRuleId,
        scoringRule: scoringRule,
        options: options,
        isActive: isActive,
        isDeleted: isDeleted,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'auditTypeId': auditTypeId,
        'groupId': groupId,
        'categoryName': categoryName,
        'questionText': questionText,
        'title': questionText,
        'orderIndex': orderIndex,
        'answerType': answerType.name,
        'weight': weight,
        'scoringRuleId': scoringRuleId,
        'scoringRule': scoringRule,
        'options': options,
        'isActive': isActive,
        'isDeleted': isDeleted,
      };

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    final groupId = json['groupId'] as String? ?? 'g1';
    final categoryName = json['categoryName'] as String? ?? '';
    final questionText = json['questionText'] as String? ?? json['title'] as String? ?? '';
    final auditTypeId = json['auditTypeId'] as String? ??
        QuestionGroupModel._inferAuditTypeId(groupId, '');
    final isStationInspection = auditTypeId == AuditTypeModel.stationInspectionId;
    return QuestionModel(
      id: json['id'] as String? ?? '',
      auditTypeId: auditTypeId,
      groupId: groupId,
      categoryName: categoryName,
      questionText: questionText,
      orderIndex: (json['orderIndex'] as num?)?.toInt() ?? 0,
      answerType: isStationInspection ? AnswerType.boolean : AnswerType.values.firstWhere(
        (e) => e.name.toLowerCase() == (json['answerType'] as String? ?? 'scale').toLowerCase(),
        orElse: () => AnswerType.scale,
      ),
      weight: (json['weight'] as num?)?.toDouble() ?? 1,
      scoringRuleId: json['scoringRuleId'] as String?,
      scoringRule: json['scoringRule'] == null ? null : Map<String, dynamic>.from(json['scoringRule'] as Map),
      options: List<Map<String, dynamic>>.from((json['options'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map))),
      isActive: json['isActive'] as bool? ?? true,
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }
}
