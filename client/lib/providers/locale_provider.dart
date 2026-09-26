import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  english('en', 'English', 'English'),
  hindi('hi', 'Hindi', 'हिंदी');

  final String code;
  final String englishName;
  final String nativeName;

  const AppLanguage(this.code, this.englishName, this.nativeName);
}

final localeProvider = StateNotifierProvider<LocaleNotifier, AppLanguage>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<AppLanguage> {
  static const _langPrefKey = 'app_language_preference';

  LocaleNotifier() : super(AppLanguage.english) {
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final functionalAllowed = prefs.getBool('storage_consent_functional');
    if (functionalAllowed == true) {
      final code = prefs.getString(_langPrefKey);
      if (code != null) {
        final matched = AppLanguage.values.firstWhere(
          (l) => l.code == code,
          orElse: () => AppLanguage.english,
        );
        state = matched;
      }
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    final prefs = await SharedPreferences.getInstance();
    final functionalAllowed = prefs.getBool('storage_consent_functional');
    if (functionalAllowed == true) {
      await prefs.setString(_langPrefKey, language.code);
    }
  }

  String translate(String key, [Map<String, String>? params]) {
    final langCode = state.code;
    String raw = key;

    if (_translations.containsKey(key) && _translations[key]!.containsKey(langCode)) {
      raw = _translations[key]![langCode]!;
    } else if (_translations.containsKey(key) && _translations[key]!.containsKey('en')) {
      raw = _translations[key]!['en']!;
    }

    if (params != null && params.isNotEmpty) {
      params.forEach((paramKey, paramVal) {
        raw = raw.replaceAll('{$paramKey}', paramVal);
      });
    }

    return raw;
  }
}

extension TranslationExtension on BuildContext {
  String tr(String key, WidgetRef ref, [Map<String, String>? params]) {
    ref.watch(localeProvider);
    return ref.read(localeProvider.notifier).translate(key, params);
  }
}

// Master Namespaced Translation Dictionary
// 'en' is 100% the verbatim source of truth from existing code.
// 'hi' is accurate and natural Hindi translation.
final Map<String, Map<String, String>> _translations = {
  // Common Actions
  'common.appName': {'en': 'LawBuddy', 'hi': 'LawBuddy'},
  'common.appSubtitle': {'en': 'AI Property Legal Assistant', 'hi': 'एआई संपत्ति कानूनी सहायक'},
  'common.cancel': {'en': 'Cancel', 'hi': 'रद्द करें'},
  'common.delete': {'en': 'Delete', 'hi': 'हटाएं'},
  'common.retry': {'en': 'Retry', 'hi': 'पुनः प्रयास करें'},
  'common.close': {'en': 'Close', 'hi': 'बंद करें'},
  'common.save': {'en': 'Save', 'hi': 'सहेजें'},
  'common.add': {'en': 'Add', 'hi': 'जोड़ें'},
  'common.or': {'en': 'OR', 'hi': 'या'},
  'common.understood': {'en': 'Understood', 'hi': 'समझ गया'},
  'common.gotIt': {'en': 'Got it', 'hi': 'समझ गया'},
  'common.viewDetails': {'en': 'View Details', 'hi': 'विवरण देखें'},
  'common.explore': {'en': 'Explore →', 'hi': 'देखें →'},
  'common.live': {'en': 'Live', 'hi': 'लाइव'},
  'common.back': {'en': 'Back', 'hi': 'पीछे'},
  'common.backToHome': {'en': 'Back to Home', 'hi': 'होम पर वापस जाएं'},
  'common.settings': {'en': 'Settings', 'hi': 'सेटिंग्स'},
  'common.language': {'en': 'Language', 'hi': 'भाषा'},
  'common.english': {'en': 'English', 'hi': 'English'},
  'common.hindi': {'en': 'हिंदी', 'hi': 'हिंदी'},
  'common.theme': {'en': 'Theme', 'hi': 'थीम'},
  'common.appearance': {'en': 'Theme', 'hi': 'थीम'},
  'common.themeAppearance': {'en': 'Theme & Appearance', 'hi': 'थीम और स्वरूप'},
  'common.chooseAppearance': {'en': 'Choose how LawBuddy looks', 'hi': 'चुनें कि LawBuddy कैसा दिखे'},
  'common.light': {'en': 'Light', 'hi': 'लाइट'},
  'common.dark': {'en': 'Dark', 'hi': 'डार्क'},
  'common.system': {'en': 'System', 'hi': 'सिस्टम'},
  'common.profile': {'en': 'Profile', 'hi': 'प्रोफाइल'},
  'common.accountDetails': {'en': 'Account Details', 'hi': 'खाता विवरण'},
  'common.fullName': {'en': 'Full Name', 'hi': 'पूरा नाम'},
  'common.emailAddress': {'en': 'Email Address', 'hi': 'ईमेल पता'},
  'common.yes': {'en': 'Yes', 'hi': 'हाँ'},
  'common.no': {'en': 'No', 'hi': 'नहीं'},
  'common.signOut': {'en': 'Sign Out', 'hi': 'साइन आउट'},
  'common.signOutConfirm': {
    'en': 'Are you sure you want to sign out of your LawBuddy session?',
    'hi': 'क्या आप अपने LawBuddy सत्र से साइन आउट करना चाहते हैं?',
  },

  // Navigation & Branding
  'brand.name': {'en': 'LawBuddy', 'hi': 'LawBuddy'},
  'brand.tagline': {'en': 'LEGALTECH AI', 'hi': 'लीगलटेक एआई'},
  'brand.subtitle': {'en': 'AI Property Legal Assistant', 'hi': 'एआई संपत्ति कानूनी सहायक'},

  // Home Screen
  'home.goodMorning': {'en': 'Good Morning', 'hi': 'शुभ प्रभात'},
  'home.goodAfternoon': {'en': 'Good Afternoon', 'hi': 'शुभ दोपहर'},
  'home.goodEvening': {'en': 'Good Evening', 'hi': 'शुभ संध्या'},
  'home.greeting': {'en': '{greeting}, {name} 👋', 'hi': '{greeting}, {name} 👋'},
  'home.quickActions': {'en': 'Quick Actions', 'hi': 'त्वरित कार्य'},
  'home.quickActionsSubtitle': {
    'en': 'Select a tool to manage your property legal workflow',
    'hi': 'अपने संपत्ति कानूनी कार्यप्रवाह को प्रबंधित करने के लिए एक उपकरण चुनें',
  },
  'home.scanAgreement': {'en': 'Scan Agreement', 'hi': 'समझौता स्कैन करें'},
  'home.scanAgreementDesc': {'en': 'Analyze documents for legal risk', 'hi': 'कानूनी जोखिम के लिए दस्तावेजों का विश्लेषण करें'},
  'home.legalChatbot': {'en': 'Legal Chatbot', 'hi': 'कानूनी चैटबॉट'},
  'home.legalChatbotDesc': {'en': 'Ask property & RERA questions', 'hi': 'संपत्ति और रेरा पर प्रश्न पूछें'},
  'home.propertyChecklist': {'en': 'Property Checklist', 'hi': 'संपत्ति चेकलिस्ट'},
  'home.stampDutyCalculator': {'en': 'Stamp Duty Calculator', 'hi': 'स्टाम्प शुल्क कैलकुलेटर'},
  'home.stampDutyCalculatorDesc': {'en': 'Calculate stamp duty & registration charges', 'hi': 'स्टाम्प शुल्क और पंजीकरण शुल्क की गणना करें'},
  'home.activeChecklistsZero': {'en': '0 Active Checklists', 'hi': '0 सक्रिय चेकलिस्ट'},
  'home.activeChecklistsBadge': {'en': '{count} Active {unit}', 'hi': '{count} सक्रिय {unit}'},
  'home.checklistUnitSingular': {'en': 'Checklist', 'hi': 'चेकलिस्ट'},
  'home.checklistUnitPlural': {'en': 'Checklists', 'hi': 'चेकलिस्ट'},
  'home.checklistZeroTasks': {'en': '0 tasks • Tap to generate property guides', 'hi': '0 कार्य • संपत्ति गाइड बनाने के लिए टैप करें'},
  'home.checklistZeroCompleted': {'en': '0 tasks completed • Tap to view guides', 'hi': '0 कार्य पूर्ण • गाइड देखने के लिए टैप करें'},
  'home.checklistTasksProgress': {
    'en': '{completed} of {total} tasks done',
    'hi': '{completed} में से {total} कार्य पूरे हुए',
  },
  'home.guideUnitSingular': {'en': 'guide', 'hi': 'गाइड'},
  'home.guideUnitPlural': {'en': 'guides', 'hi': 'गाइड'},
  'home.recentDocuments': {'en': 'Recent Documents', 'hi': 'हाल के दस्तावेज़'},
  'home.viewAll': {'en': 'View All ({count})', 'hi': 'सभी देखें ({count})'},
  'home.noAgreementsScanned': {'en': 'No agreements scanned yet', 'hi': 'अभी तक कोई समझौता स्कैन नहीं किया गया है'},
  'home.uploadOrScanAgreement': {
    'en': 'Upload or scan your property agreement for AI risk assessment.',
    'hi': 'एआई जोखिम मूल्यांकन के लिए अपने संपत्ति समझौते को अपलोड या स्कैन करें।',
  },
  'home.scanOrUploadAgreementBtn': {'en': 'Scan or Upload Agreement', 'hi': 'समझौता स्कैन या अपलोड करें'},
  'home.latestLegalUpdates': {'en': 'Latest Legal Updates', 'hi': 'नवीनतम कानूनी अपडेट'},
  'home.noLegalUpdates': {'en': 'No legal updates available at this moment', 'hi': 'इस समय कोई कानूनी अपडेट उपलब्ध नहीं है'},
  'home.reraAlert': {'en': 'RERA ALERT', 'hi': 'रेरा अलर्ट'},
  'home.reraAdvisoryDetails': {'en': 'RERA Advisory Details', 'hi': 'रेरा सलाह विवरण'},
  'home.reraStatutoryNote': {
    'en': 'Under Section 18 of the RERA Act, promoter default in handover or escrow accounting mandates strict statutory interest compensation at SBI MCLR + 2%.',
    'hi': 'रेरा अधिनियम की धारा 18 के तहत, हैंडओवर या एस्क्रो अकाउंटिंग में प्रमोटर डिफॉल्ट होने पर SBI MCLR + 2% पर वैधानिक ब्याज मुआवजा अनिवार्य है।',
  },
  'home.askLegalAi': {'en': 'Ask Legal AI', 'hi': 'कानूनी एआई से पूछें'},
  'home.needLegalHelp': {'en': 'Need Legal Help? Ask LawBuddy', 'hi': 'कानूनी मदद चाहिए? LawBuddy से पूछें'},
  'home.overviewTitle': {'en': 'LEGAL PORTFOLIO OVERVIEW', 'hi': 'कानूनी पोर्टफोलियो अवलोकन'},
  'home.totalScannedDocs': {'en': 'Documents Analyzed', 'hi': 'विश्लेषण किए गए दस्तावेज़'},
  'home.totalScannedDocsSub': {'en': 'Agreements in workspace', 'hi': 'कार्यक्षेत्र में समझौते'},
  'home.highRiskCount': {'en': 'Risk Flags Identified', 'hi': 'पहचाने गए जोखिम'},
  'home.highRiskCountSub': {'en': 'Agreements requiring review', 'hi': 'समीक्षा आवश्यक समझौते'},
  'home.noHighRisks': {'en': 'No critical risk flags', 'hi': 'कोई गंभीर जोखिम नहीं'},
  'home.dueDiligenceProgress': {'en': 'Due Diligence Tasks', 'hi': 'जांच कार्य प्रगति'},
  'home.activeChecklists': {'en': 'Active Checklists', 'hi': 'सक्रिय चेकलिस्ट'},
  'home.systemOnline': {'en': 'Legal Engine Online', 'hi': 'कानूनी इंजन सक्रिय'},
  'home.primaryScanSpotlight': {'en': 'INSTANT AI ASSESSMENT', 'hi': 'त्वरित एआई मूल्यांकन'},
  'home.heroTag': {
    'en': 'YOUR PROPERTY • YOUR RIGHTS • YOUR CONFIDENCE',
    'hi': 'आपकी संपत्ति • आपके अधिकार • आपका विश्वास',
  },
  'home.heroSub': {
    'en': 'Review your agreements, check RERA risks, and make informed property decisions with AI built for Indian real estate.',
    'hi': 'अपने समझौतों की समीक्षा करें, रेरा जोखिमों की जांच करें और भारतीय रियल एस्टेट के लिए बने एआई के साथ सूचित निर्णय लें।',
  },
  'home.scanNewDocument': {'en': 'Scan Document', 'hi': 'दस्तावेज़ स्कैन करें'},
  'home.allTasksDone': {'en': 'All due diligence verification tasks completed', 'hi': 'सभी उचित सावधानी सत्यापन कार्य पूर्ण हो गए'},
  'home.noActiveChecklists': {'en': 'No active transaction checklists', 'hi': 'कोई सक्रिय लेनदेन चेकलिस्ट नहीं है'},
  'home.defaultChecklistTitle': {'en': 'Property Purchase Diligence', 'hi': 'संपत्ति खरीद उचित सावधानी'},
  'home.defaultTaskTitle': {'en': 'Title search & Encumbrance check', 'hi': 'टाइटल खोज और भार जांच'},
  'home.clausesEvaluated': {
    'en': '{count} clauses evaluated across tenancy & title compliance',
    'hi': 'किराया और शीर्षक अनुपालन में {count} खंडों का मूल्यांकन किया गया',
  },
  'home.assessmentComplete': {
    'en': 'AI clause extraction and legal risk assessment complete',
    'hi': 'एआई खंड निष्कर्षण और कानूनी जोखिम मूल्यांकन पूर्ण',
  },
  'home.workspaceSubtitle': {'en': 'Your property legal workspace', 'hi': 'आपका संपत्ति कानूनी कार्यक्षेत्र'},
  'home.latestAnalysisReview': {'en': 'Latest Document Analysis', 'hi': 'नवीनतम दस्तावेज़ विश्लेषण'},
  'home.latestAnalysisSub': {'en': 'Real-time risk assessment & clause audit', 'hi': 'वास्तविक समय जोखिम मूल्यांकन और खंड ऑडिट'},
  'home.viewFullAnalysis': {'en': 'View Full Analysis', 'hi': 'पूर्ण विश्लेषण देखें'},
  'home.riskDistribution': {'en': 'Legal Risk Breakdown', 'hi': 'कानूनी जोखिम विवरण'},
  'home.riskDistributionSub': {'en': 'Clause severity across analyzed agreements', 'hi': 'विश्लेषण किए गए समझौतों में खंड गंभीरता'},
  'home.highRiskLabel': {'en': 'High Risk', 'hi': 'उच्च जोखिम'},
  'home.mediumRiskLabel': {'en': 'Caution', 'hi': 'सावधानी'},
  'home.lowRiskLabel': {'en': 'Compliant', 'hi': 'अनुपालन'},
  'home.dueDiligenceSection': {'en': 'Due Diligence Checklist', 'hi': 'उचित तत्परता चेकलिस्ट'},
  'home.dueDiligenceSub': {'en': 'Mandatory property transaction verification', 'hi': 'अनिवार्य संपत्ति लेनदेन सत्यापन'},
  'home.openChecklist': {'en': 'Open Checklist', 'hi': 'चेकलिस्ट खोलें'},
  'home.recentActivity': {'en': 'Recent Workspace Activity', 'hi': 'हालिया कार्यक्षेत्र गतिविधि'},
  'home.recentActivitySub': {'en': 'Audit trail of scans and verification progress', 'hi': 'स्कैन और सत्यापन प्रगति का ऑडिट ट्रेल'},
  'home.noActivityYet': {'en': 'No recent activity recorded yet', 'hi': 'अभी तक कोई हालिया गतिविधि दर्ज नहीं की गई है'},
  'home.legalIntelligence': {'en': 'Legal Intelligence & News', 'hi': 'कानूनी जानकारी और समाचार'},
  'home.legalIntelligenceSub': {'en': 'Real estate statutory alerts & circulars', 'hi': 'अचल संपत्ति वैधानिक अलर्ट और परिपत्र'},
  'home.reraAwarenessTitle': {'en': 'RERA Statutory Notice', 'hi': 'रेरा वैधानिक सूचना'},
  'home.reraAwarenessSub': {'en': 'Mandatory statutory protections under RERA', 'hi': 'रेरा के तहत अनिवार्य वैधानिक सुरक्षा'},

  // Sidebar Navigation Categories & Items
  'sidebar.overview': {'en': 'OVERVIEW', 'hi': 'अवलोकन'},
  'sidebar.workspace': {'en': 'WORKSPACE', 'hi': 'कार्यक्षेत्र'},
  'sidebar.legalTools': {'en': 'LEGAL TOOLS', 'hi': 'कानूनी उपकरण'},
  'sidebar.legalInfo': {'en': 'LEGAL INFORMATION', 'hi': 'कानूनी जानकारी'},
  'sidebar.main': {'en': 'MAIN', 'hi': 'मुख्य'},
  'sidebar.dashboard': {'en': 'Dashboard', 'hi': 'डैशबोर्ड'},
  'sidebar.documents': {'en': 'Documents', 'hi': 'दस्तावेज़'},
  'sidebar.riskAnalysis': {'en': 'Risk Analysis', 'hi': 'जोखिम विश्लेषण'},
  'sidebar.checklists': {'en': 'Checklists', 'hi': 'चेकलिस्ट'},
  'sidebar.reraCompliance': {'en': 'RERA & Compliance', 'hi': 'रेरा और अनुपालन'},
  'sidebar.documentComparison': {'en': 'Document Comparison', 'hi': 'दस्तावेज़ तुलना'},
  'sidebar.legalAi': {'en': 'Legal AI', 'hi': 'कानूनी एआई'},
  'sidebar.stampDuty': {'en': 'Stamp Duty Calculator', 'hi': 'स्टाम्प शुल्क कैलकुलेटर'},
  'sidebar.administration': {'en': 'ADMINISTRATION', 'hi': 'प्रशासन'},
  'sidebar.adminAnalytics': {'en': 'Admin Analytics', 'hi': 'व्यवस्थापक एनालिटिक्स'},
  'sidebar.settings': {'en': 'Settings', 'hi': 'सेटिंग्स'},
  'sidebar.profile': {'en': 'Profile', 'hi': 'प्रोफ़ाइल'},

  // Scan Screen
  'scan.title': {'en': 'Scan or Input Document', 'hi': 'दस्तावेज़ स्कैन या दर्ज करें'},
  'scan.subtitle': {
    'en': 'Upload a legal document for AI-powered verification and analysis.',
    'hi': 'एआई-संचालित सत्यापन और विश्लेषण के लिए एक कानूनी दस्तावेज़ अपलोड करें।',
  },
  'scan.takePhoto': {'en': 'Take a Photo', 'hi': 'फोटो खींचें'},
  'scan.cameraBadge': {'en': 'CAMERA SCAN', 'hi': 'कैमरा स्कैन'},
  'scan.cameraDesc': {
    'en': 'Instant OCR scanning of physical deed pages via camera.',
    'hi': 'कैमरे के माध्यम से भौतिक विलेख पृष्ठों की त्वरित ओसीआर स्कैनिंग।',
  },
  'scan.uploadGallery': {'en': 'Upload from Gallery', 'hi': 'गैलरी से अपलोड करें'},
  'scan.uploadFromGallery': {'en': 'Upload from Gallery', 'hi': 'गैलरी से अपलोड करें'},
  'scan.galleryBadge': {'en': 'PHOTO GALLERY', 'hi': 'फोटो गैलरी'},
  'scan.galleryDesc': {
    'en': 'Upload high-resolution document photos or screenshots.',
    'hi': 'उच्च-रिज़ॉल्यूशन दस्तावेज़ फ़ोटो या स्क्रीनशॉट अपलोड करें।',
  },
  'scan.uploadPdf': {'en': 'Upload PDF', 'hi': 'पीडीएफ अपलोड करें'},
  'scan.pdfBadge': {'en': 'PDF DOCUMENT', 'hi': 'पीडीएफ दस्तावेज़'},
  'scan.pdfDesc': {
    'en': 'Upload multi-page PDF agreements & registry documents.',
    'hi': 'बहु-पृष्ठीय पीडीएफ समझौते और रजिस्ट्री दस्तावेज़ अपलोड करें।',
  },
  'scan.selectAndUpload': {'en': 'Select & Upload', 'hi': 'चुनें और अपलोड करें'},
  'scan.orPasteClauses': {'en': 'OR PASTE DOCUMENT CLAUSES', 'hi': 'या दस्तावेज़ खंड पेस्ट करें'},
  'scan.docContent': {'en': 'Document Content', 'hi': 'दस्तावेज़ सामग्री'},
  'scan.documentContent': {'en': 'Document Content', 'hi': 'दस्तावेज़ सामग्री'},
  'scan.pastePrompt': {'en': 'Paste or type the legal document here.', 'hi': 'कानूनी दस्तावेज़ को यहाँ पेस्ट या टाइप करें।'},
  'scan.hint': {'en': 'Paste agreement or clause text here...', 'hi': 'अनुबंध या खंड का पाठ यहाँ पेस्ट करें...'},
  'scan.pasteHint': {'en': 'Paste agreement or clause text here...', 'hi': 'अनुबंध या खंड का पाठ यहाँ पेस्ट करें...'},
  'scan.analyzeText': {'en': 'Analyze Document Text', 'hi': 'दस्तावेज़ टेक्स्ट का विश्लेषण करें'},
  'scan.analyzeBtn': {'en': 'Analyze Document Text', 'hi': 'दस्तावेज़ टेक्स्ट का विश्लेषण करें'},
  'scan.emptyError': {'en': 'Please enter or paste document text.', 'hi': 'कृपया दस्तावेज़ टेक्स्ट दर्ज या पेस्ट करें।'},
  'scan.analyzingImage': {'en': 'Analyzing image document...', 'hi': 'छवि दस्तावेज़ का विश्लेषण किया जा रहा है...'},
  'scan.processingPhoto': {'en': 'Analyzing image document...', 'hi': 'छवि दस्तावेज़ का विश्लेषण किया जा रहा है...'},
  'scan.readingDoc': {'en': 'Reading document...', 'hi': 'दस्तावेज़ पढ़ा जा रहा है...'},
  'scan.processingPdf': {'en': 'Reading document...', 'hi': 'दस्तावेज़ पढ़ा जा रहा है...'},
  'scan.analyzingVision': {'en': 'Analyzing scanned PDF via AI vision...', 'hi': 'एआई विज़न के माध्यम से स्कैन किए गए पीडीएफ का विश्लेषण किया जा रहा है...'},
  'scan.processingPdfVision': {'en': 'Analyzing scanned PDF via AI vision...', 'hi': 'एआई विज़न के माध्यम से स्कैन किए गए पीडीएफ का विश्लेषण किया जा रहा है...'},
  'scan.analyzingRisks': {'en': 'Analyzing for risks...', 'hi': 'जोखिमों का विश्लेषण किया जा रहा है...'},
  'scan.processingRisk': {'en': 'Analyzing for risks...', 'hi': 'जोखिमों का विश्लेषण किया जा रहा है...'},
  'scan.pleaseWait': {'en': 'Please wait while we process your request.', 'hi': 'कृपया प्रतीक्षा करें जब तक हम आपके अनुरोध को संसाधित करते हैं।'},
  'scan.analyzingTitle': {'en': 'Analyzing your document', 'hi': 'आपके दस्तावेज़ का विश्लेषण किया जा रहा है'},
  'scan.stepReading': {'en': 'Reading & extracting document', 'hi': 'दस्तावेज़ पढ़ना और निकालना'},
  'scan.stepReadingDesc': {
    'en': 'Processing document pages and extracting content',
    'hi': 'दस्तावेज़ पृष्ठों को संसाधित करना और सामग्री निकालना',
  },
  'scan.stepStructuring': {'en': 'Structuring clauses', 'hi': 'खंडों को व्यवस्थित करना'},
  'scan.stepStructuringDesc': {
    'en': 'Identifying and organizing legal clauses',
    'hi': 'कानूनी खंडों की पहचान और आयोजन करना',
  },
  'scan.stepAuditing': {'en': 'Auditing legal risk', 'hi': 'कानूनी जोखिम का ऑडिट'},
  'scan.stepAuditingDesc': {
    'en': 'Checking clauses against applicable legal provisions',
    'hi': 'लागू कानूनी प्रावधानों के अनुसार खंडों की जांच',
  },
  'scan.stepPreparing': {'en': 'Preparing results', 'hi': 'परिणाम तैयार किए जा रहे हैं'},
  'scan.stepPreparingDesc': {
    'en': 'Finalizing your analysis report & summary',
    'hi': 'आपकी विश्लेषण रिपोर्ट और सारांश को अंतिम रूप देना',
  },
  'scan.retryingStatus': {
    'en': 'Temporarily unavailable — retrying automatically...',
    'hi': 'अस्थायी रूप से अनुपलब्ध — स्वचालित रूप से पुनः प्रयास किया जा रहा है...',
  },

  // Chat Screen
  'chat.title': {'en': 'Legal AI Assistant', 'hi': 'कानूनी एआई सहायक'},
  'chat.subtitle': {'en': 'Indian Property, RERA & Contract Specialist', 'hi': 'भारतीय संपत्ति, रेरा और अनुबंध विशेषज्ञ'},
  'chat.chatHistory': {'en': 'Chat History', 'hi': 'चैट इतिहास'},
  'chat.newChat': {'en': 'New Chat', 'hi': 'नई बातचीत'},
  'chat.savedConsultations': {'en': 'Saved Consultations', 'hi': 'सहेजी गई बातचीत'},
  'chat.sessionsStored': {'en': '{count} sessions stored in Atlas', 'hi': 'Atlas में {count} सत्र संग्रहीत हैं'},
  'chat.searchConsultations': {'en': 'Search consultations', 'hi': 'परामर्श खोजें'},
  'chat.inputHint': {'en': 'Ask about a clause or document...', 'hi': 'किसी खंड या दस्तावेज़ के बारे में पूछें...'},
  'chat.startNewConsultation': {'en': 'Start New Consultation', 'hi': 'नई बातचीत शुरू करें'},
  'chat.noMatchingConversations': {'en': 'No matching conversations', 'hi': 'कोई मिलती-जुलती बातचीत नहीं मिली'},
  'chat.noSavedConversations': {'en': 'No saved conversations yet', 'hi': 'अभी तक कोई सहेजी गई बातचीत नहीं है'},
  'chat.turnsCount': {'en': '{count} turns', 'hi': '{count} संदेश'},
  'chat.deleteTitle': {'en': 'Permanently Delete Conversation?', 'hi': 'बातचीत स्थायी रूप से हटाएं?'},
  'chat.deleteContent': {
    'en': 'This will permanently delete this conversation. This cannot be undone.',
    'hi': 'यह बातचीत स्थायी रूप से हटा दी जाएगी। इसे पूर्ववत नहीं किया जा सकता है।',
  },
  'chat.deleteAction': {'en': 'Delete Permanently', 'hi': 'स्थायी रूप से हटाएं'},
  'chat.deletedToast': {'en': 'Conversation permanently deleted', 'hi': 'बातचीत स्थायी रूप से हटा दी गई'},
  'chat.heroHeadline': {'en': 'Indian Property & RERA Legal AI', 'hi': 'भारतीय संपत्ति और रेरा कानूनी एआई'},
  'chat.heroSubtitle': {
    'en': 'Instant legal analysis, agreement scrutiny, and RERA rights guidance for homebuyers, landlords & tenants.',
    'hi': 'घर खरीदारों, मकान मालिकों और किरायेदारों के लिए त्वरित कानूनी विश्लेषण, अनुबंध जांच और रेरा अधिकार मार्गदर्शन।',
  },
  'chat.tagRera': {'en': 'RERA Compliant', 'hi': 'रेरा अनुपालन'},
  'chat.tagTenancy': {'en': 'Model Tenancy Act', 'hi': 'मॉडल टेनेंसी एक्ट'},
  'chat.tagTransfer': {'en': 'Transfer of Property Act', 'hi': 'ट्रांसफर ऑफ प्रॉपर्टी एक्ट'},
  'chat.card1Cat': {'en': 'PROPERTY AGREEMENTS', 'hi': 'संपत्ति समझौते'},
  'chat.card1Title': {'en': 'Review Agreement Clauses', 'hi': 'समझौता खंडों की समीक्षा करें'},
  'chat.card1Desc': {
    'en': 'Scan lease or sale deed terms for hidden liabilities, lock-ins, and risky clauses.',
    'hi': 'छिपी हुई देनदारियों, लॉक-इन और जोखिम भरे खंडों के लिए पट्टे या बिक्री विलेख की शर्तों की जांच करें।',
  },
  'chat.card2Cat': {'en': 'RERA COMPLIANCE', 'hi': 'रेरा अनुपालन'},
  'chat.card2Title': {'en': 'RERA Rights & Delays', 'hi': 'रेरा अधिकार और देरी'},
  'chat.card2Desc': {
    'en': 'Understand builder handover delays, Section 18 interest compensation, and escrow norms.',
    'hi': 'बिल्डर हैंडओवर में देरी, धारा 18 ब्याज मुआवजा और एस्क्रो मानदंडों को समझें।',
  },
  'chat.card3Cat': {'en': 'LEGAL DRAFTING', 'hi': 'कानूनी प्रारूपण'},
  'chat.card3Title': {'en': 'Draft Tenancy & NOC', 'hi': 'किराया अनुबंध और एनओसी का मसौदा तैयार करें'},
  'chat.card3Desc': {
    'en': 'Generate standard residential lease, sale agreement, or NOC templates with statutory clauses.',
    'hi': 'वैधानिक खंडों के साथ मानक आवासीय पट्टा, बिक्री समझौता या एनओसी टेम्पलेट तैयार करें।',
  },
  'chat.card4Cat': {'en': 'STAMP DUTY & TITLE', 'hi': 'स्टाम्प शुल्क और शीर्षक'},
  'chat.card4Title': {'en': 'Stamp Duty & Registry', 'hi': 'स्टाम्प शुल्क और रजिस्ट्री'},
  'chat.card4Desc': {
    'en': 'Mandatory document checklist, encumbrance certificate, and state registration guidelines.',
    'hi': 'अनिवार्य दस्तावेज़ चेकलिस्ट, भार प्रमाणपत्र और राज्य पंजीकरण दिशानिर्देश।',
  },
  'chat.rateLimitMessage': {
    'en': 'Rate limit reached. Please wait a moment before sending another query.',
    'hi': 'दर सीमा पूरी हो गई। कृपया अगला प्रश्न भेजने से पहले कुछ देर प्रतीक्षा करें।',
  },
  'chat.copiedToClipboard': {
    'en': 'Copied to clipboard',
    'hi': 'क्लिपबोर्ड पर कॉपी किया गया',
  },
  'chat.rateLimitToast': {
    'en': 'Rate limit exceeded. Please wait a moment.',
    'hi': 'दर सीमा पार हो गई। कृपया कुछ क्षण प्रतीक्षा करें।',
  },
  'chat.chip1': {
    'en': 'Check builder handover delay rights under RERA',
    'hi': 'रेरा के तहत बिल्डर हैंडओवर में देरी के अधिकार जांचें',
  },
  'chat.chip2': {
    'en': 'Draft standard tenancy agreement clauses',
    'hi': 'मानक किराया अनुबंध खंडों का मसौदा तैयार करें',
  },
  'chat.chip3': {
    'en': 'Explain hidden liabilities in sale deeds',
    'hi': 'बिक्री विलेखों में छिपी देनदारियों को समझें',
  },
  'chat.chip4': {
    'en': 'Verify encumbrance certificate checklist',
    'hi': 'भार प्रमाणपत्र चेकलिस्ट सत्यापित करें',
  },
  'chat.disclaimer': {
    'en': 'LawBuddy provides legal information powered by AI. It does not constitute formal legal counsel.',
    'hi': 'LawBuddy एआई द्वारा संचालित कानूनी जानकारी प्रदान करता है। यह औपचारिक कानूनी सलाह का विकल्प नहीं है।',
  },
  'chat.askLegalAi': {'en': 'Ask Legal AI', 'hi': 'लीगल एआई से पूछें'},
  'chat.typingTitle': {
    'en': 'Legal AI is analyzing your query...',
    'hi': 'लीगल एआई आपके प्रश्न का विश्लेषण कर रहा है...',
  },
  'chat.typingSubtitle': {
    'en': 'Reviewing statutory provisions and property jurisprudence',
    'hi': 'वैधानिक प्रावधानों और संपत्ति कानून की समीक्षा की जा रही है',
  },

  // Checklists Screen
  'checklists.title': {'en': 'Due Diligence Checklists', 'hi': 'उचित सावधानी चेकलिस्ट'},
  'checklists.titleLabel': {'en': 'Checklist Title', 'hi': 'चेकलिस्ट शीर्षक'},
  'checklists.defaultTitle': {'en': 'Property Due Diligence Checklist', 'hi': 'संपत्ति उचित तत्परता चेकलिस्ट'},
  'checklists.untitledChecklist': {'en': 'Untitled Checklist', 'hi': 'शीर्षकहीन चेकलिस्ट'},
  'checklists.new': {'en': 'New Checklist', 'hi': 'नई चेकलिस्ट'},
  'checklists.newChecklist': {'en': 'New Checklist', 'hi': 'नई चेकलिस्ट'},
  'checklists.createTitle': {'en': 'Generate Custom Legal Checklist', 'hi': 'कस्टम कानूनी चेकलिस्ट बनाएं'},
  'checklists.createPromptDesc': {
    'en': 'Describe your property scenario to automatically generate tailored legal verification steps.',
    'hi': 'अनुकूलित कानूनी सत्यापन चरणों को स्वचालित रूप से उत्पन्न करने के लिए अपने संपत्ति परिदृश्य का वर्णन करें।',
  },
  'checklists.createHint': {'en': 'e.g. Buying an Under-construction Apartment in Mumbai', 'hi': 'उदा. मुंबई में निर्माणाधीन अपार्टमेंट खरीदना'},
  'checklists.quickPresets': {'en': 'Quick Presets', 'hi': 'त्वरित प्रीसेट'},
  'checklists.newBtn': {'en': 'New', 'hi': 'नया'},
  'checklists.prompt': {
    'en': 'What kind of transaction are you doing?',
    'hi': 'आप किस प्रकार का लेनदेन कर रहे हैं?',
  },
  'checklists.question': {
    'en': 'What kind of transaction are you doing?',
    'hi': 'आप किस प्रकार का लेनदेन कर रहे हैं?',
  },
  'checklists.hint': {'en': 'e.g. Buying a Resale Flat in Mumbai', 'hi': 'उदा. मुंबई में रीसेल फ्लैट खरीदना'},
  'checklists.generate': {'en': 'Generate', 'hi': 'तैयार करें'},
  'checklists.generateBtn': {'en': 'Generate', 'hi': 'तैयार करें'},
  'checklists.empty': {
    'en': 'No checklists yet\nTap "New" to create a due diligence checklist.',
    'hi': 'अभी कोई चेकलिस्ट नहीं है\nनई उचित सावधानी चेकलिस्ट बनाने के लिए "नया" पर टैप करें।',
  },
  'checklists.untitled': {'en': 'Untitled Checklist', 'hi': 'शीर्षकहीन चेकलिस्ट'},
  'checklists.addItem': {'en': 'Add Item', 'hi': 'आइटम जोड़ें'},
  'checklists.addNewItem': {'en': 'Add New Item', 'hi': 'नया आइटम जोड़ें'},
  'checklists.addNewTask': {'en': 'Add New Task', 'hi': 'नया कार्य जोड़ें'},
  'checklists.addTaskAction': {'en': 'Add Task', 'hi': 'कार्य जोड़ें'},
  'checklists.enterTitle': {'en': 'Task title', 'hi': 'कार्य शीर्षक'},
  'checklists.enterTaskTitle': {'en': 'Task title', 'hi': 'कार्य शीर्षक'},
  'checklists.taskDescription': {'en': 'Task Title / Description', 'hi': 'कार्य शीर्षक / विवरण'},
  'checklists.verifyTitleDeed': {'en': 'e.g. Verify Title Deed & Encumbrance Certificate', 'hi': 'उदा. टाइटल डीड और भार प्रमाणपत्र जांचें'},
  'checklists.taskHint': {'en': 'e.g. Verify Title Deed & Encumbrance Certificate', 'hi': 'उदा. टाइटल डीड और भार प्रमाणपत्र जांचें'},
  'checklists.add': {'en': 'Add', 'hi': 'जोड़ें'},
  'checklists.addBtn': {'en': 'Add', 'hi': 'जोड़ें'},
  'checklists.cancel': {'en': 'Cancel', 'hi': 'रद्द करें'},
  'checklists.saveAction': {'en': 'Save Changes', 'hi': 'परिवर्तन सहेजें'},
  'checklists.retryAction': {'en': 'Retry', 'hi': 'पुनः प्रयास करें'},
  'checklists.taskAddedSuccess': {'en': 'Task added successfully', 'hi': 'कार्य सफलतापूर्वक जोड़ा गया'},
  'checklists.failedToAdd': {'en': 'Failed to add task: {error}', 'hi': 'कार्य जोड़ने में विफल: {error}'},
  'checklists.taskDeletedSuccess': {'en': 'Task removed successfully', 'hi': 'कार्य सफलतापूर्वक हटाया गया'},
  'checklists.deleteTaskTitle': {'en': 'Delete Task', 'hi': 'कार्य हटाएं'},
  'checklists.deleteTaskConfirm': {'en': 'Are you sure you want to remove "{task}" from this checklist?', 'hi': 'क्या आप वाकई इस चेकलिस्ट से "{task}" को हटाना चाहते हैं?'},
  'checklists.renameChecklistTitle': {'en': 'Rename Checklist', 'hi': 'चेकलिस्ट का नाम बदलें'},
  'checklists.newTitleHint': {'en': 'Enter new checklist title...', 'hi': 'नया चेकलिस्ट शीर्षक दर्ज करें...'},
  'checklists.renameSuccess': {'en': 'Checklist renamed successfully', 'hi': 'चेकलिस्ट का नाम सफलतापूर्वक बदला गया'},
  'checklists.renameFailed': {'en': 'Failed to rename checklist: {error}', 'hi': 'चेकलिस्ट का नाम बदलने में विफल: {error}'},
  'checklists.deleteChecklistTitle': {'en': 'Move Checklist to Recycle Bin?', 'hi': 'चेकलिस्ट रीसायकल बिन में ले जाएं?'},
  'checklists.deleteChecklistConfirm': {
    'en': 'Are you sure you want to move "{title}" to the Recycle Bin? You can restore it within 30 days.',
    'hi': 'क्या आप वाकई "{title}" को रीसायकल बिन में ले जाना चाहते हैं? आप इसे 30 दिनों के भीतर पुनर्स्थापित कर सकते हैं।',
  },
  'checklists.delete': {'en': 'Move to Bin', 'hi': 'बिन में ले जाएं'},
  'checklists.deleteAction': {'en': 'Move to Bin', 'hi': 'बिन में ले जाएं'},
  'checklists.checklistDeletedSuccess': {'en': 'Checklist moved to Recycle Bin', 'hi': 'चेकलिस्ट रीसायकल बिन में ले जाया गया'},
  'checklists.failedToDelete': {'en': 'Failed to delete: {error}', 'hi': 'हटाने में विफल: {error}'},
  'checklists.deleteChecklist': {'en': 'Move to Recycle Bin', 'hi': 'रीसायकल बिन में ले जाएं'},
  'checklists.deleteConfirm': {'en': 'Are you sure you want to move this checklist to the Recycle Bin?', 'hi': 'क्या आप वाकई इस चेकलिस्ट को रीसायकल बिन में ले जाना चाहते हैं?'},
  'checklists.deletedSuccess': {'en': 'Checklist moved to Recycle Bin', 'hi': 'चेकलिस्ट रीसायकल बिन में ले जाया गया'},
  'checklists.renameChecklist': {'en': 'Rename Checklist', 'hi': 'चेकलिस्ट का नाम बदलें'},
  'checklists.enterNewName': {'en': 'Checklist name', 'hi': 'चेकलिस्ट का नाम'},
  'checklists.renamedSuccess': {'en': 'Checklist renamed successfully', 'hi': 'चेकलिस्ट का नाम सफलतापूर्वक बदल दिया गया'},
  'checklists.alreadyExistsTitle': {'en': 'Checklist Already Exists', 'hi': 'चेकलिस्ट पहले से मौजूद है'},
  'checklists.alreadyExistsDesc': {'en': 'A checklist matching "{title}" already exists in your active cases.', 'hi': '"{title}" से मेल खाने वाली चेकलिस्ट पहले से ही आपके सक्रिय केस में मौजूद है।'},
  'checklists.alreadyExistsPrompt': {'en': 'Would you like to open the existing checklist or still create a new one?', 'hi': 'क्या आप मौजूदा चेकलिस्ट खोलना चाहते हैं या फिर भी एक नई चेकलिस्ट बनाना चाहते हैं?'},
  'checklists.viewExisting': {'en': 'View Existing', 'hi': 'मौजूदा देखें'},
  'checklists.stillCreate': {'en': 'Still Create', 'hi': 'फिर भी बनाएं'},
  'checklists.deleteItem': {'en': 'Delete Item', 'hi': 'आइटम हटाएं'},
  'checklists.deleteItemConfirm': {'en': 'Delete this task from checklist?', 'hi': 'क्या इस कार्य को चेकलिस्ट से हटाना है?'},
  'checklists.itemDeleted': {'en': 'Task removed', 'hi': 'कार्य हटा दिया गया'},
  'checklists.filterAll': {'en': 'All Tasks', 'hi': 'सभी कार्य'},
  'checklists.filterPending': {'en': 'Pending', 'hi': 'लंबित'},
  'checklists.filterFlagged': {'en': 'Flagged Issues', 'hi': 'ध्वजांकित मुद्दे'},
  'checklists.filterCompleted': {'en': 'Completed', 'hi': 'पूर्ण'},
  'checklists.progress': {'en': 'Progress', 'hi': 'प्रगति'},
  'checklists.completedRatio': {'en': '{completed} of {total} completed', 'hi': '{total} में से {completed} पूर्ण'},
  'checklists.allDone': {'en': 'All due-diligence items completed!', 'hi': 'सभी जांच कार्य पूर्ण हो गए!'},
  'checklists.flaggedBadge': {'en': 'FLAGGED BY DOCUMENT ISSUE', 'hi': 'दस्तावेज़ मुद्दे द्वारा ध्वजांकित'},
  'checklists.flaggedCountBadge': {'en': '{count} Flagged', 'hi': '{count} ध्वजांकित'},
  'checklists.triggeredBy': {'en': 'Triggered by: {doc}', 'hi': 'ट्रिगर: {doc}'},
  'checklists.triggeredByMulti': {'en': 'Triggered by {count} documents', 'hi': '{count} दस्तावेज़ों द्वारा ट्रिगर'},
  'checklists.viewRelatedIssue': {'en': 'View related issue', 'hi': 'संबंधित मुद्दा देखें'},
  'checklists.viewRelatedIssues': {'en': 'View {count} related issues', 'hi': '{count} संबंधित मुद्दे देखें'},
  'checklists.relatedIssueModalTitle': {'en': 'Cross-Referenced Document Issue', 'hi': 'क्रॉस-संदर्भित दस्तावेज़ मुद्दा'},
  'checklists.whyFlaggedTitle': {'en': 'Why this was flagged:', 'hi': 'इसे क्यों चिह्नित किया गया:'},
  'checklists.whyFlaggedDesc': {'en': 'LawBuddy detected a legal concern in {doc} relating to this verification task.', 'hi': 'LawBuddy ने इस सत्यापन कार्य से संबंधित {doc} में एक कानूनी चिंता का पता लगाया।'},
  'checklists.clauseFindingTitle': {'en': 'Detected Clause Finding', 'hi': 'पहचाना गया खंड निष्कर्ष'},
  'checklists.statutoryCitationsTitle': {'en': 'Legal & Statutory Citations', 'hi': 'कानूनी और वैधानिक संदर्भ'},
  'checklists.buyerImpactTitle': {'en': 'Buyer Impact & Practical Consequence', 'hi': 'खरीदार पर प्रभाव और व्यावहारिक परिणाम'},
  'checklists.recommendationTitle': {'en': 'Recommended Due Diligence Action', 'hi': 'अनुशंसित उचित सावधानी कार्रवाई'},
  'checklists.markAsVerified': {'en': 'Mark as Verified', 'hi': 'सत्यापित के रूप में चिह्नित करें'},
  'checklists.markAsPending': {'en': 'Mark as Pending', 'hi': 'लंबित के रूप में चिह्नित करें'},
  'checklists.starterTitle': {'en': 'Quick Starter Templates', 'hi': 'त्वरित टेम्पलेट'},
  'checklists.template1': {'en': 'Buying Resale Flat', 'hi': 'पुनर्विक्रय फ्लैट खरीदना'},
  'checklists.template2': {'en': 'Under-Construction RERA Property', 'hi': 'निर्माणाधीन रेरा संपत्ति'},
  'checklists.template3': {'en': 'Commercial Lease Agreement', 'hi': 'व्यावसायिक लीज समझौता'},
  'checklists.template4': {'en': 'Agricultural / Plot Land Due Diligence', 'hi': 'कृषि / प्लॉट भूमि जांच'},
  'checklists.subtitle': {'en': "Track your property's legal due diligence.", 'hi': 'अपनी संपत्ति की कानूनी जांच की निगरानी करें।'},
  'checklists.heroTitle': {'en': 'PROPERTY DUE DILIGENCE', 'hi': 'संपत्ति उचित सावधानी'},
  'checklists.heroHeadline': {'en': 'Verify before you commit.', 'hi': 'प्रतिबद्ध होने से पहले पुष्टि करें।'},
  'checklists.heroSub': {'en': 'Keep every important legal verification step organized in one place.', 'hi': 'प्रत्येक महत्वपूर्ण कानूनी सत्यापन कदम को एक स्थान पर व्यवस्थित रखें।'},
  'checklists.casesHeading': {'en': 'Active Due-Diligence Cases', 'hi': 'सक्रिय उचित सावधानी मामले'},
  'checklists.verificationBadge': {'en': 'PROPERTY VERIFICATION', 'hi': 'संपत्ति सत्यापन'},
  'checklists.dueDiligenceProgress': {'en': 'Due-diligence progress', 'hi': 'उचित सावधानी प्रगति'},
  'checklists.inProgress': {'en': 'In Progress', 'hi': 'प्रगति में'},
  'checklists.completed': {'en': 'Completed', 'hi': 'पूर्ण'},
  'checklists.emptyTitle': {'en': 'Start your property due diligence', 'hi': 'अपनी संपत्ति की उचित सावधानी शुरू करें'},
  'checklists.emptySub': {'en': 'Create a checklist to organize the legal documents, approvals and verification steps you need before committing to a property.', 'hi': 'संपत्ति के लिए प्रतिबद्ध होने से पहले आवश्यक कानूनी दस्तावेजों, अनुमोदनों और सत्यापन चरणों को व्यवस्थित करने के लिए एक चेकलिस्ट बनाएं।'},
  'checklists.quickStartSub': {'en': 'Start with a property-specific due-diligence checklist.', 'hi': 'संपत्ति-विशिष्ट चेकलिस्ट के साथ शुरुआत करें।'},

  // Stamp Duty Calculator Screen
  'calc.screenTitle': {'en': 'Stamp Duty & Registration Calculator', 'hi': 'स्टाम्प शुल्क और पंजीकरण कैलकुलेटर'},
  'calc.screenSubtitle': {
    'en': 'Calculate estimated stamp duty, registration charges, and state cess across India.',
    'hi': 'भारत भर में अनुमानित स्टाम्प शुल्क, पंजीकरण शुल्क और राज्य उपकर की गणना करें।',
  },
  'calc.cardTitle': {'en': 'Property & Transaction Details', 'hi': 'संपत्ति और लेनदेन का विवरण'},
  'calc.propertyType': {'en': 'Property Type', 'hi': 'संपत्ति का प्रकार'},
  'calc.propertyTypeLabel': {'en': 'Property Category', 'hi': 'संपत्ति की श्रेणी'},
  'calc.selectPropertyType': {'en': 'Select property type', 'hi': 'संपत्ति प्रकार चुनें'},
  'calc.selectPropertyTypeHint': {'en': 'Select property category', 'hi': 'संपत्ति श्रेणी चुनें'},
  'calc.typeResidential': {'en': 'Residential', 'hi': 'आवासीय'},
  'calc.typeCommercial': {'en': 'Commercial', 'hi': 'व्यावसायिक'},
  'calc.typeAgricultural': {'en': 'Agricultural', 'hi': 'कृषि'},
  'calc.typeOther': {'en': 'Other', 'hi': 'अन्य'},
  'calc.propertyTypeResidential': {'en': 'Residential', 'hi': 'आवासीय'},
  'calc.propertyTypeCommercial': {'en': 'Commercial', 'hi': 'व्यावसायिक'},
  'calc.propertyTypeAgricultural': {'en': 'Agricultural', 'hi': 'कृषि'},
  'calc.propertyTypeOther': {'en': 'Other', 'hi': 'अन्य'},
  'calc.state': {'en': 'State / UT', 'hi': 'राज्य / केंद्र शासित प्रदेश'},
  'calc.stateLabel': {'en': 'State / Jurisdiction', 'hi': 'राज्य / क्षेत्राधिकार'},
  'calc.selectState': {'en': 'Select state', 'hi': 'राज्य चुनें'},
  'calc.selectStateHint': {'en': 'Select State / Union Territory', 'hi': 'राज्य / केंद्र शासित प्रदेश चुनें'},
  'calc.agreementValue': {'en': 'Agreement Value', 'hi': 'अनुबंध मूल्य'},
  'calc.propValueLabel': {'en': 'Agreement / Declared Value (₹)', 'hi': 'अनुबंध / घोषित मूल्य (₹)'},
  'calc.enterAgreementValue': {'en': 'e.g. 75,00,000', 'hi': 'उदा. 75,00,000'},
  'calc.enterPropValError': {'en': 'Please enter the agreement property value', 'hi': 'कृपया अनुबंध संपत्ति मूल्य दर्ज करें'},
  'calc.circleRate': {'en': 'Circle Rate Value', 'hi': 'सर्किल रेट मूल्य'},
  'calc.circleRateLabel': {'en': 'Circle Rate Value (₹)', 'hi': 'सर्किल रेट मूल्य (₹)'},
  'calc.enterCircleRate': {'en': 'e.g. 50,00,000', 'hi': 'उदा. 50,00,000'},
  'calc.gender': {'en': 'Buyer Gender / Ownership', 'hi': 'खरीदार का लिंग / स्वामित्व'},
  'calc.genderLabel': {'en': 'Buyer Gender / Ownership', 'hi': 'खरीदार का लिंग / स्वामित्व'},
  'calc.selectGender': {'en': 'Select gender', 'hi': 'लिंग चुनें'},
  'calc.selectGenderHint': {'en': 'Select ownership gender category', 'hi': 'स्वामित्व लिंग श्रेणी चुनें'},
  'calc.genderMale': {'en': 'Male', 'hi': 'पुरुष'},
  'calc.genderFemale': {'en': 'Female (Concession where applicable)', 'hi': 'महिला (जहाँ लागू हो छूट)'},
  'calc.genderJoint': {'en': 'Joint (Male + Female)', 'hi': 'संयुक्त (पुरुष + महिला)'},
  'calc.genderOther': {'en': 'Other / Legal Entity', 'hi': 'अन्य / कानूनी संस्था'},
  'calc.firstTimeBuyer': {'en': 'First Time Buyer', 'hi': 'पहली बार खरीदार'},
  'calc.firstTimeLabel': {'en': 'First-Time Homebuyer?', 'hi': 'क्या पहली बार घर खरीद रहे हैं?'},
  'calc.selectOption': {'en': 'Select option', 'hi': 'विकल्प चुनें'},
  'calc.selectOptionHint': {'en': 'Select Yes or No', 'hi': 'हाँ या नहीं चुनें'},
  'calc.yes': {'en': 'Yes', 'hi': 'हाँ'},
  'calc.no': {'en': 'No', 'hi': 'नहीं'},
  'calc.calculateBtn': {'en': 'Calculate Stamp Duty', 'hi': 'स्टाम्प शुल्क की गणना करें'},
  'calc.calcButton': {'en': 'Calculate Charges', 'hi': 'शुल्क की गणना करें'},
  'calc.resetBtn': {'en': 'Reset', 'hi': 'रीसेट करें'},
  'calc.resetButton': {'en': 'Reset All', 'hi': 'सभी रीसेट करें'},
  'calc.fillAllError': {'en': 'Please complete all required fields.', 'hi': 'कृपया सभी आवश्यक फ़ील्ड भरें।'},
  'calc.validValueError': {'en': 'Please enter valid numerical amounts.', 'hi': 'कृपया मान्य संख्यात्मक राशि दर्ज करें।'},
  'calc.summaryTitle': {'en': 'Stamp Duty & Registration Summary', 'hi': 'स्टाम्प शुल्क और पंजीकरण सारांश'},
  'calc.rowAgreementValue': {'en': 'Agreement Value', 'hi': 'अनुबंध मूल्य'},
  'calc.rowCircleRate': {'en': 'Circle Rate Value', 'hi': 'सर्किल रेट मूल्य'},
  'calc.rowApplicableMarketValue': {'en': 'Applicable Consideration Base', 'hi': 'लागू विचारणीय आधार'},
  'calc.rowStampDuty': {'en': 'Stamp Duty ({rate}%)', 'hi': 'स्टाम्प शुल्क ({rate}%)'},
  'calc.rowRegistration': {'en': 'Registration Fee ({rate}%)', 'hi': 'पंजीकरण शुल्क ({rate}%)'},
  'calc.totalPayable': {'en': 'Total Estimated Statutory Charges', 'hi': 'कुल अनुमानित वैधानिक शुल्क'},
  'calc.stampPlusReg': {'en': 'Stamp Duty + Registration + Applicable Surcharges', 'hi': 'स्टाम्प शुल्क + पंजीकरण + लागू अधिभार'},
  'calc.disclaimer': {
    'en': 'Calculations are indicative estimates based on prevailing state stamp schedules. Verify final rates with the local sub-registrar office.',
    'hi': 'गणना प्रचलित राज्य स्टाम्प अनुसूचियों पर आधारित सांकेतिक अनुमान हैं। स्थानीय उप-पंजीयक कार्यालय से अंतिम दरों का सत्यापन करें।',
  },
  'calc.ratesVerifiedOn': {'en': 'Rates last verified on {date}', 'hi': 'दरें अंतिम बार {date} को सत्यापित की गईं'},
  'calc.sourceLabel': {'en': 'Source: {source}', 'hi': 'स्रोत: {source}'},
  'calc.ratesWarning': {
    'en': 'Statutory rates may have changed since verification. Please confirm with your local Sub-Registrar or IGR portal.',
    'hi': 'सत्यापन के बाद से वैधानिक दरें बदल सकती हैं। कृपया अपने स्थानीय उप-पंजीयक या आईजीआर पोर्टल से पुष्टि करें।',
  },
  'calc.moreThan90Days': {'en': '> 90 DAYS', 'hi': '> 90 दिन'},

  // Recent Documents Screen
  'recentDocs.title': {'en': 'Recent Documents', 'hi': 'हाल के दस्तावेज़'},
  'recentDocs.scanNew': {'en': 'Scan New Document', 'hi': 'नया दस्तावेज़ स्कैन करें'},
  'recentDocs.scanNewDoc': {'en': 'Scan New Document', 'hi': 'नया दस्तावेज़ स्कैन करें'},
  'recentDocs.repository': {'en': 'Document Legal Repository', 'hi': 'दस्तावेज़ कानूनी रिपॉजिटरी'},
  'recentDocs.repoTitle': {'en': 'Document Legal Repository', 'hi': 'दस्तावेज़ कानूनी रिपॉजिटरी'},
  'recentDocs.vaultSubtitle': {
    'en': 'Your property documents, organized and analyzed.',
    'hi': 'आपके संपत्ति दस्तावेज़, व्यवस्थित और विश्लेषित।',
  },
  'recentDocs.secureVault': {'en': 'SECURE LEGAL VAULT', 'hi': 'सुरक्षित कानूनी वॉल्ट'},
  'recentDocs.documents': {'en': 'DOCUMENTS', 'hi': 'दस्तावेज़'},
  'recentDocs.totalAnalyzed': {
    'en': '{count} total property agreements analyzed',
    'hi': 'कुल {count} संपत्ति समझौतों का विश्लेषण किया गया',
  },
  'recentDocs.repoSubtitle': {
    'en': '{count} total property agreements analyzed',
    'hi': 'कुल {count} संपत्ति समझौतों का विश्लेषण किया गया',
  },
  'recentDocs.total': {'en': 'Total', 'hi': 'कुल'},
  'recentDocs.statTotal': {'en': 'Total', 'hi': 'कुल'},
  'recentDocs.highRisk': {'en': 'High Risk', 'hi': 'उच्च जोखिम'},
  'recentDocs.statHighRisk': {'en': 'High Risk', 'hi': 'उच्च जोखिम'},
  'recentDocs.caution': {'en': 'Caution', 'hi': 'सावधानी'},
  'recentDocs.statCaution': {'en': 'Caution', 'hi': 'सावधानी'},
  'recentDocs.compliant': {'en': 'Compliant', 'hi': 'अनुरूप'},
  'recentDocs.statCompliant': {'en': 'Compliant', 'hi': 'अनुरूप'},
  'recentDocs.searchHint': {'en': 'Search documents', 'hi': 'दस्तावेज़ खोजें'},
  'recentDocs.all': {'en': 'All', 'hi': 'सभी'},
  'recentDocs.filterAll': {'en': 'All', 'hi': 'सभी'},
  'recentDocs.resetFilters': {
    'en': 'Reset Filters',
    'hi': 'फ़िल्टर रीसेट करें',
  },
  'recentDocs.noDocsMatching': {'en': 'No documents matching "{query}"', 'hi': '"{query}" से मेल खाता कोई दस्तावेज़ नहीं मिला'},
  'recentDocs.noMatch': {'en': 'No documents matching "{query}"', 'hi': '"{query}" से मेल खाता कोई दस्तावेज़ नहीं मिला'},
  'recentDocs.noDocsCategory': {'en': 'No documents in this category', 'hi': 'इस श्रेणी में कोई दस्तावेज़ नहीं'},
  'recentDocs.noCategory': {'en': 'No documents in this category', 'hi': 'इस श्रेणी में कोई दस्तावेज़ नहीं'},
  'recentDocs.emptyPrompt': {
    'en': 'Scan a new agreement or document to get an instant AI legal risk report.',
    'hi': 'तुरंत एआई कानूनी जोखिम रिपोर्ट प्राप्त करने के लिए एक नया समझौता या दस्तावेज़ स्कैन करें।',
  },
  'recentDocs.emptyDesc': {
    'en': 'Scan a new agreement or document to get an instant AI legal risk report.',
    'hi': 'तुरंत एआई कानूनी जोखिम रिपोर्ट प्राप्त करने के लिए एक नया समझौता या दस्तावेज़ स्कैन करें।',
  },
  'recentDocs.scanned': {'en': 'Scanned {time}', 'hi': '{time} स्कैन किया गया'},
  'recentDocs.scannedPrefix': {'en': 'Scanned {time}', 'hi': '{time} स्कैन किया गया'},
  'recentDocs.justNow': {'en': 'Just now', 'hi': 'अभी'},
  'recentDocs.mAgo': {'en': '{count}m ago', 'hi': '{count} मिनट पहले'},
  'recentDocs.hAgo': {'en': '{count}h ago', 'hi': '{count} घंटे पहले'},
  'recentDocs.dAgo': {'en': '{count}d ago', 'hi': '{count} दिन पहले'},
  'recentDocs.recently': {'en': 'Recently', 'hi': 'हाल ही में'},
  'recentDocs.rename': {'en': 'Rename Document', 'hi': 'दस्तावेज़ का नाम बदलें'},
  'recentDocs.renameTitle': {'en': 'Rename Document', 'hi': 'दस्तावेज़ का नाम बदलें'},
  'recentDocs.renameHint': {'en': 'Document name', 'hi': 'दस्तावेज़ का नाम'},
  'recentDocs.save': {'en': 'Save', 'hi': 'सहेजें'},
  'recentDocs.cancel': {'en': 'Cancel', 'hi': 'रद्द करें'},
  'recentDocs.delete': {'en': 'Delete Document', 'hi': 'दस्तावेज़ हटाएं'},
  'recentDocs.deleteConfirm': {'en': 'Are you sure you want to delete this document analysis?', 'hi': 'क्या आप वाकई इस दस्तावेज़ विश्लेषण को हटाना चाहते हैं?'},
  'recentDocs.renamedSuccess': {'en': 'Document renamed successfully', 'hi': 'दस्तावेज़ का नाम सफलतापूर्वक बदल दिया गया'},
  'recentDocs.deletedSuccess': {'en': 'Document moved to Recycle Bin', 'hi': 'दस्तावेज़ रीसायकल बिन में ले जाया गया'},
  'recentDocs.actions': {'en': 'Actions', 'hi': 'कार्रवाइयां'},
  'recentDocs.viewDocument': {'en': 'View Document', 'hi': 'दस्तावेज़ देखें'},
  'recentDocs.viewAnalysis': {'en': 'View Analysis', 'hi': 'विश्लेषण देखें'},
  'recentDocs.downloadReport': {'en': 'Download Risk Report', 'hi': 'जोखिम रिपोर्ट डाउनलोड करें'},
  'recentDocs.reanalyze': {'en': 'Re-analyze Document', 'hi': 'दस्तावेज़ का पुनः विश्लेषण करें'},
  'recentDocs.downloadingReport': {'en': 'Generating & downloading risk report PDF...', 'hi': 'जोखिम रिपोर्ट पीडीएफ तैयार और डाउनलोड की जा रही है...'},
  'recentDocs.reportDownloaded': {'en': 'Legal Risk Report PDF downloaded successfully', 'hi': 'कानूनी जोखिम रिपोर्ट पीडीएफ सफलतापूर्वक डाउनलोड की गई'},
  'recentDocs.reanalyzing': {'en': 'Re-analyzing document with Legal AI...', 'hi': 'लीगल एआई के साथ दस्तावेज़ का पुनः विश्लेषण किया जा रहा है...'},
  'recentDocs.reanalyzeSuccess': {'en': 'Document re-analyzed successfully', 'hi': 'दस्तावेज़ का पुनः विश्लेषण सफलतापूर्वक पूरा हुआ'},
  'recentDocs.reanalyzeFailed': {'en': 'Failed to re-analyze document', 'hi': 'दस्तावेज़ का पुनः विश्लेषण करने में विफल'},

  // Recycle Bin Screen
  'bin.title': {'en': 'Recycle Bin', 'hi': 'रीसायकल बिन'},
  'bin.documentsTab': {'en': 'Documents', 'hi': 'दस्तावेज़'},
  'bin.checklistsTab': {'en': 'Checklists', 'hi': 'चेकलिस्ट'},
  'bin.emptyTitle': {'en': 'Recycle Bin is Empty', 'hi': 'रीसायकल बिन खाली है'},
  'bin.emptySubtitle': {'en': 'Deleted documents will be kept here for 30 days before being permanently removed.', 'hi': 'हटाए गए दस्तावेज़ स्थायी रूप से हटाए जाने से पहले 30 दिनों तक यहां रखे जाएंगे।'},
  'bin.emptyChecklistsTitle': {'en': 'No Deleted Checklists', 'hi': 'कोई हटाई गई चेकलिस्ट नहीं है'},
  'bin.emptyChecklistsSubtitle': {'en': 'Deleted checklists will be kept here for 30 days before being permanently removed.', 'hi': 'हटाए गए चेकलिस्ट स्थायी रूप से हटाए जाने से पहले 30 दिनों तक यहां रखे जाएंगे।'},
  'bin.restore': {'en': 'Restore', 'hi': 'पुनर्स्थापित करें'},
  'bin.deletePermanently': {'en': 'Delete Permanently', 'hi': 'स्थायी रूप से हटाएं'},
  'bin.permanentConfirmTitle': {'en': 'Permanently Delete Document?', 'hi': 'दस्तावेज़ स्थायी रूप से हटाएं?'},
  'bin.permanentConfirmMessage': {'en': 'This will permanently delete this document and all associated data. This action is irreversible and cannot be undone.', 'hi': 'यह इस दस्तावेज़ और सभी संबद्ध डेटा को स्थायी रूप से हटा देगा। यह क्रिया अपरिवर्तनीय है।'},
  'bin.permanentConfirmChecklistTitle': {'en': 'Permanently Delete Checklist?', 'hi': 'चेकलिस्ट स्थायी रूप से हटाएं?'},
  'bin.permanentConfirmChecklistMessage': {'en': 'This will permanently delete this checklist and all its items. This action is irreversible and cannot be undone.', 'hi': 'यह इस चेकलिस्ट और उसके सभी कार्यों को स्थायी रूप से हटा देगा। यह क्रिया अपरिवर्तनीय है।'},
  'bin.restoredSuccess': {'en': 'Document restored to library', 'hi': 'दस्तावेज़ लाइब्रेरी में पुनर्स्थापित किया गया'},
  'bin.permanentlyDeletedSuccess': {'en': 'Document permanently deleted', 'hi': 'दस्तावेज़ स्थायी रूप से हटा दिया गया'},
  'bin.checklistRestoredSuccess': {'en': 'Checklist restored to library', 'hi': 'चेकलिस्ट लाइब्रेरी में पुनर्स्थापित की गई'},
  'bin.checklistPermanentlyDeletedSuccess': {'en': 'Checklist permanently deleted', 'hi': 'चेकलिस्ट स्थायी रूप से हटा दी गई'},
  'bin.autoPurgeNote': {'en': 'Items in the bin for more than 30 days are automatically deleted permanently.', 'hi': '30 दिनों से अधिक समय से बिन में मौजूद आइटम स्वचालित रूप से स्थायी रूप से हटा दिए जाते हैं।'},
  'sidebar.bin': {'en': 'Recycle Bin', 'hi': 'रीसायकल बिन'},

  // Analysis Screen
  'analysis.reportTitle': {'en': 'Risk Analysis Report', 'hi': 'जोखिम विश्लेषण रिपोर्ट'},
  'analysis.title': {'en': 'Risk Analysis Report', 'hi': 'जोखिम विश्लेषण रिपोर्ट'},
  'analysis.pageOneOfOne': {'en': 'PAGE 1 OF 1', 'hi': 'पृष्ठ 1 / 1'},
  'analysis.highRiskDetected': {'en': 'High Legal Risk Detected', 'hi': 'उच्च कानूनी जोखिम का पता चला'},
  'analysis.moderateCaution': {'en': 'Moderate Caution Advised', 'hi': 'मध्यम सावधानी की सलाह दी गई है'},
  'analysis.noRiskDetected': {'en': 'No Risk Detected', 'hi': 'कोई जोखिम नहीं मिला'},
  'analysis.standardLowRisk': {'en': 'No Risk Detected', 'hi': 'कोई जोखिम नहीं मिला'},
  'analysis.exportPdf': {'en': 'Export PDF', 'hi': 'पीडीएफ निर्यात करें'},
  'analysis.highRiskCount': {'en': '🔴 {count} High Risk', 'hi': '🔴 {count} उच्च जोखिम'},
  'analysis.pillHighRisk': {'en': '🔴 {count} High Risk', 'hi': '🔴 {count} उच्च जोखिम'},
  'analysis.cautionCount': {'en': '🟡 {count} Caution', 'hi': '🟡 {count} सावधानी'},
  'analysis.pillCaution': {'en': '🟡 {count} Caution', 'hi': '🟡 {count} सावधानी'},
  'analysis.compliantCount': {'en': '🟢 {count} Compliant', 'hi': '🟢 {count} अनुरूप'},
  'analysis.pillCompliant': {'en': '🟢 {count} Compliant', 'hi': '🟢 {count} अनुरूप'},
  'analysis.clausesTotal': {'en': '{count} Clauses Total', 'hi': '{count} कुल खंड'},
  'analysis.pillTotalClauses': {'en': '{count} Clauses Total', 'hi': '{count} कुल खंड'},
  'analysis.sourceDocTitle': {'en': 'Uploaded Source Document & Text', 'hi': 'अपलोड किया गया स्रोत दस्तावेज़ और पाठ'},
  'analysis.sourceDocDefault': {'en': 'Uploaded Source Document & Text', 'hi': 'अपलोड किया गया स्रोत दस्तावेज़ और पाठ'},
  'analysis.originalUploaded': {'en': 'Original uploaded contract file', 'hi': 'मूल अपलोड की गई अनुबंध फ़ाइल'},
  'analysis.originalContractFile': {'en': 'Original uploaded contract file', 'hi': 'मूल अपलोड की गई अनुबंध फ़ाइल'},
  'analysis.expandWindow': {'en': 'Expand Window', 'hi': 'विंडो बड़ा करें'},
  'analysis.originalContractText': {'en': 'Original Contract Text:', 'hi': 'मूल अनुबंध पाठ:'},
  'analysis.analyzedClauses': {'en': 'Analyzed Clauses & Explanations', 'hi': 'विश्लेषण किए गए खंड और स्पष्टीकरण'},
  'analysis.tapToExplain': {'en': 'Tap to explain', 'hi': 'स्पष्टीकरण के लिए टैप करें'},
  'analysis.riskRationale': {'en': 'Risk Rationale: {reason}', 'hi': 'जोखिम का कारण: {reason}'},
  'analysis.simplifyingJargon': {'en': 'Simplifying legal jargon with AI...', 'hi': 'एआई के साथ कानूनी शब्दावली को सरल बनाया जा रहा है...'},
  'analysis.plainEnglish': {'en': 'Plain English Translation', 'hi': 'सरल अनुवाद'},
  'analysis.gotIt': {'en': 'Got it', 'hi': 'समझ गया'},
  'analysis.pdfSuccess': {'en': 'Legal Risk Assessment Report exported successfully!', 'hi': 'कानूनी जोखिम मूल्यांकन रिपोर्ट सफलतापूर्वक निर्यात की गई!'},
  'analysis.exportSuccess': {'en': 'Legal Risk Assessment Report exported successfully!', 'hi': 'कानूनी जोखिम मूल्यांकन रिपोर्ट सफलतापूर्वक निर्यात की गई!'},
  'analysis.pdfFailed': {'en': 'Failed to export PDF: {error}', 'hi': 'पीडीएफ निर्यात करने में विफल: {error}'},
  'analysis.copySuccess': {'en': 'Contract text copied to clipboard!', 'hi': 'अनुबंध पाठ क्लिपबोर्ड पर कॉपी किया गया!'},
  'analysis.copyText': {'en': 'Copy Text', 'hi': 'पाठ कॉपी करें'},
  'analysis.extractedWords': {'en': 'Original Extracted Text ({count} words)', 'hi': 'मूल निकाला गया पाठ ({count} शब्द)'},

  // Auth / Login / Signup / OTP
  'auth.welcomeBack': {'en': 'Welcome Back', 'hi': 'वापसी पर स्वागत है'},
  'auth.loginToAccount': {'en': 'Sign in to your account to continue', 'hi': 'जारी रखने के लिए अपने खाते में साइन इन करें'},
  'auth.enterEmailPhone': {
    'en': 'Enter your email or phone to receive a secure OTP code.',
    'hi': 'सुरक्षित ओटीपी कोड प्राप्त करने के लिए अपना ईमेल या फोन दर्ज करें।',
  },
  'auth.loginOtpPrompt': {
    'en': 'Enter your email or phone to receive a secure OTP code.',
    'hi': 'सुरक्षित ओटीपी कोड प्राप्त करने के लिए अपना ईमेल या फोन दर्ज करें।',
  },
  'auth.email': {'en': 'Email', 'hi': 'ईमेल'},
  'auth.mobile': {'en': 'Mobile', 'hi': 'मोबाइल'},
  'auth.emailAddress': {'en': 'Email Address', 'hi': 'ईमेल पता'},
  'auth.mobileNumber': {'en': 'Mobile Number', 'hi': 'मोबाइल नंबर'},
  'auth.fullName': {'en': 'Full Name', 'hi': 'पूरा नाम'},
  'auth.emailHint': {'en': 'name@example.com', 'hi': 'name@example.com'},
  'auth.phoneHint': {'en': 'e.g. 9876543210', 'hi': 'उदा. 9876543210'},
  'auth.nameHint': {'en': 'Full name', 'hi': 'पूरा नाम'},
  'auth.enterIdentifier': {'en': 'Please enter your {type}', 'hi': 'कृपया अपना {type} दर्ज करें'},
  'auth.enterFullName': {'en': 'Please enter your full name', 'hi': 'कृपया अपना पूरा नाम दर्ज करें'},
  'auth.emailRequired': {'en': 'Please enter your email address', 'hi': 'कृपया अपना ईमेल पता दर्ज करें'},
  'auth.enterValidEmail': {'en': 'Please enter a valid email address', 'hi': 'कृपया एक मान्य ईमेल पता दर्ज करें'},
  'auth.mobileRequired': {'en': 'Please enter your mobile number', 'hi': 'कृपया अपना मोबाइल नंबर दर्ज करें'},
  'auth.enterValidPhone': {'en': 'Please enter a valid 10-digit mobile number', 'hi': 'कृपया एक मान्य 10 अंकों का मोबाइल नंबर दर्ज करें'},
  'auth.validEmail': {'en': 'Enter a valid email address', 'hi': 'एक मान्य ईमेल पता दर्ज करें'},
  'auth.validPhone': {'en': 'Enter a valid phone number', 'hi': 'एक मान्य फ़ोन नंबर दर्ज करें'},
  'auth.sendOtp': {'en': 'Send Secure OTP', 'hi': 'सुरक्षित ओटीपी भेजें'},
  'auth.sendSecureOtp': {'en': 'Send Secure OTP', 'hi': 'सुरक्षित ओटीपी भेजें'},
  'auth.sendVerificationCode': {'en': 'We will send a 6-digit verification code to this address.', 'hi': 'हम इस पते पर 6 अंकों का सत्यापन कोड भेजेंगे।'},
  'auth.createAccount': {'en': 'Create Account', 'hi': 'खाता बनाएं'},
  'auth.createAccountSub': {
    'en': 'Create your account to securely scan, analyze, and manage your property agreements.',
    'hi': 'अपने संपत्ति समझौतों को सुरक्षित रूप से स्कैन, विश्लेषण और प्रबंधित करने के लिए अपना खाता बनाएं।',
  },
  'auth.createYourAccount': {'en': 'Create your account', 'hi': 'अपना खाता बनाएं'},
  'auth.enterDetails': {'en': 'Enter your details to get started securely with LawBuddy.', 'hi': 'LawBuddy के साथ सुरक्षित रूप से शुरुआत करने के लिए अपना विवरण दर्ज करें।'},
  'auth.noAccount': {'en': "Don't have an account? ", 'hi': 'खाता नहीं है? '},
  'auth.dontHaveAccount': {'en': "Don't have an account? ", 'hi': 'खाता नहीं है? '},
  'auth.alreadyHaveAccount': {'en': 'Already have an account? ', 'hi': 'पहले से ही एक खाता है? '},
  'auth.signUp': {'en': 'Sign Up', 'hi': 'साइन अप करें'},
  'auth.logIn': {'en': 'Log In', 'hi': 'लॉग इन करें'},
  'auth.backToHome': {'en': 'Back', 'hi': 'पीछे'},
  'auth.intelligentProtection': {
    'en': 'Intelligent Protection for Property Agreements.',
    'hi': 'संपत्ति समझौतों के लिए बुद्धिमान सुरक्षा।',
  },
  'auth.loginHeroSub': {
    'en': 'Sign in to access your saved document scans, RERA compliance checks, and real-time legal assistant.',
    'hi': 'अपने सहेजे गए दस्तावेज़ स्कैन, रेरा अनुपालन जांच और रीयल-टाइम कानूनी सहायक तक पहुंचने के लिए साइन इन करें।',
  },
  'auth.signInSubtitle': {
    'en': 'Sign in to access your saved document scans, RERA compliance checks, and real-time legal assistant.',
    'hi': 'अपने सहेजे गए दस्तावेज़ स्कैन, रेरा अनुपालन जांच और रीयल-टाइम कानूनी सहायक तक पहुंचने के लिए साइन इन करें।',
  },
  'auth.loginHeroDesc': {
    'en': 'Sign in to access your saved document scans, RERA compliance checks, and real-time legal assistant.',
    'hi': 'अपने सहेजे गए दस्तावेज़ स्कैन, रेरा अनुपालन जांच और रीयल-टाइम कानूनी सहायक तक पहुंचने के लिए साइन इन करें।',
  },
  'auth.pillarRera': {'en': 'RERA Compliance Verification', 'hi': 'रेरा अनुपालन सत्यापन'},
  'auth.pillarReraSub': {'en': 'Automated cross-checking against official state statutory provisions.', 'hi': 'आधिकारिक राज्य वैधानिक प्रावधानों के खिलाफ स्वचालित क्रॉस-चेकिंग।'},
  'auth.pillarAudit': {'en': 'Instant Risk Audit', 'hi': 'त्वरित जोखिम ऑडिट'},
  'auth.pillarAuditSub': {'en': 'Detect ambiguous clauses, penalties, and deviations in seconds.', 'hi': 'सेकंडों में अस्पष्ट खंडों, दंडों और विचलनों का पता लगाएं।'},
  'auth.pillarDueDiligence': {'en': 'Due Diligence Checklists', 'hi': 'उचित तत्परता चेकलिस्ट'},
  'auth.pillarDueDiligenceSub': {'en': 'Tailored legal task lists for buyers, sellers, and tenants.', 'hi': 'खरीदारों, विक्रेताओं और किरायेदारों के लिए अनुकूलित कानूनी कार्य सूचियां।'},
  'auth.bankGradeSecurity': {'en': '256-bit Encrypted • Strict Confidentiality', 'hi': '256-बिट एन्क्रिप्टेड • पूर्ण गोपनीयता'},
  'auth.mobileSubtitle': {'en': 'AI Property Legal Assistant', 'hi': 'एआई संपत्ति कानूनी सहायक'},
  'auth.signupHeroTitle': {'en': 'Build a Safer Property Journey.', 'hi': 'एक सुरक्षित संपत्ति यात्रा का निर्माण करें।'},
  'auth.buildSaferJourney': {'en': 'Build a Safer Property Journey.', 'hi': 'एक सुरक्षित संपत्ति यात्रा का निर्माण करें।'},
  'auth.signupHeroSub': {
    'en': 'Join thousands of homebuyers and legal professionals safeguarding their property transactions.',
    'hi': 'हजारों घर खरीदारों और कानूनी पेशेवरों से जुड़ें जो अपने संपत्ति लेनदेन की सुरक्षा कर रहे हैं।',
  },
  'auth.signUpSubtitle': {
    'en': 'Create your account to securely scan, analyze, and manage your property agreements with LawBuddy.',
    'hi': 'LawBuddy के साथ अपने संपत्ति समझौतों को सुरक्षित रूप से स्कैन, विश्लेषण और प्रबंधित करने के लिए अपना खाता बनाएं।',
  },
  'auth.signupFeatureInstantAudit': {'en': 'Instant Document Audits', 'hi': 'त्वरित दस्तावेज़ ऑडिट'},
  'auth.signupFeatureInstantAuditSub': {'en': 'Comprehensive 3-tier risk analysis with severity tagging.', 'hi': 'गंभीरता टैगिंग के साथ व्यापक 3-स्तरीय जोखिम विश्लेषण।'},
  'auth.signupFeatureAiExplain': {'en': 'Plain-Language Explanations', 'hi': 'सरल भाषा में व्याख्या'},
  'auth.signupFeatureAiExplainSub': {'en': 'Complex legal terminology translated into clear actionable advice.', 'hi': 'जटिल कानूनी शब्दावली का स्पष्ट व्यावहारिक सलाह में अनुवाद।'},
  'auth.signupFeatureCustomChecklists': {'en': 'Custom Legal Checklists', 'hi': 'कस्टम कानूनी चेकलिस्ट'},
  'auth.signupFeatureCustomChecklistsSub': {'en': 'Track key verification steps throughout your transaction lifecycle.', 'hi': 'अपने लेनदेन जीवनचक्र के दौरान मुख्य सत्यापन चरणों को ट्रैक करें।'},
  'auth.reraSafety': {'en': 'RERA & Contract Safety', 'hi': 'रेरा और अनुबंध सुरक्षा'},
  'auth.aiReady': {'en': 'AI Analysis Ready', 'hi': 'एआई विश्लेषण तैयार'},
  'auth.clauseAssessment': {'en': 'Clause Risk Assessment • Escrow Compliance', 'hi': 'खंड जोखिम मूल्यांकन • एस्क्रो अनुपालन'},
  'auth.agreementIntelligence': {'en': 'Agreement Intelligence', 'hi': 'अनुबंध बुद्धिमत्ता'},
  'auth.aiProtectionReady': {'en': 'AI Protection Ready', 'hi': 'एआई सुरक्षा तैयार'},
  'auth.clauseDocVerification': {'en': 'Clause Risk Assessment • Document Verification', 'hi': 'खंड जोखिम मूल्यांकन • दस्तावेज़ सत्यापन'},
  'auth.encrypted': {'en': 'End-to-end encrypted • Strictly confidential', 'hi': 'एंड-टू-एंड एन्क्रिप्टेड • पूरी तरह गोपनीय'},
  'auth.verifyYourEmail': {'en': 'Verify Your Email', 'hi': 'अपना ईमेल सत्यापित करें'},
  'auth.verifyEmail': {'en': 'Verify Your Email', 'hi': 'अपना ईमेल सत्यापित करें'},
  'auth.enter6Digit': {'en': 'Enter the 6-digit code sent to\n{email}', 'hi': '{email}\nपर भेजा गया 6 अंकों का कोड दर्ज करें'},
  'auth.enterCodeSentTo': {'en': 'Enter the 6-digit code sent to\n{email}', 'hi': '{email}\nपर भेजा गया 6 अंकों का कोड दर्ज करें'},
  'auth.enterComplete6Digit': {'en': 'Please enter the complete 6-digit OTP code', 'hi': 'कृपया पूरा 6 अंकों का ओटीपी कोड दर्ज करें'},
  'auth.codeExpiresIn': {'en': 'Code expires in {time}', 'hi': 'कोड {time} में समाप्त हो जाएगा'},
  'auth.codeExpired': {'en': 'Code has expired', 'hi': 'कोड समाप्त हो चुका है'},
  'auth.verify': {'en': 'Verify', 'hi': 'सत्यापित करें'},
  'auth.didntReceiveCode': {'en': "Didn't receive the code? ", 'hi': 'कोड प्राप्त नहीं हुआ? '},
  'auth.resend': {'en': 'Resend', 'hi': 'पुनः भेजें'},
  'auth.waitCooldown': {'en': 'Wait {seconds}s', 'hi': '{seconds}s प्रतीक्षा करें'},
  'auth.waitSeconds': {'en': 'Wait {seconds}s', 'hi': '{seconds}s प्रतीक्षा करें'},
  'auth.otpSentSuccess': {'en': 'OTP sent successfully', 'hi': 'ओटीपी सफलतापूर्वक भेजा गया'},
  'auth.otpResentSuccess': {'en': 'A new OTP has been sent to your email.', 'hi': 'आपकी ईमेल पर एक नया ओटीपी भेजा गया है।'},
  'auth.otpResendFailed': {'en': 'Failed to resend OTP', 'hi': 'ओटीपी पुनः भेजने में विफल'},
  'auth.resendFailed': {'en': 'Failed to resend verification code. Please try again.', 'hi': 'सत्यापन कोड पुनः भेजने में विफल। कृपया पुन: प्रयास करें।'},
  'auth.enterValidOtp': {'en': 'Please enter a valid 6-digit OTP', 'hi': 'कृपया एक मान्य 6-अंकीय ओटीपी दर्ज करें'},
  'auth.verificationSuccess': {'en': 'Verification successful!', 'hi': 'सत्यापन सफल!'},
  'auth.mobileOtpComingSoon': {
    'en': 'Mobile OTP coming soon. Please use email.',
    'hi': 'मोबाइल ओटीपी जल्द आ रहा है। कृपया ईमेल का उपयोग करें।',
  },
  'auth.invalidOtp': {'en': 'Invalid OTP', 'hi': 'अमान्य ओटीपी'},

  // Share Risk Summary Feature
  'analysis.shareRiskSummary': {'en': 'Share Risk Summary', 'hi': 'जोखिम सारांश साझा करें'},
  'analysis.shareModalTitle': {'en': 'Share Risk Summary', 'hi': 'जोखिम सारांश साझा करें'},
  'analysis.shareModalSubtitle': {
    'en': 'Share a secure, read-only summary of this property legal analysis.',
    'hi': 'इस संपत्ति कानूनी विश्लेषण का एक सुरक्षित, केवल-पढ़ने योग्य सारांश साझा करें।'
  },
  'analysis.shareWhatsApp': {'en': 'Share on WhatsApp', 'hi': 'WhatsApp पर साझा करें'},
  'analysis.shareWhatsAppDesc': {'en': 'Send key findings and link via WhatsApp', 'hi': 'WhatsApp के माध्यम से मुख्य निष्कर्ष और लिंक भेजें'},
  'analysis.shareEmail': {'en': 'Share via Email', 'hi': 'ईमेल द्वारा साझा करें'},
  'analysis.shareEmailDesc': {'en': 'Compose an email with analysis summary & link', 'hi': 'विश्लेषण सारांश और लिंक के साथ एक ईमेल बनाएं'},
  'analysis.copyShareLink': {'en': 'Copy Link', 'hi': 'लिंक कॉपी करें'},
  'analysis.copyShareLinkDesc': {'en': 'Generate and copy a secure read-only URL', 'hi': 'एक सुरक्षित केवल-पढ़ने योग्य लिंक बनाएं और कॉपी करें'},
  'analysis.downloadPdfDesc': {'en': 'Export full analysis report as PDF', 'hi': 'पूर्ण विश्लेषण रिपोर्ट को पीडीएफ के रूप में निर्यात करें'},
  'analysis.linkCopiedSuccess': {'en': 'Share link copied to clipboard!', 'hi': 'साझाकरण लिंक क्लिपबोर्ड पर कॉपी किया गया!'},
  'analysis.shareGenerating': {'en': 'Generating secure share link...', 'hi': 'सुरक्षित साझाकरण लिंक बनाया जा रहा है...'},
  'analysis.shareFailed': {'en': 'Failed to generate share link. Please try again.', 'hi': 'साझाकरण लिंक बनाने में विफल। कृपया पुन: प्रयास करें।'},
  'analysis.sharedReadOnly': {'en': 'Shared Read-Only Risk Summary', 'hi': 'साझा किया गया केवल-पढ़ने योग्य जोखिम सारांश'},
  'analysis.sharedDisclaimer': {
    'en': 'This is a secure, read-only legal risk summary generated by LawBuddy. The underlying document and private owner data remain protected.',
    'hi': 'यह LawBuddy द्वारा उत्पन्न एक सुरक्षित, केवल-पढ़ने योग्य कानूनी जोखिम सारांश है। मूल दस्तावेज़ और निजी डेटा सुरक्षित रहते हैं।'
  },
  'analysis.sharedNotFound': {'en': 'Risk Summary Not Found', 'hi': 'जोखिम सारांश नहीं मिला'},
  'analysis.sharedNotFoundDesc': {
    'en': 'This share link may have expired or been removed.',
    'hi': 'यह साझाकरण लिंक समाप्त हो सकता है या हटा दिया गया हो सकता है।'
  },
  'analysis.scanYourOwnCta': {'en': 'Scan Your Own Agreement', 'hi': 'अपना अनुबंध स्कैन करें'},
  'analysis.allClauses': {'en': 'All Clauses', 'hi': 'सभी खंड'},
  'analysis.statutoryCitations': {'en': 'Statutory Citations', 'hi': 'वैधानिक उद्धरण'},
  'analysis.reraReferences': {'en': 'RERA References', 'hi': 'रेरा संदर्भ'},
  'analysis.buyerImpact': {'en': 'Buyer Impact', 'hi': 'खरीदार पर प्रभाव'},
  'analysis.recommendation': {'en': 'Recommendation', 'hi': 'सिफारिश'},

  // ==========================================
  // Welcome & Landing Screen
  // ==========================================
  'welcome.disclaimerTitle': {'en': 'Legal Disclaimer', 'hi': 'कानूनी अस्वीकरण'},
  'welcome.disclaimerContent': {
    'en': 'This application provides AI-generated information for preliminary document review and educational purposes only. It does not constitute legal advice or create an advocate-client relationship. For important property transactions, consult a qualified legal professional.',
    'hi': 'यह एप्लिकेशन केवल प्रारंभिक दस्तावेज़ समीक्षा और शैक्षिक उद्देश्यों के लिए एआई-जनित जानकारी प्रदान करता है। यह कानूनी सलाह का गठन नहीं करता है और न ही वकील-ग्राहक संबंध बनाता है। महत्वपूर्ण संपत्ति लेनदेन के लिए, किसी योग्य कानूनी पेशेवर से परामर्श लें।',
  },
  'welcome.privacyPolicy': {'en': 'Privacy Policy', 'hi': 'गोपनीयता नीति'},
  'welcome.termsOfUse': {'en': 'Terms of Use', 'hi': 'उपयोग की शर्तें'},
  'welcome.storagePreferences': {'en': 'Storage Preferences', 'hi': 'भंडारण प्राथमिकताएं'},
  'welcome.headerTagline': {'en': 'REAL ESTATE AI TECH', 'hi': 'रियल एस्टेट एआई टेक'},
  'welcome.navFeatures': {'en': 'Features', 'hi': 'सुविधाएं'},
  'welcome.navHowItWorks': {'en': 'How It Works', 'hi': 'यह कैसे काम करता है'},
  'welcome.navRiskSystem': {'en': 'Risk System', 'hi': 'जोखिम प्रणाली'},
  'welcome.navDisclaimer': {'en': 'Disclaimer', 'hi': 'अस्वीकरण'},
  'welcome.signIn': {'en': 'Sign In', 'hi': 'साइन इन'},

  'welcome.heroEyebrowDesktop': {
    'en': 'AI-POWERED LEGALTECH FOR INDIAN REAL ESTATE',
    'hi': 'भारतीय रियल एस्टेट के लिए एआई-संचालित लीगलटेक',
  },
  'welcome.heroEyebrowMobile': {
    'en': 'AI-POWERED REAL ESTATE LEGALTECH',
    'hi': 'एआई-संचालित रियल एस्टेट लीगलटेक',
  },
  'welcome.headlineLine1': {'en': 'UNDERSTAND', 'hi': 'समझें'},
  'welcome.headlineLine2Prefix': {'en': 'YOUR ', 'hi': 'अपनी '},
  'welcome.headlineLine2Accent': {'en': 'PROPERTY', 'hi': 'संपत्ति'},
  'welcome.headlineLine2Full': {'en': 'YOUR PROPERTY', 'hi': 'अपनी संपत्ति'},
  'welcome.headlineLine3': {'en': 'BEFORE YOU SIGN.', 'hi': 'हस्ताक्षर करने से पहले।'},
  'welcome.heroNarrative': {
    'en': 'Analyze real-estate contracts, detect potential legal risks under RERA, and understand complex clauses in plain English — powered by AI built for Indian property law.',
    'hi': 'रियल एस्टेट अनुबंधों का विश्लेषण करें, रेरा के तहत संभावित कानूनी जोखिमों का पता लगाएं, और जटिल खंडों को सरल भाषा में समझें — भारतीय संपत्ति कानून के लिए निर्मित एआई द्वारा संचालित।',
  },
  'welcome.getStarted': {'en': 'Get Started', 'hi': 'शुरू करें'},
  'welcome.alreadyHaveAccount': {'en': 'Already have an account? ', 'hi': 'क्या आपके पास पहले से एक खाता है? '},
  'welcome.signInAction': {'en': 'Sign in', 'hi': 'साइन इन करें'},

  'welcome.sideWordScan': {'en': 'SCAN', 'hi': 'स्कैन'},
  'welcome.sideWordAnalyze': {'en': 'ANALYZE', 'hi': 'विश्लेषण'},
  'welcome.sideWordProtect': {'en': 'PROTECT', 'hi': 'सुरक्षा'},
  'welcome.sideWordUnderstand': {'en': 'UNDERSTAND', 'hi': 'समझें'},
  'welcome.sideWordProperty': {'en': 'PROPERTY', 'hi': 'संपत्ति'},
  'welcome.sideWordRera': {'en': 'RERA', 'hi': 'रेरा'},
  'welcome.sideWordClauses': {'en': 'CLAUSES', 'hi': 'खंड'},
  'welcome.sideWordSecure': {'en': 'SECURE', 'hi': 'सुरक्षित'},

  'welcome.mockDocTitle': {'en': 'PROPERTY SALE AGREEMENT', 'hi': 'संपत्ति बिक्री समझौता'},
  'welcome.aiScanActive': {'en': 'AI Scan Active', 'hi': 'एआई स्कैन सक्रिय'},
  'welcome.mockClauseTitle': {'en': 'Clause 7.2 — Forfeiture', 'hi': 'खंड 7.2 — जब्ती'},
  'welcome.mockRelevantLaw': {'en': 'Relevant Property Law', 'hi': 'प्रासंगिक संपत्ति कानून'},
  'welcome.mockClauseBody': {
    'en': '"In case of delay beyond 30 days, 100% of earnest deposit shall be forfeited without notice."',
    'hi': '"30 दिनों से अधिक की देरी के मामले में, बिना किसी सूचना के 100% बयाना राशि जब्त कर ली जाएगी।"',
  },
  'welcome.mockRiskDetected': {'en': 'High Legal Risk Detected', 'hi': 'उच्च कानूनी जोखिम का पता चला'},
  'welcome.mockRiskScore': {'en': 'Score: 84/100', 'hi': 'स्कोर: 84/100'},
  'welcome.mockPlainEnglish': {
    'en': 'Plain English: The builder can confiscate all your advance money even for minor payment delays.',
    'hi': 'सरल अर्थ: भुगतान में मामूली देरी के लिए भी बिल्डर आपके सारे अग्रिम पैसे जब्त कर सकता है।',
  },

  'welcome.marqueeTrack1': {
    'en': 'SCAN CONTRACTS  ✦  RERA COMPLIANCE AUDIT  ✦  PLAIN-ENGLISH INSIGHTS  ✦  DETECT UNFAIR CLAUSES  ✦  INDIAN PROPERTY LAW  ✦  ',
    'hi': 'अनुबंध स्कैन करें  ✦  रेरा अनुपालन ऑडिट  ✦  सरल भाषा अंतर्दृष्टि  ✦  अनुचित खंडों की पहचान  ✦  भारतीय संपत्ति कानून  ✦  ',
  },
  'welcome.marqueeTrack2': {
    'en': 'STAMP DUTY CALCULATOR  ✦  DUE DILIGENCE CHECKLISTS  ✦  24/7 LEGAL AI CHAT  ✦  EXPORTABLE PDF REPORTS  ✦  TITLE CLEARANCE & OC  ✦  ',
    'hi': 'स्टाम्प शुल्क कैलकुलेटर  ✦  उचित सावधानी चेकलिस्ट  ✦  24/7 कानूनी एआई चैट  ✦  निर्यात योग्य पीडीएफ रिपोर्ट  ✦  शीर्षक मंजूरी और ओसी  ✦  ',
  },

  'welcome.featuresEyebrow': {'en': 'YOUR LEGAL DOCUMENTS, MADE CLEAR.', 'hi': 'आपके कानूनी दस्तावेज़, पूरी तरह स्पष्ट।'},
  'welcome.featuresTitle': {'en': 'Complete Legal Protection Suite', 'hi': 'संपूर्ण कानूनी सुरक्षा सुइट'},
  'welcome.featuresSubtitle': {
    'en': 'Six specialized AI tools built to simplify Indian real estate transactions.',
    'hi': 'भारतीय रियल एस्टेट लेनदेन को सरल बनाने के लिए निर्मित छह विशेष एआई उपकरण।',
  },
  'welcome.featScanTag': {'en': 'OCR & PDF', 'hi': 'ओसीआर और पीडीएफ'},
  'welcome.featScanTitle': {'en': 'Scan & Extract', 'hi': 'स्कैन और निष्कर्षण'},
  'welcome.featScanDesc': {
    'en': 'Upload PDF agreements, capture physical contracts via OCR camera, or paste legal text directly.',
    'hi': 'पीडीएफ अनुबंध अपलोड करें, ओसीआर कैमरे से भौतिक अनुबंध कैप्चर करें, या सीधे कानूनी पाठ पेस्ट करें।',
  },
  'welcome.featRisksTag': {'en': 'AI AUDIT', 'hi': 'एआई ऑडिट'},
  'welcome.featRisksTitle': {'en': 'Detect Legal Risks', 'hi': 'कानूनी जोखिमों का पता लगाएं'},
  'welcome.featRisksDesc': {
    'en': 'Identify potentially unfair, non-compliant, or one-sided builder clauses with RERA-trained AI.',
    'hi': 'रेरा-प्रशिक्षित एआई के साथ संभावित अनुचित, गैर-अनुपालन या एकतरफा बिल्डर खंडों की पहचान करें।',
  },
  'welcome.featPlainEnglishTag': {'en': 'SIMPLIFIED', 'hi': 'सरलीकृत'},
  'welcome.featPlainEnglishTitle': {'en': 'Plain-English Insights', 'hi': 'सरल भाषा अंतर्दृष्टि'},
  'welcome.featPlainEnglishDesc': {
    'en': 'Demystify dense legal jargon into 2-3 sentence layman explanations and negotiation advice.',
    'hi': 'जटिल कानूनी शब्दावली को 2-3 वाक्यों के सरल स्पष्टीकरण और बातचीत की सलाह में बदलें।',
  },
  'welcome.featCalculatorTag': {'en': 'STATE-WISE', 'hi': 'राज्य-वार'},
  'welcome.featCalculatorTitle': {'en': 'Stamp Duty Calculator', 'hi': 'स्टाम्प शुल्क कैलकुलेटर'},
  'welcome.featCalculatorDesc': {
    'en': 'Compute state-wise stamp duty, registration charges, local cess, and female buyer discounts across India.',
    'hi': 'पूरे भारत में राज्य-वार स्टाम्प शुल्क, पंजीकरण शुल्क, स्थानीय उपकर और महिला खरीदार छूट की गणना करें।',
  },
  'welcome.featChatTag': {'en': '24/7 CHAT', 'hi': '24/7 चैट'},
  'welcome.featChatTitle': {'en': 'AI Legal Assistant', 'hi': 'एआई कानूनी सहायक'},
  'welcome.featChatDesc': {
    'en': 'Get instant 24/7 answers on property laws, tenancy disputes, builder notices, and contract clauses.',
    'hi': 'संपत्ति कानूनों, किरायेदारी विवादों, बिल्डर नोटिस और अनुबंध खंडों पर 24/7 त्वरित उत्तर प्राप्त करें।',
  },
  'welcome.featChecklistTag': {'en': 'CHECKLIST', 'hi': 'चेकलिस्ट'},
  'welcome.featChecklistTitle': {'en': 'Due Diligence Checklists', 'hi': 'उचित सावधानी चेकलिस्ट'},
  'welcome.featChecklistDesc': {
    'en': 'Step-by-step buyer verification covering title clearance, RERA approvals, encumbrance & OC records.',
    'hi': 'शीर्षक मंजूरी, रेरा अनुमोदन, भार प्रमाणपत्र और ओसी रिकॉर्ड को कवर करने वाला चरण-दर-चरण सत्यापन।',
  },

  'welcome.howEyebrow': {'en': 'SIMPLE 4-STEP PROCESS', 'hi': 'सरल 4-चरणीय प्रक्रिया'},
  'welcome.howTitle': {'en': 'How It Works', 'hi': 'यह कैसे काम करता है'},
  'welcome.step1Title': {'en': 'Upload Agreement', 'hi': 'अनुबंध अपलोड करें'},
  'welcome.step1Desc': {
    'en': 'Upload your property agreement, sale deed, or rental contract.',
    'hi': 'अपना संपत्ति समझौता, बिक्री विलेख, या किराया अनुबंध अपलोड करें।',
  },
  'welcome.step2Title': {'en': 'AI Contract Scan', 'hi': 'एआई अनुबंध स्कैन'},
  'welcome.step2Desc': {
    'en': 'AI examines the text and evaluates statutory RERA compliance.',
    'hi': 'एआई पाठ की जांच करता है और वैधानिक रेरा अनुपालन का मूल्यांकन करता है।',
  },
  'welcome.step3Title': {'en': 'Plain-English Insights', 'hi': 'सरल भाषा अंतर्दृष्टि'},
  'welcome.step3Desc': {
    'en': 'Get plain-English explanations and flagged risk highlights.',
    'hi': 'सरल भाषा स्पष्टीकरण और चिह्नित जोखिम हाइलाइट प्राप्त करें।',
  },
  'welcome.step4Title': {'en': 'Legal Audit Report', 'hi': 'कानूनी ऑडिट रिपोर्ट'},
  'welcome.step4Desc': {
    'en': 'Generate and download a structured legal risk assessment PDF.',
    'hi': 'एक संरचित कानूनी जोखिम मूल्यांकन पीडीएफ तैयार करें और डाउनलोड करें।',
  },

  'welcome.riskEyebrow': {'en': 'AI-POWERED AUDIT PREVIEW', 'hi': 'एआई-संचालित ऑडिट पूर्वावलोकन'},
  'welcome.riskTitle': {'en': 'See What LawBuddy Finds', 'hi': 'देखें LawBuddy क्या खोजता है'},
  'welcome.riskSubtitle': {
    'en': 'Our RERA-trained engine inspects agreement clauses line-by-line to flag unfair conditions, non-compliant timelines, and asymmetric liabilities.',
    'hi': 'हमारा रेरा-प्रशिक्षित इंजन अनुचित शर्तों, गैर-अनुपालन समय-सीमाओं और एकतरफा देनदारियों को चिह्नित करने के लिए अनुबंध खंडों का पंक्ति-दर-पंक्ति निरीक्षण करता है।',
  },
  'welcome.riskDocExtract': {'en': 'AGREEMENT FOR SALE (EXTRACT)', 'hi': 'बिक्री के लिए समझौता (अंश)'},
  'welcome.riskPotentialRisk': {'en': 'POTENTIAL RISK DETECTED', 'hi': 'संभावित जोखिम का पता चला'},
  'welcome.riskClauseTitle': {'en': 'Clause 7.2 — Default & Forfeiture of Earnest Deposit', 'hi': 'खंड 7.2 — डिफ़ॉल्ट और बयाना राशि की जब्ती'},
  'welcome.riskClauseBody': {
    'en': '"In the event of any delay in milestone payment exceeding 15 days, the Promoter shall have the unilateral right to cancel the allotment and forfeit 100% of the Earnest Money Deposit and accrued interest without further notice."',
    'hi': '"15 दिनों से अधिक के माइलस्टोन भुगतान में किसी भी देरी की स्थिति में, प्रमोटर को बिना किसी पूर्व सूचना के आवंटन रद्द करने और बयाना राशि और अर्जित ब्याज का 100% जब्त करने का एकतरफा अधिकार होगा।"',
  },
  'welcome.riskStatutoryDesc': {
    'en': 'Excessive forfeiture clause exceeds statutory 10% ceiling prescribed under Section 13(1) of RERA Model Rules.',
    'hi': 'अत्यधिक जब्ती खंड रेरा मॉडल नियमों की धारा 13(1) के तहत निर्धारित वैधानिक 10% सीमा से अधिक है।',
  },
  'welcome.riskAssessmentTitle': {'en': 'AI Legal Risk Assessment', 'hi': 'एआई कानूनी जोखिम मूल्यांकन'},
  'welcome.riskScoreElevated': {'en': '{score} / 100 • Elevated', 'hi': '{score} / 100 • बढ़ा हुआ'},
  'welcome.riskHighBadge': {'en': '🔴 High Risk', 'hi': '🔴 उच्च जोखिम'},
  'welcome.riskHighDesc': {'en': 'Clause 7.2: Unilateral earnest forfeiture (100%)', 'hi': 'खंड 7.2: एकतरफा बयाना जब्ती (100%)'},
  'welcome.riskCautionBadge': {'en': '🟡 Caution', 'hi': '🟡 सावधानी'},
  'welcome.riskCautionDesc': {'en': 'Clause 14.1: Asymmetric delay penalty compensation', 'hi': 'खंड 14.1: असममित विलंब जुर्माना मुआवजा'},
  'welcome.riskStandardBadge': {'en': '🟢 Standard', 'hi': '🟢 मानक'},
  'welcome.riskStandardDesc': {'en': 'Clause 3.1: Carpet area specification & RERA warranty', 'hi': 'खंड 3.1: कारपेट एरिया विनिर्देश और रेरा वारंटी'},
  'welcome.riskRecommendation': {
    'en': 'Recommendation: Demand amendment to restrict forfeiture to max 10% of total consideration as per standard MahaRERA guidelines.',
    'hi': 'सिफारिश: मानक महा-रेरा दिशानिर्देशों के अनुसार जब्ती को कुल प्रतिफल के अधिकतम 10% तक सीमित करने के लिए संशोधन की मांग करें।',
  },

  'welcome.ctaTitle': {'en': 'Before You Sign,\nKnow What You\'re Signing.', 'hi': 'हस्ताक्षर करने से पहले,\nजानें कि आप क्या हस्ताक्षर कर रहे हैं।'},
  'welcome.ctaSubtitle': {
    'en': 'Upload your property document and let LawBuddy help you understand the clauses, risks, and important legal considerations.',
    'hi': 'अपना संपत्ति दस्तावेज़ अपलोड करें और LawBuddy को खंडों, जोखिमों और महत्वपूर्ण कानूनी विचारों को समझने में आपकी मदद करने दें।',
  },
  'welcome.ctaExplore': {'en': 'Explore Features', 'hi': 'सुविधाएं देखें'},
  'welcome.ctaAnalyze': {'en': 'Analyze Your Document →', 'hi': 'अपना दस्तावेज़ जांचें →'},

  // ==========================================
  // Admin Analytics Screen
  // ==========================================
  'adminAnalytics.badge': {'en': 'ADMIN', 'hi': 'एडमिन'},
  'adminAnalytics.title': {'en': 'Admin Analytics', 'hi': 'व्यवस्थापक विश्लेषण'},
  'adminAnalytics.subtitle': {'en': 'LawBuddy System Insights', 'hi': 'LawBuddy सिस्टम अंतर्दृष्टि'},
  'adminAnalytics.refreshTooltip': {'en': 'Refresh Analytics', 'hi': 'विश्लेषण ताज़ा करें'},
  'adminAnalytics.loadingText': {'en': 'Aggregating system telemetry & insights...', 'hi': 'सिस्टम टेलीमेट्री और अंतर्दृष्टि एकत्रित की जा रही है...'},
  'adminAnalytics.kpiTotalUsers': {'en': 'Total Users', 'hi': 'कुल उपयोगकर्ता'},
  'adminAnalytics.kpiTotalUsersSub': {'en': 'Registered accounts', 'hi': 'पंजीकृत खाते'},
  'adminAnalytics.kpiDocsAnalyzed': {'en': 'Docs Analyzed', 'hi': 'विश्लेषित दस्तावेज़'},
  'adminAnalytics.kpiDocsAnalyzedSub': {'en': 'Completed analyses', 'hi': 'पूर्ण विश्लेषण'},
  'adminAnalytics.kpiClausesEvaluated': {'en': 'Clauses Evaluated', 'hi': 'मूल्यांकित खंड'},
  'adminAnalytics.kpiClausesEvaluatedSub': {'en': 'Total legal clauses', 'hi': 'कुल कानूनी खंड'},
  'adminAnalytics.kpiAvgPages': {'en': 'Avg. Pages', 'hi': 'औसत पृष्ठ'},
  'adminAnalytics.kpiAvgPagesSub': {'en': 'Pages per contract', 'hi': 'प्रति अनुबंध पृष्ठ'},
  'adminAnalytics.supportingActivity': {'en': 'Supporting Activity:', 'hi': 'सहायक गतिविधि:'},
  'adminAnalytics.chatSessions': {'en': 'Chat Sessions', 'hi': 'चैट सत्र'},
  'adminAnalytics.diligenceChecklists': {'en': 'Diligence Checklists', 'hi': 'सावधानी चेकलिस्ट'},
  'adminAnalytics.riskSectionTitle': {'en': 'Risk Classification & Distribution', 'hi': 'जोखिम वर्गीकरण और वितरण'},
  'adminAnalytics.riskSectionSub': {
    'en': 'Dual-level evaluation: Overall Contract Risk vs. Granular Clause Severity',
    'hi': 'दोहरे स्तर का मूल्यांकन: समग्र अनुबंध जोखिम बनाम सूक्ष्म खंड गंभीरता',
  },
  'adminAnalytics.docRiskTitle': {'en': 'Document-Level Risk', 'hi': 'दस्तावेज़-स्तरीय जोखिम'},
  'adminAnalytics.docsCount': {'en': '{count} docs', 'hi': '{count} दस्तावेज़'},
  'adminAnalytics.highRiskDocs': {'en': 'High Risk Documents', 'hi': 'उच्च जोखिम वाले दस्तावेज़'},
  'adminAnalytics.mediumRiskDocs': {'en': 'Medium Risk Documents', 'hi': 'मध्यम जोखिम वाले दस्तावेज़'},
  'adminAnalytics.lowRiskDocs': {'en': 'Low Risk Documents', 'hi': 'कम जोखिम वाले दस्तावेज़'},
  'adminAnalytics.clauseSeverityTitle': {'en': 'Clause-Level Severity', 'hi': 'खंड-स्तरीय गंभीरता'},
  'adminAnalytics.clausesCount': {'en': '{count} clauses', 'hi': '{count} खंड'},
  'adminAnalytics.highRiskClauses': {'en': 'HIGH_RISK Clauses', 'hi': 'उच्च जोखिम वाले खंड'},
  'adminAnalytics.cautionClauses': {'en': 'CAUTION Clauses', 'hi': 'सावधानी खंड'},
  'adminAnalytics.compliantClauses': {'en': 'COMPLIANT Clauses', 'hi': 'अनुपालन वाले खंड'},
  'adminAnalytics.findingCategoriesTitle': {'en': 'Legal Issue Categories Breakdown', 'hi': 'कानूनी मुद्दा श्रेणियां विभाजन'},
  'adminAnalytics.findingCategoriesSub': {
    'en': 'Actual categorized findings identified during contract analysis',
    'hi': 'अनुबंध विश्लेषण के दौरान पहचाने गए वास्तविक वर्गीकृत निष्कर्ष',
  },
  'adminAnalytics.catClausesCount': {'en': '{count} clauses ({percent}%)', 'hi': '{count} खंड ({percent}%)'},
  'adminAnalytics.emptyCategories': {'en': 'No categorized clause issues recorded yet.', 'hi': 'अभी तक कोई वर्गीकृत खंड मुद्दा दर्ज नहीं किया गया है।'},
  'adminAnalytics.pipelineTitle': {'en': 'Ingestion & Extraction Pipeline Insights', 'hi': 'इनजेशन और निष्कर्षण पाइपलाइन अंतर्दृष्टि'},
  'adminAnalytics.pipelineSub': {
    'en': 'Distribution of uploaded document formats and extraction engines',
    'hi': 'अपलोड किए गए दस्तावेज़ प्रारूपों और निष्कर्षण इंजनों का वितरण',
  },
  'adminAnalytics.sourceTypesTitle': {'en': 'Document Source Types', 'hi': 'दस्तावेज़ स्रोत प्रकार'},
  'adminAnalytics.extractionMethodsTitle': {'en': 'Extraction Pipeline Methods', 'hi': 'निष्कर्षण पाइपलाइन विधियां'},
  'adminAnalytics.recentActivityTitle': {'en': 'Recent Analysis Activity Feed', 'hi': 'हालिया विश्लेषण गतिविधि फ़ीड'},
  'adminAnalytics.recentActivitySub': {
    'en': 'Real-time telemetry of completed document risk evaluations (sanitized metadata)',
    'hi': 'पूर्ण दस्तावेज़ जोखिम मूल्यांकनों की वास्तविक समय टेलीमेट्री (स्वच्छ मेटाडेटा)',
  },
  'adminAnalytics.emptyRecentScans': {'en': 'No recent document analysis telemetry recorded.', 'hi': 'कोई हालिया दस्तावेज़ विश्लेषण टेलीमेट्री दर्ज नहीं की गई है।'},
  'adminAnalytics.pagesUnitSingular': {'en': 'page', 'hi': 'पृष्ठ'},
  'adminAnalytics.pagesUnitPlural': {'en': 'pages', 'hi': 'पृष्ठ'},
  'adminAnalytics.riskBreakdownCompact': {'en': '{high}H • {caution}C • {compliant}OK', 'hi': '{high}उच्च • {caution}सावधान • {compliant}सही'},
  'adminAnalytics.justNow': {'en': 'Just now', 'hi': 'अभी'},
  'adminAnalytics.minutesAgo': {'en': '{minutes}m ago', 'hi': '{minutes} मि. पहले'},
  'adminAnalytics.hoursAgo': {'en': '{hours}h ago', 'hi': '{hours} घंटे पहले'},
  'adminAnalytics.daysAgo': {'en': '{days}d ago', 'hi': '{days} दिन पहले'},
  'adminAnalytics.accessRestricted': {'en': 'Access Restricted', 'hi': 'पहुंच प्रतिबंधित है'},
  'adminAnalytics.accessRestrictedDesc': {
    'en': 'You do not have administrator permissions to access the system analytics dashboard. Only verified administrators can view system-wide telemetry.',
    'hi': 'सिस्टम एनालिटिक्स डैशबोर्ड तक पहुंचने के लिए आपके पास व्यवस्थापक अनुमतियां नहीं हैं। केवल सत्यापित व्यवस्थापक ही सिस्टम-व्यापी टेलीमेट्री देख सकते हैं।',
  },
  'adminAnalytics.returnToWorkspace': {'en': 'Return to Workspace', 'hi': 'कार्यस्थान पर वापस जाएं'},
  'adminAnalytics.loadFailed': {'en': 'Failed to Load Analytics', 'hi': 'एनालिटिक्स लोड करने में विफल'},
  'adminAnalytics.unexpectedError': {'en': 'An unexpected network error occurred.', 'hi': 'एक अप्रत्याशित नेटवर्क त्रुटि हुई।'},
  'adminAnalytics.retryConnection': {'en': 'Retry Connection', 'hi': 'कनेक्शन का पुनः प्रयास करें'},
  'adminAnalytics.emptyTelemetry': {'en': 'No Analytics Telemetry Available', 'hi': 'कोई एनालिटिक्स टेलीमेट्री उपलब्ध नहीं है'},
  'adminAnalytics.emptyTelemetryDesc': {
    'en': 'As users upload and evaluate real estate contracts, system metrics will populate here in real time.',
    'hi': 'जैसे-जैसे उपयोगकर्ता रियल एस्टेट अनुबंध अपलोड और मूल्यांकन करेंगे, सिस्टम मेट्रिक्स यहां वास्तविक समय में दिखाई देंगे।',
  },
  'adminAnalytics.refreshBtn': {'en': 'Refresh', 'hi': 'ताज़ा करें'},

  // ==========================================
  // Document Comparison Screen
  // ==========================================
  'docComparison.initializing': {'en': 'Initializing...', 'hi': 'आरंभ किया जा रहा है...'},
  'docComparison.startingComparison': {'en': 'Starting comparison...', 'hi': 'तुलना शुरू हो रही है...'},
  'docComparison.processing': {'en': 'Processing...', 'hi': 'प्रक्रिया जारी है...'},
  'docComparison.timeoutError': {
    'en': 'This comparison is taking longer than expected. It may still finish in the background — check back shortly, or try again.',
    'hi': 'इस तुलना में अपेक्षा से अधिक समय लग रहा है। यह पृष्ठभूमि में समाप्त हो सकता है — थोड़ी देर बाद जांचें, या पुनः प्रयास करें।',
  },
  'docComparison.failedError': {'en': 'Comparison failed.', 'hi': 'तुलना विफल रही।'},
  'docComparison.lostConnectionError': {
    'en': 'Lost connection while checking comparison status. Please check your connection and try again.',
    'hi': 'तुलना स्थिति की जांच करते समय कनेक्शन टूट गया। कृपया अपना कनेक्शन जांचें और पुनः प्रयास करें।',
  },
  'docComparison.selectBothError': {
    'en': 'Please select both Version A and Version B documents.',
    'hi': 'कृपया संस्करण A और संस्करण B दोनों दस्तावेज़ चुनें।',
  },
  'docComparison.selectDistinctError': {
    'en': 'Please select two distinct versions to compare.',
    'hi': 'कृपया तुलना करने के लिए दो अलग-अलग संस्करण चुनें।',
  },
  'docComparison.startError': {
    'en': 'Unable to start document comparison. Please check your connection and try again.',
    'hi': 'दस्तावेज़ तुलना शुरू करने में असमर्थ। कृपया अपना कनेक्शन जांचें और पुनः प्रयास करें।',
  },
  'docComparison.appBarTitle': {'en': 'Compare Agreements', 'hi': 'समझौतों की तुलना करें'},
  'docComparison.heading': {'en': 'Contract Differential Analysis', 'hi': 'अनुबंध अंतर विश्लेषण'},
  'docComparison.subheading': {
    'en': 'Select two agreement drafts to identify modified clauses, added obligations, deleted buyer protections, and risk escalations.',
    'hi': 'संशोधित खंडों, जोड़े गए दायित्वों, हटाए गए खरीदार सुरक्षा उपायों और जोखिम वृद्धि की पहचान करने के लिए दो समझौते के प्रारूप चुनें।',
  },
  'docComparison.processingDesc': {
    'en': 'Analyzing clause alignments, numbers, dates, and legal statutory impact...',
    'hi': 'खंड संरेखण, संख्याओं, तिथियों और कानूनी वैधानिक प्रभाव का विश्लेषण किया जा रहा है...',
  },
  'docComparison.versionALabel': {
    'en': 'Version A (Baseline / Before Negotiation)',
    'hi': 'संस्करण A (मूल / बातचीत से पहले)',
  },
  'docComparison.versionBLabel': {
    'en': 'Version B (Revised / After Negotiation)',
    'hi': 'संस्करण B (संशोधित / बातचीत के बाद)',
  },
  'docComparison.loadDocsError': {
    'en': 'Couldn\'t load your documents. Check your connection and try again.',
    'hi': 'आपके दस्तावेज़ लोड नहीं हो सके। अपना कनेक्शन जांचें और पुनः प्रयास करें।',
  },
  'docComparison.noDocs': {
    'en': 'No scanned documents found in your workspace.',
    'hi': 'आपके कार्यस्थान में कोई स्कैन किए गए दस्तावेज़ नहीं मिले।',
  },
  'docComparison.scanNewBtn': {'en': 'Scan New Agreement', 'hi': 'नया समझौता स्कैन करें'},
  'docComparison.chooseVersionHint': {'en': 'Choose document version', 'hi': 'दस्तावेज़ संस्करण चुनें'},
  'docComparison.untitledDoc': {'en': 'Untitled Agreement', 'hi': 'शीर्षकहीन समझौता'},
  'docComparison.runAnalysisBtn': {'en': 'Run Differential Analysis', 'hi': 'अंतर विश्लेषण चलाएं'},
  // Doc comparison key aliases for complete runtime compatibility
  'docComparison.headerTitle': {'en': 'Contract Differential Analysis', 'hi': 'अनुबंध अंतर विश्लेषण'},
  'docComparison.headerSubtitle': {
    'en': 'Select two agreement drafts to identify modified clauses, added obligations, deleted buyer protections, and risk escalations.',
    'hi': 'संशोधित खंडों, जोड़े गए दायित्वों, हटाए गए खरीदार सुरक्षा उपायों और जोखिम वृद्धि की पहचान करने के लिए दो समझौते के प्रारूप चुनें।',
  },
  'docComparison.processingSubtitle': {
    'en': 'Analyzing clause alignments, numbers, dates, and legal statutory impact...',
    'hi': 'खंड संरेखण, संख्याओं, तिथियों और कानूनी वैधानिक प्रभाव का विश्लेषण किया जा रहा है...',
  },
  'docComparison.connectionLost': {
    'en': 'Lost connection while checking comparison status. Please check your connection and try again.',
    'hi': 'तुलना स्थिति की जांच करते समय कनेक्शन टूट गया। कृपया अपना कनेक्शन जांचें और पुनः प्रयास करें।',
  },
  'docComparison.selectBothPrompt': {
    'en': 'Please select both Version A and Version B documents.',
    'hi': 'कृपया संस्करण A और संस्करण B दोनों दस्तावेज़ चुनें।',
  },
  'docComparison.selectDistinctPrompt': {
    'en': 'Please select two distinct versions to compare.',
    'hi': 'कृपया तुलना करने के लिए दो अलग-अलग संस्करण चुनें।',
  },
  'docComparison.loadFailed': {
    'en': 'Couldn\'t load your documents. Check your connection and try again.',
    'hi': 'आपके दस्तावेज़ लोड नहीं हो सके। अपना कनेक्शन जांचें और पुनः प्रयास करें।',
  },
  'docComparison.noScannedDocs': {
    'en': 'No scanned documents found in your workspace.',
    'hi': 'आपके कार्यस्थान में कोई स्कैन किए गए दस्तावेज़ नहीं मिले।',
  },
  'docComparison.scanNewAgreement': {'en': 'Scan New Agreement', 'hi': 'नया समझौता स्कैन करें'},
  'docComparison.chooseVersion': {'en': 'Choose document version', 'hi': 'दस्तावेज़ संस्करण चुनें'},
  'docComparison.untitledAgreement': {'en': 'Untitled Agreement', 'hi': 'शीर्षकहीन समझौता'},
  'docComparison.runAnalysis': {'en': 'Run Differential Analysis', 'hi': 'अंतर विश्लेषण चलाएं'},

  // ==========================================
  // Chat Citations & Chat Screen Additions
  // ==========================================
  'chatCitation.openLinkError': {
    'en': 'Unable to open citation link. Please try again.',
    'hi': 'उद्धरण लिंक खोलने में असमर्थ। कृपया पुनः प्रयास करें।',
  },
  'chatCitation.sourcesHeader': {
    'en': 'Authoritative Legal Sources ({count})',
    'hi': 'प्रामाणिक कानूनी स्रोत ({count})',
  },
  'chatCitation.ragGrounded': {'en': 'RAG Grounded', 'hi': 'RAG आधारित'},
  'chatCitation.statutoryLaw': {'en': 'Statutory Law', 'hi': 'वैधानिक कानून'},
  'chatCitation.secPrefix': {'en': 'Sec {section}', 'hi': 'धारा {section}'},
  'chatCitation.officialLaw': {'en': 'Official Law', 'hi': 'आधिकारिक कानून'},
  'chatCitation.officialSource': {'en': 'Official Source', 'hi': 'आधिकारिक स्रोत'},
  'chatCitation.defaultJurisdiction': {'en': 'India', 'hi': 'भारत'},

  'chat.loadSessionsError': {
    'en': 'Unable to load previous conversations. Please check your connection and try again.',
    'hi': 'पिछली बातचीत लोड करने में असमर्थ। कृपया अपना कनेक्शन जांचें और पुनः प्रयास करें।',
  },
  'chat.loadSessionDetailsError': {
    'en': 'Unable to load this conversation. Please try again.',
    'hi': 'इस बातचीत को लोड करने में असमर्थ। कृपया पुनः प्रयास करें।',
  },
  'chat.defaultAiReply': {
    'en': 'I have reviewed your legal request.',
    'hi': 'मैंने आपके कानूनी अनुरोध की समीक्षा कर ली है।',
  },
  'chat.assistantUnavailable': {
    'en': 'The Legal AI Assistant is temporarily unavailable. Please check your internet connection and try again.',
    'hi': 'कानूनी एआई सहायक अस्थायी रूप से अनुपलब्ध है। कृपया अपना इंटरनेट कनेक्शन जांचें और पुनः प्रयास करें।',
  },
  'chat.topBarBadge': {
    'en': '24/7 LEGAL AI ASSISTANT • RERA SPECIALIST',
    'hi': '24/7 कानूनी एआई सहायक • रेरा विशेषज्ञ',
  },

  'home.defaultUserName': {'en': 'User', 'hi': 'उपयोगकर्ता'},
  'home.openLinkError': {
    'en': 'Unable to open this link. Please try again.',
    'hi': 'इस लिंक को खोलने में असमर्थ। कृपया पुनः प्रयास करें।',
  },

  // ==========================================
  // Cookie & Privacy Storage Consent
  // ==========================================
  'consent.privacyPreferences': {'en': 'Privacy preferences', 'hi': 'गोपनीयता प्राथमिकताएं'},
  'consent.bannerDescription': {
    'en': 'We use essential browser storage to keep LawBuddy working and remember your preferences.',
    'hi': 'हम LawBuddy को चालू रखने और आपकी प्राथमिकताओं को याद रखने के लिए आवश्यक ब्राउज़र स्टोरेज का उपयोग करते हैं।',
  },
  'consent.customize': {'en': 'Customize', 'hi': 'अनुकूलित करें'},
  'consent.necessaryOnly': {'en': 'Necessary Only', 'hi': 'केवल आवश्यक'},
  'consent.acceptPreferences': {'en': 'Accept Preferences', 'hi': 'प्राथमिकताएं स्वीकार करें'},
  'consent.acceptAll': {'en': 'Accept All', 'hi': 'सभी स्वीकार करें'},
  'consent.savePreferences': {'en': 'Save Preferences', 'hi': 'प्राथमिकताएं सहेजें'},
  'consent.privacyStoragePrefTitle': {
    'en': 'Privacy & Storage Preferences',
    'hi': 'गोपनीयता और संग्रहण प्राथमिकताएं',
  },
  'consent.privacyStoragePrefIntro': {
    'en': 'Configure how LawBuddy uses local storage to store data on your device. Strictly necessary tokens cannot be disabled as they are required for account security.',
    'hi': 'कॉन्फ़िगर करें कि LawBuddy आपके डिवाइस पर डेटा संग्रहीत करने के लिए स्थानीय संग्रहण का उपयोग कैसे करता है। कड़ाई से आवश्यक टोकन अक्षम नहीं किए जा सकते क्योंकि वे खाता सुरक्षा के लिए आवश्यक हैं।',
  },
  'consent.strictlyNecessaryTitle': {'en': 'STRICTLY NECESSARY', 'hi': 'कड़ाई से आवश्यक'},
  'consent.alwaysOnBadge': {'en': 'Always On', 'hi': 'हमेशा चालू'},
  'consent.strictlyNecessaryDesc': {
    'en': 'Required for authentication and core LawBuddy functionality.',
    'hi': 'प्रमाणीकरण और मुख्य LawBuddy कार्यक्षमता के लिए आवश्यक।',
  },
  'consent.functionalPrefTitle': {'en': 'FUNCTIONAL / PREFERENCES', 'hi': 'कार्यात्मक / प्राथमिकताएं'},
  'consent.functionalPrefDesc': {
    'en': 'Remember theme and language preferences across sessions.',
    'hi': 'सत्रों के दौरान थीम और भाषा प्राथमिकताओं को याद रखें।',
  },
  'consent.analyticsTitle': {'en': 'ANALYTICS', 'hi': 'एनालिटिक्स'},
  'consent.notCurrentlyUsedBadge': {'en': 'Not currently used', 'hi': 'वर्तमान में उपयोग नहीं किया गया'},
  'consent.analyticsDesc': {
    'en': 'We do not collect usage telemetry or run analytics trackers.',
    'hi': 'हम उपयोग टेलीमेट्री एकत्र नहीं करते हैं या एनालिटिक्स ट्रैकर्स नहीं चलाते हैं।',
  },
  'consent.marketingTitle': {'en': 'MARKETING', 'hi': 'मार्केटिंग'},
  'consent.marketingDesc': {
    'en': 'We do not display third-party advertisements or tracking pixels.',
    'hi': 'हम तृतीय-पक्ष विज्ञापन या ट्रैकिंग पिक्सेल प्रदर्शित नहीं करते हैं।',
  },
  'consent.readFullPrivacyPolicy': {'en': 'Read our full Privacy Policy', 'hi': 'हमारी पूरी गोपनीयता नीति पढ़ें'},
};
