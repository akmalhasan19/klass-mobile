import 'package:flutter/material.dart';
import 'package:klass_app/l10n/generated/app_localizations.dart';
import '../config/app_colors.dart';

/// Widget input prompt dengan tombol submit yang selalu di tengah vertikal.
/// TextField multiline yang auto-expand, submit button selalu centered.
class PromptInputWidget extends StatefulWidget {
  final Function(String)? onSubmit;
  final String? initialValue;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final bool isSubmitting;

  const PromptInputWidget({
    super.key,
    this.onSubmit,
    this.initialValue,
    this.controller,
    this.focusNode,
    this.hintText,
    this.isSubmitting = false,
  });

  @override
  State<PromptInputWidget> createState() => _PromptInputWidgetState();
}

class _PromptInputWidgetState extends State<PromptInputWidget> {
  late final TextEditingController _controller;
  bool _isLocalController = false;

  void _handleTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController(text: widget.initialValue);
      _isLocalController = true;
    }

    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);

    if (_isLocalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

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
              focusNode: widget.focusNode,
              readOnly: widget.isSubmitting,
              maxLines: 6,
              minLines: 1,
              onSubmitted: (_) => _handleSubmit(),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText ?? localizations?.promptInputHint ?? 'Type a topic you want to learn...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
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
    final canSubmit = !widget.isSubmitting && _controller.text.trim().isNotEmpty;

    return GestureDetector(
      onTap: canSubmit ? _handleSubmit : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: canSubmit ? AppColors.primary : AppColors.border,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: (canSubmit ? AppColors.primary : AppColors.border).withValues(alpha: 0.24),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: widget.isSubmitting
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(
                Icons.arrow_forward_rounded,
                color: canSubmit ? Colors.white : AppColors.textMuted,
                size: 22,
              ),
      ),
    );
  }

  void _handleSubmit() {
    final text = _controller.text.trim();

    if (text.isEmpty || widget.isSubmitting) {
      return;
    }

    widget.onSubmit?.call(text);
  }
}
