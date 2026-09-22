import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/user_profile_button.dart';
import '../widgets/form_consent_widget.dart';

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
      endDrawer: _buildHistoryDrawer(context, isDark, loc),
      body: Container(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        child: SafeArea(
          child: Column(
            children: [
              // TOP BAR
              _buildTopBar(context, isDark, loc),

              // BODY STREAM / EMPTY STATE
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: Column(
                      children: [
                        Expanded(
                          child: _messages.isEmpty
                              ? _buildEmptyState(isDark, loc, isMobile, isDesktop)
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
                                    return _AnimatedMessageBubble(
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
                            child: const _TypingIndicator(),
                          ),
                        _ChatInput(
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
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left: Back button
          Align(
            alignment: Alignment.centerLeft,
            child: _HoverGlassButton(
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

          // Center: True dead-center alignment
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
                _HoverGlassIconButton(
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
                  _HoverGlassIconButton(
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

  // ==========================================
  // EMPTY STATE (HERO + PROMPTS + BADGES)
  // ==========================================
  Widget _buildEmptyState(bool isDark, LocaleNotifier loc, bool isMobile, bool isDesktop) {
    final promptCards = [
      {
        'category': loc.translate('chat.card1Cat'),
        'icon': Icons.description_outlined,
        'color': isDark ? AppColors.darkAccent : AppColors.lightPrimary,
        'title': loc.translate('chat.card1Title'),
        'desc': loc.translate('chat.card1Desc'),
        'prompt': 'Can you review the key clauses in a residential property agreement and highlight standard red flags?',
      },
      {
        'category': loc.translate('chat.card2Cat'),
        'icon': Icons.shield_outlined,
        'color': isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
        'title': loc.translate('chat.card2Title'),
        'desc': loc.translate('chat.card2Desc'),
        'prompt': 'What are my legal rights and compensation rules under RERA if a builder delays possession?',
      },
      {
        'category': loc.translate('chat.card3Cat'),
        'icon': Icons.edit_note_rounded,
        'color': isDark ? AppColors.darkAccent : AppColors.lightPrimary,
        'title': loc.translate('chat.card3Title'),
        'desc': loc.translate('chat.card3Desc'),
        'prompt': 'Please draft a standard 11-month residential rental agreement with essential tenant and landlord clauses.',
      },
      {
        'category': loc.translate('chat.card4Cat'),
        'icon': Icons.account_balance_outlined,
        'color': isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
        'title': loc.translate('chat.card4Title'),
        'desc': loc.translate('chat.card4Desc'),
        'prompt': 'What documents and procedures are mandatory for property registration and stamp duty payment in India?',
      },
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),

              // Emblem Badge
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.3),
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.balance_rounded,
                    size: 30,
                    color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Eyebrow Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.25),
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
                    const SizedBox(width: 7),
                    Text(
                      'AI CONTRACT SCRUTINY • RERA RIGHTS • INSTANT CONSULTATION',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Main Headline
              Text(
                loc.translate('chat.heroHeadline'),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  fontSize: isMobile ? 22 : 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Text(
                  loc.translate('chat.heroSubtitle'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Legal Badges Row
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildLegalTag(Icons.shield_outlined, loc.translate('chat.tagRera'), isDark ? AppColors.darkSecondary : AppColors.lightSecondary, isDark),
                  _buildLegalTag(Icons.description_outlined, loc.translate('chat.tagTenancy'), isDark ? AppColors.darkAccent : AppColors.lightPrimary, isDark),
                  _buildLegalTag(Icons.balance_rounded, loc.translate('chat.tagTransfer'), isDark ? AppColors.darkSecondary : AppColors.lightSecondary, isDark),
                ],
              ),

              const SizedBox(height: 28),

              // 2x2 Interactive Prompt Cards Grid
              if (isMobile)
                Column(
                  children: promptCards.asMap().entries.map((entry) {
                    final index = entry.key;
                    final p = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _PromptCard(
                        index: index,
                        category: p['category'] as String,
                        icon: p['icon'] as IconData,
                        accentColor: p['color'] as Color,
                        title: p['title'] as String,
                        description: p['desc'] as String,
                        onTap: () => _sendMessage(textOverride: p['prompt'] as String),
                        isDark: isDark,
                      ),
                    );
                  }).toList(),
                )
              else
                Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _PromptCard(
                            index: 0,
                            category: promptCards[0]['category'] as String,
                            icon: promptCards[0]['icon'] as IconData,
                            accentColor: promptCards[0]['color'] as Color,
                            title: promptCards[0]['title'] as String,
                            description: promptCards[0]['desc'] as String,
                            onTap: () => _sendMessage(textOverride: promptCards[0]['prompt'] as String),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _PromptCard(
                            index: 1,
                            category: promptCards[1]['category'] as String,
                            icon: promptCards[1]['icon'] as IconData,
                            accentColor: promptCards[1]['color'] as Color,
                            title: promptCards[1]['title'] as String,
                            description: promptCards[1]['desc'] as String,
                            onTap: () => _sendMessage(textOverride: promptCards[1]['prompt'] as String),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _PromptCard(
                            index: 2,
                            category: promptCards[2]['category'] as String,
                            icon: promptCards[2]['icon'] as IconData,
                            accentColor: promptCards[2]['color'] as Color,
                            title: promptCards[2]['title'] as String,
                            description: promptCards[2]['desc'] as String,
                            onTap: () => _sendMessage(textOverride: promptCards[2]['prompt'] as String),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _PromptCard(
                            index: 3,
                            category: promptCards[3]['category'] as String,
                            icon: promptCards[3]['icon'] as IconData,
                            accentColor: promptCards[3]['color'] as Color,
                            title: promptCards[3]['title'] as String,
                            description: promptCards[3]['desc'] as String,
                            onTap: () => _sendMessage(textOverride: promptCards[3]['prompt'] as String),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

              const SizedBox(height: 24),

              // Quick Topic Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  loc.translate('chat.chip1'),
                  loc.translate('chat.chip2'),
                  loc.translate('chat.chip3'),
                  loc.translate('chat.chip4'),
                ].map((s) => _HoverableChip(
                  label: s,
                  isDark: isDark,
                  onTap: () => _sendMessage(textOverride: 'Explain: $s under Indian property law'),
                )).toList(),
              ),

              const SizedBox(height: 24),

              // Legal Disclaimer Capsule
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        loc.translate('chat.disclaimer'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          fontSize: 11,
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

  Widget _buildLegalTag(IconData icon, String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HISTORY DRAWER
  // ==========================================
  Widget _buildHistoryDrawer(BuildContext context, bool isDark, LocaleNotifier loc) {
    final filteredSessions = _searchQuery.trim().isEmpty
        ? _sessions
        : _sessions.where((s) {
            final title = (s['title'] ?? '').toString().toLowerCase();
            final snippet = (s['lastSnippet'] ?? '').toString().toLowerCase();
            final q = _searchQuery.trim().toLowerCase();
            return title.contains(q) || snippet.contains(q);
          }).toList();

    return Drawer(
      backgroundColor: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        loc.translate('chat.chatHistory'),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? AppColors.darkAccent : AppColors.lightPrimary),
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            // Session List
            Expanded(
              child: _isLoadingSessions
                  ? Center(
                      child: CircularProgressIndicator(
                        color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                      ),
                    )
                  : _sessionsError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.wifi_off_rounded,
                                  size: 28,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Couldn\'t load conversations',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: _loadSessions,
                                  child: Text(
                                    'Retry',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filteredSessions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              _searchQuery.isNotEmpty ? 'No sessions found' : 'No previous conversations',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          itemCount: filteredSessions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final session = filteredSessions[index];
                            final sessionId = (session['id'] ?? '').toString();
                            final title = (session['title'] ?? 'Legal Conversation').toString();
                            final lastSnippet = (session['lastSnippet'] ?? '').toString();
                            final count = session['messageCount'] ?? 0;
                            final isSelected = _currentSessionId == sessionId;

                            return InkWell(
                              onTap: () => _loadSessionDetails(sessionId),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: 0.12)
                                      : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 16,
                                      color: isSelected
                                          ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                            ),
                                          ),
                                          if (lastSnippet.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              lastSnippet,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                                fontSize: 11,
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  loc.translate('chat.turnsCount', {'count': count.toString()}),
                                                  style: GoogleFonts.inter(
                                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 16,
                                        color: isDark ? AppColors.darkError : AppColors.lightError,
                                      ),
                                      tooltip: 'Delete session',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _deleteSession(sessionId),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// PROMPT ACTION CARD WIDGET
// ==========================================
class _PromptCard extends ConsumerStatefulWidget {
  final int index;
  final String category;
  final IconData icon;
  final Color accentColor;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool isDark;

  const _PromptCard({
    required this.index,
    required this.category,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.description,
    required this.onTap,
    required this.isDark,
  });

  @override
  ConsumerState<_PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends ConsumerState<_PromptCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);
    final itemAccent = widget.accentColor;
    final isDark = widget.isDark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.translationValues(0, _isHovered ? -2.0 : 0, 0),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered
                  ? itemAccent.withValues(alpha: 0.8)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1.0,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Icon Container + Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: itemAccent.withValues(alpha: isDark ? 0.15 : 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: itemAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(widget.icon, color: itemAccent, size: 20),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          widget.category,
                          style: GoogleFonts.inter(
                            color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    widget.title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Description
                  Text(
                    widget.description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Bottom Action Row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    loc.translate('chat.askLegalAi'),
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                    size: 14,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// ANIMATED MESSAGE BUBBLE
// ==========================================
class _AnimatedMessageBubble extends ConsumerStatefulWidget {
  final Map<String, dynamic> message;
  final Function(String) onSuggestionTap;
  final VoidCallback? onScrollRequest;

  const _AnimatedMessageBubble({
    super.key,
    required this.message,
    required this.onSuggestionTap,
    this.onScrollRequest,
  });

  @override
  ConsumerState<_AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends ConsumerState<_AnimatedMessageBubble> {
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
                    _LegalSourcesCitationCard(
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
                  children: (widget.message['suggestions'] as List).map((s) => _HoverableChip(
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

// ==========================================
// LEGAL SOURCES CITATION CARD
// ==========================================
class _LegalSourcesCitationCard extends StatefulWidget {
  final List<dynamic> sources;
  final bool isDark;

  const _LegalSourcesCitationCard({
    required this.sources,
    required this.isDark,
  });

  @override
  State<_LegalSourcesCitationCard> createState() => _LegalSourcesCitationCardState();
}

class _LegalSourcesCitationCardState extends State<_LegalSourcesCitationCard> {
  bool _isExpanded = false;

  Future<void> _launchSourceUrl(String? urlStr) async {
    if (urlStr == null || urlStr.isEmpty) return;
    try {
      final uri = Uri.parse(urlStr);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error opening citation URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primaryColor = isDark ? AppColors.darkAccent : AppColors.lightPrimary;
    final secondaryColor = isDark ? AppColors.darkSecondary : AppColors.lightSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surfaceColor = isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Icon(Icons.verified_outlined, size: 15, color: primaryColor),
                  const SizedBox(width: 7),
                  Text(
                    'Authoritative Legal Sources (${widget.sources.length})',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'RAG Grounded',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            Divider(height: 1, color: borderColor),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.sources.map((src) {
                  final map = src is Map ? src : {};
                  final doc = (map['document'] ?? 'Statutory Law').toString();
                  final sec = map['section'] != null ? 'Sec ${map['section']}' : map['rule']?.toString();
                  final authority = (map['authority'] ?? 'Official Law').toString();
                  final jurisdiction = (map['jurisdiction'] ?? 'India').toString();
                  final url = map['sourceUrl'] as String?;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: borderColor.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(Icons.menu_book_rounded, size: 14, color: secondaryColor),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    doc,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  if (sec != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: secondaryColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        sec,
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: secondaryColor,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    '$jurisdiction • $authority',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                  if (url != null && url.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () => _launchSourceUrl(url),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Official Source',
                                            style: GoogleFonts.inter(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: primaryColor,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Icon(Icons.open_in_new_rounded, size: 10, color: primaryColor),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ==========================================
// CHAT DOCKED INPUT BAR
// ==========================================
class _ChatInput extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSend;
  final bool isMobile;

  const _ChatInput({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSend,
    required this.isMobile,
  });

  @override
  ConsumerState<_ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<_ChatInput> {
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

// ==========================================
// HOVERABLE TOPIC CHIP
// ==========================================
class _HoverableChip extends StatefulWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _HoverableChip({
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_HoverableChip> createState() => _HoverableChipState();
}

class _HoverableChipState extends State<_HoverableChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface)
                : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.gavel_rounded,
                size: 12,
                color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// TYPING INDICATOR
// ==========================================
class _TypingIndicator extends ConsumerStatefulWidget {
  const _TypingIndicator();

  @override
  ConsumerState<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends ConsumerState<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);

    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14).copyWith(bottomLeft: const Radius.circular(2)),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.auto_awesome, size: 13, color: isDark ? AppColors.darkAccent : AppColors.lightPrimary),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loc.translate('chat.typingTitle'),
                      style: GoogleFonts.inter(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      children: List.generate(3, (index) {
                        return AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            final progress = (_controller.value * 3 - index) % 3;
                            final offset = progress >= 0 && progress <= 1 ? -4.0 * (0.5 - (progress - 0.5).abs()) : 0.0;
                            return Transform.translate(
                              offset: Offset(0, offset),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                                child: Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }),
                    ),
                  ],
                ),
                Text(
                  loc.translate('chat.typingSubtitle'),
                  style: GoogleFonts.inter(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// HOVER GLASS BUTTON HELPERS
// ==========================================
class _HoverGlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isDark;

  const _HoverGlassButton({
    required this.child,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_HoverGlassButton> createState() => _HoverGlassButtonState();
}

class _HoverGlassButtonState extends State<_HoverGlassButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface)
                : (widget.isDark ? AppColors.darkSurface : AppColors.lightSurface),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovered
                  ? (widget.isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                  : (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _HoverGlassIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isDark;

  const _HoverGlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_HoverGlassIconButton> createState() => _HoverGlassIconButtonState();
}

class _HoverGlassIconButtonState extends State<_HoverGlassIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isHovered
                  ? (widget.isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface)
                  : (widget.isDark ? AppColors.darkSurface : AppColors.lightSurface),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isHovered
                    ? (widget.isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                    : (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ),
    );
  }
}