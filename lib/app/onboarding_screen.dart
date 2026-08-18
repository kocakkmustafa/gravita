import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'onboarding_strings.dart';
import 'theme.dart';

/// İlk-açılış akışı — O1 (Value) → O2 (Safety consent) → O5 (Camera).
///
/// `docs/PRD.md` §3.1 / `docs/design/UI-BRIEF.md` §3.1'in DAR bir dilimi;
/// kapsam sınırının gerekçesi `onboarding_strings.dart`ın başında.
///
/// ⚠️ O2 KİLİTLİ (UI-BRIEF): "açık onay olmadan devam YOK, dismiss
/// edilemez" — bu widget'ta geri tuşu/kaydırma ile atlanamaz, yalnız
/// [OnboardingStrings.safetyConsent] düğmesiyle ilerler.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({required this.onComplete, super.key});

  final Future<void> Function() onComplete;

  static const Key valueContinueKey = Key('onboarding.value.continue');
  static const Key safetyConsentKey = Key('onboarding.safety.consent');
  static const Key cameraAllowKey = Key('onboarding.camera.allow');
  static const Key cameraContinueWithoutKey = Key(
    'onboarding.camera.continueWithout',
  );
  static const Key cameraDeniedKey = Key('onboarding.camera.denied');

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

enum _Step { value, safety, camera }

class _OnboardingFlowState extends State<OnboardingFlow> {
  _Step _step = _Step.value;
  bool _cameraDenied = false;
  bool _requesting = false;

  Future<void> _requestCamera() async {
    setState(() => _requesting = true);
    final PermissionStatus status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted) {
      await widget.onComplete();
      return;
    }
    setState(() {
      _requesting = false;
      _cameraDenied = true;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    // O2 dismiss edilemez — geri tuşu adımı ATLAYAMAZ (UI-BRIEF §3.1 O2).
    canPop: false,
    child: Scaffold(
      backgroundColor: GravitaColors.page,
      body: SafeArea(
        child: switch (_step) {
          _Step.value => _ValueStep(
            key: const Key('onboarding.step.value'),
            onContinue: () => setState(() => _step = _Step.safety),
          ),
          _Step.safety => _SafetyStep(
            key: const Key('onboarding.step.safety'),
            onConsent: () => setState(() => _step = _Step.camera),
          ),
          _Step.camera => _CameraStep(
            key: const Key('onboarding.step.camera'),
            requesting: _requesting,
            denied: _cameraDenied,
            onAllow: _requestCamera,
            onContinueWithout: () async => widget.onComplete(),
          ),
        },
      ),
    ),
  );
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.primaryKey,
    required this.onPrimary,
    this.busy = false,
  });

  final String title;
  final List<Widget> body;
  final String primaryLabel;
  final Key primaryKey;
  final VoidCallback? onPrimary;
  final bool busy;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: GravitaType.display(size: 26)),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: body,
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: primaryKey,
            onPressed: busy ? null : onPrimary,
            style: FilledButton.styleFrom(
              backgroundColor: GravitaColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(primaryLabel),
          ),
        ),
      ],
    ),
  );
}

class _ValueStep extends StatelessWidget {
  const _ValueStep({required this.onContinue, super.key});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => _StepScaffold(
    title: OnboardingStrings.valueTitle,
    primaryLabel: OnboardingStrings.valueContinue,
    primaryKey: OnboardingFlow.valueContinueKey,
    onPrimary: onContinue,
    body: <Widget>[
      Text(OnboardingStrings.valueWhatWeDo, style: GravitaType.body(size: 16)),
      const SizedBox(height: 18),
      Text(
        OnboardingStrings.valueWhatWeDont,
        style: GravitaType.body(size: 14, color: GravitaColors.textSecondary),
      ),
    ],
  );
}

class _SafetyStep extends StatelessWidget {
  const _SafetyStep({required this.onConsent, super.key});
  final VoidCallback onConsent;

  @override
  Widget build(BuildContext context) => _StepScaffold(
    title: OnboardingStrings.safetyTitle,
    primaryLabel: OnboardingStrings.safetyConsent,
    primaryKey: OnboardingFlow.safetyConsentKey,
    onPrimary: onConsent,
    body: <Widget>[
      Text(
        OnboardingStrings.safetyDisclaimer,
        style: GravitaType.body(size: 16),
      ),
      const SizedBox(height: 18),
      Text(
        OnboardingStrings.safetySpaceRule,
        style: GravitaType.body(size: 14, color: GravitaColors.textSecondary),
      ),
    ],
  );
}

class _CameraStep extends StatelessWidget {
  const _CameraStep({
    required this.requesting,
    required this.denied,
    required this.onAllow,
    required this.onContinueWithout,
    super.key,
  });

  final bool requesting;
  final bool denied;
  final VoidCallback onAllow;
  final VoidCallback onContinueWithout;

  @override
  Widget build(BuildContext context) => _StepScaffold(
    title: denied
        ? OnboardingStrings.cameraDeniedTitle
        : OnboardingStrings.cameraTitle,
    primaryLabel: denied
        ? OnboardingStrings.cameraContinueWithout
        : OnboardingStrings.cameraAllow,
    primaryKey: denied
        ? OnboardingFlow.cameraContinueWithoutKey
        : OnboardingFlow.cameraAllowKey,
    onPrimary: denied ? onContinueWithout : onAllow,
    busy: requesting,
    body: <Widget>[
      Text(
        denied
            ? OnboardingStrings.cameraDeniedBody
            : OnboardingStrings.cameraRationale,
        key: denied ? OnboardingFlow.cameraDeniedKey : null,
        style: GravitaType.body(size: 16),
      ),
    ],
  );
}
