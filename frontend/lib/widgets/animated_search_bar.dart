import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class AnimatedSearchBar extends StatefulWidget {
  final Function(String)? onChanged;
  final VoidCallback? onExpanded;
  final VoidCallback? onCollapsed;
  final String hintText;

  const AnimatedSearchBar({
    super.key,
    this.onChanged,
    this.onExpanded,
    this.onCollapsed,
    this.hintText = 'Search for teachers, topics...',
  });

  @override
  State<AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<AnimatedSearchBar>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  void _toggleSearch() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _focusNode.requestFocus();
        widget.onExpanded?.call();
      } else {
        _focusNode.unfocus();
        _controller.clear();
        widget.onCollapsed?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      width: _isExpanded ? MediaQuery.of(context).size.width - 48 : 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _isExpanded ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border,
          width: _isExpanded ? 1.5 : 1,
        ),
        boxShadow: _isExpanded
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Magifier Icon (Always visible or moves)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: GestureDetector(
              onTap: _toggleSearch,
              child: Icon(
                Icons.search_rounded,
                size: 20,
                color: _isExpanded ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
          
          // TextField
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isExpanded ? 1.0 : 0.0,
            child: Padding(
              padding: const EdgeInsets.only(left: 40, right: 36),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: widget.onChanged,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // Close button
          if (_isExpanded)
            Positioned(
              right: 2,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppColors.textMuted,
                onPressed: _toggleSearch,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
        ],
      ),
    );
  }
}
