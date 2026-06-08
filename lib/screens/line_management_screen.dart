import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../providers/system_provider.dart';

class LineManagementScreen extends StatefulWidget {
  const LineManagementScreen({super.key});

  @override
  State<LineManagementScreen> createState() => _LineManagementScreenState();
}

class _LineManagementScreenState extends State<LineManagementScreen> {
  final _lineController = TextEditingController();
  final _stationController = TextEditingController();

  Color _getLineColor(BuildContext context, String line) {
    return context.read<SystemProvider>().getLineColor(line);
  }

  Color _selectedLineColor = Colors.blue; // Varsayılan renk

  void _showAddLineDialog() {
    _lineController.clear();
    _selectedLineColor = Colors.blue; // Reset
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Yeni Hat Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _lineController, 
                decoration: InputDecoration(
                  hintText: 'Hat Adı (örn: M3)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Hat Rengi Seçin:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildColorOption(const Color(0xFFE31E24), 'M1 Kırmızı', setState),
                  _buildColorOption(const Color(0xFF009543), 'M2 Yeşil', setState),
                  _buildColorOption(const Color(0xFF009FE3), 'M3 Mavi', setState),
                  _buildColorOption(const Color(0xFFE91E63), 'M4 Pembe', setState),
                  _buildColorOption(const Color(0xFF53284F), 'M5 Mor', setState),
                  _buildColorOption(const Color(0xFFB9A15E), 'M6 Altın', setState),
                  _buildColorOption(const Color(0xFFF29100), 'M7 Turuncu', setState),
                  _buildColorOption(const Color(0xFF003D88), 'M8 Lacivert', setState),
                  _buildColorOption(const Color(0xFFEDD500), 'M9 Sarı', setState),
                  _buildColorOption(const Color(0xFF9C27B0), 'T5 Lila', setState),
                  _buildColorOption(const Color(0xFFFF5722), 'Derin Turuncu', setState),
                  _buildColorOption(const Color(0xFF795548), 'Kahverengi', setState),
                  _buildColorOption(const Color(0xFF607D8B), 'Mavi Gri', setState),
                  _buildColorOption(const Color(0xFFE91E63), 'Açık Pembe', setState),
                  _buildColorOption(const Color(0xFF4CAF50), 'Açık Yeşil', setState),
                  _buildColorOption(const Color(0xFF2196F3), 'Açık Mavi', setState),
                  _buildColorOption(Colors.black, 'Siyah', setState),
                  _buildColorOption(Colors.white, 'Beyaz', setState),
                  _buildColorOption(const Color(0xFF00BCD4), 'Turkuaz', setState),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 40,
                decoration: BoxDecoration(
                  color: _selectedLineColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Text(
                    'Seçilen Renk',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                if (_lineController.text.isNotEmpty) {
                  final colorStr = '#${_selectedLineColor.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
                  context.read<SystemProvider>().addLine(_lineController.text, color: colorStr);
                  Navigator.pop(context);
                }
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption(Color color, String name, StateSetter setState) {
    final isSelected = _selectedLineColor == color;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLineColor = color;
        });
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected 
              ? Border.all(color: Colors.white, width: 3)
              : Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
          boxShadow: isSelected 
              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: isSelected 
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  void _showEditLineDialog(BuildContext context, String oldLine) {
    _lineController.text = oldLine;
    // Mevcut rengi al
    final system = context.read<SystemProvider>();
    final currentColor = system.getLineColor(oldLine);
    _selectedLineColor = currentColor;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Hattı Düzenle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _lineController,
                decoration: InputDecoration(
                  labelText: 'Hat Adı',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Hat Rengi Seçin:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildColorOption(const Color(0xFFE31E24), 'M1 Kırmızı', setState),
                  _buildColorOption(const Color(0xFF009543), 'M2 Yeşil', setState),
                  _buildColorOption(const Color(0xFF009FE3), 'M3 Mavi', setState),
                  _buildColorOption(const Color(0xFFE91E63), 'M4 Pembe', setState),
                  _buildColorOption(const Color(0xFF53284F), 'M5 Mor', setState),
                  _buildColorOption(const Color(0xFFB9A15E), 'M6 Altın', setState),
                  _buildColorOption(const Color(0xFFF29100), 'M7 Turuncu', setState),
                  _buildColorOption(const Color(0xFF003D88), 'M8 Lacivert', setState),
                  _buildColorOption(const Color(0xFFEDD500), 'M9 Sarı', setState),
                  _buildColorOption(const Color(0xFF9C27B0), 'T5 Lila', setState),
                  _buildColorOption(const Color(0xFFFF5722), 'Derin Turuncu', setState),
                  _buildColorOption(const Color(0xFF795548), 'Kahverengi', setState),
                  _buildColorOption(const Color(0xFF607D8B), 'Mavi Gri', setState),
                  _buildColorOption(const Color(0xFFE91E63), 'Açık Pembe', setState),
                  _buildColorOption(const Color(0xFF4CAF50), 'Açık Yeşil', setState),
                  _buildColorOption(const Color(0xFF2196F3), 'Açık Mavi', setState),
                  _buildColorOption(Colors.black, 'Siyah', setState),
                  _buildColorOption(Colors.white, 'Beyaz', setState),
                  _buildColorOption(const Color(0xFF00BCD4), 'Turkuaz', setState),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 40,
                decoration: BoxDecoration(
                  color: _selectedLineColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Text(
                    'Seçilen Renk',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                if (_lineController.text.isNotEmpty) {
                  final colorStr = '#${_selectedLineColor.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
                  // Önce rengi güncelle
                  system.updateLine(oldLine, _lineController.text);
                  // Renk bilgisini güncelle
                  system.updateLineColor(_lineController.text, colorStr);
                  Navigator.pop(context);
                }
              },
              child: const Text('Güncelle'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddStationDialog(String lineName) {
    _stationController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$lineName Hattına İstasyon Ekle'),
        content: TextField(
          controller: _stationController, 
          decoration: InputDecoration(
            hintText: 'İstasyon Adı',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              if (_stationController.text.isNotEmpty) {
                context.read<SystemProvider>().addStation(lineName, _stationController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('İstasyon Ekle'),
          ),
        ],
      ),
    );
  }

  void _showEditStationDialog(String line, String oldStation) {
    _stationController.text = oldStation;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İstasyonu Düzenle'),
        content: TextField(
          controller: _stationController,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              if (_stationController.text.isNotEmpty) {
                context.read<SystemProvider>().updateStation(line, oldStation, _stationController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String title, String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF87171) : const Color(0xFFD32F2F)),
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final system = context.watch<SystemProvider>();
    final lines = system.lines;

    return Scaffold(
      appBar: AppBar(title: const Text('Hat ve İstasyon Yönetimi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLineDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Yeni Hat'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Bottom padding for FAB
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          final stations = system.stations[line] ?? [];
          final lineColor = _getLineColor(context, line);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: lineColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: lineColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      line,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                title: Text(line, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                subtitle: Text('${stations.length} istasyon', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_rounded, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor, size: 20),
                      onPressed: () => _showEditLineDialog(context, line),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_forever_rounded, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF87171) : const Color(0xFFD32F2F), size: 20),
                      onPressed: () => _confirmDelete(
                        'Hattı Sil',
                        '$line hattını ve tüm istasyonlarını silmek istediğinize emin misiniz?',
                        () => system.removeLine(line),
                      ),
                    ),
                  ],
                ),
                children: [
                  ...stations.asMap().entries.map((entry) {
                    final station = entry.value;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: lineColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.location_on_rounded, color: Colors.grey, size: 18),
                      ),
                      title: Text(station, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit_rounded, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor, size: 18),
                            onPressed: () => _showEditStationDialog(line, station),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_forever_rounded, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF87171) : const Color(0xFFD32F2F), size: 18),
                            onPressed: () => _confirmDelete(
                              'İstasyonu Sil',
                              '$station istasyonunu silmek istediğinize emin misiniz?',
                              () => system.removeStation(line, station),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddStationDialog(line),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('İstasyon Ekle'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
