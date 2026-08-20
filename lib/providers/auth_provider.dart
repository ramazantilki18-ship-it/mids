import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isAuthenticated = false;
  Map<String, Map<String, bool>> _rolePermissions = {};
  StreamSubscription<DocumentSnapshot>? _userListenerSubscription;
  StreamSubscription<DocumentSnapshot>? _permissionsSubscription;
  StreamSubscription<DocumentSnapshot>? _mobilePermissionsSubscription;
  Map<String, dynamic> _mobilePermissions = {};

  UserModel? get user => _user;
  UserModel? get currentUser => _user; // Alias for compatibility with screens
  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic> get mobilePermissions => _mobilePermissions;

  static const Map<String, dynamic> DEFAULT_MOBILE_PERMISSIONS = {
    'titles': {},
    'roles': {
      'Super_Admin': {'panel': true, 'denetim': true, 'takip': true, 'puantaj': true, 'analiz': true, 'sahaTakip': true},
      'Executive_Viewer_Global': {'panel': true, 'denetim': false, 'takip': true, 'puantaj': false, 'analiz': true, 'sahaTakip': false},
      'Executive_Viewer_Restricted': {'panel': true, 'denetim': false, 'takip': true, 'puantaj': false, 'analiz': true, 'sahaTakip': false},
      'Approver': {'panel': true, 'denetim': true, 'takip': true, 'puantaj': true, 'analiz': true, 'sahaTakip': true},
      'Field_Auditor_Action_Owner': {'panel': true, 'denetim': true, 'takip': true, 'puantaj': true, 'analiz': false, 'sahaTakip': true},
      'Field_Auditor': {'panel': true, 'denetim': true, 'takip': true, 'puantaj': true, 'analiz': false, 'sahaTakip': true},
    }
  };

  bool hasMobileAccess(String pageKey) {
    if (_user == null) return false;
    if (_user!.role == UserRole.superAdmin) return true;

    final titleKey = _user!.jobTitle;
    if (titleKey != null && titleKey.isNotEmpty) {
      final titleConfig = _mobilePermissions['titles']?[titleKey] as Map?;
      if (titleConfig != null) {
        return titleConfig[pageKey] == true;
      }
      final defaultTitleConfig = DEFAULT_MOBILE_PERMISSIONS['titles']?[titleKey] as Map?;
      if (defaultTitleConfig != null) {
        return defaultTitleConfig[pageKey] == true;
      }
    }

    final roleKey = _user!.role.nameInFirebase;
    final roleConfig = (_mobilePermissions['roles']?[roleKey] ?? DEFAULT_MOBILE_PERMISSIONS['roles']?[roleKey]) as Map?;
    return roleConfig != null ? (roleConfig[pageKey] == true) : false;
  }

  // Web panelindeki varsayÄ±lan yetki matrisiyle tam uyumlu statik yetkiler
  static const Map<String, Map<String, bool>> DEFAULT_ROLE_PERMISSIONS = {
    'Super_Admin': {
      'user_add_edit': true,
      'user_delete': true,
      'perm_mgmt': true,
      'question_mgmt': true,
      'line_mgmt': true,
      'planning': true,
      'audit_start': true,
      'nc_close': true,
      'nc_approve': true,
      'nc_share': true,
      'dashboard_view': true,
      'stats_view': true,
      'export_data': true,
      'backup_data': true,
      'settings': true
    },
    'Executive_Viewer_Global': {
      'user_add_edit': false,
      'user_delete': false,
      'perm_mgmt': false,
      'question_mgmt': false,
      'line_mgmt': false,
      'planning': false,
      'audit_start': false,
      'nc_close': false,
      'nc_approve': false,
      'nc_share': true,
      'dashboard_view': true,
      'stats_view': true,
      'export_data': true,
      'backup_data': false,
      'settings': false
    },
    'Executive_Viewer_Restricted': {
      'user_add_edit': false,
      'user_delete': false,
      'perm_mgmt': false,
      'question_mgmt': false,
      'line_mgmt': false,
      'planning': false,
      'audit_start': false,
      'nc_close': false,
      'nc_approve': false,
      'nc_share': false,
      'dashboard_view': true,
      'stats_view': true,
      'export_data': true,
      'backup_data': false,
      'settings': false
    },
    'Approver': {
      'user_add_edit': false,
      'user_delete': false,
      'perm_mgmt': false,
      'question_mgmt': false,
      'line_mgmt': false,
      'planning': true,
      'audit_start': true,
      'nc_close': true,
      'nc_approve': true,
      'nc_share': true,
      'dashboard_view': true,
      'stats_view': true,
      'export_data': true,
      'backup_data': false,
      'settings': false
    },
    'Field_Auditor_Action_Owner': {
      'user_add_edit': false,
      'user_delete': false,
      'perm_mgmt': false,
      'question_mgmt': false,
      'line_mgmt': false,
      'planning': true,
      'audit_start': true,
      'nc_close': true,
      'nc_approve': false,
      'nc_share': true,
      'dashboard_view': true,
      'stats_view': true,
      'export_data': true,
      'backup_data': false,
      'settings': false
    },
    'Field_Auditor': {
      'user_add_edit': false,
      'user_delete': false,
      'perm_mgmt': false,
      'question_mgmt': false,
      'line_mgmt': false,
      'planning': false,
      'audit_start': true,
      'nc_close': false,
      'nc_approve': false,
      'nc_share': true,
      'dashboard_view': true,
      'stats_view': false,
      'export_data': false,
      'backup_data': false,
      'settings': false
    }
  };

  AuthProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((firebaseUser) async {
      if (firebaseUser != null) {
        _isAuthenticated = true;
        final userDocId = await _loadUserProfile(firebaseUser);
        _startUserDocListener(userDocId);
        _startPermissionsListener();
        _startMobilePermissionsListener();
      } else {
        _user = null;
        _isAuthenticated = false;
        
        _userListenerSubscription?.cancel();
        _userListenerSubscription = null;
        
        _permissionsSubscription?.cancel();
        _permissionsSubscription = null;
        
        _mobilePermissionsSubscription?.cancel();
        _mobilePermissionsSubscription = null;
        
        _mobilePermissions = {};
        _rolePermissions = {};
        
        notifyListeners();
      }
    });
  }

  void _startUserDocListener(String uid) {
    _userListenerSubscription?.cancel();
    _userListenerSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        _user = UserModel.fromJson({...doc.data()!, 'id': doc.id});
        notifyListeners();
      }
    }, onError: (e) {
      print('User doc real-time listen error: $e');
    });
  }

  void _startPermissionsListener() {
    _permissionsSubscription?.cancel();
    _permissionsSubscription = FirebaseFirestore.instance
        .collection('system_config')
        .doc('permissions')
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final Map<String, Map<String, bool>> parsed = {};

        data.forEach((roleKey, permData) {
          if (permData is Map) {
            final Map<String, bool> roleMap = {};
            permData.forEach((permKey, value) {
              roleMap[permKey.toString()] = value == true;
            });
            parsed[roleKey.toString()] = roleMap;
          }
        });

        _rolePermissions = parsed;
        notifyListeners();
      }
    }, onError: (err) {
      print('Permissions matrix sync error: $err');
    });
  }

  void _startMobilePermissionsListener() {
    _mobilePermissionsSubscription?.cancel();
    _mobilePermissionsSubscription = FirebaseFirestore.instance
        .collection('system_config')
        .doc('mobile_permissions')
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        _mobilePermissions = doc.data()!;
        notifyListeners();
      }
    }, onError: (err) {
      print('Mobile permissions matrix sync error: $err');
    });
  }

  Future<String> _loadUserProfile(User firebaseUser) async {
    try {
      final candidates = <DocumentSnapshot<Map<String, dynamic>>>[];
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get()
          .timeout(const Duration(seconds: 5));

      if (doc.exists && doc.data() != null) {
        candidates.add(doc);
      }

      // E-posta ile ara
      final email = firebaseUser.email?.trim();
      if (email != null && email.isNotEmpty) {
        final byEmail = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(5)
            .get()
            .timeout(const Duration(seconds: 5));
        candidates.addAll(byEmail.docs);
      }

      // KullanÄ±cÄ± adÄ± ile ara
      final username = firebaseUser.email?.split('@').first.trim();
      if (username != null && username.isNotEmpty) {
        final byUsername = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: username)
            .limit(5)
            .get()
            .timeout(const Duration(seconds: 5));
        candidates.addAll(byUsername.docs);
      }

      // VeritabanÄ±nda profil bulunamazsa default bir tane oluÅŸturup kaydet
      final resolvedProfile = _resolveBestUserProfile(
        firebaseUser: firebaseUser,
        docs: candidates,
      );
      if (resolvedProfile != null) {
        _user = resolvedProfile.user;
        notifyListeners();
        return resolvedProfile.docId;
      }

      final defaultUser = UserModel(
        id: firebaseUser.uid,
        username: username ?? 'KullanÄ±cÄ±',
        role: UserRole.fieldAuditor,
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .set({
        ...defaultUser.toJson(),
        'email': firebaseUser.email,
      }, SetOptions(merge: true));

      _user = defaultUser;
      notifyListeners();
      return firebaseUser.uid;
    } catch (e) {
      print('Firestore profile load/enrich error: $e');
      return firebaseUser.uid;
    }
  }

  _ResolvedUserProfile? _resolveBestUserProfile({
    required User firebaseUser,
    required List<DocumentSnapshot<Map<String, dynamic>>> docs,
  }) {
    if (docs.isEmpty) return null;

    final normalizedEmail = firebaseUser.email?.trim().toLowerCase() ?? '';
    final normalizedUsername =
        firebaseUser.email?.split('@').first.trim().toLowerCase() ?? '';
    final uniqueDocs = <String, DocumentSnapshot<Map<String, dynamic>>>{};

    for (final doc in docs) {
      if (!doc.exists || doc.data() == null) continue;
      uniqueDocs[doc.id] = doc;
    }

    _ResolvedUserProfile? bestProfile;
    var bestScore = -1;
    DateTime? bestUpdatedAt;

    for (final doc in uniqueDocs.values) {
      final data = doc.data();
      if (data == null) continue;

      final user = UserModel.fromJson({...data, 'id': doc.id});
      final docFirebaseUid =
          (data['firebaseUid'] ?? data['uid'] ?? '').toString().trim();
      final docEmail = data['email']?.toString().trim().toLowerCase() ?? '';
      final docUsername =
          data['username']?.toString().trim().toLowerCase() ?? '';
      final explicitAuthorizedLines = _parseExplicitAuthorizedLines(data);

      var score = 0;
      if (docFirebaseUid.isNotEmpty && docFirebaseUid == firebaseUser.uid) {
        score += 24;
      }
      if (doc.id == firebaseUser.uid) score += 20;
      if (normalizedEmail.isNotEmpty && docEmail == normalizedEmail) {
        score += 16;
      } else if (docEmail.isNotEmpty) {
        score -= 6;
      }
      if (normalizedUsername.isNotEmpty && docUsername == normalizedUsername) {
        score += 10;
      }
      if (explicitAuthorizedLines.isNotEmpty) score += 8;
      if (data['updatedAt'] != null) score += 4;
      if (data['roleId'] != null ||
          data['role'] != null ||
          data['title'] != null) {
        score += 3;
      }
      if (!user.hasGlobalLineAccess &&
          explicitAuthorizedLines.isEmpty &&
          data['scopeType'] == 'restricted') {
        score -= 4;
      }

      final updatedAt = _parseUpdatedAt(data['updatedAt'] ?? data['createdAt']);
      final isBetterScore = score > bestScore;
      final isBetterTime = score == bestScore &&
          updatedAt != null &&
          (bestUpdatedAt == null || updatedAt.isAfter(bestUpdatedAt));

      if (isBetterScore || isBetterTime) {
        bestScore = score;
        bestUpdatedAt = updatedAt;
        bestProfile = _ResolvedUserProfile(docId: doc.id, user: user);
      }
    }

    return bestProfile;
  }

  DateTime? _parseUpdatedAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  List<String> _parseExplicitAuthorizedLines(Map<String, dynamic> data) {
    final rawValue = data['authorizedLines'] ?? data['authorized_lines'];

    if (rawValue is List) {
      return rawValue
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (rawValue is String && rawValue.trim().isNotEmpty) {
      return rawValue
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return const [];
  }

  Future<String> _resolveSignInEmail(String usernameOrEmail) async {
    final input = usernameOrEmail.trim();
    if (input.isEmpty) {
      throw Exception('Lutfen e-posta adresinizi girin.');
    }

    final normalizedInput = input.toLowerCase();
    if (normalizedInput.contains('@') &&
        !normalizedInput.endsWith('@test.com')) {
      return normalizedInput;
    }

    final usernameCandidate = normalizedInput.contains('@')
        ? normalizedInput.split('@').first
        : normalizedInput;
    final resolvedEmail = await _findUserEmailByUsername(usernameCandidate);
    if (resolvedEmail != null) {
      return resolvedEmail;
    }

    if (normalizedInput.contains('@')) {
      return normalizedInput;
    }

    // Fallback: If we couldn't resolve or query failed (e.g. permission denied before auth),
    // construct the email directly.
    return '$normalizedInput@test.com';
  }

  Future<String?> _findUserEmailByUsername(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return null;

    final candidates = <String>{
      trimmed,
      trimmed.toLowerCase(),
      trimmed.toLowerCase().replaceAll(' ', '.'),
    }.where((value) => value.isNotEmpty).toList();

    final docs = <DocumentSnapshot<Map<String, dynamic>>>[];
    try {
      for (final candidate in candidates) {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: candidate)
            .limit(5)
            .get()
            .timeout(const Duration(seconds: 5));
        docs.addAll(snapshot.docs);
      }
    } catch (e) {
      // Catch permission-denied or timeout when unauthenticated
      debugPrint('Error querying user email by username (unauthenticated/unauthorized): $e');
      return null;
    }

    if (docs.isEmpty) return null;

    final normalizedLookup = trimmed.toLowerCase().replaceAll(' ', '.');
    final uniqueDocs = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in docs) {
      if (doc.exists && doc.data() != null) {
        uniqueDocs[doc.id] = doc;
      }
    }

    DocumentSnapshot<Map<String, dynamic>>? bestDoc;
    var bestScore = -1;
    DateTime? bestUpdatedAt;

    for (final doc in uniqueDocs.values) {
      final data = doc.data();
      if (data == null) continue;

      final docUsername =
          data['username']?.toString().trim().toLowerCase() ?? '';
      final docEmail = data['email']?.toString().trim().toLowerCase() ?? '';
      if (!_isValidEmail(docEmail)) continue;

      var score = 0;
      if (docUsername == normalizedLookup) score += 12;
      if (docEmail.endsWith('@test.com')) {
        score -= 5;
      } else {
        score += 4;
      }
      if ((data['firebaseUid'] ?? '').toString().trim().isNotEmpty) score += 4;
      if ((data['roleId'] ?? data['role'] ?? '').toString().trim().isNotEmpty) {
        score += 3;
      }
      if (_parseExplicitAuthorizedLines(data).isNotEmpty) score += 2;

      final updatedAt = _parseUpdatedAt(data['updatedAt'] ?? data['createdAt']);
      final isBetterScore = score > bestScore;
      final isBetterTime = score == bestScore &&
          updatedAt != null &&
          (bestUpdatedAt == null || updatedAt.isAfter(bestUpdatedAt));

      if (isBetterScore || isBetterTime) {
        bestScore = score;
        bestUpdatedAt = updatedAt;
        bestDoc = doc;
      }
    }

    final uniqueEmails = uniqueDocs.values
        .map((doc) =>
            doc.data()?['email']?.toString().trim().toLowerCase() ?? '')
        .where(_isValidEmail)
        .toSet();
    if (uniqueEmails.length > 1) {
      throw Exception(
        'Bu kullanici adi birden fazla hesaba bagli. Lutfen dogrudan e-posta adresinizle giris yapin.',
      );
    }

    final bestData = bestDoc?.data();
    final email = bestData?['email']?.toString().trim().toLowerCase();
    return _isValidEmail(email) ? email : null;
  }

  bool _isValidEmail(String? value) {
    if (value == null) return false;
    final email = value.trim();
    return email.contains('@') && email.contains('.');
  }

  bool hasPermission(String permId) {
    if (_user == null) return false;
    final rId = _user!.roleId; // Ã–rn: 'Super_Admin'

    // Super_Admin her yetkiye sahiptir
    if (rId == 'Super_Admin') return true;

    // Firestore matrisindeki yetki kontrolÃ¼
    if (_rolePermissions.containsKey(rId)) {
      if (_rolePermissions[rId]!.containsKey(permId)) {
        return _rolePermissions[rId]![permId] == true;
      }
    }

    // VeritabanÄ± verisi bulunamazsa statik varsayÄ±lanlarÄ± kullan
    if (DEFAULT_ROLE_PERMISSIONS.containsKey(rId)) {
      return DEFAULT_ROLE_PERMISSIONS[rId]![permId] == true;
    }

    return false;
  }

  Future<bool> login(String usernameOrEmail, String password,
      {bool rememberMe = false}) async {
    try {
      final email = await _resolveSignInEmail(usernameOrEmail);

      final UserCredential credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password.trim(),
      );

      if (credential.user != null) {
        await _loadUserProfile(credential.user!);

        final prefs = await SharedPreferences.getInstance();
        if (rememberMe) {
          await prefs.setBool('remember_me', true);
          await prefs.setString('saved_username', usernameOrEmail);
          await prefs.setString('saved_password', password);
        } else {
          await prefs.setBool('remember_me', false);
          await prefs.remove('saved_username');
          await prefs.remove('saved_password');
        }

        _isAuthenticated = true;
        notifyListeners();

        // Sistem logu ekle
        try {
          await FirebaseFirestore.instance.collection('system_logs').add({
            'timestamp': FieldValue.serverTimestamp(),
            'user': _user?.name ?? _user?.username ?? credential.user!.email ?? 'Mobil Kullanıcı',
            'action': 'Giriş Yapıldı (Mobil)',
            'details': 'Mobil uygulama üzerinden başarıyla giriş yapıldı.'
          }).timeout(const Duration(seconds: 5));
        } catch (err) {
          print('Log writing failed: $err');
        }

        return true;
      }
      return false;
    } catch (e) {
      print('AuthProvider Login Error: $e');
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String usernameOrEmail) async {
    try {
      final email = await _resolveSignInEmail(usernameOrEmail);
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'invalid-email':
          throw Exception('Geçerli bir e-posta adresi girin.');
        case 'user-not-found':
          throw Exception('Bu bilgilerle eşleşen bir kullanıcı bulunamadı.');
        case 'too-many-requests':
          throw Exception(
            'Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.',
          );
        case 'network-request-failed':
          throw Exception(
            'Bağlantı kurulamadı. İnternet bağlantınızı kontrol edin.',
          );
        default:
          throw Exception(
            'Şifre yenileme e-postası gönderilemedi. Lütfen tekrar deneyin.',
          );
      }
    }
  }

  Future<void> logout() async {
    try {
      final userEmail = _user?.name ?? _user?.username ?? FirebaseAuth.instance.currentUser?.email ?? 'Mobil Kullanıcı';
      await FirebaseFirestore.instance.collection('system_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'user': userEmail,
        'action': 'Çıkış Yapıldı (Mobil)',
        'details': 'Mobil uygulama üzerinden çıkış yapıldı.'
      }).timeout(const Duration(seconds: 3));
    } catch (e) {
      print('Log writing failed on logout: $e');
    }

    await FirebaseAuth.instance.signOut();
    _userListenerSubscription?.cancel();
    _userListenerSubscription = null;
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _userListenerSubscription?.cancel();
    _permissionsSubscription?.cancel();
    super.dispose();
  }
}

class _ResolvedUserProfile {
  final String docId;
  final UserModel user;

  const _ResolvedUserProfile({
    required this.docId,
    required this.user,
  });
}
