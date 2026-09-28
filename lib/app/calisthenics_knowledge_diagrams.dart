import 'package:flutter/material.dart';

import 'theme.dart';

enum _Sketch { space, wallPress, planche, tuck, lever, pull, turnover, support }

final class _Panel {
  const _Panel(this.sketch, this.en, this.tr, this.labelsEn, this.labelsTr);
  final _Sketch sketch;
  final String en, tr;
  final List<String> labelsEn, labelsTr;
}

// Original compiled vector assets. These panels identify concepts, not a
// validated progression, safe setup, anatomical angles or movement instruction.
const _panels = <String, List<_Panel>>{
  'cal-46': [
    _Panel(
      _Sketch.space,
      'Study the space',
      'Alanı incele',
      [
        'Wall: a reference, not a guarantee of stability.',
        'Mat and clear area: an exit still needs a coach.',
        'Coach and exit discussion: no kick-up shown.',
      ],
      [
        'Duvar: referans; sağlamlık garantisi değil.',
        'Mat ve boş alan: çıkış için yine eğitmen gerekir.',
        'Eğitmen ve çıkış görüşmesi: tekmeyle yükseliş gösterilmez.',
      ],
    ),
  ],
  'cal-47': [
    _Panel(
      _Sketch.wallPress,
      'Supported wall press',
      'Destekli duvar itişi',
      ['Hands meet the wall.', 'Feet remain supported on the floor.'],
      ['Eller duvarla temas eder.', 'Ayaklar yerde desteklidir.'],
    ),
    _Panel(
      _Sketch.planche,
      'Planche: a different support demand',
      'Planche: farklı destek talebi',
      [
        'Hands are the floor contact.',
        'Feet are off the floor; this is not the wall option.',
      ],
      [
        'Eller zemin temasını oluşturur.',
        'Ayaklar yerden ayrıdır; bu duvar seçeneği değildir.',
      ],
    ),
  ],
  'cal-48': [
    _Panel(
      _Sketch.tuck,
      'Shorter lever: tucked legs',
      'Kısa kol: toplanmış bacaklar',
      [
        'Hand-to-bar contact.',
        'Bent legs bring the mass nearer the shoulder.',
        'Anchor reliability is a separate question.',
      ],
      [
        'El-bar teması.',
        'Bükülü bacaklar kütleyi omuza yaklaştırır.',
        'Bağlantının sağlamlığı ayrı bir sorudur.',
      ],
    ),
    _Panel(
      _Sketch.lever,
      'Longer lever: extended body',
      'Uzun kol: uzatılmış beden',
      [
        'The bar and hand contact remain.',
        'The body extends farther from the shoulder.',
        'No hold or hanging transition is assigned here.',
      ],
      [
        'Bar ve el teması kalır.',
        'Beden omuzdan daha uzağa uzanır.',
        'Burada tutuş veya asılı geçiş görevi verilmez.',
      ],
    ),
  ],
  'cal-49': [
    _Panel(
      _Sketch.pull,
      'Pull: below the bar',
      'Çekiş: barın altında',
      ['Hands and bar.', 'Torso is below the bar.'],
      ['Eller ve bar.', 'Gövde barın altındadır.'],
    ),
    _Panel(
      _Sketch.turnover,
      'Turnover: the relationship changes',
      'Geçiş: ilişki değişir',
      [
        'Hand contact remains relevant.',
        'Torso moves from below toward above the bar.',
      ],
      [
        'El teması önemini korur.',
        'Gövde barın altından üstüne doğru yer değiştirir.',
      ],
    ),
    _Panel(
      _Sketch.support,
      'Support: above the bar',
      'Destek: barın üstünde',
      [
        'Hands provide support at the bar.',
        'Torso is above the bar; not proof of a completed muscle-up.',
      ],
      [
        'Eller barda destek oluşturur.',
        'Gövde barın üstündedir; tamamlanmış muscle-up kanıtı değildir.',
      ],
    ),
  ],
};

class CalisthenicsKnowledgeDiagrams extends StatelessWidget {
  const CalisthenicsKnowledgeDiagrams({required this.lessonId, super.key});
  final String lessonId;
  static bool supports(String id) => _panels.containsKey(id);

