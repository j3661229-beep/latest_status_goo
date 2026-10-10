// lib/features/home/presentation/screens/notifications_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/notification_repository.dart';
import '../../../../core/models/notification_model.dart';
import '../../../../core/widgets/app_ui.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late final NotificationsNotifier _notifier;

  bool _unreadOnly = false;

  /// Swiped-away items whose server/local delete is deferred until the undo
  /// snackbar closes. Hidden from the list in the meantime.
  final Set<String> _pendingDelete = <String>{};

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(notificationsListProvider.notifier);
  }

  @override
  void dispose() {
    // Commit anything still waiting for its undo window.
    for (final id in _pendingDelete) {
      _notifier.delete(id);
    }
    _pendingDelete.clear();
    super.dispose();
  }

  Future<void> _refresh() => _notifier.load();

  void _markAllRead() {
    _notifier.markAllAsRead();
    AppSnack.success(context, 'सभी सूचनाएं पढ़ी हुई मार्क की गईं');
  }

  void _onDismissed(NotificationModel item) {
    setState(() => _pendingDelete.add(item.id));
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger
        .showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            content: const Text('सूचना हटाई गई'),
            action: SnackBarAction(
              label: 'पूर्ववत',
              onPressed: () {
                if (mounted) setState(() => _pendingDelete.remove(item.id));
              },
            ),
          ),
        )
        .closed
        .then((reason) {
      if (reason == SnackBarClosedReason.action) return;
      if (_pendingDelete.remove(item.id)) {
        _notifier.delete(item.id);
      }
    });
  }

  void _handleCardTap(NotificationModel item) {
    if (!item.isRead) {
      _notifier.markAsRead(item.id);
    }

    final data = item.data;
    if (data == null) return;

    final screen = data['screen'] ?? data['deepLink'];
    if (screen != null) {
      final s = screen.toString().toLowerCase();
      if (s == 'home') {
        context.go('/home');
      } else if (s == 'discover' || s == 'festivals') {
        context.go('/discover');
      } else if (s == 'premium') {
        context.push('/premium');
      } else if (s == 'saved') {
        context.go('/saved');
      } else if (data['templateId'] != null) {
        context.push('/template/${data['templateId']}');
      }
    } else if (data['templateId'] != null) {
      context.push('/template/${data['templateId']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsListProvider);
    final p = context.palette;
    final all = (notificationsAsync.valueOrNull ?? const <NotificationModel>[])
        .where((n) => !_pendingDelete.contains(n.id))
        .toList();
    final unreadCount = all.where((n) => !n.isRead).length;

    return AppScaffold(
      title: 'सूचनाएं',
      actions: [
        AppIconButton(
          icon: Icons.done_all_rounded,
          semanticLabel: 'सभी पढ़ी हुई मार्क करें',
          onPressed: unreadCount == 0 ? null : _markAllRead,
        ),
        const SizedBox(width: AppSpacing.xxs),
      ],
      body: notificationsAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          children: const [ShimmerList(itemCount: 6, itemHeight: 96)],
        ),
        error: (e, _) => ErrorState(
          title: 'सूचनाएं लोड नहीं हो सकीं',
          onRetry: _notifier.load,
        ),
        data: (_) {
          final items = _unreadOnly ? all.where((n) => !n.isRead).toList() : all;
          return RefreshIndicator(
            color: p.primary,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: FilterPillRow(
                      labels: ['सभी', unreadCount > 0 ? 'अनपढ़े ($unreadCount)' : 'अनपढ़े'],
                      selectedIndex: _unreadOnly ? 1 : 0,
                      onSelected: (i) => setState(() => _unreadOnly = i == 1),
                    ),
                  ),
                ),
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: _unreadOnly ? 'कोई अनपढ़ी सूचना नहीं है' : 'अभी कोई सूचना नहीं है',
                      message: 'रोज़ाना नए स्टेटस और त्योहारों के विशेष अपडेट्स आपको यहां मिलते रहेंगे।',
                      compact: true,
                    ),
                  )
                else
                  ..._buildGroups(items),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildGroups(List<NotificationModel> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayList = <NotificationModel>[];
    final yesterdayList = <NotificationModel>[];
    final earlier = <NotificationModel>[];
    for (final n in items) {
      final local = n.sentAt.toLocal();
      final d = DateTime(local.year, local.month, local.day);
      if (!d.isBefore(today)) {
        todayList.add(n);
      } else if (!d.isBefore(yesterday)) {
        yesterdayList.add(n);
      } else {
        earlier.add(n);
      }
    }

    final slivers = <Widget>[];
    var counter = 0;
    void addGroup(String title, List<NotificationModel> list) {
      if (list.isEmpty) return;
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xs),
          child: Text(title, style: AppText.heading(size: 17, color: context.palette.textPrimary)),
        ),
      ));
      final start = counter;
      counter += list.length;
      slivers.add(SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final item = list[i];
            return Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xs),
              child: FadeSlideIn(
                index: start + i,
                child: _NotificationCard(
                  key: ValueKey(item.id),
                  item: item,
                  onTap: () => _handleCardTap(item),
                  onDismissed: () => _onDismissed(item),
                ),
              ),
            );
          },
          childCount: list.length,
        ),
      ));
    }

    addGroup('आज', todayList);
    addGroup('कल', yesterdayList);
    addGroup('पहले', earlier);
    return slivers;
  }
}

