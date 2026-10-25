// lib/features/shorts/presentation/screens/shorts_screen.dart
//
// "Shorts" tab: Daily News / Yojana & Scholarships / Saved, as an Inshorts-style vertical
// pager of cards (image + headline + ~60-word summary). Only admin-published items are served.
// A video is never auto-played: cards with an admin-generated video show a "watch video"
// button that opens a full-screen viewer (one VideoPlayerController, see ShortPlaybackController).
// No RefreshIndicator / Transform around the PageView (invalid SliverGeometry crash
// documented in PROJECT_AUDIT.md) — refresh is an explicit button + error retry.
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../data/short_models.dart';
import '../../data/shorts_repository.dart';
import '../providers/shorts_feed_provider.dart';
import '../short_format.dart';
import '../widgets/report_sheet.dart';
import '../widgets/short_player.dart';
import '../widgets/short_status_share_sheet.dart';

class ShortsScreen extends ConsumerStatefulWidget {
  const ShortsScreen({super.key, this.controllerFactory});

  /// Test seam: lets tests supply fake video controllers.
  final ControllerFactory? controllerFactory;

  @override
  ConsumerState<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends ConsumerState<ShortsScreen> with WidgetsBindingObserver {
  late final ShortPlaybackController _playback;
  PageController _pager = PageController();
  ShortsFeed _feed = ShortsFeed.news;
  String? _category;
  int _index = 0;
  final Set<String> _viewed = {};
  DateTime _backgroundedAt = DateTime.now();
  // Content is published automatically, so a long-idle feed is refreshed when the app returns.
  static const _staleAfter = Duration(minutes: 10);

  ShortsQuery get _query => ShortsQuery(_feed, _feed == ShortsFeed.saved ? null : _category);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _playback = ShortPlaybackController(factory: widget.controllerFactory);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pager.dispose();
    _playback.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed &&
        DateTime.now().difference(_backgroundedAt) > _staleAfter &&
        _feed != ShortsFeed.saved) {
      ref.read(shortsFeedProvider(_query).notifier).refresh();
    }
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

