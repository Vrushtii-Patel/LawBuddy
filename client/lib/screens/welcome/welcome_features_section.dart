import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class FeatureCard extends StatefulWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String description;
  final String? tag;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.description,
    this.tag,
  });

  @override
  State<FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<FeatureCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        constraints: const BoxConstraints(minHeight: 185),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? widget.accentColor.withValues(alpha: 0.8)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.accentColor,
                    size: 22,
                  ),
                ),
                if (widget.tag != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: isDark ? 0.16 : 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      widget.tag!,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.description,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                height: 1.5,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WelcomeFeaturesSection extends StatelessWidget {
  final bool isDark;
  final bool isDesktop;
  final bool isTablet;

  const WelcomeFeaturesSection({
    super.key,
    required this.isDark,
    required this.isDesktop,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final pColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final aColor = isDark ? AppColors.darkAccent : AppColors.lightAccent;

    final features = [
      FeatureCard(
        icon: Icons.document_scanner_outlined,
        accentColor: pColor,
        tag: 'OCR & PDF',
        title: 'Scan & Extract',
        description: 'Upload PDF agreements, capture physical contracts via OCR camera, or paste legal text directly.',
      ),
      FeatureCard(
        icon: Icons.shield_outlined,
        accentColor: aColor,
        tag: 'AI AUDIT',
        title: 'Detect Legal Risks',
        description: 'Identify potentially unfair, non-compliant, or one-sided builder clauses with RERA-trained AI.',
      ),
      FeatureCard(
        icon: Icons.lightbulb_outline_rounded,
        accentColor: pColor,
        tag: 'SIMPLIFIED',
        title: 'Plain-English Insights',
        description: 'Demystify dense legal jargon into 2-3 sentence layman explanations and negotiation advice.',
      ),
      FeatureCard(
        icon: Icons.calculate_outlined,
        accentColor: aColor,
        tag: 'STATE-WISE',
        title: 'Stamp Duty Calculator',
        description: 'Compute state-wise stamp duty, registration charges, local cess, and female buyer discounts across India.',
      ),
      FeatureCard(
        icon: Icons.forum_outlined,
        accentColor: pColor,
        tag: '24/7 CHAT',
        title: 'AI Legal Assistant',
        description: 'Get instant 24/7 answers on property laws, tenancy disputes, builder notices, and contract clauses.',
      ),
      FeatureCard(
        icon: Icons.checklist_rounded,
        accentColor: aColor,
        tag: 'CHECKLIST',
        title: 'Due Diligence Checklists',
        description: 'Step-by-step buyer verification covering title clearance, RERA approvals, encumbrance & OC records.',
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                'YOUR LEGAL DOCUMENTS, MADE CLEAR.',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete Legal Protection Suite',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isDesktop ? 34.0 : 26.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Six specialized AI tools built to simplify Indian real estate transactions.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isDesktop ? 15.0 : 13.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 36),

              if (isDesktop)
                Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: features[0]),
                        const SizedBox(width: 20),
                        Expanded(child: features[1]),
                        const SizedBox(width: 20),
                        Expanded(child: features[2]),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: features[3]),
                        const SizedBox(width: 20),
                        Expanded(child: features[4]),
                        const SizedBox(width: 20),
                        Expanded(child: features[5]),
                      ],
                    ),
                  ],
                )
              else if (isTablet)
                Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: features[0]),
                        const SizedBox(width: 16),
                        Expanded(child: features[1]),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: features[2]),
                        const SizedBox(width: 16),
                        Expanded(child: features[3]),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: features[4]),
                        const SizedBox(width: 16),
                        Expanded(child: features[5]),
                      ],
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    for (int i = 0; i < features.length; i++) ...[
                      if (i > 0) const SizedBox(height: 14),
                      features[i],
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
