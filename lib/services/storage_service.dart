import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class StorageService {
  static const String cloudName = 'dpk2rnnfn';
  static const String uploadPreset = 'denetimuygulaması';
  static const String _uploadEndpoint =
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
  static const String _deliveryBase =
      'https://res.cloudinary.com/$cloudName/image/upload/';
  static const String _optimizedTransform = 'f_auto,q_auto,c_limit,w_1024,h_1024';
  static const String _thumbnailTransform = 'f_auto,q_auto,c_fill,w_320,h_240';

  static String? imageUrlForPath(String path) {
    if (path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('data:')) {
      return optimizedImageUrl(path);
    }
    return null;
  }

  static String optimizedImageUrl(String url, {bool thumbnail = false}) {
    final transform = thumbnail ? _thumbnailTransform : _optimizedTransform;
    if (!url.contains(_deliveryBase) || url.contains('/$transform/')) {
      return url;
    }
    return url.replaceFirst(_deliveryBase, '$_deliveryBase$transform/');
  }

  static Future<List<String>> uploadPhotoPaths({
    required List<String> paths,
    required String auditId,
    required String questionId,
  }) async {
    if (paths.isEmpty) return [];

    final uploaded = <String>[];
    for (var i = 0; i < paths.length; i++) {
      final url = await uploadPhotoPath(
        path: paths[i],
        auditId: auditId,
        questionId: questionId,
        index: i,
      );
      if (url != null && url.isNotEmpty) {
        uploaded.add(url);
      }
    }
    return uploaded;
  }

  static Future<String?> uploadPhotoPath({
    required String path,
    required String auditId,
    required String questionId,
    required int index,
  }) async {
    if (path.isEmpty) return null;

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (path.startsWith('assets/') || path.startsWith('mock_')) {
      return path;
    }

    try {
      final bytes = await _readImageBytes(path);
      if (bytes == null || bytes.isEmpty) return null;

      final fileName = _buildFileName(path, index);
      final request = http.MultipartRequest('POST', Uri.parse(_uploadEndpoint))
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'audits/$auditId/answers/$questionId'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ));

      final streamed = await request.send().timeout(const Duration(seconds: 20), onTimeout: () {
        throw Exception('Cloudinary upload timed out');
      });
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('StorageService: Cloudinary upload failed ${response.statusCode}: ${response.body}');
        return null;
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final secureUrl = payload['secure_url'] as String?;
      if (secureUrl == null || secureUrl.isEmpty) return null;

      final optimizedUrl = optimizedImageUrl(secureUrl);
      debugPrint('StorageService: uploaded -> $optimizedUrl');
      return optimizedUrl;
    } catch (e, stack) {
      debugPrint('StorageService: upload failed for $path: $e\n$stack');
      return null;
    }
  }

  static Future<String?> uploadFeedbackPhoto({
    required String path,
    required String reporterId,
  }) async {
    if (path.isEmpty) return null;

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    try {
      final bytes = await _readImageBytes(path);
      if (bytes == null || bytes.isEmpty) return null;

      final fileName = _buildFileName(path, 0);
      final request = http.MultipartRequest('POST', Uri.parse(_uploadEndpoint))
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'feedbacks/$reporterId'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ));

      final streamed = await request.send().timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('StorageService: Feedback Cloudinary upload failed');
        return null;
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final secureUrl = payload['secure_url'] as String?;
      if (secureUrl == null || secureUrl.isEmpty) return null;

      return optimizedImageUrl(secureUrl);
    } catch (e) {
      debugPrint('StorageService: upload failed for $path: $e');
      return null;
    }
  }

  static Future<List<int>?> _readImageBytes(String path) async {
    if (path.startsWith('data:')) {
      final commaIndex = path.indexOf(',');
      if (commaIndex == -1) return null;
      return base64Decode(path.substring(commaIndex + 1));
    }

    if (kIsWeb && path.startsWith('blob:')) {
      final response = await http.get(Uri.parse(path));
      if (response.statusCode != 200) return null;
      return response.bodyBytes;
    }

    final normalized = path.startsWith('file://') ? path.replaceFirst('file://', '') : path;
    final file = File(normalized);
    if (!file.existsSync()) {
      debugPrint('StorageService: file not found $normalized');
      return null;
    }
    return file.readAsBytes();
  }

  static String _buildFileName(String path, int index) {
    final ext = p.extension(path);
    final safeExt = ext.isNotEmpty && ext.length <= 6 ? ext : '.jpg';
    return '${DateTime.now().millisecondsSinceEpoch}_$index$safeExt';
  }
}