  @override
  Widget build(BuildContext context) {
    final panels = _panels[lessonId];
    if (panels == null) return const SizedBox.shrink();
    final tr = Localizations.localeOf(context).languageCode == 'tr';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GravitaCard(
        key: Key('calisthenics-diagrams-$lessonId'),
        sealed: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr
                  ? 'Yalnız bilgi · şemayı incele'
                  : 'Knowledge only · study the diagram',
              style: GravitaType.body(size: 16, weight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              tr
                  ? 'Şekli taklit etme. Bunlar anatomik ölçüm veya güvenlik onayı değil, stilize kavram çizimleridir. Deneme öncesi nitelikli eğitmenle kurulumu ve çıkışı görüş.'
                  : 'Do not copy the pose. These are stylized concept drawings, not anatomical measurements or safety approval. Discuss setup and exit with a qualified coach before an attempt.',
              style: GravitaType.body(size: 13, height: 1.5),
            ),
            for (final panel in panels) ...[
              const SizedBox(height: 18),
              Text(
                tr ? panel.tr : panel.en,
                style: GravitaType.body(size: 15, weight: FontWeight.w600),
              ),
              ExcludeSemantics(
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: CustomPaint(painter: _KnowledgePainter(panel.sketch)),
                ),
              ),
              for (var i = 0; i < panel.labelsEn.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${i + 1}. ${(tr ? panel.labelsTr : panel.labelsEn)[i]}',
                    style: GravitaType.body(size: 13, height: 1.5),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KnowledgePainter extends CustomPainter {
  const _KnowledgePainter(this.sketch);
  final _Sketch sketch;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 300, size.height / 180);
    final pen = Paint()
      ..color = GravitaColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void line(double a, double b, double c, double d) =>
        canvas.drawLine(Offset(a, b), Offset(c, d), pen);
    void chain(List<Offset> points) {
      final path = Path()..addPolygon(points, false);
      canvas.drawPath(path, pen);
    }

    void head(double x, double y) => canvas.drawCircle(Offset(x, y), 11, pen);
    void mark(int n, double x, double y) {
      canvas.drawCircle(Offset(x, y), 12, Paint()..color = GravitaColors.ink);
      final text = TextPainter(
        text: TextSpan(
          text: '$n',
          style: GravitaType.body(size: 15, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(x - text.width / 2, y - text.height / 2));
    }

    switch (sketch) {
      case _Sketch.space:
        line(40, 25, 40, 154);
        line(40, 154, 273, 154);
        canvas.drawRect(const Rect.fromLTWH(65, 141, 100, 10), pen);
        // Upright coach only; no inverted performer or kick-up path.
        head(235, 59);
        line(235, 70, 235, 110);
        chain(const [Offset(215, 94), Offset(235, 78), Offset(255, 94)]);
        chain(const [Offset(218, 142), Offset(235, 110), Offset(253, 142)]);
        // A discussion route, not an exit technique demonstration.
        for (var x = 170.0; x < 209; x += 10) {
          line(x, 136, x + 4, 136);
        }
        mark(1, 25, 25);
        mark(2, 100, 121);
        mark(3, 268, 57);
      case _Sketch.wallPress:
        line(188, 35, 188, 150);
        line(32, 152, 244, 152);
        head(131, 52);
        chain(const [Offset(126, 65), Offset(104, 106), Offset(77, 150)]);
        chain(const [Offset(126, 71), Offset(158, 80), Offset(186, 80)]);
        mark(1, 210, 80);
        mark(2, 54, 144);
      case _Sketch.planche:
        line(30, 153, 274, 153);
        head(61, 75);
        line(74, 80, 258, 80);
        chain(const [Offset(91, 80), Offset(104, 148), Offset(119, 148)]);
        mark(1, 128, 148);
        mark(2, 266, 58);
      case _Sketch.tuck:
      case _Sketch.lever:
        line(48, 30, 264, 30);
        line(248, 15, 248, 30);
        head(63, 90);
        line(76, 90, 165, 90);
        line(94, 87, 94, 32);
        if (sketch == _Sketch.tuck) {
          chain(const [Offset(165, 90), Offset(173, 126), Offset(134, 111)]);
          mark(2, 191, 126);
        } else {
          line(165, 90, 265, 90);
          mark(2, 256, 113);
        }
        mark(1, 94, 16);
        mark(3, 273, 25);
      case _Sketch.pull:
        line(45, 43, 255, 43);
        head(151, 93);
        chain(const [
          Offset(96, 45),
          Offset(109, 91),
          Offset(151, 109),
          Offset(151, 144),
          Offset(176, 165),
        ]);
        chain(const [Offset(205, 45), Offset(190, 91), Offset(151, 109)]);
        mark(1, 84, 24);
        mark(2, 207, 126);
      case _Sketch.turnover:
        line(45, 101, 255, 101);
        head(124, 55);
        chain(const [
          Offset(134, 67),
          Offset(151, 95),
          Offset(174, 133),
          Offset(190, 166),
        ]);
        chain(const [Offset(134, 73), Offset(113, 83), Offset(147, 99)]);
        mark(1, 93, 101);
        mark(2, 187, 72);
      case _Sketch.support:
        line(45, 106, 255, 106);
        head(150, 30);
        chain(const [Offset(150, 44), Offset(150, 89), Offset(164, 157)]);
        chain(const [Offset(150, 51), Offset(120, 106), Offset(106, 106)]);
        line(154, 52, 186, 106);
        mark(1, 91, 105);
        mark(2, 192, 56);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KnowledgePainter oldDelegate) =>
      oldDelegate.sketch != sketch;
}
