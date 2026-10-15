// lib/features/shorts/presentation/screens/shorts_screen.dart
//
// "Shorts" tab: Daily News / Yojana & Scholarships / Saved, as a vertical pager.
// One VideoPlayerController for the whole feed (see ShortPlaybackController).
// No RefreshIndicator / Transform around the PageView (invalid SliverGeometry crash
// documented in PROJECT_AUDIT.md) — refresh is an explicit button + error retry.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/router/app_shell.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../data/short_models.dart';
import '../../data/shorts_repository.dart';
import '../providers/shorts_feed_provider.dart';
import '../short_format.dart';
import '../widgets/report_sheet.dart';
import '../widgets/short_player.dart';

class ShortsScreen extends ConsumerStatefulWidget {
  const ShortsScreen({super.key, this.controllerFactory});

  /// Test seam: lets tests supply fake video controllers.
  final ControllerFactory? controllerFactory;

  @override
  ConsumerState<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends ConsumerState<ShortsScreen> {
  late final ShortPlaybackController _playback;
  PageController _pager = PageController();
  ShortsFeed _feed = ShortsFeed.news;
  String? _category;
  int _index = 0;
  final Set<String> _viewed = {};

  ShortsQuery get _query => ShortsQuery(_feed, _feed == ShortsFeed.saved ? null : _category);

  @override
  void initState() {
    super.initState();
    _playback = ShortPlaybackController(factory: widget.controllerFactory);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppShell.immersive.value = true;
    });
  }

  @override
  void dispose() {
    AppShell.immersive.value = false;
    _pager.dispose();
    _playback.dispose();
    super.dispose();
  }

  void _selectFeed(ShortsFeed f) {
    if (f == _feed) return;
    HapticFeedback.selectionClick();
    setState(() {
      _feed = f;
      _category = null;
    });
    _resetPager();
  }

  void _selectCategory(String? c) {
    if (c == _category) return;
    setState(() => _category = c);
    _resetPager();
  }

  void _resetPager() {
    final old = _pager;
    _pager = PageController();
    _index = 0;
    // Dispose the old controller after the new PageView is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  /// Make the playback controller follow the visible page. Safe to call from build.
  void _syncActive(List<ShortItem> items) {
    if (items.isEmpty) return;
    final i = _index.clamp(0, items.length - 1);
    final item = items[i];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _playback.activate(item.id, item.videoUrl);
      if (_viewed.add(item.id)) ref.read(shortsRepositoryProvider).event(item.id, 'VIEW');
    });
  }

  void _onPageChanged(int i, ShortsFeedNotifier notifier, int length) {
    HapticFeedback.selectionClick();
    // Don't swap the decoder mid-swipe: let the pager settle this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _index = i);
    });
    if (i >= length - 3) notifier.loadMore();
  }

  Future<void> _openDetail(ShortItem item) async {
    _playback.suspend();
    await context.push('/shorts/${item.id}');
    if (mounted) _playback.resume();
  }

  Future<void> _share(ShortItem item) async {
    final link = item.primaryLink;
    final text = [
      item.title,
      if (link != null) link,
      '— Status Go',
    ].join('\n');
    ref.read(shortsRepositoryProvider).event(item.id, 'SHARE');
    _playback.suspend();
    try {
      await Share.share(text, subject: item.title);
    } finally {
      if (mounted) _playback.resume();
    }
  }

  Future<void> _report(ShortItem item) async {
    _playback.suspend();
    await showReportSheet(context, item.id);
    if (mounted) _playback.resume();
  }

  Future<void> _toggleSave(ShortItem item, ShortsFeedNotifier notifier) async {
    try {
      await notifier.toggleSaved(item.id);
    } catch (e) {
      if (mounted) AppSnack.error(context, apiErrorMessage(e, fallback: 'सेव नहीं हो सका।'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shortsFeedProvider(_query));
    final notifier = ref.read(shortsFeedProvider(_query).notifier);
    final topInset = MediaQuery.of(context).padding.top;
    _syncActive(state.items);

    return Theme(
      data: AppTheme.immersive,
      child: Material(
        color: AppColors.inkSurface,
        child: Stack(
          children: [
            Positioned.fill(child: _content(state, notifier, topInset)),
            Positioned(top: 0, left: 0, right: 0, child: _TopBar(
              topInset: topInset,
              feed: _feed,
              category: _category,
              onFeed: _selectFeed,
              onCategory: _selectCategory,
              onRefresh: notifier.refresh,
            )),
          ],
        ),
      ),
    );
  }

  Widget _content(ShortsFeedState state, ShortsFeedNotifier notifier, double topInset) {
    final pad = EdgeInsets.only(top: topInset + 110);
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return Padding(
        padding: pad,
        child: EmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'लोड नहीं हो सका',
          message: apiErrorMessage(state.error!),
          actionLabel: 'फिर से कोशिश करें',
          onAction: notifier.refresh,
        ),
      );
    }
    if (state.items.isEmpty) {
      return Padding(
        padding: pad,
        child: EmptyState(
          icon: _feed == ShortsFeed.saved ? Icons.bookmark_border_rounded : Icons.video_library_outlined,
          title: _feed == ShortsFeed.saved ? 'कुछ भी सहेजा नहीं गया' : 'अभी कोई वीडियो नहीं',
          message: _feed == ShortsFeed.saved
              ? 'पसंद आने वाले वीडियो को बुकमार्क करें।'
              : 'समीक्षित सामग्री प्रकाशित होते ही यहाँ दिखेगी।',
          actionLabel: 'रीफ़्रेश करें',
          onAction: notifier.refresh,
        ),
      );
    }
    return PageView.builder(
      key: ValueKey(_query),
      controller: _pager,
      scrollDirection: Axis.vertical,
      physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
      allowImplicitScrolling: false, // never pre-build/pre-load neighbours (data + decoder budget)
      itemCount: state.items.length,
      onPageChanged: (i) => _onPageChanged(i, notifier, state.items.length),
      itemBuilder: (ctx, i) {
        final item = state.items[i];
        return _ShortPage(
          key: ValueKey(item.id),
          item: item,
          playback: _playback,
          topInset: topInset,
          onDetail: () => _openDetail(item),
          onSave: () => _toggleSave(item, notifier),
          onShare: () => _share(item),
          onReport: () => _report(item),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.topInset,
    required this.feed,
    required this.category,
    required this.onFeed,
    required this.onCategory,
    required this.onRefresh,
  });

  final double topInset;
  final ShortsFeed feed;
  final String? category;
  final ValueChanged<ShortsFeed> onFeed;
  final ValueChanged<String?> onCategory;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final cats = feed == ShortsFeed.news ? kNewsCategories : kSchemeCategories;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: topInset + 4, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 4),
                // Scales down (never overflows) on narrow screens / large accessibility text.
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Tab('समाचार', feed == ShortsFeed.news, () => onFeed(ShortsFeed.news)),
                        _Tab('योजना', feed == ShortsFeed.scheme, () => onFeed(ShortsFeed.scheme)),
                        _Tab('सहेजे गए', feed == ShortsFeed.saved, () => onFeed(ShortsFeed.saved)),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'रीफ़्रेश करें',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
              ],
            ),
            if (feed != ShortsFeed.saved)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: cats.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final (value, label) = cats[i];
                    final sel = value == category;
                    return Semantics(
                      button: true,
                      selected: sel,
                      label: label,
                      child: ChoiceChip(
                        label: Text(label),
                        selected: sel,
                        onSelected: (_) => onCategory(value),
                        showCheckmark: false,
                        labelStyle: AppText.body(size: 14, weight: FontWeight.w700, color: sel ? Colors.white : AppColors.onDarkMuted),
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.black.withValues(alpha: 0.35),
                        side: BorderSide.none,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  label,
                  style: AppText.heading(
                    size: selected ? 18 : 16,
                    weight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? Colors.white : AppColors.onDarkMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _ShortPage extends StatelessWidget {
  const _ShortPage({
    super.key,
    required this.item,
    required this.playback,
    required this.topInset,
    required this.onDetail,
    required this.onSave,
    required this.onShare,
    required this.onReport,
  });

  final ShortItem item;
  final ShortPlaybackController playback;
  final double topInset;
  final VoidCallback onDetail;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onReport;

  String get _sourceLine {
    if (item.kind == ShortKind.news && item.news != null) {
      final n = item.news!;
      final when = n.publishedAt != null ? ' · ${relativeHi(n.publishedAt!)}' : '';
      return '${n.publisher}$when';
    }
    final s = item.scheme;
    if (s != null) {
      final v = s.lastVerifiedAt != null ? ' · सत्यापित: ${formatDateHi(s.lastVerifiedAt!)}' : '';
      return '${s.department ?? 'सरकारी योजना'}$v';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final stale = item.kind == ShortKind.news && isStaleNews(item.news?.publishedAt);
    final poster = item.thumbnailUrl == null
        ? const ColoredBox(color: AppColors.inkSurface)
        : CachedNetworkImage(
            imageUrl: item.thumbnailUrl!,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => const ColoredBox(color: AppColors.inkSurface),
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video + tap to pause/play
        Semantics(
          button: true,
          label: 'वीडियो चलाएं या रोकें',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: playback.togglePlay,
            child: ShortVideoSurface(playback: playback, id: item.id, placeholder: poster),
          ),
        ),
        // Bottom scrim for text legibility (contrast)
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xE6000000)],
                ),
              ),
            ),
          ),
        ),
        // Paused / loading / error indicator
        Center(
          child: ListenableBuilder(
            listenable: playback,
            builder: (_, __) {
              if (playback.activeId != item.id) return const SizedBox.shrink();
              if (playback.error != null) {
                return const _Badge(icon: Icons.error_outline_rounded, text: 'वीडियो नहीं चल सका — विवरण देखें');
              }
              final c = playback.controller;
              if (c == null) return const CircularProgressIndicator();
              return ValueListenableBuilder(
                valueListenable: c,
                builder: (_, v, __) => v.isPlaying || v.isBuffering
                    ? (v.isBuffering ? const CircularProgressIndicator() : const SizedBox.shrink())
                    : const Icon(Icons.play_arrow_rounded, size: 72, color: Colors.white70),
              );
            },
          ),
        ),
        // Info + actions
        Positioned(
          left: 16,
          right: 76,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stale)
                const _Pill('पुरानी खबर', color: AppColors.accentDark),
              if (item.correctionNote != null) const _Pill('सुधार किया गया', color: AppColors.accentDark),
              Text(
                item.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.heading(size: 21, weight: FontWeight.w800, color: Colors.white, height: 1.35),
              ),
              const SizedBox(height: 6),
              if (_sourceLine.isNotEmpty)
                Text(_sourceLine, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.onDarkMuted)),
              const SizedBox(height: 4),
              Text(item.disclaimer, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: AppText.body(size: 12.5, color: AppColors.onDarkMuted)),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: onDetail,
                  icon: const Icon(Icons.article_outlined),
                  label: Text(item.kind == ShortKind.scheme ? 'पात्रता, दस्तावेज़ और आवेदन' : 'विवरण और स्रोत'),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 4,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Action(
                icon: item.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                label: item.isSaved ? 'सहेजा गया' : 'सहेजें',
                onTap: onSave,
              ),
              _Action(icon: Icons.share_rounded, label: 'शेयर', onTap: onShare),
              ListenableBuilder(
                listenable: playback,
                builder: (_, __) => _Action(
                  icon: playback.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  label: playback.muted ? 'आवाज़ चालू करें' : 'म्यूट करें',
                  onTap: playback.toggleMute,
                ),
              ),
              _Action(icon: Icons.flag_outlined, label: 'रिपोर्ट', onTap: onReport),
            ],
          ),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: label,
        onPressed: onTap,
        iconSize: 28,
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
        icon: Icon(icon, color: Colors.white),
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.pill)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(text, style: AppText.body(size: 12.5, weight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(text, style: AppText.body(size: 14, color: Colors.white)),
          ]),
        ),
      );
}
