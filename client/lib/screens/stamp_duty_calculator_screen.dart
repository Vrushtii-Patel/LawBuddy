import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/user_profile_button.dart';
import '../services/api_service.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';

class StampDutyCalculatorScreen extends ConsumerStatefulWidget {
  const StampDutyCalculatorScreen({super.key});

  @override
  ConsumerState<StampDutyCalculatorScreen> createState() => _StampDutyCalculatorScreenState();
}

class _StampDutyCalculatorScreenState extends ConsumerState<StampDutyCalculatorScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _propertyValueController = TextEditingController();
  final TextEditingController _circleRateController = TextEditingController();

  String? _selectedPropertyType;
  String? _selectedState;
  String? _selectedGender;
  String? _isFirstTimeBuyer;

  bool _hasCalculated = false;

  // Animation Controllers
  AnimationController? _entryController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  // Calculation Results
  double _enteredPropertyValue = 0.0;
  double _enteredCircleRate = 0.0;
  double _applicableMarketValue = 0.0;
  double _stampDutyRate = 0.0;
  double _stampDutyAmount = 0.0;
  double _registrationRate = 0.0;
  double _registrationAmount = 0.0;
  double _totalPayable = 0.0;

  final List<String> _propertyTypes = [
    'Residential',
    'Commercial',
    'Agricultural',
    'Other',
  ];

  final List<String> _states = [
    'Maharashtra',
    'Karnataka',
    'Delhi',
    'Gujarat',
    'Tamil Nadu',
    'West Bengal',
    'Uttar Pradesh',
    'Haryana',
    'Telangana',
    'Rajasthan',
    'Kerala',
    'Madhya Pradesh',
    'Punjab',
    'Other',
  ];

  final List<String> _genders = [
    'Male',
    'Female',
    'Joint (Male + Female)',
    'Other / Entity',
  ];

  final List<String> _firstTimeOptions = [
    'Yes',
    'No',
  ];

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entryController!,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController!,
      curve: Curves.easeOutCubic,
    ));

    _entryController!.forward();
  }

  @override
  void dispose() {
    _entryController?.dispose();
    _propertyValueController.dispose();
    _circleRateController.dispose();
    super.dispose();
  }

  String _formatIndianRupee(double amount) {
    if (amount.isNaN || amount.isInfinite) return '₹0';
    final int rounded = amount.round();
    final String s = rounded.toString();
    if (s.length <= 3) return '₹$s';

    final String lastThree = s.substring(s.length - 3);
    final String remaining = s.substring(0, s.length - 3);

    final StringBuffer formatted = StringBuffer();
    for (int i = 0; i < remaining.length; i++) {
      if ((remaining.length - i) % 2 == 0 && i != 0) {
        formatted.write(',');
      }
      formatted.write(remaining[i]);
    }
    formatted.write(',$lastThree');
    return '₹${formatted.toString()}';
  }

  void _calculateStampDuty() {
    final loc = ref.read(localeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double propVal = double.tryParse(_propertyValueController.text.replaceAll(',', '')) ?? 0.0;
    final double circleVal = double.tryParse(_circleRateController.text.replaceAll(',', '')) ?? 0.0;

    if (_selectedPropertyType == null || _selectedState == null || _selectedGender == null || _isFirstTimeBuyer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.translate('calc.fillAllError')),
          backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (propVal <= 0 && circleVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.translate('calc.validValueError')),
          backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Applicable value is the higher of Property Value or Circle Rate
    final double applicableVal = propVal > circleVal ? propVal : circleVal;

    // Base Stamp Duty Rate determination
    double baseRate = 5.0; // Default Residential

    switch (_selectedState) {
      case 'Maharashtra':
        baseRate = 6.0;
        if (_selectedGender == 'Female') baseRate -= 1.0;
        break;
      case 'Karnataka':
        if (applicableVal <= 2000000) {
          baseRate = 2.0;
        } else if (applicableVal <= 4500000) {
          baseRate = 3.0;
        } else {
          baseRate = 5.0;
        }
        break;
      case 'Delhi':
        if (_selectedGender == 'Female') {
          baseRate = 4.0;
        } else if (_selectedGender == 'Joint (Male + Female)') {
          baseRate = 5.0;
        } else {
          baseRate = 6.0;
        }
        break;
      case 'Gujarat':
        baseRate = 4.9;
        if (_selectedGender == 'Female') baseRate = 0.0; // 100% exemption for women in GJ
        break;
      case 'Tamil Nadu':
        baseRate = 7.0;
        break;
      case 'West Bengal':
        baseRate = applicableVal > 4000000 ? 6.0 : 5.0;
        break;
      case 'Uttar Pradesh':
        baseRate = 7.0;
        if (_selectedGender == 'Female') baseRate -= 1.0;
        break;
      case 'Haryana':
        if (_selectedGender == 'Female') {
          baseRate = 5.0;
        } else if (_selectedGender == 'Joint (Male + Female)') {
          baseRate = 6.0;
        } else {
          baseRate = 7.0;
        }
        break;
      case 'Telangana':
        baseRate = 6.0;
        break;
      case 'Rajasthan':
        baseRate = 6.0;
        if (_selectedGender == 'Female') baseRate -= 1.0;
        break;
      case 'Kerala':
        baseRate = 8.0;
        break;
      case 'Madhya Pradesh':
        baseRate = 7.5;
        break;
      case 'Punjab':
        baseRate = _selectedGender == 'Female' ? 5.0 : 7.0;
        break;
      default:
        baseRate = 5.0;
    }

    // Property Type Adjustments
    if (_selectedPropertyType == 'Commercial') {
      baseRate += 1.0;
    } else if (_selectedPropertyType == 'Agricultural') {
      baseRate = (baseRate * 0.7).clamp(1.0, 10.0);
    }

    // First-time buyer concession (e.g., 0.5% rebate where applicable)
    if (_isFirstTimeBuyer == 'Yes' && baseRate > 2.0) {
      baseRate = (baseRate - 0.5).clamp(1.0, 15.0);
    }

    // Registration fee calculation (Standard: 1% capped at 30,000 in MH/certain states, or flat 1%)
    double regRate = 1.0;
    double regAmount = applicableVal * (regRate / 100.0);

    if (_selectedState == 'Maharashtra' && regAmount > 30000) {
      regAmount = 30000;
    } else if (_selectedState == 'Tamil Nadu') {
      regRate = 4.0;
      regAmount = applicableVal * (regRate / 100.0);
    }

    final double stampAmount = applicableVal * (baseRate / 100.0);
    final double total = stampAmount + regAmount;

    setState(() {
      _enteredPropertyValue = propVal;
      _enteredCircleRate = circleVal;
      _applicableMarketValue = applicableVal;
      _stampDutyRate = baseRate;
      _stampDutyAmount = stampAmount;
      _registrationRate = regRate;
      _registrationAmount = regAmount;
      _totalPayable = total;
      _hasCalculated = true;
    });

    // Save calculation event to backend (fire-and-forget: the calculator
    // itself is fully client-side and already shown to the user above, so a
    // failure here shouldn't interrupt or alarm the user — but it shouldn't
    // vanish silently either, in case this needs debugging later).
    ApiService.saveStampDutyCalculation({
      'state': _selectedState,
      'propertyType': _selectedPropertyType,
      'applicableValue': applicableVal,
      'totalPayable': total,
    }).catchError((e) {
      debugPrint('Failed to save stamp duty calculation to history: $e');
      return <String, dynamic>{};
    });
  }

  void _resetCalculator() {
    _formKey.currentState?.reset();
    _propertyValueController.clear();
    _circleRateController.clear();
    setState(() {
      _selectedPropertyType = null;
      _selectedState = null;
      _selectedGender = null;
      _isFirstTimeBuyer = null;
      _hasCalculated = false;
      _enteredPropertyValue = 0.0;
      _enteredCircleRate = 0.0;
      _applicableMarketValue = 0.0;
      _stampDutyRate = 0.0;
      _stampDutyAmount = 0.0;
      _registrationRate = 0.0;
      _registrationAmount = 0.0;
      _totalPayable = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 960;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: SafeArea(
          child: Column(
          children: [
            const SizedBox(height: 6),
            // TOP BAR
            _buildTopBar(context, isDark, loc),
            const SizedBox(height: 4),

            // BODY CONTENT
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation ?? const AlwaysStoppedAnimation(1.0),
                child: SlideTransition(
                  position: _slideAnimation ?? const AlwaysStoppedAnimation(Offset.zero),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 48.0 : 16.0,
                      vertical: 24.0,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1160),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // HERO HEADER
                            _buildHeroHeader(isDark, loc, isDesktop),
                            const SizedBox(height: 32),

                            // TWO COLUMN OR STACKED LAYOUT
                            if (isDesktop)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left Column: Calculator Inputs
                                  Expanded(
                                    flex: 6,
                                    child: _buildCalculatorFormCard(context, isDark, loc, isDesktop),
                                  ),
                                  const SizedBox(width: 28),

                                  // Right Column: Result Summary & Breakdown
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      children: [
                                        if (_hasCalculated) ...[
                                          _buildResultSummaryCard(context, isDark, loc),
                                          const SizedBox(height: 20),
                                        ],
                                        _buildDisclaimerBox(context, isDark, loc),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              // Mobile / Tablet Stacked Layout
                              _buildCalculatorFormCard(context, isDark, loc, isDesktop),
                              const SizedBox(height: 24),
                              if (_hasCalculated) ...[
                                _buildResultSummaryCard(context, isDark, loc),
                                const SizedBox(height: 20),
                              ],
                              _buildDisclaimerBox(context, isDark, loc),
                            ],
                            const SizedBox(height: 48),
                          ],
                        ),
                      ),
                    ),
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
  // TOP BAR
  // ==========================================
  Widget _buildTopBar(BuildContext context, bool isDark, LocaleNotifier loc) {
    final isDesktopOrTablet = MediaQuery.of(context).size.width >= 700;
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    loc.translate('common.back'),
                    style: GoogleFonts.inter(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center: Exact dead-center badge (desktop/tablet only to avoid mobile overlap)
          if (isDesktopOrTablet)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.lightPrimary.withValues(alpha: isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.lightPrimary.withValues(alpha: isDark ? 0.35 : 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.lightPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'STATUTORY TAX & REGISTRY CALCULATOR',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightPrimary,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Right: Profile Button
          const Align(
            alignment: Alignment.centerRight,
            child: UserProfileButton(),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HERO HEADER
  // ==========================================
  Widget _buildHeroHeader(bool isDark, LocaleNotifier loc, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Eyebrow Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.lightPrimary.withValues(alpha: isDark ? 0.2 : 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.lightPrimary.withValues(alpha: isDark ? 0.35 : 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.lightPrimary,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'STATE REGISTRATION ACT • CIRCLE RATES • STAMP REBATES',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Main Title
        Text(
          loc.translate('calc.screenTitle'),
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: isDesktop ? 30 : 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            loc.translate('calc.screenSubtitle'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: isDesktop ? 14 : 13,
              height: 1.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // CALCULATOR FORM CARD
  // ==========================================
  Widget _buildCalculatorFormCard(BuildContext context, bool isDark, LocaleNotifier loc, bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.0,
        ),
      ),
      padding: EdgeInsets.all(isDesktop ? 32.0 : 20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.lightPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.calculate_rounded, color: AppColors.lightPrimary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.translate('calc.cardTitle'),
                        style: GoogleFonts.plusJakartaSans(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Input deed consideration, circle valuation & concessions',
                        style: GoogleFonts.inter(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),

            // Form Inputs Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final isTwoCol = constraints.maxWidth > 560;

                Widget propertyTypeField = _buildDropdownField(
                  label: loc.translate('calc.propertyTypeLabel'),
                  value: _selectedPropertyType,
                  hintText: loc.translate('calc.selectPropertyTypeHint'),
                  items: _propertyTypes,
                  itemLabelBuilder: (item) => loc.translate('calc.propertyType$item'),
                  icon: Icons.apartment_rounded,
                  isDark: isDark,
                  onChanged: (val) => setState(() => _selectedPropertyType = val),
                );

                Widget stateField = _buildDropdownField(
                  label: loc.translate('calc.stateLabel'),
                  value: _selectedState,
                  hintText: loc.translate('calc.selectStateHint'),
                  items: _states,
                  icon: Icons.location_city_rounded,
                  isDark: isDark,
                  onChanged: (val) => setState(() => _selectedState = val),
                );

                Widget propertyValField = _buildTextField(
                  label: loc.translate('calc.propValueLabel'),
                  hint: 'e.g. 75,00,000',
                  controller: _propertyValueController,
                  icon: Icons.currency_rupee_rounded,
                  isDark: isDark,
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return loc.translate('calc.enterPropValError');
                    }
                    return null;
                  },
                );

                Widget circleRateField = _buildTextField(
                  label: loc.translate('calc.circleRateLabel'),
                  hint: 'e.g. 68,00,000',
                  controller: _circleRateController,
                  icon: Icons.domain_verification_rounded,
                  isDark: isDark,
                  validator: (val) => null,
                );

                Widget genderField = _buildDropdownField(
                  label: loc.translate('calc.genderLabel'),
                  value: _selectedGender,
                  hintText: loc.translate('calc.selectGenderHint'),
                  items: _genders,
                  itemLabelBuilder: (item) {
                    if (item.startsWith('Male')) return loc.translate('calc.genderMale');
                    if (item.startsWith('Female')) return loc.translate('calc.genderFemale');
                    if (item.startsWith('Joint')) return loc.translate('calc.genderJoint');
                    return loc.translate('calc.genderOther');
                  },
                  icon: Icons.wc_rounded,
                  isDark: isDark,
                  onChanged: (val) => setState(() => _selectedGender = val),
                );

                Widget firstTimeBuyerField = _buildDropdownField(
                  label: loc.translate('calc.firstTimeLabel'),
                  value: _isFirstTimeBuyer,
                  hintText: loc.translate('calc.selectOptionHint'),
                  items: _firstTimeOptions,
                  itemLabelBuilder: (item) => item == 'Yes' ? loc.translate('common.yes') : loc.translate('common.no'),
                  icon: Icons.key_rounded,
                  isDark: isDark,
                  onChanged: (val) => setState(() => _isFirstTimeBuyer = val),
                );

                if (isTwoCol) {
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: propertyTypeField),
                          const SizedBox(width: 18),
                          Expanded(child: stateField),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: propertyValField),
                          const SizedBox(width: 18),
                          Expanded(child: circleRateField),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: genderField),
                          const SizedBox(width: 18),
                          Expanded(child: firstTimeBuyerField),
                        ],
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      propertyTypeField,
                      const SizedBox(height: 16),
                      stateField,
                      const SizedBox(height: 16),
                      propertyValField,
                      const SizedBox(height: 16),
                      circleRateField,
                      const SizedBox(height: 16),
                      genderField,
                      const SizedBox(height: 16),
                      firstTimeBuyerField,
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 30),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _HoverCalculateButton(
                    label: loc.translate('calc.calcButton'),
                    isDark: isDark,
                    onTap: _calculateStampDuty,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: _HoverResetButton(
                    label: loc.translate('calc.resetButton'),
                    isDark: isDark,
                    onTap: _resetCalculator,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required String hintText,
    required List<String> items,
    String Function(String)? itemLabelBuilder,
    required IconData icon,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Row(
                children: [
                  Icon(icon, size: 18, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  const SizedBox(width: 10),
                  Text(
                    hintText,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              isExpanded: true,
              dropdownColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              items: items.map((String item) {
                final display = itemLabelBuilder != null ? itemLabelBuilder(item) : item;
                return DropdownMenuItem<String>(
                  value: item,
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: AppColors.lightPrimary),
                      const SizedBox(width: 10),
                      Text(
                        display,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    required bool isDark,
    required FormFieldValidator<String> validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            fontWeight: FontWeight.w600,
          ),
          validator: validator,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              fontSize: 13,
            ),
            filled: true,
            fillColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
            prefixIcon: Icon(icon, size: 18, color: AppColors.lightPrimary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.lightPrimary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // RESULTS SUMMARY CARD
  // ==========================================
  Widget _buildResultSummaryCard(BuildContext context, bool isDark, LocaleNotifier loc) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.receipt_long_rounded, color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    loc.translate('calc.summaryTitle'),
                    style: GoogleFonts.plusJakartaSans(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.lightPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.lightPrimary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.place_rounded, size: 13, color: AppColors.lightPrimary),
                    const SizedBox(width: 5),
                    Text(
                      _selectedState ?? '',
                      style: GoogleFonts.inter(
                        color: AppColors.lightPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          _buildResultRow(loc.translate('calc.rowAgreementValue'), _formatIndianRupee(_enteredPropertyValue), isDark),
          const SizedBox(height: 12),
          _buildResultRow(loc.translate('calc.rowCircleRate'), _formatIndianRupee(_enteredCircleRate), isDark),
          const SizedBox(height: 12),
          _buildResultRow(
            loc.translate('calc.rowApplicableMarketValue'),
            _formatIndianRupee(_applicableMarketValue),
            isDark,
            isBold: true,
            highlightColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
          ),
          const SizedBox(height: 16),
          Divider(height: 1, thickness: 0.8, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          const SizedBox(height: 16),

          _buildResultRow(
            loc.translate('calc.rowStampDuty', {'rate': _stampDutyRate.toStringAsFixed(1)}),
            _formatIndianRupee(_stampDutyAmount),
            isDark,
          ),
          const SizedBox(height: 12),
          _buildResultRow(
            loc.translate('calc.rowRegistration', {'rate': _registrationRate.toStringAsFixed(1)}),
            _formatIndianRupee(_registrationAmount),
            isDark,
          ),
          const SizedBox(height: 22),

          // Total Payable Prominent Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.translate('calc.totalPayable'),
                      style: GoogleFonts.inter(
                        color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      loc.translate('calc.stampPlusReg'),
                      style: GoogleFonts.inter(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatIndianRupee(_totalPayable),
                  style: GoogleFonts.plusJakartaSans(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(
    String label,
    String value,
    bool isDark, {
    bool isBold = false,
    Color? highlightColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: isBold
                ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: highlightColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            fontSize: 15,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // DISCLAIMER BOX
  // ==========================================
  Widget _buildDisclaimerBox(BuildContext context, bool isDark, LocaleNotifier loc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: isDark ? AppColors.darkAccent : AppColors.lightPrimary, size: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loc.translate('calc.disclaimer'),
              style: GoogleFonts.inter(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// HOVER CALCULATE BUTTON
// ==========================================
class _HoverCalculateButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;
  final bool isDark;

  const _HoverCalculateButton({
    required this.onTap,
    required this.label,
    required this.isDark,
  });

  @override
  State<_HoverCalculateButton> createState() => _HoverCalculateButtonState();
}

class _HoverCalculateButtonState extends State<_HoverCalculateButton> {
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
          height: 50,
          transform: Matrix4.translationValues(0, _isHovered ? -2.0 : 0, 0),
          decoration: BoxDecoration(
            color: widget.isDark ? AppColors.darkAccent : AppColors.lightPrimary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calculate_rounded,
                size: 20,
                color: widget.isDark ? AppColors.darkBackground : Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? AppColors.darkBackground : Colors.white,
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
// HOVER RESET BUTTON
// ==========================================
class _HoverResetButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;
  final bool isDark;

  const _HoverResetButton({
    required this.onTap,
    required this.label,
    required this.isDark,
  });

  @override
  State<_HoverResetButton> createState() => _HoverResetButtonState();
}

class _HoverResetButtonState extends State<_HoverResetButton> {
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
          height: 50,
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated)
                : (widget.isDark ? AppColors.darkSurface : AppColors.lightSurface),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.restart_alt_rounded,
                size: 18,
                color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
// HOVER GLASS BUTTON
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
                ? (widget.isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated)
                : (widget.isDark ? AppColors.darkSurface : AppColors.lightSurface),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}