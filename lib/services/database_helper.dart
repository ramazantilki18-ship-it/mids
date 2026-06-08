import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io' show Platform, Directory;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import '../models/audit_model.dart';
import '../models/task_model.dart';
import '../models/nonconformity_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (kIsWeb) {
      throw Exception('Database is not supported on Web. Use Firestore or In-Memory storage.');
    }
    if (_database != null) return _database!;
    _database = await _initDB('denetim.db');
    return _database!;
  }

  Future<void> resetDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'denetim.db');
    await deleteDatabase(path);
  }

  Future<Database> _initDB(String filePath) async {
    try {
      if (!kIsWeb && Platform.isWindows) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      final dbPath = await getDatabasesPath();
      
      // Dizin yoksa oluştur (Windows'ta bazen gerekebiliyor)
      final dir = Directory(dbPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final path = join(dbPath, filePath);
      print('Database path: $path');

      return await openDatabase(
        path,
        version: 7,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    } catch (e) {
      print('DATABASE INITIALIZATION ERROR: $e');
      rethrow;
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE audits (
        id TEXT PRIMARY KEY,
        line TEXT,
        station TEXT,
        date TEXT,
        auditorId TEXT,
        auditorName TEXT,
        auditType TEXT,
        score REAL,
        isCompleted INTEGER DEFAULT 0,
        answers TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT,
        description TEXT,
        assignedTitle TEXT,
        assignedUserId TEXT,
        targetLine TEXT,
        targetStations TEXT,
        startDate TEXT,
        dueDate TEXT,
        taskType TEXT,
        isCompleted INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE nonconformities (
        id TEXT PRIMARY KEY,
        auditId TEXT,
        auditTypeId TEXT,
        auditType TEXT,
        questionId TEXT,
        questionText TEXT,
        category TEXT,
        line TEXT,
        station TEXT,
        score INTEGER,
        auditorComment TEXT,
        auditorPhotoPaths TEXT,
        detectionDate TEXT,
        auditorName TEXT,
        responsiblePerson TEXT,
        status TEXT,
        closureDate TEXT,
        closureComment TEXT,
        closurePhotoPaths TEXT
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Sürüm 4'ten küçükse, tabloları yeniden oluştur (veri kaybı olabilir)
    if (oldVersion < 4) {
      await db.execute('DROP TABLE IF EXISTS audits');
      await db.execute('DROP TABLE IF EXISTS tasks');
      await db.execute('DROP TABLE IF EXISTS nonconformities');
      await _createDB(db, newVersion);
    }
    
    // Sürüm 5: audits tablosuna isCompleted alanı ekle (veri kaybı yok)
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE audits ADD COLUMN isCompleted INTEGER DEFAULT 0');
      } catch (e) {
        // Alan zaten varsa hata vermesini önle
        print('isCompleted alanı eklenirken hata (muhtemelen zaten var): $e');
      }
    }

    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE nonconformities ADD COLUMN auditTypeId TEXT');
      } catch (e) {
        print('auditTypeId alani eklenirken hata (muhtemelen zaten var): $e');
      }
      try {
        await db.execute('ALTER TABLE nonconformities ADD COLUMN auditType TEXT');
      } catch (e) {
        print('auditType alani eklenirken hata (muhtemelen zaten var): $e');
      }
    }
  }

  // AUDITS
  Future<void> insertAudit(AuditModel audit) async {
    final db = await instance.database;
    await db.insert('audits', {
      'id': audit.id,
      'line': audit.line,
      'station': audit.station,
      'date': audit.date.toIso8601String(),
      'auditorId': audit.auditorId,
      'auditorName': audit.auditorName,
      'auditType': audit.auditType,
      'score': audit.score,
      'isCompleted': audit.isCompleted ? 1 : 0,
      'answers': jsonEncode(audit.answers.map((e) => e.toJson()).toList()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static String? lastParseError;

  Future<List<AuditModel>> getAudits() async {
    final db = await instance.database;
    final result = await db.query('audits');
    
    List<AuditModel> parsedAudits = [];
    for (var json in result) {
      try {
        final answersJson = jsonDecode(json['answers'] as String) as List;
        parsedAudits.add(AuditModel(
          id: json['id'] as String,
          line: json['line'] as String,
          station: json['station'] as String,
          date: DateTime.parse(json['date'] as String),
          auditorId: json['auditorId'] as String,
          auditorName: json['auditorName'] as String,
          auditType: json['auditType'] as String,
          score: (json['score'] as num).toDouble(),
          isCompleted: (json['isCompleted'] as int? ?? 0) == 1,
          answers: answersJson.map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            return AuditAnswer.fromJson(map);
          }).toList(),
        ));
      } catch (e, stack) {
        lastParseError = 'ID: ${json['id']} -> $e\n$stack';
        print('Error parsing audit row: ${json['id']} -> $e');
      }
    }
    return parsedAudits;
  }

  Future<void> deleteAudit(String id) async {
    final db = await instance.database;
    await db.delete('audits', where: 'id = ?', whereArgs: [id]);
  }

  // TASKS
  Future<void> insertTask(TaskModel task) async {
    final db = await instance.database;
    await db.insert('tasks', {
      'id': task.id,
      'title': task.title,
      'description': task.description,
      'assignedTitle': task.assignedTitle,
      'assignedUserId': task.assignedUserId,
      'targetLine': task.targetLine,
      'targetStations': jsonEncode(task.targetStations),
      'startDate': task.startDate.toIso8601String(),
      'dueDate': task.dueDate.toIso8601String(),
      'taskType': task.taskType,
      'isCompleted': task.isCompleted ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TaskModel>> getTasks() async {
    final db = await instance.database;
    final result = await db.query('tasks');
    
    List<TaskModel> parsedTasks = [];
    for (var json in result) {
      try {
        parsedTasks.add(TaskModel(
          id: json['id'] as String,
          title: json['title'] as String,
          description: json['description'] as String,
          assignedTitle: json['assignedTitle'] as String,
          assignedUserId: json['assignedUserId'] as String?,
          targetLine: json['targetLine'] as String,
          targetStations: (jsonDecode(json['targetStations'] as String) as List).cast<String>(),
          startDate: DateTime.parse(json['startDate'] as String),
          dueDate: DateTime.parse(json['dueDate'] as String),
          taskType: json['taskType'] as String,
          isCompleted: (json['isCompleted'] as int) == 1,
        ));
      } catch (e) {
        print('Error parsing Task row: ${json['id']} -> $e');
      }
    }
    return parsedTasks;
  }

  Future<void> removeTask(String id) async {
    final db = await instance.database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // NONCONFORMITIES
  Future<void> insertNonconformity(NonconformityModel nc) async {
    final db = await instance.database;
    await db.insert('nonconformities', {
      'id': nc.id,
      'auditId': nc.auditId,
      'auditTypeId': nc.auditTypeId,
      'auditType': nc.auditType,
      'questionId': nc.questionId,
      'questionText': nc.questionText,
      'category': nc.category,
      'line': nc.line,
      'station': nc.station,
      'score': nc.score,
      'auditorComment': nc.auditorComment,
      'auditorPhotoPaths': jsonEncode(nc.auditorPhotoPaths),
      'detectionDate': nc.detectionDate.toIso8601String(),
      'auditorName': nc.auditorName,
      'responsiblePerson': nc.responsiblePerson,
      'status': nc.status.name,
      'closureDate': nc.closureDate?.toIso8601String(),
      'closureComment': nc.closureComment,
      'closurePhotoPaths': jsonEncode(nc.closurePhotoPaths),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<NonconformityModel>> getNonconformities() async {
    final db = await instance.database;
    final result = await db.query('nonconformities');
    
    List<NonconformityModel> parsedNCs = [];
    for (var json in result) {
      try {
        parsedNCs.add(NonconformityModel(
          id: json['id'] as String,
          auditId: json['auditId'] as String,
          auditTypeId: json['auditTypeId'] as String? ?? '',
          auditType: json['auditType'] as String? ?? '',
          questionId: json['questionId'] as String,
          questionText: json['questionText'] as String,
          category: json['category'] as String,
          line: json['line'] as String,
          station: json['station'] as String,
          score: json['score'] as int,
          auditorComment: json['auditorComment'] as String,
          auditorPhotoPaths: (jsonDecode(json['auditorPhotoPaths'] as String) as List).cast<String>(),
          detectionDate: DateTime.parse(json['detectionDate'] as String),
          auditorName: json['auditorName'] as String,
          responsiblePerson: json['responsiblePerson'] as String,
          status: NonconformityStatus.values.firstWhere((e) => e.name == json['status']),
          closureDate: json['closureDate'] != null ? DateTime.parse(json['closureDate'] as String) : null,
          closureComment: json['closureComment'] as String?,
          closurePhotoPaths: (jsonDecode(json['closurePhotoPaths'] as String) as List).cast<String>(),
        ));
      } catch (e) {
        print('Error parsing NC row: ${json['id']} -> $e');
      }
    }
    return parsedNCs;
  }
}
