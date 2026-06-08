import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/system_provider.dart';
import '../models/task_model.dart';
import '../models/audit_type_model.dart';
import '../theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class TaskPlanningScreen extends StatefulWidget {
  const TaskPlanningScreen({super.key});

  @override
  State<TaskPlanningScreen> createState() => _TaskPlanningScreenState();
}

class _TaskPlanningScreenState extends State<TaskPlanningScreen> {
  String _selectedTitle = 'Saha Denetçisi';
  String? _selectedLine;
  List<String> _selectedStations = [];
  String? _selectedUserId;
  DateTime _startDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  String _selectedTaskType = 'Planlı Denetim';
  String? _selectedAuditTypeId;
  String _planningPeriod = 'Tekil Denetim';
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  Map<int, List<String>> _monthlyStations = {for (var i = 1; i <= 12; i++) i: []};

  void _resetForm() {
    _selectedTitle = 'Saha Denetçisi';
    _selectedLine = null;
    _selectedStations = [];
    _selectedUserId = null;
    _startDate = DateTime.now();
    _dueDate = DateTime.now().add(const Duration(days: 7));
    _selectedTaskType = 'Planlı Denetim';
    _selectedAuditTypeId = null;
    _planningPeriod = 'Tekil Denetim';
    _selectedYear = DateTime.now().year;
    _selectedMonth = DateTime.now().month;
    _monthlyStations = {for (var i = 1; i <= 12; i++) i: []};
  }

