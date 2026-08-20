import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';
import '../config/update_config.dart';

class UpdateInfo {
  final bool isAvailable;
  final String latestVersion;
  final String currentVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool isForce;

  UpdateInfo({
    required this.isAvailable,
    required this.latestVersion,
    required this.currentVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    this.isForce = false,
  });
}

class UpdateService {
  static final UpdateService instance = UpdateService._();
  UpdateService._();

  /// GitHub Releases API'yi sorgulayarak yeni bir güncelleme olup olmadığını denetler
  Future<UpdateInfo> checkForUpdate() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version; // Örn: 1.0.0
      
      final response = await http.get(Uri.parse(UpdateConfig.latestReleaseUrl)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) {
        throw Exception('GitHub Releases API hata kodu: ${response.statusCode}');
      }

      final Map<String, dynamic> releaseData = jsonDecode(response.body);
      final String latestTagName = releaseData['tag_name'] ?? '1.0.0';
      final String releaseNotes = releaseData['body'] ?? '';
      
      // Asset listesinde aradığımız APK'yı bulalım
      final List<dynamic> assets = releaseData['assets'] ?? [];
      String downloadUrl = '';
      
      for (var asset in assets) {
        if (asset['name'] == UpdateConfig.apkFileName) {
          downloadUrl = asset['browser_download_url'] ?? '';
          break;
        }
      }

      if (downloadUrl.isEmpty && assets.isNotEmpty) {
        // Eğer aradığımız mimari APK bulunamazsa ilk asset'i varsayılan alabiliriz
        downloadUrl = assets.first['browser_download_url'] ?? '';
      }

      final bool isAvailable = _isNewerVersion(currentVersion, latestTagName) && downloadUrl.isNotEmpty;
      final bool isForce = releaseNotes.toUpperCase().contains('[ZORUNLU]') ||
          releaseNotes.toUpperCase().contains('[MANDATORY]');

      return UpdateInfo(
        isAvailable: isAvailable,
        latestVersion: latestTagName,
        currentVersion: currentVersion,
        downloadUrl: downloadUrl,
        releaseNotes: releaseNotes,
        isForce: isForce,
      );
    } catch (e) {
      print('GÜNCELLEME KONTROL HATASI: $e');
      return UpdateInfo(
        isAvailable: false,
        latestVersion: '',
        currentVersion: '',
        downloadUrl: '',
        releaseNotes: 'Güncelleme kontrolü başarısız oldu.',
        isForce: false,
      );
    }
  }

  /// OTA Güncellemeyi (arka planda indirme ve kurmayı) başlatır
  Stream<OtaEvent> startOtaUpdate(String downloadUrl, {String? filename}) {
    return OtaUpdate().execute(
      downloadUrl,
      destinationFilename: filename ?? UpdateConfig.apkFileName,
    );
  }

  /// Versiyon karşılaştırma mantığı (SemVer uyumlu)
  bool _isNewerVersion(String current, String latest) {
    // Sürüm başındaki 'v' harfini temizle (örn: v1.0.1 -> 1.0.1)
    final cleanCurrent = current.startsWith('v') ? current.substring(1) : current;
    final cleanLatest = latest.startsWith('v') ? latest.substring(1) : latest;

    // Build number varsa ayır (1.0.0+1 -> 1.0.0)
    final currentSemVer = cleanCurrent.split('+')[0];
    final latestSemVer = cleanLatest.split('+')[0];

    final List<int> currentParts = currentSemVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final List<int> latestParts = latestSemVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (var i = 0; i < 3; i++) {
      final int cur = i < currentParts.length ? currentParts[i] : 0;
      final int lat = i < latestParts.length ? latestParts[i] : 0;

      if (lat > cur) return true;
      if (cur > lat) return false;
    }
    return false;
  }
}
