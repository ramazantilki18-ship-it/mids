import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/audit_provider.dart';
import '../providers/system_provider.dart';
import '../theme/app_colors.dart';
import 'package:intl/intl.dart';

import '../models/task_model.dart';
import '../widgets/audit_type_selector.dart';

class StartAuditScreen extends StatefulWidget {
  final TaskModel? task;
  const StartAuditScreen({super.key, this.task});

  @override
  State<StartAuditScreen> createState() => _StartAuditScreenState();
}

class _StartAuditScreenState extends State<StartAuditScreen> {
  String? _selectedLine;
  String? _selectedStation;
  String? _selectedAuditTypeId;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _selectedLine = widget.task!.targetLine;
      if (widget.task!.targetStations.isNotEmpty) {
        _selectedStation = widget.task!.targetStations.first;
      }
      _selectedAuditTypeId = widget.task!.auditTypeId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final system = context.watch<SystemProvider>();
    final hasGlobalLineAccess = user?.hasGlobalLineAccess ?? true;
    final visibleLines = ((user == null || hasGlobalLineAccess)
        ? List<String>.from(system.lines)
        : system.lines.where(user.canAccessLine).toList())
      ..sort(_compareTurkish);
    final selectedLineValue =
        visibleLines.contains(_selectedLine) ? _selectedLine : null;
    final selectedStations = selectedLineValue != null
        ? (system.stations[selectedLineValue] ?? <String>[])
        : <String>[];
    final visibleStations = ((user == null ||
                hasGlobalLineAccess ||
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('YENİ DENETİM',
            style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, Color(0xFF1E3A8A)],
                ),
              ),
              child: Column(
                children: [
                  _buildHeaderInfoRow('TARİH',
                      DateFormat('dd MMMM yyyy | HH:mm', 'tr_TR').format(DateTime.now())),
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: Colors.white24)),
                  _buildHeaderInfoRow(
                      'DENETÇİ', user?.name ?? user?.username ?? ''),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text('Denetim Konumu'.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                    letterSpacing: 1)),
            const SizedBox(height: 16),
            _buildDropdownLabel('Hat Seçimi'),
            DropdownButtonFormField<String>(
              value: selectedLineValue,
              dropdownColor: Theme.of(context).cardTheme.color,
              decoration: _inputDecoration(),
              hint: const Text('Hat seçin'),
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
            const SizedBox(height: 20),
            _buildDropdownLabel('İstasyon Seçimi'),
            DropdownButtonFormField<String>(
              value: selectedStationValue,
              dropdownColor: Theme.of(context).cardTheme.color,
              decoration: _inputDecoration(),
              hint: const Text('İstasyon seçin'),
              items: visibleStations
                  .map(
                      (s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedStation = val),
            ),
            const SizedBox(height: 20),
            _buildDropdownLabel('Denetim Tipi'),
            AuditTypeSelector(
              auditTypes: activeAuditTypes,
              selectedAuditTypeId: selectedAuditTypeValue,
              onChanged: (val) => setState(() => _selectedAuditTypeId = val),
            ),
            const SizedBox(height: 60),
            SizedBox(
              width: double.infinity,
              height: 56,
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

                        final auditProvider = context.read<AuditProvider>();
                        if (auditProvider.currentAudit != null &&
                            !auditProvider.currentAudit!.isCompleted) {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Aktif Denetim Var',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
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
                          auditorId: user?.id ?? '1',
                          auditorName: user?.name ?? 'Kullanıcı',
                          auditType: selectedAuditType.title,
                          questions: auditQuestions,
                          auditTypeConfig: selectedAuditType,
                          taskId: widget.task?.id,
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
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                ),
                child: const Text('DENETİME BAŞLA',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Theme.of(context).cardColor,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildHeaderInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
        Flexible(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

int _compareTurkish(String a, String b) {
  const turkishAlphabet = 'abcçdefgğhıijklmnoöprsştuüvyz';
  String clean(String s) {
    return s.toLowerCase()
        .replaceAll('â', 'a')
        .replaceAll('î', 'i');
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
