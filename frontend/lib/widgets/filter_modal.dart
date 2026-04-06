import 'package:flutter/material.dart';
import 'package:klass_app/l10n/generated/app_localizations.dart';
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
  final Set<String> _selectedSubjects = {'science', 'literature'};
  final Set<String> _selectedResourceTypes = {'worksheets'};
  String _selectedDate = 'anytime';

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

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
                  _buildSectionHeader(localizations.galleryFilterSubject),
                  const SizedBox(height: 16),
                  _buildSubjectChips(),
                  const SizedBox(height: 32),
                  _buildSectionHeader(localizations.galleryFilterResourceType),
                  const SizedBox(height: 16),
                  _buildResourceTypeChips(),
                  const SizedBox(height: 32),
                  _buildSectionHeader(localizations.galleryFilterDateAdded),
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
    final localizations = AppLocalizations.of(context)!;

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
          Expanded(
            child: Text(
              localizations.galleryFilterTitle,
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
                _selectedDate = 'anytime';
              });
            },
            child: Text(
              localizations.galleryFilterClearAll,
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
    final localizations = AppLocalizations.of(context)!;

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
            hintText: localizations.galleryFilterSearchHint,
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
    final subjects = ['math', 'science', 'history', 'literature', 'art', 'geography'];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: subjects.map((s) => _buildFilterChip(
        label: _subjectLabel(s),
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
      {'key': 'pdfs', 'icon': Icons.picture_as_pdf_rounded},
      {'key': 'images', 'icon': Icons.image_rounded},
      {'key': 'worksheets', 'icon': Icons.description_rounded},
      {'key': 'videos', 'icon': Icons.smart_display_rounded},
      {'key': 'links', 'icon': Icons.link_rounded},
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: types.map((t) => _buildFilterChip(
        label: _resourceTypeLabel(t['key'] as String),
        icon: t['icon'] as IconData,
        isSelected: _selectedResourceTypes.contains(t['key']),
        onTap: () {
          setState(() {
            if (_selectedResourceTypes.contains(t['key'])) {
              _selectedResourceTypes.remove(t['key']);
            } else {
              _selectedResourceTypes.add(t['key'] as String);
            }
          });
        },
      )).toList(),
    );
  }

  Widget _buildDateChips() {
    final dates = ['anytime', 'past_week', 'past_month', 'past_year'];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: dates.map((d) => _buildFilterChip(
        label: _dateLabel(d),
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
    final localizations = AppLocalizations.of(context)!;

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
          child: Text(
            localizations.galleryFilterShowResults(42),
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

  String _subjectLabel(String key) {
    final localizations = AppLocalizations.of(context)!;

    switch (key) {
      case 'math':
        return localizations.galleryFilterSubjectMath;
      case 'science':
        return localizations.galleryFilterSubjectScience;
      case 'history':
        return localizations.galleryFilterSubjectHistory;
      case 'literature':
        return localizations.galleryFilterSubjectLiterature;
      case 'art':
        return localizations.galleryFilterSubjectArt;
      case 'geography':
        return localizations.galleryFilterSubjectGeography;
      default:
        return key;
    }
  }

  String _resourceTypeLabel(String key) {
    final localizations = AppLocalizations.of(context)!;

    switch (key) {
      case 'pdfs':
        return localizations.galleryFilterTypePdfs;
      case 'images':
        return localizations.galleryFilterTypeImages;
      case 'worksheets':
        return localizations.galleryFilterTypeWorksheets;
      case 'videos':
        return localizations.galleryFilterTypeVideos;
      case 'links':
        return localizations.galleryFilterTypeLinks;
      default:
        return key;
    }
  }

  String _dateLabel(String key) {
    final localizations = AppLocalizations.of(context)!;

    switch (key) {
      case 'past_week':
        return localizations.galleryFilterDatePastWeek;
      case 'past_month':
        return localizations.galleryFilterDatePastMonth;
      case 'past_year':
        return localizations.galleryFilterDatePastYear;
      case 'anytime':
      default:
        return localizations.galleryFilterDateAnytime;
    }
  }
}
