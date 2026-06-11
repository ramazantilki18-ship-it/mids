import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/nonconformity_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../services/storage_service.dart';
import 'package:image_picker/image_picker.dart';

class CloseNonconformityScreen extends StatefulWidget {
  final String id;
  const CloseNonconformityScreen({super.key, required this.id});

  @override
  State<CloseNonconformityScreen> createState() => _CloseNonconformityScreenState();
}

class _CloseNonconformityScreenState extends State<CloseNonconformityScreen> {
  final _commentController = TextEditingController();
  final List<String> _photoPaths = [];
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 50,
        maxWidth: 1080,
      );
      if (!mounted) return;
      if (photo != null) {
        setState(() => _photoPaths.add(photo.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fotoğraf eklenemedi: $e')),
      );
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: Theme.of(context).primaryColor),
              title: const Text('Fotoğraf Çek'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: Theme.of(context).primaryColor),
              title: const Text('Galeriden Seç'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (const bool.fromEnvironment('dart.vm.product') == false)
              ListTile(
                leading: const Icon(Icons.bug_report_rounded, color: Colors.orange),
                title: const Text('Test Fotoğrafı Ekle (Mock)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _photoPaths.add('mock_${DateTime.now().millisecondsSinceEpoch}'));
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleClose() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen açıklama girin.')));
      return;
    }
    
    // FOTOĞRAF ZORUNLU KONTROLÜ
    if (_photoPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hata: Uygunsuzluğu kapatmak için en az 1 adet çözüm kanıt fotoğrafı eklemelisiniz!'),
          backgroundColor: Colors.red,
        )
      );
      return;
    }

    try {
      final userName = context.read<AuthProvider>().user?.name ?? '';
      await context.read<NonconformityProvider>().closeNonconformity(widget.id, _commentController.text, _photoPaths, closedByName: userName);
      if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uygunsuzluk kontrol için gönderildi.'), backgroundColor: Colors.orange)
    );
    
      context.pop();
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fotoğraf yüklenemedi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  ImageProvider _getImageProvider(String path, {bool isThumbnail = true}) {
    if (path.startsWith('http')) {
      return NetworkImage(StorageService.optimizedImageUrl(path, thumbnail: isThumbnail));
    }
    if (path.startsWith('mock_')) {
      return NetworkImage('https://picsum.photos/seed/${path.hashCode}/300/200');
    }
    if (kIsWeb) {
      return NetworkImage(path); // Web'de Blob URL'leri NetworkImage ile çalışabilir
    }
    return FileImage(File(path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uygunsuzluk Kapatma')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Uygunsuzluk Kapatma İşlemi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Uygunsuzluğu kapatmak için yapılan işlemi ve çözüm kanıtlarını ekleyin.', style: TextStyle(color: AppColors.textGrey)),
            const SizedBox(height: 32),

            const Text('Açıklama *', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                border: const OutlineInputBorder(), 
                hintText: 'Lütfen Açıklama Giriniz',
                fillColor: Theme.of(context).cardColor,
                filled: true,
              ),
            ),
            const SizedBox(height: 24),

            const Row(
              children: [
                Text('Çözüm Kanıt Fotoğrafları *', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 8),
                Text('(Zorunlu)', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _showPhotoOptions,
              child: Container(
                height: 96,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.3), style: BorderStyle.solid), 
                  borderRadius: BorderRadius.circular(16), 
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.03)
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: [
                    Icon(Icons.add_a_photo_rounded, size: 40, color: Theme.of(context).primaryColor.withValues(alpha: 0.6)), 
                    const SizedBox(height: 10), 
                    Text('Kamerayı Aç veya Galeriden Seç', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600))
                  ]
                ),
              ),
            ),
            if (_photoPaths.isNotEmpty) ...[
              const SizedBox(height: 20),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photoPaths.length,
                  itemBuilder: (context, index) {
                    final path = _photoPaths[index];
                    return Stack(
                      children: [
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                backgroundColor: Colors.transparent,
                                insetPadding: EdgeInsets.zero,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Container(
                                      color: Colors.black.withValues(alpha: 0.9),
                                      child: InteractiveViewer(
                                        panEnabled: true,
                                        minScale: 0.5,
                                        maxScale: 4,
                                        child: Image(image: _getImageProvider(path, isThumbnail: false), fit: BoxFit.contain),
                                      ),
                                    ),
                                    Positioned(
                                      top: 40,
                                      right: 20,
                                      child: IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 96,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
                              color: Theme.of(context).scaffoldBackgroundColor,
                              image: DecorationImage(
                                image: _getImageProvider(path),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 16,
                          child: InkWell(
                            onTap: () => setState(() => _photoPaths.removeAt(index)),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _handleClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: const Text('KONTROLE GÖNDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
