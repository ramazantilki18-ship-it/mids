import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/feedback_model.dart';

class FeedbackProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<FeedbackModel> _feedbacks = [];
  bool _isLoading = false;
  StreamSubscription? _subscription;

  List<FeedbackModel> get feedbacks => _feedbacks;
  bool get isLoading => _isLoading;

  void initialize() {
    _isLoading = true;
    notifyListeners();

    _subscription = _firestore
        .collection('feedbacks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _feedbacks = snapshot.docs.map((doc) {
        return FeedbackModel.fromMap(doc.data(), doc.id);
      }).toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('Feedback sync error: $e');
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addFeedback(FeedbackModel feedback) async {
    try {
      await _firestore.collection('feedbacks').doc(feedback.id).set(feedback.toMap());
    } catch (e) {
      debugPrint('Error adding feedback: $e');
      rethrow;
    }
  }

  Future<void> deleteFeedback(String id) async {
    try {
      await _firestore.collection('feedbacks').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting feedback: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}