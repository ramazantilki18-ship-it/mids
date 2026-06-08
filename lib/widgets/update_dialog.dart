import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import '../services/update_service.dart';
import '../theme/app_colors.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  const UpdateDialog({super.key, required this.updateInfo});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  String _progress = '0';
  String _statusText = '';
  double _progressValue = 0.0;

  void _startUpdate() {
    setState(() {
      _isDownloading = true;
      _statusText = 'Güncelleme indiriliyor...';
    });

    try {
      final cleanVersion = widget.updateInfo.latestVersion.replaceAll('.', '_').replaceAll('+', '_');
      final filename = 'app_$cleanVersion.apk';
      UpdateService.instance.startOtaUpdate(widget.updateInfo.downloadUrl, filename: filename).listen(
        (OtaEvent event) {
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              final intVal = int.tryParse(event.value ?? '0') ?? 0;
              setState(() {
                _progress = event.value ?? '0';
                _progressValue = intVal / 100.0;
                _statusText = 'İndiriliyor: %$_progress';
              });
              break;
            case OtaStatus.INSTALLING:
              setState(() {
                _statusText = 'Yükleyici başlatılıyor...';
              });
              // Dialog penceresini otomatik kapat (kurulum ekranına geçiliyor)
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) Navigator.pop(context);
              });
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              setState(() {
                _isDownloading = false;
                _statusText = 'Yükleme izni verilmedi.';
              });
              _showErrorSnackBar('Lütfen bilinmeyen kaynaklardan yükleme izni verin.');
              break;
            case OtaStatus.DOWNLOAD_ERROR:
            case OtaStatus.INTERNAL_ERROR:
            default:
              setState(() {
                _isDownloading = false;
                _statusText = 'İndirme sırasında hata oluştu.';
              });
              _showErrorSnackBar('İndirme başarısız oldu. Lütfen tekrar deneyin.');
              break;
          }
        },
        onError: (err) {
          setState(() {
            _isDownloading = false;
            _statusText = 'Hata: $err';
          });
          _showErrorSnackBar('Güncelleme sırasında bir hata oluştu.');
        },
      );
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _statusText = 'Hata: $e';
      });
      _showErrorSnackBar('OTA Yükleyici başlatılamadı.');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accentRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final surfaceColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return PopScope(
      canPop: !_isDownloading, // İndirirken geri tuşuyla kapatmayı engelle
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Üst Alan - Modern Degrade Tasarım
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor,
                      primaryColor.withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    // Parlayan Güncelleme İkonu
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.system_update_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Güncelleme Mevcut!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // İçerik Alanı
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uygulamanın yeni bir sürümü yayınlandı. Hemen yükleyerek güncel ve kararlı kalın.',
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor.withValues(alpha: 0.75),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Sürüm Karşılaştırma Kutuları
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Mevcut Sürüm',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textColor.withValues(alpha: 0.5),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.updateInfo.currentVersion,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textColor.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: primaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Yeni Sürüm',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.updateInfo.latestVersion,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (widget.updateInfo.releaseNotes.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Yenilikler:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: textColor.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 90),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                          ),
                        ),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Text(
                            widget.updateInfo.releaseNotes,
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withValues(alpha: 0.65),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (_isDownloading) ...[
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _statusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          Text(
                            '%$_progress',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progressValue,
                          backgroundColor: primaryColor.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Butonlar
              if (!_isDownloading)
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.1),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'DAHA SONRA',
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.6),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _startUpdate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'GÜNCELLE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
