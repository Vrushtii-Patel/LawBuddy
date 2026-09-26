import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/stamp_duty_config_model.dart';
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

  // Dynamic Backend Configuration Bundle (with local cache & default fallback)
  StampDutyConfigResponse _config = StampDutyConfigResponse.defaultBundle();

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

    _loadConfig();

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

  Future<void> _loadConfig() async {
    try {
      final fetched = await ApiService.getStampDutyConfig();
      if (mounted) {
        setState(() {
          _config = fetched;
        });
      }
    } catch (_) {}
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

    // 1. Resolve State Specific Base Rate from fetched/cached configuration
    final stateConfig = _config.getConfigForState(_selectedState);
    double baseRate = stateConfig.baseRate;

    if (stateConfig.slabs.isNotEmpty) {
      for (final slab in stateConfig.slabs) {
        if (slab.maxValue == null || applicableVal <= slab.maxValue!) {
          baseRate = slab.rate;
          break;
        }
      }
    } else if (stateConfig.genderOverrides.containsKey(_selectedGender) &&
        stateConfig.genderOverrides[_selectedGender] != null) {
      baseRate = stateConfig.genderOverrides[_selectedGender]!;
    }

    // 2. Apply Global Property Type Adjustments
    final propRule = _config.globalRules.propertyTypeAdjustments[_selectedPropertyType];
    if (propRule != null) {
      if (propRule.type == 'add') {
        baseRate += propRule.value;
      } else if (propRule.type == 'multiply') {
        baseRate = (baseRate * propRule.multiplier).clamp(propRule.minRate, propRule.maxRate);
      }
    }

    // 3. Apply Global First-Time Buyer Concession
    final ftRule = _config.globalRules.firstTimeBuyerConcession;
    if (_isFirstTimeBuyer == 'Yes' && baseRate > ftRule.thresholdRate) {
      baseRate = (baseRate - ftRule.discount).clamp(ftRule.minRate, ftRule.maxRate);
    }

    // 4. Calculate Registration Fee from state configuration
    final double regRate = stateConfig.registrationRate;
    double regAmount = applicableVal * (regRate / 100.0);

    if (stateConfig.registrationCap != null && regAmount > stateConfig.registrationCap!) {
      regAmount = stateConfig.registrationCap!;
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
      'agreementValue': propVal,
      'circleRate': circleVal,
      'applicableMarketValue': applicableVal,
      'gender': _selectedGender,
      'firstTimeBuyer': _isFirstTimeBuyer,
      'stampDutyRate': baseRate,
      'stampDutyAmount': stampAmount,
      'registrationRate': regRate,
      'registrationAmount': regAmount,
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
            const SizedBox(height: 16),

            // Statutory Rate Verification Status & Citation
            _buildVerificationStatusBadge(isDark),
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
    final isDesktop = MediaQuery.of(context).size.width >= 960;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.0,
        ),
      ),
      padding: EdgeInsets.all(isDesktop ? 24.0 : 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: title absorbs all remaining space, badge hugs natural width
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loc.translate('calc.summaryTitle'),
                  style: GoogleFonts.plusJakartaSans(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktop ? 180 : 140),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _selectedState ?? '',
                          style: GoogleFonts.inter(
                            color: AppColors.lightPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

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
          const SizedBox(height: 20),

          // Total Payable Prominent Box: labels absorb remaining space, amount hugs width
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        loc.translate('calc.totalPayable'),
                        style: GoogleFonts.inter(
                          color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        loc.translate('calc.stampPlusReg'),
                        style: GoogleFonts.inter(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 220 : 160),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      _formatIndianRupee(_totalPayable),
                      style: GoogleFonts.plusJakartaSans(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: isBold
                  ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: highlightColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                fontSize: 15,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
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

  // ==========================================
  // STATUTORY RATES VERIFICATION BADGE
  // ==========================================
  Widget _buildVerificationStatusBadge(bool isDark) {
    final stateConfig = _config.getConfigForState(_selectedState);
    final verifiedDate = stateConfig.lastVerifiedOn;
    final int daysAgo = DateTime.now().difference(verifiedDate).inDays;
    final bool isWarning = daysAgo > 90;

    final String formattedDate =
        '${verifiedDate.day.toString().padLeft(2, '0')} ${_monthName(verifiedDate.month)} ${verifiedDate.year}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isWarning
            ? (isDark ? const Color(0xFF332005) : const Color(0xFFFFF8E1))
            : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWarning
              ? const Color(0xFFFF9800).withValues(alpha: isDark ? 0.6 : 0.4)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
            size: 18,
            color: isWarning
                ? const Color(0xFFFF9800)
                : (isDark ? AppColors.darkAccent : AppColors.lightPrimary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Rates last verified on $formattedDate',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isWarning
                            ? (isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100))
                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                      ),
                    ),
                    if (isWarning) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '> 90 DAYS',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isWarning
                      ? 'Statutory rates may have changed since verification. Please confirm with your local Sub-Registrar or IGR portal.'
                      : 'Source: ${stateConfig.source}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    height: 1.35,
                    color: isWarning
                        ? (isDark ? const Color(0xFFFFCC80) : const Color(0xFFBF360C))
                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
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