import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_widgets.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';
import '../analysis_screen.dart';
import '../recent_documents_screen.dart';
import '../scan_screen.dart';

class HomeLatestDocCard extends ConsumerWidget {
  final List<RecentDocItem> recentDocs;
  final bool isLoadingDocs;
  final bool isDark;
  final bool isDesktop;
  final Function(Widget) onNavigate;

  const HomeLatestDocCard({
    super.key,
    required this.recentDocs,
    required this.isLoadingDocs,
    required this.isDark,
    required this.isDesktop,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);

    final bool hasDocs = recentDocs.isNotEmpty;
    final RecentDocItem? latestDoc = hasDocs ? recentDocs.first : null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(Icons.analytics_outlined, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.translate('home.latestAnalysisReview'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            loc.translate('home.latestAnalysisSub'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (hasDocs) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => onNavigate(const RecentDocumentsScreen()),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    foregroundColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        loc.translate('home.viewAll', {'count': recentDocs.length.toString()}),
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),

          // Content: Active Latest Document vs Empty State
          if (isLoadingDocs && recentDocs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
                ),
              ),
            )
          else if (!hasDocs || latestDoc == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 12.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.description_outlined,
                        size: 26,
                        color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      loc.translate('home.noAgreementsScanned'),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.translate('home.uploadOrScanAgreement'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => onNavigate(const ScanScreen()),
                      icon: const Icon(Icons.document_scanner_outlined, size: 15),
                      label: Text(
                        loc.translate('home.scanNewDocument'),
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;

                  final docInfo = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: latestDoc.riskColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: latestDoc.riskColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(latestDoc.riskIcon, size: 12, color: latestDoc.riskColor),
                                const SizedBox(width: 4),
                                Text(
                                  latestDoc.riskLabel,
                                  style: GoogleFonts.inter(
                                    color: latestDoc.riskColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${latestDoc.sourceType} • ${latestDoc.dateText}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        latestDoc.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        latestDoc.analysis.isNotEmpty
                            ? loc.translate('home.clausesEvaluated', {'count': latestDoc.analysis.length.toString()})
                            : loc.translate('home.assessmentComplete'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  );

                  final actionButton = ElevatedButton.icon(
                    onPressed: () {
                      if (latestDoc.analysis.isNotEmpty && latestDoc.originalText.isNotEmpty) {
                        onNavigate(
                          AnalysisScreen(
                            originalText: latestDoc.originalText,
                            analysis: latestDoc.analysis,
                            documentTitle: latestDoc.title,
                            sourceType: latestDoc.sourceType,
                            fileData: latestDoc.fileData,
                            mimeType: latestDoc.mimeType,
                            documentId: latestDoc.id,
                          ),
                        );
                      } else {
                        onNavigate(const RecentDocumentsScreen());
                      }
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: Text(
                      loc.translate('home.viewFullAnalysis'),
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        docInfo,
                        const SizedBox(height: 14),
                        actionButton,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: docInfo),
                      const SizedBox(width: 16),
                      actionButton,
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
