import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Widget input prompt dengan tombol submit yang selalu di tengah vertikal.
/// TextField multiline yang auto-expand, submit button selalu centered.
class PromptInputWidget extends StatefulWidget {
  final Function(String)? onSubmit;
  final String? initialValue;
  final TextEditingController? controller;

  const PromptInputWidget({
    super.key,
    this.onSubmit,
    this.initialValue,
    this.controller,
  });

  @override
  State<PromptInputWidget> createState() => _PromptInputWidgetState();
}

class _PromptInputWidgetState extends State<PromptInputWidget> {
  late final TextEditingController _controller;
  bool _isLocalController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController(text: widget.initialValue);
      _isLocalController = true;
    }
  }

  @override
  void dispose() {
    if (_isLocalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.fromLTRB(20, 6, 8, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // `Row` dengan `crossAxisAlignment: center` menjamin tombol submit
      // selalu berada persis di tengah vertikal container,
      // tidak peduli berapa baris teks yang dimasukkan.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // TextField yang bisa expand multiline
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: 6,
              minLines: 1,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
              decoration: const InputDecoration(
                hintText: 'Ketik topik yang ingin dipelajari...',
                hintStyle: TextStyle(color: AppColors.textMuted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Submit Button — selalu vertically centered berkat CrossAxisAlignment.center
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: () {
        if (_controller.text.isNotEmpty) {
          widget.onSubmit?.call(_controller.text);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_forward_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
