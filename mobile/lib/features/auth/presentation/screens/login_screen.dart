// lib/features/auth/presentation/screens/login_screen.dart
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/auth_repository.dart';

// ─── State ───────────────────────────────────────────────────────────────────

enum _LoginStep { phoneEntry, otpVerify }

class _LoginState {
  final _LoginStep step;
  final bool loading;
  final String? error;
  final String phone;
  final String? verificationId;

  const _LoginState({
    this.step = _LoginStep.phoneEntry,
    this.loading = false,
    this.error,
    this.phone = '',
    this.verificationId,
  });

  _LoginState copyWith({
    _LoginStep? step,
    bool? loading,
    String? error,
    String? phone,
    String? verificationId,
  }) =>
      _LoginState(
        step: step ?? this.step,
        loading: loading ?? this.loading,
        error: error,
        phone: phone ?? this.phone,
        verificationId: verificationId ?? this.verificationId,
      );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _otpFocus = FocusNode();

  late final AnimationController _bgController;
  var _state = const _LoginState();

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocus.dispose();
    _otpFocus.dispose();
    _bgController.dispose();
    super.dispose();
  }

  // ── Phone Submit ──────────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    final raw = _phoneController.text.trim().replaceAll(' ', '');
    if (raw.isEmpty) {
      setState(() => _state = _state.copyWith(error: 'Please enter your phone number'));
      return;
    }
    final phone = raw.startsWith('+') ? raw : '+91$raw';

    setState(() => _state = _state.copyWith(loading: true, error: null));

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verified (SMS Retriever on Android)
        await _signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _state = _state.copyWith(
          loading: false,
          error: e.message ?? 'Verification failed. Please try again.',
        ));
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() => _state = _state.copyWith(
          step: _LoginStep.otpVerify,
          loading: false,
          phone: phone,
          verificationId: verificationId,
        ));
        Future.delayed(const Duration(milliseconds: 300), () {
          _otpFocus.requestFocus();
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Keep the verification ID updated
        setState(() => _state = _state.copyWith(verificationId: verificationId));
      },
    );
  }

  // ── OTP Submit ────────────────────────────────────────────────────────────

  Future<void> _verifyOtp(String otp) async {
    if (otp.length < 6) return;
    if (_state.verificationId == null) return;

    setState(() => _state = _state.copyWith(loading: true, error: null));

    final credential = PhoneAuthProvider.credential(
      verificationId: _state.verificationId!,
      smsCode: otp,
    );
    await _signInWithCredential(credential);
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null) throw Exception('Could not get ID token');

      final result = await ref
          .read(authRepositoryProvider)
          .signInWithFirebaseToken(idToken);

      if (!mounted) return;

      if (result['onboardingRequired'] == true) {
        context.go('/profile-setup');
      } else {
        context.go('/home');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _state = _state.copyWith(
        loading: false,
        error: e.message ?? 'Invalid OTP. Please try again.',
      ));
    } catch (e) {
      setState(() => _state = _state.copyWith(
        loading: false,
        error: 'Something went wrong. Please try again.',
      ));
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    setState(() => _state = _state.copyWith(loading: true, error: null));
    try {
      final result = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (!mounted) return;
      if (result == null) {
        setState(() => _state = _state.copyWith(loading: false));
        return;
      }
      context.go('/home');
    } catch (e) {
      setState(() => _state = _state.copyWith(
        loading: false,
        error: 'Google sign-in failed. Please try again.',
      ));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Stack(
        children: [
          // ── Animated gradient background ────────────────────────────────
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) => Positioned.fill(
              child: CustomPaint(
                painter: _GradientBgPainter(_bgController.value),
              ),
            ),
          ),

          // ── Frosted glass content ─────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: size.height - 120),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),

                    // Logo + tagline
                    FadeInDown(
                      duration: const Duration(milliseconds: 700),
                      child: _buildLogoSection(),
                    ),

                    const SizedBox(height: 48),

                    // Card
                    FadeInUp(
                      duration: const Duration(milliseconds: 800),
                      delay: const Duration(milliseconds: 200),
                      child: _buildCard(),
                    ),

                    const SizedBox(height: 32),

                    // Google sign in
                    if (_state.step == _LoginStep.phoneEntry)
                      FadeInUp(
                        duration: const Duration(milliseconds: 700),
                        delay: const Duration(milliseconds: 400),
                        child: _buildGoogleButton(),
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.brandGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 16),
        Text(
          'Status Go',
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'स्टेटस गो — Daily Status for Every Occasion',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: Colors.white.withOpacity(0.5),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: _state.step == _LoginStep.phoneEntry
                ? _buildPhoneStep()
                : _buildOtpStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome Back 👋',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter your phone number to continue',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 24),

        // Phone input
        _FieldLabel('PHONE NUMBER'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              // Country code badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.white.withOpacity(0.12))),
                ),
                child: Text(
                  '🇮🇳  +91',
                  style: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  focusNode: _phoneFocus,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  onSubmitted: (_) => _sendOtp(),
                  decoration: InputDecoration(
                    hintText: '98765 43210',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_state.error != null) ...[
          const SizedBox(height: 12),
          _ErrorText(_state.error!),
        ],

        const SizedBox(height: 24),

        _PremiumButton(
          text: 'Send OTP',
          loading: _state.loading,
          onPressed: _sendOtp,
          icon: Icons.send_rounded,
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    final defaultPinTheme = PinTheme(
      width: 52,
      height: 56,
      textStyle: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
    );

    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _state = _state.copyWith(
                    step: _LoginStep.phoneEntry,
                    error: null,
                  )),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 16),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verify OTP 🔐',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Sent to ${_state.phone}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.45),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 28),

        Center(
          child: Pinput(
            controller: _otpController,
            focusNode: _otpFocus,
            length: 6,
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: defaultPinTheme.copyWith(
              decoration: defaultPinTheme.decoration!.copyWith(
                border: Border.all(color: AppColors.primary, width: 2),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8),
                ],
              ),
            ),
            submittedPinTheme: defaultPinTheme.copyWith(
              decoration: defaultPinTheme.decoration!.copyWith(
                color: AppColors.primary.withOpacity(0.2),
                border: Border.all(color: AppColors.primary.withOpacity(0.5)),
              ),
            ),
            onCompleted: _verifyOtp,
            hapticFeedbackType: HapticFeedbackType.lightImpact,
            keyboardType: TextInputType.number,
            closeKeyboardWhenCompleted: true,
          ),
        ),

        if (_state.error != null) ...[
          const SizedBox(height: 16),
          _ErrorText(_state.error!),
        ],

        const SizedBox(height: 28),

        _PremiumButton(
          text: 'Verify OTP',
          loading: _state.loading,
          onPressed: () => _verifyOtp(_otpController.text),
          icon: Icons.verified_rounded,
        ),

        const SizedBox(height: 16),

        Center(
          child: TextButton(
            onPressed: _state.loading ? null : _sendOtp,
            child: Text(
              'Resend OTP',
              style: GoogleFonts.outfit(
                color: AppColors.accent.withOpacity(0.8),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return GestureDetector(
      onTap: _state.loading ? null : _signInWithGoogle,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
              width: 22,
              height: 22,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.g_mobiledata, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: GoogleFonts.outfit(
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Custom Painter ───────────────────────────────────────────────────────────

class _GradientBgPainter extends CustomPainter {
  final double progress;
  _GradientBgPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = AppColors.primary.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    final paint2 = Paint()
      ..color = AppColors.secondary.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.2 + size.height * 0.1 * progress),
      180,
      paint1,
    );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.65 - size.height * 0.08 * progress),
      220,
      paint2,
    );
  }

  @override
  bool shouldRepaint(_GradientBgPainter old) => old.progress != progress;
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white.withOpacity(0.35),
          letterSpacing: 1.5,
        ),
      );
}

class _ErrorText extends StatelessWidget {
  final String text;
  const _ErrorText(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFF4D4D).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFF4D4D).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFFF4D4D), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.outfit(
                  color: const Color(0xFFFF4D4D),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _PremiumButton extends StatelessWidget {
  final String text;
  final bool loading;
  final VoidCallback? onPressed;
  final IconData? icon;

  const _PremiumButton({
    required this.text,
    required this.loading,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: loading ? null : AppColors.brandGradient,
        color: loading ? Colors.white.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: loading
            ? []
            : [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
