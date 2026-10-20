import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/theme.dart';

// These tests consume the shipping ThemeData, palette, widget decorations and
// resolved component states. No test palette or copied colour values are used.
double _contrast(Color foreground, Color background) {
  final Color painted = Color.alphaBlend(foreground, background);
  final double first = painted.computeLuminance();
  final double second = background.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

void _expectContrast(
  String role,
  Color foreground,
  Color background, {
  double minimum = 4.5,
}) {
  expect(
    _contrast(foreground, background),
    greaterThanOrEqualTo(minimum),
    reason: '$role must remain readable on its painted surface',
  );
}

Map<String, Color> _colors(GravitaPalette palette) => <String, Color>{
  'page': palette.page,
  'surfaceTop': palette.surfaceTop,
  'surfaceBottom': palette.surfaceBottom,
  'ink': palette.ink,
  'inkMuted': palette.inkMuted,
  'textSecondary': palette.textSecondary,
  'textTertiary': palette.textTertiary,
  'accent': palette.accent,
  'accentHover': palette.accentHover,
  'honestySeal': palette.honestySeal,
  'honestyText': palette.honestyText,
  'hairline': palette.hairline,
  'sessionStage': palette.sessionStage,
  'sessionStageDeep': palette.sessionStageDeep,
  'sessionCamera': palette.sessionCamera,
  'sessionInkOnDark': palette.sessionInkOnDark,
  'sessionInkMutedOnDark': palette.sessionInkMutedOnDark,
  'sessionSheetSealed': palette.sessionSheetSealed,
  'onAccent': palette.onAccent,
  'cardTop': palette.cardTop,
  'cardBottom': palette.cardBottom,
  'cardBorder': palette.cardBorder,
  'sealedTop': palette.sealedTop,
  'sealedBottom': palette.sealedBottom,
  'shadow': palette.shadow,
  'focusRing': palette.focusRing,
  'disabledInk': palette.disabledInk,
  'disabledSurface': palette.disabledSurface,
  'error': palette.error,
  'onError': palette.onError,
  'errorContainer': palette.errorContainer,
  'onErrorContainer': palette.onErrorContainer,
};

Iterable<Color> _cardSamples(
  GravitaPalette palette, {
  required bool sealed,
}) sync* {
  for (final Color backdrop in <Color>[
    palette.page,
    palette.surfaceTop,
    palette.surfaceBottom,
  ]) {
    for (final double t in <double>[0, 0.25, 0.5, 0.75, 1]) {
      yield Color.alphaBlend(
        Color.lerp(
          sealed ? palette.sealedTop : palette.cardTop,
          sealed ? palette.sealedBottom : palette.cardBottom,
          t,
        )!,
        backdrop,
      );
    }
  }
}

Widget _host(
  ThemeData theme,
  Widget child, {
  bool reduceMotion = false,
  bool accessibleNavigation = false,
}) => MaterialApp(
  theme: theme,
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduceMotion,
      accessibleNavigation: accessibleNavigation,
    ),
    child: Scaffold(body: child),
  ),
);

BoxDecoration _cardDecoration(WidgetTester tester, Finder card) => tester
    .widgetList<Container>(
      find.descendant(of: card, matching: find.byType(Container)),
    )
    .map((Container widget) => widget.decoration)
    .whereType<BoxDecoration>()
    .singleWhere((BoxDecoration decoration) => decoration.gradient != null);

