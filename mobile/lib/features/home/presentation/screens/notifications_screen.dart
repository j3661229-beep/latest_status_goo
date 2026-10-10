// lib/features/home/presentation/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/data/notification_repository.dart';
import '../../../../core/models/notification_model.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsListProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'सूचनाएं',
          style: GoogleFonts.hind(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              ref.read(notificationsListProvider.notifier).markAllAsRead();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('सभी सूचनाएं पढ़ी हुई मार्क की गईं', style: GoogleFonts.hind()),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.done_all_rounded, size: 18, color: AppColors.primary),
            label: Text(
              'सब पढ़ें',
              style: GoogleFonts.hind(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2.5,
                labelStyle: GoogleFonts.hind(fontWeight: FontWeight.w700, fontSize: 15),
                unselectedLabelStyle: GoogleFonts.hind(fontWeight: FontWeight.w500, fontSize: 15),
                tabs: const [
                  Tab(text: 'सभी (All)'),
                  Tab(text: 'अनपढ़े (Unread)'),
                ],
              ),
              Container(color: AppColors.surfaceBorder, height: 1),
            ],
          ),
        ),
      ),
      body: notificationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 44, color: AppColors.danger),
              const SizedBox(height: 12),
              Text(
                'सूचनाएं लोड नहीं हो सकीं',
                style: GoogleFonts.hind(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.read(notificationsListProvider.notifier).load(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                ),
                child: Text('पुनः प्रयास करें', style: GoogleFonts.hind(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        data: (list) {
          final unreadList = list.where((n) => !n.isRead).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildNotificationList(list),
              _buildNotificationList(unreadList, isUnreadTab: true),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationList(List<NotificationModel> items, {bool isUnreadTab = false}) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(notificationsListProvider.notifier).load(),
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: 450,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  isUnreadTab ? 'कोई नई अनपढ़ी सूचना नहीं है' : 'अभी कोई सूचना नहीं है',
                  style: GoogleFonts.hind(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'रोज़ाना नए स्टेटस और त्योहारों के विशेष अपडेट्स आपको यहां मिलते रहेंगे।',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hind(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(notificationsListProvider.notifier).load(),
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return _NotificationCard(
            item: item,
            onTap: () => _handleCardTap(item),
            onDismissed: () {
              ref.read(notificationsListProvider.notifier).delete(item.id);
            },
          );
        },
      ),
    );
  }

  void _handleCardTap(NotificationModel item) {
    if (!item.isRead) {
      ref.read(notificationsListProvider.notifier).markAsRead(item.id);
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
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel item;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _NotificationCard({
    required this.item,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
      ),
      onDismissed: (_) => onDismissed(),
      child: Material(
        color: item.isRead ? AppColors.surface : AppColors.primarySurface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: item.isRead ? AppColors.surfaceBorder : const Color(0xFFBFDBFE),
                width: item.isRead ? 1 : 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item.iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(item.iconData, color: item.iconColor, size: 22),
                ),
                const SizedBox(width: 12),

                // Content
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
                              style: GoogleFonts.hind(
                                fontSize: 15,
                                fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w700,
                                color: AppColors.textPrimary,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (!item.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: GoogleFonts.hind(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),

                      // Optional image thumbnail
                      if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: Image.network(
                            item.imageUrl!,
                            height: 110,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.iconColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              item.typeLabel,
                              style: GoogleFonts.hind(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: item.iconColor,
                              ),
                            ),
                          ),
                          Text(
                            item.formattedTime,
                            style: GoogleFonts.hind(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
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
    );
  }
}
