import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';

// ==========================================
// HOME SCREEN — EXTRACTED STANDALONE WIDGETS & MODELS
// Sidebar nav item, workspace metric card, recent-document model,
// and the decorative illustration painter used by HomeScreen.
// These are fully self-contained (no HomeScreen state dependency),
// which is what makes this split safe.
// ==========================================

// ==========================================
// SIDEBAR NAVIGATION ITEM WIDGET
// ==========================================
class SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const SidebarNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<SidebarNavItem> createState() => SidebarNavItemState();
}

class SidebarNavItemState extends State<SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isActive = widget.isActive;

    Color itemColor;
    if (isActive) {
      itemColor = isDark ? AppColors.darkAccent : AppColors.lightPrimary;
    } else if (_isHovered) {
      itemColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    } else {
      itemColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    }

    Color bgColor;
    if (isActive) {
      bgColor = (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: 0.12);
    } else if (_isHovered) {
      bgColor = (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: 0.06);
    } else {
      bgColor = Colors.transparent;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(
                  color: isActive
                      ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                      : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 18,
                  color: itemColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: itemColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// WORKSPACE METRIC DATA & CARD
// ==========================================
class WorkspaceMetricData {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color accentColor;

  WorkspaceMetricData({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accentColor,
  });
}

class WorkspaceMetricCard extends StatelessWidget {
  final WorkspaceMetricData data;
  final bool isDark;

  const WorkspaceMetricCard({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final item = data;

    return Container(
      constraints: const BoxConstraints(minHeight: 110),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, color: item.accentColor, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                item.value,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// RECENT DOCUMENT MODEL
// ==========================================
class RecentDocItem {
  final String id;
  final String title;
  final String dateText;
  final String riskLabel;
  final IconData riskIcon;
  final Color riskColor;
  final String docSize;
  final String originalText;
  final List<dynamic> analysis;
  final String sourceType;
  final String? fileData;
  final String? mimeType;
  final String analysisStatus;

  RecentDocItem({
    required this.id,
    required this.title,
    required this.dateText,
    required this.riskLabel,
    required this.riskIcon,
    required this.riskColor,
    required this.docSize,
    this.originalText = '',
    this.analysis = const [],
    this.sourceType = 'PDF Document',
    this.fileData,
    this.mimeType,
    this.analysisStatus = 'completed',
  });

  factory RecentDocItem.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] as String?) ?? 'Legal Document';
    final riskLevel = (json['riskLevel'] as String?) ?? 'Low Risk';
    final docSize = (json['docSize'] as String?) ?? '1.2 MB';
    final createdAt = json['createdAt'];
    final dateText = 'Scanned ${formatRelativeTime(createdAt)}';
    final originalText = (json['originalText'] as String?) ?? '';
    final analysis = (json['analysis'] as List<dynamic>?) ?? [];
    final sourceType = (json['sourceType'] as String?) ?? 'PDF Document';
    final fileData = json['fileData'] as String?;
    final mimeType = json['mimeType'] as String?;
    final analysisStatus = (json['analysisStatus'] as String?) ?? 'completed';

    Color riskColor = AppColors.lightSecondary;
    IconData riskIcon = Icons.check_circle_outline_rounded;
    final rLower = riskLevel.toLowerCase();
    if (rLower.contains('high') || rLower.contains('red')) {
      riskColor = AppColors.lightError;
      riskIcon = Icons.error_outline_rounded;
    } else if (rLower.contains('medium') || rLower.contains('yellow') || rLower.contains('caution')) {
      riskColor = AppColors.lightCaution;
      riskIcon = Icons.warning_amber_rounded;
    }

    return RecentDocItem(
      id: (json['_id'] as String?) ?? '',
      title: title,
      dateText: dateText,
      riskLabel: riskLevel,
      riskIcon: riskIcon,
      riskColor: riskColor,
      docSize: docSize,
      originalText: originalText,
      analysis: analysis,
      sourceType: sourceType,
      fileData: fileData,
      mimeType: mimeType,
      analysisStatus: analysisStatus,
    );
  }
}

String formatRelativeTime(dynamic dateValue) {
  if (dateValue == null) return 'Recent';
  try {
    DateTime? dt;
    if (dateValue is DateTime) {
      dt = dateValue;
    } else {
      dt = DateTime.tryParse(dateValue.toString());
      if (dt == null) {
        final raw = dateValue.toString();
        final parts = raw.split(' ');
        if (parts.length >= 4) {
          return '${parts[1]} ${parts[2]} ${parts[3]}';
        }
      }
    }
    if (dt != null) {
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60 && diff.inSeconds >= 0) {
        return 'Just now';
      } else if (diff.inMinutes < 60 && diff.inMinutes >= 0) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24 && diff.inHours >= 0) {
        return '${diff.inHours}h ago';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7 && diff.inDays > 1) {
        return '${diff.inDays}d ago';
      } else {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final monthName = (dt.month >= 1 && dt.month <= 12) ? months[dt.month - 1] : '';
        return '${dt.day} $monthName ${dt.year}';
      }
    }
  } catch (_) {}
  return dateValue.toString();
}

// ==========================================
// CUSTOM ILLUSTRATION PAINTER
// ==========================================
class LegalPropertyIllustrationPainter extends CustomPainter {
  final Color accentBlue;
  final Color accentGold;
  final bool isDark;

  LegalPropertyIllustrationPainter({
    required this.accentBlue,
    required this.accentGold,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = accentBlue.withValues(alpha: isDark ? 0.38 : 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final goldStroke = Paint()
      ..color = accentGold.withValues(alpha: isDark ? 0.45 : 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final subtlePaint = Paint()
      ..color = accentBlue.withValues(alpha: isDark ? 0.2 : 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = accentBlue.withValues(alpha: isDark ? 0.06 : 0.03)
      ..style = PaintingStyle.fill;

    // Building Outline
    final b1Rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(12, 32, 22, 48),
      const Radius.circular(2),
    );
    canvas.drawRRect(b1Rect, fillPaint);
    canvas.drawRRect(b1Rect, strokePaint);
    for (double y = 40; y <= 70; y += 10) {
      canvas.drawLine(Offset(18, y), Offset(22, y), subtlePaint);
      canvas.drawLine(Offset(25, y), Offset(29, y), subtlePaint);
    }

    final b2Path = Path()
      ..moveTo(34, 80)
      ..lineTo(34, 24)
      ..lineTo(48, 12)
      ..lineTo(62, 24)
      ..lineTo(62, 80);
    canvas.drawPath(b2Path, fillPaint);
    canvas.drawPath(b2Path, strokePaint);

    final b3Path = Path()
      ..moveTo(62, 80)
      ..lineTo(62, 42)
      ..lineTo(76, 42)
      ..lineTo(76, 80);
    canvas.drawPath(b3Path, fillPaint);
    canvas.drawPath(b3Path, strokePaint);

    // Scale of Justice
    canvas.drawLine(const Offset(108, 22), const Offset(108, 72), strokePaint);
    canvas.drawLine(const Offset(98, 72), const Offset(118, 72), strokePaint);
    canvas.drawCircle(const Offset(108, 20), 2.5, goldStroke);
    canvas.drawLine(const Offset(90, 28), const Offset(126, 28), goldStroke);

    // Verified Document
    final docPath = Path()
      ..moveTo(146, 76)
      ..lineTo(146, 18)
      ..lineTo(170, 18)
      ..lineTo(182, 30)
      ..lineTo(182, 76)
      ..close();
    canvas.drawPath(docPath, fillPaint);
    canvas.drawPath(docPath, strokePaint);

    canvas.drawCircle(const Offset(172, 64), 5.5, goldStroke);
  }

  @override
  bool shouldRepaint(covariant LegalPropertyIllustrationPainter oldDelegate) {
    return oldDelegate.accentBlue != accentBlue ||
        oldDelegate.accentGold != accentGold ||
        oldDelegate.isDark != isDark;
  }
}

// ==========================================
// RERA DETAILS DIALOG
// Shared between the sidebar's "RERA Compliance" item and the dashboard's
// RERA awareness card, both of which need to show a legal advisory dialog
// or open a related news link.
// ==========================================
Future<void> handleReraDetails(
  BuildContext context,
  WidgetRef ref,
  String alertLink,
  String alertTitle,
  String alertDesc,
) async {
  if (alertLink.isNotEmpty) {
    final Uri url = Uri.parse(alertLink);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return;
    }
  }
  if (context.mounted) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogContext) {
        final loc = ref.read(localeProvider.notifier);
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          title: Row(
            children: [
              Icon(Icons.shield_outlined, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  loc.translate('home.reraAdvisoryDetails'),
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            '$alertTitle\n\n$alertDesc\n\n${loc.translate('home.reraStatutoryNote')}',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              height: 1.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                foregroundColor: Colors.white,
              ),
              child: Text(loc.translate('common.understood')),
            ),
          ],
        );
      },
    );
  }
}
