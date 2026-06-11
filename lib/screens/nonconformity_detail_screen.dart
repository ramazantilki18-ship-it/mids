import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/nonconformity_provider.dart';
import '../providers/audit_provider.dart';
import '../models/nonconformity_model.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../theme/app_colors.dart';
import '../services/storage_service.dart';

class NonconformityDetailScreen extends StatelessWidget {
  final String id;
  const NonconformityDetailScreen({super.key, required this.id});

  ImageProvider _getImageProvider(String path, {bool isThumbnail = true}) {
    if (path.startsWith('mock_')) {
      return NetworkImage(
          'https://picsum.photos/seed/${path.hashCode}/400/300');
    }
    final url = StorageService.imageUrlForPath(path);
    if (url != null) {
      return NetworkImage(
          StorageService.optimizedImageUrl(url, thumbnail: isThumbnail));
    }
    if (kIsWeb) return NetworkImage(path);
    return FileImage(File(path));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NonconformityProvider>();
    final auditProvider = context.watch<AuditProvider>();
    final user = context.watch<AuthProvider>().user;
    final isAdmin = user?.role == UserRole.superAdmin;

    // Check if NC still exists (important for after deletion)
    final ncIndex = provider.all.indexWhere((element) => element.id == id);
    if (ncIndex == -1) {
      return const Scaffold(
          body: Center(child: Text('Uygunsuzluk bulunamadı veya silindi.')));
    }
    final nc = provider.all[ncIndex];
    final matchingAuditIndex = auditProvider.auditHistory
        .indexWhere((audit) => audit.id == nc.auditId);
    final relatedAudit = matchingAuditIndex == -1
        ? null
        : auditProvider.auditHistory[matchingAuditIndex];

    if (user != null &&
        !user.canAccessNonconformity(
          line: relatedAudit?.line ?? nc.line,
          auditorId: relatedAudit?.auditorId,
          auditorName: nc.auditorName,
        )) {
      return const Scaffold(
        body: Center(child: Text('Bu kaydi goruntuleme yetkiniz yok.')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('UYGUNSUZLUK ANALİZİ',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        centerTitle: true,
        actions: [
          if (isAdmin)
            IconButton(
              icon:
                  const Icon(Icons.delete_forever_rounded, color: Colors.white),
              onPressed: () => _showDeleteConfirm(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildStatusHeader(nc, context),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildInfoCard(nc, context),
                  const SizedBox(height: 16),
                  _buildFindingCard(nc, context),
                  const SizedBox(height: 16),
                  if (nc.status == NonconformityStatus.completed)
                    _buildResolutionCard(nc, context)
                  else
                    _buildActionSection(context, nc),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uygunsuzluğu Sil'),
        content: const Text(
            'Bu uygunsuzluk kaydını kalıcı olarak silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal')),
          TextButton(
            onPressed: () async {
              await context
                  .read<NonconformityProvider>()
                  .deleteNonconformity(id);
              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                context.pop(); // Go back to list
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Uygunsuzluk silindi.'),
                      backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(NonconformityModel nc, BuildContext context) {
    final color = _getStatusColor(context, nc.status);
    final daysPassed = DateTime.now().difference(nc.detectionDate).inDays;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border(top: BorderSide(color: color, width: 4)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(_getStatusIcon(nc.status), color: color, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      nc.statusDisplayName.toUpperCase(),
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Tespit: ${nc.detectionDate.toString().substring(0, 10)}',
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Text(
                    '$daysPassed',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        height: 1),
                  ),
                  Text('GÜN GEÇTİ',
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                          fontSize: 8,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(NonconformityModel nc, BuildContext context) {
    return _buildCard(
      title: 'GENEL BİLGİLER',
      icon: Icons.info_outline_rounded,
      context: context,
      child: Column(
        children: [
          _buildDetailRow(
              Icons.person_pin_rounded, 'Denetçi', nc.auditorName, context),
          const Divider(height: 24, thickness: 0.5),
          _buildDetailRow(
              Icons.category_rounded, 'Kategori', nc.category, context),
          const Divider(height: 24, thickness: 0.5),
          _buildDetailRow(Icons.train_rounded, 'İstasyon', nc.station, context),
          const Divider(height: 24, thickness: 0.5),
          _buildDetailRow(Icons.star_rounded, 'Skor', '%${nc.score}', context,
              valueColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFF87171)
                  : const Color(0xFFE11D48)),
        ],
      ),
    );
  }

  Widget _buildFindingCard(NonconformityModel nc, BuildContext context) {
    return _buildCard(
      title: 'UYGUNSUZLUK AYRINTILARI',
      icon: Icons.search_rounded,
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SORU VE TESPİT:',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6))),
          const SizedBox(height: 8),
          Text(nc.questionText,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.4)),
          const SizedBox(height: 16),
          Text('DENETÇİ AÇIKLAMASI:',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6))),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
            child: Text(nc.auditorComment,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                    height: 1.5,
                    fontStyle: FontStyle.italic)),
          ),
          const SizedBox(height: 20),
          Text('TESPİT FOTOĞRAFLARI:',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6))),
          const SizedBox(height: 12),
          _buildPhotoGallery(nc.auditorPhotoPaths, context),
        ],
      ),
    );
  }

  Widget _buildResolutionCard(NonconformityModel nc, BuildContext context) {
    return _buildCard(
      title: 'ÇÖZÜM VE KAPATMA',
      icon: Icons.verified_rounded,
      accentColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF4ADE80)
          : const Color(0xFF16A34A),
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(Icons.event_available_rounded, 'Kapatma Tarihi',
              nc.closureDate?.toString().substring(0, 10) ?? '-', context,
              valueColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF4ADE80)
                  : const Color(0xFF16A34A)),
          const Divider(height: 24, thickness: 0.5),
          _buildDetailRow(Icons.person_rounded, 'Kapatan Kişi',
              (nc.closedByName != null && nc.closedByName!.isNotEmpty)
                  ? nc.closedByName!
                  : nc.auditorName.isNotEmpty ? nc.auditorName : '-',
              context,
              valueColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF60A5FA)
                  : const Color(0xFF3B82F6)),
          const Divider(height: 24, thickness: 0.5),
          _buildDetailRow(Icons.verified_user_rounded, 'Onaylayan Kişi',
              (nc.approvedByName != null && nc.approvedByName!.isNotEmpty && nc.approvedByName != '-')
                  ? nc.approvedByName!
                  : (nc.status == NonconformityStatus.completed ? 'Ramazan Tilki' : '-'),
              context,
              valueColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF4ADE80)
                  : const Color(0xFF16A34A)),
          const Divider(height: 24, thickness: 0.5),
          Text('DÜZELTME AÇIKLAMASI:',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6))),
          const SizedBox(height: 8),
          Text(nc.closureComment ?? 'Açıklama yok',
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.5)),
          const SizedBox(height: 20),
          _buildPhotoGallery(nc.closurePhotoPaths, context),
        ],
      ),
    );
  }

  Widget _buildActionSection(BuildContext context, NonconformityModel nc) {
    final authProvider = context.read<AuthProvider>();

    // Role based check
    final isCoordinator = authProvider.hasPermission('nc_approve');
    final isSahaRole = authProvider.hasPermission('nc_close');

    if (nc.status == NonconformityStatus.waitingControl) {
      return Column(
        children: [
          _buildResolutionCard(nc, context),
          const SizedBox(height: 16),
          if (isCoordinator)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final userName = context.read<AuthProvider>().user?.name ?? '';
                      context
                          .read<NonconformityProvider>()
                          .approveNonconformity(nc.id, approvedByName: userName);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Uygunsuzluk onaylandı ve kapatıldı.'),
                          backgroundColor: Colors.green));
                      context.pop();
                    },
                    icon: const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 20),
                    label: const Text('ONAYLA',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context
                          .read<NonconformityProvider>()
                          .rejectNonconformity(nc.id);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Çözüm reddedildi, tekrar açıldı.'),
                          backgroundColor: Colors.red));
                      context.pop();
                    },
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
                    label: const Text('REDDET',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFB923C)
                        : const Color(0xFFEA580C))
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFFB923C)
                            : const Color(0xFFEA580C))
                        .withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFB923C)
                          : const Color(0xFFEA580C)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bu uygunsuzluk Onaylayıcı onayı beklemektedir.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFFB923C)
                              : const Color(0xFFEA580C),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    if (isSahaRole &&
        (nc.status == NonconformityStatus.open ||
            nc.status == NonconformityStatus.overdue ||
            nc.status == NonconformityStatus.inProgress)) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final btnFgColor = isDark ? Colors.black87 : Colors.white;
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => context.push('/close-nonconformity/${nc.id}'),
          icon: Icon(Icons.check_circle_rounded, color: btnFgColor, size: 20),
          label: Text('ÇÖZÜMÜ KONTROLE GÖNDER',
              style: TextStyle(
                  color: btnFgColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 14)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            shadowColor: Theme.of(context).primaryColor.withValues(alpha: 0.3),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCard(
      {required String title,
      required IconData icon,
      required Widget child,
      required BuildContext context,
      Color? accentColor}) {
    final color = accentColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF60A5FA)
            : AppColors.primary);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      IconData icon, String label, String value, BuildContext context,
      {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: valueColor ?? Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 13)),
      ],
    );
  }

  Widget _buildPhotoGallery(List<String> paths, BuildContext context) {
    if (paths.isEmpty) {
      return Text('Fotoğraf eklenmemiş',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 12));
    }
    return SizedBox(
      height: 124,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        itemBuilder: (context, index) {
          final path = paths[index];
          return GestureDetector(
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
              width: 168,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).scaffoldBackgroundColor,
                image: DecorationImage(
                    image: _getImageProvider(path), fit: BoxFit.contain),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(BuildContext context, NonconformityStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case NonconformityStatus.open:
        return isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
      case NonconformityStatus.overdue:
        return isDark ? const Color(0xFFF87171) : const Color(0xFFE11D48);
      case NonconformityStatus.waitingControl:
        return isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);
      case NonconformityStatus.completed:
        return isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
      case NonconformityStatus.inProgress:
        return isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C);
    }
  }

  IconData _getStatusIcon(NonconformityStatus status) {
    switch (status) {
      case NonconformityStatus.open:
        return Icons.error_outline_rounded;
      case NonconformityStatus.overdue:
        return Icons.timer_off_outlined;
      case NonconformityStatus.waitingControl:
        return Icons.sync_rounded;
      case NonconformityStatus.completed:
        return Icons.verified_user_outlined;
      case NonconformityStatus.inProgress:
        return Icons.sync_rounded;
    }
  }
}
