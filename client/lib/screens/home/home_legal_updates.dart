import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';
import 'home_widgets.dart';

class HomeLegalUpdatesCard extends ConsumerWidget {
  final List<dynamic> legalNews;
  final bool isLoadingNews;
  final bool isDark;

  const HomeLegalUpdatesCard({
    super.key,
    required this.legalNews,
    required this.isLoadingNews,
    required this.isDark,
  });

  Future<void> _launchNewsUrl(BuildContext context, String? link) async {
    if (link == null || link.trim().isEmpty) {
      _showErrorSnackBar(context);
      return;
    }
    try {
      final uri = Uri.parse(link.trim());
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) return;
      }
      if (context.mounted) {
        _showErrorSnackBar(context);
      }
    } catch (e) {
      debugPrint('Error opening legal news URL: $e');
      if (context.mounted) {
        _showErrorSnackBar(context);
      }
    }
  }

  void _showErrorSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Unable to open this link. Please try again.',
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);

    final news = legalNews;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.feed_outlined, color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary, size: 17),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.translate('home.legalIntelligence'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            loc.translate('home.legalIntelligenceSub'),
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  loc.translate('common.live'),
                  style: GoogleFonts.inter(
                    color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (isLoadingNews && legalNews.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
                ),
              ),
            )
          else if (news.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                loc.translate('home.noLegalUpdates'),
                style: GoogleFonts.inter(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontSize: 12,
                ),
              ),
            )
          else ...[
            for (int i = 0; i < news.take(2).length; i++) ...[
              Container(
                margin: EdgeInsets.only(bottom: i < news.take(2).length - 1 ? 8 : 0),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _launchNewsUrl(context, news[i]['link']?.toString()),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (news[i]['title'] ?? 'Legal Notice').toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${news[i]['source'] ?? 'Legal News'} • ${formatRelativeTime(news[i]['pubDate'])}',
                                  style: GoogleFonts.inter(
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 14,
                            color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
