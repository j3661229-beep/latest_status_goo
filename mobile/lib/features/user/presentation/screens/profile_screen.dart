import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/profile_photo.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';
import '../../../auth/domain/models/user_model.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh plan / stats from GET /user/me whenever the profile opens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshUser(silent: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshUser(silent: true);
  }

  Future<void> _refreshUser({bool silent = false}) async {
    try {
      await ref.read(authRepositoryProvider).refreshCurrentUser();
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e), style: GoogleFonts.hind()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildProfile(context, ref);
  }

  Widget _buildProfile(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final photo = currentUserPhotoProvider(serverPhoto: user?.profilePhoto);
    final displayName = user?.displayName ?? user?.name ?? 'उपयोगकर्ता';
    final initial = displayName.trim().isNotEmpty ? displayName.trim()[0].toUpperCase() : 'U';
    final isPremium = user?.isPremium ?? false;
    final language = _langLabel(user?.language ?? 'HINDI');

    final settingsBox = Hive.box(AppConstants.hiveBoxSettings);
    final userState = user?.state ?? settingsBox.get(AppConstants.keyState) as String?;
    final userRegion = user?.region ?? settingsBox.get(AppConstants.keyRegion) as String?;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'मेरी प्रोफ़ाइल',
          style: GoogleFonts.hind(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.surfaceBorder, height: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 22, color: AppColors.textSecondary),
            tooltip: 'लॉगआउट',
            onPressed: () => _confirmSignOut(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _refreshUser(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ── 1. Profile Header Card ──────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.surfaceBorder),
                  boxShadow: AppShadows.card,
                ),
                child: Row(
                  children: [
                    // Avatar (remote URL or local file)
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primarySurface,
                        border: Border.all(color: AppColors.surfaceBorder, width: 2),
                        image: photo != null
                            ? DecorationImage(
                                image: photo,
                                fit: BoxFit.cover,
                                onError: (_, __) {},
                              )
                            : null,
                      ),
                      child: photo == null
                          ? Center(
                              child: Text(
                                initial,
                                style: GoogleFonts.hind(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),

                    // Name & Contact Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: GoogleFonts.hind(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (user?.phoneNumber != null || user?.email != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              user?.phoneNumber ?? user?.email ?? '',
                              style: GoogleFonts.hind(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          // Badges
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isPremium ? const Color(0xFFFEF3C7) : AppColors.bg,
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                    border: Border.all(
                                      color: isPremium ? const Color(0xFFF59E0B) : AppColors.surfaceBorder,
                                    ),
                                  ),
                                  child: Text(
                                    isPremium ? '⭐ प्रीमियम' : 'फ्री प्लान',
                                    style: GoogleFonts.hind(
                                      color: isPremium ? const Color(0xFFB45309) : AppColors.textSecondary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.bg,
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                    border: Border.all(color: AppColors.surfaceBorder),
                                  ),
                                  child: Text(
                                    language,
                                    style: GoogleFonts.hind(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                if (userState != null && userState.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.bg,
                                      borderRadius: BorderRadius.circular(AppRadius.pill),
                                      border: Border.all(color: AppColors.surfaceBorder),
                                    ),
                                    child: Text(
                                      userRegion != null && userRegion.isNotEmpty
                                          ? '📍 $userState ($userRegion)'
                                          : '📍 $userState',
                                      style: GoogleFonts.hind(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── 2. Premium Upgrade Callout (if free user) ───────────
              if (!isPremium)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'प्रीमियम में अपग्रेड करें',
                              style: GoogleFonts.hind(
                                color: const Color(0xFF92400E),
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'सभी स्टेटस और कस्टम फ्रेम अनलॉक करें',
                              style: GoogleFonts.hind(
                                color: const Color(0xFFB45309),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => context.push('/premium'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: const Size(60, 36),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                        ),
                        child: Text(
                          'देखें',
                          style: GoogleFonts.hind(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── 3. Quick Stats (Useful & Minimal) ───────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Row(
                  children: [
                    _StatTile(
                      emoji: '🔥',
                      value: user?.streakCount.toString() ?? '0',
                      label: 'दिन स्ट्रीक',
                    ),
                    Container(width: 1, height: 32, color: AppColors.surfaceBorder),
                    _StatTile(
                      emoji: '📤',
                      value: user?.totalShares.toString() ?? '0',
                      label: 'कुल शेयर',
                    ),
                    Container(width: 1, height: 32, color: AppColors.surfaceBorder),
                    _StatTile(
                      emoji: '🔖',
                      value: user?.totalSaves.toString() ?? '0',
                      label: 'सहेजे गए',
                    ),
                  ],
                ),
              ),

              // ── 4. Content & Business Settings ──────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'कंटेंट व ब्रांडिंग',
                    style: GoogleFonts.hind(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  children: [
                    _MenuItemTile(
                      icon: Icons.bookmark_outline_rounded,
                      title: 'सहेजे गए स्टेटस (Saved)',
                      subtitle: 'आपके सुरक्षित किए गए पसंदीदा पोस्टर्स',
                      onTap: () => context.push('/saved'),
                    ),
                    const Divider(height: 1, color: AppColors.surfaceBorder, indent: 52),
                    _MenuItemTile(
                      icon: Icons.storefront_outlined,
                      title: 'बिजनेस ब्रांडिंग और फ्रेम',
                      subtitle:
                          user?.businessName?.isNotEmpty == true ? user!.businessName! : 'नाम, नंबर, पता और पद जोड़ें',
                      onTap: () => _showBusinessBrandingDialog(context, ref, user),
                    ),
                    const Divider(height: 1, color: AppColors.surfaceBorder, indent: 52),
                    _MenuItemTile(
                      icon: Icons.crop_portrait_rounded,
                      title: 'फ्रेम स्टाइल',
                      subtitle: _getFrameTypeName(user?.frameType),
                      onTap: () => _showBusinessBrandingDialog(context, ref, user),
                    ),
                  ],
                ),
              ),

              // ── 5. General App Settings ─────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'सेटिंग्स और सहायता',
                    style: GoogleFonts.hind(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  children: [
                    _MenuItemTile(
                      icon: Icons.edit_location_alt_outlined,
                      title: 'प्रोफ़ाइल, राज्य व क्षेत्र (Profile & Region)',
                      subtitle: userState != null
                          ? '$userState ${userRegion != null ? '($userRegion)' : ''}'
                          : 'राज्य व क्षेत्र सेट करें',
                      onTap: () => context.push('/profile-setup'),
                    ),
                    const Divider(height: 1, color: AppColors.surfaceBorder, indent: 52),
                    _MenuItemTile(
                      icon: Icons.translate_rounded,
                      title: 'भाषा (Language)',
                      trailingText: language,
                      subtitle: 'पसंदीदा भाषा बदलें',
                      onTap: () => context.push('/profile-setup'),
                    ),
                    const Divider(height: 1, color: AppColors.surfaceBorder, indent: 52),
                    _MenuItemTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'सूचनाएं (Notifications)',
                      onTap: () => context.push('/notifications'),
                    ),
                    const Divider(height: 1, color: AppColors.surfaceBorder, indent: 52),
                    _MenuItemTile(
                      icon: Icons.help_outline_rounded,
                      title: 'मदद और संपर्क (Help & FAQ)',
                      onTap: () => _showHelpSheet(context),
                    ),
                    const Divider(height: 1, color: AppColors.surfaceBorder, indent: 52),
                    _MenuItemTile(
                      icon: Icons.share_outlined,
                      title: 'दोस्तों को ऐप शेयर करें',
                      onTap: _shareApp,
                    ),
                    const Divider(height: 1, color: AppColors.surfaceBorder, indent: 52),
                    _MenuItemTile(
                      icon: Icons.info_outline_rounded,
                      title: 'ऐप वर्शन (Version)',
                      trailingText: AppConstants.appVersion,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── 6. Sign Out Button ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.danger),
                    label: Text(
                      'लॉगआउट करें',
                      style: GoogleFonts.hind(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.danger,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFECACA), width: 1),
                      backgroundColor: const Color(0xFFFEF2F2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    onPressed: () => _confirmSignOut(context, ref),
                  ),
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareApp() async {
    await Share.share(
      'रोज़ अपने नाम और फोटो के साथ शानदार स्टेटस बनाएं — ${AppConstants.appName} ऐप डाउनलोड करें 📲\n${AppConstants.playStoreUrl}',
      subject: AppConstants.appName,
    );
  }

  void _showHelpSheet(BuildContext context) {
    const faqs = [
      (
        'स्टेटस पर अपना नाम/फोटो कैसे लगाएं?',
        'होम पर "Change Your Photo" दबाएं या किसी स्टेटस को खोलकर "फ़ोटो व फ़्रेम" और "नाम बदलें" चुनें।'
      ),
      ('स्टेटस व्हाट्सएप पर कैसे लगाएं?', 'स्टेटस खोलें और "व्हाट्सएप पर स्टेटस लगाएं" बटन दबाएं, फिर WhatsApp चुनें।'),
      ('डाउनलोड की गई फोटो कहाँ मिलेगी?', 'फोन की गैलरी (Photos / Gallery) में।'),
      ('प्रीमियम कैसे लें?', 'प्रोफ़ाइल में "प्रीमियम में अपग्रेड करें" पर जाएं और प्लान चुनें।'),
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'मदद और संपर्क (Help & FAQ)',
                style: GoogleFonts.hind(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              for (final faq in faqs) ...[
                Text(
                  faq.$1,
                  style: GoogleFonts.hind(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  faq.$2,
                  style: GoogleFonts.hind(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 12),
              ],
              const Divider(color: AppColors.surfaceBorder),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email_outlined, color: AppColors.primary),
                title: Text('हमें ईमेल करें', style: GoogleFonts.hind(fontWeight: FontWeight.w600)),
                subtitle: Text(AppConstants.supportEmail, style: GoogleFonts.hind(color: AppColors.textMuted)),
                onTap: () async {
                  final uri = Uri(
                    scheme: 'mailto',
                    path: AppConstants.supportEmail,
                    query:
                        'subject=${Uri.encodeComponent('${AppConstants.appName} सहायता (v${AppConstants.appVersion})')}',
                  );
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await launchUrl(uri).catchError((Object _) => false);
                  if (!ok) {
                    messenger.showSnackBar(
                      SnackBar(
                          content: Text('ईमेल ऐप नहीं मिला: ${AppConstants.supportEmail}', style: GoogleFonts.hind())),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(
          'लॉगआउट करें?',
          style: GoogleFonts.hind(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Text(
          'क्या आप सचमुच ऐप से बाहर निकलना चाहते हैं?',
          style: GoogleFonts.hind(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'रद्द करें',
              style: GoogleFonts.hind(color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
            ),
            child: Text(
              'लॉगआउट',
              style: GoogleFonts.hind(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authRepositoryProvider).signOut();
      if (context.mounted) context.go('/login');
    }
  }

  String _langLabel(String code) {
    switch (code) {
      case 'HINDI':
        return 'हिन्दी';
      case 'MARATHI':
        return 'मराठी';
      case 'ENGLISH':
        return 'English';
      default:
        return code;
    }
  }

  String _getFrameTypeName(String? type) {
    switch (type) {
      case 'businessClassic':
        return 'क्लासिक बिजनेस';
      case 'businessModern':
        return 'मॉडर्न बिजनेस';
      case 'political':
        return 'नेता / राजनेता';
      case 'minimal':
        return 'सादा / मिनिमल';
      default:
        return 'व्यक्तिगत फ्रेम (Personal)';
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
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.hind(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.hind(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback? onTap;

  const _MenuItemTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.hind(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: GoogleFonts.hind(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (trailingText != null)
              Text(
                trailingText!,
                style: GoogleFonts.hind(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
              ),
          ],
        ),
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
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      // Persists the server copy (PUT /user/me → { user }); currentUserProvider
      // rebuilds automatically from the session store.
      await widget.ref.read(authRepositoryProvider).updateBusinessBranding(
            businessName: _nameController.text.trim(),
            businessPhone: _phoneController.text.trim(),
            businessDesignation: _desigController.text.trim(),
            businessAddress: _addressController.text.trim(),
            frameType: _selectedFrameType,
          );

      if (mounted) {
        navigator.pop();
        messenger.showSnackBar(
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
            content: Text('सेव करने में समस्या आई: ${apiErrorMessage(e)}', style: GoogleFonts.hind()),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'बिजनेस ब्रांडिंग और फ्रेम',
              style: GoogleFonts.hind(
                fontSize: 18,
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
              style: GoogleFonts.hind(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFrameChip('personal', 'व्यक्तिगत (Personal)'),
                  const SizedBox(width: 8),
                  _buildFrameChip('businessClassic', 'क्लासिक बिजनेस'),
                  const SizedBox(width: 8),
                  _buildFrameChip('businessModern', 'मॉडर्न बिजनेस'),
                  const SizedBox(width: 8),
                  _buildFrameChip('political', 'नेता / राजनेता'),
                  const SizedBox(width: 8),
                  _buildFrameChip('minimal', 'मिनिमल'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildInputField(
                'दुकान / बिजनेस का नाम', _nameController, 'उदा. शर्मा इलेक्ट्रॉनिक्स', Icons.storefront_outlined),
            const SizedBox(height: 12),
            _buildInputField('फोन / WhatsApp नंबर', _phoneController, '+91 98765 43210', Icons.phone_outlined,
                keyboard: TextInputType.phone),
            const SizedBox(height: 12),
            _buildInputField('पद / टैगलाइन', _desigController, 'उदा. प्रोपराइटर / संचालक', Icons.badge_outlined),
            const SizedBox(height: 12),
            _buildInputField('पता / शहर', _addressController, 'उदा. मेन मार्केट, इंदौर', Icons.location_on_outlined),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        'सुरक्षित करें',
                        style: GoogleFonts.hind(fontSize: 15, fontWeight: FontWeight.w700),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
        ),
      ),
      labelStyle: GoogleFonts.hind(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.hind(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          style: GoogleFonts.hind(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.hind(color: AppColors.textMuted, fontSize: 13),
            prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
            filled: true,
            fillColor: AppColors.bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.surfaceBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
