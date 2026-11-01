import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';

class LawBuddyFaqItem {
  final String category;
  final String question;
  final String answer;

  const LawBuddyFaqItem({
    required this.category,
    required this.question,
    required this.answer,
  });
}

class WelcomeFaqSection extends ConsumerStatefulWidget {
  final bool isDark;
  final bool isDesktop;
  final bool isTablet;

  const WelcomeFaqSection({
    super.key,
    required this.isDark,
    required this.isDesktop,
    required this.isTablet,
  });

  @override
  ConsumerState<WelcomeFaqSection> createState() => _WelcomeFaqSectionState();
}

class _WelcomeFaqSectionState extends ConsumerState<WelcomeFaqSection> {
  String _selectedCategory = 'All';

  static const List<LawBuddyFaqItem> _faqList = [
    LawBuddyFaqItem(
      category: 'RERA & Law',
      question: 'How does LawBuddy detect hidden clauses and RERA violations?',
      answer:
          'LawBuddy cross-references your uploaded agreement clause-by-clause against authoritative Indian real estate legislation, primarily the Real Estate (Regulation and Development) Act (RERA) 2016. It automatically flags statutory violations such as advance payments exceeding the 10% ceiling (Section 13), asymmetric delay penalties favoring the builder over the buyer (Section 18), unilateral earnest money forfeiture, and omitted defect-liability guarantees (Section 14). Every finding details the exact legal risk and statutory citation.',
    ),
    LawBuddyFaqItem(
      category: 'Documents',
      question: 'What types of property agreements and file formats are supported?',
      answer:
          'You can upload registered Agreements for Sale, Builder-Buyer Agreements, Allotment Letters, Conveyance Deeds, Commercial & Residential Lease Agreements, and Title Search reports. LawBuddy accepts multi-page PDF documents, camera captures, phone gallery images (JPEG, PNG, WebP), or directly pasted clause text. Files up to 50MB with multi-page pagination are analyzed completely.',
    ),
    LawBuddyFaqItem(
      category: 'OCR & Vernacular',
      question: 'Can LawBuddy read physical document photos in Hindi or Marathi?',
      answer:
          'Yes. LawBuddy features built-in Devanagari OCR tailored for Indian state registry documents, 7/12 extracts, and sale deeds written in Hindi and Marathi. When older physical scans suffer from low contrast, folded creases, or official stamps, the system automatically triggers AI vision processing to transcribe the content accurately while preserving clause numbering and dates.',
    ),
    LawBuddyFaqItem(
      category: 'Privacy & Security',
      question: 'Is my property document confidential and securely handled?',
      answer:
          'Yes, completely. Your agreements and personal data are strictly private. All network traffic is encrypted via TLS 1.3 / HTTPS, and stored files are protected with user-isolated database permissions and cryptographic hash deduplication. We never sell your personal data or use private agreements for public AI training. You can also soft-delete documents to the 30-day Recycle Bin or permanently shred them from the server at any time.',
    ),
    LawBuddyFaqItem(
      category: 'Stamp Duty & Fees',
      question: 'How does the Stamp Duty & Registration Calculator compute my expenses?',
      answer:
          'Stamp duty and registration charges in India are governed at the state revenue level. LawBuddy incorporates active revenue schedules for 14+ Indian states (including Maharashtra, Karnataka, Delhi, Gujarat, Tamil Nadu, Uttar Pradesh, and West Bengal). It evaluates your agreement value against official circle / ready-reckoner rates, property classification (residential vs. commercial vs. land), gender concessions (such as 1% female purchaser rebates), first-time homebuyer relief, and local municipal cess.',
    ),
    LawBuddyFaqItem(
      category: 'Next Steps',
      question: 'What concrete steps should I take if a clause is marked High Risk (Red)?',
      answer:
          'A Red flag indicates an aggressive one-sided liability, statutory non-compliance, or severe financial exposure (such as builder-biased cancellation terms). LawBuddy provides exact reasoning and cited statute references so you can share the report directly with the promoter/seller to request a contract amendment, ask for alignment with the official model RERA agreement, or consult your property advocate before signing or making disbursements.',
    ),
    LawBuddyFaqItem(
      category: 'Due Diligence',
      question: 'Does LawBuddy check if a property has an active mortgage or clear title?',
      answer:
          'LawBuddy audits the contractual covenants, warranties, and obligations stated inside the document you provide. While it flags whether an agreement contains proper non-encumbrance declarations and indemnity covenants, confirming that a property is free of undisclosed bank mortgages requires obtaining a 30-year Non-Encumbrance Certificate (EC) from the Sub-Registrar\'s Office and conducting an Index II search. LawBuddy\'s Due Diligence Checklist automatically guides you through these exact verification steps.',
    ),
    LawBuddyFaqItem(
      category: 'Legal Advice',
      question: 'Does LawBuddy replace a licensed property lawyer or legal advocate?',
      answer:
          'No. LawBuddy is an intelligent preliminary audit and due diligence assistant created to decode complex legal jargon, give you bargaining transparency, and prevent rushed signatures on unfair contracts. For final transaction execution, court registration, and formal title search certificates, you should always consult a licensed real estate advocate.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isDesktop = widget.isDesktop;
    final loc = ref.watch(localeProvider.notifier);

    final categories = ['All', 'RERA & Law', 'Documents', 'OCR & Vernacular', 'Privacy & Security', 'Stamp Duty & Fees', 'Next Steps'];

    final filteredFaqs = _selectedCategory == 'All'
        ? _faqList
        : _faqList.where((item) => item.category == _selectedCategory).toList();

    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final accentColor = isDark ? AppColors.darkAccent : AppColors.lightPrimary;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : (widget.isTablet ? 24 : 16),
          ),
          child: Column(
            children: [
              // Eyebrow Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: accentColor.withValues(alpha: isDark ? 0.35 : 0.2),
                  ),
                ),
                child: Text(
                  loc.translate('welcome.faqEyebrow'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                loc.translate('welcome.faqTitle'),
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isDesktop ? 34.0 : 25.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle
              Text(
                loc.translate('welcome.faqSubtitle'),
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isDesktop ? 15.0 : 13.5,
                  height: 1.5,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 28),

              // Category Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(cat),
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? Colors.white : AppColors.lightPrimary)
                              : textSecondary,
                        ),
                        backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                        selectedColor: accentColor.withValues(alpha: isDark ? 0.25 : 0.15),
                        checkmarkColor: accentColor,
                        side: BorderSide(
                          color: isSelected
                              ? accentColor.withValues(alpha: 0.7)
                              : borderColor,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Accordion List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredFaqs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final faq = filteredFaqs[index];
                  return _FaqCard(
                    faq: faq,
                    isDark: isDark,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    accentColor: accentColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqCard extends StatefulWidget {
  final LawBuddyFaqItem faq;
  final bool isDark;
  final Color surfaceColor;
  final Color borderColor;
  final Color accentColor;
  final Color textPrimary;
  final Color textSecondary;

  const _FaqCard({
    required this.faq,
    required this.isDark,
    required this.surfaceColor,
    required this.borderColor,
    required this.accentColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _isExpanded = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            if (_isExpanded || _isHovered)
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Material(
          color: widget.surfaceColor,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: _isExpanded
                  ? widget.accentColor.withValues(alpha: 0.6)
                  : (_isHovered
                      ? widget.accentColor.withValues(alpha: 0.35)
                      : widget.borderColor),
              width: _isExpanded ? 1.4 : 1.0,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              onExpansionChanged: (expanded) {
                setState(() => _isExpanded = expanded);
              },
              iconColor: widget.accentColor,
              collapsedIconColor: widget.textSecondary,
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: widget.isDark ? 0.16 : 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.faq.category.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.faq.question,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: _isExpanded ? widget.accentColor : widget.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.025),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.borderColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      widget.faq.answer,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        height: 1.6,
                        color: widget.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
