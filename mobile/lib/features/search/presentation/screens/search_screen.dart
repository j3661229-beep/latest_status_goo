// lib/features/search/presentation/screens/search_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_ui_components.dart' show PagingFooter;
import '../../../../core/widgets/app_ui.dart';
import '../../../home/presentation/widgets/discover_widgets.dart';
import '../../../templates/domain/models/template_model.dart';
import '../providers/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  /// Optional pre-filled query (e.g. /search?q=दिवाली from the festival ribbon).
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const String _recentKey = 'recent_searches';
  static const int _recentMax = 8;
  static const List<String> _suggestions = [
    'सुप्रभात',
    'शुभ रात्रि',
    'जन्मदिन की शुभकामनाएं',
    'महाकाल',
    'भक्ति',
    'सुविचार',
    'गणेश जी',
    'हनुमान जी',
  ];

  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  String _query = '';
  String? _type; // null = all, 'IMAGE', 'VIDEO'
  List<String> _recent = const [];

  @override
  void initState() {
    super.initState();
    _recent = _loadRecent();
    final initial = widget.initialQuery?.trim() ?? '';
    if (initial.isNotEmpty) {
      _searchController.text = initial;
      _query = initial;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && initial.isEmpty) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Recent searches (Hive settings_box) ────────────────────────────────────

  List<String> _loadRecent() {
    try {
      if (!Hive.isBoxOpen(AppConstants.hiveBoxSettings)) return const [];
      final raw = Hive.box(AppConstants.hiveBoxSettings).get(_recentKey);
      if (raw is List) return raw.map((e) => e.toString()).take(_recentMax).toList();
    } catch (_) {}
    return const [];
  }

  void _persistRecent(List<String> list) {
    try {
      if (Hive.isBoxOpen(AppConstants.hiveBoxSettings)) {
        Hive.box(AppConstants.hiveBoxSettings).put(_recentKey, list);
      }
    } catch (_) {}
  }

  void _saveRecent(String term) {
    final t = term.trim();
    if (t.length < 2) return;
    final next = [t, ..._recent.where((e) => e.toLowerCase() != t.toLowerCase())].take(_recentMax).toList();
    setState(() => _recent = next);
    _persistRecent(next);
  }

  void _removeRecent(String term) {
    final next = _recent.where((e) => e != term).toList();
    setState(() => _recent = next);
    _persistRecent(next);
  }

  void _clearRecent() {
    setState(() => _recent = const []);
    _persistRecent(const []);
  }

  // ── Query handling ─────────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    setState(() {}); // refresh clear button
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = query.trim());
    });
  }

  void _submit(String query) {
    _debounce?.cancel();
    final q = query.trim();
    setState(() => _query = q);
    _saveRecent(q);
  }

  void _useTerm(String term) {
    _debounce?.cancel();
    _searchController.value = TextEditingValue(
      text: term,
      selection: TextSelection.collapsed(offset: term.length),
    );
    _focusNode.unfocus();
    setState(() => _query = term);
    _saveRecent(term);
  }

  void _clearQuery() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _query = '');
    _focusNode.requestFocus();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xxs, AppSpacing.xs, AppSpacing.page, AppSpacing.xs),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    semanticLabel: 'वापस जाएं',
                    onPressed: _back,
                  ),
                  Expanded(
                    child: AppSearchField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      hint: 'स्टेटस खोजें (जैसे सुप्रभात)...',
                      onChanged: _onSearchChanged,
                      onSubmitted: _submit,
                      onClear: _searchController.text.isNotEmpty ? _clearQuery : null,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _query.length < 2 ? _buildIdleState() : _buildSearchResults()),
          ],
        ),
      ),
    );
  }

  // ── Idle: recent, trending, suggestions ────────────────────────────────────

  Widget _buildIdleState() {
    final trendingAsync = ref.watch(trendingTermsProvider);
    final p = context.palette;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        if (_recent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.xs, AppSpacing.xxs),
            child: Row(
              children: [
                Expanded(child: Text('हाल की खोजें', style: AppText.heading(size: 17, color: p.textPrimary))),
                TextButton(
                  onPressed: _clearRecent,
                  child: const Text('सब हटाएं'),
                ),
              ],
            ),
          ),
          for (final term in _recent)
            _TermRow(
              icon: Icons.history_rounded,
              label: term,
              onTap: () => _useTerm(term),
              trailing: AppIconButton(
                icon: Icons.close_rounded,
                semanticLabel: '$term हटाएं',
                onPressed: () => _removeRecent(term),
              ),
            ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.xs),
          child: Row(
            children: [
              Icon(Icons.trending_up_rounded, color: p.primary, size: 22),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text('ट्रेंडिंग खोजें', style: AppText.heading(size: 17, color: p.textPrimary))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: trendingAsync.when(
            loading: () => Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: List.generate(6, (_) => const ShimmerBox(width: 92, height: 40, radius: AppRadius.pill)),
            ),
            // Trending is optional — fall back to static suggestions.
            error: (_, __) => _pills(_suggestions),
            data: (terms) => _pills(terms.isEmpty ? _suggestions : terms),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.xxs),
          child: Text('सुझाव', style: AppText.heading(size: 17, color: p.textPrimary)),
        ),
        for (final s in _suggestions.take(5))
          _TermRow(
            icon: Icons.search_rounded,
            label: s,
            onTap: () => _useTerm(s),
            trailing: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Icon(Icons.north_west_rounded, size: 18, color: p.textMuted),
            ),
          ),
      ],
    );
  }

  Widget _pills(List<String> terms) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final t in terms) CategoryChip(label: t, icon: Icons.local_fire_department_rounded, onTap: () => _useTerm(t)),
      ],
    );
  }

  // ── Results ────────────────────────────────────────────────────────────────

  Widget _buildSearchResults() {
    final searchAsync = ref.watch(searchTemplatesProvider(_query));
    final p = context.palette;

    return searchAsync.when(
      loading: () => ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          SizedBox(height: AppSpacing.xs),
          ShimmerGrid(itemCount: 6),
        ],
      ),
      error: (e, _) => ErrorState(
        title: 'खोज में समस्या आई',
        message: apiErrorMessage(e, fallback: 'कृपया इंटरनेट जांचें और दोबारा कोशिश करें।'),
        onRetry: () => ref.invalidate(searchTemplatesProvider(_query)),
      ),
      data: (paged) {
        if (paged.items.isEmpty) return _buildNoResults();

        final templates = _type == null
            ? paged.items
            : paged.items.where((t) => t.type.toString().toUpperCase() == _type).toList();

        if (templates.isEmpty && paged.hasMore && paged.loadMoreError == null) {
          // Nothing of this type on the loaded pages yet — keep fetching.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) ref.read(searchTemplatesProvider(_query).notifier).loadMore();
          });
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 600) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ref.read(searchTemplatesProvider(_query).notifier).loadMore();
                }
              });
            }
            return false;
          },
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: TemplateTypeSegment(
                    value: _type,
                    onChanged: (v) => setState(() => _type = v),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.sm),
                  child: Text(
                    '"$_query" के लिए ${templates.length}${paged.hasMore ? '+' : ''} स्टेटस मिले',
                    style: AppText.body(size: 15, weight: FontWeight.w700, color: p.primary, height: 1.3),
                  ),
                ),
              ),
              if (templates.isEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 320,
                    child: paged.hasMore
                        ? const Center(child: CircularProgressIndicator())
                        : const EmptyState(
                            icon: Icons.filter_alt_off_rounded,
                            title: 'इस प्रकार के स्टेटस नहीं मिले',
                            message: 'ऊपर से "सभी" चुनकर देखें।',
                            compact: true,
                          ),
                  ),
                )
              else
                SliverTemplateGrid(
                  templates: templates,
                  onTapTemplate: _openTemplate,
                ),
              SliverToBoxAdapter(
                child: PagingFooter(
                  isLoading: paged.isLoadingMore,
                  hasError: paged.loadMoreError != null,
                  onRetry: () => ref.read(searchTemplatesProvider(_query).notifier).loadMore(force: true),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            ],
          ),
        );
      },
    );
  }

  void _openTemplate(TemplateModel t) {
    _saveRecent(_query);
    context.push(t.isLocked ? '/premium' : '/template/${t.id}');
  }

  Widget _buildNoResults() {
    final p = context.palette;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        SizedBox(
          height: 300,
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: '"$_query" के लिए कोई स्टेटस नहीं मिला',
            message: 'कृपया किसी अन्य नाम या विषय से खोजें',
            compact: true,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xs),
          child: Text('ये खोजकर देखें', style: AppText.heading(size: 17, color: p.textPrimary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: _pills(_suggestions.take(6).toList()),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _TermRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _TermRow({required this.icon, required this.label, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.page),
          child: Row(
            children: [
              Icon(icon, size: 22, color: p.textMuted),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 16, weight: FontWeight.w500, color: p.textPrimary, height: 1.3),
                  ),
                ),
              ),
              trailing ?? const SizedBox(width: AppSpacing.page),
            ],
          ),
        ),
      ),
    );
  }
}
