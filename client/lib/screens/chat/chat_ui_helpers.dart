import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class HoverGlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isDark;

  const HoverGlassButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<HoverGlassButton> createState() => _HoverGlassButtonState();
}

class _HoverGlassButtonState extends State<HoverGlassButton> {
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
                ? (widget.isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface)
                : (widget.isDark ? AppColors.darkSurface : AppColors.lightSurface),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovered
                  ? (widget.isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                  : (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class HoverGlassIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isDark;

  const HoverGlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<HoverGlassIconButton> createState() => _HoverGlassIconButtonState();
}

class _HoverGlassIconButtonState extends State<HoverGlassIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isHovered
                  ? (widget.isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface)
                  : (widget.isDark ? AppColors.darkSurface : AppColors.lightSurface),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isHovered
                    ? (widget.isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                    : (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
