// lib/features/search/presentation/screens/search_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_ui_components.dart';
import '../providers/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  /// Optional pre-filled query (e.g. /search?q=दिवाली from the festival ribbon).
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

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
    final initial = widget.initialQuery?.trim() ?? '';
    if (initial.isNotEmpty) {
      _searchController.text = initial;
      _query = initial;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
    }
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
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = query.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: 0,
        title: Container(
          height: 44,
          margin: const EdgeInsets.only(right: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.surfaceBorder, width: 0.8),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            onChanged: _onSearchChanged,
            style: GoogleFonts.hind(fontSize: 15, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'स्टेटस खोजें (उदा. सुप्रभात, महाकाल)...',
              hintStyle: GoogleFonts.hind(fontSize: 14, color: AppColors.textHint),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
          ),
        ),
      ),
      body: _query.length < 2 ? _buildIdleState() : _buildSearchResults(),
    );
  }

  Widget _buildIdleState() {
    final trendingAsync = ref.watch(trendingTermsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'लोकप्रिय खोजें (Trending Searches)',
                style: GoogleFonts.hind(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          trendingAsync.when(
            loading: () => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                6,
                (_) => Container(
                  width: 84,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.shimmer,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ),
            // Trending is optional — hide it on error.
            error: (_, __) => const SizedBox.shrink(),
            data: (terms) {
              if (terms.isEmpty) return const SizedBox.shrink();
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: terms.map((t) {
                  return InkWell(
                    onTap: () {
                      _searchController.text = t;
                      setState(() => _query = t);
                    },
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.surfaceBorder, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_rounded, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 5),
                          Text(
                            t,
                            style: GoogleFonts.hind(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 48),

          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'धार्मिक, प्रेरणादायक एवं त्यौहार के स्टेटस खोजें',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hind(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'कीवर्ड टाइप करें और तुरंत अपनी पसंद का स्टेटस पाएं',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hind(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
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
        padding: const EdgeInsets.all(AppSpacing.md),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          childAspectRatio: 0.68,
        ),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: AppColors.shimmer,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, color: AppColors.textMuted, size: 40),
              const SizedBox(height: 12),
              Text(
                'खोज में समस्या आई',
                style: GoogleFonts.hind(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                apiErrorMessage(e, fallback: ''),
                textAlign: TextAlign.center,
                style: GoogleFonts.hind(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () => ref.invalidate(searchTemplatesProvider(_query)),
                style: ElevatedButton.styleFrom(minimumSize: const Size(140, 44)),
                child: const Text('पुनः प्रयास करें'),
              ),
            ],
          ),
        ),
      ),
      data: (paged) {
        final templates = paged.items;
        if (templates.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textHint),
                  const SizedBox(height: 14),
                  Text(
                    '"$_query" के लिए कोई स्टेटस नहीं मिला',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.hind(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'कृपया किसी अन्य नाम या विषय से खोजें',
                    style: GoogleFonts.hind(color: AppColors.textMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: AppColors.surface,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
              child: Text(
                paged.hasMore
                    ? '"$_query" के लिए ${templates.length}+ स्टेटस मिले'
                    : '"$_query" के लिए ${templates.length} स्टेटस मिले',
                style: GoogleFonts.hind(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  fontSize: 14,
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.surfaceBorder),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  // Infinite scroll: fetch the next page near the bottom.
                  if (n.metrics.extentAfter < 600) {
                    ref.read(searchTemplatesProvider(_query).notifier).loadMore();
                  }
                  return false;
                },
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.68,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => AppTemplateCard(template: templates[index]),
                          childCount: templates.length,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: PagingFooter(
                        isLoading: paged.isLoadingMore,
                        hasError: paged.loadMoreError != null,
                        onRetry: () => ref.read(searchTemplatesProvider(_query).notifier).loadMore(force: true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
