// lib/features/search/presentation/screens/search_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/color_utils.dart';
import '../providers/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = query.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search Bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search templates, festivals...',
                          hintStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                          suffixIcon: _query.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  child: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ──────────────────────────────────────────────────
            Expanded(
              child: _query.length < 2 ? _buildIdleState() : _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdleState() {
    final trendingAsync = ref.watch(trendingTermsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TRENDING SEARCHES',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1),
          ),
          const SizedBox(height: 14),
          trendingAsync.when(
            loading: () => Wrap(
              spacing: 8,
              runSpacing: 10,
              children: List.generate(8, (_) => Container(
                width: 80, height: 36,
                decoration: BoxDecoration(color: AppColors.shimmer, borderRadius: BorderRadius.circular(20)),
              )),
            ),
            error: (_, __) => const SizedBox(),
            data: (terms) {
              if (terms.isEmpty) return const SizedBox();
              return Wrap(
                spacing: 8,
                runSpacing: 10,
                children: terms.asMap().entries.map((entry) {
                  final i = entry.key;
                  final t = entry.value;
                  final pillarColors = [
                    [AppColors.primary, AppColors.primaryLight],
                    [AppColors.secondary, const Color(0xFFFF9EC5)],
                    [AppColors.accent, const Color(0xFF5EECD8)],
                    [const Color(0xFFF7971E), const Color(0xFFFFD200)],
                  ];
                  final colors = pillarColors[i % pillarColors.length];
                  return GestureDetector(
                    onTap: () {
                      _searchController.text = t;
                      setState(() => _query = t);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: colors.first.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13)),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                Text('🔍', style: TextStyle(fontSize: 48, color: AppColors.textMuted.withOpacity(0.5))),
                const SizedBox(height: 12),
                const Text('Search for devotional,\nfestival & motivational status', textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final searchAsync = ref.watch(searchTemplatesProvider(_query));

    return searchAsync.when(
      loading: () => GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.72,
        ),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(color: AppColors.shimmer, borderRadius: BorderRadius.circular(20)),
        ),
      ),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.textMuted))),
      data: (templates) {
        if (templates.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('😕', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 14),
              Text('No results for "$_query"', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              const Text('Try a different keyword', style: TextStyle(color: AppColors.textMuted)),
            ]),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${templates.length} results for "$_query"',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMuted, fontSize: 13),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.72,
                ),
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final t = templates[index];
                  final colors = ColorUtils.parseGradientString(t.gradient ?? t.category?.gradient);
                  return GestureDetector(
                    onTap: () => context.push('/template/${t.id}'),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: t.imageThumbUrl == null
                            ? LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)
                            : null,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppColors.cardShadow,
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Stack(
                        children: [
                          if (t.imageThumbUrl != null)
                            Positioned.fill(child: Image.network(t.imageThumbUrl!, fit: BoxFit.cover)),
                          if (t.imageThumbUrl == null)
                            Center(child: Text(t.category?.emoji ?? '✨', style: const TextStyle(fontSize: 40))),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 10, left: 10, right: 10,
                            child: Text(
                              t.nameHi ?? t.nameEn ?? 'Status',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12,
                                  shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
