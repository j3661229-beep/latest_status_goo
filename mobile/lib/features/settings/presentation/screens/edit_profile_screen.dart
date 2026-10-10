// lib/features/settings/presentation/screens/edit_profile_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/data/indian_states.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';
import '../../../auth/presentation/screens/profile_setup_screen.dart' show kAppLanguages;
import '../../../home/presentation/providers/home_data_provider.dart';

const _frameTypes = <(String, String)>[
  ('personal', 'व्यक्तिगत'),
  ('businessClassic', 'क्लासिक बिज़नेस'),
  ('businessModern', 'मॉडर्न बिज़नेस'),
  ('political', 'नेता'),
  ('minimal', 'मिनिमल'),
];

/// Edit name, photo, location, language and business branding.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _bizName;
  late final TextEditingController _bizPhone;
  late final TextEditingController _bizDesignation;
  late final TextEditingController _bizAddress;

  String? _state;
  String? _region;
  late String _language;
  late String _frameType;

  File? _newPhoto;
  File? _newLogo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = ref.read(currentUserProvider);
    _name = TextEditingController(text: u?.displayName ?? u?.name ?? '');
    _bizName = TextEditingController(text: u?.businessName ?? '');
    _bizPhone = TextEditingController(text: u?.businessPhone ?? '');
    _bizDesignation = TextEditingController(text: u?.businessDesignation ?? '');
    _bizAddress = TextEditingController(text: u?.businessAddress ?? '');
    _state = u?.state;
    _region = u?.region;
    _language = u?.language ?? 'HINDI';
    _frameType = _frameTypes.any((f) => f.$1 == u?.frameType) ? u!.frameType : 'personal';
  }

  @override
  void dispose() {
    _name.dispose();
    _bizName.dispose();
    _bizPhone.dispose();
    _bizDesignation.dispose();
    _bizAddress.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool logo}) async {
    final source = await AppBottomSheet.show<ImageSource>(
      context,
      title: logo ? 'लोगो चुनें' : 'फ़ोटो चुनें',
      builder: (ctx) => Column(
        children: [
          SettingsSection(
            margin: EdgeInsets.zero,
            children: [
              SettingsTile(
                icon: Icons.photo_camera_rounded,
                title: 'कैमरा से खींचें',
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              SettingsTile(
                icon: Icons.photo_library_rounded,
                title: 'गैलरी से चुनें',
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        ],
      ),
    );
    if (source == null) return;
    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1600);
      if (picked == null || !mounted) return;
      setState(() {
        if (logo) {
          _newLogo = File(picked.path);
        } else {
          _newPhoto = File(picked.path);
        }
      });
    } catch (e) {
      if (mounted) AppSnack.error(context, 'फ़ोटो नहीं चुनी जा सकी। अनुमति जांचें।');
    }
  }

  Future<void> _pickState() async {
    final picked = await AppBottomSheet.show<String>(
      context,
      title: 'राज्य चुनें',
      scrollable: false,
      builder: (ctx) => ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xl),
        itemCount: IndianStates.all.length,
        itemBuilder: (_, i) {
          final s = IndianStates.all[i];
          return ListTile(
            leading: Text(s.emoji, style: const TextStyle(fontSize: 24)),
            title: Text(s.name),
            trailing: s.name == _state ? Icon(Icons.check_circle_rounded, color: ctx.palette.primary) : null,
            onTap: () => Navigator.of(ctx).pop(s.name),
          );
        },
      ),
    );
    if (picked != null && picked != _state) {
      setState(() {
        _state = picked;
        _region = null;
      });
    }
  }

  Future<void> _pickRegion() async {
    final regions = IndianStates.findByName(_state ?? '')?.regions ?? const <String>[];
    if (regions.isEmpty) {
      AppSnack.info(context, 'पहले राज्य चुनें।');
      return;
    }
    final picked = await AppBottomSheet.show<String>(
      context,
      title: 'क्षेत्र चुनें',
      scrollable: false,
      builder: (ctx) => ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xl),
        itemCount: regions.length,
        itemBuilder: (_, i) => ListTile(
          title: Text(regions[i]),
          trailing: regions[i] == _region ? Icon(Icons.check_circle_rounded, color: ctx.palette.primary) : null,
          onTap: () => Navigator.of(ctx).pop(regions[i]),
        ),
      ),
    );
    if (picked != null) setState(() => _region = picked);
  }

  Future<void> _pickLanguage() async {
    final picked = await AppBottomSheet.show<String>(
      context,
      title: 'भाषा चुनें',
      builder: (ctx) => Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final l in kAppLanguages)
            CategoryChip(
              label: l.name,
              emoji: l.flag,
              selected: l.code == _language,
              onTap: () => Navigator.of(ctx).pop(l.code),
            ),
        ],
      ),
    );
    if (picked != null) setState(() => _language = picked);
  }

  String _languageName(String code) =>
      kAppLanguages.firstWhere((l) => l.code == code, orElse: () => kAppLanguages.first).name;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final repo = ref.read(authRepositoryProvider);
    final previous = ref.read(currentUserProvider);
    try {
      String? photoUrl;
      String? logoUrl;
      if (_newPhoto != null) photoUrl = await repo.uploadProfilePhoto(_newPhoto!.path);
      if (_newLogo != null) logoUrl = await repo.uploadImage(_newLogo!.path, filename: 'logo.jpg');

      await repo.updateProfileFields({
        'name': _name.text.trim(),
        if (photoUrl != null) 'profilePhoto': photoUrl,
        if (_state != null) 'state': _state,
        if (_region != null) 'region': _region,
        'language': _language,
        'businessName': _bizName.text.trim(),
        'businessPhone': _bizPhone.text.trim(),
        'businessDesignation': _bizDesignation.text.trim(),
        'businessAddress': _bizAddress.text.trim(),
        if (logoUrl != null) 'businessLogo': logoUrl,
        'frameType': _frameType,
      });
      await ref.read(sessionStoreProvider).setDisplayName(_name.text.trim());
      if (previous?.language != _language || previous?.state != _state || previous?.region != _region) {
        ref.invalidate(homeDataProvider);
      }
      if (!mounted) return;
      AppSnack.success(context, 'प्रोफ़ाइल सुरक्षित हो गई!');
      if (context.canPop()) context.pop();
    } catch (e) {
      if (mounted) AppSnack.error(context, 'सेव नहीं हो सका: ${apiErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final UserModel? user = ref.watch(currentUserProvider);
    final p = context.palette;
    final photo = _newPhoto != null
        ? FileImage(_newPhoto!) as ImageProvider
        : currentUserPhotoProvider(serverPhoto: user?.profilePhoto);
    final logo = _newLogo != null
        ? FileImage(_newLogo!) as ImageProvider
        : photoImageProvider(user?.businessLogo);

    return AppScaffold(
      title: 'प्रोफ़ाइल संपादित करें',
      bottomBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.sm),
          child: GradientButton(label: 'सेव करें', icon: Icons.check_rounded, isLoading: _saving, onPressed: _save),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xxl),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            // Avatar
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AppAvatar(image: photo, name: _name.text, radius: 54, ring: true),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: AppIconButton(
                      icon: Icons.photo_camera_rounded,
                      semanticLabel: 'फ़ोटो बदलें',
                      filled: true,
                      color: context.palette.primary,
                      size: 44,
                      iconSize: 20,
                      onPressed: () => _pickImage(logo: false),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            AppTextField(
              controller: _name,
              label: 'आपका नाम',
              hint: 'जैसे: रमेश कुमार',
              prefixIcon: Icons.person_outline_rounded,
              required: true,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              validator: (v) => (v ?? '').trim().isEmpty ? 'कृपया अपना नाम लिखें' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            _PickerField(label: 'राज्य', value: _state, placeholder: 'राज्य चुनें', icon: Icons.map_outlined, onTap: _pickState),
            const SizedBox(height: AppSpacing.md),
            _PickerField(label: 'क्षेत्र / शहर', value: _region, placeholder: 'क्षेत्र चुनें', icon: Icons.location_on_outlined, onTap: _pickRegion),
            const SizedBox(height: AppSpacing.md),
            _PickerField(label: 'भाषा', value: _languageName(_language), placeholder: '', icon: Icons.translate_rounded, onTap: _pickLanguage),

            const SectionHeader(
              title: 'बिज़नेस ब्रांडिंग',
              subtitle: 'यह जानकारी आपके पोस्टर के नीचे दिखेगी (वैकल्पिक)',
              padding: EdgeInsets.fromLTRB(0, AppSpacing.xl, 0, AppSpacing.sm),
            ),

            // Logo
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: AppRadius.lgAll,
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: p.primarySurface,
                      borderRadius: AppRadius.mdAll,
                      image: logo == null ? null : DecorationImage(image: logo, fit: BoxFit.cover),
                    ),
                    child: logo == null ? Icon(Icons.storefront_rounded, color: p.primary, size: 30) : null,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('बिज़नेस लोगो', style: AppText.body(size: 16, weight: FontWeight.w700, color: p.textPrimary)),
                        const SizedBox(height: 6),
                        SecondaryButton(
                          label: logo == null ? 'लोगो जोड़ें' : 'लोगो बदलें',
                          icon: Icons.upload_rounded,
                          tonal: true,
                          expand: false,
                          onPressed: () => _pickImage(logo: true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            AppTextField(
              controller: _bizName,
              label: 'बिज़नेस / संस्था का नाम',
              hint: 'जैसे: शर्मा ज्वेलर्स',
              prefixIcon: Icons.business_center_outlined,
              maxLength: 150,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _bizDesignation,
              label: 'टैगलाइन / पद',
              hint: 'जैसे: प्रोपराइटर',
              prefixIcon: Icons.badge_outlined,
              maxLength: 100,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _bizPhone,
              label: 'बिज़नेस फ़ोन',
              hint: '98765 43210',
              prefixIcon: Icons.call_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty || t.length == 10) return null;
                return '10 अंकों का नंबर लिखें';
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _bizAddress,
              label: 'पता',
              hint: 'दुकान / कार्यालय का पता',
              prefixIcon: Icons.place_outlined,
              maxLines: 2,
              maxLength: 255,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('फ़्रेम स्टाइल', style: AppText.body(size: 14.5, weight: FontWeight.w700, color: p.textPrimary)),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final f in _frameTypes)
                  CategoryChip(label: f.$2, selected: _frameType == f.$1, onTap: () => setState(() => _frameType = f.$1)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  final String label;
  final String? value;
  final String placeholder;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final has = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label, style: AppText.body(size: 14.5, weight: FontWeight.w700, color: p.textPrimary, height: 1.2)),
        ),
        PressableScale(
          onTap: onTap,
          semanticLabel: label,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: p.border, width: 1.2),
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: p.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    has ? value! : placeholder,
                    style: AppText.body(size: 17, weight: FontWeight.w500, color: has ? p.textPrimary : p.textHint),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded, color: p.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
