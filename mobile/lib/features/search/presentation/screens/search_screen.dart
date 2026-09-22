// lib/features/search/presentation/screens/search_screen.dart
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/search_provider.dart';
import '../../../templates/domain/models/template_model.dart';

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
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = query.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: Container(
          height: 46,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            onChanged: _onSearchChanged,
            style: GoogleFonts.hind(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'स्टेटस खोजें (उदा. सुप्रभात, महाकाल)...',
              hintStyle: GoogleFonts.hind(fontSize: 15, color: AppColors.textHint),
              prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 22),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.textMuted, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'लोकप्रिय खोज (Trending Searches)',
                style: GoogleFonts.hind(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          trendingAsync.when(
            loading: () => Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(6, (_) => Container(
                width: 90, height: 38,
                decoration: BoxDecoration(
                  color: AppColors.shimmer,
                  borderRadius: BorderRadius.circular(8),
                ),
              )),
            ),
            error: (_, __) => const SizedBox(),
            data: (terms) {
              if (terms.isEmpty) return const SizedBox();
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: terms.map((t) {
                  return Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () {
                        _searchController.text = t;
                        setState(() => _query = t);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              t,
                              style: GoogleFonts.hind(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
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
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.travel_explore_rounded,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'धार्मिक, प्रेरणादायक एवं त्यौहार के स्टेटस खोजें',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hind(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'अपनी पसंद का स्टेटस तुरंत ढूंढें और साझा करें',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hind(
                    color: AppColors.textMuted,
                    fontSize: 14,
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
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: AppColors.shimmer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
              const SizedBox(height: 12),
              Text(
                'खोज में समस्या आई',
                style: GoogleFonts.hind(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
      data: (templates) {
        if (templates.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off_rounded, size: 56, color: AppColors.textHint),
                  const SizedBox(height: 16),
                  Text(
                    '"$_query" के लिए कोई स्टेटस नहीं मिला',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.hind(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'कृपया किसी अन्य कीवर्ड से खोजें',
                    style: GoogleFonts.hind(color: AppColors.textMuted, fontSize: 15),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                '"$_query" के लिए ${templates.length} स्टेटस मिले',
                style: GoogleFonts.hind(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  fontSize: 15,
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.surfaceBorder),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final t = templates[index];
                  return _SearchTemplateCard(template: t);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SearchTemplateCard extends StatelessWidget {
  final TemplateModel template;
  const _SearchTemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        onTap: () => context.push('/template/${template.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (template.imageThumbUrl != null && template.imageThumbUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: template.imageThumbUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: AppColors.shimmer),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.primarySurface,
                    child: Center(
                      child: Text(template.category?.emoji ?? '✨', style: const TextStyle(fontSize: 36)),
                    ),
                  ),
                )
              else
                Container(
                  color: AppColors.primarySurface,
                  child: Center(
                    child: Text(template.category?.emoji ?? '✨', style: const TextStyle(fontSize: 36)),
                  ),
                ),

              // Gradient Overlay
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 70,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
              ),

              // Video Badge
              if (template.type == 'VIDEO')
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          'VIDEO',
                          style: GoogleFonts.hind(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),

              // Title
              Positioned(
                bottom: 8,
                left: 10,
                right: 10,
                child: Text(
                  template.nameHi ?? template.nameEn ?? 'स्टेटस पोस्टर',
                  style: GoogleFonts.hind(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
