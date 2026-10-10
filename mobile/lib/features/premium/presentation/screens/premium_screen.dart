// lib/features/premium/presentation/screens/premium_screen.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';
import '../../data/subscription_repository.dart';

enum SelectedPlanType { intro, annual, monthly }

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

/// Inline payment notice shown above the CTA (failure / cancel / info).
class _Notice {
  final String message;
  final InfoTone tone;
  final String? title;
  const _Notice(this.message, this.tone, {this.title});
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  SelectedPlanType _selectedPlan = SelectedPlanType.intro;
  bool _isLoading = false;
  bool _refreshing = false;
  bool _cancelling = false;
  _Notice? _notice;

  SubscriptionStatus? _subStatus;

  // Plan amounts for one-time orders
  static const _monthlyPrice = 99;
  static const _annualPrice = 799;
  static const _monthlyDays = 30;
  static const _annualDays = 365;

  static int get _savePercent =>
      (((_monthlyPrice * 12 - _annualPrice) / (_monthlyPrice * 12)) * 100).round();
  static int get _perMonthAnnual => (_annualPrice / 12).round();

  static const _benefits = <(IconData, String, String)>[
    (Icons.workspace_premium_rounded, 'सभी प्रीमियम टेम्पलेट अनलॉक', 'लॉक किए गए सभी स्टेटस इस्तेमाल करें'),
    (Icons.all_inclusive_rounded, 'असीमित डाउनलोड', 'रोज़ जितने चाहें इमेज व वीडियो डाउनलोड करें'),
    (Icons.celebration_rounded, 'सभी त्योहार पैक', 'हर त्योहार के खास प्रीमियम टेम्पलेट'),
    (Icons.support_agent_rounded, 'प्राथमिकता सहायता', 'आपकी समस्या पहले सुलझेगी'),
  ];

  late final Razorpay _razorpay;

