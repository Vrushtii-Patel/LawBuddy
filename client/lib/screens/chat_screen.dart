import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/user_profile_button.dart';
import '../widgets/form_consent_widget.dart';
import 'chat/chat_ui_helpers.dart';
import 'chat/chat_empty_state.dart';
import 'chat/chat_message_bubble.dart';
import 'chat/chat_input_bar.dart';
import 'chat/chat_typing_indicator.dart';
import 'chat/chat_history_drawer.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? initialPrompt;
  const ChatScreen({super.key, this.initialPrompt});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  String? _currentSessionId;
  List<dynamic> _sessions = [];
  bool _isLoadingSessions = false;
  String? _sessionsError;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSessions();
    if (widget.initialPrompt != null && widget.initialPrompt!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(textOverride: widget.initialPrompt);
      });
    }
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoadingSessions = true;
      _sessionsError = null;
    });
    try {
      final sessions = await ApiService.fetchChatSessions();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoadingSessions = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching chat sessions: $e');
      if (mounted) {
        setState(() {
          _isLoadingSessions = false;
          _sessionsError = 'Unable to load previous conversations. Please check your connection and try again.';
        });
      }
    }
  }

  Future<void> _loadSessionDetails(String sessionId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    try {
      final data = await ApiService.fetchChatSession(sessionId);
      if (mounted && data['messages'] != null) {
        setState(() {
          _currentSessionId = sessionId;
          _messages.clear();
          for (final msg in (data['messages'] as List)) {
            _messages.add({
              'role': msg['role'],
              'text': msg['text'],
              'time': msg['time'],
              'suggestions': msg['suggestions'],
              'sources': msg['sources'],
              'isNew': false,
            });
          }
        });
        if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
          Navigator.of(context).pop();
        }
        _scrollToBottom(force: true);
      }
    } catch (e) {
      debugPrint('Error loading chat session details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to load this conversation. Please try again.'),
            backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteSession(String sessionId) async {
    final loc = ref.read(localeProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: isDark ? AppColors.darkError : AppColors.lightError, size: 22),
              const SizedBox(width: 8),
              Text(
                loc.translate('chat.deleteTitle'),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            loc.translate('chat.deleteContent'),
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                loc.translate('common.cancel'),
                style: GoogleFonts.inter(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(loc.translate('common.delete'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final success = await ApiService.deleteChatSession(sessionId);
    if (success && mounted) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      setState(() {
        _sessions.removeWhere((s) => s['id'] == sessionId);
        if (_currentSessionId == sessionId) {
          _clearChat();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(loc.translate('chat.deletedToast'), style: GoogleFonts.inter()),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _clearChat() {
    setState(() {
      _currentSessionId = null;
      _messages.clear();
    });
  }

  void _sendMessage({String? textOverride}) async {
    final text = (textOverride ?? _controller.text).trim();
    if (text.isEmpty || _isTyping) return;

    if (textOverride == null) {
      _controller.clear();
    }

    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    setState(() {
      _messages.add({
        'role': 'user',
        'text': text,
        'time': timeStr,
        'isNew': false,
      });
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      final history = _messages
          .where((m) => m['role'] == 'user' || m['role'] == 'ai')
          .map((m) => {
                'role': m['role'],
                'text': m['text'],
              })
          .toList();

      final res = await ApiService.chat(history, sessionId: _currentSessionId);
      
      final replyTime = DateTime.now();
      final replyTimeStr = "${replyTime.hour.toString().padLeft(2, '0')}:${replyTime.minute.toString().padLeft(2, '0')}";

      if (mounted) {
        setState(() {
          _isTyping = false;
          if (res['sessionId'] != null) {
            _currentSessionId = res['sessionId'];
          }
          _messages.add({
            'role': 'ai',
            'text': res['reply'] ?? 'I have reviewed your legal request.',
            'time': replyTimeStr,
            'suggestions': res['suggestions'],
            'sources': res['sources'],
            'isNew': true,
          });
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error communicating with AI assistant: $e');
      if (mounted) {
        final errTime = DateTime.now();
        final errTimeStr = "${errTime.hour.toString().padLeft(2, '0')}:${errTime.minute.toString().padLeft(2, '0')}";
        setState(() {
          _isTyping = false;
          _messages.add({
            'role': 'error',
            'text': 'The Legal AI Assistant is temporarily unavailable. Please check your internet connection and try again.',
            'time': errTimeStr,
            'isNew': false,
          });
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final pos = _scrollController.position;
        if (force || (pos.maxScrollExtent - pos.pixels) < 300) {
          _scrollController.animateTo(
            pos.maxScrollExtent,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 960;
    final isMobile = size.width < 650;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      endDrawer: ChatHistoryDrawer(
        isDark: isDark,
        loc: loc,
        sessions: _sessions,
        isLoadingSessions: _isLoadingSessions,
        sessionsError: _sessionsError,
        searchQuery: _searchQuery,
        searchController: _searchController,
        currentSessionId: _currentSessionId,
        onRetry: _loadSessions,
        onSearchChanged: (val) => setState(() => _searchQuery = val),
        onSelectSession: _loadSessionDetails,
        onDeleteSession: _deleteSession,
      ),
      body: Container(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 6),
              // TOP BAR
              _buildTopBar(context, isDark, loc),
              const SizedBox(height: 4),

              // BODY STREAM / EMPTY STATE
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: Column(
                      children: [
                        Expanded(
                          child: _messages.isEmpty
                              ? ChatEmptyState(
                                  isDark: isDark,
                                  loc: loc,
                                  isMobile: isMobile,
                                  isDesktop: isDesktop,
                                  onPromptSelected: (p) => _sendMessage(textOverride: p),
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  physics: const BouncingScrollPhysics(),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 16 : 32,
                                    vertical: 16,
                                  ),
                                  itemCount: _messages.length,
                                  itemBuilder: (context, index) {
                                    final msg = _messages[index];
                                    return AnimatedMessageBubble(
                                      key: ValueKey('${msg['role']}_${msg['time']}_$index'),
                                      message: msg,
                                      onSuggestionTap: (s) => _sendMessage(textOverride: s),
                                      onScrollRequest: _scrollToBottom,
                                    );
                                  },
                                ),
                        ),
                        if (_isTyping)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
                            child: const TypingIndicator(),
                          ),
                        ChatInput(
                          controller: _controller,
                          focusNode: _inputFocusNode,
                          isLoading: _isTyping,
                          onSend: () => _sendMessage(),
                          isMobile: isMobile,
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                            left: isMobile ? 16 : 32,
                            right: isMobile ? 16 : 32,
                            bottom: 10,
                          ),
                          child: const FormConsentAcknowledgement(
                            type: FormConsentType.legalQuestion,
                            showTerms: true,
                            showPrivacy: true,
                            margin: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TOP APP BAR (CENTERED BADGE + ACTIONS)
  // ==========================================
  Widget _buildTopBar(BuildContext context, bool isDark, LocaleNotifier loc) {
    final isDesktopOrTablet = MediaQuery.of(context).size.width >= 700;
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left: Back button
          Align(
            alignment: Alignment.centerLeft,
            child: HoverGlassButton(
              onTap: () => Navigator.of(context).pop(),
              isDark: isDark,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_rounded,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    loc.translate('common.back'),
                    style: GoogleFonts.inter(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center: True dead-center alignment (desktop/tablet only to avoid mobile overlap)
          if (isDesktopOrTablet)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '24/7 LEGAL AI ASSISTANT • RERA SPECIALIST',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Right: Action buttons
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HoverGlassIconButton(
                  icon: Icons.history_rounded,
                  tooltip: loc.translate('chat.chatHistory'),
                  isDark: isDark,
                  onTap: () {
                    _loadSessions();
                    _scaffoldKey.currentState?.openEndDrawer();
                  },
                ),
                if (_messages.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  HoverGlassIconButton(
                    icon: Icons.add_comment_outlined,
                    tooltip: loc.translate('chat.newChat'),
                    isDark: isDark,
                    onTap: _clearChat,
                  ),
                ],
                const SizedBox(width: 8),
                const UserProfileButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}