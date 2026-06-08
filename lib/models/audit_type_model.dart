enum AnswerType { scale, boolean, multiChoice, text, quiz }

enum ScoringStrategy { scaleAverage, booleanAverage, booleanPenalty, mixedWeighted, quizAccuracy, none }

bool _readBool(dynamic value, {required bool fallback}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value.toString().trim().toLowerCase();
  if (['true', '1', 'yes', 'evet', 'active', 'aktif'].contains(normalized)) return true;
  if (['false', '0', 'no', 'hayir', 'hayır', 'inactive', 'pasif', 'deleted', 'silindi'].contains(normalized)) {
    return false;
  }
  return fallback;
}

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _readEvidenceAnswerValue(dynamic value) {
  if (value is bool) return value ? 'true' : 'false';
  if (value is num) return value.round().toString();
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  if (['true', 'yes', 'evet'].contains(normalized)) return 'true';
  if (['false', 'no', 'hayir', 'hayÄ±r'].contains(normalized)) return 'false';
  final numeric = num.tryParse(normalized.replaceAll(',', '.'));
  if (numeric != null) return numeric.round().toString();
  return normalized;
}

List<String> _readEvidenceAnswerValues(dynamic value) {
  if (value is List) {
    return value.map(_readEvidenceAnswerValue).where((item) => item.isNotEmpty).toSet().toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    return value.split(',').map(_readEvidenceAnswerValue).where((item) => item.isNotEmpty).toSet().toList();
  }
  return const [];
}

class AuditQuestionDefinition {
  final String id;
  final String text;
  final String type;
  final int orderIndex;
  final bool isActive;
  final bool isDeleted;

  const AuditQuestionDefinition({
    required this.id,
    required this.text,
    required this.type,
    this.orderIndex = 0,
    this.isActive = true,
    this.isDeleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'questionText': text,
        'type': type,
        'answerType': type == 'yes-no' ? 'boolean' : 'scale',
        'orderIndex': orderIndex,
        'isActive': isActive,
        'isDeleted': isDeleted,
      };

  factory AuditQuestionDefinition.fromJson(Map<String, dynamic> json) {
    final answerType = json['answerType'] as String?;
    return AuditQuestionDefinition(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? json['questionText'] as String? ?? json['title'] as String? ?? '',
      type: json['type'] as String? ?? (answerType == 'boolean' ? 'yes-no' : '5s-score'),
      orderIndex: _readInt(json['orderIndex']),
      isActive: _readBool(json['isActive'] ?? json['active'] ?? json['status'], fallback: true),
      isDeleted: _readBool(json['isDeleted'] ?? json['deleted'], fallback: false),
    );
  }
}

class AuditCategoryModel {
  final String id;
  final String name;
  final int orderIndex;
  final bool isActive;
  final bool isDeleted;
  final List<AuditQuestionDefinition> questions;

  const AuditCategoryModel({
    required this.id,
    required this.name,
    this.orderIndex = 0,
    this.isActive = true,
    this.isDeleted = false,
    this.questions = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'title': name,
        'orderIndex': orderIndex,
        'isActive': isActive,
        'isDeleted': isDeleted,
        'questions': questions.map((q) => q.toJson()).toList(),
      };

  factory AuditCategoryModel.fromJson(Map<String, dynamic> json) {
    return AuditCategoryModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['title'] as String? ?? 'Kategori',
      orderIndex: _readInt(json['orderIndex']),
      isActive: _readBool(json['isActive'] ?? json['active'] ?? json['status'], fallback: true),
      isDeleted: _readBool(json['isDeleted'] ?? json['deleted'], fallback: false),
      questions: ((json['questions'] as List?) ?? [])
          .map((q) => AuditQuestionDefinition.fromJson(Map<String, dynamic>.from(q as Map)))
          .where((q) => !q.isDeleted)
          .toList(),
    );
  }
}

class AuditTypeModel {
  final String id;
  final String title;
  final String description;
  final dynamic defaultAnswerValue;
  final List<AuditCategoryModel> categories;
  final bool isActive;
  final bool isDeleted;
  final int orderIndex;
  final ScoringStrategy scoringStrategy;
  final List<AnswerType> allowedAnswerTypes;
  final Map<String, dynamic> config;
  final bool evidenceRequired;
  final String evidenceRule;
  final List<String> evidenceRequiredValues;
  final bool commentRequired;
  final List<String> commentRequiredValues;