  String? _pendingOrderId;
  String? _pendingSubscriptionId;
  bool _isIntroFlow = true;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStatus();
    });
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  String get _themeHex => '#${AppColors.primary.toARGB32().toRadixString(16).substring(2)}';

  Future<void> _loadStatus() async {
    try {
      final status = await ref.read(subscriptionRepositoryProvider).fetchStatus();
      if (!mounted) return;
      setState(() {
        _subStatus = status;
        if (!status.introEligible && _selectedPlan == SelectedPlanType.intro) {
          _selectedPlan = SelectedPlanType.annual;
        }
      });
    } catch (_) {
      // Graceful fallback to default selections
    }
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<void> _initiateCheckout() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _notice = null;
    });

    final user = ref.read(currentUserProvider);

    try {
      final repo = ref.read(subscriptionRepositoryProvider);

      if (_selectedPlan == SelectedPlanType.intro) {
        // ── Intro AutoPay Flow (₹1 upfront, ₹99/mo after 30d) ──
        final introData = await repo.createIntroSubscription();
        _pendingSubscriptionId = introData.subscriptionId;
        _pendingOrderId = null;
        _isIntroFlow = true;

        final key = introData.keyId.isNotEmpty ? introData.keyId : AppConstants.razorpayKeyId;
        if (key.isEmpty) {
          throw const ApiException('भुगतान कॉन्फ़िगर नहीं है (Razorpay key missing)।');
        }

        _razorpay.open({
          'key': key,
          'subscription_id': introData.subscriptionId,
          'name': AppConstants.appName,
          'description': '30 दिन ₹1 में — फिर ₹99/माह AutoPay',
          'prefill': {
            if (user?.phoneNumber != null) 'contact': user!.phoneNumber,
            if (user?.email != null) 'email': user!.email,
          },
          'theme': {'color': _themeHex},
        });
      } else {
        // ── One-Time Order Flow (₹99 or ₹799) ──
        final planKey = _selectedPlan == SelectedPlanType.annual ? 'ANNUAL' : 'PREMIUM';
        final orderData = await repo.createOneTimeOrder(plan: planKey);

        final orderId = orderData['orderId'] as String?;
        final amount = orderData['amount'];
        final serverKey = orderData['keyId'] as String?;
        final key = (serverKey != null && serverKey.isNotEmpty) ? serverKey : AppConstants.razorpayKeyId;

        if (orderId == null || amount == null) {
          throw const ApiException('ऑर्डर नहीं बन सका। कृपया दोबारा कोशिश करें।');
        }
        if (key.isEmpty) {
          throw const ApiException('भुगतान कॉन्फ़िगर नहीं है (Razorpay key missing)।');
        }

        _pendingOrderId = orderId;
        _pendingSubscriptionId = null;
        _isIntroFlow = false;

        _razorpay.open({
          'key': key,
          'order_id': orderId,
          'amount': amount,
          'currency': orderData['currency'] ?? 'INR',
          'name': AppConstants.appName,
          'description': _selectedPlan == SelectedPlanType.annual ? 'Premium Annual' : 'Premium Monthly',
          'prefill': {
            if (user?.phoneNumber != null) 'contact': user!.phoneNumber,
            if (user?.email != null) 'email': user!.email,
          },
          'theme': {'color': _themeHex},
        });
      }
    } catch (e) {
      _pendingOrderId = null;
      _pendingSubscriptionId = null;
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(apiErrorMessage(e, fallback: 'भुगतान शुरू करने में समस्या आई।'));
      }
    }
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    final repo = ref.read(subscriptionRepositoryProvider);
    try {
      if (_isIntroFlow) {
        final subId = _pendingSubscriptionId;
        final paymentId = response.paymentId;
        final signature = response.signature;

        if (subId == null || paymentId == null || signature == null) {
          throw const ApiException('भुगतान पुष्टि विवरण अधूरा है।');
        }

        await repo.verifyIntroSubscription(
          subscriptionId: subId,
          paymentId: paymentId,
          signature: signature,
        );
      } else {
        final orderId = response.orderId ?? _pendingOrderId;
        final paymentId = response.paymentId;
        final signature = response.signature;

        if (orderId == null || paymentId == null || signature == null) {
          throw const ApiException('भुगतान पुष्टि विवरण अधूरा है।');
        }

        await repo.verifyOneTimeOrder(
          orderId: orderId,
          paymentId: paymentId,
          signature: signature,
        );
      }

      try {
        await ref.read(authRepositoryProvider).refreshCurrentUser();
        await _loadStatus();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _notice = null;
        _pendingOrderId = null;
        _pendingSubscriptionId = null;
      });
      await _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(
        apiErrorMessage(
          e,
          fallback: 'भुगतान हो गया पर पुष्टि नहीं हो सकी। चिंता न करें — कुछ देर में प्लान अपडेट हो जाएगा, '
              'या सहायता से संपर्क करें (Payment ID: ${response.paymentId ?? '-'})।',
        ),
        title: 'पुष्टि लंबित है',
      );
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    _pendingOrderId = null;
    _pendingSubscriptionId = null;
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      _showNotice(const _Notice('आपने भुगतान रद्द कर दिया। कोई पैसा नहीं कटा — जब चाहें दोबारा कोशिश करें।', InfoTone.info,
          title: 'भुगतान रद्द किया गया'));
    } else {
      _showError(
        'भुगतान विफल रहा${response.message != null ? ': ${response.message}' : ''}। अगर पैसे कटे हैं तो वह वापस आ जाएंगे।',
        title: 'भुगतान नहीं हो सका',
      );
    }
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    AppSnack.info(
      context,
      '${response.walletName ?? 'वॉलेट'} से भुगतान पूरा करें। पुष्टि होने पर प्लान सक्रिय हो जाएगा।',
    );
  }

  void _showNotice(_Notice n) => setState(() => _notice = n);

  void _showError(String message, {String? title}) {
    setState(() => _notice = _Notice(message, InfoTone.danger, title: title));
    AppSnack.error(context, title ?? message);
  }

  Future<void> _refreshStatus() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final user = await ref.read(authRepositoryProvider).refreshCurrentUser();
      await _loadStatus();
      if (!mounted) return;
      if (user?.isPremium ?? false) {
        AppSnack.success(context, 'आपका प्रीमियम प्लान सक्रिय है।');
        setState(() => _notice = null);
      } else {
        AppSnack.info(context, 'अभी प्लान सक्रिय नहीं दिखा। कुछ मिनट बाद फिर कोशिश करें।');
      }
    } catch (e) {
      if (mounted) AppSnack.error(context, apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _confirmCancelAutoPay() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.inkSurface2,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: Text('AutoPay रद्द करें?', style: AppText.heading(size: 18, color: AppColors.onDark)),
        content: Text(
          'क्या आप वाकई AutoPay रिन्यूअल बंद करना चाहते हैं? आपका प्रीमियम वर्तमान अवधि के अंत तक चालू रहेगा और इसके बाद कोई नया चार्ज नहीं कटेगा।',
          style: AppText.body(size: 14.5, color: AppColors.onDarkMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('वापस जाएं', style: AppText.body(size: 14, color: AppColors.onDarkHint)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.onDark,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('हाँ, रद्द करें'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final message = await ref.read(subscriptionRepositoryProvider).cancelSubscription();
      await ref.read(authRepositoryProvider).refreshCurrentUser();
      await _loadStatus();
      if (mounted) {
        AppSnack.success(context, message);
      }
    } catch (e) {
      if (mounted) AppSnack.error(context, apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _showSuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SuccessDialog(
        onDone: () {
          Navigator.of(ctx).pop();
          if (mounted && context.canPop()) context.pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(currentUserProvider)?.isPremium ?? false;
    final isRecurring = _subStatus?.isRecurring ?? false;
    final introEligible = _subStatus?.introEligible ?? true;
    final nextRenewalDate = DateTime.now().add(const Duration(days: 30));

    return ImmersiveTheme(
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.inkGradient),
        child: Scaffold(
          backgroundColor: AppColors.transparent,
          appBar: AppBar(
            backgroundColor: AppColors.transparent,
            automaticallyImplyLeading: false,
            leading: AppIconButton(
              icon: Icons.close_rounded,
              semanticLabel: 'बंद करें',
              glass: true,
              onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
            ),
            title: Text('प्रीमियम सदस्यता', style: AppText.heading(size: 19, color: AppColors.onDark)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Hero(),

                // ── Active AutoPay Subscription Card ──
                if (isRecurring && _subStatus?.nextBillingAt != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.inkSurface2,
                      borderRadius: AppRadius.lgAll,
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: AppColors.premiumGradient,
                                borderRadius: AppRadius.pillAll,
                              ),
                              child: Text(
                                'AutoPay सक्रिय',
                                style: AppText.body(size: 12, weight: FontWeight.w800, color: AppColors.ink),
                              ),
                            ),
                            const Spacer(),
                            if (_cancelling)
                              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            else
                              TextButton(
                                onPressed: _confirmCancelAutoPay,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'AutoPay रद्द करें',
                                  style: AppText.body(size: 13, color: AppColors.danger, weight: FontWeight.w700),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'अगला नवीनीकरण: ${_formatDate(_subStatus!.nextBillingAt!)} को ₹99',
                          style: AppText.body(size: 14.5, color: AppColors.onDark, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'आपका प्लान ऑटो-रिन्यूअल पर है। किसी भी समय बंद कर सकते हैं।',
                          style: AppText.body(size: 13, color: AppColors.onDarkMuted),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),
                FadeSlideIn(
                  index: 1,
                  child: _Benefits(items: _benefits),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('अपना प्लान चुनें', style: AppText.heading(size: 19, color: AppColors.onDark)),
                const SizedBox(height: AppSpacing.sm),

                // ── Plan 1: Intro Offer (₹1 for 30 days) ──
                FadeSlideIn(
                  index: 2,
                  child: _IntroOfferCard(
                    selected: _selectedPlan == SelectedPlanType.intro,
                    eligible: introEligible,
                    nextDate: _formatDate(nextRenewalDate),
                    onTap: () {
                      if (introEligible) {
                        setState(() => _selectedPlan = SelectedPlanType.intro);
                      } else {
                        AppSnack.info(context, 'यह ऑफ़र केवल नए उपयोगकर्ताओं के लिए उपलब्ध है।');
                      }
                    },
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // ── Plan 2: 1 Year Plan (₹799) ──
                FadeSlideIn(
                  index: 3,
                  child: _PlanCard(
                    selected: _selectedPlan == SelectedPlanType.annual,
                    title: '1 साल का प्लान',
                    price: '₹$_annualPrice',
                    detail: '$_annualDays दिन • सिर्फ ₹$_perMonthAnnual प्रति माह • एक बार का भुगतान',
                    badge: 'बेस्ट वैल्यू • $_savePercent% बचत',
                    onTap: () => setState(() => _selectedPlan = SelectedPlanType.annual),
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // ── Plan 3: 1 Month Plan (₹99 one-time) ──
                FadeSlideIn(
                  index: 4,
                  child: _PlanCard(
                    selected: _selectedPlan == SelectedPlanType.monthly,
                    title: '1 महीने का प्लान',
                    price: '₹$_monthlyPrice',
                    detail: '$_monthlyDays दिन की वैधता • एक बार का भुगतान',
                    onTap: () => setState(() => _selectedPlan = SelectedPlanType.monthly),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Notice / Disclosure Card
                if (_selectedPlan == SelectedPlanType.intro)
                  const InfoCard(
                    tone: InfoTone.info,
                    title: 'AutoPay रद्दीकरण नीति',
                    message: 'पहले 30 दिन सिर्फ ₹1। इसके बाद ₹99 प्रति माह का ऑटो-रिन्यूअल होगा। आप कभी भी ऐप से एक क्लिक में रद्दीकरण कर सकते हैं।',
                    icon: Icons.autorenew_rounded,
                  )
                else
                  const InfoCard(
                    tone: InfoTone.info,
                    message: 'एक बार का भुगतान — यह प्लान अपने-आप रिन्यू नहीं होता। समाप्ति के बाद आप फ़्री प्लान पर आ जाएंगे।',
                    icon: Icons.event_busy_rounded,
                  ),

                if (_notice != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  InfoCard(
                    tone: _notice!.tone,
                    title: _notice!.title,
                    message: _notice!.message,
                    actionLabel: 'फिर से कोशिश करें',
                    onAction: _isLoading ? null : _initiateCheckout,
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: TextButton.icon(
                    onPressed: _refreshing ? null : _refreshStatus,
                    icon: _refreshing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2))
                        : const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('पहले से भुगतान किया? स्टेटस रिफ्रेश करें'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const _TrustLine(),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.sm + MediaQuery.paddingOf(context).bottom,
            ),
            decoration: const BoxDecoration(
              color: AppColors.inkSurface2,
              boxShadow: AppShadows.bottomDock,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GradientButton(
                  label: _selectedPlan == SelectedPlanType.intro
                      ? '₹1 में शुरू करें (30 दिन)'
                      : (isPremium
                          ? (_selectedPlan == SelectedPlanType.annual ? 'प्लान बढ़ाएं · ₹$_annualPrice' : 'प्लान बढ़ाएं · ₹$_monthlyPrice')
                          : (_selectedPlan == SelectedPlanType.annual ? 'Premium शुरू करें · ₹$_annualPrice' : 'Premium शुरू करें · ₹$_monthlyPrice')),
                  icon: Icons.workspace_premium_rounded,
                  variant: GradientButtonVariant.premium,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _initiateCheckout,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    _selectedPlan == SelectedPlanType.intro
                        ? '30 दिन बाद ₹99/माह AutoPay चार्ज होगा • कभी भी रद्द करें'
                        : (isPremium
                            ? 'आप प्रीमियम सदस्य हैं — नई अवधि बचे हुए दिनों के बाद जुड़ेगी।'
                            : 'सुरक्षित 256-bit एन्क्रिप्शन द्वारा समर्थित'),
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 12.5, color: AppColors.onDarkMuted, height: 1.3),
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

// ─── Intro Offer Card ──────────────────────────────────────────────────────────

class _IntroOfferCard extends StatelessWidget {
  final bool selected;
  final bool eligible;
  final String nextDate;
  final VoidCallback onTap;

  const _IntroOfferCard({
    required this.selected,
    required this.eligible,
    required this.nextDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: PressableScale(
        onTap: onTap,
        haptic: true,
        scale: 0.98,
        semanticLabel: 'विशेष ऑफ़र, पहले 30 दिन सिर्फ ₹1, फिर ₹99 प्रति माह AutoPay',
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.standard,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.inkSurface3 : AppColors.inkSurface2,
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: selected ? AppColors.gold : (eligible ? AppColors.gold.withValues(alpha: 0.35) : AppColors.inkBorder),
              width: selected ? 2.5 : 1.2,
            ),
            boxShadow: selected ? AppShadows.premiumGlow.map((s) => s.scale(0.6)).toList() : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: selected ? AppColors.gold : (eligible ? AppColors.onDarkHint : AppColors.inkBorder),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: eligible ? AppColors.premiumGradient : null,
                            color: eligible ? null : AppColors.inkSurface,
                            borderRadius: AppRadius.pillAll,
                          ),
                          child: Text(
                            eligible ? '🎉 स्पेशल ऑफ़र · केवल नए सदस्यों के लिए' : 'ऑफ़र पहले इस्तेमाल हो चुका है',
                            style: AppText.body(
                              size: 12,
                              weight: FontWeight.w800,
                              color: eligible ? AppColors.ink : AppColors.onDarkMuted,
                              height: 1.3,
                            ),
                          ),
                        ),
                        Text(
                          'पहले 30 दिन सिर्फ ₹1',
                          style: AppText.heading(size: 17.5, color: AppColors.onDark, height: 1.25),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'फिर ₹99/माह — AutoPay से अपने-आप',
                          style: AppText.body(size: 13.5, color: AppColors.onDarkMuted, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹1', style: AppText.heading(size: 28, weight: FontWeight.w800, color: AppColors.gold)),
                      Text('30 दिन', style: AppText.body(size: 12, color: AppColors.onDarkMuted)),
                    ],
                  ),
                ],
              ),
              if (selected) ...[
                const SizedBox(height: AppSpacing.sm),
                const Divider(color: AppColors.inkBorder, height: 1),
                const SizedBox(height: AppSpacing.sm),
                _DisclosureRow(icon: Icons.check_circle_outline_rounded, text: 'पहला भुगतान: सिर्फ ₹1 (आज)'),
                const SizedBox(height: 4),
                _DisclosureRow(icon: Icons.event_repeat_rounded, text: 'अगला नवीनीकरण: $nextDate को ₹99'),
                const SizedBox(height: 4),
                _DisclosureRow(icon: Icons.cancel_outlined, text: 'रद्दीकरण नीति: कभी भी रद्द करें — कोई पेनाल्टी नहीं'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DisclosureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DisclosureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.gold),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppText.body(size: 12.5, color: AppColors.onDarkMuted, height: 1.3),
          ),
        ),
      ],
    );
  }
}

// ─── Standard Plan Card ────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final bool selected;
  final String title;
  final String price;
  final String detail;
  final String? badge;
  final VoidCallback onTap;

  const _PlanCard({
    required this.selected,
    required this.title,
    required this.price,
    required this.detail,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: PressableScale(
        onTap: onTap,
        haptic: true,
        scale: 0.98,
        semanticLabel: '$title, $price, $detail',
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.standard,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.inkSurface3 : AppColors.inkSurface2,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: selected ? AppColors.gold : AppColors.inkBorder, width: selected ? 2.5 : 1.2),
            boxShadow: selected ? AppShadows.premiumGlow.map((s) => s.scale(0.5)).toList() : null,
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? AppColors.gold : AppColors.onDarkHint,
                size: 26,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (badge != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(gradient: AppColors.premiumGradient, borderRadius: AppRadius.pillAll),
                        child: Text(
                          badge!,
                          style: AppText.body(size: 12, weight: FontWeight.w800, color: AppColors.ink, height: 1.3),
                        ),
                      ),
                    Text(title, style: AppText.heading(size: 17, color: AppColors.onDark, height: 1.25)),
                    const SizedBox(height: 2),
                    Text(detail, style: AppText.body(size: 13.5, color: AppColors.onDarkMuted, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(price, style: AppText.heading(size: 25, weight: FontWeight.w800, color: AppColors.gold)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Hero ──────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.premiumGradient,
            boxShadow: AppShadows.premiumGlow,
            border: Border.all(color: AppColors.glassBorder, width: 4),
          ),
          child: const Icon(Icons.workspace_premium_rounded, color: AppColors.ink, size: 54),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Status Go Premium',
          textAlign: TextAlign.center,
          style: AppText.heading(size: 27, weight: FontWeight.w800, color: AppColors.onDark),
        ),
        const SizedBox(height: 6),
        Text(
          'हर दिन अपने नाम और फोटो के साथ शानदार स्टेटस बनाएं',
          textAlign: TextAlign.center,
          style: AppText.body(size: 15.5, color: AppColors.onDarkMuted, height: 1.45),
        ),
      ],
    );
  }
}

// ─── Benefits ──────────────────────────────────────────────────────────────────

class _Benefits extends StatelessWidget {
  final List<(IconData, String, String)> items;
  const _Benefits({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.inkSurface2,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.inkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('प्रीमियम में क्या मिलेगा', style: AppText.heading(size: 17, color: AppColors.onDark)),
          const SizedBox(height: AppSpacing.sm),
          for (final b in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.premiumGradient),
                    child: const Icon(Icons.check_rounded, size: 18, color: AppColors.ink),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.$2, style: AppText.body(size: 15.5, weight: FontWeight.w700, color: AppColors.onDark, height: 1.3)),
                        Text(b.$3, style: AppText.body(size: 13.5, color: AppColors.onDarkMuted, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Trust Line ────────────────────────────────────────────────────────────────

class _TrustLine extends StatelessWidget {
  const _TrustLine();

  @override
  Widget build(BuildContext context) {
    final link = AppText.body(size: 13.5, weight: FontWeight.w700, color: AppColors.primaryLight, height: 1.2);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_rounded, size: 16, color: AppColors.onDarkMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '100% सुरक्षित भुगतान · Razorpay द्वारा',
                textAlign: TextAlign.center,
                style: AppText.body(size: 13, color: AppColors.onDarkMuted, height: 1.3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'UPI AutoPay • कार्ड e-Mandate',
          textAlign: TextAlign.center,
          style: AppText.body(size: 12.5, color: AppColors.onDarkHint, height: 1.3),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: () => context.push('/terms'),
              child: Text('नियम और शर्तें', style: link),
            ),
            Text('•', style: AppText.body(size: 13, color: AppColors.onDarkHint)),
            TextButton(
              onPressed: () => context.push('/refund-policy'),
              child: Text('रिफ़ंड नीति', style: link),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Success Dialog ────────────────────────────────────────────────────────────

class _SuccessDialog extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessDialog({required this.onDone});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Stack(
        children: [
          const Positioned.fill(child: IgnorePointer(child: _Confetti())),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (context, v, child) => Transform.scale(scale: v.clamp(0.0, 1.3), child: child),
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.premiumGradient,
                        boxShadow: AppShadows.premiumGlow,
                      ),
                      child: const Icon(Icons.workspace_premium_rounded, color: AppColors.ink, size: 50),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'प्रीमियम सक्रिय हो गया!',
                  textAlign: TextAlign.center,
                  style: AppText.heading(size: 22, color: p.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'धन्यवाद! अब आप सभी प्रीमियम स्टेटस और फ्रेम इस्तेमाल कर सकते हैं।',
                  textAlign: TextAlign.center,
                  style: AppText.body(size: 15.5, color: p.textSecondary, height: 1.5),
                ),
                const SizedBox(height: AppSpacing.xl),
                GradientButton(
                  label: 'शुरू करें',
                  icon: Icons.arrow_forward_rounded,
                  variant: GradientButtonVariant.premium,
                  onPressed: onDone,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Confetti ──────────────────────────────────────────────────────────────────

class _Confetti extends StatefulWidget {
  const _Confetti();

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
    ..forward();

  static const _colors = [
    AppColors.gold,
    AppColors.accent,
    AppColors.magenta,
    AppColors.primaryLight,
    AppColors.success,
    AppColors.rose,
  ];

  late final List<_Bit> _bits = () {
    final r = math.Random(11);
    return List.generate(
      28,
      (i) => _Bit(
        x: r.nextDouble(),
        delay: r.nextDouble() * 0.35,
        speed: 0.65 + r.nextDouble() * 0.5,
        size: 6 + r.nextDouble() * 6,
        spin: r.nextDouble() * 6,
        drift: (r.nextDouble() - 0.5) * 0.18,
        color: _colors[i % _colors.length],
      ),
    );
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(painter: _ConfettiPainter(_bits, _c.value)),
      ),
    );
  }
}

class _Bit {
  final double x, delay, speed, size, spin, drift;
  final Color color;
  const _Bit({
    required this.x,
    required this.delay,
    required this.speed,
    required this.size,
    required this.spin,
    required this.drift,
    required this.color,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Bit> bits;
  final double t;
  _ConfettiPainter(this.bits, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bits) {
      final local = ((t - b.delay) / (1 - b.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + (size.height + 40) * Curves.easeIn.transform(local) * b.speed;
      final x = size.width * (b.x + b.drift * math.sin(local * math.pi * 3));
      final opacity = local > 0.8 ? (1 - local) / 0.2 : 1.0;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.spin * local * math.pi * 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * 0.55), const Radius.circular(2)),
        Paint()..color = b.color.withValues(alpha: opacity.clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
