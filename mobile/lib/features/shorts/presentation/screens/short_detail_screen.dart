// lib/features/shorts/presentation/screens/short_detail_screen.dart
//
// Text-first detail view: everything in the video, plus eligibility / documents /
// steps for schemes, with official links, sources, and verification dates.
// Readable without playing the video (accessibility + low-data).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/utils/app_actions.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../data/short_models.dart';
import '../../data/shorts_repository.dart';
import '../providers/shorts_feed_provider.dart';
import '../short_format.dart';
import '../widgets/report_sheet.dart';
import '../widgets/short_status_share_sheet.dart';

class ShortDetailScreen extends ConsumerStatefulWidget {
  const ShortDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ShortDetailScreen> createState() => _ShortDetailScreenState();
}

class _ShortDetailScreenState extends ConsumerState<ShortDetailScreen> {
  bool? _savedOverride;

  Future<void> _toggleSave(ShortItem item) async {
    final next = !(_savedOverride ?? item.isSaved);
    setState(() => _savedOverride = next);
    try {
      await ref.read(shortsRepositoryProvider).setSaved(item.id, next);
    } catch (e) {
      if (!mounted) return;
      setState(() => _savedOverride = !next);
      AppSnack.error(context, apiErrorMessage(e, fallback: 'सेव नहीं हो सका।'));
    }
  }

  Future<void> _share(ShortItem item) async {
    ref.read(shortsRepositoryProvider).event(item.id, 'SHARE');
    await showShortStatusShareSheet(context, item);
  }

  Future<void> _open(ShortItem item, String url) async {
    ref.read(shortsRepositoryProvider).event(item.id, 'OPEN_LINK');
    await AppActions.openUrl(context, url);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shortDetailProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: const Text('विवरण')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'सामग्री नहीं मिली',
          message: apiErrorMessage(e, fallback: 'यह सामग्री उपलब्ध नहीं है या हटा दी गई है।'),
          actionLabel: 'फिर से कोशिश करें',
          onAction: () => ref.invalidate(shortDetailProvider(widget.id)),
        ),
        data: (d) => _Body(
          detail: d,
          saved: _savedOverride ?? d.item.isSaved,
          onSave: () => _toggleSave(d.item),
          onShare: () => _share(d.item),
          onReport: () => showReportSheet(context, d.item.id),
          onOpen: (u) => _open(d.item, u),
          onOpenRelated: (id) => context.push('/shorts/$id'),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.detail,
    required this.saved,
    required this.onSave,
    required this.onShare,
    required this.onReport,
    required this.onOpen,
    required this.onOpenRelated,
  });

  final ShortDetail detail;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onReport;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onOpenRelated;

  @override
  Widget build(BuildContext context) {
    final item = detail.item;
    final t = Theme.of(context).textTheme;
    final scheme = item.scheme;
    final news = item.news;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (item.isRegional) ...[
          Wrap(
            spacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      item.region != null ? 'क्षेत्रीय (${item.region})' : 'क्षेत्रीय समाचार',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Text(item.title, style: t.headlineSmall),
        const SizedBox(height: 8),
        if (item.isYoutube && item.youtubeId != null) ...[
          _YoutubePlayerCard(youtubeId: item.youtubeId!, title: item.title),
          const SizedBox(height: 12),
        ],
        _Disclaimer(text: item.disclaimer),
        if (item.correctionNote != null) ...[
          const SizedBox(height: 12),
          _Notice(icon: Icons.edit_note_rounded, color: AppColors.accentDark, text: 'सुधार: ${item.correctionNote}'),
        ],
        if (news != null && news.correctionStatus == 'CORRECTED') ...[
          const SizedBox(height: 12),
          const _Notice(icon: Icons.edit_note_rounded, color: AppColors.accentDark, text: 'स्रोत ने इस खबर में सुधार किया है।'),
        ],
        const SizedBox(height: 16),

        // ── Source & dates (always visible) ──
        if (news != null) _NewsSource(news: news, onOpen: onOpen),
        if (scheme != null) _SchemeHeader(scheme: scheme),

        if (item.narration != null) ...[
          const _Section('वीडियो का सार'),
          Text(item.narration!, style: t.bodyLarge),
        ],
        if (item.keyFacts.isNotEmpty) _Bullets('मुख्य बातें', item.keyFacts),

        if (scheme != null) ...[
          if (scheme.benefits.isNotEmpty) _Bullets('लाभ', scheme.benefits),
          _Bullets(
            'पात्रता',
            scheme.eligibility,
            note: 'अंतिम पात्रता आधिकारिक वेबसाइट पर जाँचें। यह सभी के लिए लाभ की गारंटी नहीं है।',
            emptyText: 'पात्रता की जानकारी आधिकारिक वेबसाइट पर देखें।',
          ),
          _Bullets('ज़रूरी दस्तावेज़', scheme.documents, emptyText: 'दस्तावेज़ों की सूची आधिकारिक वेबसाइट पर देखें।'),
          _Numbered('आवेदन कैसे करें', scheme.applicationSteps),
          if (scheme.applicationUrl != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('आधिकारिक आवेदन वेबसाइट खोलें'),
                onPressed: () => onOpen(scheme.applicationUrl!),
              ),
            ),
          ],
          if (scheme.sourceUrls.isNotEmpty) ...[
            const _Section('आधिकारिक स्रोत'),
            for (final u in scheme.sourceUrls)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.link_rounded),
                title: Text(u, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => onOpen(u),
              ),
          ],
        ],

        if (item.attribution != null) ...[
          const SizedBox(height: 8),
          Text(item.attribution!, style: t.bodySmall),
        ],

        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onSave,
                icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
                label: Text(saved ? 'सहेजा गया' : 'सहेजें'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.share_rounded),
                label: const Text('शेयर करें'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onReport,
          icon: const Icon(Icons.flag_outlined),
          label: const Text('गलत या पुरानी जानकारी बताएं'),
        ),

        if (detail.related.isNotEmpty) ...[
          const _Section('संबंधित'),
          for (final r in detail.related)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: r.publishedAt != null ? Text(formatDateHi(r.publishedAt!)) : null,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onOpenRelated(r.id),
            ),
        ],
      ],
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => _Notice(icon: Icons.smart_toy_outlined, color: AppColors.primary, text: text);
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      );
}

