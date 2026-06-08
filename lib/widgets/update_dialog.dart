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
      UpdateService.instance.startOtaUpdate(widget.updateInfo.downloadUrl).listen(
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
    final textColor = Theme.of(context).colorScheme.onSurface;

    return PopScope(
      canPop: !_isDownloading, // İndirirken geri tuşuyla kapatmayı engelle
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).cardColor,
        title: Row(
          children: [
            Icon(Icons.system_update_rounded, color: Theme.of(context).primaryColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Güncelleme Mevcut!',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Uygulamanın yeni bir sürümü yayınlandı. Hemen yükleyerek güncel kalın.',
              style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.8), height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.12)),
              ),
              child: Column(
                children: [
                  _buildVersionRow('Mevcut Sürüm', widget.updateInfo.currentVersion),
                  const SizedBox(height: 6),
                  _buildVersionRow('Yeni Sürüm', widget.updateInfo.latestVersion),
                ],
              ),
            ),
            if (widget.updateInfo.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Yenilikler:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 100),
                child: SingleChildScrollView(
                  child: Text(
                    widget.updateInfo.releaseNotes,
                    style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.7)),
                  ),
                ),
              ),
            ],
            if (_isDownloading) ...[
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progressValue,
                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  _statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: _isDownloading
            ? null
            : [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('DAHA SONRA'),
                ),
                ElevatedButton(
                  onPressed: _startUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text(
                    'HEMEN GÜNCELLE',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
      ),
    );
  }

  Widget _buildVersionRow(String label, String version) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.6), fontWeight: FontWeight.w600)),
        Text(version, style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
