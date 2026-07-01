import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/system_provider.dart';
import '../models/user_model.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import 'dart:math';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();  
  final _passwordController = TextEditingController();  // Şifre kontrolcüsü eklendi
  List<String> _tempSelectedLines = [];
  UserRole _selectedRole = UserRole.fieldAuditor;

  void _showUserDialog({UserModel? existingUser}) {
    final isEditing = existingUser != null;
    
    if (isEditing) {
      _usernameController.text = existingUser.username;
      _passwordController.text = existingUser.password ?? '';  // Mevcut şifreyi yükle
      _selectedRole = existingUser.role;
      _tempSelectedLines = List.from(existingUser.authorizedLines);
    } else {
      _usernameController.clear();
      _passwordController.clear();  // Yeni kullanıcı için şifre alanını temizle
      _selectedRole = UserRole.fieldAuditor;
      _tempSelectedLines = [];
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Personel Düzenle' : 'Yeni Personel Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _usernameController, 
                  decoration: const InputDecoration(
                    labelText: 'Kullanıcı Adı', 
                    hintText: 'Örn: ahmet.yilmaz',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: true,  // Şifreyi gizle
                  decoration: const InputDecoration(
                    labelText: 'Şifre Belirle',
                    hintText: 'Şifre giriniz',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                

                DropdownButtonFormField<UserRole>(
                  value: _selectedRole,
                  decoration: const InputDecoration(labelText: 'Sistem Yetkisi', border: OutlineInputBorder()),
                  items: UserRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.displayName))).toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      _selectedRole = val!;
                    });
                  },
                ),
                const SizedBox(height: 20),

                Text('Sorumlu Olduğu Hatlar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : AppColors.primary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: MockData.lines.map((line) {
                    final isSelected = _tempSelectedLines.contains(line);
                    return FilterChip(
                      label: Text(line, style: TextStyle(color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface, fontSize: 12)),
                      selected: isSelected,
                      selectedColor: Theme.of(context).primaryColor,
                      checkmarkColor: Colors.white,
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            _tempSelectedLines.add(line);
                          } else {
                            _tempSelectedLines.remove(line);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () {
                if (_usernameController.text.isNotEmpty) {
                  final password = _passwordController.text.isNotEmpty ? _passwordController.text : null;
                  if (isEditing) {
                    final updatedUser = UserModel(
                      id: existingUser.id,
                      username: _usernameController.text,
                      role: _selectedRole,
                      authorizedLines: List.from(_tempSelectedLines),
                      password: password ?? existingUser.password, // Şifre girildiyse güncelle, yoksa eski şifreyi koru
                    );
                    context.read<SystemProvider>().updateUser(updatedUser);
                  } else {
                    final newUser = UserModel(
                      id: 'U-${Random().nextInt(9000) + 1000}',
                      username: _usernameController.text,
                      role: _selectedRole,
                      authorizedLines: List.from(_tempSelectedLines),
                      password: password, // Yeni kullanıcı için şifre
                    );
                    context.read<SystemProvider>().addUser(newUser);
                  }
                  Navigator.pop(context);
                }
              },
              child: Text(isEditing ? 'Değişiklikleri Kaydet' : 'Personeli Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final system = context.watch<SystemProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Personel Yönetimi')),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 150), // Extended FAB için alt boşluk (artırıldı)
        itemCount: system.users.length,
        itemBuilder: (context, index) {
          final user = system.users[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                child: Text(user.name[0].toUpperCase(), style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
              ),
              title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.title, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFB923C) : AppColors.accentOrange, fontWeight: FontWeight.w600, fontSize: 12)),
                  Text('${user.name} | Sistem Yetkisi: ${user.roleDisplayName}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface)),
                  Text('Sorumlu Hatlar: ${user.authorizedLines.isEmpty ? 'Tümü' : user.authorizedLines.join(', ')}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8))),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor, size: 20),
                    onPressed: () => _showUserDialog(existingUser: user),
                  ),
                  if (user.role != UserRole.superAdmin)
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF87171) : AppColors.accentRed, size: 20),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Personeli Sil'),
                            content: Text('${user.name} isimli personeli silmek istediğinize emin misiniz?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('İptal'),
                              ),
                              TextButton(
                                onPressed: () {
                                  system.removeUser(user.id);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Personel başarıyla silindi')),
                                  );
                                },
                                child: Text('Sil', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF87171) : AppColors.accentRed)),
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
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserDialog(),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 4,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Yeni Personel Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
