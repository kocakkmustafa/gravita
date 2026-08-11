#!/usr/bin/env python3
"""Ders/kurs kütüphanesi (`content/library.json`) dürüstlük denetimi.

Ostinato `validate_library.py` / JabLab `library_test.dart`in ALTI kuralını
(kopyası değil, aynı gerekçeyle) uygular + Gravita'ya özel İKİ kural ekler.

İhlal = kullanıcıya verilmiş somut bir sözün çiğnenmesi → uyarı değil HATA.

Gravita'ya özel iki kural neden var:
  K7 (referans-notu kapısı): G-050/G-014 — taban-bağlı (floor) tolerans
     varyans-türetimli SAYILMAZ. Ders NOTLADIĞI eklemleri `gradedJoints` ile
     beyan eder; hepsi `derivedJoints`te olmalı ve hiçbiri referansın
     `unreliableJoints`inde olmamalı. (İlk hâli yalnız "derivedJoints boş mu"
     soruyordu; squat deliği gösterdi — G-072.)
  K9 (kilit izlenebilirliği): kilitli ders `lockClass: measurement` +
     `blockedBy` taşımalı; her bloker DOĞRULANIR ve artık bloklamıyorsa
     BAYAT KİLİT hatası verir (JabLab kilit-testi deseni). Bir kilidin sebebi
     ölürse kilit kendiliğinden görünür olmalı — "okuyanı olmayan beyan"ın
     aynası: beyan var, dayanağı ölmüş.
  K8 (kimlik ön koşulu kapısı): G-043 — kimlik ön koşulu yoksa rep FSM'i
     hareketi değil salınımı sayar. ⚠️ Bu kural `engine.precondition.status`
     beyanının ÜRÜN tarafındaki İLK tüketicisidir: o beyanı bugüne dek yalnız
     hasat araçları (`harvest_reps`, `build_reference`) okuyordu, ürün hiç
     sormuyordu — beşinci canlılık sorusu (G-059).
  K10 (K1'in İKİZİ — M-F-194): K1 "coming_soon'da kurs OLAMAZ" der; ikizi
     "live'da kurs OLMALI"dır. İkiz olmadan kapı YARIM: `live` bir hareketin
     kursu HEM kütüphaneden HEM katalogdan düşerse iki kaynak birbiriyle
     TUTARLI kalır (çelişki kapısı susar) ve hareket "canlı" etiketiyle
     BOŞ açılır — ölü butonun kütüphane sınıfı. Ölçüldü: mutasyon MUT-A
     eklemeden önce YAKALANMIYORDU, MUT-B (tek taraf) yakalanıyordu (G-105).
     `live` = "girebileceğin bir şey var" iddiasıdır; girilecek şey yoksa
     hareketin durumu `coming_soon`dur.

`--self-test`: on kuralın her birini KASITLI ihlalle sınar. Hiç ateşlenmemiş
bir kapıya güvenmek, bu defterde defalarca avlanan desenin ta kendisidir
(G-037/G-052) — o yüzden kapılar burada ateşlenerek kanıtlanıyor.
"""
import copy
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB_PATH = ROOT / "content" / "library.json"
CATALOG_ROOT = ROOT / "content" / "catalog"
HARVEST_DIR = ROOT / "content" / "harvest"
ENGINE_DIR = ROOT / "packages" / "gravita_engine"

#: Koordinatör hükmü (2026-08-12): "bir fixture'ın VARLIĞI, çalışan bir
#: replay'in varlığı değildir" — squat'ın kendi turunda ölçüldü, dosya VARDI
#: ve replay 30/30 SIFIR sayıyordu (güven kapısı kör noktası, sonradan
#: düzeltildi). `replayFixture:missing` artık YALNIZ dosya değil, o dosyayı
#: TÜKETEN testin GERÇEKTEN geçtiğini de ister. Süreç-ömrü boyunca ÖNBELLEK:
#: bu fonksiyon `check()` içinde (ana koşum + self-test'in ~20 mutasyonu)
#: defalarca çağrılır, dart test'i HER seferinde koşturmak self-test'i
#: dakikalarca yavaşlatırdı; sonuç hareket başına değişmez (statik test
#: dosyasının içeriğine bakar), süreç-içi önbellek GÜVENLİ.
_REPLAY_TEST_CACHE = {}


def _replay_test_passes(mid):
    """`{mid}_replay_test.dart` var mı VE gerçekten geçiyor mu (dosya-varlığı
    değil, GERÇEK koşum). Yoksa/düşerse False — "adıyla söyle", sessizce
    dosya-varlığına geri dönme."""
    if mid in _REPLAY_TEST_CACHE:
        return _REPLAY_TEST_CACHE[mid]
    test_file = ENGINE_DIR / "test" / f"{mid}_replay_test.dart"
    if not test_file.is_file():
        _REPLAY_TEST_CACHE[mid] = False
        return False
    try:
        result = subprocess.run(
            ["dart", "test", str(test_file.relative_to(ENGINE_DIR))],
            cwd=str(ENGINE_DIR), capture_output=True, text=True, timeout=60)
        ok = result.returncode == 0
    except (subprocess.TimeoutExpired, OSError):
        ok = False
    _REPLAY_TEST_CACHE[mid] = ok
    return ok


def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def load_catalogs():
    """Katalog girdileri — DALGA-BAĞIMSIZ (`content/catalog/w*`).

    ⚠️ Bu fonksiyon bir DÜZELTMENİN ürünü: burada `w1` SABİTLENMİŞTİ, yani
    K1-K9 değişmezleri kataloğun yalnız 20/31 hareketini görebiliyordu.
    Bugün ısırmıyordu çünkü `library.json`daki iki hareket de W1'de; ama bir
    W2 hareketi (wall_handstand, goblet_squat, ...) kütüphaneye girdiği gün
    kapı "katalog girdisi YOK" diye YANLIŞ ihlal üretecekti — sessiz geçiş
    değil, sahte alarm. Aynı dalga-körlüğü `catalog_smoke_test.dart`ta ve
    delta belgesinin motor-tipi sayımında da vardı (üçü tek kök: W2 eklendi,
    okuyucular genişletilmedi).
    """
    out = {}
    for wave in sorted(p for p in CATALOG_ROOT.iterdir() if p.is_dir()):
        for entry in sorted(wave.glob("*.json")):
            out[entry.stem] = load(entry)
    return out



