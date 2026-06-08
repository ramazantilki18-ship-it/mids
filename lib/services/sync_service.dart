import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/audit_model.dart';
import '../models/nonconformity_model.dart';
import '../models/user_model.dart';

class SyncService {
  static const String baseUrl = 'http://localhost:3000/api';

  static Future<bool> syncData({
    List<AuditModel>? audits,
    List<NonconformityModel>? nonconformities,
    List<UserModel>? users,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      
      if (audits != null) {
        body['audits'] = audits.map((a) => {
          'id': a.id,
          'line': a.line,
          'station': a.station,
          'date': a.date.toIso8601String(),
          'auditorName': a.auditorName,
          'score': a.score,
          'isCompleted': a.isCompleted,
        }).toList();
      }

      if (nonconformities != null) {
        body['nonconformities'] = nonconformities.map((nc) => {
          'id': nc.id,
          'auditId': nc.auditId,
          'questionText': nc.questionText,
          'category': nc.category,
          'status': nc.status.name,
          'detectionDate': nc.detectionDate.toIso8601String(),
        }).toList();
      }

      if (users != null) {
        body['users'] = users.map((u) => {
          'id': u.id,
          'username': u.username,
          'title': u.title,
          'role': u.role.name,
        }).toList();
      }

      final response = await http.post(
        Uri.parse('$baseUrl/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Sync error: $e');
      return false;
    }
  }
}
