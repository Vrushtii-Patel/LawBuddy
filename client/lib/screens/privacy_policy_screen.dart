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

                // 14 Audited Sections
                _buildPolicySection(
                  number: '1',
                  title: isHindi ? 'परिचय (Introduction)' : 'Introduction',
                  content: isHindi
                      ? 'LawBuddy ("हम", "हमारा" या "हमें") में आपका स्वागत है। LawBuddy एक भारतीय संपत्ति और कानूनी प्रौद्योगिकी सहायक है जिसे उपयोगकर्ताओं को संपत्ति समझौतों का विश्लेषण करने, खंड-स्तरीय जोखिमों को समझने, RERA और वैधानिक उद्धरणों की समीक्षा करने, स्टाम्प शुल्क का अनुमान लगाने और उचित सावधानी (due diligence) चेकलिस्ट को ट्रैक करने में सहायता के लिए डिज़ाइन किया गया है।\n\nयह गोपनीयता नीति बताती है कि कौन सी जानकारी एकत्र की जाती है, इसे कैसे संग्रहीत और संसाधित किया जाता है, AI और OCR प्रौद्योगिकियों का उपयोग कैसे किया जाता है, और आपके पास अपने डेटा पर क्या नियंत्रण हैं।'
                      : 'Welcome to LawBuddy ("we", "our", or "us"). LawBuddy is an Indian property and legal technology assistant designed to assist users in analyzing property agreements, understanding clause-level risks, reviewing RERA and statutory citations, estimating stamp duty, and tracking due diligence checklists.\n\nThis Privacy Policy explains what information is collected, how it is stored and processed, how AI and OCR technologies are utilized, and what controls you have over your data.',
                  primaryColor: primaryTextColor,
                  secondaryColor: secondaryTextColor,
                  accentColor: accentColor,
                ),

                _buildPolicySection(
                  number: '2',
                  title: isHindi ? 'हम कौन सी जानकारी एकत्र करते हैं (Information We Collect)' : 'Information We Collect',
                  content: isHindi
                      ? 'वर्तमान एप्लिकेशन कार्यान्वयन के आधार पर, हम निम्नलिखित जानकारी एकत्र और संग्रहीत करते हैं:\n\n'
                          '• खाता जानकारी (Account Information): आपका पूरा नाम, ईमेल पता, पासवर्ड हैश (bcrypt के माध्यम से एन्क्रिप्टेड), वैकल्पिक फ़ोन नंबर, प्रोफ़ाइल अवतार संदर्भ, और खाता टाइमस्टैम्प (निर्माण, अंतिम लॉगिन)।\n'
                          '• दस्तावेज़ और अनुबंध डेटा (Document & Contract Data): फ़ाइल अपलोड, कैमरा फ़ोटो या सीधे टेक्स्ट इनपुट के माध्यम से अपलोड किए गए संपत्ति अनुबंध, बिक्री विलेख (sale deeds), लीज समझौते और टेक्स्ट स्निपेट।\n'
                          '• फ़ाइल डेटा और हैश (File Data & Hash): फ़ाइल नाम, दस्तावेज़ आकार, गणना किए गए SHA-256 hashes, और दस्तावेज़ अपलोड होने पर base64-encoded फ़ाइल/छवि डेटा।\n'
                          '• निकाला गया पाठ और विभाजन (Extracted Text & Segmentation): दस्तावेज़ों से निकाला गया पाठ (डिजिटल पार्सिंग, OCR या विज़न निष्कर्षण के माध्यम से), सामान्यीकृत पाठ और खंडित कानूनी खंड (clauses)।\n'
                          '• विश्लेषण परिणाम (Analysis Results): खंड जोखिम वर्गीकरण (High Risk, Caution, Compliant), कानूनी निष्कर्ष, वैधानिक उद्धरण (उदा. RERA, Transfer of Property Act), खरीदार प्रभाव स्पष्टीकरण और सिफारिशें।\n'
                          '• चैट और परामर्श इतिहास (Chat & Consultation History): AI चैट सहायक के भीतर प्रस्तुत उपयोगकर्ता प्रश्न, पूछताछ और AI-उत्पन्न प्रतिक्रियाएं।\n'
                          '• उचित सावधानी चेकलिस्ट डेटा (Due Diligence Checklist Data): सहेजे गए चेकलिस्ट प्रकार (उदा. पुनर्विक्रय खरीद, बिल्डर खरीद), कस्टम चेकलिस्ट आइटम और आइटम पूर्णता स्थितियां।\n'
                          '• उपयोगकर्ता प्राथमिकताएं (User Preferences): UI थीम प्राथमिकता (Light/Dark) और भाषा प्राथमिकता (English/Hindi)।'
                      : 'Based on the current application implementation, we collect and store the following information:\n\n'
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
                  content: isHindi
                      ? 'हम LawBuddy प्लेटफ़ॉर्म सुविधाओं को प्रदान करने और संचालित करने के लिए एकत्र की गई जानकारी का उपयोग करते हैं:\n\n'
                          '• JSON Web Tokens (JWT) का उपयोग करके आपके उपयोगकर्ता खाता सत्र को प्रमाणित करने के लिए।\n'
                          '• भारतीय वैधानिक प्रावधानों (RERA, Indian Contract Act और Registration Act सहित) के विरुद्ध खंडों को निकालने और संविदात्मक जोखिमों का विश्लेषण करने के लिए।\n'
                          '• स्क्रीन पर खंड जोखिम वर्गीकरण, कारण और सिफारिशें प्रदर्शित करने के लिए।\n'
                          '• Legal AI चैट में संवादात्मक कानूनी प्रतिक्रियाएं और प्रासंगिक स्पष्टीकरण उत्पन्न करने के लिए।\n'
                          '• राज्य-विशिष्ट स्टाम्प शुल्क और पंजीकरण शुल्क अनुमानों की गणना करने के लिए।\n'
                          '• आपके सहेजे गए दस्तावेज़ इतिहास और लेनदेन उचित सावधानी (due diligence) चेकलिस्ट को संग्रहीत और बनाए रखने के लिए।'
                      : 'We use the collected information to provide and operate the LawBuddy platform features:\n\n'
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
                  content: isHindi
                      ? 'अपलोड किए गए संपत्ति और कानूनी दस्तावेज़ों में अक्सर व्यक्तिगत जानकारी होती है, जिसमें शामिल हैं लेकिन इन्हीं तक सीमित नहीं हैं:\n\n'
                          '• खरीदारों, विक्रेताओं, मकान मालिकों, किरायेदारों, गवाहों या प्रतिनिधियों के नाम\n'
                          '• संपत्ति के आवासीय, वाणिज्यिक या नगरपालिका पते\n'
                          '• सर्वेक्षण संख्या (Survey numbers), प्लॉट/खसरा संख्या, CTS संख्या और पंजीकरण विवरण\n'
                          '• वित्तीय प्रतिफल राशि (Financial consideration amounts), भुगतान अनुसूचियां और स्टाम्प शुल्क मूल्य\n'
                          '• आधार, पैन या अन्य पहचान संदर्भ जहाँ विलेख पाठ में मौजूद हों\n'
                          '• प्रस्तुत दस्तावेज़ में निहित अन्य शर्तें, अनुबंध और व्यक्तिगत जानकारी।\n\n'
                          'अपलोड किए गए दस्तावेज़ों को कानूनी जोखिम विश्लेषण करने के लिए उनके प्रस्तुत रूप में संसाधित किया जाता है। दस्तावेज़ रिकॉर्ड और विश्लेषण परिणाम हमारे डेटाबेस में आपके प्रमाणित खाते से जुड़े होते हैं।'
                      : 'Uploaded property and legal documents frequently contain personal information, including but not limited to:\n\n'
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
                  content: isHindi
                      ? 'स्वचालित अनुबंध समीक्षा और संवादात्मक कानूनी मार्गदर्शन प्रदान करने के लिए, LawBuddy जनरेटिव AI सेवाओं (Google Gemini API) का उपयोग करता है:\n\n'
                          '• प्रसंस्करण के लिए ट्रांसमिशन (Transmission for Processing): जब आप AI-संचालित दस्तावेज़ विश्लेषण का अनुरोध करते हैं या Legal AI सहायक में प्रश्न पूछते हैं, तो सामग्री को संसाधित करने और जोखिम मूल्यांकन, वैधानिक उद्धरण और प्रासंगिक प्रतिक्रियाएं उत्पन्न करने के लिए प्रासंगिक निकाला गया पाठ, खंडित खंड या दस्तावेज़ चित्र Google के Gemini API को प्रेषित किए जाते हैं।\n'
                          '• AI ट्रांसमिशन का दायरा (Scope of AI Transmission): इस ट्रांसमिशन में संविदात्मक शर्तों का मूल्यांकन करने के लिए आवश्यक रूप से अपलोड किए गए दस्तावेज़ या बातचीत क्वेरी में निहित व्यक्तिगत और संपत्ति विवरण शामिल हो सकते हैं।\n'
                          '• तृतीय-पक्ष AI डेटा हैंडलिंग (Third-Party AI Data Handling): Gemini API द्वारा प्रसंस्करण Google की लागू API शर्तों और गोपनीयता नीतियों के अधीन है। LawBuddy मानक API अनुरोध हैंडलिंग से परे Google के आंतरिक डेटा प्रतिधारण या सर्वर-साइड लॉगिंग के संबंध में नियंत्रण या प्रतिनिधित्व नहीं करता है।\n'
                          '• विज़न फ़ॉलबैक (Vision Fallback): स्कैन किए गए दस्तावेज़ों, तस्वीरों या पीडीएफ के लिए जहाँ ऑन-डिवाइस टेक्स्ट पहचान का उपयोग नहीं किया जाता है, मल्टीमॉडल विज़न निष्कर्षण के लिए दस्तावेज़ छवि डेटा Gemini API को प्रेषित किया जाता है।'
                      : 'To provide automated contract review and conversational legal guidance, LawBuddy utilizes generative AI services (Google Gemini API):\n\n'
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
                  content: isHindi
                      ? 'हम आपकी जानकारी की सुरक्षा के लिए उचित तकनीकी और संगठनात्मक उपाय लागू करते हैं:\n\n'
                          '• प्रमाणीकरण और पासवर्ड (Authentication & Passwords): उपयोगकर्ता पासवर्ड भंडारण से पहले bcrypt हैशिंग का उपयोग करके एन्क्रिप्ट किए जाते हैं। उपयोगकर्ता सत्रों को JSON Web Tokens (JWT) का उपयोग करके सत्यापित किया जाता है।\n'
                          '• डेटाबेस भंडारण (Database Storage): उपयोगकर्ता खाते, दस्तावेज़ मेटाडेटा, विश्लेषण परिणाम, चैट सत्र और चेकलिस्ट एक MongoDB डेटाबेस में संग्रहीत किए जाते हैं।\n'
                          '• डेटा पृथक्करण (Data Isolation): बैकएंड API मार्ग उपयोगकर्ता प्रमाणीकरण लागू करते हैं और दस्तावेज़ प्रश्नों को प्रमाणित उपयोगकर्ता आईडी तक सीमित करते हैं।\n\n'
                          'हालाँकि, इलेक्ट्रॉनिक ट्रांसमिशन या डिजिटल स्टोरेज का कोई भी तरीका 100% सुरक्षित नहीं है। यद्यपि हम आपके डेटा की सुरक्षा का प्रयास करते हैं, हम पूर्ण सुरक्षा की गारंटी नहीं दे सकते।'
                      : 'We implement reasonable technical and organizational measures to safeguard your information:\n\n'
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
                  content: isHindi
                      ? 'LawBuddy अपनी सुविधाएं प्रदान करने के लिए विशिष्ट तृतीय-पक्ष प्रौद्योगिकियों को एकीकृत करता है:\n\n'
                          '• Google ML Kit (On-Device OCR): समर्थित मोबाइल उपकरणों (Android/iOS) पर, विश्लेषण से पहले कच्चा पाठ निकालने के लिए Google ML Kit का उपयोग करके भौतिक दस्तावेज़ों के कैमरा कैप्चर को डिवाइस पर स्थानीय रूप से संसाधित किया जाता है।\n'
                          '• Google Gemini API (Cloud AI): प्राकृतिक भाषा अनुबंध विश्लेषण, वैधानिक उद्धरण मिलान, संवादात्मक सहायता और स्कैन किए गए दस्तावेज़ों के लिए मल्टीमॉडल विज़न प्रसंस्करण के लिए उपयोग किया जाता है जहाँ ऑन-डिवाइस OCR लागू नहीं होता है।\n'
                          '• MongoDB: उपयोगकर्ता खातों, दस्तावेज़ों, चैट और चेकलिस्ट के स्थायी डेटाबेस भंडारण के लिए।\n'
                          '• SMTP Email Service: जहाँ कॉन्फ़िगर किया गया हो, ईमेल सत्यापन कोड भेजने के लिए।'
                      : 'LawBuddy integrates specific third-party technologies to deliver its features:\n\n'
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
                  content: isHindi
                      ? 'हम आपकी खाता जानकारी, सहेजे गए दस्तावेज़ रिकॉर्ड, चैट बातचीत और चेकलिस्ट को तब तक बनाए रखते हैं जब तक आपका खाता डेटाबेस में मौजूद है।\n\n'
                          '• दस्तावेज़ हटाना (Document Deletion): आप ऐप में Recent Documents अनुभाग से सीधे अलग-अलग दस्तावेज़ रिकॉर्ड हटा सकते हैं, जो डेटाबेस से दस्तावेज़ रिकॉर्ड को हटा देता है।\n'
                          '• चैट हटाना (Chat Deletion): आप चैट इंटरफ़ेस के भीतर चैट सत्रों को साफ़ या हटा सकते हैं।\n'
                          '• खाता निष्कासन (Account Removal): पूर्ण खाता हटाने या सहायता के लिए, कृपया नीचे दी गई संपर्क जानकारी के माध्यम से व्यवस्थापक से संपर्क करें।'
                      : 'We retain your account information, saved document records, chat conversations, and checklists for as long as your account exists in the database.\n\n'
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
                  content: isHindi
                      ? 'Digital Personal Data Protection Act, 2023 सहित लागू भारतीय डेटा सुरक्षा सिद्धांतों के अनुसार:\n\n'
                          '• आप सीधे एप्लिकेशन के भीतर अपने सहेजे गए दस्तावेज़ों, विश्लेषण निष्कर्षों और चेकलिस्ट की समीक्षा कर सकते हैं।\n'
                          '• आप किसी भी समय अलग-अलग दस्तावेज़ विश्लेषण और चैट रिकॉर्ड हटा सकते हैं।\n'
                          '• आप अपनी खाता सेटिंग्स में अपना प्रोफ़ाइल नाम और संपर्क जानकारी अपडेट कर सकते हैं।\n'
                          '• डेटा पूछताछ या खाता हटाने के अनुरोधों के लिए, आप इस नीति में प्रदान किए गए संपर्क विवरण का उपयोग करके संपर्क कर सकते हैं।'
                      : 'In accordance with applicable Indian data protection principles, including the Digital Personal Data Protection Act, 2023:\n\n'
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
                  title: isHindi ? 'डिवाइस संग्रहण और प्राथमिकताएं (Device Storage & Preferences)' : 'Device Storage, Preferences & Cookies',
                  content: isHindi
                      ? 'LawBuddy आवश्यक संचालन सुनिश्चित करने के लिए आपके डिवाइस पर स्थानीय भंडारण तंत्र (SharedPreferences के माध्यम से, जो Flutter Web पर ब्राउज़र स्टोरेज में सुरक्षित रूप से मैप होता है) का उपयोग करता है:\n\n'
                          '• कड़ाई से आवश्यक सत्र डेटा (Strictly Necessary Session Data): आपके साइन-इन सत्र को बनाए रखने और दस्तावेज़ विश्लेषण अनुरोधों को अधिकृत करने के लिए प्रमाणीकरण जानकारी स्थानीय रूप से संग्रहीत की जाती है। यह डेटा खाता सुरक्षा के लिए आवश्यक है।\n'
                          '• कार्यात्मक प्राथमिकताएं (Functional Preferences): आपकी थीम प्राथमिकता (Light या Dark मोड) और भाषा चयन (English या Hindi) स्थानीय रूप से बनाए रखा जा सकता है ताकि आपके इंटरफ़ेस विकल्प विज़िट के बीच बने रहें।\n'
                          '• कोई ट्रैकिंग या मार्केटिंग ट्रैकर्स नहीं (No Tracking or Marketing Trackers): LawBuddy वर्तमान में विज्ञापन कुकीज़, मार्केटिंग पिक्सेल, क्रॉस-साइट ट्रैकर्स या व्यवहार विश्लेषण बीकन का उपयोग नहीं करता है।\n'
                          '• गोपनीयता और संग्रहण नियंत्रण (Privacy & Storage Controls): आप सीधे एप्लिकेशन के भीतर किसी भी समय अपनी कार्यात्मक भंडारण प्राथमिकता देख या समायोजित कर सकते हैं।'
                      : 'LawBuddy utilizes local storage mechanisms on your device (via SharedPreferences, which maps securely to browser storage on Flutter Web) to ensure essential operation:\n\n'
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
                          isHindi ? 'अपनी स्थानीय संग्रहण और कुकी प्राथमिकताएं प्रबंधित करें' : 'Manage your local storage and cookie preferences',
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
                  content: isHindi
                      ? 'LawBuddy वयस्क व्यक्तियों, संपत्ति खरीदारों, किरायेदारों और रियल एस्टेट समझौतों का प्रबंधन करने वाले संपत्ति मालिकों के लिए डिज़ाइन किया गया है। हम जानबूझकर 18 वर्ष से कम आयु के व्यक्तियों से व्यक्तिगत डेटा एकत्र नहीं करते हैं।'
                      : 'LawBuddy is designed for adult individuals, property buyers, tenants, and property owners managing real estate agreements. We do not intentionally or knowingly collect personal data from individuals under 18 years of age.',
                  primaryColor: primaryTextColor,
                  secondaryColor: secondaryTextColor,
                  accentColor: accentColor,
                ),

                _buildPolicySection(
                  number: '12',
                  title: isHindi ? 'कानूनी अस्वीकरण (Legal Disclaimer)' : 'Legal Disclaimer & Non-Advocate Notice',
                  content: isHindi
                      ? 'महत्वपूर्ण सूचना: LawBuddy केवल प्रारंभिक जागरूकता और सूचनात्मक उद्देश्यों के लिए स्वचालित दस्तावेज़ विश्लेषण और कानूनी जानकारी प्रदान करता है। LawBuddy कोई कानूनी फर्म (law firm) नहीं है और औपचारिक कानूनी सलाह, कानूनी प्रतिनिधित्व या अधिवक्ता-ग्राहक विशेषाधिकार प्राप्त परामर्श (advocate-client privileged counsel) प्रदान नहीं करता है।\n\n'
                          'संपत्ति कानून, नगरपालिका नियम और स्टाम्प शुल्क दरें भारतीय राज्यों में भिन्न होती हैं और समय के साथ बदल सकती हैं। औपचारिक संपत्ति हस्तांतरण (property conveyance), शीर्षक खोज (title searches), मुकदमेबाजी, पंजीकरण या उच्च-मूल्य वाले अनुबंधों के निष्पादन के लिए, उपयोगकर्ताओं को एक लाइसेंस प्राप्त अधिवक्ता या योग्य कानूनी पेशेवर से परामर्श करना चाहिए।'
                      : 'IMPORTANT NOTICE: LawBuddy provides automated document analysis and legal information for preliminary awareness and informational purposes only. LawBuddy is NOT a law firm and does NOT provide formal legal advice, legal representation, or advocate-client privileged counsel.\n\n'
                          'Property laws, municipal regulations, and stamp duty rates vary across Indian states and may change over time. For formal property conveyance, title searches, litigation, registration, or execution of high-value contracts, users must consult a licensed advocate or qualified legal professional.',
                  primaryColor: primaryTextColor,
                  secondaryColor: secondaryTextColor,
                  accentColor: accentColor,
                ),

                _buildPolicySection(
                  number: '13',
                  title: isHindi ? 'गोपनीयता नीति में परिवर्तन (Changes to This Privacy Policy)' : 'Changes to This Privacy Policy',
                  content: isHindi
                      ? 'हम अपने कार्यान्वयन, प्रौद्योगिकी स्टैक या वैधानिक आवश्यकताओं में परिवर्तनों को दर्शाने के लिए समय-समय पर इस गोपनीयता नीति को अपडेट कर सकते हैं। जब अपडेट होते हैं, तो इस नीति के शीर्ष पर "अंतिम अद्यतन" (Last Updated) तिथि को संशोधित किया जाएगा।'
                      : 'We may update this Privacy Policy from time to time to reflect changes in our implementation, technology stack, or statutory requirements. When updates occur, the "Last Updated" date at the top of this policy will be revised.',
                  primaryColor: primaryTextColor,
                  secondaryColor: secondaryTextColor,
                  accentColor: accentColor,
                ),

                _buildPolicySection(
                  number: '14',
                  title: isHindi ? 'संपर्क करें (Contact Us)' : 'Contact Us',
                  content: isHindi
                      ? 'यदि आपके पास इस गोपनीयता नीति के संबंध में कोई प्रश्न, प्रतिक्रिया या डेटा अनुरोध हैं, तो कृपया संपर्क करें:\n\n'
                          '• प्लेटफ़ॉर्म: LawBuddy Legal Technology Assistant\n'
                          '• संपर्क ईमेल: finalyearproject2513@gmail.com\n'
                          '• परियोजना क्षेत्राधिकार: भारत (India)'
                      : 'If you have questions, feedback, or data requests regarding this Privacy Policy, please contact:\n\n'
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
