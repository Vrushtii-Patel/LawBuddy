import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';

class DualDirectionMarquee extends ConsumerStatefulWidget {
  final bool isDark;
  const DualDirectionMarquee({super.key, required this.isDark});

  @override
  ConsumerState<DualDirectionMarquee> createState() => _DualDirectionMarqueeState();
}

class _DualDirectionMarqueeState extends ConsumerState<DualDirectionMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 32),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);
    final isDark = widget.isDark;
    final track1Text = loc.translate('welcome.marqueeTrack1');
    final track2Text = loc.translate('welcome.marqueeTrack2');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.symmetric(
          horizontal: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Line 1: Moving Left
          _buildMarqueeTrack(
            text: track1Text,
            moveLeft: true,
            isDark: isDark,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
          const SizedBox(height: 10),
          // Line 2: Moving Right (Opposite Direction)
          _buildMarqueeTrack(
            text: track2Text,
            moveLeft: false,
            isDark: isDark,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildMarqueeTrack({
    required String text,
    required bool moveLeft,
    required bool isDark,
    required Color color,
  }) {
    return SizedBox(
      height: 24,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                const singleChunkWidth = 1180.0;
                final offset = moveLeft
                    ? -(_controller.value * singleChunkWidth)
                    : ((_controller.value - 1.0) * singleChunkWidth);

                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    Positioned(
                      left: offset,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(6, (_) {
                            return Text(
                              text,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.0,
                                color: color,
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
