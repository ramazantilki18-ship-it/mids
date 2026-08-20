import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/system_provider.dart';

class FieldTrackingService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isTracking = false;
  String? _currentSessionId;
  String? _currentStationName;
  DateTime? _currentStationEntryTime;
  String? _lastStationName;
  DateTime? _lastStationExitTime;
  
  List<Map<String, dynamic>> _gpsTrail = [];
  List<Map<String, dynamic>> _visits = [];
  List<Map<String, dynamic>> _travels = [];
  
  int _lastUploadedVisitsCount = 0;
  int _lastUploadedTravelsCount = 0;

  // Getters
  bool get isTracking => _isTracking;
  String? get currentSessionId => _currentSessionId;
  String? get currentStationName => _currentStationName;
  DateTime? get currentStationEntryTime => _currentStationEntryTime;
  List<Map<String, dynamic>> get gpsTrail => _gpsTrail;
  List<Map<String, dynamic>> get visits => _visits;
  List<Map<String, dynamic>> get travels => _travels;

  /// Saha seansını başlatır (Sürekli arka plan GPS akışı çalıştırmaz, şarj ve konum takılmasını önler)
  Future<bool> startSession({
    required String userId,
    required String userName,
    required String userTitle,
    required String shiftCode,
    required SystemProvider systemProvider,
  }) async {
    if (_isTracking) return false;

    // Konum servislerini ve izinlerini kontrol et
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _currentSessionId = '${userId}_${now.millisecondsSinceEpoch}';

    _gpsTrail = [];
    _visits = [];
    _travels = [];
    _currentStationName = null;
    _currentStationEntryTime = null;
    _lastStationName = null;
    _lastStationExitTime = null;
    _lastUploadedVisitsCount = 0;
    _lastUploadedTravelsCount = 0;

    try {
      // 1. Firestore seans kaydı oluştur
      await _firestore.collection('field_sessions').doc(_currentSessionId).set({
        'userId': userId,
        'userName': userName,
        'userTitle': userTitle,
        'line': 'Tümü',
        'date': Timestamp.fromDate(today),
        'startTime': Timestamp.fromDate(now),
        'endTime': null,
        'totalDuration': 0,
        'shiftCode': shiftCode,
        'status': 'active',
        'gpsTrail': [],
        'visits': [],
        'travels': [],
      });

      _isTracking = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Saha takibi başlatılamadı: $e');
      _isTracking = false;
      _currentSessionId = null;
      notifyListeners();
      return false;
    }
  }

  /// Anlık konum doğrulaması ile istasyona giriş yapma
  Future<Map<String, dynamic>> checkInStation({
    required String stationName,
    required SystemProvider systemProvider,
    String? lineName,
  }) async {
    if (!_isTracking || _currentSessionId == null) {
      return {'success': false, 'message': 'Aktif bir saha seansı bulunamadı.'};
    }

    // 1. Cihazın anlık GPS konumunu al (Tek seferlik okuma)
    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          position = lastKnown;
        } else {
          return {
            'success': false,
            'message': 'Anlık konumunuz alınamadı. Lütfen telefonunuzun GPS alıcısını ve konum izinlerini kontrol edin.'
          };
        }
      } catch (_) {
        return {
          'success': false,
          'message': 'Anlık konumunuz alınamadı. Lütfen telefonunuzun GPS alıcısını ve konum izinlerini kontrol edin.'
        };
      }
    }

    // 2. İstasyonun enlem, boylam ve yarıçapını bul
    double? targetLat;
    double? targetLng;
    double radius = 250.0;

    final locations = systemProvider.stationLocations;
    
    // Hat bilgisi varsa direkt "Line_Station" formatını dene
    if (lineName != null && lineName.isNotEmpty) {
      final locKey = '${lineName}_$stationName';
      if (locations.containsKey(locKey)) {
        final locData = locations[locKey];
        if (locData is Map) {
          targetLat = double.tryParse(locData['latitude']?.toString() ?? '');
          targetLng = double.tryParse(locData['longitude']?.toString() ?? '');
          radius = double.tryParse(locData['radius']?.toString() ?? '') ?? 250.0;
        }
      }
    }

    // Bulunamadıysa tüm konumlar içinde ara
    if (targetLat == null || targetLng == null) {
      for (final entry in locations.entries) {
        final key = entry.key; // e.g. "M1A_Zeytinburnu"
        final parts = key.split('_');
        final nameInKey = parts.length >= 2 ? parts.sublist(1).join('_') : key;

        if (nameInKey.toLowerCase() == stationName.toLowerCase() || key == stationName) {
          final locData = entry.value;
          if (locData is Map) {
            targetLat = double.tryParse(locData['latitude']?.toString() ?? '');
            targetLng = double.tryParse(locData['longitude']?.toString() ?? '');
            radius = double.tryParse(locData['radius']?.toString() ?? '') ?? 250.0;
          }
          if (targetLat != null && targetLng != null) break;
        }
      }
    }

    // Eğer veritabanında bu istasyona ait enlem/boylam tanımlanmamışsa konum kabul edilir
    if (targetLat == null || targetLng == null) {
      return await _performCheckIn(stationName, position.latitude, position.longitude);
    }

    // 3. Kullanıcı konumu ile hedef istasyon arasındaki mesafeyi hesapla
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      targetLat,
      targetLng,
    );

    // 4. Mesafe kontrolü
    if (distance > radius) {
      return {
        'success': false,
        'message': '"$stationName" istasyonunun konum kapsama alanında değilsiniz.\n\nSizin İstasyona Uzaklığınız: ${distance.round()} metre\nİzin Verilen Yarıçap Sınırı: ${radius.round()} metre',
        'distance': distance,
        'radius': radius,
      };
    }

    // 5. Konum doğrulandı: Giriş Başarılı!
    return await _performCheckIn(stationName, position.latitude, position.longitude);
  }

  /// İç metod: İstasyon girişini uygular (Anti-Suistimal: Maks 45 dk Otomatik Çıkış Sınırı dahil)
  Future<Map<String, dynamic>> _performCheckIn(String stationName, double lat, double lng) async {
    final now = DateTime.now();

    // OTOMATİK ÇIKIŞ VE SUİSTİMAL ÖNLEME KURALI:
    // Kullanıcı önceki istasyondan çıkış yapmayı unuttuysa ve yeni bir istasyona giriş yaptıysa:
    // 1. Önceki istasyonda kalınan ham süre hesaplanır.
    // 2. Maksimum kalış süresi 45 DAKİKA ile sınırlandırılır (Suistimal engeli!).
    // 3. Kayda "autoClosed: true" ve "autoCloseReason: Çıkış Unutuldu (Maks 45dk)" bayrağı konulur.
    if (_currentStationName != null && _currentStationName != stationName) {
      final rawDuration = now.difference(_currentStationEntryTime!).inMinutes;
      final bool isCapped = rawDuration > 45;
      final int visitDuration = isCapped ? 45 : (rawDuration > 0 ? rawDuration : 1);
      final DateTime exitTime = isCapped ? _currentStationEntryTime!.add(const Duration(minutes: 45)) : now;

      _visits.add({
        'stationId': 'ST_${_visits.length}',
        'stationName': _currentStationName,
        'entryTime': Timestamp.fromDate(_currentStationEntryTime!),
        'exitTime': Timestamp.fromDate(exitTime),
        'duration': visitDuration,
        'autoClosed': true,
        'autoCloseReason': isCapped ? 'Çıkış Unutuldu (Maks 45dk Sınırı Uygulandı)' : 'Yeni İstasyona Geçiş Yapıldı',
        'flagged': isCapped,
      });

      _travels.add({
        'fromStation': _currentStationName,
        'toStation': stationName,
        'startTime': Timestamp.fromDate(exitTime),
        'endTime': Timestamp.fromDate(now),
        'duration': now.difference(exitTime).inMinutes > 0 ? now.difference(exitTime).inMinutes : 1,
      });
    }

    _currentStationName = stationName;
    _currentStationEntryTime = now;

    _gpsTrail.add({
      'lat': lat,
      'lng': lng,
      'stationName': stationName,
      'timestamp': Timestamp.fromDate(now),
    });

    await _uploadCurrentSessionData();
    notifyListeners();

    return {
      'success': true,
      'message': '"$stationName" istasyonuna girişiniz konum doğrulamasıyla başarıyla kaydedildi.',
    };
  }

  /// Konum Doğrulamalı Manuel Çıkış Yapma (Suistimal Önleme: Konum Kontrolü + Maks 45dk Koruması)
  Future<Map<String, dynamic>> checkOutStation({
    required SystemProvider systemProvider,
    String? lineName,
  }) async {
    if (!_isTracking || _currentStationName == null || _currentStationEntryTime == null) {
      return {'success': false, 'message': 'Çıkış yapılacak aktif bir istasyon bulunmuyor.'};
    }

    // 1. Cihazın anlık GPS konumunu al
    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          position = lastKnown;
        } else {
          return {
            'success': false,
            'message': 'Çıkış doğrulama konumu alınamadı. Lütfen GPS alıcınızı kontrol edin.'
          };
        }
      } catch (_) {
        return {
          'success': false,
          'message': 'Çıkış doğrulama konumu alınamadı. Lütfen GPS alıcınızı kontrol edin.'
        };
      }
    }

    // 2. İstasyonun enlem/boylamını bul
    double? targetLat;
    double? targetLng;
    double radius = 250.0;

    final locations = systemProvider.stationLocations;
    if (lineName != null && lineName.isNotEmpty) {
      final locKey = '${lineName}_$_currentStationName';
      if (locations.containsKey(locKey)) {
        final locData = locations[locKey];
        if (locData is Map) {
          targetLat = double.tryParse(locData['latitude']?.toString() ?? '');
          targetLng = double.tryParse(locData['longitude']?.toString() ?? '');
          radius = double.tryParse(locData['radius']?.toString() ?? '') ?? 250.0;
        }
      }
    }

    if (targetLat == null || targetLng == null) {
      for (final entry in locations.entries) {
        final key = entry.key;
        final parts = key.split('_');
        final nameInKey = parts.length >= 2 ? parts.sublist(1).join('_') : key;

        if (nameInKey.toLowerCase() == _currentStationName!.toLowerCase() || key == _currentStationName) {
          final locData = entry.value;
          if (locData is Map) {
            targetLat = double.tryParse(locData['latitude']?.toString() ?? '');
            targetLng = double.tryParse(locData['longitude']?.toString() ?? '');
            radius = double.tryParse(locData['radius']?.toString() ?? '') ?? 250.0;
          }
          if (targetLat != null && targetLng != null) break;
        }
      }
    }

    // Koordinat tanımlıysa mesafe kontrolü yap
    if (targetLat != null && targetLng != null) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        targetLat,
        targetLng,
      );

      if (distance > radius) {
        return {
          'success': false,
          'message': '"$_currentStationName" istasyonundan çıkış yapabilmek için istasyon sınırları (250m) içerisinde olmalısınız.\n\nMesafe: ${distance.round()} metre',
        };
      }
    }

    // 3. Konum doğrulandı: Çıkışı gerçekleştir
    final now = DateTime.now();
    final rawDuration = now.difference(_currentStationEntryTime!).inMinutes;
    final bool isCapped = rawDuration > 45;
    final int visitDuration = isCapped ? 45 : (rawDuration > 0 ? rawDuration : 1);
    final DateTime exitTime = isCapped ? _currentStationEntryTime!.add(const Duration(minutes: 45)) : now;

    _visits.add({
      'stationId': 'ST_${_visits.length}',
      'stationName': _currentStationName,
      'entryTime': Timestamp.fromDate(_currentStationEntryTime!),
      'exitTime': Timestamp.fromDate(exitTime),
      'duration': visitDuration,
      'autoClosed': false,
      'flagged': isCapped,
    });

    final String checkedOutStation = _currentStationName!;
    _lastStationName = checkedOutStation;
    _lastStationExitTime = exitTime;
    _currentStationName = null;
    _currentStationEntryTime = null;

    await _uploadCurrentSessionData();
    notifyListeners();

    return {
      'success': true,
      'message': '"$checkedOutStation" istasyonundan çıkışınız konum doğrulamasıyla kaydedildi.',
    };
  }

  /// Saha seansını tamamen bitirir
  Future<void> stopSession() async {
    if (!_isTracking || _currentSessionId == null) return;

    final now = DateTime.now();

    try {
      // Eğer şu an bir istasyonun içindeyse çıkışını 45 dk sınırı korumasıyla tamamla
      if (_currentStationName != null && _currentStationEntryTime != null) {
        final rawDuration = now.difference(_currentStationEntryTime!).inMinutes;
        final bool isCapped = rawDuration > 45;
        final int visitDuration = isCapped ? 45 : (rawDuration > 0 ? rawDuration : 1);
        final DateTime exitTime = isCapped ? _currentStationEntryTime!.add(const Duration(minutes: 45)) : now;

        _visits.add({
          'stationId': 'ST_${_visits.length}',
          'stationName': _currentStationName,
          'entryTime': Timestamp.fromDate(_currentStationEntryTime!),
          'exitTime': Timestamp.fromDate(exitTime),
          'duration': visitDuration,
          'autoClosed': true,
          'autoCloseReason': isCapped ? 'Saha Seansı Sonlandırıldı (Maks 45dk Uygulandı)' : 'Saha Seansı Sonlandırıldı',
          'flagged': isCapped,
        });
      }

      // Seans başlangıç saatini Firestore'dan al
      final doc = await _firestore.collection('field_sessions').doc(_currentSessionId).get();
      DateTime startTime = now;
      if (doc.exists && doc.data()?['startTime'] != null) {
        startTime = (doc.data()?['startTime'] as Timestamp).toDate();
      }

      final totalDuration = now.difference(startTime).inMinutes;

      // Firestore seans kaydını güncelle
      await _firestore.collection('field_sessions').doc(_currentSessionId).update({
        'endTime': Timestamp.fromDate(now),
        'totalDuration': totalDuration > 0 ? totalDuration : 1,
        'status': 'completed',
        'visits': _visits,
        'travels': _travels,
      });

    } catch (e) {
      debugPrint('Saha takibi durdurulurken hata: $e');
    } finally {
      _isTracking = false;
      _currentSessionId = null;
      _currentStationName = null;
      _currentStationEntryTime = null;
      _lastStationName = null;
      _lastStationExitTime = null;
      notifyListeners();
    }
  }

  /// Manuel olarak bir istasyon ziyaretini kaydeder (NFC vb.)
  void recordManualVisit(String stationName) {
    if (!_isTracking || _currentSessionId == null) return;

    final now = DateTime.now();

    final bool alreadyRecorded = _visits.any((v) => 
      v['stationName'] == stationName && 
      now.difference((v['exitTime'] as Timestamp).toDate()).inMinutes < 2
    );

    if (alreadyRecorded) return;

    if (_currentStationName != null && _currentStationName != stationName) {
      final rawDuration = now.difference(_currentStationEntryTime!).inMinutes;
      final int visitDuration = rawDuration > 45 ? 45 : (rawDuration > 0 ? rawDuration : 1);
      final DateTime exitTime = rawDuration > 45 ? _currentStationEntryTime!.add(const Duration(minutes: 45)) : now;

      _visits.add({
        'stationId': 'ST_${_visits.length}',
        'stationName': _currentStationName,
        'entryTime': Timestamp.fromDate(_currentStationEntryTime!),
        'exitTime': Timestamp.fromDate(exitTime),
        'duration': visitDuration,
      });
    }

    _visits.add({
      'stationId': 'ST_${_visits.length}',
      'stationName': stationName,
      'entryTime': Timestamp.fromDate(now.subtract(const Duration(minutes: 1))),
      'exitTime': Timestamp.fromDate(now),
      'duration': 1,
    });

    _currentStationName = null;
    _currentStationEntryTime = null;
    _lastStationName = stationName;
    _lastStationExitTime = now;

    _uploadCurrentSessionData();
    notifyListeners();
  }

  /// Firestore'daki seans verilerini günceller
  Future<void> _uploadCurrentSessionData() async {
    if (_currentSessionId == null) return;
    try {
      await _firestore.collection('field_sessions').doc(_currentSessionId).update({
        'gpsTrail': _gpsTrail,
        'visits': _visits,
        'travels': _travels,
      });
      _lastUploadedVisitsCount = _visits.length;
      _lastUploadedTravelsCount = _travels.length;
    } catch (e) {
      debugPrint('Firestore manuel güncelleme hatası: $e');
    }
  }
}
