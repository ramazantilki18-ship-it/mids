import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/audit_provider.dart';
import '../providers/nonconformity_provider.dart';
import '../providers/system_provider.dart';
import '../models/audit_model.dart';
import '../models/audit_type_model.dart';
import '../models/nonconformity_model.dart';
import '../models/user_model.dart';
import '../theme/app_colors.dart';
import '../data/mock_data.dart';
import '../services/audit_question_resolver.dart';
import '../utils/audit_type_matcher.dart';
import '../widgets/audit_type_selector.dart';
import 'package:intl/intl.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // Filtre Durumları
  List<String> _selectedLines = ['Tümü'];
  String _selectedStation = 'Tümü';
  String _selectedUser = 'Tümü';
  String _selectedYear = 'Tümü';
  String _selectedMonth = 'Tümü';
  String _selectedStatus = 'Tümü';
  String? _selectedAuditTypeId;
  bool _showFilters = false;
  
  // Denetçi denetim sayıları listesi için arama ve genişleme durumları
  bool _showAllAuditors = false;
  String _auditorSearchQuery = '';

  int _activeFilterCount() {
    int count = 0;
    if (!_selectedLines.contains('Tümü')) count++;
    if (_selectedStation != 'Tümü') count++;
    if (_selectedUser != 'Tümü') count++;
    if (_selectedYear != 'Tümü') count++;
    if (_selectedMonth != 'Tümü') count++;
    if (_selectedStatus != 'Tümü') count++;
    return count;
  }

  void _clearFilters() {
    setState(() {
      _selectedLines = ['Tümü'];
      _selectedStation = 'Tümü';
      _selectedUser = 'Tümü';
      _selectedYear = 'Tümü';
      _selectedMonth = 'Tümü';
      _selectedStatus = 'Tümü';
      _showAllAuditors = false;
      _auditorSearchQuery = '';
    });
  }

  bool _matchesAuditType(AuditModel audit, AuditTypeModel type) {
    return AuditTypeMatcher.matchesAudit(audit, type);
  }

  bool _canAccessAudit(UserModel user, AuditModel audit) {
    return user.canAccessAudit(
      line: audit.line,
      auditorId: audit.auditorId,
      auditorName: audit.auditorName,
    );
  }

  bool _canAccessNonconformity(
    UserModel user,
    NonconformityModel nc, {
    AuditModel? relatedAudit,
  }) {
    return user.canAccessNonconformity(
      line: relatedAudit?.line ?? nc.line,
      auditorId: relatedAudit?.auditorId,
      auditorName: nc.auditorName,
    );
  }

  List<AuditModel> _getFilteredAudits(
      List<AuditModel> audits, AuditTypeModel? selectedAuditType, {Map<String, String> auditorNameMap = const {}}) {
    if (selectedAuditType == null) return [];
    return audits.where((a) {
      bool lineMatch =
          _selectedLines.contains('Tümü') || _selectedLines.contains(a.line);
      bool stationMatch =
          _selectedStation == 'Tümü' || a.station == _selectedStation;
      final resolvedName = auditorNameMap[a.auditorName] ?? a.auditorName;
      bool userMatch =
          _selectedUser == 'Tümü' || resolvedName == _selectedUser;
      bool yearMatch =
          _selectedYear == 'Tümü' || a.date.year.toString() == _selectedYear;
      bool monthMatch =
          _selectedMonth == 'Tümü' || a.date.month.toString() == _selectedMonth;
      bool typeMatch = _matchesAuditType(a, selectedAuditType);
      return typeMatch &&
          lineMatch &&
          stationMatch &&
          userMatch &&
          yearMatch &&
          monthMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final ncProvider = context.watch<NonconformityProvider>();

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

    // auditorName -> resolvedDisplayName map oluştur
    final auditorNameMap = <String, String>{};
    for (var a in allAudits) {
      if (!auditorNameMap.containsKey(a.auditorName)) {
        auditorNameMap[a.auditorName] = system.resolveDisplayName(
          auditorId: a.auditorId,
          auditorName: a.auditorName,
        );
      }
    }

    final filteredAudits = _getFilteredAudits(allAudits, selectedAuditType, auditorNameMap: auditorNameMap);

    final auditById = {for (final audit in allAudits) audit.id: audit};
    final allNC = ncProvider.all.where((nc) {
      final relatedAudit = auditById[nc.auditId];
      if (relatedAudit == null) return false;
      return _canAccessNonconformity(
        user,
        nc,
        relatedAudit: relatedAudit,
      );
    }).toList();
    final filteredNC = allNC.where((nc) {
      final audit = auditById[nc.auditId];
      if (audit == null) return false;
      final typeMatch = selectedAuditType != null &&
          _matchesAuditType(audit, selectedAuditType);
      bool lineMatch =
          _selectedLines.contains('Tümü') || _selectedLines.contains(nc.line);
      bool stationMatch =
          _selectedStation == 'Tümü' || nc.station == _selectedStation;
      bool yearMatch = _selectedYear == 'Tümü' ||
          nc.detectionDate.year.toString() == _selectedYear;
      bool monthMatch = _selectedMonth == 'Tümü' ||
          nc.detectionDate.month.toString() == _selectedMonth;
      bool statusMatch = _selectedStatus == 'Tümü' ||
          (_selectedStatus == 'Açık' &&
              (nc.status == NonconformityStatus.open ||
                  nc.status == NonconformityStatus.inProgress)) ||
          (_selectedStatus == 'Gecikmiş' &&
              nc.status == NonconformityStatus.overdue) ||
          (_selectedStatus == 'Tamamlandı' &&
              nc.status == NonconformityStatus.completed);
      return typeMatch &&
          lineMatch &&
          stationMatch &&
          yearMatch &&
          monthMatch &&
          statusMatch;
    }).toList();

    final totalAudits = filteredAudits.length;
    final avgScore = totalAudits > 0
        ? filteredAudits.fold(0.0, (sum, a) => sum + a.score) / totalAudits
        : 0.0;
    final openNC = filteredNC
        .where((nc) =>
            nc.status == NonconformityStatus.open ||
            nc.status == NonconformityStatus.inProgress)
        .length;
    final completedNC = filteredNC
        .where((nc) => nc.status == NonconformityStatus.completed)
        .length;
    final overdueNC = filteredNC
        .where((nc) => nc.status == NonconformityStatus.overdue)
        .length;

    // Filtre seçenekleri
    final List<String> lineList = allAudits.map((a) => a.line).toSet().toList()
      ..sort();

    // F1 ve F4'ü (Füniküler) sona al
    final List<String> funiculars =
        lineList.where((l) => l.startsWith('F')).toList();
    lineList.removeWhere((l) => l.startsWith('F'));
    lineList.addAll(funiculars);

    final List<String> availableLines = ['Tümü', ...lineList];
    final List<String> availableStations = [
      'Tümü',
      ...allAudits
          .where((a) =>
              _selectedLines.contains('Tümü') ||
              _selectedLines.contains(a.line))
          .map((a) => a.station)
          .toSet()
    ];
    final List<String> availableUsers = [
      'Tümü',
      ...allAudits.map((a) => auditorNameMap[a.auditorName] ?? a.auditorName).toSet()
    ];
    final List<String> availableYears = [
      'Tümü',
      ...allAudits.map((a) => a.date.year.toString()).toSet().toList()..sort()
    ];
    final List<String> availableMonths = [
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
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('KURUMSAL ANALİZ RAPORU',
            style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_showFilters
                ? Icons.filter_alt_off_rounded
                : Icons.filter_alt_rounded),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_showFilters)
              _buildFilterPanel(availableLines, availableStations,
                  availableUsers, availableYears, availableMonths),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _buildAuditTypeSelector(
                  activeAuditTypes, selectedAuditType?.id),
            ),
            _buildReportHeaderCard(avgScore, totalAudits),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                          child: _buildSimpleMetricCard(
                              'Açık İşler',
                              '$openNC',
                              Colors.red,
                              () => context.push('/nonconformities'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildSimpleMetricCard(
                              'Gecikenler',
                              '$overdueNC',
                              Colors.orange,
                              () => context.push('/nonconformities'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildSimpleMetricCard(
                              'Tamamlanan',
                              '$completedNC',
                              Colors.green,
                              () => context.push('/nonconformities'))),
                    ],
                  ),
                  const SizedBox(height: 36),
                  _buildReportSection(
                    title: 'PERFORMANS TREND ANALİZİ',
                    subtitle:
                        'Yıl içerisindeki denetim performans gelişimini gösterir.',
                    content: _buildMonthlyTrendChart(filteredAudits),
                  ),
                  _buildReportSection(
                    title: 'HAT BAZLI DENETİM DAĞILIMI',
                    subtitle:
                        'Hangi hatlarda kaç adet denetim gerçekleştirildiğini gösterir.',
                    onTap: () => context.push('/my-audits'),
                    content: _buildVerticalBarChart(filteredAudits),
                  ),
                  _buildReportSection(
                    title: 'HAT BAZLI UYGUNSUZLUK DURUMLARI',
                    subtitle:
                        'Hataların durumlarına göre hatlar üzerindeki dağılımı.',
                    onTap: () => context.push('/nonconformities'),
                    content: _buildLineNCChart(filteredNC,
                        availableLines.where((l) => l != 'Tümü').toList()),
                  ),
                  _buildReportSection(
                    title: 'EN ÇOK UYGUNSUZLUK ÇIKAN ALANLAR',
                    subtitle: 'En sık uygunsuzluk çıkan denetim kategorileri.',
                    content: _buildNCPriorityList(filteredNC),
                  ),
                  _buildReportSection(
                    title: 'HAT PERFORMANS SIRALAMASI',
                    subtitle:
                        'Hatların genel başarı yüzdelerine göre sıralaması.',
                    content: _buildLinePerformanceList(filteredAudits),
                  ),
                  _buildReportSection(
                    title: 'DENETÇİ DENETİM SAYILARI',
                    subtitle: 'Denetçilerin toplam gerçekleştirdiği denetim sayıları.',
                    content: _buildAuditorAuditCountList(filteredAudits, system.users),
                  ),
                  _buildReportSection(
                    title: 'GENEL KATEGORİ BAŞARI ORANLARI',
                    subtitle:
                        'Denetim kategorileri özelindeki başarı yüzdeleri.',
                    content: _buildCategoryPerformance(filteredAudits),
                  ),
                  _buildReportSection(
                    title: 'HAT BAZLI KATEGORİ BAŞARI MATRİSİ',
                    subtitle:
                        'Hatların kategoriler özelindeki detaylı başarı puanları.',
                    content: _buildLineCategoryMatrix(filteredAudits,
                        availableLines.where((l) => l != 'Tümü').toList()),
                  ),
                  _buildReportSection(
                    title: 'İSTASYON BAZLI KATEGORİ BAŞARI MATRİSİ',
                    subtitle:
                        'İstasyonların kategori bazında performans dökümü.',
                    content: _buildStationCategoryMatrix(filteredAudits),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _categoriesFromAudits(List<AuditModel> audits) {
    final categories = <String>{};
    for (final audit in audits) {
      for (final item in AuditQuestionResolver.resolveAnswers(audit)) {
        if (item.question.categoryName.isNotEmpty) {
          categories.add(item.question.categoryName);
        }
      }
    }
    return categories.toList()..sort();
  }

  Widget _buildStationCategoryMatrix(List<AuditModel> audits) {
    if (audits.isEmpty) return const SizedBox();

    final categories = _categoriesFromAudits(audits);
    final stations = audits.map((a) => a.station).toSet().toList()..sort();

    // Verileri hazırla
    Map<String, Map<String, List<double>>> matrix = {};
    for (var a in audits) {
      matrix.putIfAbsent(a.station, () => {});
      for (var item in AuditQuestionResolver.resolveAnswers(a)) {
        final ans = item.answer;
        final q = item.question;
        matrix[a.station]!
            .putIfAbsent(q.categoryName, () => [])
            .add(ans.normalizedScore);
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 35,
        horizontalMargin: 16,
        headingRowHeight: 50,
        headingRowColor: WidgetStateProperty.all(
            Theme.of(context).primaryColor.withValues(alpha: 0.05)),
        columns: [
          const DataColumn(
              label: Text('İSTASYON',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
          ...categories.map((c) => DataColumn(
                  label: Container(
                constraints: const BoxConstraints(maxWidth: 80),
                child: Text(c.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.bold),
                    softWrap: true,
                    textAlign: TextAlign.center),
              ))),
        ],
        rows: stations.take(20).map((station) {
          // Max 20 istasyon göster
          final line = audits.firstWhere((a) => a.station == station).line;
          return DataRow(
            cells: [
              DataCell(Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(station,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                  Text(line,
                      style: TextStyle(
                          fontSize: 8,
                          color: _getLineColor(line),
                          fontWeight: FontWeight.w800)),
                ],
              )),
              ...categories.map((cat) {
                final scores = matrix[station]?[cat];
                if (scores == null || scores.isEmpty) {
                  return const DataCell(Text('-'));
                }
                final avg =
                    scores.reduce((a, b) => a + b) / scores.length;
                return DataCell(
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                        color: _getScoreColor(avg).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('%${avg.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: _getScoreColor(avg))),
                  ),
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLineCategoryMatrix(List<AuditModel> audits, List<String> lines) {
    if (lines.isEmpty || audits.isEmpty) return const SizedBox();

    final categories = _categoriesFromAudits(audits);

    // Verileri hazırla
    Map<String, Map<String, List<double>>> matrix = {};
    for (var a in audits) {
      matrix.putIfAbsent(a.line, () => {});
      for (var item in AuditQuestionResolver.resolveAnswers(a)) {
        final ans = item.answer;
        final q = item.question;
        matrix[a.line]!
            .putIfAbsent(q.categoryName, () => [])
            .add(ans.normalizedScore);
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 35,
        horizontalMargin: 16,
        headingRowHeight: 50,
        headingRowColor: WidgetStateProperty.all(
            Theme.of(context).primaryColor.withValues(alpha: 0.05)),
        columns: [
          const DataColumn(
              label: Text('HAT',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
          ...categories.map((c) => DataColumn(
                  label: Container(
                constraints: const BoxConstraints(maxWidth: 80),
                child: Text(c.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.bold),
                    softWrap: true,
                    textAlign: TextAlign.center),
              ))),
        ],
        rows: lines.where((l) => matrix.containsKey(l)).map((line) {
          return DataRow(
            cells: [
              DataCell(Text(line,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getLineColor(line)))),
              ...categories.map((cat) {
                final scores = matrix[line]?[cat];
                if (scores == null || scores.isEmpty) {
                  return const DataCell(Text('-'));
                }
                final avg =
                    scores.reduce((a, b) => a + b) / scores.length;
                return DataCell(
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                        color: _getScoreColor(avg).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('%${avg.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: _getScoreColor(avg))),
                  ),
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLineNCChart(List<NonconformityModel> ncs, List<String> lines) {
    if (lines.isEmpty) return const SizedBox();

    final Map<String, Map<String, int>> data = {};
    int maxTotal = 0;

    for (var line in lines) {
      final lineNCs = ncs.where((nc) => nc.line == line).toList();
      final open =
          lineNCs.where((nc) => nc.status == NonconformityStatus.open).length;
      final overdue = lineNCs
          .where((nc) => nc.status == NonconformityStatus.overdue)
          .length;
      final completed = lineNCs
          .where((nc) => nc.status == NonconformityStatus.completed)
          .length;
      final total = open + overdue + completed;

      if (total > 0) {
        data[line] = {
          'open': open,
          'overdue': overdue,
          'completed': completed,
          'total': total
        };
        if (total > maxTotal) maxTotal = total;
      }
    }

    if (data.isEmpty) return const SizedBox();

    return Column(
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.entries.take(8).map((entry) {
              final vals = entry.value;
              final total = vals['total']!;
              final heightPerc = total / (maxTotal == 0 ? 1 : maxTotal);

              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('$total',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5))),
                  const SizedBox(height: 6),
                  Container(
                    width: 24,
                    height: 140 * heightPerc,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Column(
                        children: [
                          if (vals['open']! > 0)
                            Expanded(
                              flex: vals['open']!,
                              child: Container(
                                color: Colors.red,
                                child: Center(
                                    child: Text('${vals['open']}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w900))),
                              ),
                            ),
                          if (vals['overdue']! > 0)
                            Expanded(
                              flex: vals['overdue']!,
                              child: Container(
                                color: Colors.orange,
                                child: Center(
                                    child: Text('${vals['overdue']}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w900))),
                              ),
                            ),
                          if (vals['completed']! > 0)
                            Expanded(
                              flex: vals['completed']!,
                              child: Container(
                                color: Colors.green,
                                child: Center(
                                    child: Text('${vals['completed']}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w900))),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildLineLogo(entry.key, size: 22),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        // LEJAND (RENKLERİN ANLAMI)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('Açık', Colors.red),
            const SizedBox(width: 16),
            _buildLegendItem('Gecikmiş', Colors.orange),
            const SizedBox(width: 16),
            _buildLegendItem('Tamamlandı', Colors.green),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6))),
      ],
    );
  }

  Widget _buildMainScoreCard(double score, int total) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primary.withBlue(130)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Denetim Ortalaması'.toUpperCase(),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('%${score.toStringAsFixed(1)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    Text('($total Denetim)',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: Icon(Icons.analytics_rounded,
                color: Colors.white.withValues(alpha: 0.7), size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleMetricCard(
      String title, String value, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border(bottom: BorderSide(color: color, width: 4)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: -1)),
            const SizedBox(height: 4),
            Text(title.toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalBarChart(List<AuditModel> audits) {
    final Map<String, int> lineCounts = {};
    for (var a in audits) {
      lineCounts[a.line] = (lineCounts[a.line] ?? 0) + 1;
    }

    final sortedLines = lineCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sortedLines.isEmpty ? 1 : sortedLines.first.value;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: sortedLines.take(8).map((entry) {
        final heightPerc = entry.value / maxVal;
        final lineColor = _getLineColor(entry.key);
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('${entry.value}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: lineColor)),
            const SizedBox(height: 6),
            Container(
              width: 28,
              height: 140 * heightPerc,
              decoration: BoxDecoration(
                color: lineColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ),
            const SizedBox(height: 10),
            _buildLineLogo(entry.key, size: 24),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildAuditorAuditCountList(List<AuditModel> audits, List<UserModel> systemUsers) {
    if (audits.isEmpty) return const SizedBox();

    final Map<String, List<AuditModel>> auditorGroups = {};
    for (var a in audits) {
      auditorGroups.putIfAbsent(a.auditorName, () => []).add(a);
    }

    final performance = auditorGroups.entries.map((e) {
      final userAudits = e.value;
      final firstAudit = userAudits.first;

      // Find in systemUsers first, then in MockData.users
      UserModel? foundUser;
      for (var u in systemUsers) {
        if (u.matchesIdentity(
            auditorId: firstAudit.auditorId,
            auditorName: firstAudit.auditorName)) {
          foundUser = u;
          break;
        }
      }
      if (foundUser == null) {
        for (var u in MockData.users) {
          if (u.matchesIdentity(
              auditorId: firstAudit.auditorId,
              auditorName: firstAudit.auditorName)) {
            foundUser = u;
            break;
          }
        }
      }

      final displayName = foundUser?.name ?? e.key;
      final displayTitle = foundUser?.title ?? 'Saha Denetçisi';
      final displayLines = foundUser?.authorizedLines.join(', ') ?? '';

      return {
        'name': displayName,
        'count': userAudits.length,
        'title': displayTitle,
        'lines': displayLines,
      };
    }).toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    final maxCount = performance.isNotEmpty ? performance.first['count'] as int : 1;

    // Arama filtrelemesi
    final filteredList = performance.where((p) {
      if (_auditorSearchQuery.isEmpty) return true;
      final name = (p['name'] as String).toLowerCase();
      final title = (p['title'] as String).toLowerCase();
      final query = _auditorSearchQuery.toLowerCase();
      return name.contains(query) || title.contains(query);
    }).toList();

    // Limit yönetimi
    final bool hasSearch = _auditorSearchQuery.isNotEmpty;
    final int showCount = hasSearch
        ? filteredList.length
        : (_showAllAuditors ? filteredList.length : 5);
    final displayedList = filteredList.take(showCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Arama Çubuğu
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Denetçi veya unvan ara...',
              prefixIcon: Icon(Icons.search, size: 20, color: Theme.of(context).primaryColor),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).primaryColor),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _auditorSearchQuery = val;
              });
            },
          ),
        ),
        
        // Liste başlıkları
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              SizedBox(
                  width: 35,
                  child: Text('SIRA',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 0.8))),
              Expanded(
                  child: Text('DENETÇİ BİLGİSİ',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 0.8))),
              Text('DENETİM SAYISI',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 0.8)),
            ],
          ),
        ),
        const Divider(height: 1),

        if (displayedList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Arama kriterine uygun denetçi bulunamadı.',
                style: TextStyle(color: Colors.grey.withValues(alpha: 0.8), fontSize: 12),
              ),
            ),
          )
        else
          ...displayedList.asMap().entries.map((entry) {
            final idx = entry.key;
            final p = entry.value;
            final count = p['count'] as int;
            final isTop3 = idx < 3 && !hasSearch;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.05)),
                ),
              ),
              child: Row(
                children: [
                  // Sıra Numarası veya Madalya
                  SizedBox(
                    width: 35,
                    child: isTop3
                        ? _buildPremiumMedal(idx)
                        : Text('${idx + 1}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.grey,
                                fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  
                  // Denetçi İsim ve Unvan
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['name'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: -0.2)),
                        const SizedBox(height: 2),
                        Text(
                          p['lines'] != null && (p['lines'] as String).isNotEmpty
                              ? '${p['title']} • ${p['lines']}'
                              : p['title'] as String,
                          style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.withValues(alpha: 0.85),
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  // Denetim Sayısı Gösterimi (Ve Küçük Bar)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$count',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).primaryColor,
                              fontSize: 16,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Container(
                        width: 70,
                        height: 5,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3)),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: maxCount > 0 ? count / maxCount : 0.0,
                          child: Container(
                              decoration: BoxDecoration(color: Theme.of(context).primaryColor)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

        // Daha Fazla Göster / Gizle Butonu (Arama yapılmıyorsa ve toplam sayı 5'ten fazla ise)
        if (!hasSearch && filteredList.length > 5)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAllAuditors = !_showAllAuditors;
                });
              },
              icon: Icon(
                _showAllAuditors ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                size: 18,
              ),
              label: Text(
                _showAllAuditors ? 'Daha Az Göster' : 'Tümünü Göster (${filteredList.length} Denetçi)',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLinePerformanceList(List<AuditModel> audits) {
    if (audits.isEmpty) return const SizedBox();

    final Map<String, List<double>> lineScores = {};
    for (var a in audits) {
      lineScores.putIfAbsent(a.line, () => []).add(a.score);
    }

    final performance = lineScores.entries.map((e) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      return {
        'line': e.key,
        'avg': avg,
        'count': e.value.length,
      };
    }).toList()
      ..sort((a, b) => (b['avg'] as double).compareTo(a['avg'] as double));

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              SizedBox(
                  width: 35,
                  child: Text('SIRA',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1))),
              Expanded(
                  child: Text('HAT BİLGİSİ',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1))),
              Text('BAŞARI',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1)),
            ],
          ),
        ),
        const Divider(height: 1),
        ...performance.take(5).toList().asMap().entries.map((entry) {
          final idx = entry.key;
          final p = entry.value;
          final avg = p['avg'] as double;
          final scoreColor = _getScoreColor(avg);

          final isFirst = idx == 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isFirst
                  ? const Color(0xFFFFD700).withValues(alpha: 0.05)
                  : null,
              border: Border(
                bottom: BorderSide(
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: 0.05)),
                left: isFirst
                    ? const BorderSide(color: Color(0xFFFFD700), width: 4)
                    : BorderSide.none,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: idx < 3
                      ? _buildPremiumMedal(idx)
                      : Center(
                          child: Text('${idx + 1}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.grey,
                                  fontSize: 14))),
                ),
                _buildLineLogo(p['line'] as String, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['line'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: -0.2)),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.assessment_outlined,
                              size: 11,
                              color: Colors.grey.withValues(alpha: 0.6)),
                          const SizedBox(width: 4),
                          Text('${p['count']} Denetim',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('%${avg.toStringAsFixed(1)}',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: scoreColor,
                            fontSize: 16,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Container(
                      width: 60,
                      height: 5,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                          color: scoreColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(3)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: avg / 100,
                        child: Container(
                            decoration: BoxDecoration(color: scoreColor)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCategoryPerformance(List<AuditModel> audits) {
    // Kategori bazlı skorları hesapla
    Map<String, List<double>> catScores = {};
    for (var a in audits) {
      for (var item in AuditQuestionResolver.resolveAnswers(a)) {
        final ans = item.answer;
        final q = item.question;
        catScores
            .putIfAbsent(q.categoryName, () => [])
            .add(ans.normalizedScore);
      }
    }

    if (catScores.isEmpty) return const SizedBox();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: catScores.entries.map((e) {
            final avgPerc = e.value.reduce((a, b) => a + b) / e.value.length;
            final color = _getScoreColor(avgPerc);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('%${avgPerc.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: color)),
                  const SizedBox(height: 8),
                  Container(
                    width: 32,
                    height: 120 * (avgPerc / 100),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(8)),
                      boxShadow: [
                        BoxShadow(
                            color: color.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2))
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 65,
                    height: 24, // Sabit yükseklik etiketin hizasını korur
                    child: Text(
                      e.key.replaceAll(' ', '\n'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                          height: 1.1),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildReportSection({
    required String title,
    String? subtitle,
    required Widget content,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B), // Dark Slate Corporate Header
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 1.2)),
                      if (subtitle != null)
                        Text(subtitle,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 10,
                                fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                if (onTap != null)
                  InkWell(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(List<String> lines, List<String> stations,
      List<String> users, List<String> years, List<String> months) {
    final statusOptions = ['Tümü', 'Açık', 'Gecikmiş', 'Tamamlandı'];
    return Container(
      color: Theme.of(context).cardTheme.color,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 18, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('FİLTRELEME SEÇENEKLERİ',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey,
                                letterSpacing: 1.2)),
                      ],
                    ),
                    if (_activeFilterCount() > 0)
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon:
                            const Icon(Icons.filter_alt_off_rounded, size: 16),
                        label: const Text('Temizle',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 16),
                const Text('HAT SEÇİMİ (ÇOKLU)',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: lines.map((l) {
                      final isSelected = _selectedLines.contains(l);
                      final color = l == 'Tümü'
                          ? (Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF60A5FA)
                              : AppColors.primary)
                          : _getLineColor(l);

                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              if (l == 'Tümü') {
                                _selectedLines = ['Tümü'];
                              } else {
                                _selectedLines.remove('Tümü');
                                if (!isSelected) {
                                  _selectedLines.add(l);
                                } else {
                                  _selectedLines.remove(l);
                                  if (_selectedLines.isEmpty) {
                                    _selectedLines = ['Tümü'];
                                  }
                                }
                              }
                              _selectedStation = 'Tümü';
                            });
                          },
                          borderRadius: BorderRadius.circular(25),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color
                                  : color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? color
                                    : color.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                l,
                                style: TextStyle(
                                  fontSize:
                                      l == 'Tümü' ? 9 : (l.length > 2 ? 9 : 11),
                                  fontWeight: FontWeight.w900,
                                  color: isSelected ? Colors.white : color,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                        width: availableWidth > 500
                            ? (availableWidth - 12) / 2
                            : availableWidth,
                        child: _buildDropdown(
                            'İstasyon',
                            _selectedStation,
                            stations,
                            (v) => setState(() => _selectedStation = v!))),
                    SizedBox(
                        width: availableWidth > 500
                            ? (availableWidth - 12) / 2
                            : availableWidth,
                        child: _buildDropdown(
                            'Durum',
                            _selectedStatus,
                            statusOptions,
                            (v) => setState(() => _selectedStatus = v!))),
                    SizedBox(
                        width: availableWidth,
                        child: _buildDropdown('Denetçi', _selectedUser, users,
                            (v) => setState(() => _selectedUser = v!))),
                    SizedBox(
                        width: (availableWidth - 12) / 2,
                        child: _buildDropdown('Yıl', _selectedYear, years,
                            (v) => setState(() => _selectedYear = v!))),
                    SizedBox(
                        width: (availableWidth - 12) / 2,
                        child: _buildDropdown('Ay', _selectedMonth, months,
                            (v) => setState(() => _selectedMonth = v!))),
                  ],
                ),
                const SizedBox(height: 20),
                // FİLTRE KAPATMA BUTONU
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _showFilters = false),
                    icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                    label: const Text('FİLTRELERİ KAPAT',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF60A5FA)
                              : AppColors.primary,
                      side: BorderSide(
                          color:
                              (Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF60A5FA)
                                      : AppColors.primary)
                                  .withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items,
      ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5))),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color:
                      Theme.of(context).dividerColor.withValues(alpha: 0.1))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold),
              dropdownColor: Theme.of(context).cardTheme.color,
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuditTypeSelector(
      List<AuditTypeModel> auditTypes, String? selectedAuditTypeId) {
    return AuditTypeSelector(
      auditTypes: auditTypes,
      selectedAuditTypeId: selectedAuditTypeId,
      onChanged: (value) => setState(() {
        _selectedAuditTypeId = value;
        _selectedStation = 'Tümü';
      }),
    );
  }

  Color _getScoreColor(double score) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (score >= 85) {
      return isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
    }
    if (score >= 70) {
      return isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C);
    }
    return isDark ? const Color(0xFFF87171) : const Color(0xFFE11D48);
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

  Widget _buildReportHeaderCard(double score, int total) {
    final lineLabel = _selectedLines.contains('Tümü')
        ? 'TÜM HATLAR'
        : _selectedLines.join(', ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text((!kIsWeb && Platform.isIOS) ? 'DENETİM SİSTEMİ RAPORU' : 'METRO İSTANBUL DENETİM RAPORU',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
                Text(
                    DateFormat('dd MMMM yyyy | HH:mm', 'tr_TR')
                        .format(DateTime.now()),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('GENEL BAŞARI PUANI',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('%${score.toStringAsFixed(1)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    Text('$total Denetim',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  lineLabel,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendChart(List<AuditModel> audits) {
    Map<int, List<double>> monthScores = {};
    for (int i = 1; i <= 12; i++) {
      monthScores[i] = [];
    }
    for (var a in audits) {
      monthScores[a.date.month]!.add(a.score);
    }

    final List<String> monthNames = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara'
    ];

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(5, 20, 5, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(12, (index) {
          int month = index + 1;
          final scores = monthScores[month]!;
          final avg = scores.isEmpty
              ? 0.0
              : scores.reduce((a, b) => a + b) / scores.length;
          final heightPerc = avg / 100;
          final isCurrentMonth = DateTime.now().month == month;
          final barColor = avg == 0
              ? Colors.grey.withValues(alpha: 0.2)
              : _getScoreColor(avg);

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (avg > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: barColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '%${avg.toInt()}',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: barColor),
                      ),
                    ),
                  ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        width: 14,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      FractionallySizedBox(
                        heightFactor: avg == 0 ? 0.05 : heightPerc,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          width: 14,
                          decoration: BoxDecoration(
                            gradient: avg > 0
                                ? LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      barColor,
                                      barColor.withValues(alpha: 0.7)
                                    ],
                                  )
                                : null,
                            color: avg == 0 ? barColor : null,
                            borderRadius: BorderRadius.circular(7),
                            boxShadow: avg > 0
                                ? [
                                    BoxShadow(
                                        color: barColor.withValues(alpha: 0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2))
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(monthNames[index],
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight:
                            isCurrentMonth ? FontWeight.w900 : FontWeight.bold,
                        color: isCurrentMonth
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF60A5FA)
                                : AppColors.primary)
                            : Colors.grey.withValues(alpha: 0.8))),
                if (isCurrentMonth)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF60A5FA)
                            : AppColors.primary,
                        shape: BoxShape.circle),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNCPriorityList(List<NonconformityModel> ncs) {
    Map<String, int> catCounts = {};
    for (var nc in ncs) {
      final category = nc.category.isNotEmpty ? nc.category : 'Genel';
      catCounts[category] = (catCounts[category] ?? 0) + 1;
    }
    final sorted = catCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sorted.take(4).map((e) {
        return ListTile(
          leading: CircleAvatar(
              backgroundColor: Colors.red.withValues(alpha: 0.1),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 20)),
          title: Text(e.key,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Text('${e.value} Hata',
                style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w900,
                    fontSize: 12)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPremiumMedal(int index) {
    final List<List<Color>> gradients = [
      [
        const Color(0xFFFFD700),
        const Color(0xFFFFE135),
        const Color(0xFFDAA520)
      ], // Altın
      [
        const Color(0xFFC0C0C0),
        const Color(0xFFE8E8E8),
        const Color(0xFF808080)
      ], // Gümüş
      [
        const Color(0xFFCD7F32),
        const Color(0xFFE1A95F),
        const Color(0xFF8B4513)
      ], // Bronz
    ];

    final bool isFirst = index == 0;
    final double size = isFirst ? 36 : 28;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradients[index],
        ),
        boxShadow: [
          BoxShadow(
            color: gradients[index][0].withValues(alpha: isFirst ? 0.6 : 0.4),
            blurRadius: isFirst ? 12 : 6,
            spreadRadius: isFirst ? 2 : 0,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
            color: isFirst ? Colors.white : Colors.white.withValues(alpha: 0.5),
            width: isFirst ? 2.5 : 1.5),
      ),
      child: Center(
        child: Icon(
          index == 0
              ? Icons.emoji_events
              : (index == 1 ? Icons.workspace_premium : Icons.stars_rounded),
          size: isFirst ? 18 : 14,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildLineLogo(String line, {double size = 28}) {
    final color = _getLineColor(line);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Center(
        child: Text(
          line,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.35,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
