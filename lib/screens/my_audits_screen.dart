import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/system_provider.dart';
import '../models/audit_model.dart';
import '../models/audit_type_model.dart';
import '../models/user_model.dart';
import '../providers/audit_provider.dart';
import '../utils/audit_type_matcher.dart';
import '../widgets/audit_type_selector.dart';

class MyAuditsScreen extends StatefulWidget {
  const MyAuditsScreen({super.key});

  @override
  State<MyAuditsScreen> createState() => _MyAuditsScreenState();
}

class _MyAuditsScreenState extends State<MyAuditsScreen> {
  // Filtre Durumları
  List<String> _selectedLines = ['Tümü'];
  String _selectedStation = 'Tümü';
  String _selectedYear = 'Tümü';
  String _selectedMonth = 'Tümü';
  String _selectedAuditor = 'Tümü';
  String _sortOption = 'Tarihe Göre (En Yeni)';
  String? _selectedAuditTypeId;
  bool _showFilters = false;
  int _currentPage = 1;
  static const int _pageSize = 15;

  bool _matchesAuditType(AuditModel audit, AuditTypeModel type) {
    return AuditTypeMatcher.matchesAudit(audit, type);
  }

  // Hat Renkleri (Metro İstanbul Gerçek Renk Standartları)
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
        return const Color(0xFF9C27B0);
      case 'F1':
        return const Color(0xFF333333);
      case 'TF1':
      case 'TF2':
        return const Color(0xFF795548);
      default:
        return Colors.blueGrey;
    }
  }

  bool _canAccessAudit(UserModel user, AuditModel audit) {
    return user.canAccessAudit(
      line: audit.line,
      auditorId: audit.auditorId,
      auditorName: audit.auditorName,
    );
  }

  List<AuditModel> _applyFilters(
      List<AuditModel> audits, AuditTypeModel? selectedAuditType) {
    var filtered = List<AuditModel>.from(audits);

    if (selectedAuditType == null) return [];
    filtered =
        filtered.where((a) => _matchesAuditType(a, selectedAuditType)).toList();

    // Hat Filtresi (Çoklu)
    if (!_selectedLines.contains('Tümü')) {
      filtered =
          filtered.where((a) => _selectedLines.contains(a.line)).toList();
    }

    // İstasyon Filtresi
    if (_selectedStation != 'Tümü') {
      filtered = filtered.where((a) => a.station == _selectedStation).toList();
    }

    // Yıl Filtresi
    if (_selectedYear != 'Tümü') {
      filtered = filtered
          .where((a) => a.date.year.toString() == _selectedYear)
          .toList();
    }

    // Ay Filtresi
    if (_selectedMonth != 'Tümü') {
      filtered = filtered
          .where((a) => a.date.month.toString() == _selectedMonth)
          .toList();
    }

    // Denetleyen Kişi Filtresi (Hem ID hem de isim ile kontrol et)
    if (_selectedAuditor != 'Tümü') {
      filtered = filtered
          .where((a) =>
              a.auditorName == _selectedAuditor ||
              a.auditorId == _selectedAuditor)
          .toList();
    }

    // Sıralama
    switch (_sortOption) {
      case 'Tarihe Göre (En Yeni)':
        filtered.sort((a, b) => b.date.compareTo(a.date));
        break;
      case 'Tarihe Göre (En Eski)':
        filtered.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 'Puanına Göre (Yüksekten Düşüğe)':
        filtered.sort((a, b) => b.score.compareTo(a.score));
        break;
      case 'Puanına Göre (Düşükten Yükseğe)':
        filtered.sort((a, b) => a.score.compareTo(b.score));
        break;
    }

    return filtered;
  }

  int _activeFilterCount() {
    int count = 0;
    if (!_selectedLines.contains('Tümü')) count++;
    if (_selectedStation != 'Tümü') count++;
    if (_selectedYear != 'Tümü') count++;
    if (_selectedMonth != 'Tümü') count++;
    if (_selectedAuditor != 'Tümü') count++;
    if (_sortOption != 'Tarihe Göre (En Yeni)') count++;
    return count;
  }

  void _clearFilters() {
    setState(() {
      _selectedLines = ['Tümü'];
      _selectedStation = 'Tümü';
      _selectedYear = 'Tümü';
      _selectedMonth = 'Tümü';
      _selectedAuditor = 'Tümü';
      _sortOption = 'Tarihe Göre (En Yeni)';
      _currentPage = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final auditProvider = context.watch<AuditProvider>();
    final system = context.watch<SystemProvider>();
    final allAudits = auditProvider.auditHistory
        .where((audit) => _canAccessAudit(user, audit))
        .toList();
    final activeAuditTypes = system.auditTypes
        .where((type) => type.isActive && !type.isDeleted)
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final selectedAuditType = activeAuditTypes
            .any((type) => type.id == _selectedAuditTypeId)
        ? activeAuditTypes.firstWhere((type) => type.id == _selectedAuditTypeId)
        : (activeAuditTypes.isNotEmpty ? activeAuditTypes.first : null);
    final filteredAudits = _applyFilters(allAudits, selectedAuditType);
    final displayedAudits =
        filteredAudits.take(_currentPage * _pageSize).toList();
    final hasMoreAudits = filteredAudits.length > displayedAudits.length;
    final activeFilters = _activeFilterCount();

    // Filtre seçeneklerini dinamik oluştur
    final availableLines = [
      'Tümü',
      ...allAudits.map((a) => a.line).toSet().toList()..sort()
    ];
    final availableStations = [
      'Tümü',
      ...allAudits
          .where((a) =>
              _selectedLines.contains('Tümü') ||
              _selectedLines.contains(a.line))
          .map((a) => a.station)
          .toSet()
          .toList()
        ..sort()
    ];
    final availableYears = [
      'Tümü',
      ...allAudits.map((a) => a.date.year.toString()).toSet().toList()..sort()
    ];
    final availableMonths = [
      'Tümü',
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '10',
      '11',
      '12'
    ]; // Denetleyen kişileri auditorId'ye göre kullanıcı adı ile göster
    final auditorMap = <String, String>{};
    for (var audit in allAudits) {
      if (!auditorMap.containsKey(audit.auditorId)) {
        // Önce SystemProvider'dan kullanıcıyı bul
        final systemProvider = context.read<SystemProvider>();
        try {
          final user =
              systemProvider.users.firstWhere((u) => u.id == audit.auditorId);
          auditorMap[audit.auditorId] = user.username;
        } catch (_) {
          auditorMap[audit.auditorId] =
              audit.auditorId; // Bulunamazsa ID'yi kullan
        }
      }
    }
    final availableAuditors = [
      'Tümü',
      ...auditorMap.values.toSet().toList()..sort()
    ];
    final sortOptionsList = [
      'Tarihe Göre (En Yeni)',
      'Tarihe Göre (En Eski)',
      'Puanına Göre (Yüksekten Düşüğe)',
      'Puanına Göre (Düşükten Yükseğe)'
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Denetim Kayıtları'),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(_showFilters
                    ? Icons.filter_alt_off_rounded
                    : Icons.filter_alt_rounded),
                if (activeFilters > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.orangeAccent, shape: BoxShape.circle),
                      child: Text('$activeFilters',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _buildAuditTypeSelector(
                activeAuditTypes, selectedAuditType?.id),
          ),
          // Toplam denetim sayısı (ortalı, altında çizgi)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_rounded,
                  size: 16,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Toplam ${filteredAudits.length} denetim kaydı',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          if (_showFilters)
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Theme.of(context).primaryColor.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.tune_rounded,
                                    size: 18, color: Colors.white),
                                SizedBox(width: 8),
                                Text('FİLTRELEME VE SIRALAMA',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 1.2)),
                              ],
                            ),
                            if (activeFilters > 0)
                              InkWell(
                                onTap: _clearFilters,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Text('Temizle',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final availableWidth = constraints.maxWidth;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('HAT SEÇİMİ',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey)),
                                const SizedBox(height: 10),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    children: [
                                      _buildLineLogo(
                                          'Tümü',
                                          const Color(0xFF64748B),
                                          Colors.white,
                                          true),
                                      ...availableLines
                                          .where((l) => l != 'Tümü')
                                          .map((line) => _buildLineLogo(
                                              line,
                                              _getLineColor(line),
                                              Colors.white,
                                              true)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Divider(height: 1),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                        width: availableWidth > 500
                                            ? (availableWidth - 12) / 2
                                            : availableWidth,
                                        child: _buildFilterRow(
                                            'Sıralama',
                                            _sortOption,
                                            sortOptionsList,
                                            (val) => setState(() {
                                                  _sortOption = val!;
                                                  _currentPage = 1;
                                                }))),
                                    SizedBox(
                                        width: availableWidth > 500
                                            ? (availableWidth - 12) / 2
                                            : availableWidth,
                                        child: _buildFilterRow(
                                            'İstasyon',
                                            _selectedStation,
                                            availableStations,
                                            (val) => setState(() {
                                                  _selectedStation = val!;
                                                  _currentPage = 1;
                                                }))),
                                    SizedBox(
                                        width: (availableWidth - 24) / 3 > 100
                                            ? (availableWidth - 24) / 3
                                            : (availableWidth - 12) / 2,
                                        child: _buildFilterRow(
                                            'Yıl',
                                            _selectedYear,
                                            availableYears,
                                            (val) => setState(() {
                                                  _selectedYear = val!;
                                                  _currentPage = 1;
                                                }))),
                                    SizedBox(
                                        width: (availableWidth - 24) / 3 > 100
                                            ? (availableWidth - 24) / 3
                                            : (availableWidth - 12) / 2,
                                        child: _buildFilterRow(
                                            'Ay',
                                            _selectedMonth,
                                            availableMonths,
                                            (val) => setState(() {
                                                  _selectedMonth = val!;
                                                  _currentPage = 1;
                                                }))),
                                    SizedBox(
                                        width: (availableWidth - 24) / 3 > 100
                                            ? (availableWidth - 24) / 3
                                            : availableWidth,
                                        child: _buildFilterRow(
                                            'Denetleyen',
                                            _selectedAuditor,
                                            availableAuditors,
                                            (val) => setState(() {
                                                  _selectedAuditor = val!;
                                                  _currentPage = 1;
                                                }))),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                // FİLTRE KAPATMA BUTONU
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        setState(() => _showFilters = false),
                                    icon: const Icon(
                                        Icons.keyboard_arrow_up_rounded,
                                        size: 20),
                                    label: const Text('FİLTRELERİ KAPAT',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            letterSpacing: 1)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          Theme.of(context).primaryColor,
                                      side: BorderSide(
                                          color: Theme.of(context)
                                              .primaryColor
                                              .withOpacity(0.3)),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: filteredAudits.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
                      itemCount:
                          displayedAudits.length + (hasMoreAudits ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == displayedAudits.length) {
                          final remaining =
                              filteredAudits.length - displayedAudits.length;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: TextButton.icon(
                                onPressed: () => setState(() => _currentPage++),
                                icon: const Icon(Icons.arrow_downward_rounded,
                                    size: 16),
                                label:
                                    Text('Daha Fazla Yükle ($remaining kaldı)'),
                                style: TextButton.styleFrom(
                                  backgroundColor: Theme.of(context)
                                      .primaryColor
                                      .withValues(alpha: 0.1),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                ),
                              ),
                            ),
                          );
                        }
                        final audit = displayedAudits[index];
                        return _buildAuditCard(context, audit);
                      },
                    ),
            ),
        ],
      ),
    );
  }

  // ----- FİLTRE SATIRI -----
  Widget _buildFilterRow(String label, String currentValue,
      List<String> options, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              isExpanded: true,
              dropdownColor: Theme.of(context).cardColor,
              elevation: 4,
              icon: Icon(Icons.expand_more_rounded,
                  color: Theme.of(context).primaryColor, size: 20),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              items: options.map((option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(
                    option,
                    style: TextStyle(
                      color: option == currentValue
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: option == currentValue
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // ”€”€” BOÅž DURUM ”€”€”
  Widget _buildAuditTypeSelector(
      List<AuditTypeModel> auditTypes, String? selectedAuditTypeId) {
    return AuditTypeSelector(
      auditTypes: auditTypes,
      selectedAuditTypeId: selectedAuditTypeId,
      onChanged: (value) => setState(() {
        _selectedAuditTypeId = value;
        _selectedStation = 'Tümü';
        _currentPage = 1;
      }),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded,
                  size: 56,
                  color: Theme.of(context).primaryColor.withOpacity(0.3)),
            ),
            const SizedBox(height: 24),
            Text('Sonuç Bulunamadı',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text('Seçili filtrelere uygun denetim kaydı yok.',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                    fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Filtreleri Temizle'),
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  // KOMPAKT LİSTE GÖRÜNÜMÜ - KURUMSAL TASARIM
  Widget _buildAuditCard(BuildContext context, AuditModel audit) {
    final scoreColor = _getScoreColor(audit.score);
    final ncCount = audit.answers.where((a) => a.isNonconformity).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/audit-summary/${audit.id}', extra: audit),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Yuvarlak Hat Logosu
                _buildLineLogo(
                    audit.line, _getLineColor(audit.line), Colors.white),

                const SizedBox(width: 10),

                // Sol: İstasyon
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // İstasyon adı (büyük)
                      Text(
                        audit.station,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Orta: Yüzde oranı
                Expanded(
                  child: Center(
                    child: Text(
                      '${audit.score.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: scoreColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Sağ: Kullanıcı adı + Tarih + Uygunsuzluk
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        audit.auditorName,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${audit.date.day.toString().padLeft(2, '0')}/${audit.date.month.toString().padLeft(2, '0')}/${audit.date.year}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${audit.date.hour.toString().padLeft(2, '0')}:${audit.date.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (ncCount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 11,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFFFB923C)
                                  : const Color(0xFFEA580C),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$ncCount Uygunsuzluk',
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFFB923C)
                                    : const Color(0xFFEA580C),
                                fontWeight: FontWeight.w600,
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
          ),
        ),
      ),
    );
  }

  // HAT LOGOSU OLUŞTUR (YUVARLAK)
  Widget _buildLineLogo(String line, Color color,
      [Color textColor = Colors.white, bool isInteractive = false]) {
    final isSelected = !isInteractive || _selectedLines.contains(line);

    Widget content = Container(
      margin: const EdgeInsets.only(right: 8),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isSelected ? color : color.withOpacity(0.35),
        shape: BoxShape.circle,
        border: isSelected && isInteractive
            ? Border.all(color: Colors.white, width: 2)
            : null,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          line, // T1, T4, M3 gibi tam hat adı
          style: TextStyle(
            color: isSelected ? textColor : textColor.withOpacity(0.6),
            fontSize: 10, // Daha küçük font
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );

    if (isInteractive) {
      return GestureDetector(
        onTap: () {
          setState(() {
            if (line == 'Tümü') {
              _selectedLines = ['Tümü'];
            } else {
              if (_selectedLines.contains('Tümü')) {
                _selectedLines.remove('Tümü');
              }
              if (_selectedLines.contains(line)) {
                _selectedLines.remove(line);
                if (_selectedLines.isEmpty) {
                  _selectedLines = ['Tümü'];
                }
              } else {
                _selectedLines.add(line);
              }
            }
            _selectedStation = 'Tümü';
            _currentPage = 1;
          });
        },
        child: content,
      );
    }

    return content;
  }

  Color _getScoreColor(double score) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (score >= 80) {
      return isDark ? const Color(0xFF4ADE80) : const Color(0xFF2E7D32);
    }
    if (score >= 60) {
      return isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C);
    }
    return isDark ? const Color(0xFFF87171) : const Color(0xFFD32F2F);
  }
}
