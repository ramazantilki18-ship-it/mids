import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/auth_provider.dart';

class BottomNavShell extends StatelessWidget {
  final String location;
  final Widget child;

  const BottomNavShell({super.key, required this.child, required this.location});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    final showPanel = auth.hasMobileAccess('panel');
    final showDenetim = auth.hasMobileAccess('denetim');
    final showTakip = auth.hasMobileAccess('takip');
    final showPersonalRoster = auth.hasMobileAccess('puantaj') && auth.hasMobileAccess('denetim');
    final showReports = auth.hasMobileAccess('analiz');
    final showSahaTakip = auth.hasMobileAccess('sahaTakip');

    // Self-healing redirection: if they land on a page they shouldn't see
    if (user != null) {
      bool isAllowed = true;
      if (location == '/' && !showPanel) isAllowed = false;
      if (location.startsWith('/my-audits') && !showDenetim) isAllowed = false;
      if (location.startsWith('/nonconformities') && !showTakip) isAllowed = false;
      if (location.startsWith('/personal-roster') && !showPersonalRoster) isAllowed = false;
      if (location.startsWith('/reports') && !showReports) isAllowed = false;
      if (location.startsWith('/field-tracking') && !showSahaTakip) isAllowed = false;

      if (!isAllowed) {
        // Find the first allowed tab to redirect to
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (showPanel) {
            context.go('/');
          } else if (showDenetim) {
            context.go('/my-audits');
          } else if (showTakip) {
            context.go('/nonconformities');
          } else if (showPersonalRoster) {
            context.go('/personal-roster');
          } else if (showReports) {
            context.go('/reports');
          } else if (showSahaTakip) {
            context.go('/field-tracking');
          }
        });
      }
    }

    return Scaffold(
      extendBody: false, // Prevents scrollable lists and cards from being covered behind the navigation bar
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(8, 0, 8, 10),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : AppColors.primary,
            borderRadius: BorderRadius.circular(20),
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
            borderRadius: BorderRadius.circular(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (showPanel)
                  _buildNavItem(context, '/', Icons.space_dashboard_rounded, Icons.space_dashboard_outlined, 'Panel'),
                if (showDenetim)
                  _buildNavItem(context, '/my-audits', Icons.assignment_turned_in_rounded, Icons.assignment_turned_in_outlined, 'Denetim'),
                if (showTakip)
                  _buildNavItem(context, '/nonconformities', Icons.gpp_maybe_rounded, Icons.gpp_maybe_outlined, 'Takip'),
                if (showPersonalRoster)
                  _buildNavItem(context, '/personal-roster', Icons.calendar_month_rounded, Icons.calendar_month_outlined, 'Puantaj'),
                if (showSahaTakip)
                  _buildNavItem(context, '/field-tracking', Icons.route_rounded, Icons.route_outlined, 'Saha Takip'),
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
              size: 22,
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: isSelected ? activeColor : inactiveColor,
                  fontSize: 10.0,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
