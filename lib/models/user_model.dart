enum UserRole {
  superAdmin,
  executiveViewerGlobal,
  approver,
  fieldAuditorActionOwner,
  fieldAuditor,
  executiveViewerRestricted
}

extension UserRoleExtension on UserRole {
  String get nameInFirebase {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super_Admin';
      case UserRole.executiveViewerGlobal:
        return 'Executive_Viewer_Global';
      case UserRole.approver:
        return 'Approver';
      case UserRole.fieldAuditorActionOwner:
        return 'Field_Auditor_Action_Owner';
      case UserRole.fieldAuditor:
        return 'Field_Auditor';
      case UserRole.executiveViewerRestricted:
        return 'Executive_Viewer_Restricted';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Süper Admin';
      case UserRole.executiveViewerGlobal:
        return 'Ü.Yönetici';
      case UserRole.approver:
        return 'Onaylayıcı';
      case UserRole.fieldAuditorActionOwner:
        return 'Saha Denetçisi + Aksiyon Sorumlusu';
      case UserRole.fieldAuditor:
        return 'Saha Denetçisi';
      case UserRole.executiveViewerRestricted:
        return 'Yönetici';
    }
  }
}

class UserModel {
  final String id;
  final String username;
  final String? displayName;
  final UserRole role;
  final List<String> authorizedLines;
  final List<String> authorizedStations;
  final String? password;
  final String? jobTitle;

  UserModel({
    required this.id,
    required this.username,
    this.displayName,
    required this.role,
    this.authorizedLines = const [],
    this.authorizedStations = const [],
    this.password,
    this.jobTitle,
  });

  String get name => displayName ?? username;
  String get title => jobTitle ?? role.displayName;
  String get roleDisplayName => role.displayName;
  String get roleId => role.nameInFirebase;

  bool get isAdmin =>
      role == UserRole.superAdmin || role == UserRole.executiveViewerGlobal;
  bool get isPowerUser => isAdmin || role == UserRole.approver;
  bool get isViewer => role == UserRole.executiveViewerRestricted;
  bool get hasGlobalLineAccess => isAdmin;

  Set<String> get authorizedLineSet => authorizedLines
      .map((line) => line.trim().toUpperCase())
      .where((line) => line.isNotEmpty)
      .toSet();

  bool canAccessLine(String? line) {
    if (role == UserRole.approver && authorizedLineSet.isEmpty) return false; // Strict check for approver
    if (hasGlobalLineAccess) return true;

    final normalizedLine = line?.trim().toUpperCase() ?? '';
    if (normalizedLine.isEmpty) return false;

    final lines = authorizedLineSet;
    if (lines.isEmpty) return false;

    return lines.contains(normalizedLine);
  }

  bool matchesIdentity({String? auditorId, String? auditorName}) {
    final normalizedAuditorId = auditorId?.trim() ?? '';
    if (normalizedAuditorId.isNotEmpty && normalizedAuditorId == id.trim()) {
      return true;
    }

    final normalizedAuditorName = auditorName?.trim().toLowerCase() ?? '';
    if (normalizedAuditorName.isEmpty) return false;

    final normalizedUsername = username.trim().toLowerCase();
    final normalizedName = name.trim().toLowerCase();
    return normalizedAuditorName == normalizedUsername ||
        normalizedAuditorName == normalizedName;
  }

  bool canAccessAudit({
    required String line,
    String? auditorId,
    String? auditorName,
  }) {
    if (hasGlobalLineAccess) return true;
    return canAccessLine(line);
  }

  bool canAccessNonconformity({
    required String line,
    String? auditorId,
    String? auditorName,
  }) {
    if (hasGlobalLineAccess) return true;
    return canAccessLine(line);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': displayName ?? username,
      'roleId': role.nameInFirebase,
      'role': role.nameInFirebase,
      'authorizedLines': authorizedLines,
      'authorizedStations': authorizedStations,
      'password': password,
      'title': jobTitle,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawRole = json['roleId']?.toString() ??
        json['roleName']?.toString() ??
        json['role']?.toString() ??
        json['title']?.toString() ??
        'Field_Auditor';
    final username =
        (json['username'] ?? json['name'] ?? json['email'] ?? 'Kullanıcı')
            .toString();
    final String? displayName = json['name']?.toString();
    final String? jobTitle = json['title']?.toString();

    // Map string from firebase to UserRole enum
    UserRole parsedRole = UserRole.fieldAuditor;
    for (var val in UserRole.values) {
      if (val.nameInFirebase.toLowerCase() == rawRole.toLowerCase() ||
          val.name.toLowerCase() == rawRole.toLowerCase()) {
        parsedRole = val;
        break;
      }
    }

    final normalizedRole = rawRole
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');
    if (parsedRole == UserRole.fieldAuditor) {
      if (normalizedRole == 'admin' || normalizedRole == 'superadmin') {
        parsedRole = UserRole.superAdmin;
      } else if (normalizedRole == 'coordinator' ||
          normalizedRole.contains('onaylayici') ||
          normalizedRole.contains('approver')) {
        parsedRole = UserRole.approver;
      } else if (normalizedRole.contains('fieldauditractionowner') ||
          (normalizedRole.contains('sahadenetcisi') &&
              normalizedRole.contains('aksiyonsorumlusu')) ||
          normalizedRole.contains('aksiyon')) {
        parsedRole = UserRole.fieldAuditorActionOwner;
      } else if (normalizedRole.contains('executiveviewerglobal') ||
          normalizedRole.contains('uyonetici')) {
        parsedRole = UserRole.executiveViewerGlobal;
      } else if (normalizedRole.contains('executiveviewerrestricted') ||
          normalizedRole == 'yonetici') {
        parsedRole = UserRole.executiveViewerRestricted;
      } else if (normalizedRole.contains('fieldauditor') ||
          normalizedRole.contains('sahadenetcisi') ||
          normalizedRole == 'user') {
        parsedRole = UserRole.fieldAuditor;
      } else if (normalizedRole.contains('yonetici') ||
          normalizedRole.contains('yönetici')) {
        parsedRole = UserRole.executiveViewerRestricted;
      }
    }

    return UserModel(
      id: (json['id'] ?? json['uid'] ?? username).toString(),
      username: username,
      displayName: displayName,
      role: parsedRole,
      authorizedLines: _parseStringList(
        json['authorizedLines'] ?? json['lines'] ?? json['authorized_lines'],
      ),
      authorizedStations: _parseStringList(
        json['authorizedStations'] ??
            json['stations'] ??
            json['authorized_stations'],
      ),
      password: json['password'] as String?,
      jobTitle: jobTitle,
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return const [];
  }
}
