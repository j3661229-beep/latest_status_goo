// lib/features/auth/presentation/screens/login_screen.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/auth_repository.dart';

// ─── State ────────────────────────────────────────────────────────────────────

enum _Step { phone, otp }

class _State {
  final _Step step;
  final bool loading;
  final String? error;
  final String phone;
  final String? verificationId;
  final bool isBackendFallback;
  final int resendCountdown;

  const _State({
    this.step = _Step.phone,
    this.loading = false,
    this.error,
    this.phone = '',
    this.verificationId,
    this.isBackendFallback = false,
    this.resendCountdown = 0,
  });

  _State copyWith({
    _Step? step,
    bool? loading,
    String? error,
    bool clearError = false,
    String? phone,
    String? verificationId,
    bool? isBackendFallback,
    int? resendCountdown,
  }) =>
      _State(
        step: step ?? this.step,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        phone: phone ?? this.phone,
        verificationId: verificationId ?? this.verificationId,
        isBackendFallback: isBackendFallback ?? this.isBackendFallback,
        resendCountdown: resendCountdown ?? this.resendCountdown,
      );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _phoneFocus = FocusNode();
  final _otpFocus = FocusNode();
  var _state = const _State();
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
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

  // ── Send OTP via Firebase with Backend Fallback ───────────────────────────

