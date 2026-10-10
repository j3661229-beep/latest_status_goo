// Pure-widget tests for the Status Go design-system components.
// (No network / Hive / Firebase: the full app needs platform plugins.)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:status_go/core/widgets/app_ui.dart';

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  setUpAll(() {
    // Never hit the network for fonts in tests; fall back to the default font.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // Font loading failures (no bundled font files) are expected and harmless here.
  void ignoreFontErrors(WidgetTester tester) {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('google_fonts')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  testWidgets('GradientButton shows its label and fires onPressed', (tester) async {
    ignoreFontErrors(tester);
    var taps = 0;
    await tester.pumpWidget(_host(GradientButton(label: 'OTP भेजें', onPressed: () => taps++, haptic: false)));
    expect(find.text('OTP भेजें'), findsOneWidget);
    await tester.tap(find.text('OTP भेजें'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('GradientButton ignores taps while loading', (tester) async {
    ignoreFontErrors(tester);
    var taps = 0;
    await tester.pumpWidget(_host(GradientButton(label: 'Go', isLoading: true, onPressed: () => taps++, haptic: false)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(GradientButton));
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('EmptyState renders title, message and action', (tester) async {
    ignoreFontErrors(tester);
    var acted = false;
    await tester.pumpWidget(_host(EmptyState(
      icon: Icons.bookmark_border_rounded,
      title: 'अभी कुछ सेव नहीं है',
      message: 'पसंदीदा स्टेटस सेव करें',
      actionLabel: 'स्टेटस देखें',
      onAction: () => acted = true,
    )));
    expect(find.text('अभी कुछ सेव नहीं है'), findsOneWidget);
    expect(find.text('पसंदीदा स्टेटस सेव करें'), findsOneWidget);
    await tester.tap(find.text('स्टेटस देखें'));
    await tester.pump();
    expect(acted, isTrue);
  });

  testWidgets('AppIconButton exposes a semantics label and 48dp target', (tester) async {
    ignoreFontErrors(tester);
    await tester.pumpWidget(_host(AppIconButton(icon: Icons.close_rounded, semanticLabel: 'बंद करें', onPressed: () {})));
    expect(find.bySemanticsLabel('बंद करें'), findsOneWidget);
    final size = tester.getSize(find.byType(AppIconButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('AppLogo renders at 1.3 text scale without overflow', (tester) async {
    ignoreFontErrors(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child!,
      ),
      home: const Scaffold(body: Center(child: AppLogo(size: 72, showWordmark: true))),
    ));
    expect(tester.takeException(), isNull);
  });
}
