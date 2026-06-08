import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'metro_brand_header.dart';

class DrawerMenu extends StatelessWidget {
  const DrawerMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.primary,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(),
          _buildMenuItem(
            icon: Icons.dashboard,
            title: 'Ana Sayfa',
            onTap: () => Navigator.popAndPushNamed(context, '/'),
          ),
          _buildMenuItem(
            icon: Icons.assignment,
            title: 'Denetimler',
            onTap: () => Navigator.popAndPushNamed(context, '/audits'),
          ),
          _buildMenuItem(
            icon: Icons.add_circle,
            title: 'Yeni Denetim',
            onTap: () => Navigator.popAndPushNamed(context, '/audit/new'),
          ),
          _buildMenuItem(
            icon: Icons.bar_chart,
            title: 'Raporlar',
            onTap: () => Navigator.popAndPushNamed(context, '/reports'),
          ),
          _buildMenuItem(
            icon: Icons.settings,
            title: 'Ayarlar',
            onTap: () => Navigator.popAndPushNamed(context, '/settings'),
          ),
          const Divider(color: Colors.white30),
          _buildMenuItem(
            icon: Icons.info,
            title: 'Hakkında',
            onTap: () => Navigator.popAndPushNamed(context, '/about'),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: const Align(
        alignment: Alignment.bottomCenter,
        child: MetroBrandHeader(
          logoWidth: 156,
          titleFontSize: 12.5,
          titleColor: Color(0xFF001E61),
        ),
      ),
    );
  }

  Widget _buildLegacyDrawerHeader() {
    return Container(
      color: AppColors.accentRed,
      padding: const EdgeInsets.all(24),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.assignment,
            color: Colors.white,
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            'Metro İstanbul Denetim',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Metro İstanbul',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
    );
  }
}
