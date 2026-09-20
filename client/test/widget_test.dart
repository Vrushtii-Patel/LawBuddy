import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:legal_scanner/screens/home_screen.dart';
import 'package:legal_scanner/screens/chat_screen.dart';
import 'package:legal_scanner/screens/analysis_screen.dart';
import 'package:legal_scanner/screens/welcome_screen.dart';

import 'package:legal_scanner/screens/recent_documents_screen.dart';
import 'package:legal_scanner/screens/checklists_list_screen.dart';
import 'package:legal_scanner/screens/checklist_screen.dart';
import 'package:legal_scanner/screens/privacy_policy_screen.dart';
import 'package:legal_scanner/screens/terms_of_use_screen.dart';
import 'package:legal_scanner/screens/login_screen.dart';
import 'package:legal_scanner/screens/signup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:legal_scanner/providers/consent_provider.dart';
import 'package:legal_scanner/providers/theme_provider.dart';
import 'package:legal_scanner/providers/locale_provider.dart';
import 'package:legal_scanner/screens/stamp_duty_calculator_screen.dart';
import 'package:legal_scanner/screens/scan_screen.dart';
import 'package:legal_scanner/widgets/cookie_consent_banner.dart';
import 'package:legal_scanner/widgets/form_consent_widget.dart';
import 'package:legal_scanner/theme/app_theme.dart';

