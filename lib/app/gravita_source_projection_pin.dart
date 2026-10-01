/// App-owned calisthenics source identity. It is not a media release grant.
abstract final class GravitaSourceProjectionPin {
  static const appId = 'gravita';
  static const coursePath = 'content/courses/calisthenics.v1.json';
  static const slicePath = 'content/courses/gravita.source-slice.v1.json';
  static const projectionPath =
      'content/courses/gravita.source-projection.v1.json';

  static const courseSha256 =
      '15930d335f377c9f48e1c7285f1c44e25973b9cccb3167fa99cc9b8599889502';
  static const sliceSha256 =
      '97d1651db95f363b36045805d71fe3bd045ea3253b11198b04b3ee2409f90f38';
  static const projectionSha256 =
      'd7686dd01c9a2b0d59d3c63a7af9c7a667416730c389ce7980e6bc30aaaca91f';
  static const sourceCatalogSha256 =
      '791bfea8e1479307794bcf8799cf703a7a840bcd3058c1a0d7fdf065d32d8594';
  // Preproduction source manifest, not a signed release root.
  static const sourceManifestSha256 =
      'd887683c9a9b9bdb8d4ab7c51cdc5a5b4b4de6a918079e4cfd9cf543e9751e60';

  static const lessonCount = 56;
  static const sceneCount = 392;
  static const variantCount = 392;
  static const heldCount = 1;
}
