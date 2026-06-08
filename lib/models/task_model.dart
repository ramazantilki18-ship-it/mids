
class TaskModel {
  final String id;
  final String title;
  final String description;
  final String assignedTitle; // Hangi unvana atandığı
  final String? assignedUserId; // Spesifik bir kişiye atandıysa ID'si
  final String targetLine; // Hangi hatta atandığı
  final List<String> targetStations; // Hangi istasyonlara atandığı
  final DateTime startDate;
  final DateTime dueDate;
  final bool isCompleted;
  final String taskType; // Planlı Denetim / Plansız Denetim
  final String? auditTypeId; // Uygulanacak denetim tipi

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.assignedTitle,
    this.assignedUserId,
    required this.targetLine,
    required this.targetStations,
    required this.startDate,
    required this.dueDate,
    this.isCompleted = false,
    this.taskType = 'Planlı Denetim',
    this.auditTypeId,
  });

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? assignedTitle,
    String? assignedUserId,
    String? targetLine,
    List<String>? targetStations,
    DateTime? startDate,
    DateTime? dueDate,
    bool? isCompleted,
    String? taskType,
    String? auditTypeId,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedTitle: assignedTitle ?? this.assignedTitle,
      assignedUserId: assignedUserId ?? this.assignedUserId,
      targetLine: targetLine ?? this.targetLine,
      targetStations: targetStations ?? this.targetStations,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      taskType: taskType ?? this.taskType,
      auditTypeId: auditTypeId ?? this.auditTypeId,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'assignedTitle': assignedTitle,
      'assignedUserId': assignedUserId,
      'targetLine': targetLine,
      'targetStations': targetStations,
      'startDate': startDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'isCompleted': isCompleted,
      'taskType': taskType,
      'auditTypeId': auditTypeId,
    };
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Denetim',
      description: json['description'] as String? ?? '',
      assignedTitle: json['assignedTitle'] as String? ?? 'Saha Denetçisi',
      assignedUserId: json['assignedUserId'] as String?,
      targetLine: json['targetLine'] as String? ?? '',
      targetStations: (json['targetStations'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : DateTime.now(),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : DateTime.now().add(const Duration(days: 1)),
      isCompleted: json['isCompleted'] as bool? ?? false,
      taskType: json['taskType'] as String? ?? 'Planlı Denetim',
      auditTypeId: json['auditTypeId'] as String?,
    );
  }
}
