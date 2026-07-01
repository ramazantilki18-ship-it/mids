import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';

class BottomNavShell extends StatelessWidget {
  final String location;
  final Widget child;

  const BottomNavShell({super.key, required this.child, required this.location});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().user;
    final showReports = user != null && 
        user.role != UserRole.fieldAuditor && 
        user.role != UserRole.fieldAuditorActionOwner;
    bool isSupervisorOrManager = false;
    if (user != null) {
      final title = (user.jobTitle ?? '').trim().toLowerCase();
      String clean(String s) {
        return s
            .replaceAll('ı', 'i')
            .replaceAll('ğ', 'g')
            .replaceAll('ü', 'u')
            .replaceAll('ş', 's')
            .replaceAll('ö', 'o')
            .replaceAll('ç', 'c')
            .replaceAll('â', 'a');
      }
      final cleanTitle = clean(title);
      isSupervisorOrManager = cleanTitle.contains('hat vardiya amiri') || cleanTitle.contains('istasyon sorumlusu');
    }

    final showPersonalRoster = user != null && 
        !isSupervisorOrManager && (
        user.role == UserRole.fieldAuditor || 
        user.role == UserRole.fieldAuditorActionOwner
    );

    return Scaffold(
      extendBody: false, // Prevents scrollable lists and cards from being covered behind the navigation bar
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : AppColors.primary,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.primaryLight.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(context, '/', Icons.space_dashboard_rounded, Icons.space_dashboard_outlined, 'Panel'),
                _buildNavItem(context, '/my-audits', Icons.assignment_turned_in_rounded, Icons.assignment_turned_in_outlined, 'Denetim'),
                _buildNavItem(context, '/nonconformities', Icons.gpp_maybe_rounded, Icons.gpp_maybe_outlined, 'Takip'),
                if (showPersonalRoster)
                  _buildNavItem(context, '/personal-roster', Icons.calendar_month_rounded, Icons.calendar_month_outlined, 'Puantaj'),
                if (showReports)
                  _buildNavItem(context, '/reports', Icons.analytics_rounded, Icons.analytics_outlined, 'Analiz'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, String route, IconData selectedIcon, IconData unselectedIcon, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = location == route || (route != '/' && location.startsWith(route));
    
    // Using a highly distinct vibrant orange accent on the corporate navy background
    const activeColor = Color(0xFFFF7A45); 
    final inactiveColor = isDark ? Colors.white.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.72); 

    return Expanded(
      child: InkWell(
        key: ValueKey(route),
        onTap: () => context.go(route),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon, 
              color: isSelected ? activeColor : inactiveColor, 
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
