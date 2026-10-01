import 'package:motion_account/motion_account.dart'
    show motionPaidFeaturesAvailable;

/// Catalogue readiness does not grant camera access. The first-release
/// camera UI uses the same policy as the real shared-account launch guard.
/// Course learning and self-reported progress do not depend on this policy.
const bool motionPaidCameraLaunchEnabled = motionPaidFeaturesAvailable;
