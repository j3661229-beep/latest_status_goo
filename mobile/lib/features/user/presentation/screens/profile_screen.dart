// lib/features/user/presentation/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';
import '../../../auth/domain/models/user_model.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final displayName = user?.displayName ?? user?.name ?? 'User';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final isPremium = user?.isPremium ?? false;
    final language = _langLabel(user?.language ?? 'HINDI');

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── Profile Header ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(gradient: AppColors.brandGradient),
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 28),
              child: FadeInDown(
                duration: const Duration(milliseconds: 600),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        color: Colors.white.withOpacity(0.2),
                        image: user?.profilePhoto != null
                            ? DecorationImage(
                                image: NetworkImage(user!.profilePhoto!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: user?.profilePhoto == null
                          ? Center(
                              child: Text(
                                initial,
                                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    if (user?.email != null || user?.phoneNumber != null)
                      Text(
                        user?.email ?? user?.phoneNumber ?? '',
                        style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
                      ),
                    const SizedBox(height: 14),
                    // Plan + Language badges
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PillBadge(
                          text: isPremium ? '⭐ Premium' : '🆓 Free Plan',
                          color: isPremium ? AppColors.warning : Colors.white.withOpacity(0.25),
                          textColor: isPremium ? Colors.black : Colors.white,
                        ),
                        const SizedBox(width: 10),
                        _PillBadge(
                          text: '🌐 $language',
                          color: Colors.white.withOpacity(0.2),
                          textColor: Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Stats Row ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeIn(
              duration: const Duration(milliseconds: 700),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.surfaceBorder),
                  boxShadow: AppColors.cardShadow,
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _StatTile(
                      emoji: '🔥',
                      value: user?.streakCount.toString() ?? '0',
                      label: 'Day Streak',
                    ),
                    _VerticalDivider(),
                    _StatTile(
                      emoji: '📤',
                      value: user?.totalShares.toString() ?? '0',
                      label: 'Shares',
                    ),
                    _VerticalDivider(),
                    _StatTile(
                      emoji: '🔖',
                      value: user?.totalSaves.toString() ?? '0',
                      label: 'Saved',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Premium CTA (if not premium) ────────────────────────────────
          if (!isPremium)
            SliverToBoxAdapter(
              child: FadeInUp(
                duration: const Duration(milliseconds: 700),
                child: GestureDetector(
                  onTap: () => context.push('/premium'),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppColors.cardShadowFor(AppColors.primary),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                          child: const Text('⭐', style: TextStyle(fontSize: 22)),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Upgrade to Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                              Text('Unlimited status · Starting ₹99/month', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Settings Sections ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeInUp(
              duration: const Duration(milliseconds: 800),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _SectionLabel('Account'),
                    _SettingsCard(children: [
                      _SettingRow(icon: Icons.person_outline_rounded, label: 'Edit Profile', onTap: () {}),
                      _SettingRow(icon: Icons.language_rounded, label: 'Language', value: language, onTap: () {}),
                      _SettingRow(icon: Icons.notifications_outlined, label: 'Notifications', value: 'On', onTap: () {}),
                    ]),

                    const SizedBox(height: 16),
                    _SectionLabel('Business Branding & Frames (क्राफ्टो फीचर्स)'),
                    _SettingsCard(children: [
                      _SettingRow(
                        icon: Icons.storefront_rounded,
                        label: 'Business Details & Branding',
                        value: user?.businessName?.isNotEmpty == true ? user!.businessName : 'सेट करें (Setup)',
                        onTap: () => _showBusinessBrandingDialog(context, ref, user),
                      ),
                      _SettingRow(
                        icon: Icons.crop_portrait_rounded,
                        label: 'Default Frame Style',
                        value: _getFrameTypeName(user?.frameType),
                        onTap: () => _showBusinessBrandingDialog(context, ref, user),
                      ),
                    ]),

                    const SizedBox(height: 16),
                    _SectionLabel('Support'),
                    _SettingsCard(children: [
                      _SettingRow(icon: Icons.help_outline_rounded, label: 'Help & FAQ', onTap: () {}),
                      _SettingRow(icon: Icons.star_outline_rounded, label: 'Rate the App', onTap: () {}),
                      _SettingRow(icon: Icons.share_outlined, label: 'Share with Friends', onTap: () {}),
                    ]),

                    const SizedBox(height: 16),
                    _SectionLabel('About'),
                    _SettingsCard(children: [
                      _SettingRow(icon: Icons.info_outline_rounded, label: 'App Version', value: '1.0.0', onTap: null),
                      _SettingRow(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy', onTap: () {}),
                    ]),

                    const SizedBox(height: 16),
                    // Sign Out
                    GestureDetector(
                      onTap: () async {
                        await ref.read(authRepositoryProvider).signOut();
                        if (context.mounted) context.go('/login');
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.danger.withOpacity(0.15)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
                            SizedBox(width: 10),
                            Text('Sign Out', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _langLabel(String code) {
    switch (code) {
      case 'HINDI': return 'Hindi';
      case 'MARATHI': return 'Marathi';
      case 'ENGLISH': return 'English';
      default: return code;
    }
  }

  String _getFrameTypeName(String? type) {
    switch (type) {
      case 'businessClassic': return 'Classic Business';
      case 'businessModern': return 'Modern Business';
      case 'political': return 'Political / Leader';
      case 'minimal': return 'Minimal Clean';
      default: return 'Personal Frame';
    }
  }

  void _showBusinessBrandingDialog(BuildContext context, WidgetRef ref, UserModel? user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BusinessBrandingSheet(user: user, ref: ref),
    );
  }
}

class _BusinessBrandingSheet extends StatefulWidget {
  final UserModel? user;
  final WidgetRef ref;

  const _BusinessBrandingSheet({required this.user, required this.ref});

  @override
  State<_BusinessBrandingSheet> createState() => _BusinessBrandingSheetState();
}

class _BusinessBrandingSheetState extends State<_BusinessBrandingSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _desigController;
  late final TextEditingController _addressController;
  late String _selectedFrameType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.businessName ?? '');
    _phoneController = TextEditingController(text: widget.user?.businessPhone ?? widget.user?.phoneNumber ?? '');
    _desigController = TextEditingController(text: widget.user?.businessDesignation ?? '');
    _addressController = TextEditingController(text: widget.user?.businessAddress ?? '');
    _selectedFrameType = widget.user?.frameType ?? 'personal';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _desigController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.ref.read(authRepositoryProvider).updateBusinessBranding(
        businessName: _nameController.text.trim(),
        businessPhone: _phoneController.text.trim(),
        businessDesignation: _desigController.text.trim(),
        businessAddress: _addressController.text.trim(),
        frameType: _selectedFrameType,
      );

      widget.ref.invalidate(currentUserProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'बिजनेस ब्रांडिंग और फ्रेम सफलतापूर्वक सेव हो गई!',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('सेव करने में त्रुटि: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sheet Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'बिजनेस ब्रांडिंग और फ्रेम',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'यह जानकारी आपके स्टेटस पोस्टर्स पर दिखेगी',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Frame Type Selector
            Text(
              'डिफ़ॉल्ट फ्रेम स्टाइल (Frame Style)',
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFrameChip('personal', '👤 व्यक्तिगत (Personal)'),
                _buildFrameChip('businessClassic', '🏢 क्लासिक बिजनेस'),
                _buildFrameChip('businessModern', '✨ मॉडर्न बिजनेस'),
                _buildFrameChip('political', '🚩 नेता / राजनेता'),
                _buildFrameChip('minimal', '🔹 मिनिमल'),
              ],
            ),
            const SizedBox(height: 16),

            // Form Inputs
            _buildTextField(
              controller: _nameController,
              label: 'बिजनेस / दुकान का नाम (Business Name)',
              hint: 'उदा. शर्मा इलेक्ट्रॉनिक्स / Sharma Jewellers',
              icon: Icons.business_rounded,
            ),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _phoneController,
              label: 'मोबाइल / WhatsApp नंबर',
              hint: '+91 98765 43210',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _desigController,
              label: 'पद / टैगलाइन (Designation / Tagline)',
              hint: 'उदा. प्रोपराइटर / समाजसेवी / संचालक',
              icon: Icons.badge_rounded,
            ),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _addressController,
              label: 'पता / शहर (Shop Address / City)',
              hint: 'उदा. मेन मार्केट, इंदौर (म.प्र.)',
              icon: Icons.location_on_rounded,
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'सेव और लागू करें (Save & Apply)',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrameChip(String type, String label) {
    final isSelected = _selectedFrameType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedFrameType = type);
      },
      selectedColor: AppColors.primary,
      backgroundColor: const Color(0xFFF3F4F6),
      labelStyle: GoogleFonts.outfit(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted),
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  const _PillBadge({required this.text, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  const _StatTile({required this.emoji, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.primary)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 50, color: AppColors.surfaceBorder);
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: List.generate(children.length, (i) {
          if (i == children.length - 1) return children[i];
          return Column(
            children: [
              children[i],
              const Divider(height: 1, color: AppColors.surfaceBorder, indent: 56),
            ],
          );
        }),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  const _SettingRow({required this.icon, required this.label, this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary))),
            if (value != null)
              Text(value!, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(width: 8),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