def _blocker_active(key, cat, reference_lookup, mid):
    """Adlandırılmış blokerin ŞU AN gerçekten blokladığını doğrular (K9).

    Dönüş: (tanınıyor mu, hâlâ blokluyor mu, açıklama).

    Neden gerekli (JabLab kilit-testi deseni, M-F-179/1): bir kilit, sebebi
    ORTADAN KALKTIKTAN SONRA da durabilir — ve kimse fark etmez. Bu, gece
    boyu avladığım "okuyanı olmayan beyan"ın AYNASI: bu kez beyan (kilit)
    var ama DAYANAĞI ölmüş. Kilit ancak adlandırılmış bir ölçüm-boşluğuna
    İZLENEBİLİRSE denetlenebilir; izlenebilirse de bayatlığı MEKANİK
    yakalanır.
    """
    prov = cat.get("provenance", {})
    if key.startswith("provenance.derivedJoints:excludes:"):
        joint = key.rsplit(":", 1)[1]
        derived = prov.get("derivedJoints", [])
        return True, joint not in derived, (
            f"`{joint}` derivedJoints'te {'YOK (blokluyor)' if joint not in derived else 'VAR → BLOKLAMIYOR'}")
    if key == "engine.precondition.status!=derived":
        st = cat.get("engine", {}).get("precondition", {}).get("status")
        return True, st != "derived", f"precondition.status={st}"
    if key == "replayFixture:missing":
        # Replay fixture'ı varsa hata kuralları gerçek veride sınanabilir.
        #
        # ⚠️ İKİ AYRI SORU, İKİSİ DE SORULUR (koordinatör hükmü, 2026-08-12):
        # (1) dosya var mı (2) onu TÜKETEN test GERÇEKTEN geçiyor mu. Yalnız
        # (1) sormak ölçüldü: squat'ta dosya VARDI, replay 30/30 SIFIR
        # sayıyordu (güven kapısı kör noktası) — "fixture VAR" bloke-değil
        # sanılmıştı, gerçekte hâlâ bloke idi. Vekil (dosya-varlığı) kendini
        # yanlış gösterdi; artık vekil değil GERÇEK sonuç soruluyor.
        fx = ROOT / "packages" / "gravita_engine" / "test" / "fixtures"
        present = any(p.name.startswith(mid) for p in fx.glob("*.json")) \
            if fx.is_dir() else False
        working = present and _replay_test_passes(mid)
        detail = (
            "replay fixture YOK (blokluyor)" if not present else
            f"replay fixture VAR ama tüketen test YOK/DÜŞÜYOR "
            f"({mid}_replay_test.dart) (blokluyor)" if not working else
            "replay fixture VAR VE tüketen test GEÇİYOR → BLOKLAMIYOR")
        return True, not working, detail
    if key == "provenance.sources:empty":
        # ÜÇÜNCÜ bloker sınıfı (2026-08-06, terfi turu). Hiç eğitmen kaynağı
        # HASAT EDİLMEMİŞ bir harekette her tolerans TABAN değerindedir —
        # yani hareketin bütün eşikleri varsayılandan gelir, ölçümden değil
        # (G-014/G-050'nin bir adım öncesi: orada kaynak VAR ama varyans
        # türetmemiş, burada kaynak HİÇ YOK).
        #
        # ⚠️ Bu anahtar YENİ BİR EŞİK DEĞİL: `provenance.sources` zaten her
        # katalog girdisinde duran bir alan ve `validate_catalog.py` onun
        # boşluğunu bugün de UYARI olarak basıyor. Buradaki tek yenilik, o
        # zaten-doğru olguyu MAKİNEYLE DOĞRULANABİLİR bir kilit gerekçesine
        # çevirmek — yani K9'un asıl amacı: kaynak hasat edildiği gün bu
        # bloker ölür ve kilit BAYAT diye öter, kimse hatırlamak zorunda
        # kalmaz.
        sources = prov.get("sources") or []
        return True, not sources, (
            f"provenance.sources {'BOŞ (blokluyor)' if not sources else f'{len(sources)} kaynak → BLOKLAMIYOR'}")
    return False, False, "TANINMAYAN bloker anahtarı"


#: K14 İSTİSNASI (koordinatör hükmü, 2026-08-11 — M-F ailesi devir zinciri).
#:
#: Bulgu 2026-08-07'de kaydedildi: `push_up` LIVE ama `replayFixture:missing`
#: taşıyor — kanıt VAR (gravita_engine'de 18 sentetik-perturbasyon testi,
#: `packages/gravita_engine/test/fixtures/`te dosya biçiminde DEĞİL). K14
#: bunu doğru yakaladı ve `validate_library` o günden beri BİLEREK kırmızı
#: kalıyordu — ama `run_all_gates.sh`/`gated_commit.sh` tek bir kırmızıyı
#: tüm depoya (yeni terfi dahil) yayıyordu. Kilidi koyan koordinatördü,
#: açan da o: *"K14'ü doğru sınıflamanın cezası, terfi hattını kapatmak
#: olamaz."*
#:
#: Bu YALNIZ bu (hareket, anahtar) çiftine uygulanır — genel bir muafiyet
#: LİSTESİ değil (bkz. K14'ün kendi gerekçesi: "muafiyet bir liste ise,
#: terfi eden hareket listede kalır ve kimse fark etmez"). İki güvence:
#:   ① BAŞKA hiçbir live hareket veya başka hiçbir anahtar bundan muaf
#:      DEĞİL — aşağıdaki döngü yalnız tam bu çifti eler.
#:   ② BAYATLIK kendini denetler: bu çift artık kurulmuyorsa (push_up
#:      live olmaktan çıktıysa ya da gerçek bir replayFixture kazandıysa)
#:      döngü sonunda "K14 İSTİSNASI BAYAT" diye öter — sabiti o gün ELLE
#:      silmek gerekir, sessizce durmaz.
K14_ACCEPTED_GAPS = frozenset({("push_up", "replayFixture:missing")})


