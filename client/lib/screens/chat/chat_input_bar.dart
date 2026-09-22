import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';

class ChatInput extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSend;
  final bool isMobile;

  const ChatInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSend,
    required this.isMobile,
  });

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _isFocused = widget.focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dockBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final dockBorder = _isFocused
        ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary)
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: widget.isMobile ? 16 : 32, vertical: 12),
      decoration: BoxDecoration(
        color: dockBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dockBorder,
          width: _isFocused ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: _isFocused ? 0.15 : 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.balance_rounded,
              color: _isFocused ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary) : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              style: GoogleFonts.inter(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                fontSize: 14,
              ),
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: ref.watch(localeProvider.notifier).translate('chat.inputHint'),
                hintStyle: GoogleFonts.inter(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontSize: 13.5,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                filled: false,
              ),
              onSubmitted: (_) {
                if (!widget.isLoading) widget.onSend();
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.isLoading ? null : widget.onSend,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: widget.isLoading
                  ? Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? AppColors.darkBackground : Colors.white),
                      ),
                    )
                  : Icon(
                      Icons.arrow_upward_rounded,
                      color: isDark ? AppColors.darkBackground : Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
