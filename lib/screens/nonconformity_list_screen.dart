import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/nonconformity_provider.dart';
import '../providers/audit_provider.dart';
import '../providers/system_provider.dart';
import '../models/audit_model.dart';
import '../models/audit_type_model.dart';
import '../models/nonconformity_model.dart';
import '../models/user_model.dart';
import '../theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../utils/audit_type_matcher.dart';
import '../widgets/audit_type_selector.dart';
import 'package:intl/intl.dart';

class NonconformityListScreen extends StatefulWidget {
  const NonconformityListScreen({super.key});

  @override
  State<NonconformityListScreen> createState() =>
      _NonconformityListScreenState();
}

class _NonconformityListScreenState extends State<NonconformityListScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedLine = 'Tümü';
  String _selectedCategory = 'Tümü';
  String? _selectedAuditTypeId;
  bool _showFilters = false;
  int _currentPage = 1;
  static const int _pageSize = 15;

  bool _matchesAuditType(
      AuditModel? audit, NonconformityModel nc, AuditTypeModel type) {
    return AuditTypeMatcher.matchesNonconformity(
      audit: audit,
      nonconformity: nc,
      type: type,
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLength, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentPage = 1;
        });
      }
    });
  }

  int get _tabLength => 4;

  void _setAuditType(String typeId) {
    if (_selectedAuditTypeId == typeId) return;
    setState(() {
      _selectedAuditTypeId = typeId;
      _searchController.clear();
      _searchQuery = '';
      _selectedLine = 'Tümü';
      _selectedCategory = 'Tümü';
      _currentPage = 1;
      _tabController.dispose();
      _tabController = TabController(length: _tabLength, vsync: this);
      _tabController.addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(() {
            _currentPage = 1;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NonconformityProvider>();
    final auditProvider = context.watch<AuditProvider>();
    final system = context.watch<SystemProvider>();
    final user = context.watch<AuthProvider>().user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final auditTypes = system.auditTypes
        .where((type) => type.isActive && !type.isDeleted)
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final selectedAuditType =
        auditTypes.any((type) => type.id == _selectedAuditTypeId)
            ? auditTypes.firstWhere((type) => type.id == _selectedAuditTypeId)
            : (auditTypes.isNotEmpty ? auditTypes.first : null);
    final selectedAuditTypeId = selectedAuditType?.id;
    final visibleAuditTypes = auditTypes;

    final auditById = {
      for (final audit in auditProvider.auditHistory) audit.id: audit
    };
    final activeNonconformities = provider.nonconformities.where((nc) {
      if (selectedAuditType == null) return false;
      if (!_matchesAuditType(auditById[nc.auditId], nc, selectedAuditType)) {
        return false;
      }

      final relatedAudit = auditById[nc.auditId];
      return user.canAccessNonconformity(
        line: relatedAudit?.line ?? nc.line,
        auditorId: relatedAudit?.auditorId,
        auditorName: nc.auditorName,
      );
    }).toList();

    // Dinamik filtre seçeneklerini hazırla
    final allLines = {...activeNonconformities.map((nc) => nc.line)}.toList()
      ..sort();
    allLines.insert(0, 'Tümü');
    final allCategories =
        {...activeNonconformities.map((nc) => nc.category)}.toList()..sort();
    allCategories.insert(0, 'Tümü');

    final filteredNC = activeNonconformities.where((nc) {
      if (selectedAuditType == null) return false;
      if (!_matchesAuditType(auditById[nc.auditId], nc, selectedAuditType)) {
        return false;
      }
      final relatedAudit = auditById[nc.auditId];
      final hasAccess = user.canAccessNonconformity(
        line: relatedAudit?.line ?? nc.line,
        auditorId: relatedAudit?.auditorId,
        auditorName: nc.auditorName,
      );
      if (!hasAccess) return false;

      // Arama filtresi
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matches = nc.id.toLowerCase().contains(query) ||
            nc.station.toLowerCase().contains(query) ||
            nc.category.toLowerCase().contains(query) ||
            nc.questionText.toLowerCase().contains(query);
        if (!matches) return false;
      }

      // Hat filtresi
      if (_selectedLine != 'Tümü' && nc.line != _selectedLine) return false;

      // Kategori filtresi
      if (_selectedCategory != 'Tümü' && nc.category != _selectedCategory) {
        return false;
      }

      return true;
    }).toList();

    final openNC = filteredNC
        .where((nc) =>
            nc.status == NonconformityStatus.open ||
            nc.status == NonconformityStatus.inProgress)
        .toList()
      ..sort((a, b) => b.detectionDate.compareTo(a.detectionDate));
    final overdueNC = filteredNC
        .where((nc) => nc.status == NonconformityStatus.overdue)
        .toList()
      ..sort((a, b) => b.detectionDate.compareTo(a.detectionDate));
    final controlNC = filteredNC
        .where((nc) => nc.status == NonconformityStatus.waitingControl)
        .toList()
      ..sort((a, b) => b.detectionDate.compareTo(a.detectionDate));
    final completedNC = filteredNC
        .where((nc) => nc.status == NonconformityStatus.completed)
        .where((nc) {
      final referenceDate = nc.closureDate ?? nc.detectionDate;
      return DateTime.now().difference(referenceDate).inDays <= 45;
    }).toList()
      ..sort((a, b) => b.detectionDate.compareTo(a.detectionDate));

    Color activeColor;
    switch (_tabController.index) {
      case 0:
        activeColor = const Color(0xFF3B82F6);
        break;
      case 1:
        activeColor = const Color(0xFFE11D48);
        break;
      case 2:
        activeColor = const Color(0xFFF59E0B);
        break;
      case 3:
        activeColor = const Color(0xFF16A34A);
        break;
      default:
        activeColor = AppColors.primary;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('TAKİP PANELİ',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.2)),
        centerTitle: true,
        backgroundColor:
            Theme.of(context).appBarTheme.backgroundColor ?? AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
                _showFilters
                    ? Icons.filter_alt_off_rounded
                    : Icons.filter_alt_rounded,
                color: Colors.white),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          if (_searchQuery.isNotEmpty ||
              _selectedLine != 'Tümü' ||
              _selectedCategory != 'Tümü')
            IconButton(
              icon: const Icon(Icons.filter_list_off, color: Colors.white),
              onPressed: () => setState(() {
                _searchController.clear();
                _searchQuery = '';
                _selectedLine = 'Tümü';
                _selectedCategory = 'Tümü';
                _currentPage = 1;
              }),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).appBarTheme.backgroundColor ?? AppColors.primary,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: AuditTypeSelector(
                    auditTypes: visibleAuditTypes,
                    selectedAuditTypeId: selectedAuditTypeId,
                    dense: true,
                    onDark: true,
                    onChanged: _setAuditType,
                  ),
                ),
                if (_showFilters) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'HAT SEÇİMİ',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (_selectedLine != 'Tümü' ||
                            _selectedCategory != 'Tümü' ||
                            _searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(() {
                              _selectedLine = 'Tümü';
                              _selectedCategory = 'Tümü';
                              _searchController.clear();
                              _searchQuery = '';
                              _currentPage = 1;
                            }),
                            child: const Row(
                              children: [
                                Icon(Icons.filter_alt_off_rounded,
                                    size: 12, color: Colors.white70),
                                SizedBox(width: 4),
                                Text(
                                  'Temizle',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Horizontal Line Logos Row
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: allLines.length,
                        itemBuilder: (context, index) {
                          final line = allLines[index];
                          final isSelected = _selectedLine == line;
                          final color = line == 'Tümü'
                              ? const Color(0xFF64748B)
                              : _getLineColor(line);
                          return _buildLineLogoButton(line, isSelected, color);
                        },
                      ),
                    ),
                  ),
                ],
                // TabBar
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Theme(
                    data: ThemeData(
                        highlightColor: Colors.transparent,
                        splashColor: Colors.transparent),
                    child: TabBar(
                      controller: _tabController,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: activeColor,
                        boxShadow: [
                          BoxShadow(
                              color: activeColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      onTap: (index) => setState(() {}),
                      labelColor: Colors.white,
                      unselectedLabelColor: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: 0.5),
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: [
                        _buildTab(
                            'A\u00c7IK',
                            openNC.length,
                            _tabController.index == 0
                                ? Colors.white
                                : const Color(0xFF3B82F6)),
                        _buildTab(
                            'GEC\u0130KEN',
                            overdueNC.length,
                            _tabController.index == 1
                                ? Colors.white
                                : const Color(0xFFE11D48)),
                        _buildTab(
                            'KONTROL',
                            controlNC.length,
                            _tabController.index == 2
                                ? Colors.white
                                : const Color(0xFFF59E0B)),
                        _buildTab(
                            'KAPALI',
                            completedNC.length,
                            _tabController.index == 3
                                ? Colors.white
                                : const Color(0xFF16A34A)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(openNC, user),
                _buildList(overdueNC, user),
                _buildList(controlNC, user),
                _buildList(completedNC, user),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int count, Color color) {
    return Tab(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: color)),
            const SizedBox(height: 1),
            Text('$count',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<NonconformityModel> list, UserModel user) {
    if (list.isEmpty) return _buildEmptyState();

    final displayedNC = list.take(_currentPage * _pageSize).toList();
    final hasMore = list.length > displayedNC.length;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: displayedNC.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == displayedNC.length) {
          final remaining = list.length - displayedNC.length;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _currentPage++),
                icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                label: Text('Daha Fazla Yükle ($remaining kaldı)'),
                style: TextButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          );
        }
        return _buildCompactNCItem(displayedNC[index], user);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded,
              size: 48, color: Theme.of(context).dividerColor),
          const SizedBox(height: 12),
          Text('Kayıt Bulunmuyor',
              style: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.5),
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCompactNCItem(NonconformityModel nc, UserModel user) {
    final Color lineTypeColor = _getLineColor(nc.line);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/nonconformity-detail/${nc.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Küçük Hat Logosu
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: lineTypeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: lineTypeColor.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      nc.line,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Bilgiler
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (nc.ncNo != null && nc.ncNo!.isNotEmpty)
                                  Text(
                                    nc.ncNo!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                Text(
                                  nc.station,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('dd.MM.yyyy').format(nc.detectionDate),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.75),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('HH:mm').format(nc.detectionDate),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nc.questionText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.85),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person_pin_rounded,
                              size: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.65)),
                          const SizedBox(width: 4),
                          Text(
                            context.read<SystemProvider>().resolveDisplayName(auditorName: nc.auditorName),
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Paylaş Butonu
                          IconButton(
                            onPressed: () => _shareNonconformity(nc),
                            icon: const Icon(Icons.share_rounded, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.7),
                          ),
                          if (user.role == UserRole.superAdmin)
                            IconButton(
                              onPressed: () =>
                                  _showDeleteConfirm(context, nc.id),
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18, color: Colors.red),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          const Spacer(),
                          // Durum Belirteci (Küçük Nokta)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getStatusColor(nc.status)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(nc.status),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  nc.status == NonconformityStatus.completed
                                      ? 'KAPALI'
                                      : (nc.status ==
                                              NonconformityStatus.waitingControl
                                          ? 'KONTROL'
                                          : (nc.status ==
                                                  NonconformityStatus.overdue
                                              ? 'GECİKEN'
                                              : 'AÇIK')),
                                  style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: _getStatusColor(nc.status)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _shareNonconformity(NonconformityModel nc) {
    final String dateStr = DateFormat('dd.MM.yyyy').format(nc.detectionDate);
    final String status = nc.status == NonconformityStatus.completed
        ? 'KAPALI'
        : (nc.status == NonconformityStatus.waitingControl
            ? 'KONTROL'
            : (nc.status == NonconformityStatus.overdue ? 'GECİKEN' : 'AÇIK'));

    String shareText = '⚠️ UYGUNSUZLUK BİLDİRİMİ\n';
    shareText += '--------------------------\n';
    shareText += '📍 İstasyon: ${nc.station}\n';
    shareText += '🛤 Hat: ${nc.line}\n';
    shareText += '📅 Tespit Tarihi: $dateStr\n';
    shareText += '👤 Denetçi: ${context.read<SystemProvider>().resolveDisplayName(auditorName: nc.auditorName)}\n';
    shareText += '📌 Durum: $status\n\n';
    shareText += '🔍 BULGU:\n${nc.questionText}\n\n';
    if (nc.auditorComment.isNotEmpty) {
      shareText += '📝 AÇIKLAMA: ${nc.auditorComment}\n';
    }
    String systemName = (!kIsWeb && Platform.isIOS) ? 'Denetim Sistemi' : 'Metro İstanbul Denetim Sistemi';
    shareText += '\n$systemName üzerinden gönderilmiştir.';

    Share.share(shareText, subject: '${nc.station} Uygunsuzluk Bildirimi');
  }

  void _showDeleteConfirm(BuildContext context, String id) {
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
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              await context
                  .read<NonconformityProvider>()
                  .deleteNonconformity(id);
              navigator.pop(); // Close dialog
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                    content: Text('Uygunsuzluk silindi.'),
                    backgroundColor: Colors.red),
              );
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(NonconformityStatus status) {
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

  Color _getLineColor(String line) {
    switch (line) {
      case 'M1':
      case 'M1A':
      case 'M1B':
        return const Color(0xFFE31E24);
      case 'M2':
        return const Color(0xFF009543);
      case 'M3':
        return const Color(0xFF009FE3);
      case 'M4':
        return const Color(0xFFE91E63);
      case 'M5':
        return const Color(0xFF53284F);
      case 'M6':
        return const Color(0xFFB9A15E);
      case 'M7':
        return const Color(0xFFF29100);
      case 'M8':
        return const Color(0xFF003D88);
      case 'M9':
        return const Color(0xFFEDD500);
      case 'M11':
        return const Color(0xFFE31E24);
      case 'T1':
        return const Color(0xFF003D88);
      case 'T3':
        return const Color(0xFF53284F);
      case 'T4':
        return const Color(0xFFF29100);
      case 'T5':
        return const Color(0xFF2E7D32);
      case 'F1':
        return const Color(0xFF333333);
      case 'TF1':
      case 'TF2':
        return const Color(0xFF795548);
      default:
        return Colors.blueGrey;
    }
  }

  Widget _buildLineLogoButton(String line, bool isSelected, Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLine = line;
          _currentPage = 1;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : color.withValues(alpha: 0.35),
            width: isSelected ? 2.2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            line,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
