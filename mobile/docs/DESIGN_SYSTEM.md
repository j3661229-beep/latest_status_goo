# Status Go — Design System (Phase 1)

Look & feel: Crafto-style, immersive, content-first. Big rounded cards, pill chips, vibrant gradients,
large legible type (Hindi first, English where helpful), 48dp touch targets.

```dart
import '<relative>/core/widgets/app_ui.dart';   // tokens + every component below + profile_photo helpers
```

Rules for screens: no raw `Color(0x..)` / `Colors.x` (use tokens), use `context.palette` for anything that
must adapt to dark mode, text via `AppText.*` or `Theme.of(context).textTheme`, spacing via `AppSpacing`.

---------------------------------------------------------------------------------------------------

## 1. Tokens (`lib/core/theme/app_theme.dart`)

### AppColors (static, const; light/brand values)
| Token | Hex | Notes |
|---|---|---|
| primary | #5B3DF5 | indigo-violet, 6.1:1 on white |
| primaryLight | #8B7BFF | primary on dark surfaces |
| primaryDark | #4326D6 | pressed / text on tint |
| primarySurface | #EFEBFF | tinted bg |
| primarySurfaceStrong | #DDD5FF | |
| violet / magenta | #7C3AED / #C026D3 | gradient stops |
| brandGradient | #5B3DF5 → #7C3AED → #C026D3 | white text OK (>=4.7:1) |
| brandSoftGradient | #EFEBFF → #FBE8FF | hero tint on light |
| accent | #F97316 | saffron fill/icon (NOT body text) |
| accentDark | #C2410C | saffron text on white (5.2:1) |
| saffron / rose | #FF8A00 / #DB2777 | |
| accentSurface | #FFF1E3 | |
| festivalGradient | #EA580C → #DB2777 | festivals/trending; use with large bold white text (>=18sp) |
| gold / goldDark / goldSurface | #F5B301 / #B45309 / #FFF6DB | premium |
| premiumGradient | #FFD60A → #F5B301 → #F59E0B | put **ink** text/icons on it |
| whatsapp / whatsappDark / whatsappSurface | #25D366 / #128C7E / #E6F9EE | share CTA ONLY |
| whatsappGradient | #1FB855 → #128C7E | |
| success / warning / danger / info | #15803D / #B45309 / #DC2626 / #0369A1 | + `*Surface` tints |
| bg | #F7F7FB | light page bg |
| surface | #FFFFFF | cards |
| surfaceMuted | #F0EFF7 | fills |
| surfaceBorder / borderSubtle / divider | #E7E5F0 / #EFEEF6 / #EFEEF6 | |
| ink / textPrimary | #0E0B1F | 16:1 on white |
| textSecondary | #38355A | body |
| textMuted | #5B5873 | captions, 6.8:1 on white |
| textHint | #9A98AE | placeholders only (2.8:1 — never for real content) |
| inkSurface / inkSurface2 / inkSurface3 | #0E0B1F / #1A1535 / #251E48 | dark immersive surfaces |
| inkBorder | #2F2857 | |
| onDark / onDarkMuted / onDarkHint | #F6F5FC / #B9B6D1 / #8581A3 | text on dark |
| inkGradient | #0E0B1F → #1A1535 (top→bottom) | feed/preview background |
| scrimBottom / scrimTop | ink 80% → 0 / 60% → 0 | text over imagery |
| glass / glassStrong / glassBorder | white 12% / 16% / 20% | blur overlays on dark |
| glassLight | white 80% | glass on light pages |
| scrim | ink 45% | modal barrier / lock overlay |
| shimmer / shimmerHighlight (+Dark) | #E9E7F3 / #F8F7FD (#241E45 / #332B5E) | |
| white / black / transparent | | |

`AppColors.parseGradient("#a,#b")` → `List<Color>?` (template gradient fallback).

### AppPalette (theme-adaptive) — `context.palette`
`bg, surface, surfaceMuted, surfaceElevated, border, divider, textPrimary, textSecondary, textMuted, textHint,
primary, primarySurface, shimmerBase, shimmerHighlight, isDark`. Also `context.isDarkTheme`, `context.text`.

### Spacing / radius / shadow / motion
* `AppSpacing`: xxs 4, xs 8, sm 12, md 16, lg 20, xl 24, xxl 32, xxxl 48, `page` 20 (gutter), `minTouch` 48.
* `AppRadius`: xs 6, sm 10, md 16, lg 24, xl 32, pill 999; helpers `AppRadius.mdAll/lgAll/xlAll/pillAll/smAll`.
* `AppShadows`: subtle, card, floating, bottomDock, primaryGlow, whatsappGlow, premiumGlow, festivalGlow.
* `AppMotion`: instant 90ms, fast 160, normal 260, slow 420, stagger 55; curves standard (easeOutCubic), emphasized, spring.

