import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_model.dart';

class AnnouncementModel {
  final String id;
  final String title;
  final String message;
  final List<String> targetLines;
  final DateTime startAt;
  final DateTime endAt;
  final bool isActive;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.message,
    required this.targetLines,
    required this.startAt,
    required this.endAt,
    this.isActive = true,
  });

  bool get isCurrentlyVisible {
    final now = DateTime.now();
    return isActive && !startAt.isAfter(now) && endAt.isAfter(now);
  }

  bool isVisibleForUser(UserModel user) {
    if (!isCurrentlyVisible) return false;
    if (targetLines.isEmpty || user.hasGlobalLineAccess) {
      return true;
    }

    return targetLines.any(user.canAccessLine);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'targetLines': targetLines,
      'startAt': startAt,
      'endAt': endAt,
      'isActive': isActive,
    };
  }

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Duyuru').toString(),
      message: (json['message'] ?? json['body'] ?? '').toString(),
      targetLines: _parseStringList(json['targetLines'] ?? json['lines']),
      startAt: (_parseDate(json['startAt'] ?? json['startDate']) ??
          DateTime.fromMillisecondsSinceEpoch(0)).toLocal(),
      endAt: (_parseDate(json['endAt'] ?? json['endDate']) ??
          DateTime.fromMillisecondsSinceEpoch(0)).toLocal(),
      isActive: json['isActive'] != false,
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toSet()
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();
    }
    return <String>[];
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
