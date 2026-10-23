import 'package:flutter/material.dart';
import 'account_connection.dart';
import 'camera_release_policy.dart';

import 'app_locale.dart';
import 'content_repository.dart';
import 'calisthenics_course_screen.dart';
import 'dbkb_course_entry.dart';
import 'foundation_course_entry.dart';
import 'library_model.dart';
import 'library_strings.dart';
import 'movement_page.dart';
import 'paywall_policy.dart';
import 'program/program_setup_screen.dart';
import 'workout/workout_screen.dart';
import 'skills/skill_trees_list_screen.dart';
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
    this.onStartSession,
    super.key,
  });

  static const Key noPlanKey = Key('home.noPlan');
  static const Key openNowKey = Key('home.openNow');
  static const Key queueKey = Key('home.queue');
  static const Key skillTreesKey = Key('home.skillTrees');
  static const Key programKey = Key('home.program');
  static const Key programSetupLinkKey = Key('home.programSetupLink');

  final ContentRepository content;
  final VoidCallback onBrowseLibrary;
  final StartMovementSession? onStartSession;

  @override
  Widget build(BuildContext context) {
    final LibraryCatalogue c = content.catalogue;
    final List<MovementEntry> live = c.movements
        .where((MovementEntry m) => m.isLive)
        .toList(growable: false);
    final int queued = c.movements.length - live.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(localized(context, LibraryStrings.homeTitle, 'Bugün')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 96),
        children: <Widget>[
          CalisthenicsEntryCard(content: content),
          const SizedBox(height: 10),
          DbkbEntryCard(content: content),
          const SizedBox(height: 10),
          FoundationCourseEntry(content: content),
          const SizedBox(height: 20),
          NoteCard(
            key: noPlanKey,
            icon: Icons.event_busy_outlined,
            title: localized(
              context,
              LibraryStrings.homeNoPlanTitle,
              'Çalışmanı seç',
            ),
            text: localized(
              context,
              LibraryStrings.homeNoPlanBody,
              motionPaidCameraLaunchEnabled
                  ? 'Kursları, öğrenme rehberlerini ve genel sekiz haftalık programı incele.'
                  : 'Kursları, öğrenme rehberlerini ve genel sekiz haftalık programı incele. '
                        'Canlı kamera seansları bu sürümde kullanılamıyor.',
            ),
          ),
          const SizedBox(height: 30),
          SurfaceSection(
            key: openNowKey,
            title: localizedUpper(
              context,
              LibraryStrings.homeOpenNowTitle,
              motionPaidCameraLaunchEnabled ? 'ŞU ANDA AÇIK' : 'ÖLÇÜM KATALOĞU',
            ),
            subtitle: localized(
              context,
              motionPaidCameraLaunchEnabled
                  ? '{count} movements are open for live rep counting.'
                  : '{count} configured measurement contracts. Live camera sessions are unavailable in this release. Learning guides record only your own practice report.',
              motionPaidCameraLaunchEnabled
                  ? '{count} harekette canlı tekrar sayımı açık. Duruşunuz puanlanmaz.'
                  : '{count} yapılandırılmış ölçüm sözleşmesi. '
                        'Canlı kamera seansları bu sürümde kullanılamıyor. '
                        'Öğrenme rehberleri yalnız kendi pratik bildirimini kaydeder.',
              values: <String, Object>{'count': live.length},
            ),
            children: live
                .map(
                  (MovementEntry m) => MovementCard(
                    movement: m,
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => MovementPage(
                          movement: m,
                          content: content,
                          onStartSession: onStartSession,
                          accountUserId: AccountScope.maybeOf(
                            context,
                          )?.currentUserId,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 30),
          // ⭐ GRA-P1-003: program kartı — AYNI SIRA gerekçesi (skill-trees
          // bloğunun altındaki uzun yorum): "browse library" kartından
          // ÖNCE durmak ZORUNDA, aksi hâlde gezilebilirlik yürüyüşü ona
          // hiç ulaşamaz (ölçülmüş desen, G-269).
          //
          // ⚠️ İKİNCİ kart (ProgramSetupScreen'e DOĞRUDAN) ölçülmüş bir
          // ikinci ihtiyaçtan doğdu, süs DEĞİL. `WorkoutScreen`in kendi
          // boş-durum CTA'sı `ProgramSetupScreen`e TEK yoldu — ama o CTA
          // `WorkoutScreen`in KENDİ `FutureBuilder`ı (gerçek G/Ç: path_
          // provider + dosya) çözülene KADAR ağaçta yok. `test/reachability_
          // test.dart`ın `settle()`i BİLEREK yalnız sahte-saatli pump kullanır
          // (`runAsync` yok — gerçek G/Ç zaten hiç sürülemez) ve tek turda
          // bu çözülmeyi bekleyemez; sonuç `ProgramSetupScreen` "ULAŞILAMIYOR
          // AMA VAR" çıktı. Yalnız test kusuru da değildi: bir program
          // KURULDUKTAN SONRA `WorkoutScreen` bir daha o CTA'yı hiç
          // göstermiyordu — yani var olan bir programı DEĞİŞTİRMENİN gerçek
          // kullanıcı için de hiçbir yolu yoktu. Bu kart HER İKİSİNİ birden
          // kapatıyor: her zaman senkron (Home zaten yüklü içerikten çizilir,
          // bu kartın kendi async kapısı yok) VE her zaman görünür.
          SurfaceSection(
            key: programKey,
            title: localizedUpper(
              context,
              LibraryStrings.programOverviewTitle,
              '8 HAFTALIK PROGRAMINIZ',
            ),
            children: <Widget>[
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => WorkoutScreen(
                      content: content,
                      accountUserId: AccountScope.maybeOf(
                        context,
                      )?.currentUserId,
                    ),
                  ),
                ),
                child: GravitaCard(
                  radius: 18,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          localized(
                            context,
                            LibraryStrings.programOverviewTitle,
                            '8 haftalık programınız',
                          ),
                          style: GravitaType.body(
                            context: context,
                            size: 14,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: GravitaColors.of(context).textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                key: programSetupLinkKey,
                borderRadius: BorderRadius.circular(18),
                onTap: () async {
                  // Independent practice stage (paywall A).
                  if (!await ensureSubscriptionAccess(context)) return;
                  if (!context.mounted) return;
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => ProgramSetupScreen(
                        content: content,
                        accountUserId: AccountScope.maybeOf(
                          context,
                        )?.currentUserId,
                      ),
                    ),
                  );
                },
                child: GravitaCard(
                  radius: 18,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          localized(
                            context,
                            LibraryStrings.programSetupTitle,
                            'Programınızı kurun',
                          ),
                          style: GravitaType.body(
                            context: context,
                            size: 14,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: GravitaColors.of(context).textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          // ⭐ GRA-P1-001: gerçek, dokunulabilir bir giriş noktası — hareket
          // sayfasındaki `skillGraphNode` bağı TEK BAŞINA yeterli DEĞİLDİ
          // (o bağı taşıyan üç hareketin üçü de kuyrukta ve aile-sıralı
          // listede geç sırada; `test/reachability_test.dart`ın gerçek
          // dokunuş yürüyüşü buna hiç ulaşamadı — ölçülmüş bir keşif
          // kusuruydu, test kusuru değil). Home'un az kontrollü sekmesinden
          // doğrudan erişim ekliyor.
          //
          // ⚠️ SIRA KASITLI — bu blok "browse library" kartından ÖNCE durur.
          // Ölçüldü: o kart `onBrowseLibrary` çağırıyor (`_index` değişimi,
          // GERÇEK bir `Navigator.push` DEĞİL) ve gezilebilirlik yürüyüşü
          // push-sonrası pop'u yalnız GERÇEK itilen rotalar için biliyor —
          // sekme sessizce Library'e KAYIYOR ve bir daha Home'a dönmüyor.
          // Bu blok o karttan SONRA olsaydı yürüyüş ona hiç ulaşamazdı
          // (birebir bu turda ölçülen kusur — `SkillTreesListScreen` ilk
          // yazışımda tam bu sebeple "ulaşılamıyor ama var" çıktı).
          SurfaceSection(
            key: skillTreesKey,
            title: localizedUpper(
              context,
              LibraryStrings.skillTreesTitle,
              'BECERİ AĞAÇLARI',
            ),
            subtitle: localized(
              context,
              'Drafted progressions: {count}',
              'Taslak ilerleme yolu: {count}',
              values: <String, Object>{'count': c.skillTrees.trees.length},
            ),
            children: <Widget>[
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        SkillTreesListScreen(trees: c.skillTrees.trees),
                  ),
                ),
                child: GravitaCard(
                  radius: 18,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          localized(
                            context,
                            LibraryStrings.skillTreesTitle,
                            'Beceri ağaçları',
                          ),
                          style: GravitaType.body(
                            context: context,
                            size: 14,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: GravitaColors.of(context).textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          SurfaceSection(
            key: queueKey,
            title: localizedUpper(
              context,
              LibraryStrings.homeQueueTitle,
              'KAPALI HAREKETLER',
            ),
            subtitle: localized(
              context,
              '{queued} of {total} catalogue movements have pending measurement evidence. Each movement page explains the missing measurements.',
              'Katalogdaki {total} hareketin {queued} tanesi '
                  'açık değil. Her hareketin sayfasında eksik ölçüm yazılıdır.',
              values: <String, Object>{
                'queued': queued,
                'total': c.movements.length,
              },
            ),
            children: <Widget>[
              InkWell(
                onTap: onBrowseLibrary,
                borderRadius: BorderRadius.circular(18),
                child: GravitaCard(
                  radius: 18,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          localized(
                            context,
                            LibraryStrings.libraryTitle,
                            'Kütüphane',
                          ),
                          style: GravitaType.body(
                            context: context,
                            size: 14,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: GravitaColors.of(context).textTertiary,
                      ),
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
