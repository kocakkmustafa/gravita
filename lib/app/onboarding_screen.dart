import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_locale.dart';
import 'camera_release_policy.dart';
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
  const OnboardingFlow({required this.onComplete, super.key})
    : _permissionFlowAvailable = motionPaidCameraLaunchEnabled;

  /// Isolated coverage of the later permission flow. Production onboarding
  /// always uses the shared release policy through the default constructor.
  @visibleForTesting
  const OnboardingFlow.permissionTest({required this.onComplete, super.key})
    : _permissionFlowAvailable = true;

  final Future<void> Function() onComplete;
  final bool _permissionFlowAvailable;

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
  bool _completing = false;

  Future<void> _complete() async {
    if (_completing || !mounted) return;
    setState(() => _completing = true);
    try {
      await widget.onComplete();
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Future<void> _requestCamera() async {
    if (_requesting || _completing || !mounted) return;
    if (!widget._permissionFlowAvailable) {
      await _complete();
      return;
    }
    setState(() => _requesting = true);
    try {
      final PermissionStatus status;
      try {
        status = await Permission.camera.request();
      } on Object {
        // A failed platform request grants nothing. Keep optional onboarding
        // usable through its existing explicit continue-without action.
        if (mounted) setState(() => _cameraDenied = true);
        return;
      }
      if (!mounted) return;
      if (status.isGranted) {
        await _complete();
      } else {
        setState(() => _cameraDenied = true);
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    // O2 dismiss edilemez — geri tuşu adımı ATLAYAMAZ (UI-BRIEF §3.1 O2).
    canPop: false,
    child: Scaffold(
      backgroundColor: GravitaColors.of(context).page,
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
            available: widget._permissionFlowAvailable,
            requesting: _requesting || _completing,
            denied: _cameraDenied,
            onAllow: _requestCamera,
            onContinueWithout: _complete,
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
    this.secondaryAction,
  });

  final String title;
  final List<Widget> body;
  final String primaryLabel;
  final Key primaryKey;
  final VoidCallback? onPrimary;
  final bool busy;
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: GravitaType.display(context: context, size: 26),
                ),
                const SizedBox(height: 20),
                ...body,
              ],
            ),
          ),
        ),
        if (secondaryAction != null) ...<Widget>[
          secondaryAction!,
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: primaryKey,
            onPressed: busy ? null : onPrimary,
            style: FilledButton.styleFrom(
              backgroundColor: GravitaColors.of(context).accent,
              foregroundColor: GravitaColors.of(context).onAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: busy
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: GravitaColors.of(context).disabledInk,
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
    title: localized(
      context,
      OnboardingStrings.valueTitle,
      'Gravita nedir, ne değildir?',
    ),
    primaryLabel: localized(
      context,
      OnboardingStrings.valueContinue,
      'Devam et',
    ),
    primaryKey: OnboardingFlow.valueContinueKey,
    onPrimary: onContinue,
    body: <Widget>[
      Text(
        localized(
          context,
          OnboardingStrings.valueWhatWeDo,
          'Misafir olarak 56 calisthenics dersini keşfet, kendi hızında çalış '
          've öz bildirimli öğrenme ilerlemeni bu cihazda kaydet. Canlı kamera '
          'seansları bu sürümde kullanılamıyor. Öğrenme ilerlemesi formuna puan '
          'vermez veya tekniğini doğrulamaz.',
        ),
        style: GravitaType.body(context: context, size: 16),
      ),
      const SizedBox(height: 18),
      Text(
        localized(
          context,
          OnboardingStrings.valueWhatWeDont,
          'Tıbbi araç değildir. Antrenörün yerini almaz. Düşmenizi '
          'önleyemez.',
        ),
        style: GravitaType.body(
          context: context,
          size: 14,
          color: GravitaColors.of(context).textSecondary,
        ),
      ),
    ],
  );
}

