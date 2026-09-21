// lib/features/templates/presentation/widgets/frame_picker_sheet.dart
import 'package:flutter/material.dart';
import '../../../../core/models/branding_frame.dart';
import '../../../../core/theme/app_theme.dart';

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
    final isBusinessOrPolitical = _selectedStyle != FrameStyle.personal && _selectedStyle != FrameStyle.minimal;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ब्रांडिंग फ्रेम चुनें (Branding Frame)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'पर्सनल, बिजनेस या राजनीतिक फ्रेम लगाएं',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'फ्रेम स्टाइल (Select Style)',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),

                // Frame Cards
                ...FrameStyle.values.map((style) {
                  final isSelected = style == _selectedStyle;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedStyle = style),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF1E293B) : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(style.emoji, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              style.displayName,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 16),

                // Editable Fields
                const Text(
                  'फ्रेम पर दिखने वाली जानकारी (Details)',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),

                _buildTextField(controller: _nameController, label: 'आपका नाम (Your Name)', icon: Icons.person_rounded),
                const SizedBox(height: 10),

                if (isBusinessOrPolitical) ...[
                  _buildTextField(
                    controller: _businessNameController,
                    label: _selectedStyle == FrameStyle.political
                        ? 'दल / संस्था का नाम (Party / Org)'
                        : 'दुकान / बिजनेस का नाम (Business Name)',
                    icon: Icons.store_rounded,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _designationController,
                    label: _selectedStyle == FrameStyle.political
                        ? 'पद (Designation, e.g. समाजसेवक / युवा नेता)'
                        : 'पद / व्यवसाय (e.g. संचालक / प्रोप्राइटर)',
                    icon: Icons.badge_rounded,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'फोन / WhatsApp नंबर',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _addressController,
                    label: 'शहर / पता (City / Location)',
                    icon: Icons.location_on_rounded,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),

          // Apply Button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _applyChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'फ्रेम लागू करें (Apply Frame)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
        prefixIcon: Icon(icon, color: Colors.white54, size: 18),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}
