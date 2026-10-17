import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';

class PromptCard extends ConsumerStatefulWidget {
  final int index;
  final String category;
  final IconData icon;
  final Color accentColor;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool isDark;

  const PromptCard({
    super.key,
    required this.index,
    required this.category,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.description,
    required this.onTap,
    required this.isDark,
  });

  @override
  ConsumerState<PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends ConsumerState<PromptCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final itemAccent = widget.accentColor;
    final isDark = widget.isDark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.translationValues(0, _isHovered ? -2.0 : 0, 0),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered
                  ? itemAccent.withValues(alpha: 0.8)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: itemAccent.withValues(alpha: isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, color: itemAccent, size: 16),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: itemAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.category,
                      style: GoogleFonts.plusJakartaSans(
                        color: itemAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                widget.description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  height: 1.35,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HoverableChip extends StatefulWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  final bool fullWidth;

  const HoverableChip({
    super.key,
    required this.label,
    required this.isDark,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  State<HoverableChip> createState() => _HoverableChipState();
}

class _HoverableChipState extends State<HoverableChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: widget.fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark
                    ? AppColors.darkElevatedSurface
                    : AppColors.lightElevatedSurface)
                : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize:
                widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.help_outline_rounded,
                size: 14,
                color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.label,
                  softWrap: true,
                  style: GoogleFonts.plusJakartaSans(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                size: 13,
                color: isDark
                    ? AppColors.darkTextSecondary.withValues(alpha: 0.5)
                    : AppColors.lightTextSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
