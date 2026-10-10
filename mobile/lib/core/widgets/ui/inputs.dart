// lib/core/widgets/ui/inputs.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import 'motion.dart';

/// Labelled text field (label sits ABOVE the field for legibility).
///
/// ```dart
/// AppTextField(
///   controller: _name,
///   label: 'आपका नाम',
///   hint: 'जैसे: रमेश कुमार',
///   prefixIcon: Icons.person_outline_rounded,
///   validator: (v) => (v ?? '').trim().isEmpty ? 'नाम लिखें' : null,
/// )
/// ```
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String? label;
  final String? hint;
  final String? helperText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final String? prefixText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback? onTap;
  final AutovalidateMode? autovalidateMode;
  final bool required;

  const AppTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.label,
    this.hint,
    this.helperText,
    this.prefixIcon,
    this.suffix,
    this.prefixText,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.onTap,
    this.autovalidateMode,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text.rich(
              TextSpan(
                text: label,
                children: [
                  if (required)
                    const TextSpan(text: ' *', style: TextStyle(color: AppColors.danger)),
                ],
              ),
              style: AppText.body(size: 14.5, weight: FontWeight.w700, color: p.textPrimary, height: 1.2),
            ),
          ),
        ],
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          validator: validator,
          autovalidateMode: autovalidateMode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          maxLength: maxLength,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          obscureText: obscureText,
          readOnly: readOnly,
          enabled: enabled,
          autofocus: autofocus,
          focusNode: focusNode,
          onTap: onTap,
          style: AppText.body(size: 17, weight: FontWeight.w500, color: p.textPrimary),
          cursorColor: p.primary,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            helperMaxLines: 3,
            errorMaxLines: 3,
            counterText: '',
            prefixText: prefixText,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 22),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

/// Rounded search input (real text field).
///
/// ```dart
/// AppSearchField(controller: _q, hint: 'खोजें...', onSubmitted: _search)
/// ```
class AppSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;
  final FocusNode? focusNode;

  const AppSearchField({
    super.key,
    this.controller,
    this.hint = 'खोजें...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: AppText.body(size: 16.5, weight: FontWeight.w500, color: p.textPrimary),
      cursorColor: p.primary,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 24),
        suffixIcon: onClear == null
            ? null
            : IconButton(
                tooltip: 'साफ़ करें',
                icon: const Icon(Icons.close_rounded, size: 22),
                onPressed: onClear,
              ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(borderRadius: AppRadius.pillAll, borderSide: BorderSide(color: p.border)),
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.pillAll, borderSide: BorderSide(color: p.border)),
        focusedBorder:
            OutlineInputBorder(borderRadius: AppRadius.pillAll, borderSide: BorderSide(color: p.primary, width: 2)),
      ),
    );
  }
}

/// Single pill chip (category / filter).
///
/// ```dart
/// CategoryChip(label: 'सुप्रभात', emoji: '🌅', selected: true, onTap: () {})
/// ```
class CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final String? emoji;
  final Gradient? selectedGradient;

  const CategoryChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.emoji,
    this.selectedGradient,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = selected ? AppColors.white : p.textPrimary;
    return PressableScale(
      onTap: onTap,
      haptic: true,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: selected ? (selectedGradient ?? AppColors.brandGradient) : null,
          color: selected ? null : p.surface,
          borderRadius: AppRadius.pillAll,
          border: Border.all(color: selected ? AppColors.transparent : p.border, width: 1.2),
          boxShadow: selected ? AppShadows.primaryGlow.map((s) => s.scale(0.5)).toList() : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[Text(emoji!, style: const TextStyle(fontSize: 16)), const SizedBox(width: 6)],
            if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 6)],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 14.5, weight: FontWeight.w700, color: fg, height: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontally scrolling row of [CategoryChip]s.
///
/// ```dart
/// FilterPillRow(
///   labels: const ['सभी', 'त्योहार', 'सुविचार'],
///   selectedIndex: _i,
///   onSelected: (i) => setState(() => _i = i),
/// )
/// ```
class FilterPillRow extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<String?>? emojis;
  final EdgeInsetsGeometry padding;
  final double height;

  const FilterPillRow({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.emojis,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.page),
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, i) => Center(
          child: CategoryChip(
            label: labels[i],
            emoji: emojis != null && i < emojis!.length ? emojis![i] : null,
            selected: i == selectedIndex,
            onTap: () => onSelected(i),
          ),
        ),
      ),
    );
  }
}
