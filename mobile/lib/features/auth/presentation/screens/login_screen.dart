// lib/features/auth/presentation/screens/login_screen.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../legal/presentation/widgets/legal_consent_text.dart';
import '../../data/auth_repository.dart';
import '../../data/sms_otp_retriever.dart';

// ─── State ────────────────────────────────────────────────────────────────────

enum _Step { phone, otp }

class _State {
  final _Step step;
  final bool loading;
  final bool googleLoading;

  /// Inline validation message under the phone field.
  final String? error;
  final String phone;
  final String? verificationId;
  final bool isBackendFallback;
  final int resendCountdown;

  /// OTP echoed by the backend in test-OTP mode (development only).
  final String? devOtp;

  const _State({
    this.step = _Step.phone,
    this.loading = false,
    this.googleLoading = false,
    this.error,
    this.phone = '',
    this.verificationId,
    this.isBackendFallback = false,
    this.resendCountdown = 0,
    this.devOtp,
  });

  _State copyWith({
    _Step? step,
    bool? loading,
    bool? googleLoading,
    String? error,
    bool clearError = false,
    String? phone,
    String? verificationId,
    bool? isBackendFallback,
    int? resendCountdown,
    String? devOtp,
    bool clearDevOtp = false,
  }) =>
      _State(
        step: step ?? this.step,
        loading: loading ?? this.loading,
        googleLoading: googleLoading ?? this.googleLoading,
        error: clearError ? null : (error ?? this.error),
        phone: phone ?? this.phone,
        verificationId: verificationId ?? this.verificationId,
        isBackendFallback: isBackendFallback ?? this.isBackendFallback,
        resendCountdown: resendCountdown ?? this.resendCountdown,
        devOtp: clearDevOtp ? null : (devOtp ?? this.devOtp),
      );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with TickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _phoneFocus = FocusNode();
  final _otpFocus = FocusNode();
  final _smsRetriever = SmsOtpRetriever();
  late final AnimationController _float;
  late final AnimationController _shake;
  var _state = const _State();
  bool _otpError = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _phoneFocus.addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _float.dispose();
    _shake.dispose();
    _phoneFocus.removeListener(_onFocus);
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _phoneFocus.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _state = _state.copyWith(resendCountdown: 30));
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_state.resendCountdown <= 1) {
        timer.cancel();
        setState(() => _state = _state.copyWith(resendCountdown: 0));
      } else {
        setState(() => _state = _state.copyWith(resendCountdown: _state.resendCountdown - 1));
      }
    });
  }

  // ── Send OTP via backend ──────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    if (_state.loading) return;
    final raw = _phoneCtrl.text.trim().replaceAll(' ', '');
    if (raw.length != 10) {
      setState(() => _state = _state.copyWith(error: 'कृपया 10 अंकों का सही मोबाइल नंबर डालें'));
      return;
    }
    final phone = raw.startsWith('+') ? raw : '+91$raw';
    FocusScope.of(context).unfocus();
    setState(() => _state = _state.copyWith(loading: true, clearError: true));
    await _sendBackendOtp(phone);
  }

  Future<void> _resendOtp() async {
    if (_state.loading || _state.phone.isEmpty) return;
    setState(() => _state = _state.copyWith(loading: true, clearError: true));
    await _sendBackendOtp(_state.phone);
  }

  Future<void> _sendBackendOtp(String phone) async {
    try {
      await ref.read(authRepositoryProvider).sendOtp(phone);
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _state.copyWith(loading: false));
      AppSnack.error(context, apiErrorMessage(e, fallback: 'OTP भेजा नहीं जा सका। कृपया पुनः प्रयास करें।'));
      return;
    }
    if (!mounted) return;
    _otpCtrl.clear();
    setState(() {
      _otpError = false;
      _state = _state.copyWith(
        step: _Step.otp,
        loading: false,
        phone: phone,
        verificationId: 'BACKEND_OTP',
        isBackendFallback: true,
        clearError: true,
        clearDevOtp: true,
      );
    });
    _startCountdown();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted && _state.step == _Step.otp) _otpFocus.requestFocus();
    });
  }

  // ── Verify OTP ────────────────────────────────────────────────────────────

  Future<void> _verifyOtp(String otp) async {
    if (otp.length < 6 || _state.loading) return;
    setState(() => _state = _state.copyWith(loading: true, clearError: true));
    await _signInWithBackendOtp(otp);
  }

  Future<void> _signInWithBackendOtp(String otp) async {
    try {
      final result = await ref.read(authRepositoryProvider).verifyOtp(_state.phone, otp);
      if (!mounted) return;
      _goAfterLogin(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _otpError = true;
        _state = _state.copyWith(loading: false);
      });
      _otpCtrl.clear();
      _otpFocus.requestFocus();
      _shake.forward(from: 0);
      HapticFeedback.mediumImpact();
      AppSnack.error(context, apiErrorMessage(e, fallback: 'OTP अमान्य है। कृपया सही 6 अंकों का OTP दर्ज करें।'));
    }
  }

  /// Same onboarding check for every login method.
  void _goAfterLogin(AuthResult result) {
    if (result.onboardingRequired) {
      context.go('/profile-setup');
    } else {
      context.go('/home');
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    if (_state.loading || _state.googleLoading) return;
    setState(() => _state = _state.copyWith(googleLoading: true, clearError: true));
    try {
      final result = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (!mounted) return;
      if (result != null) {
        _goAfterLogin(result);
      } else {
        setState(() => _state = _state.copyWith(googleLoading: false));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _state.copyWith(googleLoading: false));
      AppSnack.error(context, apiErrorMessage(e, fallback: 'Google Sign-In में समस्या हुई।'));
    }
  }

  void _changeNumber() {
    _countdownTimer?.cancel();
    _otpCtrl.clear();
    setState(() {
      _otpError = false;
      _state = _state.copyWith(step: _Step.phone, clearError: true, resendCountdown: 0);
    });
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted && _state.step == _Step.phone) _phoneFocus.requestFocus();
    });
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.primaryDark,
        resizeToAvoidBottomInset: true,
        body: LayoutBuilder(
          builder: (context, c) {
            final compact = c.maxHeight < 560;
            final heroH = compact ? 132.0 : (c.maxHeight * 0.40).clamp(250.0, 360.0);
            return Stack(
              children: [
                // Hero
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedContainer(
                    duration: AppMotion.normal,
                    curve: AppMotion.standard,
                    height: heroH,
                    child: _Hero(animation: _float, showCards: !compact),
                  ),
                ),
                // Bottom sheet panel
                AnimatedPositioned(
                  duration: AppMotion.normal,
                  curve: AppMotion.standard,
                  top: heroH - 28,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
                      boxShadow: AppShadows.bottomDock,
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
                      child: SafeArea(
                        top: false,
                        child: SingleChildScrollView(
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xl, AppSpacing.page, AppSpacing.xl),
                          child: AnimatedSwitcher(
                            duration: AppMotion.normal,
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(anim),
                                child: child,
                              ),
                            ),
                            child: _state.step == _Step.phone
                                ? _buildPhoneStep(p)
                                : _buildOtpStep(p),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPhoneStep(AppPalette p) {
    final focused = _phoneFocus.hasFocus;
    final hasError = _state.error != null;
    final borderColor = hasError ? AppColors.danger : (focused ? p.primary : p.border);
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('लॉगिन / साइन अप', style: AppText.heading(size: 24, color: p.textPrimary)),
        const SizedBox(height: 4),
        Text(
          'अपने मोबाइल नंबर से सुरक्षित लॉगिन करें',
          style: AppText.body(size: 15, color: p.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'मोबाइल नंबर (Mobile Number)',
            style: AppText.body(size: 14.5, weight: FontWeight.w700, color: p.textPrimary, height: 1.2),
          ),
        ),
        AnimatedContainer(
          duration: AppMotion.fast,
          constraints: const BoxConstraints(minHeight: 60),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: borderColor, width: focused || hasError ? 2 : 1.4),
          ),
          child: Row(
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 60),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: p.surfaceMuted,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppRadius.md - 2)),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🇮🇳', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 6),
                    Text('+91', style: AppText.body(size: 17, weight: FontWeight.w700, color: p.textPrimary)),
                  ],
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  focusNode: _phoneFocus,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  cursorColor: p.primary,
                  style: AppText.body(size: 20, weight: FontWeight.w700, color: p.textPrimary, letterSpacing: 1),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  onChanged: (_) {
                    if (_state.error != null) {
                      setState(() => _state = _state.copyWith(clearError: true));
                    } else {
                      setState(() {});
                    }
                  },
                  onSubmitted: (_) => _sendOtp(),
                  decoration: InputDecoration(
                    hintText: '98765 43210',
                    hintStyle: AppText.body(size: 18, color: p.textHint),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    suffixIcon: _phoneCtrl.text.length == 10
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: AppMotion.fast,
          alignment: Alignment.topCenter,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _state.error!,
                          style: AppText.body(size: 13.5, weight: FontWeight.w600, color: AppColors.danger, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: AppSpacing.lg),
        GradientButton(
          label: 'OTP भेजें',
          icon: Icons.sms_rounded,
          isLoading: _state.loading,
          onPressed: _state.googleLoading ? null : _sendOtp,
        ),
        const SizedBox(height: AppSpacing.lg),
        const _OrDivider(),
        const SizedBox(height: AppSpacing.lg),
        _GoogleButton(
          loading: _state.googleLoading,
          onPressed: _state.loading ? null : _signInWithGoogle,
        ),
        const SizedBox(height: AppSpacing.lg),
        const LegalConsentText(),
      ],
    );
  }

  Widget _buildOtpStep(AppPalette p) {
    final mask = _state.phone.startsWith('+91') && _state.phone.length == 13
        ? '+91 ${_state.phone.substring(3, 8)} ${_state.phone.substring(8)}'
        : _state.phone;
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('OTP दर्ज करें', style: AppText.heading(size: 24, color: p.textPrimary)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: AppText.body(size: 15, color: p.textMuted),
                  children: [
                    const TextSpan(text: '6 अंकों का OTP भेजा गया: '),
                    TextSpan(
                      text: mask,
                      style: AppText.body(size: 15, weight: FontWeight.w700, color: p.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _state.loading ? null : _changeNumber,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('बदलें'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        LayoutBuilder(
          builder: (context, c) {
            const gap = 8.0;
            final boxW = ((c.maxWidth - gap * 5) / 6).clamp(38.0, 54.0);
            final base = BoxDecoration(
              color: p.surface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: p.border, width: 1.6),
            );
            final pin = PinTheme(
              width: boxW,
              height: 60,
              textStyle: AppText.heading(size: 24, color: p.textPrimary, height: 1.1),
              decoration: base,
            );
            return AnimatedBuilder(
              animation: _shake,
              builder: (context, child) {
                final t = _shake.value;
                final dx = math.sin(t * math.pi * 5) * 10 * (1 - t);
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: Semantics(
                label: 'OTP दर्ज करें (6 अंक)',
                child: Pinput(
                  controller: _otpCtrl,
                  focusNode: _otpFocus,
                  length: 6,
                  autofocus: false,
                  forceErrorState: _otpError,
                  defaultPinTheme: pin,
                  focusedPinTheme: pin.copyWith(
                    decoration: base.copyWith(border: Border.all(color: p.primary, width: 2.4)),
                  ),
                  submittedPinTheme: pin.copyWith(
                    decoration: base.copyWith(
                      color: p.primarySurface,
                      border: Border.all(color: p.primary, width: 1.8),
                    ),
                  ),
                  errorPinTheme: pin.copyWith(
                    decoration: base.copyWith(
                      color: AppColors.dangerSurface,
                      border: Border.all(color: AppColors.danger, width: 2),
                    ),
                    textStyle: AppText.heading(size: 24, color: AppColors.danger, height: 1.1),
                  ),
                  separatorBuilder: (_) => const SizedBox(width: gap),
                  mainAxisAlignment: MainAxisAlignment.center,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  // Android: SMS User Consent API (no READ_SMS permission; system prompt asks once).
                  // iOS: oneTimeCode autofill hint surfaces the code above the keyboard.
                  smsRetriever: defaultTargetPlatform == TargetPlatform.android ? _smsRetriever : null,
                  hapticFeedbackType: HapticFeedbackType.lightImpact,
                  onChanged: (_) {
                    if (_otpError) setState(() => _otpError = false);
                  },
                  onCompleted: _verifyOtp,
                ),
              ),
            );
          },
        ),
        AnimatedSize(
          duration: AppMotion.fast,
          alignment: Alignment.topCenter,
          child: _otpError
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'OTP सही नहीं है। दोबारा डालें।',
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.danger),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: AppSpacing.xl),
        GradientButton(
          label: 'OTP सत्यापित करें',
          icon: Icons.verified_user_rounded,
          isLoading: _state.loading,
          onPressed: () => _verifyOtp(_otpCtrl.text),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: _state.resendCountdown > 0
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'दोबारा OTP भेजें  0:${_state.resendCountdown.toString().padLeft(2, '0')}',
                    style: AppText.body(size: 15, weight: FontWeight.w600, color: p.textMuted),
                  ),
                )
              : TextButton.icon(
                  onPressed: _state.loading ? null : _resendOtp,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('OTP दोबारा भेजें'),
                ),
        ),
      ],
    );
  }

}

