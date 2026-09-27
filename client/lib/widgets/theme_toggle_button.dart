import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Semantics(
      toggled: isDark,
      label: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      button: true,
      excludeSemantics: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => RotationTransition(
          turns: child.key == const ValueKey('icon1')
              ? Tween<double>(begin: 1, end: 0).animate(anim)
              : Tween<double>(begin: 0.75, end: 1).animate(anim),
          child: ScaleTransition(scale: anim, child: child),
        ),
        child: IconButton(
          key: ValueKey(isDark),
          icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
          onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
        ),
      ),
    );
  }
}
