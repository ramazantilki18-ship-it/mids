import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupService {
  static Future<void> exportData() async {
    final firestore = FirebaseFirestore.instance;
    Map<String, dynamic> backupData = {};

    List<String> collections = ['audits', 'nonconformities', 'users', 'stations', 'lines', 'questions'];

    for (var col in collections) {
      final snapshot = await firestore.collection(col).get();
      backupData[col] = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    }

    final jsonString = jsonEncode(backupData);
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/kurumsal_denetim_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    
    await file.writeAsString(jsonString);
    
    // Share the file
    await Share.shareXFiles([XFile(file.path)], text: 'Metro İstanbul Denetim Sistemi Veri Yedeği');
  }

  static Future<void> importData(String jsonContent) async {
    final Map<String, dynamic> data = jsonDecode(jsonContent);
    final firestore = FirebaseFirestore.instance;

    for (var col in data.keys) {
      final List<dynamic> docs = data[col];
      for (var doc in docs) {
        final id = doc['id'];
        final Map<String, dynamic> docData = Map<String, dynamic>.from(doc);
        docData.remove('id');
        await firestore.collection(col).doc(id).set(docData);
      }
    }
  }
}
