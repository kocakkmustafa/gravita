import 'package:flutter/material.dart';

import 'content_repository.dart';
import 'library_model.dart';
import 'library_strings.dart';
import 'movement_page.dart';
import 'surface_widgets.dart';
import 'theme.dart';

/// Today — kullanıcının ilk gördüğü yüzey.
///
/// ## Tasarımın "bugünkü plan" bloku neden UYGULANMADI
///
/// Design'ın `home` ekranı bir günlük plan, devam eden kurs ve "son seans
/// özeti" gösteriyor. Üçünün de arkasında bir motor VAR SAYILIYOR: bir
/// planlayıcı. Gravita'da öyle bir motor yok. "Today's workout: 3×8 push-ups"
/// yazan bir kart, arkasında hiçbir karar olmadan üretilmiş bir SAYI olurdu —
/// yani placeholder veri, aile kuralının en açık yasağı.
///
/// Bu ekran onun yerine DOĞRU olanı söylüyor: neyin açık olduğu, neyin
/// kuyrukta olduğu, ve planlayıcı OLMADIĞI. Bir eksikliği gizlemek yerine
/// adlandırmak, bu ürünün her yüzeyde verdiği karar.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.content,
    required this.onBrowseLibrary,
    super.key,
  });

  static const Key noPlanKey = Key('home.noPlan');
  static const Key openNowKey = Key('home.openNow');
  static const Key queueKey = Key('home.queue');

  final ContentRepository content;
  final VoidCallback onBrowseLibrary;

  @override
  Widget build(BuildContext context) {
    final LibraryCatalogue c = content.catalogue;
    final List<MovementEntry> live =
        c.movements.where((MovementEntry m) => m.isLive).toList(growable: false);
    final int queued = c.movements.length - live.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text(LibraryStrings.homeTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 96),
        children: <Widget>[
          const NoteCard(
            key: noPlanKey,
            icon: Icons.event_busy_outlined,
            title: LibraryStrings.homeNoPlanTitle,
            text: LibraryStrings.homeNoPlanBody,
          ),
          const SizedBox(height: 30),
          SurfaceSection(
            key: openNowKey,
            title: LibraryStrings.homeOpenNowTitle.toUpperCase(),
            subtitle: LibraryStrings.homeOpenBody(live.length),
            children: live
                .map((MovementEntry m) => MovementCard(
                      movement: m,
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              MovementPage(movement: m, content: content),
                        ),
                      ),
                    ))
                .toList(growable: false),
          ),
          const SizedBox(height: 30),
          SurfaceSection(
            key: queueKey,
            title: LibraryStrings.homeQueueTitle.toUpperCase(),
            subtitle:
                LibraryStrings.homeQueueBody(queued, c.movements.length),
            children: <Widget>[
              InkWell(
                onTap: onBrowseLibrary,
                borderRadius: BorderRadius.circular(18),
                child: GravitaCard(
                  radius: 18,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 15),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(LibraryStrings.libraryTitle,
                            style: GravitaType.body(
                                size: 14, weight: FontWeight.w500)),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 20, color: GravitaColors.textTertiary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
