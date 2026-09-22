// lib/features/user/presentation/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    final displayName = user?.displayName ?? user?.name ?? 'उपयोगकर्ता';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final isPremium = user?.isPremium ?? false;
    final language = _langLabel(user?.language ?? 'HINDI');

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          'मेरी प्रोफाइल (Profile)',
          style: GoogleFonts.hind(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 24),
            tooltip: 'लॉगआउट (Sign Out)',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('लॉगआउट करें?', style: GoogleFonts.hind(fontWeight: FontWeight.w700)),
                  content: Text('क्या आप सचमुच ऐप से बाहर निकलना चाहते हैं?', style: GoogleFonts.hind(fontSize: 15)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('रद्द करें', style: GoogleFonts.hind(color: AppColors.textMuted)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(90, 40)),
                      child: Text('लॉगआउट', style: GoogleFonts.hind(fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) context.go('/login');
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Profile Header (Solid Royal Blue banner) ─────────────────
            Container(
              color: AppColors.primary,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 84,
                    height: 84,
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
                              style: GoogleFonts.hind(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    displayName,
                    style: GoogleFonts.hind(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  if (user?.phoneNumber != null || user?.email != null)
                    Text(
                      user?.phoneNumber ?? user?.email ?? '',
                      style: GoogleFonts.hind(color: Colors.white.withOpacity(0.85), fontSize: 14),
                    ),
                  const SizedBox(height: 12),
                  // Badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPremium ? AppColors.accent : Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          isPremium ? '⭐ प्रीमियम सदस्य' : 'फ्री प्लान (Free)',
                          style: GoogleFonts.hind(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '🌐 $language',
                          style: GoogleFonts.hind(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Stats Row ────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceBorder),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                children: [
                  _StatTile(
                    emoji: '🔥',
                    value: user?.streakCount.toString() ?? '0',
                    label: 'दिन स्ट्रीक',
                  ),
                  Container(width: 1, height: 40, color: AppColors.surfaceBorder),
                  _StatTile(
                    emoji: '📤',
                    value: user?.totalShares.toString() ?? '0',
                    label: 'कुल शेयर',
                  ),
                  Container(width: 1, height: 40, color: AppColors.surfaceBorder),
                  _StatTile(
                    emoji: '🔖',
                    value: user?.totalSaves.toString() ?? '0',
                    label: 'सेव किए गए',
                  ),
                ],
              ),
            ),

            // ── Premium Upgrade Card (if not premium) ───────────────────
            if (!isPremium)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.workspace_premium, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'प्रीमियम में अपग्रेड करें ⭐',
                            style: GoogleFonts.hind(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          Text(
                            'सभी स्टेटस और कस्टम फ्रेम अनलॉक करें',
                            style: GoogleFonts.hind(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => context.push('/premium'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(80, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('देखें', style: GoogleFonts.hind(fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ],
                ),
              ),

            // ── Business Branding Section ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'बिजनेस ब्रांडिंग और फ्रेम (Business Framing)',
                    style: GoogleFonts.hind(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.storefront, color: AppColors.primary, size: 24),
                          title: Text('दुकान / बिजनेस की जानकारी', style: GoogleFonts.hind(fontWeight: FontWeight.w600, fontSize: 16)),
                          subtitle: Text(
                            user?.businessName?.isNotEmpty == true
                                ? user!.businessName!
                                : 'नाम, नंबर, पता और पद जोड़ें',
                            style: GoogleFonts.hind(fontSize: 13, color: AppColors.textMuted),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                          onTap: () => _showBusinessBrandingDialog(context, ref, user),
                        ),
                        const Divider(height: 1, color: AppColors.divider),
                        ListTile(
                          leading: const Icon(Icons.crop_portrait, color: AppColors.primary, size: 24),
                          title: Text('फ्रेम स्टाइल', style: GoogleFonts.hind(fontWeight: FontWeight.w600, fontSize: 16)),
                          subtitle: Text(
                            _getFrameTypeName(user?.frameType),
                            style: GoogleFonts.hind(fontSize: 13, color: AppColors.textMuted),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                          onTap: () => _showBusinessBrandingDialog(context, ref, user),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Settings List ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'अन्य विकल्प (Options)',
                    style: GoogleFonts.hind(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.bookmark_outline, color: AppColors.primary, size: 24),
                          title: Text('सेव किए गए स्टेटस', style: GoogleFonts.hind(fontWeight: FontWeight.w600, fontSize: 16)),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                          onTap: () => context.push('/saved'),
                        ),
                        const Divider(height: 1, color: AppColors.divider),
                        ListTile(
                          leading: const Icon(Icons.language, color: AppColors.primary, size: 24),
                          title: Text('भाषा (Language)', style: GoogleFonts.hind(fontWeight: FontWeight.w600, fontSize: 16)),
                          trailing: Text(language, style: GoogleFonts.hind(color: AppColors.textMuted, fontSize: 14)),
                          onTap: () {},
                        ),
                        const Divider(height: 1, color: AppColors.divider),
                        ListTile(
                          leading: const Icon(Icons.help_outline, color: AppColors.primary, size: 24),
                          title: Text('मदद और संपर्क (Help & FAQ)', style: GoogleFonts.hind(fontWeight: FontWeight.w600, fontSize: 16)),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                          onTap: () {},
                        ),
                        const Divider(height: 1, color: AppColors.divider),
                        ListTile(
                          leading: const Icon(Icons.share, color: AppColors.primary, size: 24),
                          title: Text('दोस्तों को ऐप शेयर करें', style: GoogleFonts.hind(fontWeight: FontWeight.w600, fontSize: 16)),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                          onTap: () {},
                        ),
                        const Divider(height: 1, color: AppColors.divider),
                        ListTile(
                          leading: const Icon(Icons.info_outline, color: AppColors.primary, size: 24),
                          title: Text('ऐप वर्शन (Version)', style: GoogleFonts.hind(fontWeight: FontWeight.w600, fontSize: 16)),
                          trailing: Text('1.0.0', style: GoogleFonts.hind(color: AppColors.textMuted, fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Sign Out Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    if (context.mounted) context.go('/login');
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout, color: AppColors.danger, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'लॉगआउट करें (Sign Out)',
                        style: GoogleFonts.hind(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  String _langLabel(String code) {
    switch (code) {
      case 'HINDI': return 'हिन्दी';
      case 'MARATHI': return 'मराठी';
      case 'ENGLISH': return 'English';
      default: return code;
    }
  }

  String _getFrameTypeName(String? type) {
    switch (type) {
      case 'businessClassic': return 'क्लासिक बिजनेस';
      case 'businessModern': return 'मॉडर्न बिजनेस';
      case 'political': return 'नेता / राजनेता';
      case 'minimal': return 'सादा / मिनिमल';
      default: return 'व्यक्तिगत फ्रेम (Personal)';
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
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.hind(fontWeight: FontWeight.w700, fontSize: 20, color: AppColors.primary),
          ),
          Text(
            label,
            style: GoogleFonts.hind(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
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
            content: Text(
              'बिजनेस जानकारी सुरक्षित हो गई!',
              style: GoogleFonts.hind(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('सेव करने में समस्या आई: $e', style: GoogleFonts.hind()),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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

            Text(
              'बिजनेस ब्रांडिंग और फ्रेम',
              style: GoogleFonts.hind(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'यह जानकारी आपके स्टेटस पोस्टर्स के निचले हिस्से में दिखेगी',
              style: GoogleFonts.hind(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 18),

            Text(
              'फ्रेम स्टाइल चुनें',
              style: GoogleFonts.hind(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFrameChip('personal', 'व्यक्तिगत (Personal)'),
                _buildFrameChip('businessClassic', 'क्लासिक बिजनेस'),
                _buildFrameChip('businessModern', 'मॉडर्न बिजनेस'),
                _buildFrameChip('political', 'नेता / राजनेता'),
                _buildFrameChip('minimal', 'मिनिमल'),
              ],
            ),
            const SizedBox(height: 16),

            _buildInputField('दुकान / बिजनेस का नाम', _nameController, 'उदा. शर्मा इलेक्ट्रॉनिक्स', Icons.storefront),
            const SizedBox(height: 12),
            _buildInputField('फोन / WhatsApp नंबर', _phoneController, '+91 98765 43210', Icons.phone, keyboard: TextInputType.phone),
            const SizedBox(height: 12),
            _buildInputField('पद / टैगलाइन', _desigController, 'उदा. प्रोपराइटर / संचालक', Icons.badge_outlined),
            const SizedBox(height: 12),
            _buildInputField('पता / शहर', _addressController, 'उदा. मेन मार्केट, इंदौर', Icons.location_on_outlined),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text(
                        'सुरक्षित करें (Save & Apply)',
                        style: GoogleFonts.hind(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
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
      backgroundColor: AppColors.bg,
      labelStyle: GoogleFonts.hind(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, String hint, IconData icon, {TextInputType keyboard = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.hind(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          style: GoogleFonts.hind(fontSize: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            filled: true,
            fillColor: AppColors.bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.surfaceBorder),
            ),
          ),
        ),
      ],
    );
  }
}
