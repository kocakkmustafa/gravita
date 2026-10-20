import 'dart:ui';

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Gravita's visual language — design panel v1, 2026-08-05
/// (`docs/design/DESIGN-PANEL-PROMPT.md`; `claude.ai/design` project
/// `6ccaab1e-6d13-4cb5-a0c9-6038e7c1170d`, files `GravitaScreen.dc.html` /
/// `Gravita States.dc.html`).
///
/// STYLE ONLY. Nothing in this file changes what a screen's tests can find —
/// every widget below is a decoration that [ProgressView], [LiveSessionScreen]
/// and [ContentFailureScreen] wrap their existing state, Keys and copy in.
/// Those files keep their structure from before this file existed.
///
/// ## The card material — CLOSED, founder decision (2026-08-06)
///
/// The design panel's own brief (§1, "kardeş ayrışması") had said Gravita's
/// cards are *"rafine düz kart, cam DEĞİL"* (refined flat card, NOT glass),
/// but the delivered `GravitaScreen.dc.html` uses `backdrop-filter:
/// blur(26px) saturate(165%)` on nearly every card — frosted glass. Flagged
/// up; **founder ruled GLASS STAYS** — the brief's "not glass" line is
/// superseded, not the delivered file. Implemented as delivered.
///
/// The blur/saturate values stay in exactly ONE place — [GravitaMaterial.
/// cardBlur] / [GravitaMaterial.cardSaturation] — regardless: a settled
/// decision doesn't retire the hygiene of a single material definition, and
/// it keeps a future theme change one line instead of a hunt through every
/// screen. Consequence this decision has for sibling-differentiation and how
/// it was re-verified against the delivered file (not just the brief's
/// words): `docs/design/DESIGN-AHEAD-OF-CODE.md` §3.1.

// ── Colour ───────────────────────────────────────────────────────────────

/// Immutable semantic colours for one widget subtree. The legacy constants below
/// remain light references; runtime UI resolves this extension through its context.
@immutable
final class GravitaPalette extends ThemeExtension<GravitaPalette> {
  const GravitaPalette({
    required this.brightness,
    required this.page,
    required this.surfaceTop,
    required this.surfaceBottom,
    required this.ink,
    required this.inkMuted,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentHover,
    required this.honestySeal,
    required this.honestyText,
    required this.hairline,
    required this.sessionStage,
    required this.sessionStageDeep,
    required this.sessionCamera,
    required this.sessionInkOnDark,
    required this.sessionInkMutedOnDark,
    required this.sessionSheetSealed,
    required this.onAccent,
    required this.cardTop,
    required this.cardBottom,
    required this.cardBorder,
    required this.sealedTop,
    required this.sealedBottom,
    required this.shadow,
    required this.focusRing,
    required this.disabledInk,
    required this.disabledSurface,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
  });

  final Brightness brightness;
  final Color page;
  final Color surfaceTop;
  final Color surfaceBottom;
  final Color ink;
  final Color inkMuted;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentHover;
  final Color honestySeal;
  final Color honestyText;
  final Color hairline;
  final Color sessionStage;
  final Color sessionStageDeep;
  final Color sessionCamera;
  final Color sessionInkOnDark;
  final Color sessionInkMutedOnDark;
  final Color sessionSheetSealed;
  final Color onAccent;
  final Color cardTop;
  final Color cardBottom;
  final Color cardBorder;
  final Color sealedTop;
  final Color sealedBottom;
  final Color shadow;
  final Color focusRing;
  final Color disabledInk;
  final Color disabledSurface;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;

