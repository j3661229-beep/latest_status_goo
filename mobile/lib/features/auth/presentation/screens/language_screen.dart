// lib/features/auth/presentation/screens/language_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

const _languages = [
  {'code': 'HINDI', 'name': 'हिंदी', 'english': 'Hindi', 'flag': '🇮🇳', 'desc': 'India\'s most spoken language'},
  {'code': 'MARATHI', 'name': 'मराठी', 'english': 'Marathi', 'flag': '🟠', 'desc': 'Maharashtra language'},
  {'code': 'ENGLISH', 'name': 'English', 'english': 'English', 'flag': '🇺🇸', 'desc': 'International language'},
  {'code': 'GUJARATI', 'name': 'ગુજરાતી', 'english': 'Gujarati', 'flag': '🟡', 'desc': 'Gujarat language'},
  {'code': 'PUNJABI', 'name': 'ਪੰਜਾਬੀ', 'english': 'Punjabi', 'flag': '🔵', 'desc': 'Punjab language'},
];

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends ConsumerState<LanguageSelectionScreen> {
  String? _selected;

  Future<void> _onContinue() async {
    if (_selected == null) return;
    final box = Hive.box(AppConstants.hiveBoxSettings);
    await box.put(AppConstants.keyLanguage, _selected);
    await box.put(AppConstants.keyHasOnboarded, true);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              // Header
              const Text(
                '🙏 नमस्ते!',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'अपनी भाषा चुनें\nChoose your language',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),

              // Language options
              Expanded(
                child: ListView.separated(
                  itemCount: _languages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final lang = _languages[i];
                    final isSelected = _selected == lang['code'];
                    return GestureDetector(
                      onTap: () => setState(() => _selected = lang['code']),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ] : [],
                        ),
                        child: Row(
                          children: [
                            Text(lang['flag']!, style: const TextStyle(fontSize: 28)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang['name']!,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${lang['english']} · ${lang['desc']}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 24),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selected != null ? _onContinue : null,
                  child: const Text('Continue →'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
