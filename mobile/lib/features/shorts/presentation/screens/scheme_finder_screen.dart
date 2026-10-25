// lib/features/shorts/presentation/screens/scheme_finder_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_error.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_actions.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../data/short_models.dart';
import '../widgets/short_status_share_sheet.dart';

class SchemeFinderScreen extends ConsumerStatefulWidget {
  const SchemeFinderScreen({super.key});

  @override
  ConsumerState<SchemeFinderScreen> createState() => _SchemeFinderScreenState();
}

class _SchemeFinderScreenState extends ConsumerState<SchemeFinderScreen> {
  String _occupation = 'ALL';
  String _gender = 'ALL';
  String _socialCategory = 'ALL';
  String _stateCode = 'ALL';

  bool _isLoading = false;
  List<Map<String, dynamic>> _matches = [];

  final List<(String, String)> _occupations = const [
    ('ALL', 'सभी नागरिक'),
    ('FARMER', '🌾 किसान'),
    ('STUDENT', '🎓 विद्यार्थी'),
    ('WOMEN', '👩 महिला'),
    ('SENIOR_CITIZEN', '👴 वरिष्ठ नागरिक'),
    ('LABOUR', '🛠 श्रमिक / मजदूर'),
    ('SELF_EMPLOYED', '🏪 छोटा व्यापार / स्वरोजगार'),
  ];

  final List<(String, String)> _categories = const [
    ('ALL', 'सभी वर्ग'),
    ('OBC', 'ओबीसी (OBC)'),
    ('SC', 'एससी (SC)'),
    ('ST', 'एसटी (ST)'),
    ('GENERAL', 'सामान्य (General)'),
  ];

  final List<(String, String)> _states = const [
    ('ALL', 'पूरे भारत (All India)'),
    ('UP', 'उत्तर प्रदेश'),
    ('MP', 'मध्य प्रदेश'),
    ('MH', 'महाराष्ट्र'),
    ('BIHAR', 'बिहार'),
    ('RJ', 'राजस्थान'),
    ('GJ', 'गुजरात'),
    ('HR', 'हरियाणा'),
    ('DL', 'दिल्ली'),
  ];

  @override
  void initState() {
    super.initState();
    _findSchemes();
  }

  Future<void> _findSchemes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final res = await apiClient.post<Map<String, dynamic>>('/schemes/check-eligibility', data: {
        'occupation': _occupation,
        'gender': _gender,
        'socialCategory': _socialCategory,
        if (_stateCode != 'ALL') 'stateCode': _stateCode,
      });