  Future<void> _sendOtp() async {
    final raw = _phoneCtrl.text.trim().replaceAll(' ', '');
    if (raw.length < 10) {
      setState(() => _state = _state.copyWith(error: 'कृपया 10 अंकों का मोबाइल नंबर डालें'));
      return;
    }
    final phone = raw.startsWith('+') ? raw : '+91$raw';
    setState(() => _state = _state.copyWith(loading: true, clearError: true));

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential cred) async {
          await _signInWithFirebase(cred);
        },
        verificationFailed: (FirebaseAuthException e) async {
          debugPrint('Firebase phone verification failed (${e.code}: ${e.message}). Falling back to backend OTP...');
          await _sendBackendOtp(phone, fallbackReason: e.message);
        },
        codeSent: (String vid, int? resendToken) {
          if (!mounted) return;
          setState(() => _state = _state.copyWith(
                step: _Step.otp,
                loading: false,
                phone: phone,
                verificationId: vid,
                isBackendFallback: false,
              ));
          _startCountdown();
          Future.delayed(const Duration(milliseconds: 300), _otpFocus.requestFocus);
        },
        codeAutoRetrievalTimeout: (String vid) {
          if (mounted) setState(() => _state = _state.copyWith(verificationId: vid));
        },
      );
    } catch (e) {
      debugPrint('Direct Firebase verify error: $e. Using backend OTP...');
      await _sendBackendOtp(phone, fallbackReason: null);
    }
  }

  Future<void> _sendBackendOtp(String phone, {String? fallbackReason}) async {
    try {
      await ref.read(authRepositoryProvider).sendOtp(phone);
      if (!mounted) return;
      setState(() => _state = _state.copyWith(
            step: _Step.otp,
            loading: false,
            phone: phone,
            verificationId: 'BACKEND_OTP',
            isBackendFallback: true,
          ));
      _startCountdown();
      Future.delayed(const Duration(milliseconds: 300), _otpFocus.requestFocus);
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _state.copyWith(
            loading: false,
            error: 'OTP भेजने में समस्या हुई। कृपया पुनः प्रयास करें।',
          ));
    }
  }

  // ── Verify OTP ────────────────────────────────────────────────────────────

  Future<void> _verifyOtp(String otp) async {
    if (otp.length < 6) return;
    setState(() => _state = _state.copyWith(loading: true, clearError: true));

    if (_state.isBackendFallback || _state.verificationId == 'BACKEND_OTP') {
      await _signInWithBackendOtp(otp);
      return;
    }

    // Try Firebase credential first
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _state.verificationId ?? '',
        smsCode: otp,
      );
      await _signInWithFirebase(cred);
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase verify failed: ${e.message}. Trying backend fallback...');
      // If Firebase verification fails, also attempt backend verify
      await _signInWithBackendOtp(otp);
    } catch (e) {
      await _signInWithBackendOtp(otp);
    }
  }

  Future<void> _signInWithFirebase(PhoneAuthCredential cred) async {
    try {
      final uc = await FirebaseAuth.instance.signInWithCredential(cred);
      final idToken = await uc.user?.getIdToken();
      if (idToken == null) throw Exception('Token not found');

      final result = await ref
          .read(authRepositoryProvider)
          .signInWithFirebaseToken(idToken);

      if (!mounted) return;
      if (result['onboardingRequired'] == true) {
        context.go('/profile-setup');
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _state.copyWith(
            loading: false,
            error: 'OTP गलत है या एक्सपायर हो गया है। दोबारा कोशिश करें।',
          ));
    }
  }

  Future<void> _signInWithBackendOtp(String otp) async {
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .verifyOtp(_state.phone, otp);

      if (!mounted) return;
      if (result['onboardingRequired'] == true) {
        context.go('/profile-setup');
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _state.copyWith(
            loading: false,
            error: 'OTP अमान्य है। कृपया सही 6 अंकों का OTP दर्ज करें।',
          ));
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    setState(() => _state = _state.copyWith(loading: true, clearError: true));
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (!mounted) return;
      if (user != null) {
        context.go('/home');
      } else {
        setState(() => _state = _state.copyWith(loading: false));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _state.copyWith(
            loading: false,
            error: 'Google Sign-In में समस्या हुई।',
          ));
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              _buildHeader(),
              const SizedBox(height: 36),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _state.step == _Step.phone
                    ? _buildPhoneStep()
                    : _buildOtpStep(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.15)),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.primary,
            size: 42,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Status Go',
          textAlign: TextAlign.center,
          style: GoogleFonts.hind(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'अपने मोबाइल नंबर से सुरक्षित लॉगिन करें',
          textAlign: TextAlign.center,
          style: GoogleFonts.hind(fontSize: 16, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'मोबाइल नंबर (Mobile Number)',
          style: GoogleFonts.hind(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
            borderRadius: BorderRadius.circular(10),
            color: AppColors.surface,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(9),
                    bottomLeft: Radius.circular(9),
                  ),
                  border: const Border(
                    right: BorderSide(color: AppColors.surfaceBorder, width: 1.5),
                  ),
                ),
                child: Text(
                  '🇮🇳 +91',
                  style: GoogleFonts.hind(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  focusNode: _phoneFocus,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.hind(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  onSubmitted: (_) => _sendOtp(),
                  decoration: InputDecoration(
                    hintText: '98765 43210',
                    hintStyle: GoogleFonts.hind(fontSize: 16, color: AppColors.textHint),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_state.error != null) ...[
          const SizedBox(height: 12),
          _ErrorBox(_state.error!),
        ],

        const SizedBox(height: 24),

        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _state.loading ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: _state.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded, size: 20),
            label: Text(
              _state.loading ? 'भेज रहे हैं...' : 'OTP भेजें (Send OTP)',
              style: GoogleFonts.hind(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ),

        const SizedBox(height: 32),
        _OrDivider(),
        const SizedBox(height: 20),

        OutlinedButton(
          onPressed: _state.loading ? null : _signInWithGoogle,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.surfaceBorder, width: 1.5),
            backgroundColor: AppColors.surface,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.network(
                'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                width: 22,
                height: 22,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.g_mobiledata_rounded, size: 24),
              ),
              const SizedBox(width: 10),
              Text(
                'Google से लॉगिन करें',
                style: GoogleFonts.hind(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildOtpStep() {
    final defaultPin = PinTheme(
      width: 52,
      height: 60,
      textStyle: GoogleFonts.hind(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder, width: 2),
      ),
    );

    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () {
            _countdownTimer?.cancel();
            setState(() => _state = _state.copyWith(
                  step: _Step.phone,
                  clearError: true,
                ));
          },
          child: Row(
            children: [
              const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'मोबाइल नंबर बदलें (Change)',
                style: GoogleFonts.hind(
                  fontSize: 15,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'OTP दर्ज करें (Enter OTP)',
          style: GoogleFonts.hind(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: GoogleFonts.hind(fontSize: 15, color: AppColors.textMuted),
            children: [
              const TextSpan(text: 'OTP भेजा गया: '),
              TextSpan(
                text: _state.phone,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        Center(
          child: Pinput(
            controller: _otpCtrl,
            focusNode: _otpFocus,
            length: 6,
            defaultPinTheme: defaultPin,
            focusedPinTheme: defaultPin.copyWith(
              decoration: defaultPin.decoration!.copyWith(
                border: Border.all(color: AppColors.primary, width: 2.5),
              ),
            ),
            submittedPinTheme: defaultPin.copyWith(
              decoration: defaultPin.decoration!.copyWith(
                color: AppColors.primarySurface,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
            ),
            onCompleted: _verifyOtp,
            hapticFeedbackType: HapticFeedbackType.lightImpact,
            keyboardType: TextInputType.number,
          ),
        ),

        if (_state.error != null) ...[
          const SizedBox(height: 16),
          _ErrorBox(_state.error!),
        ],

        const SizedBox(height: 28),

        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _state.loading ? null : () => _verifyOtp(_otpCtrl.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: _state.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Icon(Icons.verified_user_rounded, size: 20),
            label: Text(
              _state.loading ? 'सत्यापित कर रहे हैं...' : 'OTP सत्यापित करें (Verify)',
              style: GoogleFonts.hind(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ),

        const SizedBox(height: 18),

        Center(
          child: _state.resendCountdown > 0
              ? Text(
                  'दोबारा OTP भेजें (${_state.resendCountdown} सेकंड)',
                  style: GoogleFonts.hind(color: AppColors.textMuted, fontSize: 15, fontWeight: FontWeight.w500),
                )
              : TextButton(
                  onPressed: _state.loading ? null : _sendOtp,
                  child: Text(
                    'OTP दोबारा भेजें (Resend OTP)',
                    style: GoogleFonts.hind(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.hind(
                fontSize: 15,
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.surfaceBorder, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'या',
            style: GoogleFonts.hind(fontSize: 15, color: AppColors.textMuted, fontWeight: FontWeight.w600),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.surfaceBorder, thickness: 1)),
      ],
    );
  }
}
