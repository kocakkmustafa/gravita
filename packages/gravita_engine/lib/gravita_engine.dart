/// Gravita hareket motoru — config-güdümlü, motion_core üstünde.
library;

export 'src/hold_engine.dart';
export 'src/metrics.dart';
export 'src/mirror_symmetry.dart';
export 'src/multiphase_engine.dart';
export 'src/perturbation.dart';
export 'src/progress_summary.dart';
export 'src/movement_config.dart';
export 'src/rep_engine.dart';

// SessionStore ÇEKİRDEĞE TERFİ ETTİ (motion_core 0.9.0, M-F-193 hakemliği):
// yerel port SİLİNDİ. Yeniden ihraç ediliyor çünkü `ProgressSummary` imzaları
// `SessionRecord` alıyor — tüketiciyi transitif bir pakete zorlamak
// bağımlılığı görünmez kılardı. (Kabuk ayrıca motion_core'u DOĞRUDAN da
// bildiriyor, pin EŞİTLİĞİ testli.)
export 'package:motion_core/motion_core.dart'
    show SessionRecord, SessionStore, JsonlSessionStore;
