// lib/core/router/app_shell.dart
//
// Main shell (bottom navigation) used by the tab routes.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../widgets/ui/layout.dart';
import '../widgets/ui/motion.dart';

/// Global switches a tab screen can flip to restyle the shell.
///
/// A dark, full-bleed screen (e.g. the immersive Home feed) sets
/// `AppShell.immersive.value = true` in `initState` (post-frame) and resets it in
/// `dispose`; the nav bar then renders its dark glass variant and the shell
/// background turns ink so there is no light gap around the floating bar.
class AppShell {
  AppShell._();
  static final ValueNotifier<bool> immersive = ValueNotifier<bool>(false);

  /// Height the floating nav bar occupies (incl. its outer margin, excl. safe area).
  static const double navHeight = 68;
  static const double navMargin = 12;
}

class _Dest {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  const _Dest({required this.icon, required this.activeIcon, required this.label, required this.path});
}

const _destinations = <_Dest>[
  _Dest(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'होम', path: '/home'),
  _Dest(icon: Icons.explore_outlined, activeIcon: Icons.explore_rounded, label: 'खोजें', path: '/discover'),
  _Dest(icon: Icons.bookmark_outline_rounded, activeIcon: Icons.bookmark_rounded, label: 'सहेजें', path: '/saved'),
  _Dest(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'प्रोफ़ाइल', path: '/profile'),
];

/// Scaffold with the floating pill nav. Use as the ShellRoute builder.
class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    var selected = 0;
    for (var i = 0; i < _destinations.length; i++) {
      if (location.startsWith(_destinations[i].path)) {
        selected = i;
        break;
      }
    }

    return ValueListenableBuilder<bool>(
      valueListenable: AppShell.immersive,
      builder: (context, immersive, _) {
        final bar = _FloatingNavBar(
          selectedIndex: selected,
          dark: immersive || context.isDarkTheme,
          onSelected: (i) {
            HapticFeedback.selectionClick();
            if (i != selected) context.go(_destinations[i].path);
          },
        );
        final scaffold = Scaffold(
          backgroundColor: immersive ? AppColors.inkSurface : context.palette.bg,
          body: child,
          bottomNavigationBar: bar,
        );
        return immersive ? ImmersiveTheme(child: scaffold) : scaffold;
      },
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final bool dark;
  final ValueChanged<int> onSelected;

  const _FloatingNavBar({required this.selectedIndex, required this.dark, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final palette = dark ? AppPalette.dark : AppPalette.light;
    final bg = dark ? AppColors.inkSurface : context.palette.bg;

    return ColoredBox(
      color: bg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 4, AppSpacing.md, AppShell.navMargin),
          child: Container(
            height: AppShell.navHeight - 8,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: dark ? AppColors.inkSurface3 : AppColors.surface,
              borderRadius: AppRadius.pillAll,
              border: Border.all(color: dark ? AppColors.glassBorder : palette.border),
              boxShadow: dark ? null : AppShadows.floating,
            ),
            child: LayoutBuilder(
              builder: (context, c) {
                final activeW = c.maxWidth * 0.34;
                final inactiveW = (c.maxWidth - activeW) / (_destinations.length - 1);
                return Row(
                  children: [
                    for (var i = 0; i < _destinations.length; i++)
                      _NavItem(
                        dest: _destinations[i],
                        selected: i == selectedIndex,
                        width: i == selectedIndex ? activeW : inactiveW,
                        inactiveColor: palette.textMuted,
                        onTap: () => onSelected(i),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _Dest dest;
  final bool selected;
  final double width;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.dest,
    required this.selected,
    required this.width,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: dest.label,
      excludeSemantics: true,
      onTap: onTap,
      child: PressableScale(
        onTap: onTap,
        scale: 0.94,
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.standard,
          width: width,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: selected ? AppColors.brandGradient : null,
            borderRadius: AppRadius.pillAll,
            boxShadow: selected ? AppShadows.primaryGlow.map((s) => s.scale(0.4)).toList() : null,
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: AppMotion.fast,
                    child: Icon(
                      selected ? dest.activeIcon : dest.icon,
                      key: ValueKey(selected),
                      size: 26,
                      color: selected ? AppColors.white : inactiveColor,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 6),
                    Text(
                      dest.label,
                      maxLines: 1,
                      style: AppText.body(size: 14, weight: FontWeight.w800, color: AppColors.white, height: 1.1),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
