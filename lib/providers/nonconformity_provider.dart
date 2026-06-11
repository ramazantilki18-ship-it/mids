import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/nonconformity_model.dart';
import '../data/mock_data.dart';
import '../services/storage_service.dart';
import '../services/audit_question_resolver.dart';

import '../services/pending_upload_service.dart';

class NonconformityProvider extends ChangeNotifier {
  List<NonconformityModel> _allNC = [];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _nonCompletedSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _closureDateSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _detectionDateSubscription;

  List<NonconformityModel> _nonCompletedNC = [];
  List<NonconformityModel> _closureDateNC = [];
  List<NonconformityModel> _detectionDateNC = [];
  List<NonconformityModel> _pendingNC = [];
  Timer? _syncTimer;

  List<NonconformityModel> get all => _allNC;
  List<NonconformityModel> get open => _allNC.where((nc) => nc.isOpen).toList();
  List<NonconformityModel> get completed => _allNC.where((nc) => nc.status == NonconformityStatus.completed).toList();
  List<NonconformityModel> get overdue => _allNC.where((nc) => nc.status == NonconformityStatus.overdue).toList();
  List<NonconformityModel> get waitingControl => _allNC.where((nc) => nc.status == NonconformityStatus.waitingControl).toList();
  List<NonconformityModel> get nonconformities => _allNC;

