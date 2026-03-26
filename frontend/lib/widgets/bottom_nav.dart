import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Bottom Navigation Bar — 4 tabs: Home, Search, Bookmark, Profile.
/// Active state dengan highlight hijau.
class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(iconPath: 'assets/icons/house.png', label: 'Home'),
      _NavItem(iconPath: 'assets/icons/search.png', label: 'Search'),
      _NavItem(iconPath: 'assets/icons/bookmark.png', label: 'Bookmark'),
      _NavItem(iconPath: 'assets/icons/profile.png', label: 'Profile'),
    ];

    return Container(
      height: 90,
      padding: const EdgeInsets.only(bottom: 8), // Replikasi pb-2
      decoration: BoxDecoration(
        color: AppColors.background, // Tidak transparan (solid)
        border: const Border(
          top: BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04), // Replikasi shadow
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isActive = currentIndex == index;
          return _buildNavButton(item, isActive, () => onTap(index));
        }),
      ),
    );
  }

  Widget _buildNavButton(_NavItem item, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.05) // bg-[#529F60]/5
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Opacity(
                opacity: isActive ? 1.0 : 0.6, // opacity-60 alih-alih 100
                child: Center(
                  child: Image.asset(
                    item.iconPath,
                    width: 26, // Ukuran ikon dikurangi dari 34 ke 26
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
                color: isActive ? AppColors.primary : AppColors.textMuted,
                letterSpacing: 0.3,
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 3, // w-[3px]
                height: 3, // h-[3px]
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String iconPath;
  final String label;

  _NavItem({required this.iconPath, required this.label});
}
