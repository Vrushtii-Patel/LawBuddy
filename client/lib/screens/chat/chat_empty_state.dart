import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';
import 'chat_prompt_card.dart';

class ChatEmptyState extends StatelessWidget {
  final bool isDark;
  final LocaleNotifier loc;
  final bool isMobile;
  final bool isDesktop;
  final Function(String) onPromptSelected;

  const ChatEmptyState({
    super.key,
    required this.isDark,
    required this.loc,
    required this.isMobile,
    required this.isDesktop,
    required this.onPromptSelected,
  });

  @override
  Widget build(BuildContext context) {
    final promptCards = [
      {
        'category': loc.translate('chat.card1Cat'),
        'icon': Icons.description_outlined,
        'color': isDark ? AppColors.darkAccent : AppColors.lightPrimary,
        'title': loc.translate('chat.card1Title'),
        'desc': loc.translate('chat.card1Desc'),
        'prompt':
            'Can you review the key clauses in a residential property agreement and highlight standard red flags?',
      },
      {
        'category': loc.translate('chat.card2Cat'),
        'icon': Icons.shield_outlined,
        'color': isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
        'title': loc.translate('chat.card2Title'),
        'desc': loc.translate('chat.card2Desc'),
        'prompt':
            'What are my legal rights and compensation rules under RERA if a builder delays possession?',
      },
      {
        'category': loc.translate('chat.card3Cat'),
        'icon': Icons.edit_note_rounded,
        'color': isDark ? AppColors.darkAccent : AppColors.lightPrimary,
        'title': loc.translate('chat.card3Title'),
        'desc': loc.translate('chat.card3Desc'),
        'prompt':
            'Please draft a standard 11-month residential rental agreement with essential tenant and landlord clauses.',
      },
      {
        'category': loc.translate('chat.card4Cat'),
        'icon': Icons.account_balance_outlined,
        'color': isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
        'title': loc.translate('chat.card4Title'),
        'desc': loc.translate('chat.card4Desc'),
        'prompt':
            'What documents and procedures are mandatory for property registration and stamp duty payment in India?',
      },
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 28,
        vertical: isMobile ? 24 : 36,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Clean Centered Emblem
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                          .withValues(alpha: 0.2),
                      (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                          .withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary)
                        .withValues(alpha: 0.25),
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.balance_rounded,
                    size: 24,
                    color:
                        isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                loc.translate('chat.heroHeadline'),
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                  fontSize: isMobile ? 22 : 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(
                  loc.translate('chat.heroSubtitle'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // 4 Clean Starter Prompt Cards in Responsive Grid
              if (isMobile)
                Column(
                  children: promptCards.asMap().entries.map((entry) {
                    final index = entry.key;
                    final p = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PromptCard(
                        index: index,
                        category: p['category'] as String,
                        icon: p['icon'] as IconData,
                        accentColor: p['color'] as Color,
                        title: p['title'] as String,
                        description: p['desc'] as String,
                        onTap: () => onPromptSelected(p['prompt'] as String),
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
                          child: PromptCard(
                            index: 0,
                            category: promptCards[0]['category'] as String,
                            icon: promptCards[0]['icon'] as IconData,
                            accentColor: promptCards[0]['color'] as Color,
                            title: promptCards[0]['title'] as String,
                            description: promptCards[0]['desc'] as String,
                            onTap: () => onPromptSelected(
                                promptCards[0]['prompt'] as String),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PromptCard(
                            index: 1,
                            category: promptCards[1]['category'] as String,
                            icon: promptCards[1]['icon'] as IconData,
                            accentColor: promptCards[1]['color'] as Color,
                            title: promptCards[1]['title'] as String,
                            description: promptCards[1]['desc'] as String,
                            onTap: () => onPromptSelected(
                                promptCards[1]['prompt'] as String),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: PromptCard(
                            index: 2,
                            category: promptCards[2]['category'] as String,
                            icon: promptCards[2]['icon'] as IconData,
                            accentColor: promptCards[2]['color'] as Color,
                            title: promptCards[2]['title'] as String,
                            description: promptCards[2]['desc'] as String,
                            onTap: () => onPromptSelected(
                                promptCards[2]['prompt'] as String),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PromptCard(
                            index: 3,
                            category: promptCards[3]['category'] as String,
                            icon: promptCards[3]['icon'] as IconData,
                            accentColor: promptCards[3]['color'] as Color,
                            title: promptCards[3]['title'] as String,
                            description: promptCards[3]['desc'] as String,
                            onTap: () => onPromptSelected(
                                promptCards[3]['prompt'] as String),
                            isDark: isDark,
                          ),
                        ),
                      ],
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
