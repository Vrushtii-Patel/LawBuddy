import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/user_profile_button.dart';
import '../widgets/form_consent_widget.dart';
import '../widgets/app_toast.dart';
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

class _ChatScreenState extends ConsumerState<ChatScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  bool _isScrolled = false;
  String? _currentSessionId;
  List<dynamic> _sessions = [];
  bool _isLoadingSessions = false;
  String? _sessionsError;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSessions();
    if (widget.initialPrompt != null &&
        widget.initialPrompt!.trim().isNotEmpty) {
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
        final loc = ref.read(localeProvider.notifier);
        setState(() {
          _isLoadingSessions = false;
          _sessionsError = loc.translate('chat.loadSessionsError');
        });
      }
    }
  }

  Future<void> _loadSessionDetails(String sessionId) async {
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
        final loc = ref.read(localeProvider.notifier);
        AppToast.showError(
            context, loc.translate('chat.loadSessionDetailsError'));
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
          backgroundColor: isDark
              ? AppColors.darkElevatedSurface
              : AppColors.lightElevatedSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  color: isDark ? AppColors.darkError : AppColors.lightError,
                  size: 22),
              const SizedBox(width: 8),
              Text(
                loc.translate('chat.deleteTitle'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            loc.translate('chat.deleteContent'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.4,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                loc.translate('common.cancel'),
                style: GoogleFonts.plusJakartaSans(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? AppColors.darkError : AppColors.lightError,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(loc.translate('chat.deleteAction'),
                  style:
                      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final success = await ApiService.deleteChatSession(sessionId);
    if (success && mounted) {
      setState(() {
        _sessions.removeWhere((s) => s['id'] == sessionId);
        if (_currentSessionId == sessionId) {
          _clearChat();
        }
      });
      AppToast.showSuccess(context, loc.translate('chat.deletedToast'),
          duration: const Duration(seconds: 2));
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
      _isScrolled = false;
    });
  }

  void _sendMessage({String? textOverride}) async {
    final text = (textOverride ?? _controller.text).trim();
    if (text.isEmpty || _isTyping) return;

    if (textOverride == null) {
      _controller.clear();
    }

    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

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
      final replyTimeStr =
          "${replyTime.hour.toString().padLeft(2, '0')}:${replyTime.minute.toString().padLeft(2, '0')}";

      if (mounted) {
        final loc = ref.read(localeProvider.notifier);
        setState(() {
          _isTyping = false;
          if (res['sessionId'] != null) {
            final isNewSession = _currentSessionId != res['sessionId'];
            _currentSessionId = res['sessionId'];
            if (isNewSession) {
              _loadSessions();
            }
          }
          _messages.add({
            'role': 'ai',
            'text': res['reply'] ?? loc.translate('chat.defaultAiReply'),
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
        final loc = ref.read(localeProvider.notifier);
        final errTime = DateTime.now();
        final errTimeStr =
            "${errTime.hour.toString().padLeft(2, '0')}:${errTime.minute.toString().padLeft(2, '0')}";
        setState(() {
          _isTyping = false;
          _messages.add({
            'role': 'error',
            'text': loc.translate('chat.assistantUnavailable'),
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
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
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
              // TOP BAR (Solid page background, dynamic 1px bottom border & soft shadow)
              _buildTopBar(context, isDark, loc),

              // BODY STREAM / EMPTY STATE
              Expanded(
                child: Stack(
                  children: [
                    NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.axis == Axis.vertical) {
                          final isScrolled = notification.metrics.pixels > 6;
                          if (isScrolled != _isScrolled && mounted) {
                            setState(() => _isScrolled = isScrolled);
                          }
                        }
                        return false;
                      },
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
                                        onPromptSelected: (p) =>
                                            _sendMessage(textOverride: p),
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
                                            key: ValueKey(
                                                '${msg['role']}_${msg['time']}_$index'),
                                            message: msg,
                                            onSuggestionTap: (s) =>
                                                _sendMessage(textOverride: s),
                                            onScrollRequest: _scrollToBottom,
                                          );
                                        },
                                      ),
                              ),
                              if (_isTyping)
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 16 : 32),
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
                                  bottom: 8,
                                ),
                                child: const FormConsentAcknowledgement(
                                  type: FormConsentType.legalQuestion,
                                  showTerms: true,
                                  showPrivacy: true,
                                  compact: true,
                                  margin: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Short gradient fade from beige/background to transparent under the header
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: _isScrolled ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 180),
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  (isDark
                                      ? AppColors.darkBackground
                                      : AppColors.lightBackground),
                                  (isDark
                                      ? AppColors.darkBackground
                                      : AppColors.lightBackground)
                                      .withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TOP APP BAR
  // ==========================================
  Widget _buildTopBar(BuildContext context, bool isDark, LocaleNotifier loc) {
    final pageBg =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: pageBg,
        border: Border(
          bottom: BorderSide(
            color: _isScrolled ? borderColor : Colors.transparent,
            width: 1.0,
          ),
        ),
        boxShadow: _isScrolled
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Back button + Product Identity
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  size: 22,
                ),
                tooltip: loc.translate('common.back'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              Text(
                'LawBuddy',
                style: GoogleFonts.plusJakartaSans(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),

          // Right: Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.edit_note_rounded,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  size: 22,
                ),
                tooltip: loc.translate('chat.newChat'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                onPressed: _clearChat,
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  Icons.history_rounded,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  size: 22,
                ),
                tooltip: loc.translate('chat.chatHistory'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                onPressed: () {
                  _loadSessions();
                  _scaffoldKey.currentState?.openEndDrawer();
                },
              ),
              const SizedBox(width: 4),
              const UserProfileButton(),
            ],
          ),
        ],
      ),
    );
  }
}
