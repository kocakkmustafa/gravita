/// Teaching access and camera availability are separate product capabilities.
/// A linked lesson or a catalogue status alone cannot satisfy the camera goal.
final class FoundationCoverage {
  FoundationCoverage({
    required Iterable<String> catalogueIds,
    required Iterable<String> startableCameraIds,
    required Iterable<String> practiceGuideIds,
    required Iterable<String> readingGuideIds,
  }) : catalogueIds = Set.unmodifiable(catalogueIds),
       configuredCameraIds = Set.unmodifiable(startableCameraIds),
       practiceGuideIds = Set.unmodifiable(practiceGuideIds),
       readingGuideIds = Set.unmodifiable(readingGuideIds) {
    if (!this.catalogueIds.containsAll(configuredCameraIds) ||
        !this.catalogueIds.containsAll(this.practiceGuideIds) ||
        !this.catalogueIds.containsAll(this.readingGuideIds)) {
      throw StateError('Coverage refers to an unknown catalogue movement');
    }
  }

  // Existing roadmap target; this is not a newly inferred accuracy threshold.
  static const int cameraFoundationTarget = 20;

  /// Configured engine contracts only: not paid access or field validation.
  final Set<String> catalogueIds,
      configuredCameraIds,
      practiceGuideIds,
      readingGuideIds;
  Set<String> get cameraUnavailableIds =>
      catalogueIds.difference(configuredCameraIds);
  bool get configuredCameraTargetReached =>
      configuredCameraIds.length >= cameraFoundationTarget;
  int get cameraShortfall => configuredCameraTargetReached
      ? 0
      : cameraFoundationTarget - configuredCameraIds.length;
}