def check(lib, catalog_lookup, reference_lookup):
    """Sekiz değişmezi uygular; ihlal listesi döner (boş = temiz)."""
    violations = []
    k14_gaps_seen = set()

    for m in lib["movements"]:
        mid = m["id"]
        cat = catalog_lookup(m.get("catalogId", mid))
        if cat is None:
            violations.append(f"{mid}: katalog girdisi YOK "
                              f"(content/catalog/w*/{m.get('catalogId', mid)}.json)")
            continue

        prov = cat.get("provenance", {})
        derived_joints = prov.get("derivedJoints", [])
        # Referans artefaktındaki `unreliableJoints` TARAF bazlı
        # (`left_elbow`); katalog provenance'ı ve dersler ÇİFT bazlı
        # (`elbow`) konuşuyor — bir tarafı güvenilmezse çift güvenilmez
        # (M-F-95 zayıf-halka kuralının aynısı).
        unreliable_pairs = {
            j.removeprefix("left_").removeprefix("right_")
            for j in (reference_lookup(m.get("id", mid)) or {})
            .get("result", {}).get("unreliableJoints", [])
        }
        precondition = cat.get("engine", {}).get("precondition", {})
        pre_status = precondition.get("status")
        catalog_error_ids = {e["id"] for e in cat.get("formErrors", [])}
        catalog_courses = set(cat.get("courses", []))

        # K1: coming_soon harekette kurs OLAMAZ.
        if m.get("status") == "coming_soon" and m.get("courses"):
            violations.append(
                f"{mid}: coming_soon ama {len(m['courses'])} kurs listeliyor")

        # K4: honesty.notMeasured DOLU olmalı.
        if not m.get("honesty", {}).get("notMeasured"):
            violations.append(f"{mid}: honesty.notMeasured boş/yok")

        # K6: comingSoon maddeleri gerekçesiz olamaz.
        for item in m.get("comingSoonInThisMovement", []):
            if len(item.strip()) < 20:
                violations.append(
                    f"{mid}: comingSoonInThisMovement maddesi gerekçesiz "
                    f"görünüyor: '{item}'")

        # ⚠️ K12 (2026-08-07): DÜRÜSTLÜK CÜMLESİ KATALOGLA ÇELİŞEMEZ.
        #
        # Bulunuş: `floor_press` sayfası *"The rules for the floor press ARE
        # WRITTEN, but 3 things are still missing"* diyordu. O hareketin
        # **hiç kuralı yok** — sıfır `formError`. Cümle koşulsuz yazılmıştı.
        #
        # Neden hiçbir kapı görmedi: dil nöbeti SÖZCÜKLERE bakar ve bu cümle
        # kibar; drift kapısı üretilenle diski karşılaştırır ve ikisi de aynı
        # yanlıştı. *Yanlış ama kibar bir cümle her kapıdan geçer* —
        # doğruluğu ancak KAYNAĞA karşı ölçülür.
        rules = cat.get("formErrors") or []
        claims_rules = any(
            "rules for the" in line and "are written" in line
            for line in m.get("honesty", {}).get("waitingOnMeasurement", []))
        if claims_rules and not rules:
            violations.append(
                f"{mid}: dürüstlük kutusu 'kurallar YAZILMIŞ' diyor ama "
                f"katalogda SIFIR kural var — cümle kaynağıyla çelişiyor")

        # ⭐ K14 — CANLI hareketin de blokerleri ÖLÇÜLÜR.
        #
        # Bulunuş: `push_up` `live`, ama terfi ölçütüme göre
        # `replayFixture:missing` taşıyor. Nasıl olabildi: curated girdilerde
        # `status` ve `blockedBy` YENİDEN TÜRETİLMİYOR (muafiyet listesi),
        # ve bu denetim yalnız `status != live` olanlara bakıyordu.
        #
        # Yani uygulamanın TEK açık hareketinin açık olduğu iddiası,
        # hiçbir kapının yeniden ölçmediği ELLE YAZILMIŞ bir değerdi.
        #
        # > *Muafiyet bir LİSTE ise, terfi eden hareket listede kalır ve
        # > kimse fark etmez.* Buradaki hâli daha ağır: muafiyet, ölçütün
        # > kendisini atlatıyordu.
        if m.get("status") == "live":
            unmet = [k for k in ("engine.precondition.status!=derived",
                                 "replayFixture:missing",
                                 "provenance.sources:empty")
                     if _blocker_active(k, cat, reference_lookup, mid)[1]]
            excepted = [k for k in unmet if (mid, k) in K14_ACCEPTED_GAPS]
            still_unmet = [k for k in unmet if k not in excepted]
            if still_unmet:
                violations.append(
                    f"{mid}: LIVE ama terfi ölçütü karşılanmıyor — "
                    f"{still_unmet}. Bu değer curated muafiyeti yüzünden "
                    f"yeniden türetilmiyor, yani ÖLÇÜLMEDEN 'açık' diyor")
            for k in excepted:
                k14_gaps_seen.add((mid, k))

        if m.get("status") != "live":
            # ⚠️ K11 (2026-08-07): BOŞ bloker listesi de bir BAYAT gerekçedir.
            #
            # Eski hâl yalnız listedeki anahtarları geziyordu — liste BOŞSA
            # sıfır tur dönüyor ve kapı SUSUYORDU. Ölçüldü: curated bir
            # hareketin `blockedBy`sini boşalttım, `validate_library` ve
            # `promote --check` İKİSİ DE yeşil kaldı; hareket hâlâ
            # "2 ölçüm eksik" diyordu ve hiçbir şey eksik değildi.
            #
            # Ölçüt (koordinatör aktarımı): *sevk edilmiş bir dürüstlük
            # cümlesini yanlışa çevirecek en MAKUL değişiklik neyse, kapı
            # onu tutmalı.* Burada o değişiklik "hasat geldi, bloker öldü" —
            # hiç uçuk değil, gecenin ASIL HEDEFİ.
            blockers = m.get("blockedBy") or []
            if not blockers:
                violations.append(
                    f"{mid}: coming_soon ama HİÇ bloker adlandırmıyor — "
                    f"gerekçesiz bir kapalılık, dayanağı olmayan bir beyandır")
            for key in blockers:
                known, active, expl = _blocker_active(
                    key, cat, reference_lookup, mid)
                if not known:
                    violations.append(f"{mid}: tanınmayan bloker: '{key}'")
                elif not active:
                    violations.append(
                        f"{mid}: BAYAT 'coming_soon' — bloker '{key}' artık "
                        f"bloklamıyor ({expl})")
            continue

        # K10: live hareket EN AZ 1 kurs taşımak zorunda — K1'in ikizi
        # (M-F-194). Aşağıdaki çelişki kapısı iki kaynağın BİRBİRİNE
        # uymasını ister; bu kapı iddianın DÜNYAYA uymasını ister. İkisi
        # aynı şey değil: iki kaynak birlikte boşalırsa çelişki yoktur ama
        # kullanıcı "canlı" yazan boş bir sayfa görür (G-105).
        if not m.get("courses"):
            violations.append(
                f"{mid}: status=live ama SIFIR kurs — 'canlı' girilebilir bir "
                f"şey olduğu iddiasıdır; yoksa durum coming_soon olmalı")

        # K8: live hareket DERIVED ön koşul taşımak zorunda (G-043).
        if pre_status != "derived":
            violations.append(
                f"{mid}: status=live ama engine.precondition.status="
                f"'{pre_status}' (DERIVED olmalı) — kimlik ön koşulu yokken "
                f"rep FSM'i hareketi değil salınımı sayar (G-043)")

        # Katalog ile kütüphane kurs listesi ÇELİŞEMEZ (iki yönlü).
        lib_courses = {c["id"] for c in m.get("courses", [])}
        for extra in sorted(lib_courses - catalog_courses):
            violations.append(
                f"{mid}/{extra}: kütüphanede var, katalog courses[]'te YOK")
        for missing in sorted(catalog_courses - lib_courses):
            violations.append(
                f"{mid}/{missing}: katalog courses[]'te var, kütüphanede YOK")

        for c in m.get("courses", []):
            # K2: her kursun en az 1 dersi olmalı.
            if not c.get("lessons"):
                violations.append(f"{mid}/{c['id']}: boş kurs (0 ders)")
                continue

            for l in c["lessons"]:
                lid = l["id"]
                locked = l.get("status") == "locked"

                # ATIF SINIFI S7 (G-119): `focus` serbest metin DEĞİL, katalog
                # `gateableMetrics`ine atıftır (ya da formErrors'a işaret eden
                # 'form'). Sabotaj sınamasında sessiz geçiyordu: uydurma bir
                # odak yazılabiliyor ve ders "neyi ölçtüğünü" yanlış beyan
                # ederken hiçbir kapı ötmüyordu.
                gateable = set((cat.get('measurementContract') or {})
                               .get('gateableMetrics') or [])
                focus = l.get('focus')
                if focus is not None and focus != 'form' and focus not in gateable:
                    violations.append(
                        f"{lid}: focus '{focus}' katalogun gateableMetrics'inde "
                        f"YOK ({sorted(gateable)}) ve 'form' da değil — ders "
                        f"ölçmediği bir şeyi odak ilan ediyor")

                # K3: ders, katalogda olmayan formError'a atıf yapamaz.
                for eid in l.get("errorFocus", []):
                    if eid not in catalog_error_ids:
                        violations.append(
                            f"{lid}: var olmayan formError'a atıf: '{eid}' "
                            f"({mid} kataloğunda yok)")

                # K5: locked ders lockedReason taşımalı; tersi de tutarsız.
                if locked and not l.get("lockedReason"):
                    violations.append(f"{lid}: status=locked ama lockedReason yok")
                if not locked and l.get("lockedReason"):
                    violations.append(
                        f"{lid}: lockedReason var ama status=locked değil "
                        f"(tutarsız beyan)")

                # K9: KİLİTLİ ders, kilidini ADLANDIRILMIŞ ve DOĞRULANABİLİR
                # bir ölçüm-boşluğuna izlemek zorunda; bloker artık
                # bloklamıyorsa kilit BAYATTIR (yapısal kilit de yasak).
                if locked:
                    if l.get("lockClass") != "measurement":
                        violations.append(
                            f"{lid}: kilitli ama `lockClass` 'measurement' "
                            f"değil ({l.get('lockClass')!r}) — yapı/ekran "
                            f"kilidi ÖLÇÜM kilidi gibi sunulamaz")
                    blockers = l.get("blockedBy") or []
                    if not blockers:
                        violations.append(
                            f"{lid}: kilitli ama `blockedBy` YOK — kilidi "
                            f"adlandırılmış bir ölçüm-boşluğuna izlenemeyen "
                            f"kilit denetlenemez")
                    for key in blockers:
                        known, active, expl = _blocker_active(
                            key, cat, reference_lookup, mid)
                        if not known:
                            violations.append(
                                f"{lid}: tanınmayan bloker anahtarı: '{key}'")
                        elif not active:
                            violations.append(
                                f"{lid}: BAYAT KİLİT — bloker '{key}' artık "
                                f"BLOKLAMIYOR ({expl}); kilit gözden "
                                f"geçirilmeli")

                # ATIF SINIFI S8 (G-119): `gradedJoints` KİLİTLİ derste de
                # DOĞRULANIR. Sabotaj sınamasında sessiz geçiyordu: K7 yalnız
                # açık dersleri görüyordu, yani kilitli bir dersin eklem
                # beyanı çürük kalabilir ve KİLİT AÇILDIĞI GÜN çürük beyanla
                # açılırdı. Kilit bir muafiyet değil, geçici bir kapıdır.
                known_joints = (set(derived_joints) | unreliable_pairs
                                | set(prov.get('floorBoundJoints') or []))
                for j in (l.get('gradedJoints') or []):
                    if j not in known_joints:
                        violations.append(
                            f"{lid}: gradedJoints '{j}' katalogda TANINMIYOR "
                            f"(derivedJoints/floorBoundJoints/unreliable "
                            f"kümelerinin hiçbirinde yok) — var olmayan bir "
                            f"eklemi notlamayı beyan ediyor")

                # K7: referansa karşı form notu veren AÇIK ders, NOTLADIĞI her
                # eklemin varyans-türetimli olduğunu göstermek zorunda.
                #
                # ⚠️ Bu kural ilk yazıldığında yalnız "derivedJoints BOŞ mu"
                # diye soruyordu. bodyweight_squat referansı üretilince kuralın
                # DELİĞİ ortaya çıktı (G-072): squat'ın varyans-türetimli 4
                # eklemi KOL eklemleri (elbow/forearm/shoulder/upper_arm), buna
                # karşın squat'ın notlayacağı eklemler BACAK (hip/knee/shin/
                # thigh/trunk_tilt) ve hepsi TABAN-bağlı. "Bir yerde varyans
                # var" sorusu, "NOTLADIĞIM yerde varyans var mı" sorusunun
                # yerine geçemez — vekil ölçen kapı sınıfı hata (bu defterin
                # gece boyu avladığı desen). Ders artık notladığı eklemleri
                # `gradedJoints` ile BEYAN eder ve kural kesişimi denetler.
                if l.get("gradesFormAgainstReference") and not locked:
                    graded = l.get("gradedJoints")
                    if not graded:
                        violations.append(
                            f"{lid}: gradesFormAgainstReference=true ve AÇIK "
                            f"ama `gradedJoints` beyan edilmemiş — hangi eklemi "
                            f"notladığını söylemeyen bir ders denetlenemez")
                    else:
                        not_derived = [j for j in graded
                                       if j not in derived_joints]
                        if not_derived:
                            violations.append(
                                f"{lid}: AÇIK form-notu ama şu eklem(ler) "
                                f"varyans-türetimli DEĞİL (taban-bağlı): "
                                f"{', '.join(sorted(not_derived))} — tolerans "
                                f"ölçümden değil varsayılandan geliyor "
                                f"(G-050/G-014)")
                        unreliable_hit = [j for j in graded
                                          if j in unreliable_pairs]
                        if unreliable_hit:
                            violations.append(
                                f"{lid}: AÇIK form-notu ama şu eklem(ler) "
                                f"referansta GÜVENİLMEZ işaretli: "
                                f"{', '.join(sorted(unreliable_hit))} — "
                                f"eğitmenlerin anlaşamadığı eklem üzerine "
                                f"hüküm kurulamaz (G-059/V17)")

    # K14 istisnasının kendi BAYATLIK denetimi (K9 bayat-kilit desenin
    # aynası): sabitte duran bir çift bu koşumda hiç GÖRÜLMEDİYSE ya
    # hareket artık live değildir ya da boşluk gerçekten kapanmıştır —
    # ikisinde de istisna sessizce durmamalı, ELLE silinmesi gerektiğini
    # söylemeli.
    for mid, key in sorted(K14_ACCEPTED_GAPS):
        if (mid, key) not in k14_gaps_seen:
            violations.append(
                f"K14 İSTİSNASI BAYAT: {mid}/{key} artık kurulmuyor "
                f"(hareket live değil ya da boşluk kapandı) — "
                f"K14_ACCEPTED_GAPS sabitinden elle silinmeli")

    return violations


