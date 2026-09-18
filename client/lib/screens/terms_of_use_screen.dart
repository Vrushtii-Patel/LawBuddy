import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';

class TermsOfUseScreen extends ConsumerWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;
    final currentLanguage = ref.watch(localeProvider);
    final isHindi = currentLanguage == AppLanguage.hindi;

    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final accentColor = isDark ? AppColors.darkAccent : AppColors.lightPrimary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: primaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: isHindi ? 'वापस जाएं' : 'Back',
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.description_outlined, color: accentColor, size: 18),
            ),
            const SizedBox(width: 8),
            Text(
              'LawBuddy',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
            ),
          ],
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 48 : 20,
          vertical: 36,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    isHindi ? 'उपयोग की शर्तें' : 'TERMS OF SERVICE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Main Title
                Text(
                  isHindi ? 'उपयोग की शर्तें' : 'Terms of Use',
                  style: GoogleFonts.inter(
                    fontSize: isDesktop ? 34 : 26,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),

                // Last Updated
                Text(
                  isHindi ? 'अंतिम अद्यतन: 15 सितंबर 2026' : 'Last Updated: 15 September 2026',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 24),

                // Mandatory Legal Notice Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.gavel_rounded, color: accentColor, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isHindi ? 'महत्वपूर्ण सूचना: विधिक सलाह अस्वीकरण' : 'Important Notice: No Legal Advice',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isHindi
                                  ? 'LawBuddy केवल सूचनात्मक और दस्तावेज़ विश्लेषण सहायता के उद्देश्य से AI-संचालित विश्लेषण प्रदान करता है। यह किसी अधिकृत वकील या विधिक पेशेवर की सलाह का विकल्प नहीं है।'
                                  : 'LawBuddy provides AI-powered document analysis and assistive legal information for informational and educational purposes only. It does not constitute legal advice and does not establish an attorney-client relationship.',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                height: 1.5,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Terms Sections
                _buildSection(
                  number: '1',
                  title: isHindi ? 'स्वीकृति' : 'Acceptance of Terms',
                  content: isHindi
                      ? 'LawBuddy का उपयोग करके, आप इन नियमों और शर्तों से बंधे होने के लिए सहमत होते हैं।'
                      : 'By accessing and using LawBuddy, you agree to comply with and be bound by these Terms of Use. If you do not agree, please do not use the application.',
                  isDark: isDark,
                  cardColor: cardColor,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  borderColor: borderColor,
                  accentColor: accentColor,
                ),
                _buildSection(
                  number: '2',
                  title: isHindi ? 'सेवा का विवरण' : 'Description of Service',
                  content: isHindi
                      ? 'LawBuddy भारतीय संपत्ति दस्तावेजों (जैसे सेल डीड, लीज एग्रीमेंट, पावर ऑफ अटॉर्नी आदि) के लिए AI-आधारित OCR, विश्लेषण और चेकलिस्ट सहायता प्रदान करता है।'
                      : 'LawBuddy offers AI-assisted document parsing, optical character recognition (OCR), risk flag identification, due-diligence checklists, and informational assistance for Indian property and real estate documentation.',
                  isDark: isDark,
                  cardColor: cardColor,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  borderColor: borderColor,
                  accentColor: accentColor,
                ),
                _buildSection(
                  number: '3',
                  title: isHindi ? 'उपयोगकर्ता की जिम्मेदारियां' : 'User Responsibilities & Data Accuracy',
                  content: isHindi
                      ? 'उपयोगकर्ता यह सुनिश्चित करने के लिए जिम्मेदार हैं कि उनके द्वारा अपलोड किए गए दस्तावेज़ वैध हैं और उनके पास उनका अधिकार है। महत्वपूर्ण संपत्ति लेन-देन के लिए हमेशा मूल दस्तावेजों का वकील से सत्यापन करवाएं।'
                      : 'Users are responsible for ensuring they possess the right to upload submitted documents. Users must independently verify critical contractual details, financial figures, stamp duty requirements, and title records with certified legal counsel or local registrar offices.',
                  isDark: isDark,
                  cardColor: cardColor,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  borderColor: borderColor,
                  accentColor: accentColor,
                ),
                _buildSection(
                  number: '4',
                  title: isHindi ? 'बौद्धिक संपदा' : 'Intellectual Property',
                  content: isHindi
                      ? 'LawBuddy की तकनीक, सॉफ्टवेयर और इंटरफ़ेस LawBuddy के स्वामित्व में हैं। आपके द्वारा अपलोड की गई व्यक्तिगत फाइलें आपकी ही रहती हैं।'
                      : 'The LawBuddy application, including UI layouts, algorithms, heuristics, logos, and software code, is protected under applicable intellectual property laws. You retain full ownership of the documents you submit.',
                  isDark: isDark,
                  cardColor: cardColor,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  borderColor: borderColor,
                  accentColor: accentColor,
                ),
                _buildSection(
                  number: '5',
                  title: isHindi ? 'दायित्व की सीमा' : 'Limitation of Liability',
                  content: isHindi
                      ? 'LawBuddy और इसके डेवलपर्स किसी भी वित्तीय या कानूनी निर्णय, संपत्ति विवाद, या AI व्याख्याओं के आधार पर किए गए कार्यों के लिए उत्तरदायी नहीं होंगे।'
                      : 'To the maximum extent permitted under applicable law, LawBuddy and its developers shall not be liable for any direct, indirect, incidental, or consequential damages resulting from reliance on AI summaries or analysis generated by the platform.',
                  isDark: isDark,
                  cardColor: cardColor,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  borderColor: borderColor,
                  accentColor: accentColor,
                ),
                _buildSection(
                  number: '6',
                  title: isHindi ? 'संपर्क' : 'Contact Information',
                  content: isHindi
                      ? 'उपयोग की शर्तों के संबंध में किसी भी प्रश्न के लिए finalyearproject2513@gmail.com पर संपर्क करें।'
                      : 'For inquiries regarding these Terms of Use, please reach out to finalyearproject2513@gmail.com.',
                  isDark: isDark,
                  cardColor: cardColor,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  borderColor: borderColor,
                  accentColor: accentColor,
                ),
                const SizedBox(height: 40),

                // Back Button
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: Text(
                      isHindi ? 'वापस जाएं' : 'Return to App',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryTextColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String number,
    required String title,
    required String content,
    required bool isDark,
    required Color cardColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
    required Color accentColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              height: 1.6,
              color: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}