### Typography
Headings **Poppins**, body **Noto Sans**, Devanagari fallback **Noto Sans Devanagari** (Hindi/Marathi).
* `AppText.heading({size, weight, color, height, letterSpacing})`, `AppText.body({...})` → `TextStyle`.
* TextTheme: display L/M/S 34/28/24, headline L/M/S 26/22/20, title L/M/S 19/17/15, body L/M/S 17/15.5/13.5,
  label L/M/S 16/14/12.5. Buttons 16.5-17sp. App clamps system text scale to 0.9–1.3.

### Themes
`AppTheme.light`, `AppTheme.dark` (both fully themed: AppBar, BottomSheet, Dialog, Input, Elevated/Filled/Outlined/Text/Icon
buttons, Chip, Switch, Checkbox, ListTile, SnackBar, Progress, TabBar, NavigationBar, Card, Divider).
`AppTheme.immersive` == dark. Theme mode: `themeModeProvider` (`lib/core/theme/theme_mode_provider.dart`),
`ref.watch(themeModeProvider)` / `ref.read(themeModeProvider.notifier).setMode(ThemeMode.dark)`; persisted in
`settings_box` key `theme_mode`; wired in `main.dart`.
Force dark on a screen regardless of mode: wrap in `ImmersiveTheme(child: ...)` (or use `GradientScaffold`).

---------------------------------------------------------------------------------------------------

## 2. Components

All exported by `core/widgets/app_ui.dart` (files in `core/widgets/ui/`).

### Buttons (`buttons.dart`)
```dart
GradientButton(label: 'आगे बढ़ें', onPressed: _go);                       // primary, full width, h56
GradientButton(label: 'WhatsApp पर शेयर', icon: Icons.share_rounded,
    variant: GradientButtonVariant.whatsapp, isLoading: _busy, onPressed: _share);
// variants: primary | whatsapp | premium (ink text) | festival;  params: expand, haptic, height
SecondaryButton(label: 'बाद में', onPressed: () {});                      // outlined pill
SecondaryButton(label: 'हटाएं', destructive: true, tonal: true, icon: Icons.delete_outline, onPressed: ...);
AppIconButton(icon: Icons.close_rounded, semanticLabel: 'बंद करें', onPressed: ..., glass: false, filled: false);
```
`AppIconButton.semanticLabel` is required; hit box is always >= 48dp. `glass: true` = translucent white over imagery.

### Inputs & chips (`inputs.dart`)
```dart
AppTextField(controller: c, label: 'आपका नाम', hint: '...', prefixIcon: Icons.person_outline_rounded,
    required: true, validator: (v) => ..., keyboardType, textInputAction, maxLength, maxLines, minLines,
    inputFormatters, onChanged, onSubmitted, obscureText, readOnly, enabled, helperText, suffix, prefixText);
AppSearchField(controller: c, hint: 'खोजें...', onChanged: ..., onSubmitted: ..., onClear: ...);
CategoryChip(label: 'सुप्रभात', emoji: '🌅', icon: null, selected: true, onTap: ..., selectedGradient: null);
FilterPillRow(labels: [...], selectedIndex: i, onSelected: (i) {}, emojis: [...]);   // horizontal scroll, h48
```
`AppTextField` renders its label ABOVE the field and must live inside a `Form` for `validator`.

### Feedback (`feedback.dart`)
```dart
AppSnack.success(context, 'सेव हो गया'); AppSnack.error(context, msg); AppSnack.info(context, msg);
final ok = await ConfirmDialog.show(context, title: ..., message: ..., confirmLabel: ..., cancelLabel: ...,
    destructive: true, icon: Icons.logout_rounded, extra: InfoCard(...));       // -> bool
EmptyState(icon: Icons.bookmark_border_rounded, title: '...', message: '...', actionLabel: '...', onAction: ..., gradient:, compact:);
ErrorState(message: apiErrorMessage(e), onRetry: () => ref.invalidate(p), title:, retryLabel:, icon:);
OfflineBanner(message: ..., onRetry: ...);
ShimmerBox(width:, height:, radius:); ShimmerGrid(itemCount: 6, crossAxisCount: 2, aspectRatio: .72);
ShimmerList(itemCount: 5, itemHeight: 76);      // Shimmer* are non-scrolling (shrinkWrap) — put in a scroll view
```