def _self_test():
    """Sekiz kuralı kasıtlı ihlalle ateşle. Ateşlenmeyen kapı = sahte kapı."""
    base_lib = load(LIB_PATH)
    catalogs = load_catalogs()

    def lookup(cid):
        return copy.deepcopy(catalogs.get(cid))

    def ref_lookup(mid):
        p = HARVEST_DIR / f"reference.{mid}.json"
        return load(p) if p.exists() else None

    def live(lib):
        return next(m for m in lib["movements"] if m["status"] == "live")

    def push_up(lib):
        """`live()` YETMİYOR artık (2026-08-12, bodyweight_squat terfisi):
        iki live hareket var ve `promote_library.py`nin sıralaması ("legs" <
        "push" alfabetik) `live(lib)`i SESSİZCE squat'a çevirdi — aşağıdaki
        mutasyonların çoğu push_up'ın KENDİ ders/kurs YAPISINI (id'ler,
        lesson sırası) varsayıyor. Konumla değil KİMLİKLE seçilir — tam
        `soon_with_reference`in kendi gerekçesiyle aynı ders (M-F-4. dersin
        üçüncü görünüşü: veri büyüyünce/değişince konumsal seçim kayar)."""
        return next(m for m in lib["movements"] if m["id"] == "push_up")

    def soon(lib):
        return next(m for m in lib["movements"] if m["status"] == "coming_soon")

    def soon_with_reference(lib):
        """KONUMLA değil ÖZELLİKLE seçer — K7c'nin ihtiyacı olan hareket.

        ⚠️ Bu fonksiyon bir REGRESYONUN ürünü. K7c ("varyans-türetimli ama
        referansta GÜVENİLMEZ işaretli eklem notlanamaz") mutasyonu `soon()`
        kullanıyordu, yani **listedeki İLK** `coming_soon` hareketi. Kütüphane
        iki hareketliyken o hep `bodyweight_squat`tı ve testin ihtiyacı olan
        iki özelliği (referans artefaktı VAR + `derivedJoints` DOLU) taşıyordu.

        Kütüphane 31'e çıkınca ilk sıradaki `farmer_carry` oldu — referansı da
        türetilmiş eklemi de YOK. Mutasyon hiçbir şey ihlal edemedi ve kapı
        **SESSİZCE SAHTE OLDU**: hata vermedi, sadece ölçmeyi bıraktı.

        Bu, bu defterin 4. dersinin (*"yapısal kaldırma, yokluk iddialarını
        vakum-doğru yapar"*) EKLEME yönündeki ikizi: veri BÜYÜYÜNCE de bir
        kapı ölçmeyi bırakabiliyor. Fixture konumla seçilirse, fixture'ın
        kendisi kayabilir.
        """
        # ⚠️ İKİNCİ REGRESYON (2026-08-12): `status != coming_soon` filtresi
        # bodyweight_squat terfi edince (bu turda) TEK uygun hareketi
        # havuzdan düşürdü — özellik ÖZELLİKLE arandığı hâlde durum
        # filtresi konumsal seçimin gizli bir biçimiydi. Filtre kaldırıldı:
        # mutasyon zaten `status = "live"`e ZORLUYOR (aşağıda), o yüzden
        # başlangıç durumu hiç önemli değildi — yalnız YANLIŞ önemli
        # SANILMIŞTI.
        for m in lib["movements"]:
            cat = catalogs.get(m.get("catalogId", m["id"])) or {}
            prov = cat.get("provenance", {})
            if prov.get("derivedJoints") and ref_lookup(m["id"]):
                return m
        raise AssertionError(
            "K7c için gereken hareket YOK: referans artefaktı olan ve "
            "derivedJoints'i dolu bir `coming_soon` hareket bulunamadı")

    def graded_lesson(lib):
        for c in live(lib)["courses"]:
            for l in c["lessons"]:
                if l.get("gradesFormAgainstReference"):
                    return l
        raise AssertionError("gradesFormAgainstReference dersi yok")

    def mut_k1(lib):
        soon(lib)["courses"] = [{"id": "fake", "lessons": [{"id": "fake.l"}]}]

    def mut_k2(lib):
        live(lib)["courses"][0]["lessons"] = []

    def mut_k3(lib):
        live(lib)["courses"][0]["lessons"][0]["errorFocus"] = ["no_such_error"]

    def mut_k4(lib):
        live(lib)["honesty"]["notMeasured"] = []

    def mut_k5(lib):
        graded_lesson(lib).pop("lockedReason")

    def mut_k6(lib):
        live(lib)["comingSoonInThisMovement"] = ["soon"]

    def mut_k7(lib):
        # Taban-bağlı eklemi notlayan AÇIK ders.
        l = graded_lesson(lib)
        l.pop("status")
        l.pop("lockedReason")

    def mut_k7_nodecl(lib):
        # gradesFormAgainstReference AÇIK ama gradedJoints beyan YOK.
        l = graded_lesson(lib)
        l.pop("status")
        l.pop("lockedReason")
        l.pop("gradedJoints", None)

    def mut_k9_nolockclass(lib):
        graded_lesson(lib).pop("lockClass", None)

    def mut_k9_noblockedby(lib):
        graded_lesson(lib).pop("blockedBy", None)

    def mut_k9_stale(lib):
        # GERÇEK BAYAT KİLİT: push_up'ın `precondition.status` DERIVED'dir,
        # yani "precondition != derived" blokeri BLOKLAMAZ. Kilit dayanağını
        # yitirmiş olur ve K9 bunu yakalamak ZORUNDA — bu, K9'un asıl varlık
        # sebebi (sebebi ölmüş kilit sessizce durmasın).
        graded_lesson(lib)["blockedBy"] = [
            "engine.precondition.status!=derived"]

    def mut_k9_stale_sources(lib):
        # ÜÇÜNCÜ bloker sınıfının BAYAT dalı: push_up'ın provenance'ında 5
        # kaynak VAR, yani "sources boş" blokeri onu BLOKLAMAZ. Anahtarın
        # yalnız TANINMASI yetmez — hasat geldiği gün ölüp ötmesi gerekir,
        # ki terfi kuyruğundaki 30 hareketin kilidi kendiliğinden gözden
        # geçirilsin. Tanınırlık ile canlılık AYRI iki kapı.
        graded_lesson(lib)["blockedBy"] = ["provenance.sources:empty"]

    def mut_k12_rule_claim(lib):
        # Gerçek kusurun aynası: KURALSIZ bir harekete *"kurallar yazılmış"*
        # cümlesini geri koyar. Yani bu twin, düzeltilen cümlenin GERİ
        # DÖNMESİNİ ölçüyor — üretici şablonu yarın koşulsuzlaşırsa öter.
        for m in lib["movements"]:
            cat = catalogs.get(m["catalogId"]) or {}
            if not (cat.get("formErrors") or []):
                m["honesty"]["waitingOnMeasurement"] = [
                    f"Nothing is measured here. The rules for the "
                    f"{m['displayName'].lower()} are written, but 3 things "
                    f"are still missing."
                ]
                return
        raise AssertionError("kuralsız hareket yok — fikstür seçilemedi")

    def mut_k11_no_blockers(lib):
        # BOŞ bloker listesi: hareket "kapalı" diyor ama neden kapalı
        # olduğunu söylemiyor. Kapı bunu sessizce geçiyordu.
        soon(lib)["blockedBy"] = []

    def mut_k9_unknown(lib):
        graded_lesson(lib)["blockedBy"] = ["ekran_henuz_yapilmadi"]

    def mut_k9_structural(lib):
        graded_lesson(lib)["lockClass"] = "structural"

    def mut_s7_focus(lib):
        live(lib)["courses"][0]["lessons"][0]["focus"] = "uydurma_odak"

    def mut_s8_graded(lib):
        # KİLİTLİ derste çürük eklem beyanı — K7 bunu görmüyordu.
        graded_lesson(lib)["gradedJoints"] = ["yok_boyle_eklem"]

    def mut_k7_unreliable(lib):
        # G-072 deliği: eklem VARYANS-türetimli ama referansta GÜVENİLMEZ.
        # squat: derivedJoints=[elbow,forearm,shoulder,upper_arm],
        #        unreliableJoints=[left/right_elbow, left/right_forearm]
        # ⚠️ `soon()` DEĞİL: fixture ÖZELLİKLE seçilir, konumla değil
        # (bkz. `soon_with_reference` gerekçesi — kütüphane 31'e çıkınca bu
        # kapı sessizce sahte olmuştu).
        sq = soon_with_reference(lib)
        sq["status"] = "live"
        sq["courses"] = [{
            "id": "leg_foundations",
            "lessons": [{
                "id": "leg_foundations.arm_grade",
                "gradesFormAgainstReference": True,
                "gradedJoints": ["elbow"],
            }],
        }]

    def mut_k14_scope(lib):
        # K14 İSTİSNASI DAR mı? `push_up` DIŞINDA bir hareketi live yapmak
        # onun KENDİ eksik blokerleriyle K14'ü AYRI ateşlemeli — istisna
        # bir sınıfa değil tek bir (hareket, anahtar) çiftine bağlı.
        soon(lib)["status"] = "live"

    def mut_k14_stale(lib):
        # İstisna BAYATLIYOR mu? push_up live olmaktan çıkarsa
        # K14_ACCEPTED_GAPS'teki çift bu koşumda hiç kurulmaz — kendini
        # BAYAT diye işaretlemek ZORUNDA (K9 bayat-kilit deseninin aynası).
        # ⚠️ `live(lib)` DEĞİL: iki live hareket olunca (bodyweight_squat
        # terfisi) `live()` HANGİSİNİ döndüreceği dizi SIRASINA bağlı — bu
        # testin doğruluğu özellikle PUSH_UP'ın coming_soon olmasına bağlı
        # (K14_ACCEPTED_GAPS yalnız push_up'a kayıtlı), o yüzden KİMLİKLE
        # seçilir.
        push_up(lib)["status"] = "coming_soon"

    cases = [
        ("S7 focus katalogda YOK (G-119)", mut_s7_focus,
         "gateableMetrics'inde"),
        ("S8 KİLİTLİ derste çürük gradedJoints (G-119)", mut_s8_graded,
         "katalogda TANINMIYOR"),
        ("K1 coming_soon'da kurs", mut_k1, "coming_soon ama"),
        ("K2 boş kurs", mut_k2, "boş kurs"),
        ("K3 olmayan formError", mut_k3, "var olmayan formError"),
        ("K4 boş notMeasured", mut_k4, "notMeasured boş"),
        ("K5 gerekçesiz kilit", mut_k5, "lockedReason yok"),
        ("K6 gerekçesiz comingSoon", mut_k6, "gerekçesiz"),
        ("K7a dayanaksız form notu", mut_k7, "varyans-türetimli DEĞİL"),
        ("K7b gradedJoints beyansız", mut_k7_nodecl,
         "`gradedJoints` beyan edilmemiş"),
        ("K7c güvenilmez eklem notlanıyor", mut_k7_unreliable,
         "GÜVENİLMEZ işaretli"),
        ("K9a lockClass yok", mut_k9_nolockclass, "lockClass"),
        ("K9b blockedBy yok", mut_k9_noblockedby, "`blockedBy` YOK"),
        ("K9c tanınmayan bloker", mut_k9_unknown, "tanınmayan bloker"),
        ("K11 gerekçesiz kapalılık (BOŞ bloker listesi)", mut_k11_no_blockers,
         "HİÇ bloker adlandırmıyor"),
        ("K12 cümle katalogla çelişiyor (kural yok ama 'yazılmış' diyor)",
         mut_k12_rule_claim, "SIFIR kural"),
        ("K9e BAYAT KİLİT (bloker artık bloklamıyor)", mut_k9_stale,
         "BAYAT KİLİT"),
        ("K9f BAYAT KİLİT — sources dolu (terfi turu anahtarı)",
         mut_k9_stale_sources, "BAYAT KİLİT"),
        ("K9d yapı-kilidi ölçüm gibi sunuluyor", mut_k9_structural,
         "ÖLÇÜM kilidi gibi sunulamaz"),
        ("K14 istisnası DAR (başka hareket muaf değil)", mut_k14_scope,
         "LIVE ama terfi ölçütü karşılanmıyor"),
        ("K14 istisnası BAYATLIYOR (push_up live değilse)", mut_k14_stale,
         "K14 İSTİSNASI BAYAT"),
    ]

    ok = True
    # Ateşlenen dal SAYISI sayaçtan gelir, elle yazılmaz. Önceki hâli
    # `"19/19 kapı ateşlendi"` diye SABİT metindi: yeni bir dal eklendiğinde
    # sessizce yanlışa döner ve "kaç kapım var" sorusunu yanlış cevaplardı —
    # bu defterin kendi avladığı desen (elle tutulan türetimli sayı).
    fired = [0]
    # Temiz taban ÖNCE: mutasyonsuz kütüphane ihlalsiz olmalı, yoksa
    # aşağıdaki her testin "yakaladı" demesi anlamsızdır.
    if check(copy.deepcopy(base_lib), lookup, ref_lookup):
        print("   ⛔ TABAN KİRLİ — mutasyonsuz kütüphane ihlal veriyor")
        return 1
    print("   ✅ taban temiz (mutasyonsuz kütüphane ihlalsiz)")

    for name, mutate, expect in cases:
        lib = copy.deepcopy(base_lib)
        mutate(lib)
        found = check(lib, lookup, ref_lookup)
        hit = any(expect in v for v in found)
        print(f"   {'✅' if hit else '⛔'} {name}: "
              f"{'yakalandı' if hit else 'YAKALANMADI — SAHTE KAPI'}")
        ok = ok and hit
        fired[0] += 1

    # K8 katalog tarafından ihlal edilir (ön koşul pending), kütüphaneden değil:
    # canlı hareketin kataloğunu pending'e çevir.
    lib = copy.deepcopy(base_lib)
    live_id = live(lib)["catalogId"]

    def lookup_pending(cid):
        cat = copy.deepcopy(catalogs.get(cid))
        if cat is not None and cid == live_id:
            cat["engine"]["precondition"]["status"] = "pending"
        return cat

    found = check(lib, lookup_pending, ref_lookup)
    hit = any("DERIVED olmalı" in v for v in found)
    print(f"   {'✅' if hit else '⛔'} K8 pending ön koşulla live: "
          f"{'yakalandı' if hit else 'YAKALANMADI — SAHTE KAPI'}")
    ok = ok and hit
    fired[0] += 1

    # ⭐ replayFixture DOSYA-VARLIĞI YETMEZ (koordinatör hükmü, 2026-08-12):
    # tüketen test GERÇEKTEN düşerse bloker hâlâ AKTİF kalmalı — dosya orada
    # dursa bile. `_REPLAY_TEST_CACHE`i GEÇİCİ olarak sahte-düşen sonuçla
    # doldurup `_blocker_active`i doğrudan sınıyoruz (tam `check()` zincirini
    # dolaşmadan — squat bugün bu anahtarı `blockedBy`de TAŞIMIYOR, mekanik
    # birimi izole sınamak burada daha net).
    saved_cache = dict(_REPLAY_TEST_CACHE)
    try:
        _REPLAY_TEST_CACHE["bodyweight_squat"] = False
        sq_cat = catalogs["bodyweight_squat"]
        known, active, expl = _blocker_active(
            "replayFixture:missing", sq_cat, ref_lookup, "bodyweight_squat")
        hit = known and active
        print(f"   {'✅' if hit else '⛔'} replayFixture: dosya VAR ama test "
              f"DÜŞÜYOR → hâlâ blokluyor: "
              f"{'yakalandı' if hit else 'YAKALANMADI — SAHTE KAPI'} ({expl})")
        ok = ok and hit
        fired[0] += 1
    finally:
        _REPLAY_TEST_CACHE.clear()
        _REPLAY_TEST_CACHE.update(saved_cache)

    # K10 GERÇEK deliği İKİ kaynağı birlikte boşaltmakla ortaya çıkar; tek
    # taraf boşaltmak yalnız çelişki kapısını ateşler ve K10'u kanıtlamaz
    # (ölçüm: MUT-A sessizdi, MUT-B yakalanıyordu — G-105). Bu yüzden K8
    # gibi katalog+kütüphane birlikte mutasyona sokuluyor.
    lib = copy.deepcopy(base_lib)
    live(lib)["courses"] = []

    def lookup_nocourse(cid):
        cat = copy.deepcopy(catalogs.get(cid))
        if cat is not None and cid == live_id:
            cat["courses"] = []
        return cat

    found = check(lib, lookup_nocourse, ref_lookup)
    hit = any("SIFIR kurs" in v for v in found)
    print(f"   {'✅' if hit else '⛔'} K10 live ama kurssuz (K1'in ikizi): "
          f"{'yakalandı' if hit else 'YAKALANMADI — SAHTE KAPI'}")
    ok = ok and hit
    fired[0] += 1
    # NEGATİF İKİZ: mutasyon ÇELİŞKİ kapısını ateşlememeli, yoksa yukarıdaki
    # "yakalandı" K10'u değil eski kapıyı ölçmüş olur (vekil-ölçüm sınıfı).
    proxy = any("katalog courses[]" in v for v in found)
    print(f"   {'✅' if not proxy else '⛔'} K10 vekil-ölçüm değil "
          f"(çelişki kapısı SUSUYOR): {'temiz' if not proxy else 'VEKİL ÖLÇÜM'}")
    ok = ok and not proxy
    fired[0] += 1

    print(f"✅ {fired[0]}/{fired[0]} kapı ateşlendi" if ok
          else "⛔ bazı kapılar ateşlenmedi")
    return 0 if ok else 1



