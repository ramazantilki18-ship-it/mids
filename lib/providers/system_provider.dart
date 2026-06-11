import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../data/mock_data.dart';
import '../models/user_model.dart';
import '../models/task_model.dart';
import '../models/question_model.dart';
import '../models/audit_type_model.dart';
import '../models/announcement_model.dart';
import '../services/database_helper.dart';

class SystemProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  Timer? _announcementTicker;
  bool _isAnnouncementExpirySyncRunning = false;
  Map<String, bool> _announcementVisibilitySnapshot = <String, bool>{};

  // DATA MANAGEMENT STATE
  final Map<String, String> _linesWithColors =
      Map.from(MockData.linesWithColors);
  final Map<String, List<String>> _stations = Map.from(MockData.stations);
  final Map<String, dynamic> _stationNfcs = {};
  final List<UserModel> _users = List.from(MockData.users);
  List<TaskModel> _tasks = [];
  final List<AnnouncementModel> _announcements = [];
  final List<AuditTypeModel> _auditTypes = [
    AuditTypeModel.fiveS,
    AuditTypeModel.stationInspection
  ];
  final List<QuestionGroupModel> _questionGroups =
      List.from(MockData.questionGroups);
  final List<QuestionModel> _questions = List.from(MockData.questions);

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // GETTERS
  List<String> get lines => _linesWithColors.keys.toList();
  Map<String, List<String>> get stations => _stations;
  Map<String, dynamic> get stationNfcs => _stationNfcs;

  // Hat rengi alma
  Color getLineColor(String line) {
    final colorStr = _linesWithColors[line];
    if (colorStr != null) {
      try {
        return Color(int.parse(colorStr));
      } catch (_) {}
    }
    return Colors.blueGrey; // Varsayılan
  }

  List<UserModel> get users => _users;
  List<TaskModel> get tasks => _tasks;
  List<AnnouncementModel> get announcements =>
      List<AnnouncementModel>.unmodifiable(_announcements);
  List<AuditTypeModel> get auditTypes {
    return _auditTypes
        .where((t) => !t.isDeleted)
        .map(_withFallbackCategories)
        .toList();
  }

  List<QuestionGroupModel> get questionGroups {
    if (_hasNewAuditModel) {
      return List<QuestionGroupModel>.from(_questionGroups);
    }
    final groups = List<QuestionGroupModel>.from(_questionGroups);
    for (final group in MockData.questionGroups) {
      if (!groups.any((g) => g.id == group.id)) {
        groups.add(group);
      }
    }
    return groups;
  }

  List<QuestionModel> get questions {
    if (_hasNewAuditModel) return List<QuestionModel>.from(_questions);
    final items = List<QuestionModel>.from(_questions);
    for (final question in MockData.questions) {
      if (!items.any((q) => q.id == question.id)) {
        items.add(question);
      }
    }
    return items;
  }

  bool get _hasNewAuditModel =>
      _auditTypes.any((type) => type.categories.isNotEmpty);

  List<AnnouncementModel> activeAnnouncementsForUser(UserModel user) {
    final seenIds = <String>{};
    final items = _announcements
        .where((announcement) => announcement.isVisibleForUser(user))
        .where((announcement) => seenIds.add(announcement.id))
        .toList()
      ..sort((a, b) => a.endAt.compareTo(b.endAt));
    return items;
  }

  AuditTypeModel _withFallbackCategories(AuditTypeModel type) {
    if (type.categories.isNotEmpty) return type;

    final fallbackCategories = type.id == AuditTypeModel.stationInspectionId
        ? _defaultStationCategories()
        : _categoriesFromQuestions(
            type.id,
            MockData.questions
                .where((q) =>
                    q.auditTypeId == type.id ||
                    type.id == AuditTypeModel.fiveSId)
                .toList());

    if (fallbackCategories.isEmpty) return type;
    return AuditTypeModel(
      id: type.id,
      title: type.title,
      description: type.description,
      defaultAnswerValue: type.defaultAnswerValue,
      categories: fallbackCategories,
      isActive: type.isActive,
      isDeleted: type.isDeleted,
      orderIndex: type.orderIndex,
      scoringStrategy: type.scoringStrategy,
      allowedAnswerTypes: type.allowedAnswerTypes,
      config: type.config,
      evidenceRequired: type.evidenceRequired,
      evidenceRule: type.evidenceRule,
      evidenceRequiredValues: type.evidenceRequiredValues,
    );
  }

  List<QuestionModel> questionsForAuditType(AuditTypeModel auditType) {
    final type = _withFallbackCategories(auditType);
    final questions = <QuestionModel>[];

    for (final category
        in type.categories.where((c) => c.isActive && !c.isDeleted)) {
      final categoryQuestions = category.questions
          .where((q) => q.isActive && !q.isDeleted)
          .toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      for (final question in categoryQuestions) {
        questions.add(QuestionModel(
          id: question.id,
          auditTypeId: type.id,
          groupId: category.id,
          categoryName: category.name,
          questionText: question.text,
          orderIndex: question.orderIndex,
          answerType:
              question.type == 'yes-no' ? AnswerType.boolean : AnswerType.scale,
        ));
      }
    }

    return questions;
  }

  List<AuditCategoryModel> _categoriesFromQuestions(
      String auditTypeId, List<QuestionModel> questions) {
    final names = <String>[];
    for (final question in questions) {
      if (!names.contains(question.categoryName)) {
        names.add(question.categoryName);
      }
    }

    return names.map((name) {
      final categoryQuestions = questions
          .where((q) => q.categoryName == name)
          .toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return AuditCategoryModel(
        id: _stableCategoryId(auditTypeId, name),
        name: name,
        orderIndex: names.indexOf(name),
        questions: categoryQuestions
            .map((q) => AuditQuestionDefinition(
                  id: q.id,
                  text: q.questionText,
                  type: q.answerType == AnswerType.boolean
                      ? 'yes-no'
                      : '5s-score',
                  orderIndex: q.orderIndex,
                ))
            .toList(),
      );
    }).toList();
  }

  List<AuditCategoryModel> _defaultStationCategories() {
    const data = <String, List<String>>{
      'İSTASYON GİRİŞİ': [
        'İstasyon yönlendirmeleri usule uygun mu?',
        'İşletmeyi engelleyebileceği bir yapısal durum var mı?',
        'Asansör emreamadeliğe uygun mu?',
        'Yürüyen merdiven emreamadeliğe uygun mu?',
        'Çevre ve giriş temizliği uygun mu?',
        'Totem / alınlık temizlik ve yapısal durumu uygun mu?',
      ],
      'KONKORS TURNİKE': [
        'İstasyon yönlendirmeleri usule uygun mu?',
        'Turnikeler dijital/mekanik olarak çalışıyor mu?',
        'Bölge aydınlatmaları çalışıyor mu?',
        'Biletmatikler sorunsuz dolum yapıyor mu?',
      ],
      'PERON': [
        'İstasyon yönlendirmeleri usule uygun mu?',
        'YBS ekranları doğru ve çalışır durumda mı?',
        'Bölge aydınlatmaları çalışıyor mu?',
        'Çevre temizliği uygun mu?',
      ],
      'GÜVENLİK': [
        'Görev numarasına uyumlu mu?',
        'Personel yaka kimliği görünür durumda mı?',
        'Personel teçhizatı uygun mu?',
        'Yolculara karşı tutum ve davranışları uygun mudur?',
      ],
      'TEMİZLİK': [
        'Temizlik odası tertip ve düzen kontrolü uygun mu?',
        'Personel kılık kıyafeti kurumsal standartlara uygun mu?',
        'İş planında yer alan iş kalemlerini uygun ekipmanla mı yapıyor?',
        'Temizlik otomat makinası çalışma planına uygun mu?',
      ],
    };

    var categoryIndex = 0;
    return data.entries.map((entry) {
      final currentCategoryIndex = categoryIndex++;
      return AuditCategoryModel(
        id: _stableCategoryId(AuditTypeModel.stationInspectionId, entry.key),
        name: entry.key,
        orderIndex: currentCategoryIndex,
        questions: entry.value
            .asMap()
            .entries
            .map((questionEntry) => AuditQuestionDefinition(
                  id: '${_stableCategoryId(AuditTypeModel.stationInspectionId, entry.key)}-q${questionEntry.key + 1}',
                  text: questionEntry.value,
                  type: 'yes-no',
                  orderIndex: questionEntry.key,
                ))
            .toList(),
      );
    }).toList();
  }

  String _stableCategoryId(String auditTypeId, String name) {
    final slug = name
        .toLowerCase()
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '$auditTypeId-$slug';
  }

  void _hydrateQuestionCompatibilityFromAuditTypes() {
    final groups = <QuestionGroupModel>[];
    final questions = <QuestionModel>[];

    for (final type in _auditTypes.where((t) => !t.isDeleted)) {
      for (final category
          in type.categories.where((c) => c.isActive && !c.isDeleted)) {
        groups.add(QuestionGroupModel(
          id: category.id,
          auditTypeId: type.id,
          name: category.name,
          icon: Icons.category_rounded,
          orderIndex: category.orderIndex,
        ));

        for (final question
            in category.questions.where((q) => q.isActive && !q.isDeleted)) {
          questions.add(QuestionModel(
            id: question.id,
            auditTypeId: type.id,
            groupId: category.id,
            categoryName: category.name,
            questionText: question.text,
            orderIndex: question.orderIndex,
            answerType: question.type == 'yes-no'
                ? AnswerType.boolean
                : AnswerType.scale,
          ));
        }
      }
    }

    if (groups.isEmpty && questions.isEmpty) return;
    _questionGroups
      ..clear()
      ..addAll(groups);
    _questions
      ..clear()
      ..addAll(questions);
    MockData.questionGroups
      ..clear()
      ..addAll(groups);
    MockData.questions
      ..clear()
      ..addAll(questions);
  }

  SystemProvider() {
    _loadTheme();
    _initData();
    _loadPersistentData();
    _initFirestoreUsersSync();
    _startAnnouncementTicker();
  }

  void _startAnnouncementTicker() {
    _announcementTicker?.cancel();
    _announcementVisibilitySnapshot = _buildAnnouncementVisibilitySnapshot();
    _announcementTicker = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshAnnouncementVisibility();
    });
  }

  Map<String, bool> _buildAnnouncementVisibilitySnapshot() {
    return <String, bool>{
      for (final announcement in _announcements)
        announcement.id: announcement.isCurrentlyVisible,
    };
  }

  bool _hasAnnouncementVisibilityChanged(Map<String, bool> nextSnapshot) {
    if (_announcementVisibilitySnapshot.length != nextSnapshot.length) {
      return true;
    }
    for (final entry in nextSnapshot.entries) {
      if (_announcementVisibilitySnapshot[entry.key] != entry.value) {
        return true;
      }
    }
    return false;
  }

  void _refreshAnnouncementVisibility() {
    _deactivateExpiredAnnouncements();
    final nextSnapshot = _buildAnnouncementVisibilitySnapshot();
    if (_hasAnnouncementVisibilityChanged(nextSnapshot)) {
      _announcementVisibilitySnapshot = nextSnapshot;
      notifyListeners();
    }
  }

  Future<void> _deactivateExpiredAnnouncements() async {
    if (_isAnnouncementExpirySyncRunning) return;

    final now = DateTime.now();
    final expiredIds = _announcements
        .where((announcement) =>
            announcement.isActive && !announcement.endAt.isAfter(now))
        .map((announcement) => announcement.id)
        .toList();

    if (expiredIds.isEmpty) return;

    _isAnnouncementExpirySyncRunning = true;
    try {
      await Future.wait(expiredIds.map((id) {
        return FirebaseFirestore.instance
            .collection('announcements')
            .doc(id)
            .set({
          'isActive': false,
          'updatedAt': FieldValue.serverTimestamp(),
          'autoDeactivatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }));
    } catch (e) {
      debugPrint('Announcement periodic cleanup skipped: $e');
    } finally {
      _isAnnouncementExpirySyncRunning = false;
    }
  }

  void _initFirestoreUsersSync() {
    FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snapshot) {
      _users.clear();
      if (snapshot.docs.isEmpty) {
        _users.addAll(MockData.users);
      } else {
        _users.addAll(snapshot.docs
            .map((doc) => UserModel.fromJson({...doc.data(), 'id': doc.id})));
      }
      notifyListeners();
    });

    FirebaseFirestore.instance.collection('auditTypes').snapshots().listen(
        (snapshot) {
      _auditTypes
        ..clear()
        ..addAll([AuditTypeModel.fiveS, AuditTypeModel.stationInspection]);
      if (snapshot.docs.isNotEmpty) {
        final types = snapshot.docs
            .map(
                (doc) => AuditTypeModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        _auditTypes
          ..clear()
          ..addAll(types);
      } else {
        FirebaseFirestore.instance
            .collection('auditTypes')
            .doc(AuditTypeModel.fiveSId)
            .set(AuditTypeModel.fiveS.toJson());
        FirebaseFirestore.instance
            .collection('auditTypes')
            .doc(AuditTypeModel.stationInspectionId)
            .set(AuditTypeModel.stationInspection.toJson());
      }
      _hydrateQuestionCompatibilityFromAuditTypes();
      notifyListeners();
    }, onError: (e) => debugPrint('Audit Types Sync Error: $e'));

    FirebaseFirestore.instance
        .collection('auditQuestionGroups')
        .orderBy('orderIndex')
        .snapshots()
        .listen((snapshot) {
      if (_hasNewAuditModel) return;
      debugPrint(
          'FIRESTORE: Question Groups sync (${snapshot.docs.length} docs)');
      _questionGroups.clear();
      if (snapshot.docs.isNotEmpty) {
        _questionGroups.addAll(snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return QuestionGroupModel.fromJson(data);
        }));
      }
      MockData.questionGroups.clear();
      MockData.questionGroups.addAll(_questionGroups);
      notifyListeners();
    }, onError: (e) => debugPrint('Question Groups Sync Error: $e'));

    FirebaseFirestore.instance.collection('question_groups').snapshots().listen(
        (snapshot) {
      if (_hasNewAuditModel) return;
      if (_questionGroups.isNotEmpty || snapshot.docs.isEmpty) return;
      _questionGroups.addAll(snapshot.docs.map(
          (doc) => QuestionGroupModel.fromJson({...doc.data(), 'id': doc.id})));
      notifyListeners();
    }, onError: (e) => debugPrint('Legacy Question Groups Sync Error: $e'));

    FirebaseFirestore.instance
        .collection('auditQuestions')
        .orderBy('orderIndex')
        .snapshots()
        .listen((snapshot) {
      if (_hasNewAuditModel) return;
      debugPrint('FIRESTORE: Questions sync (${snapshot.docs.length} docs)');
      _questions.clear();
      if (snapshot.docs.isNotEmpty) {
        _questions.addAll(snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return QuestionModel.fromJson(data);
        }));
      }
      MockData.questions.clear();
      MockData.questions.addAll(_questions);
      notifyListeners();
    }, onError: (e) => debugPrint('Questions Sync Error: $e'));

    FirebaseFirestore.instance
        .collection('questions')
        .orderBy('orderIndex')
        .snapshots()
        .listen((snapshot) {
      if (_hasNewAuditModel) return;
      if (_questions.isNotEmpty || snapshot.docs.isEmpty) return;
      _questions.addAll(snapshot.docs
          .map((doc) => QuestionModel.fromJson({...doc.data(), 'id': doc.id})));
      notifyListeners();
    }, onError: (e) => debugPrint('Legacy Questions Sync Error: $e'));

    // Plans (Tasks) Real-time Sync
    FirebaseFirestore.instance.collection('plans').snapshots().listen(
        (snapshot) {
      debugPrint('FIRESTORE: Plans sync (${snapshot.docs.length} docs)');
      _tasks.clear();
      if (snapshot.docs.isNotEmpty) {
        final parsedTasks = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return TaskModel.fromJson(data);
        }).toList();
        _tasks.addAll(parsedTasks.where((task) => !_isDemoTask(task)));
        for (final task in parsedTasks.where(_isDemoTask)) {
          FirebaseFirestore.instance.collection('plans').doc(task.id).delete();
        }
      }
      notifyListeners();
    }, onError: (e) => debugPrint('Plans Sync Error: $e'));

    FirebaseFirestore.instance.collection('announcements').snapshots().listen(
        (snapshot) {
      debugPrint(
          'FIRESTORE: Announcements sync (${snapshot.docs.length} docs)');
      final now = DateTime.now();
      _announcements.clear();

      for (final doc in snapshot.docs) {
        final announcement =
            AnnouncementModel.fromJson({...doc.data(), 'id': doc.id});
        if (!announcement.endAt.isAfter(now)) {
          continue; // skip expired
        }
        if (announcement.isActive) {
          _announcements.add(announcement);
        }
      }

      _announcements.sort((a, b) => a.startAt.compareTo(b.startAt));
      _announcementVisibilitySnapshot = _buildAnnouncementVisibilitySnapshot();
      notifyListeners();
    }, onError: (e) => debugPrint('Announcements Sync Error: $e'));

    // Lines/Stations Real-time Sync
    FirebaseFirestore.instance
        .collection('system_config')
        .doc('lines_stations')
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data()!;
        if (data['lineColors'] != null) {
          _linesWithColors.clear();
          final rawColors = data['lineColors'] as Map;
          rawColors.forEach((k, v) {
            // Convert web hex (#E31E24) to Flutter format (0xFFE31E24)
            String colorStr = v.toString();
            if (colorStr.startsWith('#')) {
              colorStr = '0xFF${colorStr.substring(1)}';
            }
            _linesWithColors[k.toString()] = colorStr;
          });
        }
        if (data['stations'] != null) {
          _stations.clear();
          final rawStations = data['stations'] as Map;
          rawStations.forEach((k, v) {
            if (v is List) {
              _stations[k.toString()] =
                  List<String>.from(v.map((e) => e.toString()));
            }
          });
        }
        if (data['stationNfcs'] != null) {
          _stationNfcs.clear();
          final rawNfcs = data['stationNfcs'] as Map;
          rawNfcs.forEach((k, v) {
            _stationNfcs[k.toString()] = v;
          });
          debugPrint('FIRESTORE: lines_stations NFC sync (${_stationNfcs.length} stations)');
        }
        _savePersistentData();
        notifyListeners();
      } else {
        // Seed defaults to Firebase if no data exists
        _seedLinesStationsToFirebase();
      }
    }, onError: (e) => debugPrint('Lines/Stations Sync Error: $e'));
  }

  Future<void> _seedLinesStationsToFirebase() async {
    final Map<String, String> webColors = {};
    _linesWithColors.forEach((k, v) {
      // Convert Flutter format (0xFFE31E24) to web hex (#E31E24)
      if (v.startsWith('0xFF') || v.startsWith('0xff')) {
        webColors[k] = '#${v.substring(4)}';
      } else {
        webColors[k] = v;
      }
    });
    await FirebaseFirestore.instance
        .collection('system_config')
        .doc('lines_stations')
        .set({
      'lineColors': webColors,
      'lines': _linesWithColors.keys.toList(),
      'stations': _stations,
      'stationNfcs': _stationNfcs,
    });
  }

  Future<void> _saveLinesStationsToFirebase() async {
    final Map<String, String> webColors = {};
    _linesWithColors.forEach((k, v) {
      if (v.startsWith('0xFF') || v.startsWith('0xff')) {
        webColors[k] = '#${v.substring(4)}';
      } else {
        webColors[k] = v;
      }
    });
    try {
      await FirebaseFirestore.instance
          .collection('system_config')
          .doc('lines_stations')
          .set({
        'lineColors': webColors,
        'lines': _linesWithColors.keys.toList(),
        'stations': _stations,
        'stationNfcs': _stationNfcs,
      });
    } catch (e) {
      debugPrint('Save lines/stations to Firebase error: $e');
    }
  }

  // _parseIcon is handled in QuestionGroupModel

  Future<void> updateFirebaseUser(UserModel user) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .set(user.toJson());
  }

  Future<void> _initData() async {
    try {
      final dbTasks = await DatabaseHelper.instance.getTasks();
      final demoTasks = dbTasks.where(_isDemoTask).toList();
      for (final task in demoTasks) {
        await DatabaseHelper.instance.removeTask(task.id);
      }
      _tasks = dbTasks.where((task) => !_isDemoTask(task)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('DB unavailable for Tasks: $e');
    }
  }

  @override
  void dispose() {
    _announcementTicker?.cancel();
    super.dispose();
  }

  bool _isDemoTask(TaskModel task) {
    if (['t1', 't2', 't3'].contains(task.id)) return true;
    final text = '${task.title} ${task.description}'.toLowerCase();
    return text.contains('yenikapı') ||
        text.contains('kabataş') ||
        text.contains('kadıköy');
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    // İlk açılışta varsayılan olarak karanlık modda açılması için null durumunda 'true' döndürür.
    final isDark = prefs.getBool('is_dark_mode') ?? true;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  // Persistent data: lines, stations, users
  Future<void> _loadPersistentData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final linesJson = prefs.getString('lines_with_colors_json');
      final stationsJson = prefs.getString('stations_json');
      final usersJson = prefs.getString('users_json');
      final stationNfcsJson = prefs.getString('station_nfcs_json');

      if (linesJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(linesJson);
        _linesWithColors.clear();
        decoded.forEach((k, v) {
          _linesWithColors[k] = v.toString();
        });
      }

      if (stationsJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(stationsJson);
        _stations.clear();
        decoded.forEach((k, v) {
          _stations[k] =
              List<String>.from((v as List).map((e) => e.toString()));
        });
      }

      if (stationNfcsJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(stationNfcsJson);
        _stationNfcs.clear();
        _stationNfcs.addAll(decoded);
      }

      if (usersJson != null) {
        final List<dynamic> decoded = jsonDecode(usersJson);
        _users
          ..clear()
          ..addAll(decoded
              .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e))));
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load persistent SystemProvider data: $e');
    }
  }

  Future<void> _savePersistentData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'lines_with_colors_json', jsonEncode(_linesWithColors));
      await prefs.setString('stations_json', jsonEncode(_stations));
      await prefs.setString(
          'station_nfcs_json', jsonEncode(_stationNfcs));
      await prefs.setString(
          'users_json', jsonEncode(_users.map((u) => u.toJson()).toList()));
    } catch (e) {
      debugPrint('Failed to save persistent SystemProvider data: $e');
    }
  }

  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', _themeMode == ThemeMode.dark);
    notifyListeners();
  }

  // LINE MANAGEMENT
  void addLine(String line, {String color = '0xFF2196F3'}) {
    if (!_linesWithColors.containsKey(line)) {
      _linesWithColors[line] = color;
      _stations[line] = [];
      _savePersistentData();
      _saveLinesStationsToFirebase();
      notifyListeners();
    }
  }

  void removeLine(String line) {
    _linesWithColors.remove(line);
    _stations.remove(line);
    _savePersistentData();
    _saveLinesStationsToFirebase();
    notifyListeners();
  }

  void updateLine(String oldName, String newName) {
    if (_linesWithColors.containsKey(oldName) &&
        !_linesWithColors.containsKey(newName)) {
      final color = _linesWithColors.remove(oldName)!;
      _linesWithColors[newName] = color;
      final stations = _stations.remove(oldName);
      if (stations != null) {
        _stations[newName] = stations;
      }
      _savePersistentData();
      _saveLinesStationsToFirebase();
      notifyListeners();
    }
  }

  void updateLineColor(String line, String colorStr) {
    if (_linesWithColors.containsKey(line)) {
      _linesWithColors[line] = colorStr;
      _savePersistentData();
      _saveLinesStationsToFirebase();
      notifyListeners();
    }
  }

  // STATION MANAGEMENT
  void addStation(String line, String station) {
    if (_stations.containsKey(line) && !_stations[line]!.contains(station)) {
      _stations[line]!.add(station);
      _savePersistentData();
      _saveLinesStationsToFirebase();
      notifyListeners();
    }
  }

  void removeStation(String line, String station) {
    if (_stations.containsKey(line)) {
      _stations[line]!.remove(station);
      _savePersistentData();
      _saveLinesStationsToFirebase();
      notifyListeners();
    }
  }

  void updateStation(String line, String oldName, String newName) {
    if (_stations.containsKey(line)) {
      int index = _stations[line]!.indexOf(oldName);
      if (index != -1) {
        _stations[line]![index] = newName;
        _savePersistentData();
        _saveLinesStationsToFirebase();
        notifyListeners();
      }
    }
  }

  // USER MANAGEMENT
  Future<void> addUser(UserModel user) async {
    _users.add(user);
    _savePersistentData();
    notifyListeners();

    // Sync to Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .set(user.toJson());
  }

  Future<void> updateUser(UserModel user) async {
    int index = _users.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      _users[index] = user;
      _savePersistentData();
      notifyListeners();

      // Sync to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .set(user.toJson());
    }
  }

  Future<void> removeUser(String id) async {
    _users.removeWhere((u) => u.id == id);
    _savePersistentData();
    notifyListeners();

    // Sync to Firestore
    await FirebaseFirestore.instance.collection('users').doc(id).delete();
  }

  // TASK MANAGEMENT
  Future<void> addTask(TaskModel task) async {
    _tasks.add(task);
    notifyListeners();
    final docRef = FirebaseFirestore.instance.collection('plans').doc();
    final taskData = task.copyWith(id: docRef.id).toJson();
    await docRef.set(taskData);
  }

  Future<void> addTasks(List<TaskModel> newTasks) async {
    _tasks.addAll(newTasks);
    notifyListeners();
    final batch = FirebaseFirestore.instance.batch();
    for (var task in newTasks) {
      final docRef = FirebaseFirestore.instance.collection('plans').doc();
      final taskData = task.copyWith(id: docRef.id).toJson();
      batch.set(docRef, taskData);
    }
    await batch.commit();
  }

  Future<void> updateTask(TaskModel task) async {
    int index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
      await FirebaseFirestore.instance
          .collection('plans')
          .doc(task.id)
          .update(task.toJson());
      notifyListeners();
    }
  }

  Future<void> removeTask(String id) async {
    _tasks = _tasks.where((t) => t.id != id).toList();
    notifyListeners();
    await FirebaseFirestore.instance.collection('plans').doc(id).delete();
  }

  Future<void> removeUnassignedTasks() async {
    final toRemove = _tasks.where((t) => t.assignedUserId == null).toList();
    if (toRemove.isEmpty) return;

    _tasks = _tasks.where((t) => t.assignedUserId != null).toList();
    notifyListeners();

    final batch = FirebaseFirestore.instance.batch();
    for (var task in toRemove) {
      batch.delete(FirebaseFirestore.instance.collection('plans').doc(task.id));
    }
    await batch.commit();
  }

  // QUESTION MANAGEMENT
  Future<void> addQuestionGroup(QuestionGroupModel group) async {
    if (_hasNewAuditModel) {
      final index =
          _auditTypes.indexWhere((type) => type.id == group.auditTypeId);
      if (index != -1) {
        final type = _auditTypes[index];
        final categories = [
          ...type.categories,
          AuditCategoryModel(
            id: group.id,
            name: group.name,
            orderIndex: group.orderIndex,
            questions: const [],
          ),
        ];
        final data = type.toJson();
        data['categories'] = categories.map((c) => c.toJson()).toList();
        await FirebaseFirestore.instance
            .collection('auditTypes')
            .doc(type.id)
            .set(data, SetOptions(merge: true));
        return;
      }
    }
    _questionGroups.add(group);
    notifyListeners();
    final docRef =
        FirebaseFirestore.instance.collection('auditQuestionGroups').doc();
    final groupData = group.toJson();
    groupData['id'] = docRef.id;
    await FirebaseFirestore.instance
        .collection('auditQuestionGroups')
        .doc(docRef.id)
        .set(groupData);
  }

  Future<void> addQuestion(QuestionModel question) async {
    if (_hasNewAuditModel) {
      final typeIndex =
          _auditTypes.indexWhere((type) => type.id == question.auditTypeId);
      if (typeIndex != -1) {
        final type = _auditTypes[typeIndex];
        final categories = type.categories.map((category) {
          if (category.id != question.groupId) return category;
          return AuditCategoryModel(
            id: category.id,
            name: category.name,
            orderIndex: category.orderIndex,
            isActive: category.isActive,
            isDeleted: category.isDeleted,
            questions: [
              ...category.questions,
              AuditQuestionDefinition(
                id: question.id,
                text: question.questionText,
                type: question.answerType == AnswerType.boolean
                    ? 'yes-no'
                    : '5s-score',
                orderIndex: question.orderIndex,
              ),
            ],
          );
        }).toList();
        final data = type.toJson();
        data['categories'] = categories.map((c) => c.toJson()).toList();
        await FirebaseFirestore.instance
            .collection('auditTypes')
            .doc(type.id)
            .set(data, SetOptions(merge: true));
        return;
      }
    }
    _questions.add(question);
    notifyListeners();
    final docRef =
        FirebaseFirestore.instance.collection('auditQuestions').doc();
    final qData = question.toJson();
    qData['id'] = docRef.id;
    await FirebaseFirestore.instance
        .collection('auditQuestions')
        .doc(docRef.id)
        .set(qData);
  }

  Future<void> removeQuestion(String id) async {
    if (_hasNewAuditModel) {
      for (final type in _auditTypes) {
        var changed = false;
        final categories = type.categories.map((category) {
          final questions = category.questions.map((question) {
            if (question.id != id) return question;
            changed = true;
            return AuditQuestionDefinition(
              id: question.id,
              text: question.text,
              type: question.type,
              orderIndex: question.orderIndex,
              isActive: false,
              isDeleted: true,
            );
          }).toList();
          return AuditCategoryModel(
            id: category.id,
            name: category.name,
            orderIndex: category.orderIndex,
            isActive: category.isActive,
            isDeleted: category.isDeleted,
            questions: questions,
          );
        }).toList();
        if (changed) {
          await FirebaseFirestore.instance
              .collection('auditTypes')
              .doc(type.id)
              .set({
            'categories': categories.map((c) => c.toJson()).toList(),
          }, SetOptions(merge: true));
          return;
        }
      }
    }
    _questions.removeWhere((q) => q.id == id);
    notifyListeners();
    await FirebaseFirestore.instance
        .collection('auditQuestions')
        .doc(id)
        .update({'isDeleted': true, 'isActive': false});
  }

  Future<void> removeQuestionGroup(String id) async {
    if (_hasNewAuditModel) {
      for (final type in _auditTypes) {
        if (!type.categories.any((category) => category.id == id)) continue;
        final categories = type.categories.map((category) {
          if (category.id != id) return category;
          return AuditCategoryModel(
            id: category.id,
            name: category.name,
            orderIndex: category.orderIndex,
            isActive: false,
            isDeleted: true,
            questions: category.questions,
          );
        }).toList();
        await FirebaseFirestore.instance
            .collection('auditTypes')
            .doc(type.id)
            .set({
          'categories': categories.map((c) => c.toJson()).toList(),
        }, SetOptions(merge: true));
        return;
      }
    }
    _questionGroups.removeWhere((g) => g.id == id);
    notifyListeners();
    await FirebaseFirestore.instance
        .collection('auditQuestionGroups')
        .doc(id)
        .update({'isDeleted': true, 'isActive': false});

    // Also remove related questions
    final relatedQuestions = _questions.where((q) => q.groupId == id).toList();
    for (var q in relatedQuestions) {
      await removeQuestion(q.id);
    }
  }
}
