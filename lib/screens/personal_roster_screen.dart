import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';

class PersonalRosterScreen extends StatefulWidget {
  const PersonalRosterScreen({super.key});

  @override
  State<PersonalRosterScreen> createState() => _PersonalRosterScreenState();
}

class _PersonalRosterScreenState extends State<PersonalRosterScreen> with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;
  bool _isLoading = false;
  Map<String, dynamic> _daysData = {};
  List<Map<String, dynamic>> _shiftsList = [];
  late TabController _tabController;

  // Fallback defaults if shifts collection is empty
  final List<Map<String, dynamic>> _defaultShifts = [
    {'code': 'S8', 'name': 'Sabah', 'hours': '06:30 - 15:30', 'type': 'work', 'group': 'sabah'},
    {'code': 'S10', 'name': 'Sabah', 'hours': '06:45 - 15:45', 'type': 'work', 'group': 'sabah'},
    {'code': 'S12', 'name': 'Sabah', 'hours': '07:00 - 16:00', 'type': 'work', 'group': 'sabah'},
    {'code': 'N', 'name': 'Sabah (Normal)', 'hours': '08:00 - 17:00', 'type': 'work', 'group': 'sabah'},
    {'code': 'A9', 'name': 'Akşam', 'hours': '14:00 - 23:00', 'type': 'work', 'group': 'aksam'},
    {'code': 'A10', 'name': 'Akşam', 'hours': '12:00 - 21:00', 'type': 'work', 'group': 'aksam'},
    {'code': 'A11', 'name': 'Akşam', 'hours': '14:30 - 23:30', 'type': 'work', 'group': 'aksam'},
    {'code': 'A12', 'name': 'Akşam', 'hours': '14:45 - 23:45', 'type': 'work', 'group': 'aksam'},
    {'code': 'A13', 'name': 'Akşam', 'hours': '15:00 - 23:59', 'type': 'work', 'group': 'aksam'},
    {'code': 'İ', 'name': 'Haftalık İzin', 'hours': 'Tatil', 'type': 'off', 'group': 'izin'},
    {'code': 'Yİ', 'name': 'Yıllık İzin', 'hours': 'İzinli', 'type': 'off', 'group': 'izin'},
    {'code': 'R', 'name': 'Rapor', 'hours': 'İstirahat', 'type': 'off', 'group': 'izin'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _tabController = TabController(length: 2, vsync: this);
    _loadShiftsAndRoster();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _docId {
    final user = context.read<AuthProvider>().user;
    final userId = user?.id ?? 'unknown';
    return '${userId}_${_selectedDate.year}_${_selectedDate.month}';
  }

  Future<void> _loadShiftsAndRoster() async {
    setState(() {
      _isLoading = true;
      _daysData = {};
    });

    try {
      // 1. Fetch shifts from database
      final shiftsSnapshot =
          await FirebaseFirestore.instance.collection('shifts').get();
      if (shiftsSnapshot.docs.isNotEmpty) {
        _shiftsList = shiftsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'code': data['code'] ?? '',
            'name': data['name'] ?? '',
            'hours': data['hours'] ?? '',
            'type': data['type'] ?? 'work',
            'group': data['group'] ?? 'sabah',
          };
        }).toList();
      } else {
        _shiftsList = List.from(_defaultShifts);
      }

      // 2. Load user monthly roster data
      final doc = await FirebaseFirestore.instance
          .collection('user_rosters')
          .doc(_docId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['days'] != null) {
          _daysData = Map<String, dynamic>.from(data['days']);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veriler yüklenirken hata oluştu: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _autoSaveRoster() async {
    try {
      final user = context.read<AuthProvider>().user;
      await FirebaseFirestore.instance
          .collection('user_rosters')
          .doc(_docId)
          .set({
        'userId': user?.id,
        'userName': user?.name,
        'year': _selectedDate.year,
        'month': _selectedDate.month,
        'updatedAt': FieldValue.serverTimestamp(),
        'days': _daysData,
      });
    } catch (e) {
      debugPrint('Auto-save error: $e');
    }
  }

  int get _daysInMonth {
    return DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
  }

  int get _firstWeekdayOfMonth {
    return DateTime(_selectedDate.year, _selectedDate.month, 1).weekday;
  }

  // Shift group color themes
  Color _getShiftColor(String code, String group) {
    if (code == 'İ') return const Color(0xFF34C759); // Green
    if (code == 'Yİ') return const Color(0xFFAF52DE); // Purple
    if (code == 'R') return const Color(0xFFFF3B30); // Red
    
    if (group == 'sabah') return const Color(0xFF007AFF); // Blue
    if (group == 'aksam') return const Color(0xFFFF9500); // Orange
    return Colors.blueGrey;
  }

  void _openShiftSelectionBottomSheet(int dayNum) {
    final dayKey = dayNum.toString();
    final dayData = _daysData[dayKey] ?? {'shift': '', 'excuse': ''};
    String currentSelectedShift = dayData['shift'] ?? '';

    final currentDayDate = DateTime(_selectedDate.year, _selectedDate.month, dayNum);
    final dayTitleString = '${dayNum} ${DateFormat('MMMM yyyy', 'tr_TR').format(currentDayDate)}';

    // Group shifts locally
    final sabahShifts = _shiftsList.where((s) => s['group'] == 'sabah').toList();
    final aksamShifts = _shiftsList.where((s) => s['group'] == 'aksam').toList();
    final izinShifts = _shiftsList.where((s) => s['group'] == 'izin').toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final sheetBgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
            final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

            Widget buildShiftTile(Map<String, dynamic> s) {
              final code = s['code'] as String;
              final name = s['name'] as String;
              final hours = s['hours'] as String;
              final group = s['group'] as String;

              final isSelected = currentSelectedShift == code;
              final colorTheme = _getShiftColor(code, group);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: InkWell(
                  onTap: () {
                    setModalState(() {
                      currentSelectedShift = code;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? colorTheme.withOpacity(0.08) 
                          : isDark ? Colors.white.withOpacity(0.02) : Colors.grey.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? colorTheme : (isDark ? Colors.white10 : Colors.black12),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Left: Code Badge
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colorTheme,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colorTheme.withOpacity(0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              )
                            ]
                          ),
                          child: Center(
                            child: Text(
                              code,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Middle: Text Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 13,
                                    color: colorTheme.withOpacity(0.8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    hours,
                                    style: TextStyle(
                                      color: isDark ? Colors.white60 : Colors.black54,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Right: Selection Checkmark
                        if (isSelected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: colorTheme,
                            size: 26,
                          )
                        else
                          Icon(
                            Icons.radio_button_off_rounded,
                            color: isDark ? Colors.white24 : Colors.black26,
                            size: 24,
                          )
                      ],
                    ),
                  ),
                ),
              );
            }

            Widget buildGroupSection(String title, List<Map<String, dynamic>> items, Color groupColor) {
              if (items.isEmpty) return const SizedBox();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 14.0, bottom: 8.0),
                    child: Text(
                      title,
                      style: TextStyle(
                        color: groupColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  ...items.map(buildShiftTile),
                ],
              );
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: BoxDecoration(
                color: sheetBgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // Drag Handle
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Title Header
                  Text(
                    dayTitleString,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  // Grouped Scroll View
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildGroupSection(
                            'Sabah Vardiyaları', 
                            sabahShifts, 
                            const Color(0xFF007AFF)
                          ),
                          buildGroupSection(
                            'Akşam Vardiyaları', 
                            aksamShifts, 
                            const Color(0xFFFF9500)
                          ),
                          buildGroupSection(
                            'İzin ve Diğer', 
                            izinShifts, 
                            const Color(0xFF34C759)
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Bottom Actions
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    decoration: BoxDecoration(
                      color: sheetBgColor,
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                      ),
                    ),
                    child: Row(
                      children: [
                        // İptal
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              side: BorderSide(
                                color: isDark ? Colors.white24 : Colors.grey,
                              ),
                            ),
                            child: Text(
                              'İptal',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Temizle
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _daysData.remove(dayKey);
                            });
                            _autoSaveRoster();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF3B30), size: 18),
                          label: const Text('Temizle', style: TextStyle(color: Color(0xFFFF3B30), fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF3B30).withOpacity(0.08),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Kaydet
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                if (currentSelectedShift.isNotEmpty) {
                                  final currentExcuse = dayData['excuse'] ?? '';
                                  _daysData[dayKey] = {
                                    'shift': currentSelectedShift,
                                    'excuse': currentExcuse,
                                  };
                                } else {
                                  _daysData.remove(dayKey);
                                }
                              });
                              _autoSaveRoster();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF007AFF),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 2,
                              shadowColor: const Color(0xFF007AFF).withOpacity(0.3),
                            ),
                            child: const Text(
                              'Kaydet',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openExcuseInputDialog(int dayNum) {
    final dayKey = dayNum.toString();
    final dayData = _daysData[dayKey] ?? {'shift': '', 'excuse': ''};
    final excuseController = TextEditingController(text: dayData['excuse'] ?? '');
    final shift = dayData['shift'] ?? '';

    final currentDayDate = DateTime(_selectedDate.year, _selectedDate.month, dayNum);
    final formattedDate = '${dayNum} ${DateFormat('MMMM yyyy', 'tr_TR').format(currentDayDate)}';

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            '$formattedDate Mazeret',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shift.isNotEmpty ? 'Seçili Vardiya: $shift' : 'Seçili Vardiya Yok',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: excuseController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Mazeret açıklamasını buraya yazın...',
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            if (excuseController.text.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() {
                    if (shift.isNotEmpty) {
                      _daysData[dayKey] = {
                        'shift': shift,
                        'excuse': '',
                      };
                    } else {
                      _daysData.remove(dayKey);
                    }
                  });
                  _autoSaveRoster();
                  Navigator.pop(context);
                },
                child: const Text('Temizle', style: TextStyle(color: Colors.red)),
              ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _daysData[dayKey] = {
                    'shift': shift,
                    'excuse': excuseController.text.trim(),
                  };
                });
                _autoSaveRoster();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Segment 1: Compact 7-Column Calendar Grid View
  Widget _buildRosterCalendarGrid(bool isDark) {
    final daysInMonth = _daysInMonth;
    final firstWeekday = _firstWeekdayOfMonth;
    
    // Shift index offset matching Monday-first calendar columns
    // firstWeekday: 1=Mon, 2=Tue... 7=Sun
    final leadingEmptyCells = firstWeekday - 1;

    final weekDays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return Column(
      children: [
        // Grid Header (Week days names)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDays.map((d) => Expanded(
              child: Center(
                child: Text(
                  d,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
            )).toList(),
          ),
        ),
        // Grid Content
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: daysInMonth + leadingEmptyCells,
            itemBuilder: (context, index) {
              if (index < leadingEmptyCells) {
                return const SizedBox();
              }

              final dayNum = index - leadingEmptyCells + 1;
              final dayKey = dayNum.toString();
              
              final dayData = _daysData[dayKey] ?? {'shift': '', 'excuse': ''};
              final selectedShift = dayData['shift'] ?? '';
              final excuse = dayData['excuse'] ?? '';

              final matchedShift = _shiftsList.firstWhere(
                (s) => s['code'] == selectedShift,
                orElse: () => <String, dynamic>{},
              );
              final shiftGroup = matchedShift['group'] ?? '';
              
              final isShiftSelected = selectedShift.isNotEmpty;
              final themeColor = isShiftSelected 
                  ? _getShiftColor(selectedShift, shiftGroup) 
                  : Colors.grey;

              return InkWell(
                onTap: () => _openShiftSelectionBottomSheet(dayNum),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isShiftSelected 
                        ? themeColor.withOpacity(0.08) 
                        : isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.015),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isShiftSelected ? themeColor : (isDark ? Colors.white12 : Colors.black.withOpacity(0.06)),
                      width: isShiftSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Day Number
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      // Shift code circular badge
                      if (isShiftSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: themeColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            selectedShift,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        )
                      else
                        Icon(
                          Icons.add_rounded,
                          size: 15,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      // Indicator of Excuse
                      if (excuse.isNotEmpty)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF9500),
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(height: 4),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Segment 2: Excuse entry with active list and manual day selector
  Widget _buildExcuseList(bool isDark) {
    final excuseDays = _daysData.entries
        .where((e) => (e.value['excuse'] ?? '').toString().trim().isNotEmpty)
        .toList();

    // Sort by day number
    excuseDays.sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));

    return Column(
      children: [
        const SizedBox(height: 8),
        // Excuses List
        Expanded(
          child: excuseDays.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_turned_in_rounded,
                        size: 48,
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Kayıtlı mazeret bulunmamaktadır.',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  itemCount: excuseDays.length,
                  itemBuilder: (context, index) {
                    final entry = excuseDays[index];
                    final dayNum = int.parse(entry.key);
                    final dayKey = entry.key;
                    final currentDayDate = DateTime(_selectedDate.year, _selectedDate.month, dayNum);
                    final dayName = DateFormat('EEEE', 'tr_TR').format(currentDayDate);

                    final excuse = entry.value['excuse'] ?? '';
                    final shift = entry.value['shift'] ?? '';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                        ),
                      ),
                      color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.012),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            // Date Column
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$dayNum ${DateFormat('MMMM', 'tr_TR').format(currentDayDate)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$dayName ${shift.isNotEmpty ? "($shift)" : ""}',
                                    style: TextStyle(
                                      color: isDark ? Colors.white54 : Colors.black54,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Excuse Content & Edit Column
                            Expanded(
                              flex: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF9500).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9500), size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        excuse,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFFFF9500), 
                                          fontSize: 12, 
                                          fontWeight: FontWeight.bold
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kişisel Puantaj & Mazeret'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Ay/Yıl Seçici Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        onPressed: () {
                          setState(() {
                            _selectedDate = DateTime(
                              _selectedDate.year,
                              _selectedDate.month - 1,
                            );
                          });
                          _loadShiftsAndRoster();
                        },
                      ),
                      Text(
                        DateFormat('MMMM yyyy', 'tr_TR').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios_rounded),
                        onPressed: () {
                          setState(() {
                            _selectedDate = DateTime(
                              _selectedDate.year,
                              _selectedDate.month + 1,
                            );
                          });
                          _loadShiftsAndRoster();
                        },
                      ),
                    ],
                  ),
                ),
                // Custom Tab Bar for Puantaj and Mazeret
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      labelColor: isDark ? Colors.white : const Color(0xFF007AFF),
                      unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      tabs: const [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_view_month_rounded, size: 16),
                              SizedBox(width: 6),
                              Text('Puantaj Girişi'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_late_rounded, size: 16),
                              SizedBox(width: 6),
                              Text('Mazeret Girişi'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Tab Views Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Compact Month Calendar Grid
                      _buildRosterCalendarGrid(isDark),
                      // Tab 2: Timeline Excuse List
                      _buildExcuseList(isDark),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
