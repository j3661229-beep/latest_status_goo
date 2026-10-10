// lib/features/templates/presentation/widgets/editor_sheet_frame.dart
//
// Shared chrome for the editor bottom sheets (frame / quote / name / photo):
// rounded themed surface, drag handle, header, scrollable body and an optional
// pinned footer (primary action).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_ui.dart';

class EditorSheetFrame extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// Fraction of the screen height the sheet may use (null = wrap content).
  final double? heightFactor;

  /// Body. When [scrollBody] is true it is wrapped in a scroll view, otherwise
  /// it is placed in an [Expanded]/[Flexible] and must scroll on its own.
  final Widget child;
  final bool scrollBody;
  final Widget? footer;

  const EditorSheetFrame({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.heightFactor,
    this.scrollBody = true,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final inset = media.viewInsets.bottom;

    final body = scrollBody
        ? SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.md),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: child,
          )
        : child;

    final column = Column(
      mainAxisSize: heightFactor == null ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHandle(),
        SheetHeader(title: title, subtitle: subtitle),
        if (heightFactor == null) Flexible(child: body) else Expanded(child: body),
        if (footer != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.xs,
              AppSpacing.page,
              AppSpacing.md + (inset > 0 ? 0 : media.padding.bottom),
            ),
            child: footer,
          ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(top: media.padding.top + AppSpacing.xl),
      child: AnimatedPadding(
        duration: AppMotion.fast,
        padding: EdgeInsets.only(bottom: inset),
        child: Container(
          height: heightFactor == null
              ? null
              : (media.size.height * heightFactor!).clamp(0.0, math.max(0.0, media.size.height - inset - media.padding.top - AppSpacing.xl)).toDouble(),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            border: Border.all(color: p.border),
          ),
          child: column,
        ),
      ),
    );
  }
}
