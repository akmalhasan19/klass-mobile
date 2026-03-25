import 'package:flutter/material.dart';

/// Widget list horizontal yang "bleed" menembus padding layar.
/// Title/header tetap sejajar dengan padding general (horizontal: 24),
/// tapi ListView-nya full-bleed ke pinggiran layar.
class BleedingHorizontalList extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final double height;
  final double itemSpacing;
  final EdgeInsets? titlePadding;

  const BleedingHorizontalList({
    super.key,
    required this.title,
    required this.children,
    this.height = 200,
    this.itemSpacing = 20,
    this.titlePadding,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title tetap di dalam padding general
        Padding(
          padding: titlePadding ?? const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: Color(0xFFE8ECF4),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // ListView full-bleed tanpa padding container (menembus pinggiran)
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            // Padding hanya di awal dan akhir, tidak di parent
            padding: const EdgeInsets.only(left: 24, right: 24),
            itemCount: children.length,
            separatorBuilder: (_, _) => SizedBox(width: itemSpacing),
            itemBuilder: (_, index) => children[index],
          ),
        ),
      ],
    );
  }
}