  /// Count a view for the visible card (no video is loaded). Safe to call from build.
  void _syncActive(List<ShortItem> items) {
    if (items.isEmpty) return;
    final item = items[_index.clamp(0, items.length - 1)];
    if (_viewed.contains(item.id)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _viewed.add(item.id)) ref.read(shortsRepositoryProvider).event(item.id, 'VIEW');
    });
  }

  /// Full-screen player, opened only when the reader asks for the video.
  Future<void> _watchVideo(ShortItem item) async {
    if (!item.hasVideo) return;
    HapticFeedback.selectionClick();
    unawaited(_playback.activate(item.id, item.videoUrl));
    await Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _VideoViewer(item: item, playback: _playback),
    ));
    _playback.stop();
  }

  void _onPageChanged(int i, ShortsFeedNotifier notifier, int length) {
    HapticFeedback.selectionClick();
    // Don't swap the decoder mid-swipe: let the pager settle this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _index = i);
    });
    if (i >= length - 3) notifier.loadMore();
  }

  Future<void> _openDetail(ShortItem item) => context.push('/shorts/${item.id}');

  Future<void> _share(ShortItem item) async {
    ref.read(shortsRepositoryProvider).event(item.id, 'SHARE');
    await showShortStatusShareSheet(context, item);
  }

  Future<void> _report(ShortItem item) => showReportSheet(context, item.id);

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

    return Material(
      color: context.palette.bg,
      child: Column(
        children: [
          _TopBar(
            topInset: topInset,
            feed: _feed,
            category: _category,
            onFeed: _selectFeed,
            onCategory: _selectCategory,
            onRefresh: notifier.refresh,
          ),
          Expanded(child: _content(state, notifier)),
        ],
      ),
    );
  }

  Widget _content(ShortsFeedState state, ShortsFeedNotifier notifier) {
    const pad = EdgeInsets.only(top: 24);
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
          icon: _feed == ShortsFeed.saved ? Icons.bookmark_border_rounded : Icons.newspaper_rounded,
          title: _feed == ShortsFeed.saved ? 'कुछ भी सहेजा नहीं गया' : 'अभी कोई खबर नहीं',
          message: _feed == ShortsFeed.saved
              ? 'पसंद आने वाली खबर या योजना को बुकमार्क करें।'
              : 'एडमिन द्वारा प्रकाशित खबरें और योजनाएँ यहाँ दिखेंगी।',
          actionLabel: 'रीफ़्रेश करें',
          onAction: notifier.refresh,
        ),
      );
    }
    final pager = PageView.builder(
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
          onWatch: () => _watchVideo(item),
          onDetail: () => _openDetail(item),
          onSave: () => _toggleSave(item, notifier),
          onShare: () => _share(item),
          onReport: () => _report(item),
        );
      },
    );
    if (state.loadMoreError == null) return pager;
    return Stack(
      children: [
        Positioned.fill(child: pager),
        Positioned(
          left: 0,
          right: 0,
          top: 8,
          child: Center(
            child: ActionChip(
              avatar: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
              label: Text('और खबरें लोड नहीं हुईं — दोबारा कोशिश करें',
                  style: AppText.body(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
              backgroundColor: Colors.black.withValues(alpha: 0.6),
              side: BorderSide.none,
              onPressed: notifier.loadMore,
            ),
          ),
        ),
      ],
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
    final p = context.palette;
    final cats = feed == ShortsFeed.news ? kNewsCategories : kSchemeCategories;
    return Material(
      color: p.surface,
      elevation: 1,
      shadowColor: Colors.black26,
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
                FilledButton.tonalIcon(
                  onPressed: () => context.push('/scheme-finder'),
                  icon: const Icon(Icons.calculate_outlined, size: 16),
                  label: const Text('योजना मित्र', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'रीफ़्रेश करें',
                  onPressed: onRefresh,
                  icon: Icon(Icons.refresh_rounded, color: p.textPrimary),
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
                        labelStyle: AppText.body(size: 14, weight: FontWeight.w700, color: sel ? Colors.white : p.textSecondary),
                        selectedColor: AppColors.primary,
                        backgroundColor: p.surfaceMuted,
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
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: AppText.heading(
                    size: selected ? 18 : 16,
                    weight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? p.primary : p.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 3,
                  width: selected ? 22 : 0,
                  decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(2)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One Inshorts-style news card: image, headline, ~60-word summary, source, actions.
class _ShortPage extends StatelessWidget {
  const _ShortPage({
    super.key,
    required this.item,
    required this.onWatch,
    required this.onDetail,
    required this.onSave,
    required this.onShare,
    required this.onReport,
  });

  final ShortItem item;
  final VoidCallback onWatch;
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
    final p = context.palette;
    final stale = item.kind == ShortKind.news && isStaleNews(item.news?.publishedAt);
    final summary = item.summary ?? item.hook;
    final hasVideo = item.hasVideo;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: p.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image (+ optional admin-generated video behind a button)
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Poster(url: item.thumbnailUrl, kind: item.kind),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _Pill(item.kind == ShortKind.scheme ? 'सरकारी योजना' : 'समाचार', color: AppColors.primary),
                    ),
                    if (hasVideo)
                      Center(
                        child: Semantics(
                          button: true,
                          label: 'वीडियो देखें',
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: onWatch,
                              child: const SizedBox(
                                width: 64,
                                height: 64,
                                child: Icon(Icons.play_arrow_rounded, size: 44, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (hasVideo && item.durationSec != null)
                      Positioned(
                        right: 10,
                        bottom: 4,
                        child: _Pill('${item.durationSec!.round()} सेकंड', color: Colors.black54),
                      ),
                  ],
                ),
              ),
              // Headline + summary (clipped, never overflows on small screens)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: ClipRect(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(spacing: 6, children: [
                            if (stale) const _Pill('पुरानी खबर', color: AppColors.accentDark),
                            if (item.correctionNote != null) const _Pill('सुधार किया गया', color: AppColors.accentDark),
                          ]),
                          Text(
                            item.title,
                            style: AppText.heading(size: 20, weight: FontWeight.w800, color: p.textPrimary, height: 1.35),
                          ),
                          if (summary != null) ...[
                            const SizedBox(height: 10),
                            Text(summary, style: AppText.body(size: 16, color: p.textSecondary, height: 1.6)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Source + disclaimer
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_sourceLine.isNotEmpty)
                      Text(_sourceLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(size: 13.5, weight: FontWeight.w700, color: p.textMuted)),
                    Text(item.disclaimer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(size: 12, color: p.textMuted)),
                  ],
                ),
              ),
              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: onDetail,
                          icon: const Icon(Icons.article_outlined),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(item.kind == ShortKind.scheme ? 'पात्रता, दस्तावेज़ और आवेदन' : 'विवरण और स्रोत'),
                          ),
                        ),
                      ),
                    ),
                    _Action(
                      icon: item.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      label: item.isSaved ? 'सहेजा गया' : 'सहेजें',
                      onTap: onSave,
                    ),
                    _Action(icon: Icons.share_rounded, label: 'शेयर', onTap: onShare),
                    _Action(icon: Icons.flag_outlined, label: 'रिपोर्ट', onTap: onReport),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.url, required this.kind});
  final String? url;
  final ShortKind kind;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      child: Center(
        child: Icon(kind == ShortKind.scheme ? Icons.account_balance_rounded : Icons.newspaper_rounded,
            size: 56, color: Colors.white70),
      ),
    );
    if (url == null) return fallback;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

/// Full-screen player for the one admin-generated video behind a card.
class _VideoViewer extends StatelessWidget {
  const _VideoViewer({required this.item, required this.playback});
  final ShortItem item;
  final ShortPlaybackController playback;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.immersive,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              button: true,
              label: 'वीडियो चलाएं या रोकें',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: playback.togglePlay,
                child: ShortVideoSurface(
                  playback: playback,
                  id: item.id,
                  placeholder: const ColoredBox(color: Colors.black),
                ),
              ),
            ),
            Center(
              child: ListenableBuilder(
                listenable: playback,
                builder: (_, __) {
                  if (playback.activeId != item.id) return const SizedBox.shrink();
                  if (playback.error != null) {
                    return const _Badge(icon: Icons.error_outline_rounded, text: 'वीडियो नहीं चल सका');
                  }
                  final c = playback.controller;
                  if (c == null) return const CircularProgressIndicator();
                  return ValueListenableBuilder(
                    valueListenable: c,
                    builder: (_, v, __) => v.isBuffering
                        ? const CircularProgressIndicator()
                        : v.isPlaying
                            ? const SizedBox.shrink()
                            : const Icon(Icons.play_arrow_rounded, size: 72, color: Colors.white70),
                  );
                },
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'बंद करें',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.heading(size: 16, weight: FontWeight.w700, color: Colors.white)),
                    ),
                    ListenableBuilder(
                      listenable: playback,
                      builder: (_, __) => IconButton(
                        tooltip: playback.muted ? 'आवाज़ चालू करें' : 'म्यूट करें',
                        onPressed: playback.toggleMute,
                        icon: Icon(playback.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
        iconSize: 26,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: Icon(icon, color: context.palette.textSecondary),
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
