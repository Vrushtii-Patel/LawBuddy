class OverviewKpi {
  final int totalUsers;
  final int totalDocumentsAnalyzed;
  final int totalClausesEvaluated;
  final double averagePagesPerDoc;
  final int totalChatSessions;
  final int totalChecklists;

  OverviewKpi({
    required this.totalUsers,
    required this.totalDocumentsAnalyzed,
    required this.totalClausesEvaluated,
    required this.averagePagesPerDoc,
    required this.totalChatSessions,
    required this.totalChecklists,
  });

  factory OverviewKpi.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return OverviewKpi(
        totalUsers: 0,
        totalDocumentsAnalyzed: 0,
        totalClausesEvaluated: 0,
        averagePagesPerDoc: 0.0,
        totalChatSessions: 0,
        totalChecklists: 0,
      );
    }
    return OverviewKpi(
      totalUsers: json['totalUsers'] as int? ?? 0,
      totalDocumentsAnalyzed: json['totalDocumentsAnalyzed'] as int? ?? 0,
      totalClausesEvaluated: json['totalClausesEvaluated'] as int? ?? 0,
      averagePagesPerDoc: (json['averagePagesPerDoc'] as num?)?.toDouble() ?? 0.0,
      totalChatSessions: json['totalChatSessions'] as int? ?? 0,
      totalChecklists: json['totalChecklists'] as int? ?? 0,
    );
  }
}

class DocumentRiskDistribution {
  final int highRisk;
  final int mediumRisk;
  final int lowRisk;

  DocumentRiskDistribution({
    required this.highRisk,
    required this.mediumRisk,
    required this.lowRisk,
  });

  int get total => highRisk + mediumRisk + lowRisk;

  factory DocumentRiskDistribution.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return DocumentRiskDistribution(highRisk: 0, mediumRisk: 0, lowRisk: 0);
    }
    return DocumentRiskDistribution(
      highRisk: json['highRisk'] as int? ?? 0,
      mediumRisk: json['mediumRisk'] as int? ?? 0,
      lowRisk: json['lowRisk'] as int? ?? 0,
    );
  }
}

class ClauseRiskDistribution {
  final int highRisk;
  final int caution;
  final int compliant;

  ClauseRiskDistribution({
    required this.highRisk,
    required this.caution,
    required this.compliant,
  });

  int get total => highRisk + caution + compliant;

  factory ClauseRiskDistribution.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ClauseRiskDistribution(highRisk: 0, caution: 0, compliant: 0);
    }
    return ClauseRiskDistribution(
      highRisk: json['highRisk'] as int? ?? 0,
      caution: json['caution'] as int? ?? 0,
      compliant: json['compliant'] as int? ?? 0,
    );
  }
}

class RiskDistribution {
  final DocumentRiskDistribution documentLevel;
  final ClauseRiskDistribution clauseLevel;

  RiskDistribution({
    required this.documentLevel,
    required this.clauseLevel,
  });

  factory RiskDistribution.fromJson(Map<String, dynamic>? json) {
    return RiskDistribution(
      documentLevel: DocumentRiskDistribution.fromJson(json?['documentLevel']),
      clauseLevel: ClauseRiskDistribution.fromJson(json?['clauseLevel']),
    );
  }
}

class FindingCategoryStat {
  final String category;
  final int count;

  FindingCategoryStat({
    required this.category,
    required this.count,
  });

  factory FindingCategoryStat.fromJson(Map<String, dynamic> json) {
    return FindingCategoryStat(
      category: json['category'] as String? ?? 'General Finding',
      count: json['count'] as int? ?? 0,
    );
  }
}

class SourceTypeStat {
  final String sourceType;
  final int count;

  SourceTypeStat({
    required this.sourceType,
    required this.count,
  });

  factory SourceTypeStat.fromJson(Map<String, dynamic> json) {
    return SourceTypeStat(
      sourceType: json['sourceType'] as String? ?? 'Unknown',
      count: json['count'] as int? ?? 0,
    );
  }
}

class ExtractionMethodStat {
  final String method;
  final int count;

  ExtractionMethodStat({
    required this.method,
    required this.count,
  });

  factory ExtractionMethodStat.fromJson(Map<String, dynamic> json) {
    return ExtractionMethodStat(
      method: json['method'] as String? ?? 'unknown',
      count: json['count'] as int? ?? 0,
    );
  }

  String get displayLabel {
    switch (method) {
      case 'scanned_pdf_vision':
        return 'Scanned PDF Vision';
      case 'digital_pdf_text':
        return 'Digital PDF Text';
      case 'direct_ocr':
        return 'Direct Image OCR';
      case 'raw_text':
        return 'Direct Text Input';
      default:
        return method.replaceAll('_', ' ');
    }
  }
}

class RecentScanSummary {
  final String id;
  final String title;
  final String riskLevel;
  final int highRiskCount;
  final int cautionCount;
  final int compliantCount;
  final int totalPages;
  final String sourceType;
  final String extractionMethod;
  final DateTime createdAt;

  RecentScanSummary({
    required this.id,
    required this.title,
    required this.riskLevel,
    required this.highRiskCount,
    required this.cautionCount,
    required this.compliantCount,
    required this.totalPages,
    required this.sourceType,
    required this.extractionMethod,
    required this.createdAt,
  });

  factory RecentScanSummary.fromJson(Map<String, dynamic> json) {
    return RecentScanSummary(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Document',
      riskLevel: json['riskLevel'] as String? ?? 'Low Risk',
      highRiskCount: json['highRiskCount'] as int? ?? 0,
      cautionCount: json['cautionCount'] as int? ?? 0,
      compliantCount: json['compliantCount'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 1,
      sourceType: json['sourceType'] as String? ?? 'PDF Document',
      extractionMethod: json['extractionMethod'] as String? ?? 'digital_pdf_text',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }

  String get extractionMethodLabel {
    switch (extractionMethod) {
      case 'scanned_pdf_vision':
        return 'Vision AI';
      case 'digital_pdf_text':
        return 'Digital PDF';
      case 'direct_ocr':
        return 'OCR';
      case 'raw_text':
        return 'Direct Text';
      default:
        return extractionMethod;
    }
  }
}

class AdminAnalyticsData {
  final OverviewKpi overview;
  final RiskDistribution riskDistribution;
  final List<FindingCategoryStat> findingCategories;
  final List<SourceTypeStat> sourceDistribution;
  final List<ExtractionMethodStat> extractionMethods;
  final List<RecentScanSummary> recentScans;

  AdminAnalyticsData({
    required this.overview,
    required this.riskDistribution,
    required this.findingCategories,
    required this.sourceDistribution,
    required this.extractionMethods,
    required this.recentScans,
  });

  factory AdminAnalyticsData.fromJson(Map<String, dynamic> json) {
    return AdminAnalyticsData(
      overview: OverviewKpi.fromJson(json['overview']),
      riskDistribution: RiskDistribution.fromJson(json['riskDistribution']),
      findingCategories: (json['findingCategories'] as List<dynamic>?)
              ?.map((item) => FindingCategoryStat.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      sourceDistribution: (json['sourceDistribution'] as List<dynamic>?)
              ?.map((item) => SourceTypeStat.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      extractionMethods: (json['extractionMethods'] as List<dynamic>?)
              ?.map((item) => ExtractionMethodStat.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      recentScans: (json['recentScans'] as List<dynamic>?)
              ?.map((item) => RecentScanSummary.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
