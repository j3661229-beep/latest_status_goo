// lib/features/templates/presentation/widgets/frame_picker_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/branding_frame.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_ui.dart';
import 'editor_sheet_frame.dart';

class FramePickerSheet extends StatefulWidget {
  final BrandingFrameData initialData;
  final Function(BrandingFrameData updated) onApply;

  const FramePickerSheet({
    super.key,
    required this.initialData,
    required this.onApply,
  });

  @override
  State<FramePickerSheet> createState() => _FramePickerSheetState();
}

class _FramePickerSheetState extends State<FramePickerSheet> {
  late FrameStyle _selectedStyle;
  late TextEditingController _nameController;
  late TextEditingController _businessNameController;
  late TextEditingController _designationController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _selectedStyle = widget.initialData.style;
    _nameController = TextEditingController(text: widget.initialData.name);
    _businessNameController = TextEditingController(text: widget.initialData.businessName ?? '');
    _designationController = TextEditingController(text: widget.initialData.businessDesignation ?? '');
    _phoneController = TextEditingController(text: widget.initialData.businessPhone ?? '');
    _addressController = TextEditingController(text: widget.initialData.businessAddress ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessNameController.dispose();
    _designationController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _applyChanges() {
    final updated = widget.initialData.copyWith(
      style: _selectedStyle,
      name: _nameController.text.trim(),
      businessName: _businessNameController.text.trim(),
      businessDesignation: _designationController.text.trim(),
      businessPhone: _phoneController.text.trim(),
      businessAddress: _addressController.text.trim(),
    );
    widget.onApply(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isBusinessOrPolitical = _selectedStyle != FrameStyle.personal && _selectedStyle != FrameStyle.minimal;

    return EditorSheetFrame(
      title: 'ब्रांडिंग फ्रेम चुनें',
      subtitle: 'पर्सनल, बिजनेस या राजनीतिक फ्रेम लगाएं',
      heightFactor: 0.82,
      footer: GradientButton(
        label: 'फ्रेम लागू करें',
        icon: Icons.check_rounded,
        onPressed: _applyChanges,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('फ्रेम स्टाइल', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: p.textMuted)),
          const SizedBox(height: AppSpacing.xs),
          for (final style in FrameStyle.values) _styleCard(context, style),
          const SizedBox(height: AppSpacing.md),
          Text('फ्रेम पर दिखने वाली जानकारी',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: p.textMuted)),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _nameController,
            label: 'आपका नाम',
            prefixIcon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          if (isBusinessOrPolitical) ...[
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _businessNameController,
              label: _selectedStyle == FrameStyle.political ? 'दल / संस्था का नाम' : 'दुकान / बिजनेस का नाम',
              prefixIcon: Icons.storefront_rounded,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _designationController,
              label: _selectedStyle == FrameStyle.political ? 'पद (जैसे समाजसेवक / युवा नेता)' : 'पद / व्यवसाय (जैसे संचालक)',
              prefixIcon: Icons.badge_outlined,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _phoneController,
              label: 'फोन / WhatsApp नंबर',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _addressController,
              label: 'शहर / पता',
              prefixIcon: Icons.location_on_outlined,
              textInputAction: TextInputAction.done,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Widget _styleCard(BuildContext context, FrameStyle style) {
    final p = context.palette;
    final selected = style == _selectedStyle;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: PressableScale(
        scale: 0.98,
        semanticLabel: style.displayName,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedStyle = style);
        },
        child: AnimatedContainer(
          duration: AppMotion.fast,
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? p.primarySurface : p.surfaceMuted,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: selected ? p.primary : p.border, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Text(style.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  style.displayName,
                  style: AppText.body(
                    size: 16,
                    weight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: p.textPrimary,
                    height: 1.25,
                  ),
                ),
              ),
              if (selected) Icon(Icons.check_circle_rounded, color: p.primary, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