// ─── Hero ─────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final Animation<double> animation;
  final bool showCards;
  const _Hero({required this.animation, required this.showCards});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppLogo(size: 40, showWordmark: true, horizontal: true, wordmarkColor: AppColors.white),
              Expanded(
                child: AnimatedOpacity(
                  duration: AppMotion.normal,
                  opacity: showCards ? 1 : 0,
                  child: showCards
                      ? LayoutBuilder(
                          builder: (context, c) => ExcludeSemantics(
                            child: _FloatingCards(animation: animation, width: c.maxWidth, height: c.maxHeight),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardSpec {
  final Gradient gradient;
  final IconData icon;
  final String label;
  final Color fg;
  const _CardSpec(this.gradient, this.icon, this.label, this.fg);
}

const _cardSpecs = <_CardSpec>[
  _CardSpec(AppColors.festivalGradient, Icons.celebration_rounded, 'शुभ दीपावली', AppColors.white),
  _CardSpec(AppColors.premiumGradient, Icons.wb_sunny_rounded, 'सुप्रभात', AppColors.ink),
  _CardSpec(
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.rose, AppColors.magenta],
    ),
    Icons.favorite_rounded,
    'शुभ रात्रि',
    AppColors.white,
  ),
];

class _FloatingCards extends StatelessWidget {
  final Animation<double> animation;
  final double width;
  final double height;
  const _FloatingCards({required this.animation, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final centerW = math.min(width * 0.34, (height - 14) / 1.3).clamp(60.0, 130.0);
    final sideW = centerW * 0.82;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        double bob(double phase, double amp) => math.sin((animation.value + phase) * math.pi * 2) * amp;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: width * 0.04,
              top: height * 0.22 + bob(0.0, 5),
              child: Transform.rotate(
                angle: -0.14,
                child: _SampleCard(spec: _cardSpecs[0], width: sideW),
              ),
            ),
            Positioned(
              right: width * 0.04,
              top: height * 0.28 + bob(0.5, 6),
              child: Transform.rotate(
                angle: 0.14,
                child: _SampleCard(spec: _cardSpecs[2], width: sideW),
              ),
            ),
            Positioned(
              left: (width - centerW) / 2,
              top: 2 + bob(0.25, 9),
              child: _SampleCard(spec: _cardSpecs[1], width: centerW, elevated: true),
            ),
          ],
        );
      },
    );
  }
}

