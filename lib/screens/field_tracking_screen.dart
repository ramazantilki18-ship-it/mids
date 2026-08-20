import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/system_provider.dart';
import '../services/field_tracking_service.dart';
import 'personal_roster_screen.dart';

class FieldTrackingScreen extends StatefulWidget {
  const FieldTrackingScreen({super.key});

  @override
  State<FieldTrackingScreen> createState() => _FieldTrackingScreenState();
}

class _FieldTrackingScreenState extends State<FieldTrackingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _rosterLoading = false;
  String _todayShiftCode = '';
  bool _isDailyStatusSaved = false;
  Timer? _timer;
  Duration _sessionDuration = Duration.zero;
  String _historyDateFilter = 'all';

  // Günlük Durum Formu Alanları
  String _selectedShift = '';
  String _meetingType = 'none'; // 'none', 'meeting', 'training', 'other'
  bool _hasMeeting = false;
  final TextEditingController _meetingDescriptionController = TextEditingController();
  TimeOfDay _meetingStartTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _meetingEndTime = const TimeOfDay(hour: 12, minute: 0);
  bool _savingStatus = false;

  List<Map<String, dynamic>> _shiftsList = [];
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
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTodayRoster();
      _startDurationTimerIfNeeded();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer?.cancel();
    _meetingDescriptionController.dispose();
    super.dispose();
  }

  void _startDurationTimerIfNeeded() {
    final tracking = context.read<FieldTrackingService>();
    if (tracking.isTracking) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateSessionDuration();
    });
  }

  void _calculateSessionDuration() {
    final tracking = context.read<FieldTrackingService>();
    if (!tracking.isTracking || tracking.currentSessionId == null) {
      _timer?.cancel();
      if (mounted) {
        setState(() {
          _sessionDuration = Duration.zero;
        });
      }
      return;
    }

    final timestampPart = tracking.currentSessionId!.split('_').last;
    final startMs =
        int.tryParse(timestampPart) ?? DateTime.now().millisecondsSinceEpoch;
    final startTime = DateTime.fromMillisecondsSinceEpoch(startMs);

    if (mounted) {
      setState(() {
        _sessionDuration = DateTime.now().difference(startTime);
      });
    }
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

      // 2. Load daily status
      final now = DateTime.now();
      final docId = '${user.id}_${now.year}_${now.month}';
      final doc = await FirebaseFirestore.instance
          .collection('user_rosters')
          .doc(docId)
          .get();

      if (doc.exists && doc.data() != null) {
        final days = doc.data()?['days'] as Map?;
        if (days != null) {
          final todayData = days['${now.day}'];
          String code = '';
          bool fieldActive = false;
          bool hasMtg = false;
          String mtgType = 'none';
          String mtgDesc = '';
          String mtgStart = '';
          String mtgEnd = '';

          if (todayData is Map) {
            code = todayData['shift']?.toString() ?? '';
            fieldActive = todayData['isFieldTrackingActive'] == true;
            hasMtg = todayData['hasMeeting'] == true;
            mtgType = todayData['meetingType']?.toString() ?? (hasMtg ? 'meeting' : 'none');
            mtgDesc = todayData['meetingDescription']?.toString() ?? '';
            mtgStart = todayData['meetingStart']?.toString() ?? '';
            mtgEnd = todayData['meetingEnd']?.toString() ?? '';
          } else if (todayData is String) {
            code = todayData;
          }

          if (mounted) {
            setState(() {
              _todayShiftCode = code;
              _selectedShift = code.isNotEmpty ? code : '';
              _isDailyStatusSaved = fieldActive;
              _meetingType = mtgType;
              _hasMeeting = hasMtg;
              _meetingDescriptionController.text = mtgDesc;
              if (mtgStart.contains(':')) {
                final parts = mtgStart.split(':');
                _meetingStartTime = TimeOfDay(
                  hour: int.tryParse(parts[0]) ?? 10,
                  minute: int.tryParse(parts[1]) ?? 0,
                );
              }
              if (mtgEnd.contains(':')) {
                final parts = mtgEnd.split(':');
                _meetingEndTime = TimeOfDay(
                  hour: int.tryParse(parts[0]) ?? 12,
                  minute: int.tryParse(parts[1]) ?? 0,
                );
              }
              _rosterLoading = false;
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _todayShiftCode = '';
          _rosterLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading shift for field tracking: $e');
      if (mounted) {
        setState(() {
          _rosterLoading = false;
        });
      }
    }
  }

  String _getShiftDisplayName(String code) {
    if (_shiftsList.isEmpty) return code;
    final s = _shiftsList.firstWhere(
      (element) => element['code'] == code,
      orElse: () => {'code': code, 'name': 'Vardiya', 'hours': ''},
    );
    final hours = s['hours'] != null && s['hours'].toString().isNotEmpty ? ' (${s['hours']})' : '';
    return '$code - ${s['name']}$hours';
  }

  Color _getShiftColor(String code, String group) {
    if (code == 'İ') return const Color(0xFF34C759);
    if (code == 'Yİ') return const Color(0xFFAF52DE);
    if (code == 'R') return const Color(0xFFFF3B30);
    if (group == 'sabah') return const Color(0xFF007AFF);
    if (group == 'aksam') return const Color(0xFFFF9500);
    return Colors.blueGrey;
  }

  void _openShiftSelectionBottomSheet() {
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

              final isSelected = _selectedShift == code;
              final colorTheme = _getShiftColor(code, group);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedShift = code;
                    });
                    setModalState(() {});
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? colorTheme.withOpacity(0.08) 
                          : isDark ? Colors.white.withOpacity(0.02) : Colors.grey.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? colorTheme : (isDark ? Colors.white10 : Colors.black12),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: colorTheme,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              code,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hours,
                                style: TextStyle(
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: colorTheme,
                            size: 22,
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
                    padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
                    child: Text(
                      title,
                      style: TextStyle(
                        color: groupColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  ...items.map(buildShiftTile),
                ],
              );
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: sheetBgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Bugünkü Vardiyanızı Seçin',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          buildGroupSection('SABAH VARDİYALARI', sabahShifts, const Color(0xFF007AFF)),
                          buildGroupSection('AKŞAM VARDİYALARI', aksamShifts, const Color(0xFFFF9500)),
                          buildGroupSection('İZİN VE DİĞER', izinShifts, const Color(0xFF34C759)),
                        ],
                      ),
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

  bool _isOffDay(String shiftCode) {
    if (shiftCode.isEmpty) return true;
    final upper = shiftCode.toUpperCase();
    return ['İ', 'Yİ', 'R', 'OFF', 'TATİL', 'İZİN'].contains(upper);
  }

  int _calculateMeetingDuration() {
    final startMinutes = _meetingStartTime.hour * 60 + _meetingStartTime.minute;
    final endMinutes = _meetingEndTime.hour * 60 + _meetingEndTime.minute;
    return endMinutes > startMinutes ? endMinutes - startMinutes : 0;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveDailyStatus() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    if (_selectedShift.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir vardiya seçin.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final hasMtg = _meetingType != 'none';
    final desc = _meetingDescriptionController.text.trim();

    if (hasMtg && _meetingType == 'other' && desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen diğer seçeneği için açıklama girin.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _savingStatus = true;
    });

    try {
      final now = DateTime.now();
      final docId = '${user.id}_${now.year}_${now.month}';
      final dayKey = '${now.day}';

      final meetingDuration = hasMtg ? _calculateMeetingDuration() : 0;

      final dayData = {
        'shift': _selectedShift,
        'isFieldTrackingActive': true,
        'hasMeeting': hasMtg,
        'meetingType': _meetingType,
        'meetingDescription': desc,
        'meetingStart': hasMtg ? _formatTimeOfDay(_meetingStartTime) : '',
        'meetingEnd': hasMtg ? _formatTimeOfDay(_meetingEndTime) : '',
        'meetingDuration': meetingDuration,
      };

      await FirebaseFirestore.instance
          .collection('user_rosters')
          .doc(docId)
          .set(
        {
          'userId': user.id,
          'year': now.year,
          'month': now.month,
          'days': {dayKey: dayData},
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        setState(() {
          _todayShiftCode = _selectedShift;
          _isDailyStatusSaved = true;
          _hasMeeting = hasMtg;
          _savingStatus = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Günlük durum kaydedildi! ${hasMtg ? '(${_meetingType == 'meeting' ? 'Toplantı' : _meetingType == 'training' ? 'Eğitim' : 'Diğer'}: ${_formatTimeOfDay(_meetingStartTime)} - ${_formatTimeOfDay(_meetingEndTime)})' : ''}',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Otomatik olarak Saha Takip sekmesine geç
        _tabController.animateTo(1);
      }
    } catch (e) {
      debugPrint('Error saving daily status: $e');
      if (mounted) {
        setState(() {
          _savingStatus = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kaydedilirken hata oluştu. Tekrar deneyin.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleStartTracking() async {
    final auth = context.read<AuthProvider>();
    final system = context.read<SystemProvider>();
    final tracking = context.read<FieldTrackingService>();

    if (auth.user == null) return;

    if (_isOffDay(_todayShiftCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bugün izin gününüz olduğundan saha takibi başlatılamaz.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final success = await tracking.startSession(
      userId: auth.user!.id,
      userName: auth.user!.name,
      userTitle: auth.user!.jobTitle ?? 'Saha Personeli',
      shiftCode: _todayShiftCode.isEmpty ? 'G' : _todayShiftCode,
      systemProvider: system,
    );

    if (success) {
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saha takibi ve konum doğrulama başlatıldı.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saha takibi başlatılamadı. Lütfen konum servisini ve izinlerinizi kontrol edin.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleStopTracking() async {
    final tracking = context.read<FieldTrackingService>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saha Takibini Bitir'),
        content: const Text('Sahadan ayrıldınız mı? Bugüne ait saha mesai takibi sonlandırılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İPTAL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('TAKİBİ BİTİR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await tracking.stopSession();
      _timer?.cancel();
      if (mounted) {
        setState(() {
          _sessionDuration = Duration.zero;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saha takibi sonlandırıldı. Veriler kaydedildi.'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  Future<void> _pickTime(BuildContext context, bool isStart) async {
    final initialTime = isStart ? _meetingStartTime : _meetingEndTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _meetingStartTime = picked;
        } else {
          _meetingEndTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<FieldTrackingService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saha Takip Sistemi'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.tealAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.assignment), text: 'Günlük Durum'),
            Tab(icon: Icon(Icons.my_location), text: 'Saha Takip'),
            Tab(icon: Icon(Icons.history), text: 'Geçmiş Takip'),
          ],
        ),
      ),
      body: _rosterLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDailyStatusTab(isDark),
                _buildFieldTrackingTab(tracking, isDark),
                _buildHistoryTab(isDark),
              ],
            ),
    );
  }

  // ===================================================================
  // SEKME 1: GÜNLÜK DURUM GİRİŞİ (PUANTAJ & TOPLANTI)
  // ===================================================================
  Widget _buildDailyStatusTab(bool isDark) {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      return const Center(child: Text('Kullanıcı bilgisi bulunamadı.'));
    }

    final now = DateTime.now();
    final dateStr = DateFormat('d MMMM yyyy, EEEE', 'tr').format(now);
    final todayStart = DateTime(now.year, now.month, now.day);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('field_sessions')
          .where('userId', isEqualTo: user.id)
          .where('date', isEqualTo: Timestamp.fromDate(todayStart))
          .snapshots(),
      builder: (context, snapshot) {
        int totalMinutes = 0;
        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['status'] == 'active') {
              final tracking = context.read<FieldTrackingService>();
              if (tracking.isTracking) {
                totalMinutes += _sessionDuration.inMinutes;
              }
            } else {
              totalMinutes += (data['totalDuration'] as num? ?? 0).toInt();
            }
          }
        }

        final hours = totalMinutes ~/ 60;
        final minutes = totalMinutes % 60;
        final totalDurationStr = hours > 0 ? '${hours}sa ${minutes}dk' : '${minutes}dk';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tarih Başlığı
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.blue, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bugünün Tarihi',
                              style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(dateStr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      if (_isDailyStatusSaved)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 16),
                              SizedBox(width: 4),
                              Text('Kaydedildi', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bugünkü Toplam Saha Süresi Göstergesi
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: isDark 
                          ? [Colors.teal.shade900, Colors.teal.shade700] 
                          : [Colors.teal.shade50, Colors.teal.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.tealAccent.withOpacity(0.1) : Colors.teal.shade700.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.timer_outlined,
                            color: isDark ? Colors.tealAccent : Colors.teal.shade800,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bugünkü Toplam Saha Süresi',
                                style: TextStyle(
                                  fontSize: 12, 
                                  fontWeight: FontWeight.w600, 
                                  color: isDark ? Colors.tealAccent.shade100 : Colors.teal.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                totalDurationStr,
                                style: TextStyle(
                                  fontSize: 22, 
                                  fontWeight: FontWeight.bold, 
                                  color: isDark ? Colors.white : Colors.teal.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Vardiya Seçimi (Tıklanabilir Küçük Kart)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: _openShiftSelectionBottomSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.work_outline, color: Colors.teal, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bugünkü Vardiya',
                                style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedShift.isEmpty
                                    ? 'Vardiya Seçmek İçin Dokunun'
                                    : _getShiftDisplayName(_selectedShift),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PersonalRosterScreen(hideExcuseTab: true)),
                    );
                    _loadTodayRoster();
                  },
                  icon: const Icon(Icons.calendar_month, color: Colors.teal, size: 18),
                  label: const Text(
                    'Aylık Vardiya Planı Gir',
                    style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Özel Durum / Plan Seçimi (Toplantı, Eğitim, Diğer)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.groups, color: Colors.purple, size: 22),
                          SizedBox(width: 8),
                          Text('Özel Durum / Plan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            _buildOzelDurumOption(context, 'Yok', 'none'),
                            _buildOzelDurumOption(context, 'Toplantı', 'meeting'),
                            _buildOzelDurumOption(context, 'Eğitim', 'training'),
                            _buildOzelDurumOption(context, 'Diğer', 'other'),
                          ],
                        ),
                      ),
                      if (_meetingType != 'none') ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.purple.withOpacity(0.15)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildTimeRow(label: 'Başlangıç Saati', time: _meetingStartTime, onTap: () => _pickTime(context, true)),
                              const Divider(height: 16),
                              _buildTimeRow(label: 'Bitiş Saati', time: _meetingEndTime, onTap: () => _pickTime(context, false)),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Etkinlik Süresi:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.purple)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.purple.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                                    child: Text('${_calculateMeetingDuration()} dakika', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                                  ),
                                ],
                              ),
                              if (_meetingType == 'other') ...[
                                const Divider(height: 16),
                                const Text('Açıklama / Gerekçe', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.purple)),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _meetingDescriptionController,
                                  enabled: true,
                                  decoration: InputDecoration(
                                    hintText: 'Lütfen bugüne ait açıklamayı girin...',
                                    hintStyle: const TextStyle(fontSize: 13),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Colors.purple, width: 1.5),
                                    ),
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                  maxLines: 2,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bu süre saha mesai hedefinizden düşülecektir.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Kaydet / Güncelle Butonu
              ElevatedButton.icon(
                onPressed: _savingStatus ? null : _saveDailyStatus,
                icon: _savingStatus
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(_isDailyStatusSaved ? Icons.edit : Icons.save),
                label: Text(
                  _isDailyStatusSaved ? 'GÜNLÜK DURUMU GÜNCELLE' : 'GÜNLÜK DURUMU KAYDET',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeRow({required String label, required TimeOfDay time, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time, size: 18, color: Colors.purple),
                  const SizedBox(width: 6),
                  Text(_formatTimeOfDay(time), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOzelDurumOption(BuildContext context, String label, String value) {
    final isSelected = _meetingType == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _meetingType = value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.purple
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // ===================================================================
  // SEKME 2: SAHA TAKİP (HARİTA VE BAŞLAT / DURDUR)
  // ===================================================================
  String? _selectedLineForCheckIn;
  String? _selectedStationForCheckIn;
  bool _isCheckingIn = false;

  // ===================================================================
  // SEKME 2: SAHA TAKİP (MANUEL KONUM DOĞRULAMALI GİRİŞ / ÇIKIŞ)
  // ===================================================================
  Widget _buildFieldTrackingTab(FieldTrackingService tracking, bool isDark) {
    // Eğer günlük durum girilmemişse kilitle
    if (!_isDailyStatusSaved && !tracking.isTracking) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 20),
              const Text('Saha Takibi Kilitli', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                'Saha takibini başlatabilmek için önce "Günlük Durum" sekmesinden puantajınızı doldurun.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Günlük Durumu Doldur'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatusCard(tracking, isDark),
          if (_todayShiftCode.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildShiftSummaryCard(isDark),
          ],
          if (tracking.isTracking) ...[
            const SizedBox(height: 16),
            _buildActiveStationHeader(tracking, isDark),
            const SizedBox(height: 16),
            _buildManualCheckInCard(tracking, isDark),
            const SizedBox(height: 16),
            _buildVisitsList(tracking, isDark),
            const SizedBox(height: 24),
          ],
          _buildActionButton(tracking),
        ],
      ),
    );
  }

  Widget _buildStatusCard(FieldTrackingService tracking, bool isDark) {
    final statusText = tracking.isTracking ? 'SAHADAYIM (MESAI AKTİF)' : 'Saha Takibi Kapalı';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: tracking.isTracking
                ? [Colors.teal.shade800, Colors.green.shade700]
                : [Colors.blueGrey.shade700, Colors.grey.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: tracking.isTracking ? Colors.greenAccent : Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusText.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (tracking.isTracking) ...[
              const Text('AKTİF SAHA SÜRESİ', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
              const SizedBox(height: 8),
              Text(
                _formatDuration(_sessionDuration),
                style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ] else ...[
              const Icon(Icons.location_off, size: 48, color: Colors.white54),
              const SizedBox(height: 12),
              const Text(
                'Saha mesainizi başlatın. Gittiğiniz istasyonlara butonla konum doğrulayarak kolayca giriş/çıkış yapın.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShiftSummaryCard(bool isDark) {
    final isOff = _isOffDay(_todayShiftCode);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(isOff ? Icons.event_busy : Icons.work, color: isOff ? Colors.orange : Colors.green, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bugünkü Vardiya Bilgisi', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        isOff ? 'İzin Günü ($_todayShiftCode)' : 'Çalışma Günü ($_todayShiftCode)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTodayRoster, tooltip: 'Vardiyayı Yenile'),
              ],
            ),
            if (_meetingType != 'none') ...[
              const Divider(height: 16),
              Row(
                children: [
                  Icon(
                    _meetingType == 'meeting'
                        ? Icons.groups
                        : _meetingType == 'training'
                            ? Icons.school
                            : Icons.info_outline,
                    color: Colors.purple,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_meetingType == 'meeting' ? 'Toplantı' : _meetingType == 'training' ? 'Eğitim' : 'Diğer (${_meetingDescriptionController.text})'}: ${_formatTimeOfDay(_meetingStartTime)} - ${_formatTimeOfDay(_meetingEndTime)} (${_calculateMeetingDuration()} dk)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.purple),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveStationHeader(FieldTrackingService tracking, bool isDark) {
    final currentStation = tracking.currentStationName;
    final entryTime = tracking.currentStationEntryTime;

    if (currentStation == null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.directions_walk_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Şu Anki Durumunuz', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text('Yolda / İstasyon Dışı', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final entryTimeStr = entryTime != null ? DateFormat('HH:mm').format(entryTime) : '';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? const Color(0xFF0F382C) : const Color(0xFFE6F4EA),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bulunduğunuz İstasyon', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(currentStation, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                      if (entryTimeStr.isNotEmpty)
                        Text('Giriş Saati: $entryTimeStr', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final system = context.read<SystemProvider>();
                final result = await tracking.checkOutStation(
                  systemProvider: system,
                  lineName: _selectedLineForCheckIn,
                );

                if (context.mounted) {
                  if (result['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? '"$currentStation" istasyonundan çıkış yapıldı.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  } else {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                            SizedBox(width: 8),
                            Text('Çıkış Doğrulanamadı', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                        content: Text(result['message'] ?? 'Çıkış yapılamadı.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('TAMAM'),
                          ),
                        ],
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.orange),
              label: Text('"$currentStation" İSTASYONUNDAN ÇIKIŞ YAP', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.orange, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualCheckInCard(FieldTrackingService tracking, bool isDark) {
    final system = context.watch<SystemProvider>();
    final currentStation = tracking.currentStationName;

    final lines = system.lines;
    _selectedLineForCheckIn ??= lines.isNotEmpty ? lines.first : null;

    final stationsForLine = _selectedLineForCheckIn != null
        ? (system.stations[_selectedLineForCheckIn] ?? [])
        : <String>[];

    if (_selectedStationForCheckIn == null || !stationsForLine.contains(_selectedStationForCheckIn)) {
      _selectedStationForCheckIn = stationsForLine.isNotEmpty ? stationsForLine.first : null;
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.add_location_alt_rounded, color: Colors.teal, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    currentStation != null ? 'Farklı Bir İstasyona Geçiş Yap' : 'İstasyona Giriş Yap (Konum Doğrulamalı)',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              currentStation != null 
                  ? 'Şu an $currentStation istasyonundasınız. Farklı bir istasyona giriş yaparsanız, $currentStation çıkışınız otomatik kaydedilir.'
                  : 'Bulunduğunuz istasyonu seçip "Giriş Yap" butonuna basın. Anlık GPS konumunuz doğrulanacaktır.',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(height: 16),
            
            // Hat Seçimi Dropdown
            DropdownButtonFormField<String>(
              value: _selectedLineForCheckIn,
              decoration: InputDecoration(
                labelText: 'Hat Seçin',
                prefixIcon: const Icon(Icons.subway_rounded, color: Colors.teal),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: lines.map((line) {
                return DropdownMenuItem<String>(
                  value: line,
                  child: Text(line, style: const TextStyle(fontWeight: FontWeight.w600)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedLineForCheckIn = val;
                    final newStations = system.stations[val] ?? [];
                    _selectedStationForCheckIn = newStations.isNotEmpty ? newStations.first : null;
                  });
                }
              },
            ),
            const SizedBox(height: 12),

            // İstasyon Seçimi Dropdown
            DropdownButtonFormField<String>(
              value: _selectedStationForCheckIn,
              decoration: InputDecoration(
                labelText: 'İstasyon Seçin',
                prefixIcon: const Icon(Icons.place_rounded, color: Colors.teal),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: stationsForLine.map((station) {
                return DropdownMenuItem<String>(
                  value: station,
                  child: Text(station, style: const TextStyle(fontWeight: FontWeight.w600)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedStationForCheckIn = val;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Giriş Yap Butonu
            ElevatedButton.icon(
              onPressed: (_isCheckingIn || _selectedStationForCheckIn == null)
                  ? null
                  : () async {
                      setState(() {
                        _isCheckingIn = true;
                      });

                      final result = await tracking.checkInStation(
                        stationName: _selectedStationForCheckIn!,
                        systemProvider: system,
                        lineName: _selectedLineForCheckIn,
                      );

                      if (mounted) {
                        setState(() {
                          _isCheckingIn = false;
                        });

                        if (result['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result['message'] ?? 'Giriş yapıldı.'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        } else {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                                  SizedBox(width: 8),
                                  Text('Konum Doğrulanamadı', style: TextStyle(fontSize: 16)),
                                ],
                              ),
                              content: Text(result['message'] ?? 'İstasyona yeterince yakın değilsiniz.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('TAMAM'),
                                ),
                              ],
                            ),
                          );
                        }
                      }
                    },
              icon: _isCheckingIn
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.login_rounded),
              label: Text(
                _isCheckingIn ? 'Konum Doğrulanıyor...' : '📍 İSTASYONA GİRİŞ YAP (KONUM DOĞRULA)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitsList(FieldTrackingService tracking, bool isDark) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Bugünkü Ziyaretler', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            if (tracking.visits.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Henüz bir istasyon ziyareti kaydedilmedi.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tracking.visits.length,
                itemBuilder: (context, index) {
                  final visit = tracking.visits[index];
                  final entryTime = (visit['entryTime'] as Timestamp).toDate();
                  final exitTime = (visit['exitTime'] as Timestamp).toDate();
                  final duration = visit['duration'] as int;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black12 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('📍 ${visit['stationName']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(
                              '${DateFormat('HH:mm').format(entryTime)} - ${DateFormat('HH:mm').format(exitTime)}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                          child: Text('$duration dk', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(FieldTrackingService tracking) {
    if (tracking.isTracking) {
      return ElevatedButton.icon(
        onPressed: _handleStopTracking,
        icon: const Icon(Icons.location_off),
        label: const Text('SAHADAN AYRILDIM (TAKİBİ BİTİR)'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      );
    } else {
      final isOff = _isOffDay(_todayShiftCode);

      return ElevatedButton.icon(
        onPressed: isOff ? null : _handleStartTracking,
        icon: const Icon(Icons.my_location),
        label: const Text('SAHADAYIM (TAKİBİ BAŞLAT)'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isOff ? Colors.grey : Colors.green.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      );
    }
  }

  // ===================================================================
  // SEKME 3: GEÇMİŞ TAKİP VE OTURUM GEÇMİŞİ LİSTELEME
  // ===================================================================
  Widget _buildHistoryTab(bool isDark) {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      return const Center(child: Text('Kullanıcı bilgisi bulunamadı.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('field_sessions')
          .where('userId', isEqualTo: user.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        final sessions = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();

        // 1. Akıllı Tarih Filtreleme
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final startOfThisWeek = todayStart.subtract(Duration(days: todayStart.weekday - 1));
        final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
        final startOfThisMonth = DateTime(now.year, now.month, 1);

        var filteredSessions = sessions;

        if (_historyDateFilter == 'this_week') {
          filteredSessions = filteredSessions.where((s) {
            final DateTime? start = (s['startTime'] as Timestamp?)?.toDate() ?? (s['date'] as Timestamp?)?.toDate();
            return start != null && start.isAfter(startOfThisWeek.subtract(const Duration(seconds: 1)));
          }).toList();
        } else if (_historyDateFilter == 'last_week') {
          filteredSessions = filteredSessions.where((s) {
            final DateTime? start = (s['startTime'] as Timestamp?)?.toDate() ?? (s['date'] as Timestamp?)?.toDate();
            return start != null && 
                start.isAfter(startOfLastWeek.subtract(const Duration(seconds: 1))) &&
                start.isBefore(startOfThisWeek);
          }).toList();
        } else if (_historyDateFilter == 'this_month') {
          filteredSessions = filteredSessions.where((s) {
            final DateTime? start = (s['startTime'] as Timestamp?)?.toDate() ?? (s['date'] as Timestamp?)?.toDate();
            return start != null && start.isAfter(startOfThisMonth.subtract(const Duration(seconds: 1)));
          }).toList();
        }

        // 2. Hafta Hafta Gruplama (Pazartesi günü baz alınarak)
        final Map<DateTime, List<Map<String, dynamic>>> grouped = {};
        for (var s in filteredSessions) {
          final DateTime start = (s['startTime'] as Timestamp?)?.toDate() ?? 
              (s['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
          final monday = DateTime(start.year, start.month, start.day).subtract(Duration(days: start.weekday - 1));
          if (!grouped.containsKey(monday)) {
            grouped[monday] = [];
          }
          grouped[monday]!.add(s);
        }

        // Haftaları yeniden eskiye sırala
        final sortedWeeks = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        // Alt taraftaki oturum listelerini de kendi içinde tarihe göre yeniden eskiye sırala
        for (final key in grouped.keys) {
          grouped[key]!.sort((a, b) {
            final DateTime dateA = (a['startTime'] as Timestamp?)?.toDate() ?? 
                (a['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
            final DateTime dateB = (b['startTime'] as Timestamp?)?.toDate() ?? 
                (b['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
            return dateB.compareTo(dateA);
          });
        }

        String getWeekTitle(DateTime monday) {
          final sunday = monday.add(const Duration(days: 6));
          final String formatStr = 'd MMMM';
          final String mondayStr = DateFormat(formatStr, 'tr').format(monday);
          final String sundayStr = DateFormat(formatStr, 'tr').format(sunday);
          final int weekNum = _getWeekOfYear(monday);

          if (monday.isAtSameMomentAs(startOfThisWeek)) {
            return 'Bu Hafta / $weekNum. Hafta ($mondayStr - $sundayStr)';
          } else if (monday.isAtSameMomentAs(startOfLastWeek)) {
            return 'Geçen Hafta / $weekNum. Hafta ($mondayStr - $sundayStr)';
          } else {
            return '$weekNum. Hafta ($mondayStr - $sundayStr)';
          }
        }

        return Column(
          children: [
            // Filtre Alanı
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _historyDateFilter,
                          isExpanded: true,
                          icon: const Icon(Icons.filter_list, size: 20),
                          dropdownColor: isDark ? Colors.grey.shade900 : Colors.white,
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Tüm Oturumlar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'this_week', child: Text('Bu Hafta', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'last_week', child: Text('Geçen Hafta', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'this_month', child: Text('Bu Ay', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _historyDateFilter = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Hafta Hafta Oturum Listesi
            Expanded(
              child: filteredSessions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 64,
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Geçmiş Saha Oturumu Bulunmadı',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Seçilen filtreye uygun saha takip oturumu bulunmamaktadır.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: sortedWeeks.length,
                      itemBuilder: (context, weekIdx) {
                        final monday = sortedWeeks[weekIdx];
                        final weekSessions = grouped[monday] ?? [];
                        final weekTitle = getWeekTitle(monday);

                        // Group week's sessions by date string (yyyy-MM-dd)
                        final Map<String, List<Map<String, dynamic>>> dayGroups = {};
                        for (var s in weekSessions) {
                          final DateTime? start = (s['startTime'] as Timestamp?)?.toDate() ?? (s['date'] as Timestamp?)?.toDate();
                          final dateKey = start != null 
                              ? DateFormat('yyyy-MM-dd').format(start) 
                              : 'unknown';
                          if (!dayGroups.containsKey(dateKey)) {
                            dayGroups[dateKey] = [];
                          }
                          dayGroups[dateKey]!.add(s);
                        }

                        // Sort the day keys in descending order
                        final sortedDays = dayGroups.keys.toList()..sort((a, b) => b.compareTo(a));

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hafta Başlığı
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.date_range_rounded, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    weekTitle,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${weekSessions.length}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // O Haftaya Ait Günler ve Oturumlar
                            ...sortedDays.map((dayKey) {
                              final daySessions = dayGroups[dayKey] ?? [];
                              if (daySessions.isEmpty) return const SizedBox.shrink();

                              // Calculate total duration for this day
                              final totalDurationForDay = daySessions.fold<int>(
                                0, 
                                (sum, s) => sum + ((s['totalDuration'] as num?)?.toInt() ?? 0)
                              );
                              final totalDurationStr = totalDurationForDay > 60 
                                  ? '${totalDurationForDay ~/ 60}sa ${totalDurationForDay % 60}dk' 
                                  : '${totalDurationForDay}dk';

                              // Find date string from first session
                              final firstSession = daySessions.first;
                              final DateTime? start = (firstSession['startTime'] as Timestamp?)?.toDate() ?? (firstSession['date'] as Timestamp?)?.toDate();
                              final dateStr = start != null 
                                  ? DateFormat('d MMMM yyyy, EEEE', 'tr').format(start)
                                  : '—';

                              final hasActiveSession = daySessions.any((s) => s['status'] == 'active');

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ExpansionTile(
                                  leading: CircleAvatar(
                                    backgroundColor: hasActiveSession 
                                        ? Colors.orange.withOpacity(0.15) 
                                        : Colors.green.withOpacity(0.15),
                                    child: Icon(
                                      hasActiveSession ? Icons.play_arrow_rounded : Icons.check_circle_rounded,
                                      color: hasActiveSession ? Colors.orange : Colors.green,
                                    ),
                                  ),
                                  title: Text(
                                    dateStr,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    'Toplam Süre: $totalDurationStr  •  ${daySessions.length} Oturum',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  children: [
                                    const Divider(height: 1),
                                    ...daySessions.map((s) {
                                      final DateTime? sStart = (s['startTime'] as Timestamp?)?.toDate();
                                      final DateTime? sEnd = (s['endTime'] as Timestamp?)?.toDate();
                                      final startStr = sStart != null 
                                          ? DateFormat('HH:mm').format(sStart)
                                          : '—';
                                      final endStr = sEnd != null 
                                          ? DateFormat('HH:mm').format(sEnd)
                                          : (s['status'] == 'active' ? 'Aktif' : '—');
                                          
                                      final durationMin = s['totalDuration'] ?? 0;
                                      final durationStr = durationMin > 60 
                                          ? '${durationMin ~/ 60}sa ${durationMin % 60}dk' 
                                          : '${durationMin}dk';

                                      final List visits = s['visits'] ?? [];
                                      final status = s['status'] ?? 'completed';

                                      return Container(
                                        padding: const EdgeInsets.all(16.0),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(color: Colors.grey.withOpacity(0.12)),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  status == 'active' ? Icons.play_arrow_rounded : Icons.check_circle_rounded,
                                                  color: status == 'active' ? Colors.orange : Colors.green,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Oturum: $startStr - $endStr',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  'Süre: $durationStr',
                                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text('Vardiya Kodu:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                                                Text(s['shiftCode'] ?? '—', style: const TextStyle(fontSize: 12)),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Ziyaret Edilen İstasyonlar:',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                                            ),
                                            const SizedBox(height: 6),
                                            if (visits.isEmpty)
                                              const Text(
                                                'Saha Dışı / Yolda (İstasyon ziyareti yapılmadı)',
                                                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                                              )
                                            else
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: visits.map<Widget>((v) {
                                                  final String name = v['stationName'] ?? 'Bilinmeyen İstasyon';
                                                  final int duration = v['duration'] ?? 1;
                                                  final String durStr = duration > 60 
                                                      ? '${duration ~/ 60}sa ${duration % 60}dk' 
                                                      : '${duration}dk';
                                                  return Chip(
                                                    avatar: const Icon(Icons.location_on, size: 12, color: Colors.blue),
                                                    label: Text('$name ($durStr)'),
                                                    labelStyle: const TextStyle(fontSize: 10),
                                                    padding: EdgeInsets.zero,
                                                    visualDensity: VisualDensity.compact,
                                                  );
                                                }).toList(),
                                              ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  int _getWeekOfYear(DateTime date) {
    // Perşembe gününü bul (ISO 8601 standardına göre hafta perşembe gününe göre belirlenir)
    final thursday = date.add(Duration(days: 3 - (date.weekday - 1)));
    // Yılın ilk gününü bul
    final firstDayOfYear = DateTime(thursday.year, 1, 1);
    // Yılın ilk perşembesini bul
    final thursFirstWeek = firstDayOfYear.add(Duration(days: 3 - (firstDayOfYear.weekday - 1)));
    // Gün farkını bul ve 7'ye bölüp 1 ekle
    final diff = thursday.difference(thursFirstWeek).inDays;
    return (diff / 7).round() + 1;
  }
}