#: ⭐ K13 — ÖZNE TESTİ (J-177 aktarımı).
#:
#: > *Ölü kod sessizdir, ÖLÜ BEYAN KONUŞUR.* Bir alanın etkisi onu okuyan
#: > KODLA sınırlı değil; onu okuyan YAZARI da sayar.
#:
#: Ayırıcı ölçüt ÖZNE: *"çoğu eğitmen…"* alan iddiasıdır, sorun yok.
#: *"BİZ ölçeriz / BİZ izleriz / en çok BİZ…"* ÜRÜN iddiasıdır ve dayanak
#: ister. Dayanak burada tek yerde: canlı hareketlerin `honesty.measured`
#: listesi. Orada yoksa, iddia ölçümden GENİŞTİR.
#:
#: ⚠️ Ölçüt DAR: yalnız birinci çoğul + YETENEK fiili. "we will never tell
#: you" gibi SINIR cümleleri serbest — onlar iddiayı daraltır, genişletmez.
CAPABILITY_VERBS = ("watch", "grade", "judge", "detect", "measure", "score",
                    "time", "check", "track", "count")


def product_claims(lib):
    """Ölçümden GENİŞ ürün iddiaları — üretilmiş ve curated metinlerde."""
    import re

    measured = " ".join(
        line.lower()
        for m in lib["movements"] if m.get("status") == "live"
        for line in m.get("honesty", {}).get("measured", []))

    # ⭐ TERS İKİZ DERSİ: ilk hâli yalnız "we <verb>" arıyordu ve ÜÇ
    # koşumda ölçüldü — *"Knee angle **is watched**"* ve *"**Gravita
    # watches** your knee angle"* kapıdan GEÇİYORDU. Yani kapı, iddiayı
    # SİLMEYİ değil ÖZNEYİ GİZLEMEYİ ödüllendiriyordu.
    #
    # > *Bir kapı, kendisini geçmenin YANLIŞ yolunu da kapatmalı.*
    #
    # Düzeltme: ürün öznesi AÇIK olsun (biz/Gravita/uygulama/motor) ya da
    # GİZLİ (edilgen) — ikisi de tutulur. Alan iddiası serbest kalır çünkü
    # o kendi öznesini ADLANDIRIR ("most instructors", "coaches").
    #: Kendi kendini SINIRLAYAN cümle: yetenekten söz eder ama kullanıcının
    #: onu almadığını AYNI satırda söyler.
    BOUNDED = re.compile(
        r"no screen|nothing in (?:the|this) app|nothing actually tells you|"
        r"we do not count it|never a score|does not (?:show|display)|"
        r"is not shown|permanent limit", re.I)

    PRODUCT = r"(?:we|our|gravita|the app|the engine|the camera|it)"
    pat = re.compile(
        rf"\b{PRODUCT}(?:\s+(?:can|do|does|would|will))?\s+("
        + "|".join(CAPABILITY_VERBS) + r")(?:e?s)?\b", re.I)
    # Edilgen: özne SİLİNMİŞ hâl. Okuyan boşluğa "uygulama"yı koyar.
    passive = re.compile(
        r"\b(?:is|are|was|were|be|been|gets?|being)\s+(?:\w+\s+){0,2}("
        + "|".join(v + "ed" if not v.endswith("e") else v + "d"
                   for v in CAPABILITY_VERBS) + r")\b", re.I)

    out = []
    for m in lib["movements"]:
        # ⭐ Choreia aktarımı: *kusur cümlenin KONUSUNDA değil,
        # ÖNVARSAYIMINDA.* Bir yanlış iddianın yaşayabileceği en ucuz yer
        # yan cümledir, çünkü kimse konu olmayan cümleciği tekrar okumaz.
        # İlk hâlim yalnız `comingSoonInThisMovement`a bakıyordu; dürüstlük
        # kutusunun kendisi ve ön koşul gerekçeleri DIŞARIDAYDI — yani
        # kapı, korumak için kurulduğu metnin çoğunu hiç görmüyordu.
        lines = list(m.get("comingSoonInThisMovement", []))
        for key in ("measured", "notMeasured", "waitingOnMeasurement"):
            lines += m.get("honesty", {}).get(key, [])
        if isinstance(m.get("honesty", {}).get("scoring"), str):
            lines.append(m["honesty"]["scoring"])
        if isinstance((m.get("precondition") or {}).get("rationale"), str):
            lines.append(m["precondition"]["rationale"])
        for field in ("_",):
            for line in lines:
                # ⚠️ OLUMSUZLUK İDDİAYI TERSİNE ÇEVİRİR. İlk taslak
                # *"...so it would **not** be graded even once the tolerance
                # question is settled"* cümlesini yakaladı — o cümle
                # yeteneği iddia etmiyor, REDDEDİYOR. Bu gecenin 12.
                # fazla-geniş ilk taslağı; ölçüt yine DARALTILDI.
                # ⭐ 13. daraltma — ve bu sefer bir SINIFI KORUMAK için.
                #
                # Kapı şu cümleyi yakalıyordu: *"Tempo — the engine measures
                # it from the real turnaround point… **But no screen in this
                # app shows it to you, so we do not count it as something
                # you get.**"* Bu dosyadaki EN DİKKATLİ cümle, ve kapı onu
                # ihlal sayıyordu.
                #
                # Kusur benim ölçütümdeydi: dayanağı yalnız
                # `honesty.measured` (kullanıcının ALDIĞI) saymıştım. Motorun
                # YAPABİLDİĞİ ayrı bir gerçek — cümle kullanıcının onu
                # ALMADIĞINI açıkça söylüyorsa iddia ölçümden geniş DEĞİL,
                # tam sınırında.
                #
                # > Dürüstlük kapısı, dürüst cümleyi cezalandırıyorsa
                # > ölçütü yanlıştır.
                if BOUNDED.search(line):
                    continue

                def claimed(rx, label):
                    out = []
                    for mt in rx.finditer(line):
                        # ⚠️ Olumsuzluk İKİ yerde durabilir ve ilk taslak
                        # ikisini de kaçırdı: (a) *"**Nothing** is measured
                        # here"* — "Nothing"/"None"/"neither" olumsuz sözcük
                        # listemde yoktu; (b) *"load and distance are **not**
                        # measured"* — "not", edilgen kalıbın KENDİ boşluğuna
                        # düşüyor, yani öncesine bakan pencere onu göremiyor.
                        # Bu yüzden pencere + eşleşmenin KENDİSİ birlikte
                        # taranıyor.
                        span = (line[max(0, mt.start() - 24):mt.start()]
                                + mt.group(0)).lower()
                        if re.search(r"\b(not|never|no|nothing|none|neither|"
                                     r"cannot|without)\b|"
                                     r"n[''\u2019]t\b",
                                     span):
                            continue
                        out.append((mt.group(1), label))
                    return out

                found = claimed(pat, "açık özne")
                found += [(v[:-2] if v.endswith("ed") else v[:-1],
                           "EDİLGEN — özne gizlenmiş")
                          for v, _ in claimed(passive, "")]
                for verb, how in found:
                    if verb.lower() not in measured:
                        out.append(
                            f"{m['id']}: '{verb}' yeteneği iddia ediliyor "
                            f"({how}) ama canlı hareketlerin ölçülenler "
                            f"listesinde YOK — ölçümden geniş ürün iddiası")
    return out


