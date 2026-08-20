import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

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
  final String? ncNo;
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
  final String? closedByName;
  final String? approvedByName;

  NonconformityModel({
    required this.id,
    this.ncNo,
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
    this.closedByName,
    this.approvedByName,
  });

  // Ekranlardaki isimlendirmelerle uyumluluk için getterlar
  String get statusDisplayName => status.displayName;
  bool get isOpen => status == NonconformityStatus.open || status == NonconformityStatus.inProgress;
  bool get isClosed => status == NonconformityStatus.completed;

  NonconformityModel copyWith({
    String? ncNo,
    NonconformityStatus? status,
    String? closureComment,
    List<String>? closurePhotoPaths,
    DateTime? closureDate,
    String? auditorName,
    String? responsiblePerson,
    String? closedByName,
    String? approvedByName,
  }) {
    return NonconformityModel(
      id: id,
      ncNo: ncNo ?? this.ncNo,
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
      closedByName: closedByName ?? this.closedByName,
      approvedByName: approvedByName ?? this.approvedByName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ncNo': ncNo,
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
      'closedByName': closedByName,
      'approvedByName': approvedByName,
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory NonconformityModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    try {
      final status = _parseStatus(map['status']);
      final rawScore = map['score'] ?? 0;
      final score = rawScore is num ? rawScore.toInt() : (int.tryParse(rawScore.toString()) ?? 0);

      final rawAuditorPhotos = map['auditorPhotoPaths'];
      final auditorPhotoPaths = rawAuditorPhotos is List
          ? rawAuditorPhotos.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList()
          : <String>[];

      final rawClosurePhotos = map['closurePhotoPaths'];
      final closurePhotoPaths = rawClosurePhotos is List
          ? rawClosurePhotos.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList()
          : <String>[];

      return NonconformityModel(
        id: docId ?? map['id']?.toString() ?? '',
        ncNo: map['ncNo']?.toString(),
        auditId: map['auditId']?.toString() ?? '',
        auditTypeId: map['auditTypeId']?.toString() ?? '',
        auditType: map['auditType']?.toString() ?? '',
        questionId: map['questionId']?.toString() ?? '',
        questionText: map['questionText']?.toString() ?? '',
        category: map['category']?.toString() ?? '',
        station: map['station']?.toString() ?? '',
        line: map['line']?.toString() ?? '',
        score: score,
        auditorComment: map['auditorComment']?.toString() ?? '',
        auditorPhotoPaths: auditorPhotoPaths,
        detectionDate: _parseDateTime(map['detectionDate']) ?? DateTime.now(),
        auditorName: map['auditorName']?.toString() ?? '',
        responsiblePerson: map['responsiblePerson']?.toString() ?? '',
        status: status,
        closureComment: map['closureComment']?.toString(),
        closurePhotoPaths: closurePhotoPaths,
        closureDate: _parseDateTime(map['closureDate']),
        closedByName: map['closedByName']?.toString(),
        approvedByName: map['approvedByName']?.toString(),
      );
    } catch (_) {
      return NonconformityModel(
        id: docId ?? map['id']?.toString() ?? '',
        auditId: map['auditId']?.toString() ?? '',
        questionId: '',
        questionText: '',
        category: '',
        station: '',
        line: '',
        score: 0,
        auditorComment: '',
        detectionDate: DateTime.now(),
        auditorName: '',
        responsiblePerson: '',
        status: NonconformityStatus.open,
      );
    }
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
