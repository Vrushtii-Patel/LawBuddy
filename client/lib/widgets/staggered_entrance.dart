import 'package:flutter/material.dart';

/// Wraps [child] in a subtle fade + upward-slide entrance animation, delayed
/// proportionally to [index]. Intended for list items that should appear one
/// after another rather than all at once — e.g. clause risk cards in the
/// analysis results, reinforcing the "AI is revealing findings" moment.
///
/// Deliberately understated (a short fade + a few pixels of slide) rather
/// than bouncy or playful, to match a legal-document tool's tone. The delay
/// is capped so a long list (many clauses) doesn't take several seconds to
/// finish appearing — items beyond [maxStaggeredIndex] all animate in
/// together with the last staggered one.
///
/// Built with implicit animations (AnimatedOpacity/AnimatedSlide) rather
/// than a custom AnimationController, so it's fully self-contained and has
/// no dependency on — or effect on — the parent widget's own animation
/// lifecycle.
class StaggeredEntrance extends StatefulWidget {
  final int index;
  final Widget child;
  final int maxStaggeredIndex;
  final Duration stepDelay;
  final Duration animationDuration;

  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.maxStaggeredIndex = 10,
    this.stepDelay = const Duration(milliseconds: 45),
    this.animationDuration = const Duration(milliseconds: 340),
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    final cappedIndex = widget.index.clamp(0, widget.maxStaggeredIndex);
    final delay = widget.stepDelay * cappedIndex;
    Future.delayed(delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 0.04),
      duration: widget.animationDuration,
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: widget.animationDuration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}