      final list = (res.data?['data']?['matches'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) {
        setState(() {
          _matches = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnack.error(context, apiErrorMessage(e, fallback: 'योजनाएं खोजने में समस्या आई।'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: const Text('🎯 योजना मित्र — पात्रता कैलकुलेटर'),
        actions: [
          IconButton(
            tooltip: 'रीसेट करें',
            onPressed: () {
              setState(() {
                _occupation = 'ALL';
                _gender = 'ALL';
                _socialCategory = 'ALL';
                _stateCode = 'ALL';
              });
              _findSchemes();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Filter Form Card
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: p.border),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.how_to_reg_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'अपनी जानकारी चुनें',
                              style: AppText.heading(size: 16, weight: FontWeight.w800, color: p.textPrimary),
                            ),
                            Text(
                              'आपके लिए सरकारी लाभ व जरूरी कागजात तुरंत देखें',
                              style: AppText.body(size: 12, color: p.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Occupation selector
                  Text('आप क्या करते हैं? (व्यवसाय/वर्ग)',
                      style: AppText.body(size: 13, weight: FontWeight.w700, color: p.textPrimary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _occupations.map((o) {
                      final sel = _occupation == o.$1;
                      return ChoiceChip(
                        label: Text(o.$2),
                        selected: sel,
                        onSelected: (_) {
                          setState(() => _occupation = o.$1);
                          _findSchemes();
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : p.textPrimary,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Social Category & State Row
                  Row(
                    children: [
                      // Social Category
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('जाति वर्ग',
                                style: AppText.body(size: 13, weight: FontWeight.w700, color: p.textPrimary)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _socialCategory,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: _categories.map((c) => DropdownMenuItem(value: c.$1, child: Text(c.$2, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _socialCategory = v);
                                  _findSchemes();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // State
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('राज्य',
                                style: AppText.body(size: 13, weight: FontWeight.w700, color: p.textPrimary)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _stateCode,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: _states.map((s) => DropdownMenuItem(value: s.$1, child: Text(s.$2, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _stateCode = v);
                                  _findSchemes();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Search result header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Text(
                    'पात्र सरकारी योजनाएं (${_matches.length})',
                    style: AppText.heading(size: 15, weight: FontWeight.w800, color: p.textPrimary),
                  ),
                  const Spacer(),
                  if (_isLoading)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),
          ),

          // Matches List
          if (_matches.isEmpty && !_isLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: p.textMuted),
                      const SizedBox(height: 8),
                      Text('कोई योजना नहीं मिली', style: AppText.heading(size: 16, color: p.textPrimary)),
                      const SizedBox(height: 4),
                      Text('कृपया फ़िल्टर बदल कर दोबारा कोशिश करें।', style: AppText.body(size: 13, color: p.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final s = _matches[i];
                  return _SchemeCard(
                    scheme: s,
                    onShareStatus: () {
                      final item = ShortItem(
                        id: s['id'] ?? '',
                        kind: ShortKind.scheme,
                        title: s['nameHi'] ?? s['officialName'] ?? '',
                        category: s['category'] ?? 'SCHEME',
                        hook: (s['benefits'] as List?)?.firstOrNull?.toString(),
                        summary: (s['benefits'] as List?)?.take(2).join(' • '),
                        attribution: s['officialName'],
                        disclaimer: 'यह योजना भारत सरकार / राज्य सरकार द्वारा संचालित है।',
                        isSaved: false,
                        scheme: SchemeInfo(
                          id: s['id'] ?? '',
                          nameHi: s['nameHi'] ?? '',
                          officialName: s['officialName'] ?? '',
                          applicationUrl: s['applicationUrl'],
                          benefits: (s['benefits'] as List?)?.cast<String>() ?? [],
                          documents: (s['documents'] as List?)?.cast<String>() ?? [],
                        ),
                      );
                      showShortStatusShareSheet(context, item);
                    },
                  );
                },
                childCount: _matches.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _SchemeCard extends StatelessWidget {
  final Map<String, dynamic> scheme;
  final VoidCallback onShareStatus;

  const _SchemeCard({required this.scheme, required this.onShareStatus});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final match = scheme['matchPercentage'] ?? 80;
    final benefits = (scheme['benefits'] as List?)?.cast<String>() ?? [];
    final docs = (scheme['documents'] as List?)?.cast<String>() ?? [];
    final applyUrl = scheme['applicationUrl'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scheme['nameHi'] ?? scheme['officialName'] ?? '',
                      style: AppText.heading(size: 17, weight: FontWeight.w800, color: p.textPrimary),
                    ),
                    Text(
                      scheme['officialName'] ?? '',
                      style: AppText.body(size: 11, color: p.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, color: Color(0xFF2E7D32), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$match% पात्र',
                      style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Benefits Highlights
          if (benefits.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE65100).withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💰 योजना के मुख्य लाभ:',
                      style: TextStyle(color: Color(0xFFE65100), fontSize: 12, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  ...benefits.take(3).map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('• $b', style: AppText.body(size: 13, color: p.textPrimary)),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Documents Checklist
          if (docs.isNotEmpty) ...[
            Text('📄 जरूरी दस्तावेज़ (Checklist):',
                style: AppText.body(size: 12, weight: FontWeight.w700, color: p.textMuted)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: docs.map((d) => Chip(
                    label: Text(d, style: const TextStyle(fontSize: 11)),
                    avatar: const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: p.surfaceMuted,
                    side: BorderSide.none,
                  )).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Action Buttons
          Row(
            children: [
              // WhatsApp Status Brand Button
              Expanded(
                child: FilledButton.icon(
                  onPressed: onShareStatus,
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('स्टेटस बनाएं', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Official Portal Link
              if (applyUrl != null)
                OutlinedButton.icon(
                  onPressed: () => AppActions.openUrl(context, applyUrl),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('आधिकारिक पोर्टल', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
