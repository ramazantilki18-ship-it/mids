import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'widgets/metro_brand_header.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF003366), // Metro Istanbul Navy Blue
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.white),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: MetroBrandHeader(
                logoWidth: 156,
                titleFontSize: 12.5,
                titleColor: Color(0xFF001E61),
              ),
            ),
          ),
          const Offstage(
            offstage: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.assignment,
                  color: Colors.white,
                  size: 48,
                ),
                SizedBox(height: 8),
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
          ),
          _buildDrawerItem(
            context,
            icon: Icons.dashboard,
            title: 'Ana Sayfa',
            route: '/',
          ),
          _buildDrawerItem(
            context,
            icon: Icons.assignment,
            title: 'Denetimler',
            route: '/audits',
          ),
          _buildDrawerItem(
            context,
            icon: Icons.add_circle,
            title: 'Yeni Denetim',
            route: '/audit/new',
          ),
          _buildDrawerItem(
            context,
            icon: Icons.bar_chart,
            title: 'Raporlar',
            route: '/reports',
          ),
          _buildDrawerItem(
            context,
            icon: Icons.settings,
            title: 'Ayarlar',
            route: '/settings',
          ),
          const Divider(color: Colors.white30),
          _buildDrawerItem(
            context,
            icon: Icons.info,
            title: 'Hakkında',
            route: '/about',
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }
}