class _NewsSource extends StatelessWidget {
  const _NewsSource({required this.news, required this.onOpen});
  final NewsInfo news;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final stale = isStaleNews(news.publishedAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('स्रोत: ${news.publisher}', style: t.titleMedium),
        if (news.originalHeadline != null) Text('“${news.originalHeadline}”', style: t.bodyMedium),
        if (news.publishedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('प्रकाशित: ${formatDateTimeHi(news.publishedAt!)}', style: t.bodySmall),
          ),
        if (news.lastVerifiedAt != null) Text('स्रोत की जाँच: ${formatDateTimeHi(news.lastVerifiedAt!)}', style: t.bodySmall),
        if (stale)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: _Notice(icon: Icons.history_rounded, color: AppColors.accentDark, text: 'यह पुरानी खबर है, ताज़ा अपडेट के लिए स्रोत देखें।'),
          ),
        if (news.isDeveloping)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: _Notice(icon: Icons.update_rounded, color: AppColors.accentDark, text: 'यह खबर अभी विकसित हो रही है; जानकारी बदल सकती है।'),
          ),
        if (news.url != null)
          TextButton.icon(
            onPressed: () => onOpen(news.url!),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('मूल खबर पढ़ें'),
          ),
      ],
    );
  }
}

class _SchemeHeader extends StatelessWidget {
  const _SchemeHeader({required this.scheme});
  final SchemeInfo scheme;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(scheme.nameHi, style: t.titleMedium),
        if (scheme.officialName.isNotEmpty) Text(scheme.officialName, style: t.bodySmall),
        if (scheme.department != null) Text('विभाग: ${scheme.department}', style: t.bodyMedium),
        Text(
          scheme.lastVerifiedAt != null ? 'अंतिम सत्यापन: ${formatDateHi(scheme.lastVerifiedAt!)}' : 'सत्यापन की तारीख उपलब्ध नहीं',
          style: t.bodySmall,
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
      );
}

class _Bullets extends StatelessWidget {
  const _Bullets(this.title, this.items, {this.note, this.emptyText});
  final String title;
  final List<String> items;
  final String? note;
  final String? emptyText;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && emptyText == null) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(title),
        if (items.isEmpty) Text(emptyText!, style: t.bodyMedium),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(i, style: t.bodyLarge)),
              ],
            ),
          ),
        if (note != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(note!, style: t.bodySmall)),
      ],
    );
  }
}

class _Numbered extends StatelessWidget {
  const _Numbered(this.title, this.items);
  final String title;
  final List<String> items;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(title),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i + 1}.  ', style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                Expanded(child: Text(items[i], style: t.bodyLarge)),
              ],
            ),
          ),
      ],
    );
  }
}

class _YoutubePlayerCard extends StatefulWidget {
  const _YoutubePlayerCard({required this.youtubeId, required this.title});
  final String youtubeId;
  final String title;

  @override
  State<_YoutubePlayerCard> createState() => _YoutubePlayerCardState();
}

class _YoutubePlayerCardState extends State<_YoutubePlayerCard> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.youtubeId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: const Color(0xFFFF0000),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.smart_display_rounded, size: 18, color: Color(0xFFFF0000)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'आधिकारिक योजना वीडियो (YouTube)',
                      style: AppText.body(size: 13, weight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
