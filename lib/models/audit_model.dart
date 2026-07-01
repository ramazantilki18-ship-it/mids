import 'audit_type_model.dart';

class AnswerPhoto {
  final String id;
  final String url;
  final DateTime createdAt;

  AnswerPhoto({
    required this.id,
    required this.url,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'url': url,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AnswerPhoto.fromMap(Map<String, dynamic> map) => AnswerPhoto(
        id: map['id']?.toString() ?? 'photo-${DateTime.now().microsecondsSinceEpoch}',
        url: map['url']?.toString() ?? map['path']?.toString() ?? '',
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

class AdditionalNonconformity {
  final String id;
  final String photoUrl;
  final String comment;

  AdditionalNonconformity({
    required this.id,
    required this.photoUrl,
    required this.comment,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'photoUrl': photoUrl,
        'comment': comment,
      };

  factory AdditionalNonconformity.fromMap(Map<String, dynamic> map) =>
      AdditionalNonconformity(
        id: map['id']?.toString() ?? 'unc-${DateTime.now().microsecondsSinceEpoch}',
        photoUrl: map['photoUrl']?.toString() ?? '',
        comment: map['comment']?.toString() ?? '',
      );
}

class AuditAnswer {
  final String questionId;
  final String? questionText;
  final String? categoryId;
  final String? categoryName;
  final int? orderIndex;
  final int score;
  final String? comment;
  final List<String> additionalComments;
  final List<String> photoPaths;
  final List<AnswerPhoto> photos;
  final bool isNonconformity;
  final AnswerType answerType;
  final dynamic value;
  final double? weightedScore;
  final bool? isCorrect;
  final bool isOutOfScope;
  final List<AdditionalNonconformity> additionalNonconformities;

  AuditAnswer({
    required this.questionId,
    this.questionText,
    this.categoryId,
    this.categoryName,
    this.orderIndex,
    required this.score,
    this.comment,
    this.additionalComments = const [],
    this.photoPaths = const [],
    List<AnswerPhoto>? photos,
    this.isNonconformity = false,
    this.answerType = AnswerType.scale,
    this.value,
    this.weightedScore,
    this.isCorrect,
    this.isOutOfScope = false,
    this.additionalNonconformities = const [],
  }) : photos = photos ?? _photosFromLegacyPaths(photoPaths);

  static List<AnswerPhoto> _photosFromLegacyPaths(List<String> paths) {
    return paths
        .where((path) => path.isNotEmpty)
        .map((path) => AnswerPhoto(id: 'photo-${path.hashCode.abs()}', url: path))
        .toList();
  }

  List<String> get allPhotoUrls {
    final urls = <String>{...photoPaths, ...photos.map((p) => p.url)};
    return urls.where((url) => url.isNotEmpty).toList();
  }

  double get numericScore {
    if (weightedScore != null) return weightedScore!;
    if (value is num) return (value as num).toDouble();
    if (value is bool) return value == true ? 1 : 0;
    return score.toDouble();
  }

  bool? get booleanValue => value is bool ? value as bool : null;

  double get normalizedScore {
    if (isOutOfScope) return 100.0;
    switch (answerType) {
      case AnswerType.scale:
      case AnswerType.scale6:
        final scoreVal = numericScore.round();
        if (scoreVal == 0) return 0.0;
        if (scoreVal == 1) return 25.0;
        if (scoreVal == 2) return 50.0;
        if (scoreVal == 3) return 80.0;
        if (scoreVal == 4) return 99.0;
        if (scoreVal == 5) return 100.0;
        return 0.0;
      case AnswerType.boolean:
        return booleanValue == false ? 0 : 100;
      case AnswerType.multiChoice:
      case AnswerType.quiz:
        return numericScore * 100;
      case AnswerType.text:
        return 0;
    }
  }

  Map<String, dynamic> toMap() => {
        'questionId': questionId,
        'questionText': questionText,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'orderIndex': orderIndex,
        'score': score,
        'comment': comment,
        'additionalComments': additionalComments,
        'photoPaths': allPhotoUrls,
        'photos': photos.map((p) => p.toMap()).toList(),
        'isNonconformity': isNonconformity,
        'answerType': answerType.name,
        'value': value ?? score,
        'weightedScore': weightedScore,
        'isCorrect': isCorrect,
        'isOutOfScope': isOutOfScope,
        'additionalNonconformities': additionalNonconformities.map((e) => e.toMap()).toList(),
      };

  factory AuditAnswer.fromMap(Map<String, dynamic> map) {
    final legacyPaths = List<String>.from(map['photoPaths'] ?? []);
    final storedPhotos = ((map['photos'] as List?) ?? [])
        .map((p) {
          if (p is String) {
            return AnswerPhoto(id: 'photo-${p.hashCode.abs()}', url: p);
          }
          if (p is Map) {
            return AnswerPhoto.fromMap(Map<String, dynamic>.from(p));
          }
          return null;
        })
        .whereType<AnswerPhoto>()
        .where((p) => p.url.isNotEmpty)
        .toList();
    final photosByUrl = <String, AnswerPhoto>{
      for (final photo in _photosFromLegacyPaths(legacyPaths)) photo.url: photo,
      for (final photo in storedPhotos) photo.url: photo,
    };
    final mergedPaths = photosByUrl.keys.where((url) => url.isNotEmpty).toList();
    final rawScore = map['score'] ?? map['value'] ?? 0;
    final score = rawScore is num ? rawScore.toInt() : (rawScore == true ? 1 : 0);

    final rawAddNCs = map['additionalNonconformities'] as List? ?? const [];
    final additionalNonconformities = rawAddNCs
        .map((e) => e is Map ? AdditionalNonconformity.fromMap(Map<String, dynamic>.from(e)) : null)
        .whereType<AdditionalNonconformity>()
        .toList();

    return AuditAnswer(
      questionId: map['questionId'] ?? '',
      questionText: map['questionText'] as String?,
      categoryId: map['categoryId'] as String?,
      categoryName: map['categoryName'] as String?,
      orderIndex: (map['orderIndex'] as num?)?.toInt(),
      score: score,
      comment: map['comment'] as String?,
      additionalComments: List<String>.from(map['additionalComments'] ?? []),
      photoPaths: mergedPaths,
      photos: photosByUrl.values.toList(),
      isNonconformity: map['isNonconformity'] ?? false,
      answerType: AnswerType.values.firstWhere(
        (e) => e.name.toLowerCase() == (map['answerType'] as String? ?? 'scale').toLowerCase(),
        orElse: () => AnswerType.scale,
      ),
      value: map['value'],
      weightedScore: (map['weightedScore'] as num?)?.toDouble(),
      isCorrect: map['isCorrect'] as bool?,
      isOutOfScope: map['isOutOfScope'] ?? false,
      additionalNonconformities: additionalNonconformities,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory AuditAnswer.fromJson(Map<String, dynamic> json) => AuditAnswer.fromMap(json);
}

class AuditModel {
  final String id;
  final DateTime date;
  final String line;
  final String station;
  final String auditorId;
  final String auditorName;
  final String auditType;
  final String auditTypeId;
  final bool isCompleted;
  final List<AuditAnswer> answers;
  final double score;
  final DateTime? startedAt;
  final DateTime? completedAt;

  AuditModel({
    required this.id,
    required this.date,
    required this.line,
    required this.station,
    required this.auditorId,
    required this.auditorName,
    required this.auditType,
    this.auditTypeId = AuditTypeModel.fiveSId,
    this.isCompleted = false,
    this.answers = const [],
    this.score = 0.0,
    this.startedAt,
    this.completedAt,
  });

  double get overallScore => score;
  int get totalQuestionCount => answers.length;
  int get nonconformityCount => answers.where((a) => a.isNonconformity).length;
  int get lowScoreCount => answers.where((a) => a.score <= 3).length;
  int get highScoreCount => answers.where((a) => a.score >= 4).length;

  AuditModel copyWith({
    String? id,
    DateTime? date,
    String? line,
    String? station,
    String? auditorId,
    String? auditorName,
    String? auditType,
    String? auditTypeId,
    bool? isCompleted,
    List<AuditAnswer>? answers,
    double? score,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return AuditModel(
      id: id ?? this.id,
      date: date ?? this.date,
      line: line ?? this.line,
      station: station ?? this.station,
      auditorId: auditorId ?? this.auditorId,
      auditorName: auditorName ?? this.auditorName,
      auditType: auditType ?? this.auditType,
      auditTypeId: auditTypeId ?? this.auditTypeId,
      isCompleted: isCompleted ?? this.isCompleted,
      answers: answers ?? this.answers,
      score: score ?? this.score,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'line': line,
        'station': station,
        'auditorId': auditorId,
        'auditorName': auditorName,
        'auditType': auditType,
        'auditTypeId': auditTypeId,
        'isCompleted': isCompleted,
        'score': score,
        'answers': answers.map((x) => x.toMap()).toList(),
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory AuditModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final answers = List<AuditAnswer>.from(
      (map['answers'] ?? []).map((x) => AuditAnswer.fromMap(Map<String, dynamic>.from(x))),
    );
    final rawScore = map['score'] ?? 0.0;
    final storedScore = rawScore is num ? rawScore.toDouble() : double.tryParse(rawScore.toString()) ?? 0.0;

    return AuditModel(
      id: docId ?? map['id'] ?? '',
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      line: map['line'] ?? '',
      station: map['station'] ?? '',
      auditorId: map['auditorId'] ?? '',
      auditorName: map['auditorName'] ?? '',
      auditType: map['auditType'] ?? 'Denetim Tipi',
      auditTypeId: map['auditTypeId']?.toString() ?? '',
      isCompleted: map['isCompleted'] ?? false,
      score: storedScore,
      answers: answers,
      startedAt: map['startedAt'] != null ? DateTime.tryParse(map['startedAt'].toString()) : null,
      completedAt: map['completedAt'] != null ? DateTime.tryParse(map['completedAt'].toString()) : null,
    );
  }
}
