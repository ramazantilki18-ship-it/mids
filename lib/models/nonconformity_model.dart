enum NonconformityStatus { open, inProgress, completed, overdue, waitingControl }

extension NonconformityStatusExtension on NonconformityStatus {
  String get displayName {
    switch (this) {
      case NonconformityStatus.open: return 'Açık';
      case NonconformityStatus.inProgress: return 'İşlemde';
      case NonconformityStatus.completed: return 'Tamamlandı';
      case NonconformityStatus.overdue: return 'Gecikmiş';
      case NonconformityStatus.waitingControl: return 'Kontrol Bekliyor';
    }
  }
}

class NonconformityModel {
  final String id;
  final String auditId;
  final String auditTypeId;
  final String auditType;
  final String questionId;
  final String questionText;
  final String category;
  final String station;
  final String line;
  final int score;
  final String auditorComment;
  final List<String> auditorPhotoPaths;
  final DateTime detectionDate;
  final String auditorName;
  final String responsiblePerson;
  final NonconformityStatus status;
  final String? closureComment;
  final List<String> closurePhotoPaths;
  final DateTime? closureDate;

  NonconformityModel({
    required this.id,
    required this.auditId,
    this.auditTypeId = '',
    this.auditType = '',
    required this.questionId,
    required this.questionText,
    required this.category,
    required this.station,
    required this.line,
    required this.score,
    required this.auditorComment,
    this.auditorPhotoPaths = const [],
    required this.detectionDate,
    required this.auditorName,
    required this.responsiblePerson,
    this.status = NonconformityStatus.open,
    this.closureComment,
    this.closurePhotoPaths = const [],
    this.closureDate,
  });

  // Ekranlardaki isimlendirmelerle uyumluluk için getterlar
  String get statusDisplayName => status.displayName;
  bool get isOpen => status == NonconformityStatus.open || status == NonconformityStatus.inProgress;
  bool get isClosed => status == NonconformityStatus.completed;

  NonconformityModel copyWith({
    NonconformityStatus? status,
    String? closureComment,
    List<String>? closurePhotoPaths,
    DateTime? closureDate,
    String? auditorName,
    String? responsiblePerson,
  }) {
    return NonconformityModel(
      id: id,
      auditId: auditId,
      auditTypeId: auditTypeId,
      auditType: auditType,
      questionId: questionId,
      questionText: questionText,
      category: category,
      station: station,
      line: line,
      score: score,
      auditorComment: auditorComment,
      auditorPhotoPaths: auditorPhotoPaths,
      detectionDate: detectionDate,
      auditorName: auditorName ?? this.auditorName,
      responsiblePerson: responsiblePerson ?? this.responsiblePerson,
      status: status ?? this.status,
      closureComment: closureComment ?? this.closureComment,
      closurePhotoPaths: closurePhotoPaths ?? this.closurePhotoPaths,
      closureDate: closureDate ?? this.closureDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'auditId': auditId,
      'auditTypeId': auditTypeId,
      'auditType': auditType,
      'questionId': questionId,
      'questionText': questionText,
      'category': category,
      'station': station,
      'line': line,
      'score': score,
      'auditorComment': auditorComment,
      'auditorPhotoPaths': auditorPhotoPaths,
      'detectionDate': detectionDate.toIso8601String(),
      'auditorName': auditorName,
      'responsiblePerson': responsiblePerson,
      'status': status.name,
      'closureComment': closureComment,
      'closurePhotoPaths': closurePhotoPaths,
      'closureDate': closureDate?.toIso8601String(),
    };
  }

  factory NonconformityModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final status = _parseStatus(map['status']);
    final rawScore = map['score'] ?? 0;
    final score = rawScore is num ? rawScore.toInt() : int.tryParse(rawScore.toString()) ?? 0;
    return NonconformityModel(
      id: docId ?? map['id'] ?? '',
      auditId: map['auditId'] ?? '',
      auditTypeId: map['auditTypeId']?.toString() ?? '',
      auditType: map['auditType']?.toString() ?? '',
      questionId: map['questionId'] ?? '',
      questionText: map['questionText'] ?? '',
      category: map['category'] ?? '',
      station: map['station'] ?? '',
      line: map['line'] ?? '',
      score: score,
      auditorComment: map['auditorComment'] ?? '',
      auditorPhotoPaths: List<String>.from(map['auditorPhotoPaths'] ?? []),
      detectionDate: DateTime.tryParse(map['detectionDate']?.toString() ?? '') ?? DateTime.now(),
      auditorName: map['auditorName'] ?? '',
      responsiblePerson: map['responsiblePerson'] ?? '',
      status: status,
      closureComment: map['closureComment'],
      closurePhotoPaths: List<String>.from(map['closurePhotoPaths'] ?? []),
      closureDate: map['closureDate'] != null ? DateTime.tryParse(map['closureDate'].toString()) : null,
    );
  }

  static NonconformityStatus _parseStatus(dynamic rawStatus) {
    final value = rawStatus?.toString().trim().toLowerCase() ?? '';
    switch (value) {
      case 'completed':
      case 'complete':
      case 'closed':
      case 'close':
      case 'kapali':
      case 'kapalı':
      case 'tamamlandi':
      case 'tamamlandı':
        return NonconformityStatus.completed;
      case 'waitingcontrol':
      case 'waiting_control':
      case 'waiting-control':
      case 'kontrol':
      case 'kontrol bekliyor':
        return NonconformityStatus.waitingControl;
      case 'overdue':
      case 'gecikmis':
      case 'gecikmiş':
        return NonconformityStatus.overdue;
      case 'inprogress':
      case 'in_progress':
      case 'in-progress':
      case 'islemde':
      case 'işlemde':
        return NonconformityStatus.inProgress;
      case 'open':
      case 'acik':
      case 'açık':
        return NonconformityStatus.open;
      default:
        return NonconformityStatus.completed;
    }
  }
}