class _SafetyStep extends StatelessWidget {
  const _SafetyStep({required this.onConsent, super.key});
  final VoidCallback onConsent;

  @override
  Widget build(BuildContext context) => _StepScaffold(
    title: localized(context, OnboardingStrings.safetyTitle, 'Başlamadan önce'),
    primaryLabel: localized(
      context,
      OnboardingStrings.safetyConsent,
      'Anladım ve kabul ediyorum',
    ),
    primaryKey: OnboardingFlow.safetyConsentKey,
    onPrimary: onConsent,
    body: <Widget>[
      Text(
        localized(
          context,
          OnboardingStrings.safetyDisclaimer,
          'Gravita bir hareket çalışma aracıdır; tıbbi hizmet veya yüz '
          'yüze antrenörün yerini almaz. Düşmeyi önleyemez.',
        ),
        style: GravitaType.body(context: context, size: 16),
      ),
      const SizedBox(height: 18),
      Text(
        localized(
          context,
          OnboardingStrings.safetySpaceRule,
          'Başlamadan önce düz, kaymayan bir zemin seçin ve kol '
          'mesafenizdeki eşyaları kaldırın. Duvar gereken hareketlerde '
          'duvarın tamamı kamera kadrajında görünsün.',
        ),
        style: GravitaType.body(
          context: context,
          size: 14,
          color: GravitaColors.of(context).textSecondary,
        ),
      ),
    ],
  );
}

class _CameraStep extends StatelessWidget {
  const _CameraStep({
    required this.available,
    required this.requesting,
    required this.denied,
    required this.onAllow,
    required this.onContinueWithout,
    super.key,
  });

  final bool available;
  final bool requesting;
  final bool denied;
  final VoidCallback onAllow;
  final VoidCallback onContinueWithout;

  @override
  Widget build(BuildContext context) => _StepScaffold(
    title: !available
        ? localized(context, 'Camera unavailable', 'Kamera kapalı')
        : denied
        ? localized(
            context,
            OnboardingStrings.cameraDeniedTitle,
            'Kamera erişimi kapalı',
          )
        : localized(context, OnboardingStrings.cameraTitle, 'Kamera erişimi'),
    primaryLabel: !available || denied
        ? localized(
            context,
            OnboardingStrings.cameraContinueWithout,
            'Kamera izni vermeden devam et',
          )
        : localized(
            context,
            OnboardingStrings.cameraAllow,
            'Kameraya izin ver',
          ),
    primaryKey: !available || denied
        ? OnboardingFlow.cameraContinueWithoutKey
        : OnboardingFlow.cameraAllowKey,
    onPrimary: !available || denied ? onContinueWithout : onAllow,
    busy: requesting,
    secondaryAction: !available || denied
        ? null
        : SizedBox(
            width: double.infinity,
            child: TextButton(
              key: OnboardingFlow.cameraContinueWithoutKey,
              onPressed: requesting ? null : onContinueWithout,
              child: Text(
                localized(
                  context,
                  OnboardingStrings.cameraContinueWithout,
                  'Kamera izni vermeden devam et',
                ),
              ),
            ),
          ),
    body: <Widget>[
      Text(
        denied
            ? localized(
                context,
                OnboardingStrings.cameraDeniedBody,
                'Kamerayı daha sonra Ayarlar’dan açabilirsiniz. Kütüphaneyi '
                've dersleri kamera olmadan da inceleyebilirsiniz.',
              )
            : localized(
                context,
                OnboardingStrings.cameraRationale,
                'Kurs ve öz bildirimli ilerleme kamera izni gerektirmez. '
                'Canlı kamera seansları bu sürümde kullanılamıyor. İzin '
                'vermeden devam edebilirsin; görüntü kaydedilmez veya yüklenmez.',
              ),
        key: denied ? OnboardingFlow.cameraDeniedKey : null,
        style: GravitaType.body(context: context, size: 16),
      ),
    ],
  );
}