  static const GravitaPalette light = GravitaPalette(
    brightness: Brightness.light,
    page: GravitaColors.page,
    surfaceTop: GravitaColors.surfaceTop,
    surfaceBottom: GravitaColors.surfaceBottom,
    ink: GravitaColors.ink,
    inkMuted: GravitaColors.inkMuted,
    textSecondary: GravitaColors.textSecondary,
    textTertiary: GravitaColors.textTertiary,
    accent: GravitaColors.accent,
    accentHover: GravitaColors.accentHover,
    honestySeal: GravitaColors.honestySeal,
    honestyText: GravitaColors.honestyText,
    hairline: GravitaColors.hairline,
    sessionStage: GravitaColors.sessionStage,
    sessionStageDeep: GravitaColors.sessionStageDeep,
    sessionCamera: GravitaColors.sessionCamera,
    sessionInkOnDark: GravitaColors.sessionInkOnDark,
    sessionInkMutedOnDark: GravitaColors.sessionInkMutedOnDark,
    sessionSheetSealed: GravitaColors.sessionSheetSealed,
    onAccent: Color(0xFFFFFFFF),
    cardTop: Color(0x8FFFFFFF),
    cardBottom: Color(0x47FFFFFF),
    cardBorder: Color(0xB3FFFFFF),
    sealedTop: Color(0xD9FFF4F3),
    sealedBottom: Color(0xB3FAE7E5),
    shadow: Color(0x1F1E1817),
    focusRing: GravitaColors.ink,
    disabledInk: Color(0xFF625956),
    disabledSurface: Color(0xFFE1D9D6),
    error: Color(0xFF9F1B22),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD7),
    onErrorContainer: Color(0xFF6C1118),
  );

  /// Camera/stage tokens deliberately stay dark in both app themes. Sheets and
  /// honesty panels use the active palette and are not camera overlays.
  static const GravitaPalette dark = GravitaPalette(
    brightness: Brightness.dark,
    page: Color(0xFF171211),
    surfaceTop: Color(0xFF211B19),
    surfaceBottom: Color(0xFF1B1514),
    ink: Color(0xFFFFF7F3),
    inkMuted: Color(0xFFD8C6C0),
    textSecondary: Color(0xFFC3ADA5),
    textTertiary: Color(0xFFAD958E),
    accent: Color(0xFFFF8C97),
    accentHover: Color(0xFFFFB8BD),
    honestySeal: Color(0xFFDFA49A),
    honestyText: Color(0xFFE6C3BD),
    hairline: Color(0x338D726A),
    sessionStage: GravitaColors.sessionStage,
    sessionStageDeep: GravitaColors.sessionStageDeep,
    sessionCamera: GravitaColors.sessionCamera,
    sessionInkOnDark: GravitaColors.sessionInkOnDark,
    sessionInkMutedOnDark: GravitaColors.sessionInkMutedOnDark,
    sessionSheetSealed: Color(0xFF332321),
    onAccent: Color(0xFF48050B),
    cardTop: Color(0xAD4A3931),
    cardBottom: Color(0xD1312522),
    cardBorder: Color(0xA68D726A),
    sealedTop: Color(0xF23E2825),
    sealedBottom: Color(0xF2332321),
    shadow: Color(0x52000000),
    focusRing: Color(0xFFFFF7F3),
    disabledInk: Color(0xFFB8ABA8),
    disabledSurface: Color(0xFF3D3230),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF69000B),
    errorContainer: Color(0xFF69252A),
    onErrorContainer: Color(0xFFFFDAD6),
  );

  @override
  GravitaPalette copyWith({
    Brightness? brightness,
    Color? page,
    Color? surfaceTop,
    Color? surfaceBottom,
    Color? ink,
    Color? inkMuted,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentHover,
    Color? honestySeal,
    Color? honestyText,
    Color? hairline,
    Color? sessionStage,
    Color? sessionStageDeep,
    Color? sessionCamera,
    Color? sessionInkOnDark,
    Color? sessionInkMutedOnDark,
    Color? sessionSheetSealed,
    Color? onAccent,
    Color? cardTop,
    Color? cardBottom,
    Color? cardBorder,
    Color? sealedTop,
    Color? sealedBottom,
    Color? shadow,
    Color? focusRing,
    Color? disabledInk,
    Color? disabledSurface,
    Color? error,
    Color? onError,
    Color? errorContainer,
    Color? onErrorContainer,
  }) => GravitaPalette(
    brightness: brightness ?? this.brightness,
    page: page ?? this.page,
    surfaceTop: surfaceTop ?? this.surfaceTop,
    surfaceBottom: surfaceBottom ?? this.surfaceBottom,
    ink: ink ?? this.ink,
    inkMuted: inkMuted ?? this.inkMuted,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary: textTertiary ?? this.textTertiary,
    accent: accent ?? this.accent,
    accentHover: accentHover ?? this.accentHover,
    honestySeal: honestySeal ?? this.honestySeal,
    honestyText: honestyText ?? this.honestyText,
    hairline: hairline ?? this.hairline,
    sessionStage: sessionStage ?? this.sessionStage,
    sessionStageDeep: sessionStageDeep ?? this.sessionStageDeep,
    sessionCamera: sessionCamera ?? this.sessionCamera,
    sessionInkOnDark: sessionInkOnDark ?? this.sessionInkOnDark,
    sessionInkMutedOnDark: sessionInkMutedOnDark ?? this.sessionInkMutedOnDark,
    sessionSheetSealed: sessionSheetSealed ?? this.sessionSheetSealed,
    onAccent: onAccent ?? this.onAccent,
    cardTop: cardTop ?? this.cardTop,
    cardBottom: cardBottom ?? this.cardBottom,
    cardBorder: cardBorder ?? this.cardBorder,
    sealedTop: sealedTop ?? this.sealedTop,
    sealedBottom: sealedBottom ?? this.sealedBottom,
    shadow: shadow ?? this.shadow,
    focusRing: focusRing ?? this.focusRing,
    disabledInk: disabledInk ?? this.disabledInk,
    disabledSurface: disabledSurface ?? this.disabledSurface,
    error: error ?? this.error,
    onError: onError ?? this.onError,
    errorContainer: errorContainer ?? this.errorContainer,
    onErrorContainer: onErrorContainer ?? this.onErrorContainer,
  );

  @override
  GravitaPalette lerp(covariant GravitaPalette? other, double t) {
    if (other == null) return this;
    return GravitaPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      page: Color.lerp(page, other.page, t)!,
      surfaceTop: Color.lerp(surfaceTop, other.surfaceTop, t)!,
      surfaceBottom: Color.lerp(surfaceBottom, other.surfaceBottom, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      honestySeal: Color.lerp(honestySeal, other.honestySeal, t)!,
      honestyText: Color.lerp(honestyText, other.honestyText, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      sessionStage: Color.lerp(sessionStage, other.sessionStage, t)!,
      sessionStageDeep: Color.lerp(
        sessionStageDeep,
        other.sessionStageDeep,
        t,
      )!,
      sessionCamera: Color.lerp(sessionCamera, other.sessionCamera, t)!,
      sessionInkOnDark: Color.lerp(
        sessionInkOnDark,
        other.sessionInkOnDark,
        t,
      )!,
      sessionInkMutedOnDark: Color.lerp(
        sessionInkMutedOnDark,
        other.sessionInkMutedOnDark,
        t,
      )!,
      sessionSheetSealed: Color.lerp(
        sessionSheetSealed,
        other.sessionSheetSealed,
        t,
      )!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      cardTop: Color.lerp(cardTop, other.cardTop, t)!,
      cardBottom: Color.lerp(cardBottom, other.cardBottom, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      sealedTop: Color.lerp(sealedTop, other.sealedTop, t)!,
      sealedBottom: Color.lerp(sealedBottom, other.sealedBottom, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      disabledInk: Color.lerp(disabledInk, other.disabledInk, t)!,
      disabledSurface: Color.lerp(disabledSurface, other.disabledSurface, t)!,
      error: Color.lerp(error, other.error, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      onErrorContainer: Color.lerp(
        onErrorContainer,
        other.onErrorContainer,
        t,
      )!,
    );
  }
}

abstract final class GravitaColors {
  GravitaColors._();

  static GravitaPalette of(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme.extension<GravitaPalette>() ??
        (theme.brightness == Brightness.dark
            ? GravitaPalette.dark
            : GravitaPalette.light);
  }

  /// Page backdrop behind the phone frame in the design's canvas; reused
  /// here as the app's own scaffold background (there is no phone bezel to
  /// frame in a real device).
  static const Color page = Color(0xFFF2EFEE);

  /// The in-screen gradient the design applies inside its phone frame
  /// (`GravitaScreen.dc.html` root: `linear-gradient(158deg,#F8F5F4,#EDE6E5
  /// 52%,#F5EFEE)`). Close enough to [page] that a flat fallback (no
  /// gradient support) reads the same.
  static const Color surfaceTop = Color(0xFFF8F5F4);
  static const Color surfaceBottom = Color(0xFFF5EFEE);

  static const Color ink = Color(0xFF1E1817);
  static const Color inkMuted = Color(0xFF4A403E);
  static const Color textSecondary = Color(0xFF6E6260);

  /// ⚠️ **METİN İÇİN KULLANMA — bu bir NON-TEXT tokenidir.**
  ///
  /// Ölçüldü (WCAG 2.2 · 2026-08-07, J-114 aktarımı): `#7A6C69` sayfa
  /// zemininde (`#F2EFEE`) **4.40:1**, mühür kartının alt ucunda **4.26:1**
  /// veriyor — ikisi de normal metin eşiği **4.5**'in ALTINDA. Kusur küçük
  /// mono ölçüm-dilinde oluşuyordu ve bu üründe mono metin BASKIN (tasarımın
  /// kendi sayımı: 161 mono ↔ 71 prose).
  ///
  /// İkon/kenarlık/ayraç için MEŞRU: WCAG 1.4.11 metin-dışı eşiği **3.0** ve
  /// bu renk kart üstünde 4.56 veriyor — rahatça geçiyor.
  ///
  /// Metin gerektiğinde [textSecondary] kullan (sayfada 5.13, mühürde 4.98).
  /// Token DEĞİŞTİRİLMEDİ, KULLANIMI ayrıldı: ikisi de tasarımın teslim ettiği
  /// palette içinde (delta belgesi §3.1 ikisini de sayıyor), o yüzden bu bir
  /// palet ihlali değil, aynı paletin doğru yerde kullanılması.
  static const Color textTertiary = Color(0xFF7A6C69);

  /// KOYU zemin (seans ekranı) için ikincil metin.
  ///
  /// Ölçüldü: hem [textTertiary] (3.37) hem [textSecondary] (2.88)
  /// `sessionCamera` üstünde eşiğin ALTINDA — koyu zeminde açık ton gerekiyor,
  /// açık-zemin tokeni ters çevrilerek kullanılamıyor. Bu değer
  /// `sessionCamera` üstünde 7.60, `sessionStage` üstünde 8.33 veriyor.
  static const Color sessionInkMutedOnDark = Color(0xFFB8ABA8);

  /// The ONLY accent colour (design brief §1: "kırmızı yalnız üç işte:
  /// ölçülen kriter, kapı/kilit, dürüstlük mührü" — measured criterion,
  /// gate/lock, honesty seal. Do not reach for this for plain emphasis.
  static const Color accent = Color(0xFFA11019);
  static const Color accentHover = Color(0xFF7A0C12);

  /// Deeper red used specifically on the honesty-box seal and locked-reason
  /// framing (`GravitaScreen.dc.html` honesty block: border-top `#6E0A10`,
  /// its own body text `#5A3A38`) — visually distinct from [accent] so a
  /// "measured criterion" pill and a "here is what we don't grade" seal
  /// never read as the same kind of mark.
  static const Color honestySeal = Color(0xFF6E0A10);
  static const Color honestyText = Color(0xFF5A3A38);

  static const Color hairline = Color(0x33FFFFFF); // rgba(255,255,255,.2)

  /// The camera/stage keeps its dark exposure backdrop in either app theme.
  /// Use the context palette for sheets and controls around that camera.
  static const Color sessionStage = Color(0xFF171212);
  static const Color sessionStageDeep = Color(0xFF100C0C);
  static const Color sessionCamera = Color(0xFF221B1B);
  static const Color sessionInkOnDark = Color(0xFFFFFDFC);

  /// Seans alt-sayfasının MÜHÜRLÜ hâli (arıza/dürüstlük beyanı).
  ///
  /// ⚠️ Bu renk `live_session_screen.dart` içinde **yerinde yazılmış bir
  /// literal**di (`const Color(0xFFFFF4F3)`) ve tam da bu yüzden kontrast
  /// kapısının **DIŞINDAYDI**: kapı `GravitaColors`taki tokenları tarıyor,
  /// yerinde tanımlanmış bir zemini göremiyor. Ölçüldü — bugün güvenli
  /// (honestyText 9.29:1), ama **ölçülmeyen bir alan üretiyordu.**
  ///
  /// J-126 aktarımının bende karşılığı: *yeşil bir kapı, bakılmayan bir alan
  /// üretir.* Token'a terfi etmek, alanı kapının içine alır.
  static const Color sessionSheetSealed = Color(0xFFFFF4F3);
}

// ── Type ─────────────────────────────────────────────────────────────────

/// Two families (design's own CSS: `'Public Sans'` for prose, `'Roboto
/// Mono'` for anything measured). Mono is reserved for numbers, criteria and
/// status pills — the same "this is a fact vs this is prose" split Choreia's
/// [ChoreiaType] documents for its own three-family version.
///
/// **F2 (D1, 2026-08-16):** both families are now BUNDLED assets
/// (`pubspec.yaml` `fonts:`, OFL 1.1) instead of `google_fonts`' runtime
/// fetch from `fonts.gstatic.com` — that fetch was `B5`, the blocker behind
/// the cold-start network-rejection failure and the test-suite's dependency
/// on this machine's font cache (see the now-obsolete w700 workaround this
/// file's git history carries, `movement_page.dart`). Plain [TextStyle]
/// with `fontFamily` needs no package: Flutter resolves it against whatever
/// `pubspec.yaml` declares.
abstract final class GravitaType {
  GravitaType._();

  static const String _publicSans = 'Public Sans';
  static const String _robotoMono = 'Roboto Mono';

  // ── Varsayılan METİN renkleri ────────────────────────────────────────
  //
  // ⚠️ Ayrı sabit olmalarının sebebi ölçülmüş: bunlar bir FONT kararı değil
  // bir TOKEN kararıdır, ve paylaşılan bir varsayılanın eşik altına düşmesi
  // (J-116) rengi elle vermeyen HER çağıranı sessizce bozar.
  //
  // Bağ YAPISALDIR, iddia değil: yardımcılar `color ?? <sabit>` diyor, yani
  // sabiti ölçmek çağrının aldığı rengi ölçmektir.
  static const Color defaultDisplayColor = GravitaColors.ink;
  static const Color defaultBodyColor = GravitaColors.ink;
  static const Color defaultMonoColor = GravitaColors.textSecondary;

  static TextStyle display({
    BuildContext? context,
    double size = 27,
    Color? color,
    FontWeight weight = FontWeight.w600,
    double height = 1.15,
  }) => TextStyle(
    fontFamily: _publicSans,
    fontSize: size,
    height: height,
    fontWeight: weight,
    letterSpacing: -0.02 * size,
    color: context == null
        ? color ?? defaultDisplayColor
        : color ?? GravitaColors.of(context).ink,
  );

  static TextStyle body({
    BuildContext? context,
    double size = 15,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double height = 1.6,
  }) => TextStyle(
    fontFamily: _publicSans,
    fontSize: size,
    height: height,
    fontWeight: weight,
    color: context == null
        ? color ?? defaultBodyColor
        : color ?? GravitaColors.of(context).ink,
  );

  /// Measurement/status language — criteria, units, timers, section
  /// eyebrows. `letterSpacingEm` mirrors the design's CSS `em` tracking,
  /// scaled by font size the way Choreia's [ChoreiaType.label] does.
  static TextStyle mono({
    BuildContext? context,
    double size = 11,
    Color? color,
    FontWeight weight = FontWeight.w500,
    double letterSpacingEm = 0.1,
  }) => TextStyle(
    fontFamily: _robotoMono,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacingEm * size,
    // ⚠️ VARSAYILAN [defaultMonoColor] — eskiden [textTertiary] idi ve
    // bu, rengi ELLE vermeyen her çağıranı sessizce eşik-altı bir metne
    // düşürüyordu: kusurun varsayılan olması, en kolay çoğalma yolu.
    color: context == null
        ? color ?? defaultMonoColor
        : color ?? GravitaColors.of(context).textSecondary,
  );
}

// ── Card material (the isolated token — see file doc comment) ─────────────

abstract final class GravitaMaterial {
  GravitaMaterial._();

  /// Sigma for the card backdrop blur. THE single number to change if the
  /// founder sides with the brief's "not glass" line over the delivered
  /// file. Setting this to `0` and [cardSaturation] to `1.0` flattens every
  /// [GravitaCard] in the app at once.
  static const double cardBlur = 26;

  static const double cardSaturation = 1.65;

  /// Below this blur, [GravitaCard] skips [BackdropFilter] entirely rather
  /// than paying its compositing cost for an effect too small to see —
  /// relevant the day this constant is turned down toward 0.
  static const double _blurEpsilon = 0.5;
}

/// One glass/flat card — the shared decoration primitive for every restyled
/// screen. Radius follows the design's card-radius scale: 18 for a compact
/// row, 22 for a standard card (the default), 24 for a hero card.
class GravitaCard extends StatelessWidget {
  const GravitaCard({
    super.key,
    required this.child,
    this.radius = 22,
    this.padding = const EdgeInsets.all(18),
    this.sealed = false,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// The honesty-box / locked-reason treatment (design: red-tinted gradient,
  /// solid `honestySeal` top border, no blur — the design keeps this one
  /// flat even where it makes every other card glass, because a seal reads
  /// as ink on paper, not a floating pane).
  final bool sealed;

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(radius);
    final GravitaPalette palette = GravitaColors.of(context);
    final bool effectsEnabled = GravitaMotion.effectsEnabled(context);

    // A single, UNIFORM border colour — Flutter's own constraint ("a
    // borderRadius can only be given on borders with uniform colors") rules
    // out the design's literal two-tone border (strong top, faint sides).
    // The seal's visual weight instead comes from the flat top bar below,
    // which is a plain rectangle and has no such restriction.
    Widget body = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: sealed
              ? <Color>[palette.sealedTop, palette.sealedBottom]
              : <Color>[palette.cardTop, palette.cardBottom],
        ),
        border: Border.all(
          color: sealed
              ? palette.honestySeal.withValues(alpha: 0.4)
              : palette.cardBorder,
        ),
      ),
      child: child,
    );

    if (!sealed &&
        effectsEnabled &&
        GravitaMaterial.cardBlur >= GravitaMaterial._blurEpsilon) {
      body = BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GravitaMaterial.cardBlur,
          sigmaY: GravitaMaterial.cardBlur,
        ),
        child: body,
      );
    }

    if (sealed) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(height: 2.5, color: palette.honestySeal),
          body,
        ],
      );
    }

    // Shadow lives on THIS outer box, not the clipped one: a shadow inside
    // ClipRRect would be cropped flush at its own edge and disappear.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: effectsEnabled
            ? <BoxShadow>[
                BoxShadow(
                  color: palette.shadow,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: ClipRRect(borderRadius: borderRadius, child: body),
    );
  }
}