### Layout (`layout.dart`)
```dart
AppScaffold(title: 'सेटिंग्स', body: ..., actions: [...], bottomBar: ..., showBack: true, floatingActionButton:);
GradientScaffold(body: ..., gradient: AppColors.inkGradient, appBar:, bottomNavigationBar:, dark: true); // dark immersive page
ImmersiveTheme(child: ...);                       // dark Theme + light status-bar icons
GlassContainer(radius: AppRadius.lg, blur: 18, padding: ..., child: ...);  GlassContainer.light(child: ...);
SectionHeader(title: 'आज के त्योहार', subtitle: '...', actionLabel: 'सभी देखें', onAction: () {}, onDark: false, padding:);
AppBottomSheet.show<T>(context, title: 'भाषा', subtitle: '...', builder: (ctx) => ..., scrollable: true);  // + SheetHandle, SheetHeader
SettingsSection(title: 'खाता', children: [SettingsTile(icon:, title:, subtitle:, value:, trailing:, onTap:, iconColor:, destructive:, showChevron:)]);
LabeledSwitchTile(icon: ..., title: ..., subtitle: ..., value: v, onChanged: (v) {});
InfoCard(tone: InfoTone.warning|info|success|danger|brand, title:, message: '...', icon:, actionLabel:, onAction:);
StatPill(icon: Icons.local_fire_department_rounded, value: '7', label: 'दिन', color: AppColors.accent);
AppAvatar(image: currentUserPhotoProvider(serverPhoto: u?.profilePhoto), name: u?.name, radius: 36, ring: true);
AppAvatar.fromSource(source: urlOrPath, name: ...);
AppLogo(size: 72, showWordmark: true, horizontal: false, wordmarkColor: ...);   // built from widgets, no assets
```

### Cards (`cards.dart`)
```dart
PremiumBadge(compact: true);                      // gold crown pill
AppBadge(label: 'नया', icon: Icons.bolt_rounded, gradient: AppColors.festivalGradient, compact: true);
TemplateLock();                                    // lock overlay (scrim + gold lock)
TemplateCard(template: t, aspectRatio: .75, showTitle: true, showStats: true, actionOverlay: w, onTap: null, radius: AppRadius.lg);
   // default tap: locked -> /premium, else /template/:id.  Shows premium/trending/new badges, lock, use-count, shimmer.
TemplateGrid(templates: list, onTapTemplate: (t) {}, showTitle: true, actionBuilder: (t) => widget);  // 2-col masonry, non-scrolling
SliverTemplateGrid(templates: list, ...);          // same, for CustomScrollView
formatCount(12500) -> '12.5K'
```

### Motion (`motion.dart`)
```dart
PressableScale(onTap: ..., onLongPress: ..., scale: .96, haptic: false, semanticLabel: '...', child: w);
FadeSlideIn(index: i, delay: Duration.zero, duration: AppMotion.slow, dy: 18, dx: 0, child: w);  // staggered entrance (index clamps at 8)
PageIndicator(count: 3, index: page, activeColor:, inactiveColor:, dotSize: 8);
```

### Shell / bottom nav (`core/router/app_shell.dart`)
`MainShell` renders a floating pill nav (होम, खोजें, सहेजें, प्रोफ़ाइल) with an animated gradient active pill.
Dark immersive tab screens set `AppShell.immersive.value = true` in `initState` (post-frame) and `false` in `dispose`
— the bar then turns dark and the shell background becomes ink. The shell does NOT extend the body behind the bar
(`extendBody: false`); reserve nothing extra. `AppShell.navHeight` = 68.

### Legacy (kept for compile-compat, delegate to the above; prefer new ones)
`lib/core/theme/app_ui_components.dart`: `AppSectionHeader` -> `SectionHeader`, `AppTemplateCard` -> `TemplateCard`/`TemplateGrid`,
`AppWhatsAppButton` -> `GradientButton(variant: whatsapp)`, `AppSearchBarTrigger` (still fine), `PagingFooter` (fine).
`AppColors.surfaceBorder/textSecondary/...` keep working but the values changed. Screens still using
`GoogleFonts.hind(...)` compile fine; migrate to `AppText.body/heading`.

---------------------------------------------------------------------------------------------------

## 3. Routes

Public (no auth): `/splash`, `/intro`, `/login`, `/privacy-policy`, `/terms`, `/refund-policy`, `/about`, `/help`.
Authenticated: `/settings`, `/edit-profile`, `/my-plan`, `/premium`, `/search`, `/notifications`, `/template/:id`,
`/profile-setup`, tabs `/home /discover /saved /profile`. Unknown routes -> `NotFoundScreen` (router `errorBuilder`).
`/intro` is shown once before `/login` on a fresh install (`settings_box.intro_seen`).

## 4. Helpers
* `AppActions` (`core/utils/app_actions.dart`): `openUrl`, `rateApp`, `shareApp`, `email`, `whatsappSupport`, `call`.
* `appVersionProvider`, `buildSupportDiagnostics()` (`core/utils/app_info.dart`).
* `AuthRepository`: `updateProfileFields(map)`, `updateLanguage(code)`, `uploadImage(path)`, `deleteAccount()`.
* `NotificationService`: `isPushOptedIn`, `setPushEnabled(bool)`, `setPreferenceTag(key, bool)`.
* `LegalConsentText` (`features/legal/presentation/widgets/`): tappable "agree to Terms & Privacy" line.

## 5. Owner TODOs (AppConstants)
`supportEmail, supportPhone, supportWhatsappNumber, companyName, companyAddress, grievanceOfficerName,
grievanceOfficerEmail, websiteUrl, privacyUrl, termsUrl, refundUrl, playStoreUrl (verify package id), policyLastUpdated`.
Legal text lives in `features/legal/data/legal_content.dart` (EN + हिंदी) — have counsel review.