/// Decorative template card built only from gradients + icons.
class _SampleCard extends StatelessWidget {
  final _CardSpec spec;
  final double width;
  final bool elevated;
  const _SampleCard({required this.spec, required this.width, this.elevated = false});

  @override
  Widget build(BuildContext context) {
    final h = width * 1.3;
    return Container(
      width: width,
      height: h,
      padding: EdgeInsets.all(width * 0.08),
      decoration: BoxDecoration(
        gradient: spec.gradient,
        borderRadius: BorderRadius.circular(width * 0.16),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.5), width: 1.5),
        boxShadow: elevated ? AppShadows.floating : AppShadows.card,
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: FittedBox(
                child: Icon(spec.icon, size: width * 0.42, color: spec.fg),
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              spec.label,
              style: AppText.heading(size: width * 0.13, color: spec.fg, height: 1.1),
            ),
          ),
          SizedBox(height: width * 0.07),
          // Mock "name strip" like on a real status.
          Container(
            height: width * 0.2,
            padding: EdgeInsets.symmetric(horizontal: width * 0.04),
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(width * 0.1),
            ),
            child: Row(
              children: [
                Container(
                  width: width * 0.13,
                  height: width * 0.13,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.white),
                ),
                SizedBox(width: width * 0.04),
                Expanded(
                  child: Container(
                    height: width * 0.04,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(width),
                    ),
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

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Expanded(child: Divider(color: p.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('या', style: AppText.body(size: 14.5, weight: FontWeight.w600, color: p.textMuted)),
        ),
        Expanded(child: Divider(color: p.border)),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onPressed;
  const _GoogleButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onPressed != null && !loading;
    return PressableScale(
      onTap: enabled ? onPressed : null,
      semanticLabel: 'Google से लॉगिन करें',
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: AppRadius.pillAll,
          border: Border.all(color: p.isDark ? AppColors.white : p.border, width: 1.4),
          boxShadow: AppShadows.subtle,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.primary),
              )
            else ...[
              const SizedBox(width: 22, height: 22, child: CustomPaint(painter: _GoogleGPainter())),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Google से लॉगिन करें',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(
                    size: 16.5,
                    weight: FontWeight.w700,
                    color: enabled ? AppColors.ink : AppColors.textHint,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Google "G" mark. These four are Google's official brand colours (third-party
/// trademark, intentionally not part of the Status Go palette).
class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final r = size.width / 2 - stroke / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: r);
    double rad(double deg) => deg * math.pi / 180;

    Paint ring(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, rad(205), rad(110), false, ring(_red));
    canvas.drawArc(rect, rad(145), rad(60), false, ring(_yellow));
    canvas.drawArc(rect, rad(45), rad(100), false, ring(_green));
    canvas.drawArc(rect, rad(0), rad(45), false, ring(_blue));
    canvas.drawRect(
      Rect.fromLTRB(center.dx, center.dy - stroke / 2, size.width - 0.5, center.dy + stroke / 2),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
