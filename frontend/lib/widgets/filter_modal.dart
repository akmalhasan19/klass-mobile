import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class FilterModal extends StatefulWidget {
  const FilterModal({super.key});

  /// Menampilkan modal filter sebagai bottom sheet yang memenuhi hampir seluruh layar.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => const FilterModal(),
    );
  }

  @override
  State<FilterModal> createState() => _FilterModalState();
}

class _FilterModalState extends State<FilterModal> {
  // State pilihan filter (mengikuti referensi)
  final Set<String> _selectedSubjects = {'Science', 'Literature'};
  final Set<String> _selectedResourceTypes = {'Worksheets'};
  String _selectedDate = 'Anytime';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          _buildTopBar(),
          _buildSearchArea(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('SUBJECT'),
                  const SizedBox(height: 16),
                  _buildSubjectChips(),
                  const SizedBox(height: 32),
                  _buildSectionHeader('RESOURCE TYPE'),
                  const SizedBox(height: 16),
                  _buildResourceTypeChips(),
                  const SizedBox(height: 32),
                  _buildSectionHeader('DATE ADDED'),
                  const SizedBox(height: 16),
                  _buildDateChips(),
                ],
              ),
            ),
          ),
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(12),
            ),
          ),
          const Expanded(
            child: Text(
              'Filter Materials',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedSubjects.clear();
                _selectedResourceTypes.clear();
                _selectedDate = 'Anytime';
              });
            },
            child: const Text(
              'Clear all',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildSearchArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search materials, tags, or topics...',
            hintStyle: TextStyle(
              fontFamily: 'Inter',
              color: AppColors.textMuted.withValues(alpha: 0.6),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.textMuted,
              size: 22,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: AppColors.textMuted,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildSubjectChips() {
    final subjects = ['Math', 'Science', 'History', 'Literature', 'Art', 'Geography'];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: subjects.map((s) => _buildFilterChip(
        label: s,
        isSelected: _selectedSubjects.contains(s),
        onTap: () {
          setState(() {
            if (_selectedSubjects.contains(s)) {
              _selectedSubjects.remove(s);
            } else {
              _selectedSubjects.add(s);
            }
          });
        },
      )).toList(),
    );
  }

  Widget _buildResourceTypeChips() {
    final types = [
      {'label': 'PDFs', 'icon': Icons.picture_as_pdf_rounded},
      {'label': 'Images', 'icon': Icons.image_rounded},
      {'label': 'Worksheets', 'icon': Icons.description_rounded},
      {'label': 'Videos', 'icon': Icons.smart_display_rounded},
      {'label': 'Links', 'icon': Icons.link_rounded},
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: types.map((t) => _buildFilterChip(
        label: t['label'] as String,
        icon: t['icon'] as IconData,
        isSelected: _selectedResourceTypes.contains(t['label']),
        onTap: () {
          setState(() {
            if (_selectedResourceTypes.contains(t['label'])) {
              _selectedResourceTypes.remove(t['label']);
            } else {
              _selectedResourceTypes.add(t['label'] as String);
            }
          });
        },
      )).toList(),
    );
  }

  Widget _buildDateChips() {
    final dates = ['Anytime', 'Past Week', 'Past Month', 'Past Year'];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: dates.map((d) => _buildFilterChip(
        label: d,
        isSelected: _selectedDate == d,
        onTap: () => setState(() => _selectedDate = d),
      )).toList(),
    );
  }

  Widget _buildFilterChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: const Text(
            'Show 42 Results',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
