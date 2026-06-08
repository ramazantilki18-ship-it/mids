import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 20),
              title: LayoutBuilder(
                builder: (context, constraints) {
                  // AppBar küçüldüğünde font boyutunu ayarla
                  final isCollapsed = constraints.maxHeight < 80;
                  final fontSize = isCollapsed ? 16.0 : 24.0;
                  
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YÖNETİM',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: fontSize,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!isCollapsed)
                        Text(
                          'PANELİ',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: fontSize,
                            color: Colors.white.withValues(alpha: 0.9),
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  );
                },
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark 
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [AppColors.primary, const Color(0xFF1E3A8A)],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Menü Kartları
                _buildModernMenuCard(
                  context,
                  'Personel Yönetimi',
                  'Kullanıcı ekle, çıkar ve yetki belirle',
                  Icons.people_alt_rounded,
                  Theme.of(context).primaryColor,
                  () => context.push('/user-management'),
                ),
                const SizedBox(height: 14),
                _buildModernMenuCard(
                  context,
                  'Soru Bankası Yönetimi',
                  'Denetim sorularını düzenle, ekle veya çıkar',
                  Icons.quiz_rounded,
                  Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFB923C) : AppColors.accentOrange,
                  () => context.push('/question-management'),
                ),
                const SizedBox(height: 14),
                _buildModernMenuCard(
                  context,
                  'Hat ve İstasyon Yönetimi',
                  'Hat ve istasyon ekle, çıkar ve düzenle',
                  Icons.train_rounded,
                  Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4ADE80) : AppColors.accentGreen,
                  () => context.push('/line-management'),
                ),
                const SizedBox(height: 14),
                const SizedBox(height: 14),
                _buildModernMenuCard(
                  context,
                  'Görev Atama ve Planlama',
                  'Denetim görevlerini personele veya unvanlara ata',
                  Icons.assignment_ind_rounded,
                  Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF87171) : const Color(0xFFD32F2F),
                  () => context.push('/task-planning'),
                ),
                const SizedBox(height: 14),
                _buildModernMenuCard(
                  context,
                  'Geri Bildirim Takip',
                  'Kullanıcıların bildirdiği hata ve önerileri incele',
                  Icons.feedback_rounded,
                  Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF1E3A8A),
                  () => context.push('/feedback-management'),
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernMenuCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // İkon
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 14),
                
                // Yazılar
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Ok İkonu
                Icon(
                  Icons.chevron_right_rounded,
                  color: color.withValues(alpha: 0.4),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