  NonconformityProvider() {
    _initRealtimeSync();
    _startSyncTimer();
  }

  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _loadPendingNC();
    });
    Future.delayed(const Duration(seconds: 5), () async {
      await _loadPendingNC();
    });
  }

  Future<void> _loadPendingNC() async {
    _pendingNC = await PendingUploadService.getPendingNonconformities();
    _updateAndNotify();
  }

  void _initRealtimeSync() {
    _nonCompletedSubscription?.cancel();
    _closureDateSubscription?.cancel();
    _detectionDateSubscription?.cancel();

    final date45DaysAgo = DateTime.now().subtract(const Duration(days: 45));
    final date45DaysAgoStr = date45DaysAgo.toIso8601String();

    _nonCompletedSubscription = FirebaseFirestore.instance
        .collection('nonconformities')
        .where('status', isNotEqualTo: 'completed')
        .snapshots()
        .listen((snapshot) {
      debugPrint('FIRESTORE: Non-completed NC sync (${snapshot.docs.length} docs)');
      _nonCompletedNC = _processSnapshotDocs(snapshot.docs);
      _updateAndNotify();
    }, onError: (e) {
      debugPrint('FIRESTORE Non-completed NC Sync Error: $e');
    });

    _closureDateSubscription = FirebaseFirestore.instance
        .collection('nonconformities')
        .where('closureDate', isGreaterThanOrEqualTo: date45DaysAgoStr)
        .snapshots()
        .listen((snapshot) {
      debugPrint('FIRESTORE ClosureDate NC sync (${snapshot.docs.length} docs)');
      _closureDateNC = _processSnapshotDocs(snapshot.docs);
      _updateAndNotify();
    }, onError: (e) {
      debugPrint('FIRESTORE ClosureDate NC Sync Error: $e');
    });

    _detectionDateSubscription = FirebaseFirestore.instance
        .collection('nonconformities')
        .where('detectionDate', isGreaterThanOrEqualTo: date45DaysAgoStr)
        .snapshots()
        .listen((snapshot) {
      debugPrint('FIRESTORE DetectionDate NC sync (${snapshot.docs.length} docs)');
      _detectionDateNC = _processSnapshotDocs(snapshot.docs);
      _updateAndNotify();
    }, onError: (e) {
      debugPrint('FIRESTORE DetectionDate NC Sync Error: $e');
    });
  }

  List<NonconformityModel> _processSnapshotDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final List<NonconformityModel> list = [];
    for (final doc in docs) {
      final nc = NonconformityModel.fromMap(doc.data(), doc.id);
      if (_isDemoNonconformity(nc)) {
        FirebaseFirestore.instance.collection('nonconformities').doc(nc.id).delete();
      } else {
        list.add(nc);
      }
    }
    return list;
  }

  void _updateAndNotify() {
    final Map<String, NonconformityModel> merged = {};

    // 1. Add all non-completed nonconformities
    for (final nc in _nonCompletedNC) {
      merged[nc.id] = nc;
    }

    final limitDate = DateTime.now().subtract(const Duration(days: 45));

    void addCompletedIfWithin45Days(NonconformityModel nc) {
      if (nc.status == NonconformityStatus.completed) {
        final refDate = nc.closureDate ?? nc.detectionDate;
        if (refDate.isAfter(limitDate)) {
          merged[nc.id] = nc;
        }
      } else {
        merged[nc.id] = nc;
      }
    }

    // 2. Add from closureDate query
    for (final nc in _closureDateNC) {
      addCompletedIfWithin45Days(nc);
    }

    // 3. Add from detectionDate query
    for (final nc in _detectionDateNC) {
      addCompletedIfWithin45Days(nc);
    }

    // 4. Add pending nonconformities
    for (final nc in _pendingNC) {
      merged[nc.id] = nc;
    }

    _allNC = merged.values.toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _nonCompletedSubscription?.cancel();
    _closureDateSubscription?.cancel();
    _detectionDateSubscription?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }


  Future<void> _loadData() async {
    // Handled by realtime sync
  }

  bool _isDemoNonconformity(NonconformityModel nc) {
    return nc.id.startsWith('NC-AUD-20') || RegExp(r'^AUD-20\d+$').hasMatch(nc.auditId);
  }

  List<NonconformityModel> _generateNCFromMockData() {
    List<NonconformityModel> ncs = [];
    int counter = 0;
    
    for (var audit in MockData.auditHistory) {
      for (var answer in audit.answers) {
        if (answer.isNonconformity) {
          final question = AuditQuestionResolver.resolveAnswer(audit, answer).question;
          
          // Eşit dağılım için modülo kullanıyoruz
          NonconformityStatus status;
          String? closureComment;
          List<String>? closurePhotos;
          DateTime? closureDate;

          int type = counter % 3;
          if (type == 0) {
            status = NonconformityStatus.completed;
            closureComment = 'Uygunsuzluk giderildi, alan temizlendi ve düzenlendi. Standartlara uygun hale getirildi.';
            closurePhotos = [MockData.realPhotos[2], MockData.realPhotos[3]];
            closureDate = audit.date.add(const Duration(days: 2));
          } else if (type == 1) {
            status = NonconformityStatus.overdue;
          } else {
            status = NonconformityStatus.open;
          }

          ncs.add(NonconformityModel(
            id: 'NC-${audit.id}-${answer.questionId}',
            auditId: audit.id,
            auditTypeId: audit.auditTypeId,
            auditType: audit.auditType,
            questionId: answer.questionId,
            questionText: question.questionText,
            category: question.categoryName,
            station: audit.station,
            line: audit.line,
            score: answer.score,
            auditorComment: answer.comment ?? 'Açıklama belirtilmedi',
            auditorPhotoPaths: answer.allPhotoUrls.isNotEmpty ? answer.allPhotoUrls : [MockData.realPhotos[0]],
            detectionDate: audit.date,
            auditorName: audit.auditorName,
            responsiblePerson: 'Saha Denetçisi + Aksiyon Sorumlusu',
            status: status,
            closureComment: closureComment,
            closurePhotoPaths: closurePhotos ?? [],
            closureDate: closureDate,
          ));
          counter++;
        }
      }
    }
    return ncs;
  }

  Future<void> reload() async {
    await _loadData();
  }

  Future<void> addNonconformity(NonconformityModel nc) async {
    await FirebaseFirestore.instance.collection('nonconformities').doc(nc.id).set(nc.toMap());
  }

  Future<void> closeNonconformity(String id, String comment, List<String> photoPaths, {String? closedByName}) async {
    final doc = await FirebaseFirestore.instance.collection('nonconformities').doc(id).get();
    final nc = doc.exists && doc.data() != null ? NonconformityModel.fromMap(doc.data()!, doc.id) : null;
    final uploadedPhotoPaths = nc == null
        ? photoPaths
        : await StorageService.uploadPhotoPaths(
            paths: photoPaths,
            auditId: nc.auditId,
            questionId: 'closure_${nc.questionId}',
          );
    if (photoPaths.isNotEmpty && uploadedPhotoPaths.isEmpty) {
      throw Exception('Fotoğraf Storage alanına yüklenemedi.');
    }

    final updateData = <String, dynamic>{
      'status': 'waitingControl',
      'closureComment': comment,
      'closurePhotoPaths': uploadedPhotoPaths,
      'closureDate': DateTime.now().toIso8601String(),
    };
    if (closedByName != null && closedByName.isNotEmpty) {
      updateData['closedByName'] = closedByName;
    }
    await FirebaseFirestore.instance.collection('nonconformities').doc(id).update(updateData);
  }

  Future<void> approveNonconformity(String id, {String? approvedByName}) async {
    final updateData = <String, dynamic>{
      'status': 'completed',
    };
    if (approvedByName != null && approvedByName.isNotEmpty) {
      updateData['approvedByName'] = approvedByName;
    }
    await FirebaseFirestore.instance.collection('nonconformities').doc(id).update(updateData);
  }

  Future<void> rejectNonconformity(String id) async {
    await FirebaseFirestore.instance.collection('nonconformities').doc(id).update({
      'status': 'open',
    });
  }

  Future<void> updateNonconformityStatus(String id, NonconformityStatus status) async {
    await FirebaseFirestore.instance.collection('nonconformities').doc(id).update({
      'status': status.name,
    });
  }

  Future<void> deleteNonconformity(String id) async {
    await FirebaseFirestore.instance.collection('nonconformities').doc(id).delete();
  }

  Future<List<NonconformityModel>> getAllNonconformities() async {
    return _allNC;
  }
}