def main():
    if "--self-test" in sys.argv:
        print("kapı ateşleme sınaması (kasıtlı ihlaller):")
        return _self_test()

    lib = load(LIB_PATH)
    catalogs = load_catalogs()
    def ref_lookup(mid):
        p = HARVEST_DIR / f"reference.{mid}.json"
        return load(p) if p.exists() else None

    violations = check(lib, lambda cid: catalogs.get(cid), ref_lookup)

    if violations:
        print(f"⛔ {len(violations)} DÜRÜSTLÜK İHLALİ:")
        for v in violations:
            print(f"   - {v}")
        return 1

    live = [m["id"] for m in lib["movements"] if m.get("status") == "live"]
    soon = [m["id"] for m in lib["movements"] if m.get("status") == "coming_soon"]
    lessons = sum(len(c.get("lessons", []))
                  for m in lib["movements"] for c in m.get("courses", []))
    locked = sum(1 for m in lib["movements"] for c in m.get("courses", [])
                 for l in c.get("lessons", []) if l.get("status") == "locked")
    if claims := product_claims(lib):
        for c in claims:
            print(f"⛔ ÖZNE: {c}")
        return 1

    print(f"✅ kütüphane denetimi TEMİZ — {len(lib['movements'])} hareket "
          f"({len(live)} canlı: {live} · {len(soon)} yakında: {soon}) · "
          f"{lessons} ders ({locked} kilitli, hepsi isimli gerekçeli) · "
          f"12 değişmez (19 kapı dalı)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
