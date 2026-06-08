import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

import '../providers/system_provider.dart';
import '../providers/audit_provider.dart';
import '../widgets/feedback_submission_sheet.dart';
import '../models/user_model.dart';

import '../models/task_model.dart';
import '../models/announcement_model.dart';
import '../theme/app_colors.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../widgets/metro_brand_header.dart';
import '../widgets/audit_type_selector.dart';
import '../widgets/manager_monthly_stats_widget.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _announcementRefreshTimer;
  String? _selectedLine;
  String? _selectedStation;
  String? _selectedAuditTypeId;

  @override
  void initState() {
    super.initState();
    _announcementRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdates();
    });
  }

  Future<void> _checkUpdates() async {
    if (kIsWeb) return;
    final updateInfo = await UpdateService.instance.checkForUpdate();
    if (updateInfo.isAvailable && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => UpdateDialog(updateInfo: updateInfo),
      );
    }
  }

  @override
  void dispose() {
    _announcementRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final systemProvider = context.watch<SystemProvider>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final auditProvider = context.watch<AuditProvider>();

    final activeAnnouncements = systemProvider.activeAnnouncementsForUser(user);

    // Filter tasks for the current user, uncompleted, and in the current month
    final now = DateTime.now();
    final myCurrentMonthTasks = systemProvider.tasks.where((t) {
      final isAssigned =
          t.assignedUserId == user.id || t.assignedTitle == user.title;
      final isUncompleted = !t.isCompleted;
      final isCurrentMonth =
          t.dueDate.month == now.month && t.dueDate.year == now.year;
      return isAssigned && isUncompleted && isCurrentMonth;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, MediaQuery.of(context).padding.top + 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPremiumTopHeader(context, user, systemProvider),

            const SizedBox(height: 24),

            _buildAnnouncementPanel(context, activeAnnouncements),

            const SizedBox(height: 24),

            if (user.role == UserRole.executiveViewerGlobal ||
                user.role == UserRole.executiveViewerRestricted)
              const ManagerMonthlyStatsWidget()
            else
              _buildPlannedTasksPanel(context, myCurrentMonthTasks),

            const SizedBox(height: 24),

            // Denetim Başlat / Devam Et Butonları
            if (auditProvider.currentAudit != null &&
                !auditProvider.currentAudit!.isCompleted) ...[
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.accentGreen,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentGreen.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Row(
                    children: [
                      // Sol Taraf: Devam Et
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => context.push('/audit-questions'),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 11),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.play_circle_fill_rounded,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'AKTİF DENETİME DEVAM ET',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Dikey Ayırıcı Çizgi
                      Container(
                        width: 1,
                        height: 20,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      // Sağ Taraf: İptal Et (Çöp Kutusu)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Denetimi İptal Et'),
                                content: const Text(
                                    'Aktif denetim taslağınız silinecektir. Bu işlem geri alınamaz. Devam etmek istiyor musunuz?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                    child: const Text('VAZGEÇ'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accentRed,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('DENETİMİ SİL'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              auditProvider.clearDraft();
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 11),
                            child: Icon(
                              Icons.delete_forever_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (user.role != UserRole.executiveViewerGlobal &&
                user.role != UserRole.executiveViewerRestricted)
              _buildEmbeddedStartAuditForm(
                  context, user, systemProvider, auditProvider),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumTopHeader(
      BuildContext context, UserModel user, SystemProvider systemProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final greeting = _getGreeting();
    final surface = Theme.of(context).cardColor;
    final primaryText = Theme.of(context).colorScheme.onSurface;
    final mutedText = primaryText.withValues(alpha: 0.62);

    Widget buildActionButton({
      required IconData icon,
      required Color color,
      required VoidCallback onTap,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .primaryColor
                  .withValues(alpha: isDark ? 0.18 : 0.06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Theme.of(context)
                    .primaryColor
                    .withValues(alpha: isDark ? 0.24 : 0.10),
              ),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
        ),
      );
    }

    final brandHeader = MetroBrandHeader(
      logoWidth: 126,
      titleFontSize: 10.5,
      titleColor: isDark ? Colors.white70 : const Color(0xFF001E61),
      compact: true,
      framed: false,
    );

    final dateChip = Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .primaryColor
            .withValues(alpha: isDark ? 0.18 : 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context)
              .primaryColor
              .withValues(alpha: isDark ? 0.24 : 0.10),
        ),
      ),
      child: Text(
        DateFormat('dd MMM yyyy, HH:mm', 'tr_TR').format(now),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );

    final actionButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildActionButton(
          icon: systemProvider.isDarkMode
              ? Icons.light_mode_rounded
              : Icons.dark_mode_rounded,
          color: Theme.of(context).primaryColor,
          onTap: systemProvider.toggleTheme,
        ),
        const SizedBox(width: 8),
        buildActionButton(
          icon: Icons.bug_report_rounded,
          color: isDark ? const Color(0xFFFB923C) : AppColors.accentOrange,
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const FeedbackSubmissionSheet(),
            );
          },
        ),
        const SizedBox(width: 8),
        buildActionButton(
          icon: Icons.lock_reset_rounded,
          color: Theme.of(context).primaryColor,
          onTap: () => context.push('/change-password'),
        ),
        const SizedBox(width: 8),
        buildActionButton(
          icon: Icons.logout_rounded,
          color: AppColors.accentRed,
          onTap: () async {
            await context.read<AuthProvider>().logout();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context)
              .primaryColor
              .withValues(alpha: isDark ? 0.24 : 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context)
                .primaryColor
                .withValues(alpha: isDark ? 0.18 : 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 360;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSmall) ...[
                Center(child: brandHeader),
                const SizedBox(height: 10),
                Center(child: actionButtons),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    brandHeader,
                    actionButtons,
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                '$greeting | ${user.username}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: mutedText,
                ),
              ),
              const SizedBox(height: 6),
              Center(child: dateChip),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAnnouncementPanel(
      BuildContext context, List<AnnouncementModel> announcements) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final surface = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final borderColor = primary.withValues(alpha: isDark ? 0.26 : 0.14);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.14 : 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Duyurular',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (announcements.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: isDark ? 0.12 : 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: primary.withValues(alpha: isDark ? 0.18 : 0.08)),
              ),
              child: Text(
                'Şu anda hattınız için aktif bir duyuru bulunmuyor.',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            )
          else
            ...announcements.take(3).map((announcement) =>
                _buildAnnouncementItem(context, announcement)),
          if (announcements.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+${announcements.length - 3} duyuru daha',
                style: TextStyle(
                  color: primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlannedTasksPanel(BuildContext context, List<TaskModel> tasks) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final surface = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final borderColor = primary.withValues(alpha: isDark ? 0.26 : 0.14);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.14 : 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Planlanan Görevler',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bu Ayki Planlanan Denetimleriniz',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.58),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${tasks.length} Görev',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (tasks.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: isDark ? 0.12 : 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: primary.withValues(alpha: isDark ? 0.18 : 0.08)),
              ),
              child: Text(
                'Bu ay için planlanmış aktif bir göreviniz bulunmuyor.',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _buildTaskItem(context, task);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, TaskModel task) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: textColor.withValues(alpha: isDark ? 0.10 : 0.07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${task.targetLine} | ${task.targetStations.join(', ')}',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Son Tarih: ${DateFormat('dd.MM.yyyy').format(task.dueDate)}',
                  style: const TextStyle(
                    color: AppColors.accentRed,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () async {
              final systemProvider = context.read<SystemProvider>();
              final auditProvider = context.read<AuditProvider>();
              final authProvider = context.read<AuthProvider>();
              final user = authProvider.user;

              // Find audit type from task
              final activeAuditTypes = systemProvider.auditTypes
                  .where((type) => type.isActive && !type.isDeleted)
                  .toList();
              final matchingType = activeAuditTypes
                  .where((t) => t.id == task.auditTypeId)
                  .toList();
              if (matchingType.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Denetim tipi bulunamadı.')),
                  );
                }
                return;
              }
              final selectedAuditType = matchingType.first;
              final auditQuestions =
                  systemProvider.questionsForAuditType(selectedAuditType);
              if (auditQuestions.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Bu denetim tipi için aktif soru bulunamadı.')),
                  );
                }
                return;
              }

              final station = task.targetStations.isNotEmpty
                  ? task.targetStations.first
                  : null;
              if (station == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Görevde istasyon tanımlanmamış.')),
                  );
                }
                return;
              }

              // Check for active audit
              if (auditProvider.currentAudit != null &&
                  !auditProvider.currentAudit!.isCompleted) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Aktif Denetim Var',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    content: const Text(
                        'Yarım kalmış aktif bir denetiminiz bulunuyor. Yeni bir denetim başlatırsanız mevcut denetim kaybolacaktır. Devam etmek istiyor musunuz?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('İPTAL'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentRed,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('YENİ DENETİM BAŞLAT'),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
              }

              auditProvider.startNewAudit(
                line: task.targetLine,
                station: station,
                auditorId: user?.id ?? '1',
                auditorName: user?.name ?? 'Kullanıcı',
                auditType: selectedAuditType.title,
                questions: auditQuestions,
                auditTypeConfig: selectedAuditType,
                taskId: task.id,
              );
              if (context.mounted) {
                context.push('/audit-questions');
              }
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            label: const Text(
              'DENETLE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGreen,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementItem(
      BuildContext context, AnnouncementModel announcement) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final lineLabel = announcement.targetLines.isEmpty
        ? 'Tüm Hatlar'
        : announcement.targetLines.join(', ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: textColor.withValues(alpha: isDark ? 0.10 : 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  announcement.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Aktif',
                  style: TextStyle(
                    color: AppColors.accentGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            announcement.message,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildAnnouncementMetaChip(
                context,
                Icons.route_rounded,
                lineLabel,
              ),
              _buildAnnouncementMetaChip(
                context,
                Icons.schedule_rounded,
                DateFormat('dd.MM HH:mm', 'tr_TR').format(announcement.endAt),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementMetaChip(
      BuildContext context, IconData icon, String text) {
    final color = Theme.of(context).primaryColor;
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Günaydın';
    if (hour < 17) return 'İyi günler';
    return 'İyi akşamlar';
  }

  Widget _buildEmbeddedStartAuditForm(BuildContext context, UserModel user,
      SystemProvider system, AuditProvider auditProvider) {
    final hasGlobalLineAccess = user.hasGlobalLineAccess;
    final visibleLines = ((hasGlobalLineAccess)
        ? List<String>.from(system.lines)
        : system.lines.where(user.canAccessLine).toList())
      ..sort(_compareTurkish);
    final selectedLineValue =
        visibleLines.contains(_selectedLine) ? _selectedLine : null;
    final selectedStations = selectedLineValue != null
        ? (system.stations[selectedLineValue] ?? <String>[])
        : <String>[];
    final visibleStations = ((hasGlobalLineAccess ||
            user.authorizedStations.isEmpty)
        ? List<String>.from(selectedStations)
        : selectedStations
            .where((station) => user.authorizedStations.contains(station))
            .toList())
      ..sort(_compareTurkish);
    final selectedStationValue =
        visibleStations.contains(_selectedStation) ? _selectedStation : null;

    final activeAuditTypes = system.auditTypes
        .where((type) => type.isActive && !type.isDeleted)
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    if (_selectedAuditTypeId == null && activeAuditTypes.isNotEmpty) {
      _selectedAuditTypeId = activeAuditTypes.first.id;
    }
    if (_selectedAuditTypeId != null &&
        activeAuditTypes.isNotEmpty &&
        !activeAuditTypes.any((t) => t.id == _selectedAuditTypeId)) {
      _selectedAuditTypeId = activeAuditTypes.first.id;
    }
    final selectedAuditTypeValue =
        activeAuditTypes.any((t) => t.id == _selectedAuditTypeId)
            ? _selectedAuditTypeId
            : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.24
                  : 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.14
                    : 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yeni Denetim Başlat',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedLineValue,
            dropdownColor: Theme.of(context).cardTheme.color,
            decoration: _inputDecoration(),
            hint: Text(
              'Hat seçin',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
            items: visibleLines
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (val) {
              setState(() {
                _selectedLine = val;
                _selectedStation = null;
              });
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedStationValue,
            dropdownColor: Theme.of(context).cardTheme.color,
            decoration: _inputDecoration(),
            hint: Text(
              'İstasyon seçin',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
            items: visibleStations
                .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                .toList(),
            onChanged: (val) => setState(() => _selectedStation = val),
          ),
          const SizedBox(height: 10),
          _buildDropdownLabel('Denetim Tipi'),
          AuditTypeSelector(
            auditTypes: activeAuditTypes,
            selectedAuditTypeId: selectedAuditTypeValue,
            onChanged: (val) => setState(() => _selectedAuditTypeId = val),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: (selectedLineValue != null &&
                      selectedStationValue != null &&
                      selectedAuditTypeValue != null)
                  ? () async {
                      final line = selectedLineValue;
                      final station = selectedStationValue;
                      final auditTypeId = selectedAuditTypeValue;

                      final selectedAuditType = activeAuditTypes.firstWhere(
                        (t) => t.id == auditTypeId,
                        orElse: () => activeAuditTypes.first,
                      );
                      final auditQuestions =
                          system.questionsForAuditType(selectedAuditType);
                      if (auditQuestions.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Seçili denetim tipi için aktif soru bulunamadı.')),
                        );
                        return;
                      }

                      if (auditProvider.currentAudit != null &&
                          !auditProvider.currentAudit!.isCompleted) {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Aktif Denetim Var',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            content: const Text(
                                'Yarım kalmış aktif bir denetiminiz bulunuyor. Yeni bir denetim başlatırsanız mevcut denetim kaybolacaktır. Yine de devam etmek istiyor musunuz?'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('İPTAL'),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentRed,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('YENİ DENETİM BAŞLAT'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                      }

                      auditProvider.startNewAudit(
                        line: line,
                        station: station,
                        auditorId: user.id,
                        auditorName: user.name,
                        auditType: selectedAuditType.title,
                        questions: auditQuestions,
                        auditTypeConfig: selectedAuditType,
                      );
                      if (context.mounted) {
                        context.push('/audit-questions');
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              child: const Text('DENETİME BAŞLA',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1.2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4),
      child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
    );
  }

  InputDecoration _inputDecoration() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: Theme.of(context)
              .primaryColor
              .withValues(alpha: isDark ? 0.35 : 0.18),
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: Theme.of(context)
              .primaryColor
              .withValues(alpha: isDark ? 0.35 : 0.18),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: Theme.of(context).primaryColor,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  int _compareTurkish(String a, String b) {
    const turkishAlphabet = 'abcçdefgğhıijklmnoöprsştuüvyz';
    String clean(String s) {
      return s.toLowerCase().replaceAll('â', 'a').replaceAll('î', 'i');
    }

    final cleanA = clean(a);
    final cleanB = clean(b);

    int minLen = cleanA.length < cleanB.length ? cleanA.length : cleanB.length;
    for (int i = 0; i < minLen; i++) {
      final charA = cleanA[i];
      final charB = cleanB[i];
      int indexA = turkishAlphabet.indexOf(charA);
      int indexB = turkishAlphabet.indexOf(charB);
      if (indexA == -1 && indexB == -1) {
        int comp = charA.compareTo(charB);
        if (comp != 0) return comp;
      } else if (indexA == -1) {
        return 1;
      } else if (indexB == -1) {
        return -1;
      } else if (indexA != indexB) {
        return indexA.compareTo(indexB);
      }
    }
    return cleanA.length.compareTo(cleanB.length);
  }
}
