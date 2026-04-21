// lib/features/home/presentation/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

// ── Placeholder types for real widgets ──────────────────────
// In production these would be wired to Riverpod providers

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {

  // Mock data
  final _featured = [
    { 'id': '1', 'nameHi': 'सुप्रभात', 'gradient': 'morning', 'emoji': '🌅', 'cat': 'Good Morning' },
    { 'id': '2', 'nameHi': 'जय श्री राम', 'gradient': 'devotional', 'emoji': '🙏', 'cat': 'Devotional' },
    { 'id': '3', 'nameHi': 'दीपावली', 'gradient': 'festival', 'emoji': '🪔', 'cat': 'Festival' },
    { 'id': '4', 'nameHi': 'सफलता', 'gradient': 'brand', 'emoji': '💪', 'cat': 'Motivation' },
  ];

  final _categories = [
    {'slug': 'devotional', 'name': 'भक्ति', 'emoji': '🙏', 'gradient': [const Color(0xFFF7971E), const Color(0xFFFFD200)]},
    {'slug': 'motivational', 'name': 'प्रेरणा', 'emoji': '💪', 'gradient': [const Color(0xFF7C5CFC), const Color(0xFFFF6B9D)]},
    {'slug': 'good-morning', 'name': 'सुप्रभात', 'emoji': '🌅', 'gradient': [const Color(0xFF2DD4BF), const Color(0xFF7C5CFC)]},
    {'slug': 'festival', 'name': 'त्योहार', 'emoji': '🎉', 'gradient': [const Color(0xFFFF6B9D), const Color(0xFFFFB347)]},
    {'slug': 'birthday', 'name': 'जन्मदिन', 'emoji': '🎂', 'gradient': [const Color(0xFF7C5CFC), const Color(0xFFFF6B9D)]},
    {'slug': 'good-night', 'name': 'शुभ रात्रि', 'emoji': '🌙', 'gradient': [const Color(0xFF1a1a2e), const Color(0xFF7C5CFC)]},
  ];

  final _trending = [
    { 'id': '1', 'nameHi': 'जय श्री राम', 'gradient': [const Color(0xFFF7971E), const Color(0xFFFFD200)], 'emoji': '🙏', 'uses': '4.5K' },
    { 'id': '2', 'nameHi': 'सुप्रभात फूल', 'gradient': [const Color(0xFF2DD4BF), const Color(0xFF7C5CFC)], 'emoji': '🌸', 'uses': '8.9K' },
    { 'id': '3', 'nameHi': 'सफलता की राह', 'gradient': [const Color(0xFF7C5CFC), const Color(0xFFFF6B9D)], 'emoji': '💪', 'uses': '5.2K' },
    { 'id': '4', 'nameHi': 'दीपावली', 'gradient': [const Color(0xFFFF6B9D), const Color(0xFFFFB347)], 'emoji': '🪔', 'uses': '12K' },
    { 'id': '5', 'nameHi': 'जन्मदिन', 'gradient': [const Color(0xFF7C5CFC), const Color(0xFFFF6B9D)], 'emoji': '🎂', 'uses': '7.9K' },
    { 'id': '6', 'nameHi': 'शुभ रात्रि', 'gradient': [const Color(0xFF1a1a2e), const Color(0xFF7C5CFC)], 'emoji': '🌙', 'uses': '3.5K' },
  ];

  Color _gradientStart(String g) => switch (g) {
    'devotional' => const Color(0xFFF7971E),
    'morning' => const Color(0xFF2DD4BF),
    'festival' => const Color(0xFFFF6B9D),
    _ => const Color(0xFF7C5CFC),
  };

  Color _gradientEnd(String g) => switch (g) {
    'devotional' => const Color(0xFFFFD200),
    'morning' => const Color(0xFF7C5CFC),
    'festival' => const Color(0xFFFFB347),
    _ => const Color(0xFFFF6B9D),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar ────────────────────────────────
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.brandGradient),
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('📲', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        const Text('Status Go', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                        const Spacer(),
                        // Streak badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Text('🔥', style: TextStyle(fontSize: 14)),
                              SizedBox(width: 4),
                              Text('5 Days', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => context.push('/search'),
                          child: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // ── Festival Alert Banner ────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B9D), Color(0xFFFFB347)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('दशहरा कल है!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      Text('Special status के साथ wishes share करें', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: const Text('देखें', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFFF6B9D))),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Featured / Daily Pack Carousel ───────────────
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('⭐ Featured Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _featured.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) {
              final item = _featured[i];
              return GestureDetector(
                onTap: () => context.push('/template/${item['id']}'),
                child: Container(
                  width: 130,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_gradientStart(item['gradient'] as String), _gradientEnd(item['gradient'] as String)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: _gradientStart(item['gradient'] as String).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(item['emoji'] as String, style: const TextStyle(fontSize: 36)),
                            const SizedBox(height: 8),
                            Text(item['nameHi'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14), textAlign: TextAlign.center),
                            const SizedBox(height: 4),
                            Text(item['cat'] as String, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // ── Categories ───────────────────────────────────
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('📂 Categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) {
              final cat = _categories[i];
              return GestureDetector(
                onTap: () => context.push('/discover?cat=${cat['slug']}'),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: cat['gradient'] as List<Color>),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(child: Text(cat['emoji'] as String, style: const TextStyle(fontSize: 26))),
                    ),
                    const SizedBox(height: 6),
                    Text(cat['name'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // ── Trending ─────────────────────────────────────
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('🔥 Trending Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 9 / 16,
          ),
          itemCount: _trending.length,
          itemBuilder: (ctx, i) {
            final t = _trending[i];
            return GestureDetector(
              onTap: () => context.push('/template/${t['id']}'),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: t['gradient'] as List<Color>,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    // Uses badge
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
                        child: Text(t['uses'] as String, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(t['emoji'] as String, style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 4),
                          Text(t['nameHi'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 100), // Bottom nav padding
      ],
    );
  }
}
