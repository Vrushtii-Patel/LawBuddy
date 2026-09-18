import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/locale_provider.dart';
import '../widgets/cookie_consent_banner.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

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
              child: Icon(Icons.shield_outlined, color: accentColor, size: 18),
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
                    isHindi ? 'कानूनी दस्तावेज' : 'LEGAL & PRIVACY',
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
                  isHindi ? 'गोपनीयता नीति' : 'Privacy Policy',
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

                // Summary Notice Box
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.privacy_tip_outlined, color: accentColor, size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isHindi ? 'आपकी गोपनीयता और डेटा पारदर्शिता' : 'Privacy & Data Handling Overview',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isHindi
                                  ? 'LawBuddy आपके संपत्ति दस्तावेजों और व्यक्तिगत डेटा के प्रसंस्करण के बारे में पारदर्शी रहने के लिए प्रतिबद्ध है। यह नीति बताती है कि डेटा कैसे एकत्र, संग्रहीत और संसाधित किया जाता है।'
                                  : 'LawBuddy is committed to transparency regarding how your property documents and account data are processed, stored, and analyzed by our AI and OCR technology.',
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

                // 13 Audited Sections
                _buildPolicySection(
                  number: '1',
                  title: isHindi ? 'परिचय (Introduction)' : 'Introduction',
                  content:
                      'Welcome to LawBuddy ("we", "our", or "us"). LawBuddy is an Indian property and legal technology assistant designed to assist users in analyzing property agreements, understanding clause-level risks, reviewing RERA and statutory citations, estimating stamp duty, and tracking due diligence checklists.\n\nThis Privacy Policy explains what information is collected, how it is stored and processed, how AI and OCR technologies are utilized, and what controls you have over your data.',
                  primaryColor: primaryTextColor,
                  secondaryColor: secondaryTextColor,
                  accentColor: accentColor,
                ),

                _buildPolicySection(
                  number: '2',
                  title: isHindi ? 'हम कौन सी जानकारी एकत्र करते हैं (Information We Collect)' : 'Information We Collect',
                  content:
                      'Based on the current application implementation, we collect and store the following information:\n\n'
                      '• Account Information: Your full name, email address, password hash (encrypted via bcrypt), optional phone number, profile avatar reference, and account timestamps (creation, last login).\n'
                      '• Document & Contract Data: Property contracts, sale deeds, lease agreements, and text snippets uploaded via file upload, camera photo, or direct text input.\n'
                      '• File Data & Hash: File names, document sizes, computed SHA-256 hashes, and base64-encoded file/image data when documents are uploaded.\n'
                      '• Extracted Text & Segmentation: Text extracted from documents (via digital parsing, OCR, or vision extraction), normalized text, and segmented legal clauses.\n'
                      '• Analysis Results: Clause risk classifications (High Risk, Caution, Compliant), legal findings, statutory citations (e.g., RERA, Transfer of Property Act), buyer impact explanations, and recommendations.\n'
                      '• Chat & Consultation History: User queries, questions, and AI-generated responses submitted within the AI Chat Assistant.\n'
                      '• Due Diligence Checklist Data: Saved checklist types (e.g., resale buying, builder purchase), custom checklist items, and item completion statuses.\n'
                      '• User Preferences: UI theme preference (Light/Dark) and language preference (English/Hindi).',
                  primaryColor: primaryTextColor,
                  secondaryColor: secondaryTextColor,
                  accentColor: accentColor,
                ),

                _buildPolicySection(
                  number: '3',
                  title: isHindi ? 'हम आपकी जानकारी का उपयोग कैसे करते हैं (How We Use Your Information)' : 'How We Use Your Information',
                  content:
                      'We use the collected information to provide and operate the LawBuddy platform features:\n\n'
                      '• To authenticate your user account session using JSON Web Tokens (JWT).\n'
                      '• To extract clauses and analyze contractual risks against Indian statutory provisions (including RERA, the Indian Contract Act, and the Registration Act).\n'
                      '• To display clause risk classifications, reasons, and recommendations on screen.\n'
                      '• To generate conversational legal responses and contextual explanations in the Legal AI chat.\n'
                      '• To calculate state-specific stamp duty and registration fee estimates.\n'
                      '• To store and maintain your saved document history and transaction due diligence checklists.',
                  primaryColor: primaryTextColor,
                  secondaryColor: secondaryTextColor,
                  accentColor: accentColor,
                ),

                _buildPolicySection(
                  number: '4',
                  title: isHindi ? 'कानूनी दस्तावेज और व्यक्तिगत डेटा (Legal Documents and Personal Data)' : 'Legal Documents and Personal Data',
                  content:
                      'Uploaded property and legal documents frequently contain personal information, including but not limited to:\n\n'
                      '• Names of buyers, sellers, landlords, tenants, witnesses, or representatives\n'
                      '• Property residential, commercial, or municipal addresses\n'
                      '• Survey numbers, plot/khasra numbers, CTS numbers, and registration particulars\n'
                      '• Financial consideration amounts, payment schedules, and stamp duty values\n'
                      '• Aadhaar, PAN, or other identity references where present in the deed text\n'
                      '• Other terms, covenants, and personal information contained within the submitted document.\n\n'
                      'Uploaded documents are processed in their submitted form to perform legal risk analysis. Document records and analysis results are associated with your authenticated account in our database.',
                  primaryColor: primaryTextColor,
                  secondaryColor: secondaryTextColor,
                  accentColor: accentColor,
                ),

                _buildPolicySection(
                  number: '5',
                  title: isHindi ? 'एआई-संचालित प्रसंस्करण (AI-Powered Processing)' : 'AI-Powered Processing & Gemini Disclosure',
                  content:
                      'To provide automated contract review and conversational legal guidance, LawBuddy utilizes generative AI services (Google Gemini API):\n\n'
                      '• Transmission for Processing: When you request AI-powered document analysis or ask questions in the Legal AI assistant, relevant extracted text, segmented clauses, or document images are transmitted to Google\'s Gemini API to process the content and generate risk evaluations, statutory citations, and contextual responses.\n'
                      '• Scope of AI Transmission: This transmission may include the personal and property details contained within the uploaded document or conversation query as needed to evaluate contractual terms.\n'
                      '• Third-Party AI Data Handling: Processing by the Gemini API is subject to Google\'s applicable API terms and privacy policies. LawBuddy does not control or make representations regarding Google\'s internal data retention or server-side logging beyond standard API request handling.\n'
                      '• Vision Fallback: For scanned documents, photographs, or PDFs where on-device text recognition is not utilized, document image data is transmitted to the Gemini API for multimodal vision extraction.',
                  primaryColor: primaryTextColor,
                  secondaryColor: secondaryTextColor,
                  accentColor: accentColor,
                ),

                _buildPolicySection(
                  number: '6',
                  title: isHindi ? 'दस्तावेज़ भंडारण और सुरक्षा (Document Storage and Security)' : 'Document Storage and Security',
                  content:
                      'We implement reasonable technical and organizational measures to safeguard your information:\n\n'
                      '• Authentication & Passwords: User passwords are encrypted using bcrypt hashing before storage. User sessions are verified using JSON Web Tokens (JWT).\n'
                      '• Database Storage: User accounts, document metadata, analysis results, chat sessions, and checklists are stored in a MongoDB database.\n'
                      '• Data Isolation: Backend API routes enforce user authentication and restrict document queries to the authenticated user ID.\n\n'
                      'However, no method of electronic transmission or digital storage is 100% secure. While we strive to protect your data, we cannot guarantee absolute security.',
                  primaryColor: primaryTextColor,
                  secondaryColor: secondaryTextColor,
                  accentColor: accentColor,
                ),

                _buildPolicySection(
                  number: '7',
                  title: isHindi ? 'तृतीय-पक्ष सेवाएं (Third-Party Services)' : 'Third-Party Services & OCR Processing',
                  content:
                      'LawBuddy integrates specific third-party technologies to deliver its features:\n\n'
                      '• Google ML Kit (On-Device OCR): On supported mobile devices (Android/iOS), camera captures of physical documents are processed locally on the device using Google ML Kit to extract raw text before analysis.\n'
                      '• Google Gemini API (Cloud AI): Used for natural language contract analysis, statutory citation matching, conversational assistance, and multimodal vision processing for scanned documents where on-device OCR is not applied.\n'
                      '• MongoDB: For persistent database storage of user accounts, documents, chats, and checklists.\n'
                      '• SMTP Email Service: For sending email verification codes where configured.',
                  primaryColor: primaryTextColor,
                  secondaryColor: secondaryTextColor,
                  accentColor: accentColor,
                ),

                _buildPolicySection(
                  number: '8',
                  title: isHindi ? 'डेटा प्रतिधारण और हटाना (Data Retention & Deletion)' : 'Data Retention & Deletion',
                  content:
                      'We retain your account information, saved document records, chat conversations, and checklists for as long as your account exists in the database.\n\n'
                      '• Document Deletion: You can delete individual document records directly from the Recent Documents section in the app, which removes the document record from the database.\n'
                      '• Chat Deletion: You can clear or delete chat sessions within the chat interface.\n'
                      '• Account Removal: For full account deletion or assistance, please contact the administrator via the contact information below.',
                  primaryColor: primaryTextColor,
                  secondaryColor: secondaryTextColor,
                  accentColor: accentColor,
                ),

                _buildPolicySection(
                  number: '9',
                  title: isHindi ? 'आपके गोपनीयता अधिकार (Your Privacy Rights)' : 'Your Privacy Rights',
                  content:
                      'In accordance with applicable Indian data protection principles, including the Digital Personal Data Protection Act, 2023:\n\n'
                      '• You may review your saved documents, analysis findings, and checklists directly within the application.\n'
                      '• You may delete individual document analyses and chat records at any time.\n'
                      '• You may update your profile name and contact information in your account settings.\n'
                      '• For data inquiries or account deletion requests, you may reach out using the contact details provided in this policy.',
                  primaryColor: primaryTextColor,
                  secondaryColor: secondaryTextColor,
                  accentColor: accentColor,
                ),

                _buildPolicySection(
                  number: '10',
                  title: isHindi ? 'ब्राउज़र संग्रहण और प्राथमिकताएं (Device Storage & Preferences)' : 'Device Storage, Preferences & Cookies',
                  content:
                      'LawBuddy utilizes local storage mechanisms on your device (via SharedPreferences, which maps securely to browser storage on Flutter Web) to ensure essential operation:\n\n'
                      '• Strictly Necessary Session Data: Authentication information is stored locally to maintain your signed-in session and authorize document analysis requests. This data is essential for account security.\n'
                      '• Functional Preferences: Your theme preference (Light or Dark mode) and language selection (English or Hindi) may be retained locally so your interface choices persist between visits.\n'
                      '• No Tracking or Marketing Trackers: LawBuddy currently does not use advertising cookies, marketing pixels, cross-site trackers, or behavioral analytics beacons.\n'
                      '• Privacy & Storage Controls: You can view or adjust your functional storage preference at any time directly within the application.',
                  primaryColor: primaryTextColor,
                  secondaryColor: secondaryTextColor,
                  accentColor: accentColor,
                ),

                // Interactive Manage Storage Preferences Banner
                Container(
                  margin: const EdgeInsets.only(left: 40, bottom: 28),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 18, color: accentColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isHindi ? 'अपनी संग्रहण प्राथमिकताएं अनुकूलित करें' : 'Manage your local storage and cookie preferences',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => showPrivacyPreferencesDialog(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryTextColor,
                          side: BorderSide(color: borderColor),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          isHindi ? 'प्राथमिकताएं प्रबंधित करें' : 'Manage Preferences',
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),

                _buildPolicySection(
                  number: '11',
                  title: isHindi ? "बच्चों की गोपनीयता (Children's Privacy)" : "Children's Privacy",
                  content:
                      'LawBuddy is designed for adult individuals, property buyers, tenants, and property owners managing real estate agreements. We do not intentionally or knowingly collect personal data from individuals under 18 years of age.',
                  primaryColor: primaryTextColor,
                  secondaryColor: secondaryTextColor,
                  accentColor: accentColor,
                ),

                _buildPolicySection(
                  number: '12',
                  title: isHindi ? 'कानूनी अस्वीकरण (Legal Disclaimer)' : 'Legal Disclaimer & Non-Advocate Notice',
                  content:
                      'IMPORTANT NOTICE: LawBuddy provides automated document analysis and legal information for preliminary awareness and informational purposes only. LawBuddy is NOT a law firm and does NOT provide formal legal advice, legal representation, or advocate-client privileged counsel.\n\n'
                      'Property laws, municipal regulations, and stamp duty rates vary across Indian states and may change over time. For formal property conveyance, title searches, litigation, registration, or execution of high-value contracts, users must consult a licensed advocate or qualified legal professional.',
                  primaryColor: primaryTextColor,
                  secondaryColor: secondaryTextColor,
                  accentColor: accentColor,
                ),

                _buildPolicySection(
                  number: '13',
                  title: isHindi ? 'गोपनीयता नीति में परिवर्तन (Changes to This Privacy Policy)' : 'Changes to This Privacy Policy',
                  content:
                      'We may update this Privacy Policy from time to time to reflect changes in our implementation, technology stack, or statutory requirements. When updates occur, the "Last Updated" date at the top of this policy will be revised.',
                  primaryColor: primaryTextColor,
                  secondaryColor: secondaryTextColor,
                  accentColor: accentColor,
                ),

                _buildPolicySection(
                  number: '14',
                  title: isHindi ? 'संपर्क करें (Contact Us)' : 'Contact Us',
                  content:
                      'If you have questions, feedback, or data requests regarding this Privacy Policy, please contact:\n\n'
                      '• Platform: LawBuddy Legal Technology Assistant\n'
                      '• Contact Email: finalyearproject2513@gmail.com\n'
                      '• Project Jurisdiction: India',
                  primaryColor: primaryTextColor,
                  secondaryColor: secondaryTextColor,
                  accentColor: accentColor,
                ),

                const SizedBox(height: 24),
                Divider(color: borderColor),
                const SizedBox(height: 20),

                // Back Action
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: Text(
                      isHindi ? 'वापस जाएं' : 'Back to LawBuddy',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryTextColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPolicySection({
    required String number,
    required String title,
    required String content,
    required Color primaryColor,
    required Color secondaryColor,
    required Color accentColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
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
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Text(
              content,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                height: 1.55,
                color: secondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
