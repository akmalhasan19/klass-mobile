import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Bottom Navigation Bar — role-aware navigation.
/// Teacher: Home, Search, Workspace, Profile
/// Freelancer: Home, Jobs, Portfolio, Profile
class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String role;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.role = 'teacher',
  });

  @override
  Widget build(BuildContext context) {
    final items = _getNavItems();

    return Container(
      height: 90,
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(
            color: AppColors.borderLight,
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / items.length;

          return Stack(
            children: [
              // Sliding Indicator Background
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutQuart,
                left: (currentIndex * itemWidth) + (itemWidth - 38) / 2,
                top: 11,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              // Navigation Buttons
              Row(
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isActive = currentIndex == index;
                  return Expanded(
                    child: _buildNavButton(item, isActive, () => onTap(index)),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_NavItem> _getNavItems() {
    if (role == 'freelancer') {
      return [
        _NavItem(icon: Icons.dashboard_rounded, label: 'Home'),
        _NavItem(icon: Icons.work_rounded, label: 'Jobs'),
        _NavItem(icon: Icons.cases_rounded, label: 'Portfolio'),
        _NavItem(icon: Icons.person_rounded, label: 'Profile'),
      ];
    }
    // Teacher uses icon images from assets
    return [
      _NavItem(iconPath: 'assets/icons/house.png', label: 'Home'),
      _NavItem(iconPath: 'assets/icons/search.png', label: 'Search'),
      _NavItem(iconPath: 'assets/icons/workspaces.png', label: 'Workspace'),
      _NavItem(iconPath: 'assets/icons/profile.png', label: 'Profile'),
    ];
  }

  Widget _buildNavButton(_NavItem item, bool isActive, VoidCallback onTap) {
    final activeColor = AppColors.primary;
    final inactiveColor = AppColors.textMuted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Opacity(
              opacity: isActive ? 1.0 : 0.6,
              child: Center(
                child: item.icon != null
                    ? Icon(
                        item.icon,
                        size: 26,
                        color: isActive ? activeColor : inactiveColor,
                      )
                    : Image.asset(
                        item.iconPath!,
                        width: 26,
                        height: 26,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 0),
          Text(
            item.label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? activeColor : inactiveColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String? iconPath;
  final IconData? icon;
  final String label;

  _NavItem({this.iconPath, this.icon, required this.label});
}
