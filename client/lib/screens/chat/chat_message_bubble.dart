import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';
import 'chat_citation_card.dart';
import 'chat_prompt_card.dart';

class AnimatedMessageBubble extends ConsumerStatefulWidget {
  final Map<String, dynamic> message;
  final Function(String) onSuggestionTap;
  final VoidCallback? onScrollRequest;

  const AnimatedMessageBubble({
    super.key,
    required this.message,
    required this.onSuggestionTap,
    this.onScrollRequest,
  });

  @override
  ConsumerState<AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends ConsumerState<AnimatedMessageBubble> {
  bool _copied = false;
  String _fullText = '';
  String _displayedText = '';
  bool _isRevealing = false;
  bool _showCursor = true;
  Timer? _typingTimer;
  Timer? _cursorTimer;
  List<String> _tokens = [];
  int _tokenIndex = 0;
  int _tickCount = 0;

  @override
  void initState() {
    super.initState();
    _fullText = widget.message['text'] ?? '';
    final isAI = widget.message['role'] == 'ai' ||
        (widget.message['role'] != 'user' && widget.message['role'] != 'error');
    final isNew = widget.message['isNew'] == true;

    if (isAI && isNew && _fullText.isNotEmpty) {
      _startTypingAnimation();
    } else {
      _displayedText = _fullText;
      _isRevealing = false;
    }
  }

  void _startTypingAnimation() {
    final matches = RegExp(r'(\S+\s*)').allMatches(_fullText);
    _tokens = matches.map((m) => m.group(0)!).toList();
    if (_tokens.isEmpty) {
      _tokens = [_fullText];
    }

    _isRevealing = true;
    _tokenIndex = 0;
    _displayedText = '';
    _tickCount = 0;

    _cursorTimer = Timer.periodic(const Duration(milliseconds: 460), (timer) {
      if (mounted) {
        setState(() => _showCursor = !_showCursor);
      }
    });

    _typingTimer = Timer.periodic(const Duration(milliseconds: 26), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_tokenIndex >= _tokens.length) {
        _finishTyping();
        return;
      }

      final int stepSize = (_tokens.length > 350 && _tickCount % 4 == 0) ? 2 : 1;
      final nextIndex = math.min(_tokenIndex + stepSize, _tokens.length);
      _tokenIndex = nextIndex;
      _tickCount++;

      setState(() {
        _displayedText = _tokens.sublist(0, _tokenIndex).join('');
      });

      if (_tickCount % 4 == 0) {
        widget.onScrollRequest?.call();
      }

      if (_tokenIndex >= _tokens.length) {
        _finishTyping();
      }
    });
  }

  void _finishTyping() {
    _typingTimer?.cancel();
    _typingTimer = null;
    _cursorTimer?.cancel();
    _cursorTimer = null;
    if (mounted) {
      setState(() {
        _isRevealing = false;
        _displayedText = _fullText;
        widget.message['isNew'] = false;
      });
    } else {
      widget.message['isNew'] = false;
    }
    widget.onScrollRequest?.call();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations && _isRevealing) {
      _finishTyping();
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copied = true);

    final loc = ref.read(localeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(loc.translate('chat.copiedToClipboard')),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message['role'] == 'user';
    final isError = widget.message['role'] == 'error';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userBgColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final aiBgColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final rawContent = isUser ? (widget.message['text'] ?? '') : _displayedText;
    final contentToRender = (_isRevealing && _showCursor) ? '$rawContent ▌' : rawContent;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 6, top: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isError
                    ? (isDark ? AppColors.darkError : AppColors.lightError).withValues(alpha: 0.12)
                    : (isUser ? userBgColor : aiBgColor),
                border: Border.all(
                  color: isError
                      ? (isDark ? AppColors.darkError : AppColors.lightError).withValues(alpha: 0.5)
                      : (isUser ? Colors.transparent : borderColor),
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(14).copyWith(
                  bottomRight: isUser ? const Radius.circular(2) : null,
                  bottomLeft: !isUser ? const Radius.circular(2) : null,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUser)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.person_rounded, size: 13, color: Colors.white),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'You',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                _copied ? Icons.check_rounded : Icons.copy_rounded,
                                key: ValueKey<bool>(_copied),
                                size: 14,
                                color: _copied ? Colors.white : Colors.white70,
                              ),
                            ),
                            tooltip: 'Copy message',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _copyToClipboard(context, widget.message['text'] ?? ''),
                          ),
                        ],
                      ),
                    ),
                  if (!isUser && !isError)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  _isRevealing ? Icons.auto_awesome : Icons.gavel_rounded,
                                  size: 14,
                                  color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Legal AI Advisor',
                                style: GoogleFonts.inter(
                                  color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_isRevealing)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 8,
                                        height: 8,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(isDark ? AppColors.darkAccent : AppColors.lightAccent),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'ANALYZING',
                                        style: GoogleFonts.inter(
                                          color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'PROPERTY LAW',
                                    style: GoogleFonts.inter(
                                      color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isRevealing)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6.0),
                                  child: Tooltip(
                                    message: 'Reveal entire answer immediately',
                                    child: InkWell(
                                      onTap: _finishTyping,
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: 0.3),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.fast_forward_rounded, size: 12, color: isDark ? AppColors.darkAccent : AppColors.lightPrimary),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Show full answer',
                                              style: GoogleFonts.inter(
                                                color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              IconButton(
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                                    key: ValueKey<bool>(_copied),
                                    size: 15,
                                    color: _copied ? (isDark ? AppColors.darkSecondary : AppColors.lightSecondary) : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                  ),
                                ),
                                tooltip: 'Copy response',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _copyToClipboard(context, _fullText),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  MarkdownBody(
                    data: contentToRender,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: GoogleFonts.inter(
                        color: isUser ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        fontSize: 14.5,
                        height: 1.65,
                        letterSpacing: -0.1,
                      ),
                      pPadding: const EdgeInsets.only(bottom: 10),
                      h1: GoogleFonts.inter(
                        color: isUser ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                        height: 1.4,
                        letterSpacing: -0.4,
                      ),
                      h1Padding: const EdgeInsets.only(top: 14, bottom: 8),
                      h2: GoogleFonts.inter(
                        color: isUser ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        fontWeight: FontWeight.w700,
                        fontSize: 16.5,
                        height: 1.4,
                        letterSpacing: -0.2,
                      ),
                      h2Padding: const EdgeInsets.only(top: 12, bottom: 6),
                      h3: GoogleFonts.inter(
                        color: isUser ? Colors.white : (isDark ? AppColors.darkAccent : AppColors.lightPrimary),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.35,
                      ),
                      h3Padding: const EdgeInsets.only(top: 10, bottom: 4),
                      strong: GoogleFonts.inter(
                        color: isUser
                            ? Colors.white
                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        fontWeight: FontWeight.w700,
                      ),
                      em: GoogleFonts.inter(
                        color: isUser ? Colors.white70 : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        fontStyle: FontStyle.italic,
                      ),
                      listBullet: GoogleFonts.inter(
                        color: isUser ? Colors.white70 : (isDark ? AppColors.darkAccent : AppColors.lightPrimary),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                      listBulletPadding: const EdgeInsets.only(right: 6),
                      listIndent: 22,
                      blockquote: GoogleFonts.inter(
                        color: isUser ? Colors.white70 : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        fontSize: 13.5,
                        height: 1.55,
                        fontStyle: FontStyle.italic,
                      ),
                      blockquotePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      blockquoteDecoration: BoxDecoration(
                        color: isUser
                            ? Colors.white.withValues(alpha: 0.1)
                            : (isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(
                            color: isUser ? Colors.white70 : (isDark ? AppColors.darkAccent : AppColors.lightPrimary),
                            width: 3.5,
                          ),
                        ),
                      ),
                      code: GoogleFonts.firaCode(
                        backgroundColor: isUser
                            ? Colors.white.withValues(alpha: 0.2)
                            : (isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface),
                        color: isUser
                            ? Colors.white
                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      codeblockPadding: const EdgeInsets.all(12),
                      codeblockDecoration: BoxDecoration(
                        color: isUser
                            ? Colors.black.withValues(alpha: 0.2)
                            : (isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      tableBorder: TableBorder.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      tableHead: GoogleFonts.inter(
                        color: isUser ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                      tableBody: GoogleFonts.inter(
                        color: isUser ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        fontSize: 13,
                      ),
                      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  if (!isUser && !isError && !_isRevealing && widget.message['sources'] != null && (widget.message['sources'] as List).isNotEmpty)
                    LegalSourcesCitationCard(
                      sources: widget.message['sources'] as List,
                      isDark: isDark,
                    ),
                ],
              ),
            ),
            if (widget.message['time'] != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  widget.message['time'],
                  style: GoogleFonts.inter(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            if (!isUser && !_isRevealing && widget.message['suggestions'] != null && (widget.message['suggestions'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10.0, bottom: 8.0),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: (widget.message['suggestions'] as List).map((s) => HoverableChip(
                    label: s.toString(),
                    isDark: isDark,
                    onTap: () => widget.onSuggestionTap(s.toString()),
                  )).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
