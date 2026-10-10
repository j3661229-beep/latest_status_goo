// lib/features/premium/data/subscription_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
});

class SubscriptionStatus {
  final String plan;
  final DateTime? expiresAt;
  final int? daysRemaining;
  final bool isRecurring;
  final DateTime? nextBillingAt;
  final int recurringAmount;
  final String? rzpSubId;
  final bool introEligible;

  const SubscriptionStatus({
    required this.plan,
    this.expiresAt,
    this.daysRemaining,
    required this.isRecurring,
    this.nextBillingAt,
    this.recurringAmount = 9900,
    this.rzpSubId,
    this.introEligible = false,
  });

  bool get isPremium => plan == 'PREMIUM' || plan == 'ANNUAL';

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      plan: json['plan'] as String? ?? 'FREE',
      expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt'] as String) : null,
      daysRemaining: json['daysRemaining'] as int?,
      isRecurring: json['isRecurring'] as bool? ?? false,
      nextBillingAt: json['nextBillingAt'] != null ? DateTime.tryParse(json['nextBillingAt'] as String) : null,
      recurringAmount: (json['recurringAmount'] as num?)?.toInt() ?? 9900,
      rzpSubId: json['rzpSubId'] as String?,
      introEligible: json['introEligible'] as bool? ?? false,
    );
  }
}

class IntroCheckoutData {
  final String subscriptionId;
  final int upfrontAmount;
  final String upfrontAmountDisplay;
  final DateTime firstRenewalAt;
  final int recurringAmount;
  final String recurringAmountDisplay;
  final String keyId;
  final String? shortUrl;

  const IntroCheckoutData({
    required this.subscriptionId,
    required this.upfrontAmount,
    required this.upfrontAmountDisplay,
    required this.firstRenewalAt,
    required this.recurringAmount,
    required this.recurringAmountDisplay,
    required this.keyId,
    this.shortUrl,
  });

  factory IntroCheckoutData.fromJson(Map<String, dynamic> json) {
    final renewalStr = json['firstRenewalAt'] as String?;
    return IntroCheckoutData(
      subscriptionId: json['subscriptionId'] as String? ?? '',
      upfrontAmount: (json['upfrontAmount'] as num?)?.toInt() ?? 100,
      upfrontAmountDisplay: json['upfrontAmountDisplay'] as String? ?? '₹1',
      firstRenewalAt: renewalStr != null ? (DateTime.tryParse(renewalStr) ?? DateTime.now().add(const Duration(days: 30))) : DateTime.now().add(const Duration(days: 30)),
      recurringAmount: (json['recurringAmount'] as num?)?.toInt() ?? 9900,
      recurringAmountDisplay: json['recurringAmountDisplay'] as String? ?? '₹99/माह',
      keyId: json['keyId'] as String? ?? '',
      shortUrl: json['shortUrl'] as String?,
    );
  }
}

class SubscriptionRepository {
  SubscriptionRepository({Dio? api}) : _api = api ?? apiClient;

  final Dio _api;

  /// Fetch user subscription status including recurring details and intro eligibility.
  Future<SubscriptionStatus> fetchStatus() async {
    try {
      final res = await _api.get('/subscribe/status');
      final data = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : Map<String, dynamic>.from(res.data as Map);
      return SubscriptionStatus.fromJson(data);
    } catch (e) {
      throw ApiException(apiErrorMessage(e, fallback: 'सब्सक्रिप्शन स्थिति प्राप्त करने में समस्या आई।'));
    }
  }

  /// Create or resume a ₹1 intro subscription for AutoPay.
  Future<IntroCheckoutData> createIntroSubscription() async {
    try {
      final res = await _api.post('/subscribe/intro/create');
      final data = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : Map<String, dynamic>.from(res.data as Map);
      return IntroCheckoutData.fromJson(data);
    } catch (e) {
      throw ApiException(apiErrorMessage(e, fallback: 'ऑफर शुरू करने में समस्या आई।'));
    }
  }

  /// Verify ₹1 upfront subscription authentication callback from Razorpay.
  Future<Map<String, dynamic>> verifyIntroSubscription({
    required String subscriptionId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final res = await _api.post('/subscribe/intro/verify', data: {
        'razorpaySubscriptionId': subscriptionId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
      });
      return res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      throw ApiException(apiErrorMessage(e, fallback: 'ऑफर वेरिफिकेशन विफल रहा।'));
    }
  }

  /// Create a one-time order (₹99 monthly or ₹799 annual fallback).
  Future<Map<String, dynamic>> createOneTimeOrder({required String plan}) async {
    try {
      final res = await _api.post('/subscribe/create', data: {'plan': plan});
      return res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      throw ApiException(apiErrorMessage(e, fallback: 'ऑर्डर नहीं बन सका।'));
    }
  }

  /// Verify a one-time order payment.
  Future<void> verifyOneTimeOrder({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      await _api.post('/subscribe/verify', data: {
        'razorpayOrderId': orderId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      });
    } catch (e) {
      throw ApiException(apiErrorMessage(e, fallback: 'भुगतान पुष्टि नहीं हो सकी।'));
    }
  }

  /// Cancel recurring subscription at cycle end.
  Future<String> cancelSubscription({bool cancelAtCycleEnd = true}) async {
    try {
      final res = await _api.post('/subscribe/cancel', data: {
        'cancelAtCycleEnd': cancelAtCycleEnd,
      });
      final data = res.data is Map ? res.data as Map : const {};
      return (data['message'] as String?) ?? 'Subscription सफलतापूर्वक रद्द कर दिया गया।';
    } catch (e) {
      throw ApiException(apiErrorMessage(e, fallback: 'सब्स्क्रिप्शन रद्द नहीं हो सका।'));
    }
  }
}
