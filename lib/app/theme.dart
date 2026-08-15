import 'dart:ui';

import 'package:flutter/material.dart';

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

abstract final class GravitaColors {
  GravitaColors._();

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

  /// Session screen is the app's one dark surface (`GravitaScreen.dc.html`:
  /// `const dark = screen === "session"`). Everything else in Gravita is
  /// light — this palette is scoped to that single exception, not promoted
  /// to a second app-wide theme.
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
    double size = 27,
    Color? color,
    FontWeight weight = FontWeight.w600,
    double height = 1.15,
  }) =>
      TextStyle(
        fontFamily: _publicSans,
        fontSize: size,
        height: height,
        fontWeight: weight,
        letterSpacing: -0.02 * size,
        color: color ?? defaultDisplayColor,
      );

  static TextStyle body({
    double size = 15,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double height = 1.6,
  }) =>
      TextStyle(
        fontFamily: _publicSans,
        fontSize: size,
        height: height,
        fontWeight: weight,
        color: color ?? defaultBodyColor,
      );

  /// Measurement/status language — criteria, units, timers, section
  /// eyebrows. `letterSpacingEm` mirrors the design's CSS `em` tracking,
  /// scaled by font size the way Choreia's [ChoreiaType.label] does.
  static TextStyle mono({
    double size = 11,
    Color? color,
    FontWeight weight = FontWeight.w500,
    double letterSpacingEm = 0.1,
  }) =>
      TextStyle(
        fontFamily: _robotoMono,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacingEm * size,
        // ⚠️ VARSAYILAN [defaultMonoColor] — eskiden [textTertiary] idi ve
        // bu, rengi ELLE vermeyen her çağıranı sessizce eşik-altı bir metne
        // düşürüyordu: kusurun varsayılan olması, en kolay çoğalma yolu.
        color: color ?? defaultMonoColor,
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
              ? <Color>[
                  const Color(0xFFFFF4F3).withValues(alpha: 0.85),
                  const Color(0xFFFAE7E5).withValues(alpha: 0.7),
                ]
              : <Color>[
                  Colors.white.withValues(alpha: 0.56),
                  Colors.white.withValues(alpha: 0.28),
                ],
        ),
        border: Border.all(
          color: sealed
              ? GravitaColors.honestySeal.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.7),
        ),
      ),
      child: child,
    );

    if (GravitaMaterial.cardBlur >= GravitaMaterial._blurEpsilon) {
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
          Container(height: 2.5, color: GravitaColors.honestySeal),
          body,
        ],
      );
    }

    // Shadow lives on THIS outer box, not the clipped one: a shadow inside
    // ClipRRect would be cropped flush at its own edge and disappear.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: GravitaColors.ink.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
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
    this.tone = GravitaColors.accent,
    this.filled = true,
  });

  final String label;
  final Color tone;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: filled ? tone.withValues(alpha: 0.1) : null,
          border:
              filled ? null : Border.all(color: tone.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: GravitaType.mono(size: 10, color: tone, weight: FontWeight.w600),
        ),
      );
}

// ── App theme ────────────────────────────────────────────────────────────

/// The MaterialApp theme — Gravita's light surface (Home/Library/Progress/
/// Profile/ContentFailure). The session screen is the one dark exception
/// and stays out of this ThemeData; see the file doc comment.
abstract final class GravitaTheme {
  GravitaTheme._();

  static ThemeData get light {
    final TextTheme base = ThemeData.light().textTheme.apply(
      fontFamily: GravitaType._publicSans,
      bodyColor: GravitaColors.ink,
      displayColor: GravitaColors.ink,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: GravitaColors.page,
      colorScheme: ColorScheme.fromSeed(
        seedColor: GravitaColors.accent,
        brightness: Brightness.light,
        surface: GravitaColors.page,
      ),
      textTheme: base,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: GravitaColors.ink,
        titleTextStyle: GravitaType.display(size: 20),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GravitaColors.accent,
          foregroundColor: Colors.white,
          textStyle: GravitaType.body(size: 15, weight: FontWeight.w500),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
