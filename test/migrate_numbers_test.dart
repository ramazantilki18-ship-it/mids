import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:denetim_app/firebase_options.dart';

void main() {
  test('Migrate Audit and NC numbers', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {}

    final firestore = FirebaseFirestore.instance;

    print('--- Migrating Audits ---');
    final auditsSnap = await firestore.collection('audits').get();
    final audits = auditsSnap.docs;

    audits.sort((a, b) {
      final aDate = a.data()['date'] ?? a.data()['createdAt'];
      final bDate = b.data()['date'] ?? b.data()['createdAt'];
      DateTime aTime = DateTime.fromMillisecondsSinceEpoch(0);
      DateTime bTime = DateTime.fromMillisecondsSinceEpoch(0);
      if (aDate is Timestamp) aTime = aDate.toDate();
      if (bDate is Timestamp) bTime = bDate.toDate();
      return aTime.compareTo(bTime);
    });

    int auditCounter = 0;
    for (final doc in audits) {
      auditCounter++;
      final String auditNo = 'D-${auditCounter.toString().padLeft(5, '0')}';
      print('Audit ${doc.id} -> $auditNo');
      await firestore.collection('audits').doc(doc.id).update({'auditNo': auditNo});
    }

    print('--- Migrating Non-conformities ---');
    final ncSnap = await firestore.collection('nonconformities').get();
    final ncs = ncSnap.docs;

    ncs.sort((a, b) {
      final aDate = a.data()['createdAt'] ?? a.data()['date'];
      final bDate = b.data()['createdAt'] ?? b.data()['date'];
      DateTime aTime = DateTime.fromMillisecondsSinceEpoch(0);
      DateTime bTime = DateTime.fromMillisecondsSinceEpoch(0);
      if (aDate is Timestamp) aTime = aDate.toDate();
      if (bDate is Timestamp) bTime = bDate.toDate();
      return aTime.compareTo(bTime);
    });

    int ncCounter = 0;
    for (final doc in ncs) {
      ncCounter++;
      final String ncNo = 'U-${ncCounter.toString().padLeft(5, '0')}';
      print('NC ${doc.id} -> $ncNo');
      await firestore.collection('nonconformities').doc(doc.id).update({'ncNo': ncNo});
    }

    print('Setting counters in system_config/counters: auditCounter=$auditCounter, ncCounter=$ncCounter');
    await firestore.collection('system_config').doc('counters').set({
      'lastAuditNumber': auditCounter,
      'lastNcNumber': ncCounter,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print('SUCCESS: MIGRATION COMPLETED!');
  });
}
