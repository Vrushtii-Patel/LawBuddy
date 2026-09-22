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

  @override
  Widget build(BuildContext context) {
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
                            onTap: () => onPromptSelected(promptCards[0]['prompt'] as String),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: PromptCard(
                            index: 1,
                            category: promptCards[1]['category'] as String,
                            icon: promptCards[1]['icon'] as IconData,
                            accentColor: promptCards[1]['color'] as Color,
                            title: promptCards[1]['title'] as String,
                            description: promptCards[1]['desc'] as String,
                            onTap: () => onPromptSelected(promptCards[1]['prompt'] as String),
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
                          child: PromptCard(
                            index: 2,
                            category: promptCards[2]['category'] as String,
                            icon: promptCards[2]['icon'] as IconData,
                            accentColor: promptCards[2]['color'] as Color,
                            title: promptCards[2]['title'] as String,
                            description: promptCards[2]['desc'] as String,
                            onTap: () => onPromptSelected(promptCards[2]['prompt'] as String),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: PromptCard(
                            index: 3,
                            category: promptCards[3]['category'] as String,
                            icon: promptCards[3]['icon'] as IconData,
                            accentColor: promptCards[3]['color'] as Color,
                            title: promptCards[3]['title'] as String,
                            description: promptCards[3]['desc'] as String,
                            onTap: () => onPromptSelected(promptCards[3]['prompt'] as String),
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
                ].map((s) => HoverableChip(
                  label: s,
                  isDark: isDark,
                  onTap: () => onPromptSelected('Explain: $s under Indian property law'),
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
}