void main() {
  testWidgets('RecentDocumentsScreen renders with summary stats, search, and documents', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final sampleDocs = [
      {
        '_id': 'doc_001',
        'title': 'Dahanu Flat Sale Deed.pdf',
        'riskLevel': 'High Risk',
        'docSize': '14.3 MB',
        'createdAt': DateTime.now().toIso8601String(),
        'sourceType': 'PDF Document',
        'originalText': 'Sample text',
        'analysis': [],
      },
      {
        '_id': 'doc_002',
        'title': 'Commercial Lease Agreement.pdf',
        'riskLevel': 'Compliant',
        'docSize': '2.1 MB',
        'createdAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'sourceType': 'PDF Document',
        'originalText': 'Sample text 2',
        'analysis': [],
      },
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: RecentDocumentsScreen(initialDocs: sampleDocs),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(RecentDocumentsScreen), findsOneWidget);
    expect(find.text('Recent Documents'), findsOneWidget);
    expect(find.text('Document Legal Repository'), findsOneWidget);
    expect(find.text('Dahanu Flat Sale Deed.pdf'), findsOneWidget);
    expect(find.text('Commercial Lease Agreement.pdf'), findsOneWidget);
    expect(find.text('High Risk'), findsWidgets);
    expect(find.text('Compliant'), findsWidgets);
    expect(find.text('Scan New Document'), findsOneWidget);
  });

  testWidgets('RecentDocumentsScreen document card three-dot menu displays all 6 options in correct order', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final sampleDocs = [
      {
        '_id': 'doc_001',
        'title': 'Dahanu Flat Sale Deed.pdf',
        'riskLevel': 'High Risk',
        'docSize': '14.3 MB',
        'createdAt': DateTime.now().toIso8601String(),
        'sourceType': 'PDF Document',
        'originalText': 'Sample text',
        'analysis': [],
      },
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: RecentDocumentsScreen(initialDocs: sampleDocs),
        ),
      ),
    );

    await tester.pump();

    // Find the three dot button
    final menuButton = find.byIcon(Icons.more_vert_rounded);
    expect(menuButton, findsOneWidget);

    // Tap to open popup menu
    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    // Verify all 6 options exist
    expect(find.text('View Document'), findsOneWidget);
    expect(find.text('View Analysis'), findsOneWidget);
    expect(find.text('Download Risk Report'), findsOneWidget);
    expect(find.text('Rename Document'), findsOneWidget);
    expect(find.text('Re-analyze Document'), findsOneWidget);
    expect(find.text('Delete Document'), findsOneWidget);

    // Verify icons
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
  });
  testWidgets('WelcomeScreen renders hero, CTA, features, and risk sections on Desktop', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: WelcomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Scan & Extract'), findsOneWidget);
    expect(find.text('Detect Legal Risks'), findsOneWidget);
    expect(find.text('Plain-English Insights'), findsWidgets);
  });

  testWidgets('WelcomeScreen renders on Mobile without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: WelcomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('HomeScreen builds on Desktop (1200x900)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('OVERVIEW'), findsOneWidget);
    expect(find.text('WORKSPACE'), findsOneWidget);
    expect(find.text('LEGAL TOOLS'), findsOneWidget);
    expect(find.text('LEGAL INFORMATION'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Risk Analysis'), findsOneWidget);
    expect(find.text('Checklists'), findsOneWidget);
    expect(find.text('Legal AI'), findsOneWidget);
    expect(find.text('Stamp Duty Calculator'), findsOneWidget);
    expect(find.text('RERA & Compliance'), findsOneWidget);
    expect(find.text('Latest Document Analysis'), findsOneWidget);
    expect(find.text('Legal Risk Breakdown'), findsOneWidget);
    expect(find.text('Due Diligence Checklist'), findsOneWidget);
  });

  testWidgets('HomeScreen builds on Mobile (375x812) without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Latest Document Analysis'), findsOneWidget);
    expect(find.text('Legal Risk Breakdown'), findsOneWidget);
    expect(find.text('Due Diligence Checklist'), findsOneWidget);
  });

  testWidgets('ChatScreen builds without overflowing on desktop/mobile', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ChatScreen(),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.textContaining('LEGAL AI ASSISTANT'), findsWidgets);
  });

  testWidgets('AnalysisScreen renders with summary and Export PDF button', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AnalysisScreen(
            documentTitle: 'Sample Rental Agreement',
            originalText: 'The tenant must pay 10 months security deposit.',
            analysis: [
              {
                'text': 'The tenant must pay 10 months security deposit.',
                'category': 'Yellow',
                'reason': 'Excessive security deposit under standard Model Tenancy Act guidance.'
              }
            ],
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(AnalysisScreen), findsOneWidget);
    expect(find.text('Risk Analysis Report'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
    expect(find.byIcon(Icons.download), findsOneWidget);
  });

  testWidgets('ChatScreen renders empty state suggestions and handles input', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ChatScreen(),
        ),
      ),
    );

    await tester.pump();
    expect(find.textContaining('LEGAL AI ASSISTANT'), findsWidgets);
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('ChecklistsListScreen builds and renders header and action', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ChecklistsListScreen(),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(ChecklistsListScreen), findsOneWidget);
  });

  testWidgets('ChecklistScreen builds with initial title and actions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ChecklistScreen(
            type: 'sample_type',
            initialTitle: 'Resale Apartment Due Diligence',
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(ChecklistScreen), findsOneWidget);
    expect(find.text('Resale Apartment Due Diligence'), findsOneWidget);
  });

  testWidgets('PrivacyPolicyScreen renders all key legal sections and disclaimer', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PrivacyPolicyScreen(),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Last Updated: 15 September 2026'), findsOneWidget);
    expect(find.text('Introduction'), findsOneWidget);
    expect(find.text('Information We Collect'), findsOneWidget);
    expect(find.text('Legal Disclaimer & Non-Advocate Notice'), findsOneWidget);
  });

  testWidgets('WelcomeScreen renders dark mode with nav, elevated preview card, and secondary badges', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const WelcomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('LawBuddy'), findsWidgets);
    expect(find.text('REAL ESTATE AI TECH'), findsWidgets);
    expect(find.text('PROPERTY SALE AGREEMENT'), findsOneWidget);
    expect(find.text('AI Scan Active'), findsOneWidget);
    expect(find.text('Relevant Property Law'), findsOneWidget);
    expect(find.text('Clause 7.2 — Forfeiture'), findsOneWidget);
    expect(find.text('High Legal Risk Detected'), findsWidgets);
  });

  testWidgets('LoginScreen renders translated human-readable text without raw auth keys', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Intelligent Protection for Property Agreements.'), findsOneWidget);
    expect(find.text('Sign in to your account to continue'), findsOneWidget);
    expect(find.text('RERA Compliance Verification'), findsOneWidget);
    expect(find.text('Instant Risk Audit'), findsOneWidget);
    expect(find.text('Due Diligence Checklists'), findsOneWidget);
    expect(find.text('256-bit Encrypted • Strict Confidentiality'), findsOneWidget);

    // Verify that raw translation keys are NOT rendered
    expect(find.text('auth.loginHeroSub'), findsNothing);
    expect(find.text('auth.pillarRera'), findsNothing);
    expect(find.text('auth.pillarAudit'), findsNothing);
    expect(find.text('auth.pillarDueDiligence'), findsNothing);
    expect(find.text('auth.bankGradeSecurity'), findsNothing);
    expect(find.text('auth.loginToAccount'), findsNothing);
  });

  testWidgets('SignupScreen renders translated human-readable text without raw auth keys', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SignupScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(SignupScreen), findsOneWidget);
    expect(find.text('Create Account'), findsWidgets);
    expect(find.text('Build a Safer Property Journey.'), findsOneWidget);
    expect(find.text('Instant Document Audits'), findsOneWidget);
    expect(find.text('Plain-Language Explanations'), findsOneWidget);
    expect(find.text('Custom Legal Checklists'), findsOneWidget);
    expect(find.text('256-bit Encrypted • Strict Confidentiality'), findsOneWidget);

    // Verify raw keys are absent
    expect(find.text('auth.signupHeroTitle'), findsNothing);
    expect(find.text('auth.signupHeroSub'), findsNothing);
    expect(find.text('auth.signupFeatureInstantAudit'), findsNothing);
  });

  testWidgets('StampDutyCalculatorScreen renders translated human-readable text without raw calc keys', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: StampDutyCalculatorScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(StampDutyCalculatorScreen), findsOneWidget);
    expect(find.text('Stamp Duty & Registration Calculator'), findsOneWidget);
    expect(find.text('Property & Transaction Details'), findsOneWidget);
    expect(find.text('Calculate Charges'), findsOneWidget);
    expect(find.text('Reset All'), findsOneWidget);

    // Verify raw keys are absent
    expect(find.text('calc.calcButton'), findsNothing);
    expect(find.text('calc.resetButton'), findsNothing);
    expect(find.text('calc.propertyTypeLabel'), findsNothing);
    expect(find.text('calc.circleRateLabel'), findsNothing);
  });

  testWidgets('CookieConsentBanner renders for new users and handles choices', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Center(child: Text('App Content')),
                CookieConsentBanner(),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Your Privacy Matters'), findsOneWidget);
    expect(find.textContaining('LawBuddy uses browser storage'), findsOneWidget);
    expect(find.text('Necessary Only'), findsOneWidget);
    expect(find.text('Accept Preferences'), findsOneWidget);
    expect(find.text('Customize'), findsOneWidget);

    // Click Necessary Only
    await tester.tap(find.text('Necessary Only'));
    await tester.pumpAndSettle();

    // Banner should be dismissed
    expect(find.text('Your Privacy Matters'), findsNothing);
  });

  testWidgets('showPrivacyPreferencesDialog displays all 4 categories with correct states', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showPrivacyPreferencesDialog(context),
                child: const Text('Open Settings'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Privacy & Storage Preferences'), findsOneWidget);
    expect(find.text('STRICTLY NECESSARY'), findsOneWidget);
    expect(find.text('Always On'), findsOneWidget);
    expect(find.text('FUNCTIONAL / PREFERENCES'), findsOneWidget);
    expect(find.text('ANALYTICS'), findsOneWidget);
    expect(find.text('MARKETING'), findsOneWidget);
    expect(find.text('Not currently used'), findsNWidgets(2));
    expect(find.text('Save Preferences'), findsOneWidget);
  });

  test('Accept functional storage persists theme and language preferences', () async {
    SharedPreferences.setMockInitialValues({
      'storage_consent_status': 'accepted_all',
      'storage_consent_functional': true,
    });
    final themeNotifier = ThemeNotifier();
    themeNotifier.setTheme(ThemeMode.dark);
    final localeNotifier = LocaleNotifier();
    await localeNotifier.setLanguage(AppLanguage.hindi);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('theme_preference'), true);
    expect(prefs.getString('app_language_preference'), 'hi');
  });

  test('Revoking functional storage purges theme and language but preserves auth data', () async {
    SharedPreferences.setMockInitialValues({
      'theme_preference': true,
      'app_language_preference': 'hi',
      'jwt_token': 'jwt_secure_session_token_123',
      'userId': 'usr_test_999',
    });
    final consentNotifier = ConsentNotifier();
    await consentNotifier.necessaryOnly();

    final prefs = await SharedPreferences.getInstance();
    // Functional keys must be cleared
    expect(prefs.getBool('theme_preference'), isNull);
    expect(prefs.getString('app_language_preference'), isNull);
    expect(prefs.getString('storage_consent_status'), 'necessary_only');
    expect(prefs.getBool('storage_consent_functional'), false);

    // Authentication data MUST remain untouched
    expect(prefs.getString('jwt_token'), 'jwt_secure_session_token_123');
    expect(prefs.getString('userId'), 'usr_test_999');
  });

  test('Boot after revocation does not restore old stored values', () async {
    SharedPreferences.setMockInitialValues({
      'storage_consent_status': 'necessary_only',
      'storage_consent_functional': false,
      'theme_preference': true,
      'app_language_preference': 'hi',
    });
    final themeNotifier = ThemeNotifier();
    final localeNotifier = LocaleNotifier();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(themeNotifier.state, ThemeMode.system);
    expect(localeNotifier.state, AppLanguage.english);
  });

  test('Boot with functional consent restores saved preferences', () async {
    SharedPreferences.setMockInitialValues({
      'storage_consent_status': 'accepted_all',
      'storage_consent_functional': true,
      'theme_preference': true,
      'app_language_preference': 'hi',
    });
    final themeNotifier = ThemeNotifier();
    final localeNotifier = LocaleNotifier();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(themeNotifier.state, ThemeMode.dark);
    expect(localeNotifier.state, AppLanguage.hindi);
  });

  test('In-memory theme and language switching works during session when functional storage is disabled', () async {
    SharedPreferences.setMockInitialValues({
      'storage_consent_status': 'necessary_only',
      'storage_consent_functional': false,
    });
    final themeNotifier = ThemeNotifier();
    themeNotifier.setTheme(ThemeMode.light);
    expect(themeNotifier.state, ThemeMode.light);

    final localeNotifier = LocaleNotifier();
    await localeNotifier.setLanguage(AppLanguage.hindi);
    expect(localeNotifier.state, AppLanguage.hindi);

    // Verify nothing was written to storage
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('theme_preference'), isNull);
    expect(prefs.getString('app_language_preference'), isNull);
  });

  testWidgets('Tapping Customize in CookieConsentBanner opens Privacy Preferences dialog with all 4 categories', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: const Scaffold(
            body: Center(child: Text('LawBuddy Landing')),
          ),
          builder: (context, child) {
            return Stack(
              children: [
                if (child != null) child,
                const CookieConsentBanner(),
              ],
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Your Privacy Matters'), findsOneWidget);
    expect(find.text('Customize'), findsOneWidget);

    // Tap Customize
    await tester.tap(find.text('Customize'));
    await tester.pumpAndSettle();

    // Dialog must open immediately on top
    expect(find.text('Privacy & Storage Preferences'), findsOneWidget);
    expect(find.text('STRICTLY NECESSARY'), findsOneWidget);
    expect(find.text('Always On'), findsOneWidget);
    expect(find.text('FUNCTIONAL / PREFERENCES'), findsOneWidget);
    expect(find.text('ANALYTICS'), findsOneWidget);
    expect(find.text('MARKETING'), findsOneWidget);
    expect(find.text('Not currently used'), findsNWidgets(2));
  });

  testWidgets('SignupScreen requires explicit consent checkbox unchecked by default', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SignupScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    // Verify checkbox is present and initially unchecked
    final checkboxFinder = find.byType(Checkbox);
    expect(checkboxFinder, findsOneWidget);
    final Checkbox checkboxWidget = tester.widget(checkboxFinder);
    expect(checkboxWidget.value, false);

    // Verify text contains Terms of Use and Privacy Policy
    expect(find.textContaining('I agree to the'), findsOneWidget);
    expect(find.text('Create Account'), findsWidgets);
  });

  testWidgets('SignupScreen blocks submission when required consent is missing', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SignupScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    // Fill valid form fields
    final textFields = find.byType(TextFormField);
    expect(textFields, findsNWidgets(2));

    await tester.enterText(textFields.at(0), 'Test Legal User');
    await tester.enterText(textFields.at(1), 'testuser@example.com');
    await tester.pump();

    // Find submit button and tap WITHOUT checking consent
    final submitButton = find.widgetWithText(ElevatedButton, 'Create Account');
    expect(submitButton, findsOneWidget);

    await tester.tap(submitButton);
    await tester.pump();

    // Error message must appear
    expect(find.text('Please accept the Terms of Use and Privacy Policy.'), findsOneWidget);
  });

  testWidgets('SignupScreen allows checking consent and clears error', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SignupScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    // Tap the consent checkbox
    final checkboxFinder = find.byType(Checkbox);
    expect(checkboxFinder, findsOneWidget);

    await tester.tap(checkboxFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Checkbox is now checked
    final Checkbox updatedCheckbox = tester.widget(checkboxFinder);
    expect(updatedCheckbox.value, true);
  });

  testWidgets('FormConsentAcknowledgement renders in ChatScreen with links', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ChatScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify informational consent is displayed near input
    expect(
      find.textContaining('I understand that the information I provide may be processed by LawBuddy'),
      findsOneWidget,
    );
  });

  testWidgets('FormConsentAcknowledgement renders in ScanScreen for document uploads', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ScanScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify single document upload acknowledgement notice is displayed
    expect(
      find.textContaining('I understand that the document I submit will be processed by LawBuddy'),
      findsOneWidget,
    );
  });

  testWidgets('FormConsentCheckbox standalone toggle, error state, and text rendering', (WidgetTester tester) async {
    bool agreed = false;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return MaterialApp(
            home: Scaffold(
              body: FormConsentCheckbox(
                value: agreed,
                hasError: !agreed,
                errorMessage: 'Consent required',
                onChanged: (val) => setState(() => agreed = val ?? false),
              ),
            ),
          );
        },
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Consent required'), findsOneWidget);
    expect(agreed, false);

    // Tap to agree
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(agreed, true);
    expect(find.text('Consent required'), findsNothing);
  });

  testWidgets('FormConsentAcknowledgement renders custom text and links', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormConsentAcknowledgement(
            type: FormConsentType.custom,
            customText: 'Custom acknowledgment text',
            showTerms: true,
            showPrivacy: true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Custom acknowledgment text'), findsOneWidget);
    expect(find.byType(FormConsentAcknowledgement), findsOneWidget);
  });

  testWidgets('TermsOfUseScreen renders terms content and back button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: TermsOfUseScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(TermsOfUseScreen), findsOneWidget);
    expect(find.text('Terms of Use'), findsWidgets);
    expect(find.byIcon(Icons.arrow_back_rounded), findsWidgets);
  });

  testWidgets('ScanScreen builds without overflow and provides all scanning options', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ScanScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ScanScreen), findsOneWidget);
    expect(find.byIcon(Icons.camera_enhance_rounded), findsWidgets);
    expect(find.byIcon(Icons.photo_library_outlined), findsWidgets);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsWidgets);
    expect(find.text('Take a Photo'), findsWidgets);
    expect(find.text('Upload PDF'), findsWidgets);
  });
}