  const AuditTypeModel({
    required this.id,
    required this.title,
    this.description = '',
    this.defaultAnswerValue = 5,
    this.categories = const [],
    this.isActive = true,
    this.isDeleted = false,
    this.orderIndex = 0,
    this.scoringStrategy = ScoringStrategy.scaleAverage,
    this.allowedAnswerTypes = const [AnswerType.scale],
    this.config = const {},
    this.evidenceRequired = true,
    this.evidenceRule = 'nonconformity',
    this.evidenceRequiredValues = const [],
    this.commentRequired = false,
    this.commentRequiredValues = const [],
  });

  static const fiveSId = 'audit-type-5s';
  static const stationInspectionId = 'audit-type-istasyon-denetimi';

  static const fiveS = AuditTypeModel(
    id: fiveSId,
    title: '5S Denetimi',
    description: 'Varsayılan ölçek bazlı genel denetim tipi.',
    defaultAnswerValue: 5,
    scoringStrategy: ScoringStrategy.scaleAverage,
    allowedAnswerTypes: [AnswerType.scale],
    evidenceRequired: true,
    evidenceRequiredValues: ['1', '2', '3'],
    commentRequired: true,
    commentRequiredValues: ['1', '2', '3'],
    config: {
      'scaleMin': 1,
      'scaleMax': 5,
      'nonconformityThreshold': 3,
    },
  );

  static const stationInspection = AuditTypeModel(
    id: stationInspectionId,
    title: 'İSTASYON DENETİMİ',
    description: 'Evet/Hayır cevaplı istasyon denetimi. Evet=1, Hayır=0.',
    defaultAnswerValue: true,
    scoringStrategy: ScoringStrategy.booleanAverage,
    allowedAnswerTypes: [AnswerType.boolean],
    evidenceRequired: true,
    evidenceRequiredValues: ['false'],
    commentRequired: true,
    commentRequiredValues: ['false'],
    config: {
      'yesScore': 1,
      'noScore': 0,
      'nonconformityValue': false,
    },
  );

  AuditTypeModel copyWith({
    String? id,
    String? title,
    String? description,
    dynamic defaultAnswerValue,
    List<AuditCategoryModel>? categories,
    bool? isActive,
    bool? isDeleted,
    int? orderIndex,
    ScoringStrategy? scoringStrategy,
    List<AnswerType>? allowedAnswerTypes,
    Map<String, dynamic>? config,
    bool? evidenceRequired,
    String? evidenceRule,
    List<String>? evidenceRequiredValues,
    bool? commentRequired,
    List<String>? commentRequiredValues,
  }) {
    return AuditTypeModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      defaultAnswerValue: defaultAnswerValue ?? this.defaultAnswerValue,
      categories: categories ?? this.categories,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      orderIndex: orderIndex ?? this.orderIndex,
      scoringStrategy: scoringStrategy ?? this.scoringStrategy,
      allowedAnswerTypes: allowedAnswerTypes ?? this.allowedAnswerTypes,
      config: config ?? this.config,
      evidenceRequired: evidenceRequired ?? this.evidenceRequired,
      evidenceRule: evidenceRule ?? this.evidenceRule,
      evidenceRequiredValues: evidenceRequiredValues ?? this.evidenceRequiredValues,
      commentRequired: commentRequired ?? this.commentRequired,
      commentRequiredValues: commentRequiredValues ?? this.commentRequiredValues,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'name': title,
        'description': description,
        'defaultAnswerValue': defaultAnswerValue,
        'categories': categories.map((c) => c.toJson()).toList(),
        'modelVersion': 2,
        'isActive': isActive,
        'isDeleted': isDeleted,
        'orderIndex': orderIndex,
        'scoringStrategy': scoringStrategy.name,
        'allowedAnswerTypes': allowedAnswerTypes.map((e) => e.name).toList(),
        'config': config,
        'evidenceRequired': evidenceRequired,
        'evidenceRule': evidenceRule,
        'evidenceRequiredValues': evidenceRequiredValues,
        'commentRequired': commentRequired,
        'commentRequiredValues': commentRequiredValues,
      };