  void _showTaskDialog({TaskModel? editTask}) {
    if (editTask != null) {
      _selectedTitle = editTask.assignedTitle;
      _selectedLine = editTask.targetLine;
      _selectedStations = List.from(editTask.targetStations);
      _selectedUserId = editTask.assignedUserId;
      _startDate = editTask.startDate;
      _dueDate = editTask.dueDate;
      _selectedTaskType = editTask.taskType;
      _selectedAuditTypeId = null;
      _planningPeriod = 'Tekil Denetim';
    } else {
      _resetForm();
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final system = context.read<SystemProvider>();
            _selectedLine ??= system.lines.isNotEmpty ? system.lines.first : '';
            final availableStations = system.stations[_selectedLine] ?? [];
            if (_selectedAuditTypeId == null && editTask?.auditTypeId != null) {
              final types = system.auditTypes.where((t) => t.id == editTask!.auditTypeId).toList();
              if (types.isNotEmpty) _selectedAuditTypeId = types.first.id;
            }
            _selectedAuditTypeId ??= system.auditTypes.isNotEmpty ? system.auditTypes.first.id : null;

            return AlertDialog(
              title: Text(editTask == null ? 'Yeni Görev Ata' : 'Görevi Düzenle'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Görev detaylarını doldurarak yeni bir denetim planı oluşturun.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      if (editTask == null)
                        DropdownButtonFormField<String>(
                          initialValue: _planningPeriod,
                          decoration: const InputDecoration(labelText: 'Planlama Periyodu', border: OutlineInputBorder()),
                          items: ['Tekil Denetim', 'Aylık Planlama', 'Yıllık Planlama']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (val) => setDialogState(() {
                            _planningPeriod = val!;
                            if (_planningPeriod != 'Tekil Denetim') {
                              _selectedTaskType = 'Planlı Denetim';
                            }
                          }),
                        ),
                      if (editTask == null) const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: system.auditTypes.any((t) => t.id == _selectedAuditTypeId) ? _selectedAuditTypeId : null,
                        decoration: const InputDecoration(labelText: 'Denetim Tipi', border: OutlineInputBorder()),
                        items: system.auditTypes.map((type) => DropdownMenuItem(
                          value: type.id,
                          child: Row(children: [
                            Icon(_auditTypeIcon(type), size: 18, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            Text(type.title),
                          ]),
                        )).toList(),
                        onChanged: (val) => setDialogState(() => _selectedAuditTypeId = val),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String?>(
                        initialValue: _selectedUserId,
                        decoration: const InputDecoration(labelText: 'Denetçi Seç', border: OutlineInputBorder()),
                        items: [
                          if (_planningPeriod == 'Tekil Denetim') const DropdownMenuItem(value: null, child: Text('Kişi Atanmadı')),
                          ...system.users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))),
                        ],
                        onChanged: (val) {
                          setDialogState(() {
                            _selectedUserId = val;
                            if (val != null) {
                              final user = system.users.firstWhere((u) => u.id == val);
                              _selectedTitle = user.title;
                              if (user.authorizedLines.isNotEmpty) {
                                _selectedLine = user.authorizedLines.first;
                                _selectedStations = [];
                              }
                            } else {
                              _selectedTitle = 'Saha Denetçisi';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      if (_planningPeriod == 'Tekil Denetim') ...[
                        DropdownButtonFormField<String>(
                          initialValue: _selectedTaskType,
                          decoration: const InputDecoration(labelText: 'Görev Türü', border: OutlineInputBorder()),
                          items: ['Planlı Denetim', 'Plansız Denetim']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (val) => setDialogState(() => _selectedTaskType = val!),
                        ),
                        const SizedBox(height: 16),
                        if (_selectedTaskType == 'Plansız Denetim')
                          DropdownButtonFormField<String>(
                            initialValue: _selectedLine,
                            decoration: const InputDecoration(labelText: 'İlgili Hat', border: OutlineInputBorder()),
                            items: system.lines.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                            onChanged: (val) => setDialogState(() {
                              _selectedLine = val!;
                              _selectedStations = [];
                            }),
                          )
                        else if (_selectedUserId != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Theme.of(context).primaryColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Hat:  (Kullanıcı yetkisine göre)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor)),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        const Text('İstasyon Seçimi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: availableStations.map((s) {
                            final isSelected = _selectedStations.contains(s);
                            return FilterChip(
                              label: Text(s, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color)),
                              selected: isSelected,
                              selectedColor: Theme.of(context).primaryColor,
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    _selectedStations.add(s);
                                  } else {
                                    _selectedStations.remove(s);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final date = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
                                  if (date != null) setDialogState(() => _startDate = date);
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'Başlangıç', border: OutlineInputBorder()),
                                  child: Text(DateFormat('dd.MM.yyyy').format(_startDate), style: const TextStyle(fontSize: 13)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final date = await showDatePicker(context: context, initialDate: _dueDate, firstDate: _startDate, lastDate: DateTime(2030));
                                  if (date != null) setDialogState(() => _dueDate = date);
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'Bitiş', border: OutlineInputBorder()),
                                  child: Text(DateFormat('dd.MM.yyyy').format(_dueDate), style: const TextStyle(fontSize: 13)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ]
                      else if (_planningPeriod == 'Aylık Planlama') ...[
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: _selectedYear,
                                decoration: const InputDecoration(labelText: 'Yıl', border: OutlineInputBorder()),
                                items: [2024, 2025, 2026].map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                                onChanged: (val) => setDialogState(() => _selectedYear = val!),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: _selectedMonth,
                                decoration: const InputDecoration(labelText: 'Ay', border: OutlineInputBorder()),
                                items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text(DateFormat('MMMM', 'tr_TR').format(DateTime(2024, m))))).toList(),
                                onChanged: (val) => setDialogState(() => _selectedMonth = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_selectedUserId != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Theme.of(context).primaryColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Hat:  (Kullanıcı yetkisine göre)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor)),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        const Text('Haftalık İstasyon Seçimi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: availableStations.map((s) {
                            final isSelected = _selectedStations.contains(s);
                            return FilterChip(
                              label: Text(s, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color)),
                              selected: isSelected,
                              selectedColor: Theme.of(context).primaryColor,
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    _selectedStations.add(s);
                                  } else {
                                    _selectedStations.remove(s);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ]
                      else if (_planningPeriod == 'Yıllık Planlama') ...[
                        DropdownButtonFormField<int>(
                          initialValue: _selectedYear,
                          decoration: const InputDecoration(labelText: 'Yıl', border: OutlineInputBorder()),
                          items: [2024, 2025, 2026].map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                          onChanged: (val) => setDialogState(() => _selectedYear = val!),
                        ),
                        const SizedBox(height: 16),
                        if (_selectedUserId != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Theme.of(context).primaryColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Hat:  (Kullanıcı yetkisine göre)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor)),
                                ),
                              ],
                            ),
                          ),
                        const Text('Aylık İstasyon Dağılımı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        ...List.generate(12, (index) {
                          int month = index + 1;
                          String monthName = DateFormat('MMMM', 'tr_TR').format(DateTime(2024, month));
                          List<String> currentMonthStations = _monthlyStations[month]!;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 0,
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.03),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            child: ExpansionTile(
                              title: Text(monthName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                currentMonthStations.isEmpty ? 'İstasyon Seçilmedi' : ' İstasyon',
                                style: TextStyle(fontSize: 11, color: currentMonthStations.isEmpty ? Colors.red : Colors.green),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: availableStations.map((s) {
                                      bool isSelected = currentMonthStations.contains(s);
                                      return FilterChip(
                                        label: Text(s, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color)),
                                        selected: isSelected,
                                        selectedColor: Theme.of(context).primaryColor,
                                        onSelected: (selected) {
                                          setDialogState(() {
                                            if (selected) {
                                              _monthlyStations[month]!.add(s);
                                            } else {
                                              _monthlyStations[month]!.remove(s);
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                  onPressed: () {
                    final selectedAuditType = system.auditTypes.firstWhere(
                      (t) => t.id == _selectedAuditTypeId,
                      orElse: () => system.auditTypes.isNotEmpty ? system.auditTypes.first : AuditTypeModel.fiveS,
                    );
                    final effectiveAuditTypeId = selectedAuditType.id;
                    final groupName = selectedAuditType.title;

                    if (_planningPeriod == 'Tekil Denetim') {
                      if (_selectedStations.isEmpty && _selectedTaskType != 'Plansız Denetim') {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen istasyon seçin.')));
                        return;
                      }
                      final newTask = TaskModel(
                        id: editTask?.id ?? 'T-${Random().nextInt(10000)}',
                        title: groupName,
                        description: '${_selectedLine ?? ""} Hattı ${_selectedStations.join(", ")} istasyonları denetimi.',
                        assignedTitle: _selectedTitle,
                        assignedUserId: _selectedUserId,
                        targetLine: _selectedLine ?? '',
                        targetStations: _selectedStations,
                        startDate: _startDate,
                        dueDate: _dueDate,
                        taskType: _selectedTaskType,
                        auditTypeId: effectiveAuditTypeId,
                      );
                      if (editTask != null) {
                        system.updateTask(newTask);
                      } else {
                        system.addTask(newTask);
                      }
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Görev kaydedildi.')));
                    } else if (_planningPeriod == 'Aylık Planlama') {
                      if (_selectedUserId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Denetçi seçimi zorunludur.')));
                        return;
                      }
                      if (_selectedStations.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen en az bir istasyon seçin.')));
                        return;
                      }
                      List<TaskModel> monthlyTasks = [];
                      for (int week = 1; week <= 4; week++) {
                        DateTime startDate = DateTime(_selectedYear, _selectedMonth, (week - 1) * 7 + 1);
                        DateTime endDate = DateTime(_selectedYear, _selectedMonth, week * 7);
                        monthlyTasks.add(TaskModel(
                          id: 'MT-${Random().nextInt(100000)}',
                          title: '$groupName - $week. Hafta',
                          description: '${_selectedLine ?? ""} hattı $_selectedMonth. ay $week. hafta denetimi.',
                          assignedTitle: _selectedTitle,
                          assignedUserId: _selectedUserId,
                          targetLine: _selectedLine ?? '',
                          targetStations: List.from(_selectedStations),
                          startDate: startDate,
                          dueDate: endDate,
                          taskType: 'Planlı Denetim',
                          auditTypeId: effectiveAuditTypeId,
                        ));
                      }
                      system.addTasks(monthlyTasks);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$_selectedMonth. ay için 4 adet haftalık görev oluşturuldu.')));
                    } else if (_planningPeriod == 'Yıllık Planlama') {
                      if (_selectedUserId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Denetçi seçimi zorunludur.')));
                        return;
                      }
                      bool hasEmptyMonth = _monthlyStations.values.any((list) => list.isEmpty);
                      if (hasEmptyMonth) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen her ay için en az bir istasyon seçin.')));
                        return;
                      }
                      List<TaskModel> yearlyTasks = [];
                      for (int month = 1; month <= 12; month++) {
                        DateTime startDate = DateTime(_selectedYear, month, 1);
                        DateTime endDate = DateTime(_selectedYear, month + 1, 0);
                        yearlyTasks.add(TaskModel(
                          id: 'YT-${Random().nextInt(100000)}',
                          title: '$groupName - ${monthName(month)}',
                          description: '${_selectedLine ?? ""} hattı yıllık planlı denetimi.',
                          assignedTitle: _selectedTitle,
                          assignedUserId: _selectedUserId,
                          targetLine: _selectedLine ?? '',
                          targetStations: List.from(_monthlyStations[month]!),
                          startDate: startDate,
                          dueDate: endDate,
                          taskType: 'Planlı Denetim',
                          auditTypeId: effectiveAuditTypeId,
                        ));
                      }
                      system.addTasks(yearlyTasks);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$_selectedYear yılı için 12 adet aylık görev oluşturuldu.')));
                    }
                  },
                  child: Text(editTask == null ? 'Oluştur' : 'Güncelle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String monthName(int m) {
    return DateFormat('MMMM', 'tr_TR').format(DateTime(2024, m));
  }

  IconData _auditTypeIcon(AuditTypeModel type) {
    if (type.id == AuditTypeModel.stationInspectionId) {
      return Icons.domain_rounded;
    }
    return Icons.fact_check_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final system = context.watch<SystemProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Görev Planlama'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(),
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: system.users.map((user) {
          final userTasks = system.tasks.where((t) => t.assignedUserId == user.id).toList();
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                '${userTasks.length} Aktif Görev | ${user.title}',
                style: const TextStyle(fontSize: 12),
              ),
              children: userTasks.map((task) {
                final isOverdue = task.dueDate.isBefore(DateTime.now()) && !task.isCompleted;
                return Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.12))),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Icon(
                      task.isCompleted ? Icons.check_circle : Icons.pending_actions,
                      color: task.isCompleted 
                          ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4ADE80) : const Color(0xFF2E7D32)) 
                          : (isOverdue 
                              ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF87171) : const Color(0xFFD32F2F)) 
                              : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFB923C) : const Color(0xFFEA580C))),
                    ),
                    title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${DateFormat('dd.MM.yyyy').format(task.startDate)} - ${DateFormat('dd.MM.yyyy').format(task.dueDate)} | ${task.targetLine}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        if (task.targetStations.isNotEmpty)
                          Text(
                            'İstasyonlar: ${task.targetStations.join(", ")}',
                            style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor, size: 20),
                          onPressed: () => _showTaskDialog(editTask: task),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF87171) : AppColors.accentRed, size: 20),
                          onPressed: () => _showDeleteConfirmation(task),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showDeleteConfirmation(TaskModel task) {
    final system = context.read<SystemProvider>();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Görevi Sil'),
          content: const Text('Bu görevi silmek istediğinize emin misiniz?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF87171) : AppColors.accentRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                system.removeTask(task.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Görev silindi.')),
                );
              },
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );
  }
}