void main() {
  test('palette copies and interpolation cover every shipping colour', () {
    const GravitaPalette light = GravitaPalette.light;
    const GravitaPalette dark = GravitaPalette.dark;
    expect(_colors(light.copyWith()), _colors(light));
    expect(_colors(light.lerp(dark, 0)), _colors(light));
    expect(_colors(light.lerp(dark, 1)), _colors(dark));
    expect(identical(light.lerp(null, 0.5), light), isTrue);
    final GravitaPalette middle = light.lerp(dark, 0.5);
    for (final String key in _colors(light).keys) {
      expect(
        _colors(middle)[key],
        Color.lerp(_colors(light)[key], _colors(dark)[key], 0.5),
        reason: '$key must animate with the active theme',
      );
    }
    final GravitaPalette changed = light.copyWith(ink: dark.ink);
    expect(changed.ink, dark.ink);
    expect(light.ink, GravitaColors.ink);
    expect(changed.page, light.page);
    // Camera exposure stays dark while app sheets follow the selected mode.
    expect(dark.sessionCamera, light.sessionCamera);
    expect(dark.sessionStage, light.sessionStage);
    expect(dark.sessionSheetSealed, isNot(light.sessionSheetSealed));
  });

  for (final (String name, ThemeData theme) in <(String, ThemeData)>[
    ('light', GravitaTheme.light),
    ('dark', GravitaTheme.dark),
  ]) {
    final GravitaPalette palette = theme.extension<GravitaPalette>()!;

    test('$name text, glass, seals and camera surfaces retain contrast', () {
      final Map<String, Color> text = <String, Color>{
        'body': palette.ink,
        'muted': palette.inkMuted,
        'secondary': palette.textSecondary,
        'criterion': palette.accent,
        'hover': palette.accentHover,
        'seal': palette.honestySeal,
        'honesty': palette.honestyText,
      };
      for (final Color background in <Color>[
        palette.page,
        palette.surfaceTop,
        palette.surfaceBottom,
        palette.sessionSheetSealed,
        ..._cardSamples(palette, sealed: false),
        ..._cardSamples(palette, sealed: true),
      ]) {
        for (final MapEntry<String, Color> role in text.entries) {
          _expectContrast('$name ${role.key}', role.value, background);
        }
        _expectContrast(
          '$name non-text mark',
          palette.textTertiary,
          background,
          minimum: 3,
        );
        _expectContrast(
          '$name focus edge',
          palette.focusRing,
          background,
          minimum: 3,
        );
      }
      for (final Color background in <Color>[
        palette.sessionStage,
        palette.sessionStageDeep,
        palette.sessionCamera,
      ]) {
        _expectContrast(
          '$name camera text',
          palette.sessionInkOnDark,
          background,
        );
        _expectContrast(
          '$name camera metadata',
          palette.sessionInkMutedOnDark,
          background,
        );
      }
      _expectContrast(
        '$name disabled label',
        palette.disabledInk,
        palette.disabledSurface,
      );
    });

    test(
      '$name Material roles resolve readable error, focus and disabled states',
      () {
        final ColorScheme scheme = theme.colorScheme;
        _expectContrast(
          '$name Material body',
          scheme.onSurface,
          scheme.surface,
        );
        _expectContrast(
          '$name Material secondary',
          scheme.onSurfaceVariant,
          scheme.surface,
        );
        _expectContrast('$name error message', scheme.error, scheme.surface);
        _expectContrast('$name error fill', scheme.onError, scheme.error);
        _expectContrast(
          '$name error panel',
          scheme.onErrorContainer,
          scheme.errorContainer,
        );
        expect(scheme.error, palette.error);
        expect(scheme.onSurface, palette.ink);
        expect(theme.textTheme.bodyMedium!.color, palette.ink);
        expect(theme.textTheme.displayLarge!.color, palette.ink);
        expect(theme.appBarTheme.foregroundColor, palette.ink);
        expect(theme.disabledColor, palette.disabledInk);

        final ButtonStyle filled = theme.filledButtonTheme.style!;
        expect(
          filled.foregroundColor!.resolve(<WidgetState>{WidgetState.disabled}),
          palette.disabledInk,
        );
        expect(
          filled.backgroundColor!.resolve(<WidgetState>{WidgetState.disabled}),
          palette.disabledSurface,
        );
        for (final Set<WidgetState> states in <Set<WidgetState>>[
          <WidgetState>{},
          <WidgetState>{WidgetState.hovered},
          <WidgetState>{WidgetState.pressed},
          <WidgetState>{WidgetState.focused},
          <WidgetState>{WidgetState.disabled},
        ]) {
          final Color background = filled.backgroundColor!.resolve(states)!;
          final Color foreground = filled.foregroundColor!.resolve(states)!;
          // Disabled controls are WCAG-exempt, but Gravita still keeps the
          // unavailable action legible rather than fading its explanation away.
          _expectContrast(
            '$name filled $states',
            foreground,
            states.contains(WidgetState.disabled)
                ? background
                : Color.alphaBlend(
                    filled.overlayColor!.resolve(states)!,
                    background,
                  ),
          );
          final Size minimum = filled.minimumSize!.resolve(states)!;
          expect(minimum.width, greaterThanOrEqualTo(48));
          expect(minimum.height, greaterThanOrEqualTo(48));
        }
        final BorderSide filledFocus = filled.side!.resolve(<WidgetState>{
          WidgetState.focused,
        })!;
        expect(filledFocus.width, greaterThanOrEqualTo(2));
        _expectContrast(
          '$name inset filled focus',
          filledFocus.color,
          filled.backgroundColor!.resolve(<WidgetState>{WidgetState.focused})!,
          minimum: 3,
        );

        for (final ButtonStyle style in <ButtonStyle>[
          theme.textButtonTheme.style!,
          theme.outlinedButtonTheme.style!,
          theme.iconButtonTheme.style!,
        ]) {
          _expectContrast(
            '$name unfilled label',
            style.foregroundColor!.resolve(<WidgetState>{})!,
            scheme.surface,
          );
          _expectContrast(
            '$name unfilled disabled',
            style.foregroundColor!.resolve(<WidgetState>{
              WidgetState.disabled,
            })!,
            scheme.surface,
          );
          final BorderSide focus = style.side!.resolve(<WidgetState>{
            WidgetState.focused,
          })!;
          expect(focus.width, greaterThanOrEqualTo(2));
          _expectContrast(
            '$name unfilled focus',
            focus.color,
            scheme.surface,
            minimum: 3,
          );
        }

        final Color inputSurface = theme.inputDecorationTheme.fillColor!;
        _expectContrast(
          '$name input hint',
          theme.inputDecorationTheme.hintStyle!.color!,
          inputSurface,
        );
        _expectContrast(
          '$name input error',
          theme.inputDecorationTheme.errorStyle!.color!,
          inputSurface,
        );
        _expectContrast(
          '$name input focus',
          theme.inputDecorationTheme.focusedBorder!.borderSide.color,
          inputSurface,
          minimum: 3,
        );
        _expectContrast(
          '$name input error edge',
          theme.inputDecorationTheme.errorBorder!.borderSide.color,
          inputSurface,
          minimum: 3,
        );
        _expectContrast(
          '$name dialog',
          theme.dialogTheme.contentTextStyle!.color!,
          theme.dialogTheme.backgroundColor!,
        );
        _expectContrast(
          '$name snackbar',
          theme.snackBarTheme.contentTextStyle!.color!,
          theme.snackBarTheme.backgroundColor!,
        );
        _expectContrast(
          '$name snackbar action',
          theme.snackBarTheme.actionTextColor!,
          theme.snackBarTheme.backgroundColor!,
        );
        _expectContrast(
          '$name bottom sheet',
          palette.ink,
          theme.bottomSheetTheme.modalBackgroundColor!,
        );
        _expectContrast(
          '$name chip',
          theme.chipTheme.labelStyle!.color!,
          theme.chipTheme.backgroundColor!,
        );
        _expectContrast(
          '$name selected chip',
          theme.chipTheme.secondaryLabelStyle!.color!,
          theme.chipTheme.selectedColor!,
        );
        _expectContrast(
          '$name navigation',
          theme.navigationBarTheme.labelTextStyle!
              .resolve(<WidgetState>{})!
              .color!,
          theme.navigationBarTheme.backgroundColor!,
        );
        _expectContrast(
          '$name selected navigation',
          theme.navigationBarTheme.labelTextStyle!.resolve(<WidgetState>{
            WidgetState.selected,
          })!.color!,
          theme.navigationBarTheme.indicatorColor!,
        );
      },
    );

    testWidgets('$name Card and Pill paint their context palette', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          theme,
          Column(
            children: <Widget>[
              const GravitaCard(
                key: ValueKey<String>('glass'),
                child: Text('Glass'),
              ),
              const GravitaCard(
                key: ValueKey<String>('sealed'),
                sealed: true,
                child: Text('Seal'),
              ),
              const GravitaPill(label: 'STATE'),
              const GravitaPill(label: 'OUTLINE', filled: false),
              GravitaPill(label: 'EXPLICIT', tone: palette.honestySeal),
            ],
          ),
        ),
      );
      for (final (String key, List<Color> colors) in <(String, List<Color>)>[
        ('glass', <Color>[palette.cardTop, palette.cardBottom]),
        ('sealed', <Color>[palette.sealedTop, palette.sealedBottom]),
      ]) {
        final Finder card = find.byKey(ValueKey<String>(key));
        final BoxDecoration decoration = _cardDecoration(tester, card);
        expect((decoration.gradient! as LinearGradient).colors, colors);
        final DecoratedBox outer = tester.widget<DecoratedBox>(
          find.descendant(of: card, matching: find.byType(DecoratedBox)).first,
        );
        expect(
          (outer.decoration as BoxDecoration).boxShadow!.single.color,
          palette.shadow,
        );
        expect(
          find.descendant(of: card, matching: find.byType(BackdropFilter)),
          key == 'glass' ? findsOneWidget : findsNothing,
        );
      }
      expect(
        tester.widget<Text>(find.text('STATE')).style!.color,
        palette.accent,
      );
      expect(
        tester.widget<Text>(find.text('OUTLINE')).style!.color,
        palette.accent,
      );
      expect(
        tester.widget<Text>(find.text('EXPLICIT')).style!.color,
        palette.honestySeal,
      );
      final Finder pill = find.ancestor(
        of: find.text('STATE'),
        matching: find.byType(GravitaPill),
      );
      final Container painted = tester.widget<Container>(
        find.descendant(of: pill, matching: find.byType(Container)),
      );
      final BoxDecoration decoration = painted.decoration! as BoxDecoration;
      _expectContrast(
        '$name painted status pill',
        palette.accent,
        Color.alphaBlend(decoration.color!, palette.page),
      );
    });
  }

  testWidgets(
    'palette is scoped, with deterministic fallback and no global state',
    (WidgetTester tester) async {
      late GravitaPalette light;
      late GravitaPalette dark;
      late GravitaPalette custom;
      final GravitaPalette alternate = GravitaPalette.dark.copyWith(
        ink: GravitaPalette.dark.accent,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: <Widget>[
              Theme(
                data: ThemeData.light(),
                child: Builder(
                  builder: (BuildContext context) {
                    light = GravitaColors.of(context);
                    return const SizedBox();
                  },
                ),
              ),
              Theme(
                data: ThemeData.dark(),
                child: Builder(
                  builder: (BuildContext context) {
                    dark = GravitaColors.of(context);
                    return const SizedBox();
                  },
                ),
              ),
              Theme(
                data: GravitaTheme.dark.copyWith(
                  extensions: <ThemeExtension<dynamic>>[alternate],
                ),
                child: Builder(
                  builder: (BuildContext context) {
                    custom = GravitaColors.of(context);
                    return const SizedBox();
                  },
                ),
              ),
            ],
          ),
        ),
      );
      expect(identical(light, GravitaPalette.light), isTrue);
      expect(identical(dark, GravitaPalette.dark), isTrue);
      expect(identical(custom, alternate), isTrue);
      expect(GravitaColors.ink, GravitaPalette.light.ink);
      expect(GravitaColors.page, GravitaPalette.light.page);
    },
  );

  testWidgets('type defaults use context and retain legacy light calls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        GravitaTheme.dark,
        Builder(
          builder: (BuildContext context) {
            final GravitaPalette palette = GravitaColors.of(context);
            expect(GravitaType.display(context: context).color, palette.ink);
            expect(GravitaType.body(context: context).color, palette.ink);
            expect(
              GravitaType.mono(context: context).color,
              palette.textSecondary,
            );
            expect(
              GravitaType.body(
                context: context,
                color: palette.honestyText,
              ).color,
              palette.honestyText,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    expect(GravitaType.display().color, GravitaType.defaultDisplayColor);
    expect(GravitaType.body().color, GravitaType.defaultBodyColor);
    expect(GravitaType.mono().color, GravitaType.defaultMonoColor);
  });

  testWidgets('reduced motion keeps card tint and removes blur and shadows', (
    WidgetTester tester,
  ) async {
    final ThemeData theme = GravitaTheme.dark;
    await tester.pumpWidget(
      _host(
        theme,
        const GravitaCard(child: Text('Readable')),
        reduceMotion: true,
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    final BoxDecoration decoration = _cardDecoration(
      tester,
      find.byType(GravitaCard),
    );
    expect((decoration.gradient! as LinearGradient).colors, <Color>[
      GravitaPalette.dark.cardTop,
      GravitaPalette.dark.cardBottom,
    ]);
    final Iterable<DecoratedBox> decorated = tester.widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(GravitaCard),
        matching: find.byType(DecoratedBox),
      ),
    );
    for (final DecoratedBox widget in decorated) {
      final Decoration value = widget.decoration;
      if (value is BoxDecoration) {
        expect(value.boxShadow ?? <BoxShadow>[], isEmpty);
      }
    }
  });

  testWidgets('reduced motion skips all platform transitions and duration', (
    WidgetTester tester,
  ) async {
    final MaterialPageRoute<void> route = MaterialPageRoute<void>(
      builder: (BuildContext context) => const SizedBox(),
    );
    const Animation<double> animation = AlwaysStoppedAnimation<double>(0.5);
    const Widget child = SizedBox(key: ValueKey<String>('route-content'));
    for (final (bool disabledAnimations, bool accessibleNavigation)
        in <(bool, bool)>[(true, false), (false, false), (false, true)]) {
      final bool reduced = disabledAnimations || accessibleNavigation;
      await tester.pumpWidget(
        _host(
          GravitaTheme.dark,
          Builder(
            builder: (BuildContext context) {
              expect(GravitaMotion.reduceMotion(context), reduced);
              expect(GravitaMotion.effectsEnabled(context), !reduced);
              expect(
                GravitaMotion.duration(
                  context,
                  normal: const Duration(milliseconds: 275),
                ),
                reduced ? Duration.zero : const Duration(milliseconds: 275),
              );
              if (reduced) {
                for (final PageTransitionsBuilder builder in Theme.of(
                  context,
                ).pageTransitionsTheme.builders.values) {
                  expect(
                    identical(
                      builder.buildTransitions<void>(
                        route,
                        context,
                        animation,
                        animation,
                        child,
                      ),
                      child,
                    ),
                    isTrue,
                  );
                }
              } else {
                expect(
                  identical(
                    const GravitaPageTransitionsBuilder()
                        .buildTransitions<void>(
                          route,
                          context,
                          animation,
                          animation,
                          child,
                        ),
                    child,
                  ),
                  isFalse,
                );
              }
              return child;
            },
          ),
          reduceMotion: disabledAnimations,
          accessibleNavigation: accessibleNavigation,
        ),
      );
    }
    route.dispose();
  });
}
