import 'package:flutter/material.dart';

import '../app_locale.dart';
import '../surface_widgets.dart';

/// Visible limits for the unchanged v1 sample prescription. No readiness,
/// diagnosis, personal dose, mastery or camera assessment is inferred here.
class ProgramSafetyNotice extends StatelessWidget {
  const ProgramSafetyNotice({required this.containsSwing, super.key});

  static const Key guidanceKey = Key('program.safetyGuidance');
  static const Key swingKey = Key('program.swingBoundary');

  final bool containsSwing;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      NoteCard(
        key: guidanceKey,
        text: localized(
          context,
          'Experience is self-reported; it does not establish readiness. The scheduled sets, repetitions and hold times are examples, not deadlines. Use only a familiar variation that you can enter and finish under control. You may use the lesson’s smaller dose, stop sooner and rest longer. A later week does not require an increase. End the task for pain, dizziness, unusual breathlessness or loss of control; do not retest symptoms with an easier version.',
          'Deneyim kendi beyanındır; hazır oluşu doğrulamaz. Takvimdeki set, tekrar ve tutuş süreleri örnektir, son tarih değildir. Yalnız girişini ve bitirişini kontrol edebildiğin tanıdık biçimi kullan. Dersin daha küçük dozunu seçebilir, erken bitirebilir ve daha uzun dinlenebilirsin. Sonraki hafta artış zorunlu değildir. Ağrı, baş dönmesi, olağandışı nefes darlığı veya kontrol kaybında görevi bitir; belirtileri daha kolay biçimle yeniden sınama.',
        ),
      ),
      if (containsSwing) ...[
        const SizedBox(height: 12),
        NoteCard(
          key: swingKey,
          sealed: true,
          text: localized(
            context,
            'This sample plan may include a kettlebell swing. Its full setup and finish are not taught here. If unfamiliar, skip the swing; for a new generated plan, leave kettlebell unselected until you have learned it separately. Kettlebell deadlift or handling reading is not swing instruction.',
            'Bu örnek plan kettlebell swing içerebilir. Tam kurulumu ve bitirişi burada öğretilmiyor. Tanıdık değilse swing’i atla; yeni otomatik plan için ayrıca öğrenene kadar kettlebell’i seçme. Kettlebell deadlift veya taşıma okuması swing öğretimi değildir.',
          ),
        ),
      ],
    ],
  );
}