/// A named-status pill — "CRITERION", "LOCKED", "GENERATED" and this
/// screen's own measured/notes equivalents. Mono type; [filled] draws the
/// tinted-and-bordered treatment the design reserves for a state that IS,
/// leaving the hollow outline for a state that is named but not active.
class GravitaPill extends StatelessWidget {
  const GravitaPill({
    super.key,
    required this.label,
    this.tone,
    this.filled = true,
  });

  final String label;
  final Color? tone;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final Color resolvedTone = tone ?? GravitaColors.of(context).accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: filled ? resolvedTone.withValues(alpha: 0.1) : null,
        border: filled ? null : Border.all(color: resolvedTone),
      ),
      child: Text(
        label,
        style: GravitaType.mono(
          context: context,
          size: 10,
          color: resolvedTone,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── App theme ────────────────────────────────────────────────────────────

/// Motion preferences are read from the current subtree, never cached globally.
/// Reduced motion keeps the glass tint but removes compositing-heavy effects;
/// callers of Animated* widgets can use [duration] for the same policy.
abstract final class GravitaMotion {
  GravitaMotion._();

  static bool reduceMotion(BuildContext context) {
    final MediaQueryData? media = MediaQuery.maybeOf(context);
    return media?.disableAnimations == true ||
        media?.accessibleNavigation == true;
  }

  static bool effectsEnabled(BuildContext context) => !reduceMotion(context);

  static Duration duration(
    BuildContext context, {
    Duration normal = const Duration(milliseconds: 200),
  }) => reduceMotion(context) ? Duration.zero : normal;
}

/// The platform's normal transition is retained unless motion is reduced.
class GravitaPageTransitionsBuilder extends PageTransitionsBuilder {
  const GravitaPageTransitionsBuilder({
    this.delegate = const FadeUpwardsPageTransitionsBuilder(),
  });

  final PageTransitionsBuilder delegate;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => GravitaMotion.reduceMotion(context)
      ? child
      : delegate.buildTransitions<T>(
          route,
          context,
          animation,
          secondaryAnimation,
          child,
        );
}

/// App-owned Material surfaces share the semantic palette used by custom UI.
abstract final class GravitaTheme {
  GravitaTheme._();

  static ThemeData get light => _build(GravitaPalette.light);
  static ThemeData get dark => _build(GravitaPalette.dark);

  static ThemeData _build(GravitaPalette palette) {
    final bool dark = palette.brightness == Brightness.dark;
    // Material components need an opaque surface. Glass cards retain their
    // production alpha tokens and are tested over the declared app backdrops.
    final Color surface = Color.alphaBlend(palette.cardBottom, palette.page);
    final Color raised = Color.alphaBlend(palette.cardTop, palette.page);
    final Color sealed = Color.alphaBlend(palette.sealedBottom, palette.page);
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: palette.accent,
          brightness: palette.brightness,
        ).copyWith(
          primary: palette.accent,
          onPrimary: palette.onAccent,
          primaryContainer: sealed,
          onPrimaryContainer: palette.honestyText,
          secondary: palette.inkMuted,
          onSecondary: palette.page,
          secondaryContainer: raised,
          onSecondaryContainer: palette.ink,
          tertiary: palette.honestySeal,
          onTertiary: palette.page,
          tertiaryContainer: sealed,
          onTertiaryContainer: palette.honestyText,
          surface: surface,
          onSurface: palette.ink,
          onSurfaceVariant: palette.textSecondary,
          surfaceDim: palette.page,
          surfaceBright: raised,
          surfaceContainerLowest: palette.page,
          surfaceContainerLow: surface,
          surfaceContainer: surface,
          surfaceContainerHigh: raised,
          surfaceContainerHighest: raised,
          outline: palette.textTertiary,
          outlineVariant: palette.cardBorder,
          error: palette.error,
          onError: palette.onError,
          errorContainer: palette.errorContainer,
          onErrorContainer: palette.onErrorContainer,
          inverseSurface: palette.ink,
          onInverseSurface: palette.page,
          inversePrimary: palette.page,
          surfaceTint: Colors.transparent,
          shadow: palette.shadow,
        );
    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      colorScheme: scheme,
    );
    final TextTheme text = base.textTheme.apply(
      fontFamily: GravitaType._publicSans,
      bodyColor: palette.ink,
      displayColor: palette.ink,
    );
    final WidgetStateProperty<Color?> foreground =
        WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) => states.contains(WidgetState.disabled)
              ? palette.disabledInk
              : palette.accent,
        );
    final WidgetStateProperty<Color?> overlay =
        WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) => states.contains(WidgetState.disabled)
              ? Colors.transparent
              : palette.accent.withValues(
                  alpha: states.contains(WidgetState.pressed) ? 0.12 : 0.06,
                ),
        );
    final ButtonStyle commonButton = ButtonStyle(
      foregroundColor: foreground,
      overlayColor: overlay,
      minimumSize: const WidgetStatePropertyAll<Size>(Size(48, 52)),
      textStyle: WidgetStatePropertyAll<TextStyle>(
        GravitaType.body(size: 15, weight: FontWeight.w500),
      ),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder()),
      side: WidgetStateProperty.resolveWith<BorderSide?>(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.focused) &&
                !states.contains(WidgetState.disabled)
            ? BorderSide(color: palette.focusRing, width: 3)
            : BorderSide.none,
      ),
    );
    final ButtonStyle filledButton = commonButton.copyWith(
      foregroundColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) => states.contains(WidgetState.disabled)
            ? palette.disabledInk
            : palette.onAccent,
      ),
      backgroundColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) => states.contains(WidgetState.disabled)
            ? palette.disabledSurface
            : states.contains(WidgetState.hovered)
            ? palette.accentHover
            : palette.accent,
      ),
      overlayColor: WidgetStatePropertyAll<Color>(
        palette.onAccent.withValues(alpha: 0.08),
      ),
      // The inset focus edge contrasts with the filled control itself. Other
      // controls use focusRing against their surrounding Material surface.
      side: WidgetStateProperty.resolveWith<BorderSide?>(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.focused) &&
                !states.contains(WidgetState.disabled)
            ? BorderSide(color: palette.onAccent, width: 3)
            : BorderSide.none,
      ),
    );
    final OutlineInputBorder inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: palette.textTertiary),
    );
    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[palette],
      scaffoldBackgroundColor: palette.page,
      canvasColor: surface,
      cardColor: surface,
      disabledColor: palette.disabledInk,
      dividerColor: palette.cardBorder,
      focusColor: palette.focusRing.withValues(alpha: 0.12),
      hoverColor: palette.accent.withValues(alpha: 0.06),
      highlightColor: palette.accent.withValues(alpha: 0.1),
      splashColor: palette.accent.withValues(alpha: 0.12),
      shadowColor: palette.shadow,
      textTheme: text,
      iconTheme: IconThemeData(color: palette.inkMuted),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: palette.ink,
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: GravitaType.display(size: 20, color: palette.ink),
      ),
      filledButtonTheme: FilledButtonThemeData(style: filledButton),
      elevatedButtonTheme: ElevatedButtonThemeData(style: filledButton),
      textButtonTheme: TextButtonThemeData(style: commonButton),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: commonButton.copyWith(
          side: WidgetStateProperty.resolveWith<BorderSide?>(
            (Set<WidgetState> states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? palette.disabledInk
                  : states.contains(WidgetState.focused)
                  ? palette.focusRing
                  : palette.textTertiary,
              width: states.contains(WidgetState.focused) ? 3 : 1,
            ),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: commonButton.copyWith(
          foregroundColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) => states.contains(WidgetState.disabled)
                ? palette.disabledInk
                : palette.inkMuted,
          ),
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: palette.shadow,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: raised,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GravitaType.display(size: 22, color: palette.ink),
        contentTextStyle: GravitaType.body(color: palette.ink),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: palette.textTertiary,
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: palette.ink,
        contentTextStyle: GravitaType.body(color: palette.page),
        actionTextColor: palette.page,
        disabledActionTextColor: palette.page,
        closeIconColor: palette.page,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: surface,
        labelStyle: GravitaType.body(color: palette.textSecondary),
        hintStyle: GravitaType.body(color: palette.textSecondary),
        helperStyle: GravitaType.body(size: 12, color: palette.textSecondary),
        errorStyle: GravitaType.body(size: 12, color: palette.error),
        floatingLabelStyle: GravitaType.body(color: palette.inkMuted),
        prefixIconColor: palette.inkMuted,
        suffixIconColor: palette.inkMuted,
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: palette.disabledInk),
        ),
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: palette.focusRing, width: 3),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: palette.error, width: 2),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: palette.error, width: 3),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: sealed,
        disabledColor: palette.disabledSurface,
        secondarySelectedColor: sealed,
        labelStyle: GravitaType.body(color: palette.ink),
        secondaryLabelStyle: GravitaType.body(color: palette.honestyText),
        checkmarkColor: palette.honestyText,
        deleteIconColor: palette.inkMuted,
        side: BorderSide(color: palette.textTertiary),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: sealed,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (Set<WidgetState> states) => GravitaType.body(
            size: 12,
            color: states.contains(WidgetState.disabled)
                ? palette.disabledInk
                : states.contains(WidgetState.selected)
                ? palette.honestyText
                : palette.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
          (Set<WidgetState> states) => IconThemeData(
            color: states.contains(WidgetState.disabled)
                ? palette.disabledInk
                : states.contains(WidgetState.selected)
                ? palette.honestyText
                : palette.textSecondary,
          ),
        ),
      ),
      bottomNavigationBarTheme: base.bottomNavigationBarTheme.copyWith(
        backgroundColor: surface,
        selectedItemColor: palette.honestyText,
        unselectedItemColor: palette.textSecondary,
      ),
      listTileTheme: base.listTileTheme.copyWith(
        textColor: palette.ink,
        iconColor: palette.inkMuted,
        selectedColor: palette.honestyText,
        selectedTileColor: sealed,
      ),
      dividerTheme: DividerThemeData(color: palette.cardBorder, thickness: 1),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.accent,
        selectionColor: palette.accent.withValues(alpha: 0.2),
        selectionHandleColor: palette.accent,
      ),
      progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
        color: palette.accent,
        linearTrackColor: palette.disabledSurface,
        circularTrackColor: palette.disabledSurface,
      ),
      tooltipTheme: base.tooltipTheme.copyWith(
        decoration: BoxDecoration(
          color: palette.ink,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GravitaType.body(size: 12, color: palette.page),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: GravitaPageTransitionsBuilder(),
          TargetPlatform.iOS: GravitaPageTransitionsBuilder(
            delegate: CupertinoPageTransitionsBuilder(),
          ),
          TargetPlatform.macOS: GravitaPageTransitionsBuilder(
            delegate: CupertinoPageTransitionsBuilder(),
          ),
          TargetPlatform.windows: GravitaPageTransitionsBuilder(),
          TargetPlatform.linux: GravitaPageTransitionsBuilder(),
          TargetPlatform.fuchsia: GravitaPageTransitionsBuilder(),
        },
      ),
    );
  }
}