class _TypeStyle {
  final Color color;
  final IconData icon;
  const _TypeStyle(this.color, this.icon);
}

_TypeStyle _styleFor(NotificationModel n, bool dark) {
  switch (n.type.toUpperCase()) {
    case 'FESTIVAL_ALERT':
      return _TypeStyle(dark ? AppColors.accent : AppColors.accentDark, Icons.celebration_rounded);
    case 'PREMIUM_OFFER':
      return _TypeStyle(dark ? AppColors.gold : AppColors.goldDark, Icons.workspace_premium_rounded);
    case 'DAILY_STATUS':
      return _TypeStyle(dark ? AppColors.primaryLight : AppColors.primary, Icons.wb_sunny_rounded);
    case 'TEMPLATE_APPROVED':
      return const _TypeStyle(AppColors.success, Icons.check_circle_rounded);
    case 'TEMPLATE_REJECTED':
      return const _TypeStyle(AppColors.danger, Icons.error_outline_rounded);
    default:
      return _TypeStyle(dark ? AppColors.primaryLight : AppColors.info, Icons.notifications_rounded);
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel item;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _NotificationCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = _styleFor(item, p.isDark);
    final unread = !item.isRead;
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;

    return Dismissible(
      key: ValueKey('dismiss_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(color: AppColors.danger, borderRadius: AppRadius.lgAll),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.white, size: 28),
      ),
      onDismissed: (_) => onDismissed(),
      child: Semantics(
        button: true,
        label: '${unread ? 'नई सूचना: ' : ''}${item.title}. ${item.body}',
        excludeSemantics: true,
        child: Material(
          color: unread ? p.primarySurface : p.surface,
          borderRadius: AppRadius.lgAll,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.lgAll,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                borderRadius: AppRadius.lgAll,
                border: Border.all(
                  color: unread ? p.primary.withValues(alpha: 0.35) : p.border,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: style.color.withValues(alpha: 0.14),
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: Icon(style.icon, color: style.color, size: 26),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: AppText.body(
                                  size: 16,
                                  weight: unread ? FontWeight.w800 : FontWeight.w600,
                                  color: p.textPrimary,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            if (unread)
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(top: 6, left: 8),
                                decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
                              ),
                          ],
                        ),
                        if (item.body.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.body,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(size: 14.5, color: p.textSecondary, height: 1.4),
                          ),
                        ],
                        if (hasImage) ...[
                          const SizedBox(height: AppSpacing.xs),
                          ClipRRect(
                            borderRadius: AppRadius.mdAll,
                            child: CachedNetworkImage(
                              imageUrl: item.imageUrl!,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const ShimmerBox(height: 120),
                              errorWidget: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: style.color.withValues(alpha: 0.14),
                                borderRadius: AppRadius.pillAll,
                              ),
                              child: Text(
                                item.typeLabel,
                                style: AppText.body(
                                    size: 12.5, weight: FontWeight.w700, color: style.color, height: 1.2),
                              ),
                            ),
                            Text(
                              item.formattedTime,
                              style: AppText.body(size: 13, color: p.textMuted, height: 1.2),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
