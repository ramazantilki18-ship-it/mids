import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'start_audit_screen.dart';
import '../widgets/verification_dialog.dart';
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
import 'dart:io' show Platform;

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

  // Roster Shift & Excuse state
  bool _rosterLoading = false;
  String _todayShiftCode = '';
  String _todayExcuse = '';
  bool _excuseDialogShown = false;
  Map<String, dynamic> _currentMonthDays = {};
  final TextEditingController _excuseController = TextEditingController();

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
      _loadTodayRoster();
    });
  }

  Future<void> _loadTodayRoster() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    if (mounted) {
      setState(() {
        _rosterLoading = true;
      });
    }

    try {
      final now = DateTime.now();
      final docId = '${user.id}_${now.year}_${now.month}';
      final doc = await FirebaseFirestore.instance
          .collection('user_rosters')
          .doc(docId)
          .get();

      if (doc.exists && doc.data() != null) {
        final days = doc.data()?['days'] as Map?;
        if (days != null) {
          if (mounted) {
            setState(() {
              _currentMonthDays = Map<String, dynamic>.from(days);
              final todayData = _currentMonthDays['${now.day}'];
              if (todayData is Map) {
                _todayShiftCode = todayData['shift']?.toString() ?? '';
                _todayExcuse = todayData['excuse']?.toString() ?? '';
                _excuseController.text = _todayExcuse;
              }
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _currentMonthDays = {};
          _todayShiftCode = '';
          _todayExcuse = '';
          _excuseController.clear();
        });
      }
    } catch (e) {
      debugPrint('Error loading today roster: $e');
    } finally {
      if (mounted) {
        setState(() {
          _rosterLoading = false;
        });
        _checkAndShowExcuseDialogAuto();
      }
    }
  }

  Future<void> _submitExcuse(String excuseText, DateTime targetDate) async {
    if (excuseText.trim().isEmpty) return;
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    if (mounted) {
      setState(() {
        _rosterLoading = true;
      });
    }

    try {
      final docId = '${user.id}_${targetDate.year}_${targetDate.month}';
      final docRef = FirebaseFirestore.instance.collection('user_rosters').doc(docId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        Map<String, dynamic> daysData = {};
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data()!;
          if (data['days'] != null) {
            daysData = Map<String, dynamic>.from(data['days']);
          }
        }

        final targetDayData = Map<String, dynamic>.from(daysData['${targetDate.day}'] as Map? ?? {});
        targetDayData['excuse'] = excuseText.trim();
        daysData['${targetDate.day}'] = targetDayData;

        transaction.set(docRef, {
          'userId': user.id,
          'userName': user.name,
          'year': targetDate.year,
          'month': targetDate.month,
          'updatedAt': FieldValue.serverTimestamp(),
          'days': daysData,
        }, SetOptions(merge: true));
      });

      await _loadTodayRoster();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mazeretiniz başarıyla kaydedildi.')),
        );
      }
    } catch (e) {
      debugPrint('Error saving excuse: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mazeret kaydedilirken hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _rosterLoading = false;
        });
      }
    }
  }

  void _openExcuseDialog(BuildContext context, int target, int completed, DateTime targetDate, {bool isDismissible = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _excuseController.clear();

    final dateStr = DateFormat('dd.MM.yyyy').format(targetDate);

    showDialog(
      context: context,
      barrierDismissible: isDismissible,
      builder: (context) {
        return PopScope(
          canPop: isDismissible,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.accentOrange),
                const SizedBox(width: 8),
                Text(
                  '$dateStr Mazereti',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$dateStr tarihinde yapmanız gereken $target denetimden $completed adedini tamamladınız. Lütfen hedef eksikliğinin mazeretini giriniz:',
                  style: const TextStyle(fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _excuseController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Mazeret nedeni yazınız...',
                    hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 13),
                    fillColor: isDark ? Colors.black26 : Colors.grey[50],
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  style: const TextStyle(fontSize: 13.5),
                ),
              ],
            ),
            actions: [
              if (isDismissible)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                  child: const Text('VAZGEÇ'),
                ),
              ElevatedButton(
                onPressed: () {
                  if (_excuseController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lütfen bir mazeret yazınız.')),
                    );
                    return;
                  }
                  final txt = _excuseController.text;
                  Navigator.pop(context);
                  _submitExcuse(txt, targetDate);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('GÖNDER'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkAndShowExcuseDialogAuto() async {
    if (!mounted) return;
    if (_excuseDialogShown) return;

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    // Check role constraints
    if (user.role != UserRole.fieldAuditor && user.role != UserRole.fieldAuditorActionOwner) {
      return;
    }

    // Check title constraints
    final String titleLower = (user.jobTitle ?? '').trim().toLowerCase();
    String cleanText(String s) {
      return s
          .replaceAll('ı', 'i')
          .replaceAll('ğ', 'g')
          .replaceAll('ü', 'u')
          .replaceAll('ş', 's')
          .replaceAll('ö', 'o')
          .replaceAll('ç', 'c')
          .replaceAll('â', 'a');
    }
    final cleanTitle = cleanText(titleLower);
    final isSupervisorOrManager = cleanTitle.contains('hat vardiya amiri') || cleanTitle.contains('istasyon sorumlusu');
    if (isSupervisorOrManager) return;

    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    // Get yesterday roster details
    Map? yesterdayData;
    if (yesterday.month == now.month) {
      yesterdayData = _currentMonthDays['${yesterday.day}'] as Map?;
    } else {
      // Month transition - fetch yesterday's roster
      try {
        final docId = '${user.id}_${yesterday.year}_${yesterday.month}';
        final doc = await FirebaseFirestore.instance.collection('user_rosters').doc(docId).get();
        if (doc.exists && doc.data() != null) {
          final days = doc.data()?['days'] as Map?;
          yesterdayData = days?['${yesterday.day}'] as Map?;
        }
      } catch (e) {
        debugPrint('Error loading yesterday roster for transition: $e');
      }
    }

    final String shiftCode = yesterdayData?['shift']?.toString() ?? '';
    final String excuseText = yesterdayData?['excuse']?.toString() ?? '';

    if (shiftCode.isEmpty) return;

    final system = context.read<SystemProvider>();
    final shift = system.shifts.firstWhere(
      (s) => s['code'] == shiftCode,
      orElse: () => <String, dynamic>{},
    );
    final bool isWorkShift = shift['type'] == 'work';
    final int requiredCount = shift['requiredAuditCount'] as int? ?? 0;
    final int targetCount = isWorkShift ? requiredCount : 0;

    if (targetCount <= 0) return;

    // Calculate completed count for yesterday
    final audit = context.read<AuditProvider>();
    final completedCount = audit.auditHistory.where((a) {
      return a.auditorId == user.id &&
          a.date.year == yesterday.year &&
          a.date.month == yesterday.month &&
          a.date.day == yesterday.day &&
          a.isCompleted;
    }).length;

    final int remainingCount = (targetCount - completedCount).clamp(0, targetCount);

    if (remainingCount > 0 && excuseText.isEmpty) {
      setState(() {
        _excuseDialogShown = true;
      });
      // Show dialog after current frame build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openExcuseDialog(context, targetCount, completedCount, yesterday);
        }
      });
    }
  }

  Future<void> _checkUpdates() async {
    // OTA APK updates are Android only. iOS uses TestFlight/AppStore natively.
    if (kIsWeb || Platform.isIOS) return;
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
    _excuseController.dispose();
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
            14, MediaQuery.of(context).padding.top + 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPremiumTopHeader(context, user, systemProvider),

            const SizedBox(height: 12),

            _buildShiftProgressCard(context, user, systemProvider, auditProvider),

            const SizedBox(height: 12),

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
                user.role != UserRole.executiveViewerRestricted) ...[
              _buildEmbeddedStartAuditForm(
                  context, user, systemProvider, auditProvider),
              const SizedBox(height: 12),
            ],

            _buildAnnouncementPanel(context, activeAnnouncements),

            const SizedBox(height: 12),

            if (user.role == UserRole.executiveViewerGlobal ||
                user.role == UserRole.executiveViewerRestricted)
              const ManagerMonthlyStatsWidget()
            else
              _buildPlannedTasksPanel(context, myCurrentMonthTasks),

            const SizedBox(height: 16),
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
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .primaryColor
            .withValues(alpha: isDark ? 0.14 : 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context)
              .primaryColor
              .withValues(alpha: isDark ? 0.20 : 0.08),
        ),
      ),
      child: Text(
        DateFormat('dd MMM yyyy, HH:mm', 'tr_TR').format(now),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              brandHeader,
              actionButtons,
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '$greeting | ${user.name} (${user.title})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: mutedText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              dateChip,
            ],
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          const SizedBox(height: 10),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
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

              // Verification Check (NFC & Location)
              final nfcKey = '${task.targetLine}_$station';
              final nfcData = systemProvider.stationNfcs[nfcKey];
              String? expectedNfcUid;
              if (nfcData is Map) {
                expectedNfcUid = nfcData['uid']?.toString();
              } else if (nfcData is String) {
                expectedNfcUid = nfcData;
              }

              final locData = systemProvider.stationLocations[nfcKey];
              Map<String, dynamic>? locationConfig;
              if (locData is Map<String, dynamic>) {
                locationConfig = locData;
              } else if (locData is Map) {
                locationConfig = Map<String, dynamic>.from(locData);
              }

              final hasNfc = expectedNfcUid != null && expectedNfcUid.isNotEmpty;
              final hasLocation = locationConfig != null &&
                  locationConfig['latitude'] != null &&
                  locationConfig['longitude'] != null;

              if (hasNfc || hasLocation) {
                if (context.mounted) {
                  final verified = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (dialogContext) => VerificationFlowDialog(
                      expectedNfcUid: expectedNfcUid,
                      locationConfig: locationConfig,
                      stationName: station,
                    ),
                  );
                  if (verified != true) return;
                }
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

  InputDecoration _embeddedInputDecoration({
    required BuildContext context,
    required String labelText,
    required IconData prefixIcon,
    bool isDark = false,
  }) {
    final primary = Theme.of(context).primaryColor;
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white60 : Colors.black45,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      prefixIcon: Icon(prefixIcon, color: primary, size: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: primary.withValues(alpha: isDark ? 0.3 : 0.15),
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: primary.withValues(alpha: isDark ? 0.2 : 0.1),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: primary,
          width: 1.5,
        ),
      ),
    );
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
    final stationNums = selectedLineValue != null
        ? (system.stationNumbers[selectedLineValue] ?? <String, int>{})
        : <String, int>{};
    final visibleStations = ((hasGlobalLineAccess ||
            user.authorizedStations.isEmpty)
        ? List<String>.from(selectedStations)
        : selectedStations
            .where((station) => user.authorizedStations.contains(station))
            .toList())
      ..sort((a, b) {
        final numA = stationNums[a] ?? 999;
        final numB = stationNums[b] ?? 999;
        if (numA != numB) {
          return numA.compareTo(numB);
        }
        return _compareTurkish(a, b);
      });
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar (Metro Blue)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF001B3B), const Color(0xFF002B5B)]
                      : [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.accentRed.withValues(alpha: 0.85),
                    width: 2,
                  ),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.assignment_add,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'YENİ DENETİM BAŞLAT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            // Body (Form)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedLineValue,
                    dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    decoration: _embeddedInputDecoration(
                      context: context,
                      labelText: 'Hat',
                      prefixIcon: Icons.route_rounded,
                      isDark: isDark,
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStationValue,
                    dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    decoration: _embeddedInputDecoration(
                      context: context,
                      labelText: 'İstasyon / Bölge',
                      prefixIcon: Icons.pin_drop_rounded,
                      isDark: isDark,
                    ),
                    items: visibleStations
                        .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedStation = val),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      'DENETİM TİPİ SEÇİN',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  AuditTypeSelector(
                    auditTypes: activeAuditTypes,
                    selectedAuditTypeId: selectedAuditTypeValue,
                    onDark: isDark,
                    onChanged: (val) => setState(() => _selectedAuditTypeId = val),
                  ),
                  const SizedBox(height: 12),
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

                              // Mükerrer denetim uyarısı (Son 10 dakika)
                              final recentDuplicate = auditProvider.auditHistory.where((a) =>
                                  a.station == station &&
                                  a.auditTypeId == auditTypeId &&
                                  DateTime.now().difference(a.date).inMinutes.abs() < 10
                              ).firstOrNull;

                              if (recentDuplicate != null) {
                                final formattedTime = DateFormat('HH:mm').format(recentDuplicate.date);
                                final auditorDisplayName = system.resolveDisplayName(
                                  auditorId: recentDuplicate.auditorId,
                                  auditorName: recentDuplicate.auditorName,
                                );
                                if (context.mounted) {
                                  final confirmDuplicate = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: const Row(
                                        children: [
                                          Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                          SizedBox(width: 8),
                                          Text('Mükerrer Denetim Uyarısı', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      content: Text(
                                        'Bu istasyonda son 10 dakika içinde ($formattedTime\'de) $auditorDisplayName tarafından aynı tipte bir denetim zaten gerçekleştirilmiştir.\n\nYine de yeni bir denetim başlatmak istiyor musunuz?'
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(dialogContext, false),
                                          child: const Text('VAZGEÇ'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(dialogContext, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('DEVAM ET'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmDuplicate != true) return;
                                }
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
                                            Navigator.pop(dialogContext, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.accentRed,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('DENETİMİ SİL'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm != true) return;
                              }

                              // Verification Check (NFC & Location)
                              final nfcKey = '${line}_$station';
                              final nfcData = system.stationNfcs[nfcKey];
                              String? expectedNfcUid;
                              if (nfcData is Map) {
                                expectedNfcUid = nfcData['uid']?.toString();
                              } else if (nfcData is String) {
                                expectedNfcUid = nfcData;
                              }

                              final locData = system.stationLocations[nfcKey];
                              Map<String, dynamic>? locationConfig;
                              if (locData is Map<String, dynamic>) {
                                locationConfig = locData;
                              } else if (locData is Map) {
                                locationConfig = Map<String, dynamic>.from(locData);
                              }

                              final hasNfc = expectedNfcUid != null && expectedNfcUid.isNotEmpty;
                              final hasLocation = locationConfig != null &&
                                  locationConfig['latitude'] != null &&
                                  locationConfig['longitude'] != null;

                              if (hasNfc || hasLocation) {
                                if (context.mounted) {
                                  final verified = await showDialog<bool>(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (dialogContext) => VerificationFlowDialog(
                                      expectedNfcUid: expectedNfcUid,
                                      locationConfig: locationConfig,
                                      stationName: station,
                                    ),
                                  );
                                  if (verified != true) return;
                                }
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
                        disabledBackgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                        disabledForegroundColor: isDark ? Colors.white24 : Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 18,
                            color: (selectedLineValue != null &&
                                    selectedStationValue != null &&
                                    selectedAuditTypeValue != null)
                                ? Colors.white
                                : (isDark ? Colors.white24 : Colors.black26),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'DENETİME BAŞLA',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  Widget _buildShiftProgressCard(
      BuildContext context, UserModel user, SystemProvider system, AuditProvider audit) {
    if (user.role != UserRole.fieldAuditor && user.role != UserRole.fieldAuditorActionOwner) {
      return const SizedBox.shrink();
    }

    final String titleLower = (user.jobTitle ?? '').trim().toLowerCase();
    String cleanText(String s) {
      return s
          .replaceAll('ı', 'i')
          .replaceAll('ğ', 'g')
          .replaceAll('ü', 'u')
          .replaceAll('ş', 's')
          .replaceAll('ö', 'o')
          .replaceAll('ç', 'c')
          .replaceAll('â', 'a');
    }
    final cleanTitle = cleanText(titleLower);
    final isSupervisorOrManager = cleanTitle.contains('hat vardiya amiri') || cleanTitle.contains('istasyon sorumlusu');

    if (isSupervisorOrManager) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Find today's shift configuration
    final shift = system.shifts.firstWhere(
      (s) => s['code'] == _todayShiftCode,
      orElse: () => <String, dynamic>{},
    );

    final String shiftCode = _todayShiftCode.isEmpty ? 'Belirlenmedi' : _todayShiftCode;
    final String shiftName = shift['name']?.toString() ?? 'Atanmamış';
    final String shiftHours = shift['hours']?.toString() ?? '';
    final bool isWorkShift = shift['type'] == 'work';
    final int requiredCount = shift['requiredAuditCount'] as int? ?? 0;
    final int targetCount = isWorkShift ? requiredCount : 0;

    // Calculate completed count for today
    final now = DateTime.now();
    final completedCount = audit.auditHistory.where((a) {
      return a.auditorId == user.id &&
          a.date.year == now.year &&
          a.date.month == now.month &&
          a.date.day == now.day &&
          a.isCompleted;
    }).length;

    final int remainingCount = (targetCount - completedCount).clamp(0, targetCount);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: isDark ? 0.24 : 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header of Roster Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0D1B2A), const Color(0xFF1B263B)]
                    : [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: const Border(
                bottom: BorderSide(
                  color: AppColors.accentRed,
                  width: 2.0,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'GÜNLÜK VARDİYA BİLGİSİ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (targetCount > 0) ...[
                  if (remainingCount == 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'HEDEF TAMAMLANDI',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  else if (_todayExcuse.isEmpty)
                    GestureDetector(
                      onTap: () => _openExcuseDialog(context, targetCount, completedCount, DateTime.now(), isDismissible: true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFFFB923C) : AppColors.accentOrange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'MAZERET BİLDİR',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFFFB923C) : AppColors.accentOrange).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: (isDark ? const Color(0xFFFB923C) : AppColors.accentOrange).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded, color: isDark ? const Color(0xFFFB923C) : AppColors.accentOrange, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'MAZERET BİLDİRİLDİ',
                            style: TextStyle(color: isDark ? const Color(0xFFFB923C) : AppColors.accentOrange, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          
          // Card Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left: Shift info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  shiftCode,
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  shiftName,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (shiftHours.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  shiftHours,
                                  style: TextStyle(
                                    color: isDark ? Colors.white60 : Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Right: Target & Completed counters
                    if (targetCount > 0) ...[
                      Container(
                        height: 40,
                        width: 1,
                        color: Theme.of(context).dividerColor,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      _buildCounterBox(context, 'Hedef', targetCount.toString(), isDark),
                      const SizedBox(width: 14),
                      _buildCounterBox(context, 'Yapılan', completedCount.toString(), isDark, color: AppColors.primary),
                      const SizedBox(width: 14),
                      _buildCounterBox(
                        context, 
                        'Kalan', 
                        remainingCount.toString(), 
                        isDark, 
                        color: remainingCount > 0 ? AppColors.accentRed : AppColors.accentGreen
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isWorkShift ? 'Denetim hedefi tanımlanmamış' : 'Bugün izinlisiniz',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_todayExcuse.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: Theme.of(context).dividerColor),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 14,
                        color: isDark ? const Color(0xFFFB923C) : AppColors.accentOrange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Mazeretiniz: $_todayExcuse',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterBox(BuildContext context, String label, String value, bool isDark, {Color? color}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white60 : Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }


}
