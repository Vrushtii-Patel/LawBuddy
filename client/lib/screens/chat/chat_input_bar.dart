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
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChange);
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText && mounted) {
      setState(() => _hasText = hasText);
    }
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _isFocused = widget.focusNode.hasFocus);
    }
  }

  @override
  void didUpdateWidget(ChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
      _hasText = widget.controller.text.trim().isNotEmpty;
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
      _isFocused = widget.focusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool canSend = !widget.isLoading && _hasText;

    final dockBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final dockBorder = _isFocused
        ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary)
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: widget.isMobile ? 16 : 32, vertical: 12),
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
              color: (isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                  .withValues(alpha: _isFocused ? 0.15 : 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.balance_rounded,
              color: _isFocused
                  ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                  : (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              style: GoogleFonts.plusJakartaSans(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                fontSize: 14,
              ),
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: ref
                    .watch(localeProvider.notifier)
                    .translate('chat.inputHint'),
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                  fontSize: 13.5,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                filled: false,
              ),
              onSubmitted: (_) {
                if (canSend) widget.onSend();
              },
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            enabled: canSend,
            label: widget.isLoading
                ? ref
                    .watch(localeProvider.notifier)
                    .translate('a11y.chatSending')
                : ref
                    .watch(localeProvider.notifier)
                    .translate('a11y.chatSendMessage'),
            child: MouseRegion(
              cursor: canSend
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: GestureDetector(
                onTap: canSend ? widget.onSend : null,
                child: AnimatedOpacity(
                  opacity: canSend || widget.isLoading ? 1.0 : 0.35,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: widget.isLoading
                        ? Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark
                                    ? AppColors.softGraphite
                                    : AppColors.warmLinen,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.arrow_upward_rounded,
                            color: isDark
                                ? AppColors.softGraphite
                                : AppColors.warmLinen,
                            size: 22,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
