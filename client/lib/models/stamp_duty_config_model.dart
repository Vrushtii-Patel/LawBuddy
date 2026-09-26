class SlabConfig {
  final double? maxValue;
  final double rate;

  const SlabConfig({
    this.maxValue,
    required this.rate,
  });

  factory SlabConfig.fromJson(Map<String, dynamic> json) {
    return SlabConfig(
      maxValue: json['maxValue'] != null ? (json['maxValue'] as num).toDouble() : null,
      rate: (json['rate'] as num?)?.toDouble() ?? 5.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'maxValue': maxValue,
    'rate': rate,
  };
}

class StateStampDutyConfig {
  final String state;
  final double baseRate;
  final Map<String, double?> genderOverrides;
  final List<SlabConfig> slabs;
  final double registrationRate;
  final double? registrationCap;
  final DateTime lastVerifiedOn;
  final String source;

  const StateStampDutyConfig({
    required this.state,
    required this.baseRate,
    this.genderOverrides = const {},
    this.slabs = const [],
    this.registrationRate = 1.0,
    this.registrationCap,
    required this.lastVerifiedOn,
    this.source = 'State Revenue Department',
  });

  factory StateStampDutyConfig.fromJson(Map<String, dynamic> json) {
    Map<String, double?> overrides = {};
    if (json['genderOverrides'] is Map) {
      final map = json['genderOverrides'] as Map;
      map.forEach((k, v) {
        if (v != null) {
          overrides[k.toString()] = (v as num).toDouble();
        }
      });
    }

    List<SlabConfig> slabsList = [];
    if (json['slabs'] is List) {
      slabsList = (json['slabs'] as List)
          .map((e) => SlabConfig.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    DateTime verifiedDate = DateTime.now();
    if (json['lastVerifiedOn'] != null) {
      try {
        verifiedDate = DateTime.parse(json['lastVerifiedOn'].toString());
      } catch (_) {}
    }

    return StateStampDutyConfig(
      state: json['state']?.toString() ?? 'Other',
      baseRate: (json['baseRate'] as num?)?.toDouble() ?? 5.0,
      genderOverrides: overrides,
      slabs: slabsList,
      registrationRate: (json['registrationRate'] as num?)?.toDouble() ?? 1.0,
      registrationCap: json['registrationCap'] != null ? (json['registrationCap'] as num).toDouble() : null,
      lastVerifiedOn: verifiedDate,
      source: json['source']?.toString() ?? 'State Revenue Department',
    );
  }

  Map<String, dynamic> toJson() => {
    'state': state,
    'baseRate': baseRate,
    'genderOverrides': genderOverrides,
    'slabs': slabs.map((e) => e.toJson()).toList(),
    'registrationRate': registrationRate,
    'registrationCap': registrationCap,
    'lastVerifiedOn': lastVerifiedOn.toIso8601String(),
    'source': source,
  };
}

class PropertyTypeAdjustment {
  final String type; // 'add', 'multiply', 'none'
  final double value;
  final double multiplier;
  final double minRate;
  final double maxRate;

  const PropertyTypeAdjustment({
    this.type = 'none',
    this.value = 0.0,
    this.multiplier = 1.0,
    this.minRate = 1.0,
    this.maxRate = 10.0,
  });

  factory PropertyTypeAdjustment.fromJson(Map<String, dynamic> json) {
    return PropertyTypeAdjustment(
      type: json['type']?.toString() ?? 'none',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      multiplier: (json['multiplier'] as num?)?.toDouble() ?? 1.0,
      minRate: (json['minRate'] as num?)?.toDouble() ?? 1.0,
      maxRate: (json['maxRate'] as num?)?.toDouble() ?? 10.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'value': value,
    'multiplier': multiplier,
    'minRate': minRate,
    'maxRate': maxRate,
  };
}

class FirstTimeBuyerConcession {
  final double discount;
  final double thresholdRate;
  final double minRate;
  final double maxRate;

  const FirstTimeBuyerConcession({
    this.discount = 0.5,
    this.thresholdRate = 2.0,
    this.minRate = 1.0,
    this.maxRate = 15.0,
  });

  factory FirstTimeBuyerConcession.fromJson(Map<String, dynamic> json) {
    return FirstTimeBuyerConcession(
      discount: (json['discount'] as num?)?.toDouble() ?? 0.5,
      thresholdRate: (json['thresholdRate'] as num?)?.toDouble() ?? 2.0,
      minRate: (json['minRate'] as num?)?.toDouble() ?? 1.0,
      maxRate: (json['maxRate'] as num?)?.toDouble() ?? 15.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'discount': discount,
    'thresholdRate': thresholdRate,
    'minRate': minRate,
    'maxRate': maxRate,
  };
}

class GlobalStampDutyRules {
  final Map<String, PropertyTypeAdjustment> propertyTypeAdjustments;
  final FirstTimeBuyerConcession firstTimeBuyerConcession;

  const GlobalStampDutyRules({
    this.propertyTypeAdjustments = const {},
    this.firstTimeBuyerConcession = const FirstTimeBuyerConcession(),
  });

  factory GlobalStampDutyRules.fromJson(Map<String, dynamic> json) {
    Map<String, PropertyTypeAdjustment> propMap = {};
    if (json['propertyTypeAdjustments'] is Map) {
      final map = json['propertyTypeAdjustments'] as Map;
      map.forEach((k, v) {
        if (v is Map) {
          propMap[k.toString()] = PropertyTypeAdjustment.fromJson(Map<String, dynamic>.from(v));
        }
      });
    }

    FirstTimeBuyerConcession ft = const FirstTimeBuyerConcession();
    if (json['firstTimeBuyerConcession'] is Map) {
      ft = FirstTimeBuyerConcession.fromJson(Map<String, dynamic>.from(json['firstTimeBuyerConcession']));
    }

    return GlobalStampDutyRules(
      propertyTypeAdjustments: propMap,
      firstTimeBuyerConcession: ft,
    );
  }

  Map<String, dynamic> toJson() => {
    'propertyTypeAdjustments': propertyTypeAdjustments.map((k, v) => MapEntry(k, v.toJson())),
    'firstTimeBuyerConcession': firstTimeBuyerConcession.toJson(),
  };
}

class StampDutyConfigResponse {
  final List<StateStampDutyConfig> states;
  final GlobalStampDutyRules globalRules;

  const StampDutyConfigResponse({
    required this.states,
    required this.globalRules,
  });

  StateStampDutyConfig getConfigForState(String? stateName) {
    if (stateName == null || stateName.isEmpty) {
      return _fallbackStateConfig('Other');
    }
    final match = states.firstWhere(
      (s) => s.state.toLowerCase() == stateName.toLowerCase(),
      orElse: () => _fallbackStateConfig(stateName),
    );
    return match;
  }

  static StateStampDutyConfig _fallbackStateConfig(String state) {
    return StateStampDutyConfig(
      state: state,
      baseRate: 5.0,
      registrationRate: 1.0,
      lastVerifiedOn: DateTime.now(),
      source: 'Default Statutory Baseline',
    );
  }

  factory StampDutyConfigResponse.fromJson(Map<String, dynamic> json) {
    List<StateStampDutyConfig> statesList = [];
    if (json['states'] is List) {
      statesList = (json['states'] as List)
          .map((e) => StateStampDutyConfig.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    GlobalStampDutyRules rules = const GlobalStampDutyRules();
    if (json['globalRules'] is Map) {
      rules = GlobalStampDutyRules.fromJson(Map<String, dynamic>.from(json['globalRules']));
    }

    return StampDutyConfigResponse(
      states: statesList,
      globalRules: rules,
    );
  }

  Map<String, dynamic> toJson() => {
    'states': states.map((e) => e.toJson()).toList(),
    'globalRules': globalRules.toJson(),
  };

  static StampDutyConfigResponse defaultBundle() {
    final verified = DateTime(2026, 8, 1);
    return StampDutyConfigResponse(
      states: [
        StateStampDutyConfig(
          state: 'Maharashtra',
          baseRate: 6.0,
          genderOverrides: {'Female': 5.0},
          registrationCap: 30000,
          lastVerifiedOn: verified,
          source: 'Maharashtra Stamp Act (Article 25) & IGR Maharashtra',
        ),
        StateStampDutyConfig(
          state: 'Karnataka',
          baseRate: 5.0,
          slabs: const [
            SlabConfig(maxValue: 2000000, rate: 2.0),
            SlabConfig(maxValue: 4500000, rate: 3.0),
            SlabConfig(maxValue: null, rate: 5.0),
          ],
          lastVerifiedOn: verified,
          source: 'Karnataka Stamp Act & Kaveri Online Services',
        ),
        StateStampDutyConfig(
          state: 'Delhi',
          baseRate: 6.0,
          genderOverrides: {
            'Female': 4.0,
            'Joint (Male + Female)': 5.0,
            'Male': 6.0,
            'Other / Entity': 6.0,
          },
          lastVerifiedOn: verified,
          source: 'Delhi Revenue Department (DOR) & IGR Delhi',
        ),
        StateStampDutyConfig(
          state: 'Gujarat',
          baseRate: 4.9,
          genderOverrides: {'Female': 0.0},
          lastVerifiedOn: verified,
          source: 'Gujarat Stamp Act & IGR Gujarat',
        ),
        StateStampDutyConfig(
          state: 'Tamil Nadu',
          baseRate: 7.0,
          registrationRate: 4.0,
          lastVerifiedOn: verified,
          source: 'Tamil Nadu Registration Department (TNREGINET)',
        ),
        StateStampDutyConfig(
          state: 'West Bengal',
          baseRate: 5.0,
          slabs: const [
            SlabConfig(maxValue: 4000000, rate: 5.0),
            SlabConfig(maxValue: null, rate: 6.0),
          ],
          lastVerifiedOn: verified,
          source: 'Directorate of Registration and Stamp Revenue, West Bengal',
        ),
        StateStampDutyConfig(
          state: 'Uttar Pradesh',
          baseRate: 7.0,
          genderOverrides: {'Female': 6.0},
          lastVerifiedOn: verified,
          source: 'UP Stamp and Registration Department (IGRSUP)',
        ),
        StateStampDutyConfig(
          state: 'Haryana',
          baseRate: 7.0,
          genderOverrides: {
            'Female': 5.0,
            'Joint (Male + Female)': 6.0,
            'Male': 7.0,
            'Other / Entity': 7.0,
          },
          lastVerifiedOn: verified,
          source: 'Haryana Revenue & Disaster Management Department (JAMABANDI)',
        ),
        StateStampDutyConfig(
          state: 'Telangana',
          baseRate: 6.0,
          lastVerifiedOn: verified,
          source: 'Telangana Registration & Stamps Department (CARD)',
        ),
        StateStampDutyConfig(
          state: 'Rajasthan',
          baseRate: 6.0,
          genderOverrides: {'Female': 5.0},
          lastVerifiedOn: verified,
          source: 'Rajasthan Registration and Stamps Department (EPANJIYAN)',
        ),
        StateStampDutyConfig(
          state: 'Kerala',
          baseRate: 8.0,
          lastVerifiedOn: verified,
          source: 'Kerala Registration Department (PEARL)',
        ),
        StateStampDutyConfig(
          state: 'Madhya Pradesh',
          baseRate: 7.5,
          lastVerifiedOn: verified,
          source: 'MP Commercial Tax Department (SAMPADA)',
        ),
        StateStampDutyConfig(
          state: 'Punjab',
          baseRate: 7.0,
          genderOverrides: {'Female': 5.0},
          lastVerifiedOn: verified,
          source: 'Department of Revenue & Rehabilitation Punjab',
        ),
        StateStampDutyConfig(
          state: 'Other',
          baseRate: 5.0,
          lastVerifiedOn: verified,
          source: 'Indian Stamp Act (Central Baseline)',
        ),
      ],
      globalRules: const GlobalStampDutyRules(
        propertyTypeAdjustments: {
          'Commercial': PropertyTypeAdjustment(type: 'add', value: 1.0),
          'Agricultural': PropertyTypeAdjustment(type: 'multiply', multiplier: 0.7, minRate: 1.0, maxRate: 10.0),
          'Residential': PropertyTypeAdjustment(type: 'none', value: 0.0),
          'Other': PropertyTypeAdjustment(type: 'none', value: 0.0),
        },
        firstTimeBuyerConcession: FirstTimeBuyerConcession(
          discount: 0.5,
          thresholdRate: 2.0,
          minRate: 1.0,
          maxRate: 15.0,
        ),
      ),
    );
  }
}
