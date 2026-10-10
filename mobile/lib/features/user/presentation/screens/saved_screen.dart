// lib/features/user/presentation/screens/saved_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../templates/domain/models/template_model.dart';
import '../../data/saved_templates.dart';

export '../../data/saved_templates.dart' show savedTemplatesProvider, savedIdsProvider;

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  /// Last successfully loaded list — shown while the provider reloads after a
  /// toggle so the grid doesn't flash back to skeletons.
  List<TemplateModel>? _last;

  Future<void> _refresh() async {
    try {
      final future = ref.refresh(savedTemplatesProvider.future);
      await future;
    } catch (_) {
      // Error UI is rendered from provider state.
    }
  }

  Future<void> _remove(TemplateModel t) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(savedIdsProvider.notifier).toggle(t.id);
    } catch (e) {
      if (!mounted) return;
      AppSnack.error(context, apiErrorMessage(e, fallback: 'हटाया नहीं जा सका। कृपया दोबारा कोशिश करें।'));
      return;
    }
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: const Text('सहेजे गए स्टेटस से हटाया गया'),
          action: SnackBarAction(
            label: 'पूर्ववत',
            onPressed: () async {
              try {
                await ref.read(savedIdsProvider.notifier).toggle(t.id);
              } catch (e) {
                if (mounted) {
                  AppSnack.error(context, apiErrorMessage(e, fallback: 'दोबारा सेव नहीं हो सका।'));
                }
              }
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final savedAsync = ref.watch(savedTemplatesProvider);
    final fresh = savedAsync.valueOrNull;
    if (fresh != null) _last = fresh;
    final data = fresh ?? _last;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: p.primary,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Header(count: data?.length, onRefresh: _refresh)),
              if (data == null && savedAsync.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(
                    title: 'स्टेटस लोड नहीं हो सके',
                    message: apiErrorMessage(savedAsync.error!,
                        fallback: 'कृपया इंटरनेट जांचें और दोबारा कोशिश करें।'),
                    onRetry: () => ref.invalidate(savedTemplatesProvider),
                  ),
                )
              else if (data == null)
                const SliverToBoxAdapter(child: ShimmerGrid(itemCount: 6))
              else if (data.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.bookmark_border_rounded,
                    title: 'कोई स्टेटस सहेजा नहीं है',
                    message: 'अपनी पसंद के स्टेटस पर दिल दबाकर यहाँ सहेजें और बाद में इस्तेमाल करें।',
                    actionLabel: 'टेम्पलेट खोजें',
                    onAction: () => context.go('/discover'),
                  ),
                )
              else ...[
                SliverTemplateGrid(
                  templates: data,
                  actionBuilder: (t) => _HeartButton(onTap: () => _remove(t)),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int? count;
  final Future<void> Function() onRefresh;

  const _Header({required this.count, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.xs, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('सहेजे गए स्टेटस', style: AppText.heading(size: 24, color: p.textPrimary)),
                if (count != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: p.primarySurface, borderRadius: AppRadius.pillAll),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite_rounded, size: 16, color: p.primary),
                        const SizedBox(width: 6),
                        Text(
                          '$count स्टेटस',
                          style: AppText.body(size: 13.5, weight: FontWeight.w700, color: p.primary, height: 1.2),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          AppIconButton(
            icon: Icons.refresh_rounded,
            semanticLabel: 'रिफ्रेश करें',
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

/// Filled heart on the card; tap removes from saved (with undo).
class _HeartButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HeartButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'सहेजे गए से हटाएं',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Align(
            alignment: Alignment.topRight,
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.scrim),
              child: Padding(
                padding: EdgeInsets.all(7),
                child: Icon(Icons.favorite_rounded, color: AppColors.danger, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
