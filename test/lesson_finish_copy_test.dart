import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'support/locale_asset_harness.dart';

// Canonical course/projection identities stay immutable. These exact reviewed
// display revisions must resolve through real packaged resources in all14
// locales. This test does not validate physical performance or native rendering.
final _corrections = <String, List<String>>{
  "cal-15": [
    "Press away smoothly without shrugging or forcing elbows wide.",
    "Press away smoothly without shrugging or forcing elbows wide. To finish, come upright over both feet, taking small steps closer to the wall if needed. Settle with both feet fully on the floor and your body supported by them without leaning on the hands. Once balance is steady and the palms carry no body weight, lift the palms and rest with arms free.",
    "Omuz silkmeden veya dirseği çok yana zorlamadan akıcı it. Bitirmek için gerekirse duvara küçük adımlarla yaklaşarak iki ayağın üzerinde dikleş. İki ayağın tamamen yerdeyken el desteğine yaslanmadan vücudunu ayaklarınla taşı. Denge sabitlenip avuçlar vücut ağırlığı taşımadığında avuçları kaldır ve kolları serbest dinlendir.",
  ],
  "cal-16": [
    "Press back to the starting line and reset your breath before repeating.",
    "Press back to the starting line and reset your breath before repeating. To finish, come upright over both feet, taking small steps closer to the fixed support if needed. Settle with both feet fully on the floor and your body supported by them without leaning on the hands. Once balance is steady and the palms carry no body weight, lift the palms and rest with arms free.",
    "Başlangıç çizgisine it ve yinelemeden nefesi düzenle. Bitirmek için gerekirse sabit desteğe küçük adımlarla yaklaşarak iki ayağın üzerinde dikleş. İki ayağın tamamen yerdeyken el desteğine yaslanmadan vücudunu ayaklarınla taşı. Denge sabitlenip avuçlar vücut ağırlığı taşımadığında avuçları kaldır ve kolları serbest dinlendir.",
  ],
  "cal-17": [
    "Press back without sitting the hips onto the heels.",
    "Press back without sitting the hips onto the heels. To finish, keep both knees on the mat, move the hips back through a comfortable range and bring the trunk into stable kneeling without relying on the palms. Do not force the hips onto the heels. Keep the palms placed until their load is fully removed and balance settles; then lift them, one at a time if needed, and rest with arms free.",
    "Kalçayı topuklara oturtmadan geri it. Bitirmek için iki dizi matta tut; kalçayı rahat aralıkta geriye alarak gövdeyi avuç desteğine ihtiyaç duymayan dengeli bir diz üstü konumuna getir. Kalçayı topuklara zorlama. Avuçların yükü tamamen boşalıp denge sabitlenene kadar elleri yerinde tut; sonra gerekirse tek tek avuçları kaldır ve kolları serbest dinlendir.",
  ],
  "cal-20": [
    "Keep the head and trunk quiet; this is small shoulder-blade movement, not a deep push-up.",
    "Keep the head and trunk quiet; this is small shoulder-blade movement, not a deep push-up. To finish, come upright over both feet, taking small steps closer to the wall or fixed incline support if needed. Settle with both feet fully on the floor and your body supported by them without leaning on the hands. Once balance is steady and the palms carry no body weight, lift the palms and rest with arms free.",
    "Baş ve gövde sakin; bu derin şınav değil küçük kürek kemiği hareketi. Bitirmek için gerekirse duvara veya sabit yükselti desteğine küçük adımlarla yaklaşarak iki ayağın üzerinde dikleş. İki ayağın tamamen yerdeyken el desteğine yaslanmadan vücudunu ayaklarınla taşı. Denge sabitlenip avuçlar vücut ağırlığı taşımadığında avuçları kaldır ve kolları serbest dinlendir.",
  ],
  "cal-45": [
    "If comfortable, lift one heel briefly while the other foot remains loaded; do not chase straight suspended legs.",
    "If comfortable, lift one heel briefly while the other foot remains loaded; do not chase straight suspended legs. To finish, replace the lifted heel, keep both feet fully on the floor and settle the hips fully onto the seated starting support. Let the feet and seat take the body weight until the arms are unloaded and balance is steady. Only then open the grips, release the handles and rest with hands free.",
    "Rahatsa diğer ayak yüklüyken bir topuğu kısa kaldır; havada düz bacak kovalamama. Bitirmek için kaldırdığın topuğu yere koy, iki ayağı tamamen yerde tut ve kalçayı başlangıçtaki oturma desteğine tam yerleştir. Vücut ağırlığı ayaklar ve oturma desteğiyle taşınırken kolların yükünü tamamen boşalt ve dengeyi sabitle. Ancak sonra tutuşları aç, tutacakları bırak ve eller serbest dinlen.",
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(warmActualLocaleAssets);
  final course =
      jsonDecode(
            File('content/courses/calisthenics.v1.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final lessons = <String, Map<String, dynamic>>{
    for (final module in course['modules'] as List)
      for (final lesson in module['lessons'] as List)
        lesson['id'] as String: (lesson as Map).cast<String, dynamic>(),
  };
  for (final entry in _corrections.entries) {
    test(
      '${entry.key} finish correction resolves in all14 actual locale assets',
      () {
        final canonical = entry.value[0];
        final revised = entry.value[1];
        expect(lessons[entry.key]!['steps'][2]['en'], canonical);
        for (final locale in appSupportedLocales) {
          final tag = canonicalLocaleTag(locale.toLanguageTag());
          final translated = LocaleCatalogRegistry.translatedSource(
            revised,
            tag,
          );
          expect(
            translated,
            isNotNull,
            reason: '$tag must contain the reviewed new source ID',
          );
          if (tag != 'en') {
            expect(
              translated,
              isNot(revised),
              reason: '$tag must not pass via English fallback',
            );
          }
          expect(
            LocaleCatalogRegistry.translatedSource(canonical, tag),
            translated,
            reason:
                '$tag must apply the correction to the actual canonical lesson source',
          );
          expect(
            resolveLocalized(tag, canonical),
            resolveLocalized(tag, revised, turkish: entry.value[2]),
          );
        }
      },
    );
  }
}
