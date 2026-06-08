import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'services/pdf_service.dart';
import 'data/mock_data.dart';
import 'dart:async';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _initDatabase();
  runApp(const AutoExportApp());
}

void _initDatabase() {
  try {
    if (kIsWeb) {
      final webFactory = _getWebFactory();
      if (webFactory != null) databaseFactory = webFactory;
    } else {
      _initDesktopFactory();
    }
  } catch (e) {
    debugPrint('Database init error: $e');
  }
}

DatabaseFactory? _getWebFactory() {
  try {
    return databaseFactoryFfiWeb;
  } catch (_) {
    return null;
  }
}

void _initDesktopFactory() {
  try {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  } catch (_) {}
}

class AutoExportApp extends StatefulWidget {
  const AutoExportApp({super.key});

  @override
  State<AutoExportApp> createState() => _AutoExportAppState();
}

class _AutoExportAppState extends State<AutoExportApp> {
  String _status = 'Başlatılıyor...';
  Color _color = Colors.grey;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), _doExport);
  }

  Future<void> _doExport() async {
    setState(() {
      _status = 'PDF oluşturuluyor...';
      _color = Colors.blue;
    });
    try {
      if (MockData.auditHistory.isEmpty) {
        setState(() {
          _status = 'Dışa aktarılacak denetim kaydı bulunamadı.';
          _color = Colors.orange;
        });
        return;
      }

      // Find first audit with photos
      final auditWithPhotos = MockData.auditHistory.firstWhere(
        (audit) => audit.answers.any((ans) => ans.allPhotoUrls.isNotEmpty),
        orElse: () => MockData.auditHistory.first,
      );
      
      debugPrint('AutoExport: Using audit ${auditWithPhotos.id} (photos: ${auditWithPhotos.answers.where((a) => a.allPhotoUrls.isNotEmpty).length} answers with photos)');
      
      await PdfService.exportAndShareAudit(auditWithPhotos);
      setState(() {
        _status = '✅ PDF başarıyla oluşturuldu!\nİndirme işlemi tarayıcınızda başlatıldı.';
        _color = Colors.green;
      });
    } catch (e, stack) {
      debugPrint('AutoExport: ERROR: $e\n$stack');
      setState(() {
        _status = '❌ Hata oluştu:\n$e\n\nDetaylar için konsolu kontrol edin.';
        _color = Colors.red;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Export Test',
      home: Scaffold(
        appBar: AppBar(title: const Text('PDF Export Test')),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _color == Colors.green ? Icons.check_circle : 
                  _color == Colors.red ? Icons.error : Icons.hourglass_empty,
                  size: 80,
                  color: _color,
                ),
                const SizedBox(height: 30),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                if (_color == Colors.red)
                  ElevatedButton(
                    onPressed: _doExport,
                    child: const Text('Tekrar Dene'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