  factory AuditTypeModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? AuditTypeModel.fiveSId;
    final title = json['title'] as String? ?? json['name'] as String? ?? 'Denetim Tipi';
    final isStationInspection = id == AuditTypeModel.stationInspectionId || title.toUpperCase() == 'İSTASYON DENETİMİ';
    final scoringStrategy = isStationInspection ? ScoringStrategy.booleanAverage : _parseScoringStrategy(json['scoringStrategy'] as String?);
    return AuditTypeModel(
      id: isStationInspection ? AuditTypeModel.stationInspectionId : id,
      title: title,
      description: json['description'] as String? ?? '',
      defaultAnswerValue: json.containsKey('defaultAnswerValue')
          ? json['defaultAnswerValue']
          : (isStationInspection ? true : 5),
      categories: ((json['categories'] as List?) ?? [])
          .map((c) => AuditCategoryModel.fromJson(Map<String, dynamic>.from(c as Map)))
          .where((c) => !c.isDeleted)
          .toList(),
      isActive: _readBool(json['isActive'] ?? json['active'] ?? json['status'], fallback: true),
      isDeleted: _readBool(json['isDeleted'] ?? json['deleted'], fallback: false),
      orderIndex: _readInt(json['orderIndex']),
      scoringStrategy: scoringStrategy,
      allowedAnswerTypes: isStationInspection ? [AnswerType.boolean] : ((json['allowedAnswerTypes'] as List?) ?? ['scale'])
          .map((e) => _parseAnswerType(e.toString()))
          .toList(),
      config: isStationInspection ? AuditTypeModel.stationInspection.config : Map<String, dynamic>.from(json['config'] as Map? ?? {}),
      evidenceRequired: _readBool(
        json['evidenceRequired'],
        fallback: isStationInspection ? true : scoringStrategy != ScoringStrategy.none,
      ),
      evidenceRule: json['evidenceRule'] as String? ?? 'nonconformity',
      evidenceRequiredValues: json['evidenceRequiredValues'] != null || json['evidenceValues'] != null || json['requiredEvidenceAnswers'] != null
          ? _readEvidenceAnswerValues(json['evidenceRequiredValues'] ?? json['evidenceValues'] ?? json['requiredEvidenceAnswers'])
          : (isStationInspection ? ['false'] : (id == AuditTypeModel.fiveSId ? ['1', '2', '3'] : [])),
      commentRequired: _readBool(
        json['commentRequired'],
        fallback: isStationInspection ? true : (id == AuditTypeModel.fiveSId),
      ),
      commentRequiredValues: json['commentRequiredValues'] != null
          ? _readEvidenceAnswerValues(json['commentRequiredValues'])
          : (isStationInspection ? ['false'] : (id == AuditTypeModel.fiveSId ? ['1', '2', '3'] : [])),
    );
  }

  static AnswerType _parseAnswerType(String value) {
    return AnswerType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AnswerType.scale,
    );
  }

  static ScoringStrategy _parseScoringStrategy(String? value) {
    return ScoringStrategy.values.firstWhere(
      (e) => e.name.toLowerCase() == (value ?? '').toLowerCase(),
      orElse: () => ScoringStrategy.scaleAverage,
    );
  }
}
