#!/usr/bin/env python3
"""Katalog → kütüphane TERFİ aracı (koordinatör hükmü, 2026-08-06).

## Hangi soruyu cevaplıyor

`content/catalog/` 31 hareketin kural-setini taşıyor; `content/library.json`
kullanıcının GÖRDÜĞÜ tek kaynak ve bugüne dek 2 hareket taşıyordu. Tasarım
paneli "31 MOVEMENTS / 9 families" iddia ediyor. Üç sayı üç ayrı şeyi ölçüyordu
ve hiçbiri ötekiyle uzlaşmıyordu.

**Koordinatör hükmü:** kullanıcı-gerçeği `library.json`'dır; katalog bir
HAZIRLIK HAVUZUDUR, vitrin değil. Bir hareket kütüphaneye ancak HAK EDEREK
girer — ama girmemek onu GÖRÜNMEZ kılmaz: girmeyen hareket de görünür, İSİMLİ
gerekçesiyle.

Bu araç o hükmün mekanik hâlidir: 31 hareketin hepsini kütüphaneye taşır,
her birinin durumunu ARTEFAKTTAN türetir ve gerekçesini ELLE YAZMAZ.

## Terfi ölçütü (ölçüm olmadan terfi YOK)

Bir hareket `status: live` olabilmek için ÜÇ artefakt kapısını da geçmeli —
üçü de `validate_library.py._blocker_active`'in MAKİNEYLE doğruladığı
anahtarlar, yani bu araç kendi hükmünü kendi vermiyor:

  1. `engine.precondition.status == derived`  (G-043: kimlik ön koşulu yoksa
     tekrar FSM'i hareketi değil salınımı sayar)
  2. replay fixture VAR                        (kural gerçek veride ateşlendi mi)
  3. `provenance.sources` DOLU                 (tolerans ölçümden mi geliyor)

Bugün 31/31 hareketin **1'i** (push_up) bunların hepsini geçiyor. Kalan 30
`coming_soon` — ve bu bir EKSİKLİK DEĞİL, ÖLÇÜM KUYRUĞUDUR; ürün de öyle sunar.

## İki hareket neden ELLE yazılı kalıyor (`honestySource: curated`)

`push_up` ve `bodyweight_squat`'ın dürüstlük kutusu HASAT ARTEFAKTLARINDAN
gelen GERÇEK SAYILAR taşıyor (14.7°/32.0° sol-sağ farkı, 5 eğitmen/36 çekim,
barbell-kirlenmesi hikâyesi). Katalogda o sayılar YOK. Onları üretilmiş
metinle ezmek İÇERİK KAYBI olurdu — bu yüzden ikisi `honestySource: curated`
işaretlidir ve `--check` onların prose'unu DRIFT açısından denetlemez.

⚠️ **MUAFİYETİN SINIRI DARALTILDI (2026-08-07, JabLab aktarımı).** Muafiyet
YALNIZ drift'e uygulanır — *"bu prose yeniden üretilenle aynı mı"* sorusuna.
Her girdiye uygulanan DEĞİŞMEZLERE (vaat dili · defter kodu · `measured`
iddiasının kabukta yolu var mı) **uygulanmaz.**

Gerekçe ölçümle: eski geniş muafiyet iki gerçek kusuru sakladı — (a) push_up'ın
3 yanlış `measured` iddiası, (b) curated prose'taki 8 defter kodu. İkisi de
TAMAMEN muaf alanların içindeydi; ikisini de bir kapı değil insan sorusu
buldu. *Muafiyet, kapının kendi kör noktasını üretir* — muafiyet ne kadar
GENİŞSE kör nokta o kadar büyük.

⚠️ Muafiyet SESSİZ değil BEYAN EDİLMİŞ: bu defterin gece boyu avladığı desen
"beyan var, okuyanı yok"tu; muafiyeti dosyaya yazıp okutmak onun aynası.
Türetimli ALANLAR (equipment/level/aliases/...) curated girdilerde de
üretilir — orada elle yazılmış bir şey yok, olsa drift ederdi.

## Kullanım

    python3 tools/promote_library.py            # ne değişecek, YAZMADAN
    python3 tools/promote_library.py --write     # uygula
    python3 tools/promote_library.py --check     # CI kapısı: drift VAR mı

`--check` İKİ şeyi ölçer:
  (a) **kapsam:** katalogdaki her hareket kütüphanede var mı (yeni bir katalog
      girdisi vitrine sessizce girmeyi ATLAYAMAZ)
  (b) **drift:** üretilmiş alanlar bugün üretilenle aynı mı (biri elle
      düzenlediyse ya da katalog değişip kütüphane bayatladıysa yakalanır)
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB_PATH = ROOT / "content" / "library.json"
CATALOG_ROOT = ROOT / "content" / "catalog"
CLASSES_PATH = ROOT / "content" / "schema" / "movement-classes.json"
FIXTURE_DIR = ROOT / "packages" / "gravita_engine" / "test" / "fixtures"

GENERATED_MARK = "generated"

#: Üretilmiş girdide bu alanlar ARACIN malıdır — elle düzenlenirse `--check`
#: bunu drift olarak bildirir. `honesty`/`blurb`/`comingSoonInThisMovement`
#: yalnız `honestySource != curated` olan girdilerde bu kümededir.
DERIVED_FIELDS = (
    "displayName", "family", "level", "class", "wave", "catalogId",
    "equipment", "muscleGroups", "aliases", "classBadge",
    "safetyWarnings", "skillGraphNode", "referenceSources",
)


def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def load_catalogs():
    """Katalog girdileri — DALGA-BAĞIMSIZ okunur (G-099 dalga-körlüğü ailesi)."""
    out = {}
    for wave in sorted(p for p in CATALOG_ROOT.iterdir() if p.is_dir()):
        for entry in sorted(wave.glob("*.json")):
            out[entry.stem] = load(entry)
    return out


# ── Kapılar: her biri ARTEFAKTA bakar, hiçbiri kanaate bakmaz ──────────────

def has_replay_fixture(mid):
    if not FIXTURE_DIR.is_dir():
        return False
    return any(p.name.startswith(mid) for p in FIXTURE_DIR.glob("*.json"))


def blockers_for(mid, cat):
    """ŞU AN bloklayan anahtarlar — `validate_library._blocker_active` sözlüğü.

    Anahtar üretmiyoruz, o denetçinin TANIDIĞI anahtarları kullanıyoruz:
    tanımadığı bir anahtar yazsaydık kütüphane denetimi "tanınmayan bloker"
    diye ÖTERDİ. İki araç aynı sözlüğü konuşuyor — kapı ile beyanın aynı
    dili konuşması, K9'un bayat-kilit denetiminin ön şartı.
    """
    keys = []
    if cat.get("engine", {}).get("precondition", {}).get("status") != "derived":
        keys.append("engine.precondition.status!=derived")
    if not has_replay_fixture(mid):
        keys.append("replayFixture:missing")
    if not (cat.get("provenance", {}).get("sources") or []):
        keys.append("provenance.sources:empty")
    return keys


# ── Üretim: her cümle bir alandan doğar ────────────────────────────────────

_UNIT_NOUN = {
    "repFsm": "Rep counting and tempo",
    "staticHold": "Hold timing and body-line tracking",
    "multiPhaseFsm": "Phase-by-phase tracking",
}


def _blocker_sentence(key, mid, name, cat):
    """Bir bloker anahtarının KULLANICI cümlesi — anahtar başına TEK ev.

    Cümleler harekete göre değişen sayıları (kural adedi, kaynak adedi)
    kendi kataloğundan alır: "üç kural" diyen bir cümle, üç kuralı olmayan
    bir harekette YANLIŞ olurdu.
    """
    # ⚠️ HİÇBİR CÜMLEDE "yet" YOK (M-F-186, koordinatör hükmü 2026-08-07).
    # "not open yet" bir SÖZ verir; "closed" bir DURUM bildirir. Cümlenin geri
    # kalanı (kaç ölçüm eksik, adları) dürüstlüğü zaten taşıyor — "yet" hiçbir
    # bilgi eklemiyordu, yalnız zamanlama vaat ediyordu. Aynı hatayı Ostinato
    # bu gece elle 7 yerde temizledi; burada şablon TEK yer olduğu için 30
    # hareket tek düzeltmeyle kapanıyor. Şablonun kaldıracı iki yönlü çalışır.
    #
    # ⚠️ HİÇBİR CÜMLEDE DEFTER KODU DA YOK. İlk yazışımda buraya "(G-043)"
    # koymuştum — kullanıcıya hiçbir şey söylemeyen bir iç-kayıt kimliği.
    # Aynı sınıf kural zaten var ("ham detail/hata kodu yüzeye sızmaz"); iz
    # sürülebilirlik `blockedBy` anahtarında ve katalogun `rationale`ında
    # duruyor, kullanıcı cümlesinde değil. İzlenebilirlik iç tarafın işidir.
    if key == "engine.precondition.status!=derived":
        return (
            f"There is no identity check for this movement. For push-ups we "
            f"verify your torso is actually horizontal before a rep counts; the "
            f"equivalent test for the {name.lower()} has not been derived from "
            f"measurement, so nothing would stop us counting a movement that "
            f"only looks like one."
        )
    if key == "replayFixture:missing":
        n = len(cat.get("formErrors") or [])
        # ⚠️ SIFIR kural AYRI bir kuyruktur (JabLab aktarımı, 2026-08-07).
        # "0 kural hiç koşturulmadı" cümlesi teknik olarak doğru ama YANLIŞ
        # KUYRUĞU gösterir: burada eksik olan ÖLÇÜM değil KODdur. Sınırın
        # sınıfını yazmak yetmiyor — hangi kuyruğa gittiğini de yazmak
        # gerekiyor, yoksa kapanmayacak şey kovalanır ya da kapanacak şey
        # bekletilir. Ölçüldü: `floor_press`in hiç kuralı yok.
        if n == 0:
            return (
                "No error rules have been written for this movement at all. "
                "Anything we said about its form would be a guess, because "
                "there is nothing defined to look for."
            )
        rules = "rule" if n == 1 else "rules"
        return (
            f"Its {n} error {rules} have never been run against real footage. "
            f"There is no replay fixture for this movement, so we have no "
            f"evidence they fire when they should — or stay quiet when they "
            f"should."
        )
    if key == "provenance.sources:empty":
        return (
            "No instructor reference has been harvested for this movement, so "
            "every tolerance in its rules sits at our default floor rather than "
            "coming from measured disagreement between real instructors. A "
            "number from a default is not a measurement."
        )
    raise AssertionError(f"cümlesi olmayan bloker anahtarı: {key}")


def _dedupe(items):
    """Sıra korunarak tekilleştirme — aynı sınır iki kez söylenmez."""
    seen, out = set(), []
    for it in items:
        k = it.strip().lower()
        if k and k not in seen:
            seen.add(k)
            out.append(it)
    return out


def scoring_statement(grading_lessons_open):
    """⭐ TESPİT/KOÇLUK ile PUANLAMA ayrımı — ÜRETİLİR (J-113 aktarımı).

    JabLab'ın bulgusu: *"ölçülenler"* listesi İKİ AYRI iddiayı tek başlıkta
    topluyor — *"tespit edip koçluyoruz"* ile *"puanlıyoruz"*. Kullanıcı
    ikincisini okuyor. **M-F-287'nin TERS yönü:** bir SINIRI değil bir
    YETENEĞİ olduğundan geniş yazmak — ve bu daha tehlikeli, çünkü hata
    kullanıcının ALEYHİNE.

    Gravita'da ölçüldü (2026-08-07): 30/31 hareket ipucu veren **71 kural**
    taşıyor (tespit + koçluk) ama **bugün gerçekten puanlayan ders 0** — tek
    form-notu dersi kilitli ve `scoreDisplay` 31/31 `band`. Yani sınıf VAR ve
    üstelik BASKIN; eksik olan ADI.

    Cümle ARTEFAKTTAN türer (`grading_lessons_open` sayısı), elle yazılmaz:
    ilk ders notlamaya başladığı gün kendiliğinden değişir. Sabit yazılsaydı
    o gün sessizce yalan olurdu.
    """
    if grading_lessons_open == 0:
        return (
            "None of this is a score. We count and time what is listed above, "
            "and when a rule fires we tell you what to change — but no number "
            "grades your form, on this movement or any other in Gravita. Form "
            "grading stays shut until joint tolerances come from measured "
            "disagreement between real instructors rather than from our "
            "default floor."
        )
    return (
        f"{grading_lessons_open} "
        f"{'lesson' if grading_lessons_open == 1 else 'lessons'} in Gravita "
        f"now grade form against a measured instructor reference. Everything "
        f"listed above that is not part of one of those lessons is counted or "
        f"timed and cued, not scored."
    )


def generate_entry(mid, cat, classes, grading_lessons_open=0):
    """Katalog girdisinden kütüphane girdisi — TEK bir cümle elle yazılmadan.

    Dürüstlük kutusunun kaynağı W0 §3'ün sözleşmesi: `measurementContract`
    + sınıfın `userCopy`'si. Bu araç oraya BİR ŞEY EKLEMİYOR, yalnız
    hareketin BUGÜNKÜ durumunu (kapılar) o sözleşmenin önüne koyuyor.
    """
    name = cat["name"]
    mc = cat.get("measurementContract", {})
    cls = cat.get("class", "A")
    class_copy = classes.get(cls, {}).get("userCopy", {})
    keys = blockers_for(mid, cat)
    live = not keys

    # ── DERS 5: sınırın SINIFINI da yaz ────────────────────────────────
    # "ölçülmedi" (kuyruk, açılabilir) ile "ölçülemez" (kamera göremez,
    # kalıcı) AYNI listede toplanırsa ikisi de yanlış okunur: kalıcı sınır
    # "yakında" sanılır, kuyruk da umutsuz görünür. Bu yüzden:
    #   · kuyruk  → comingSoonInThisMovement (isimli bloker + ne açacağı)
    #   · kalıcı  → honesty.notMeasured      (katalog + sınıf userCopy)
    # Sınıfın `userCopy.notMeasured`'ı YALNIZ sınıf bir İDDİA KISITI ilan
    # ediyorsa eklenir (B: form hükmü YOK · D: prop ölçülmez). Sınıf A'nın
    # kopyası jenerik bir üçlüdür ("Force or torque · Muscle activation ·
    # Load on the bar") ve her A-hareketi bunu zaten KENDİ sözcükleriyle
    # söylüyor.
    #
    # ⚠️ Bu bir zevk kararı değil, ÖLÇÜLMÜŞ bir kusurun düzeltmesi: ilk
    # koşumda plank'ın dürüstlük kutusunda **"Load on the bar"** yazıyordu.
    # Plank'ta bar yoktur. Jenerik sınıf metnini hareket-özel metnin yanına
    # koymak, doğru bir cümleyi YANLIŞ bir yere taşıyor — ve dürüstlük
    # kutusunun bütün değeri tam olarak orada.
    claims = classes.get(cls, {}).get("claims", {})
    class_declares_restriction = (
        claims.get("formVerdict") is False or claims.get("propMetric") is False
    )
    permanent = _dedupe(
        list(mc.get("notMeasured") or [])
        + (list(class_copy.get("notMeasured") or [])
           if class_declares_restriction else [])
    )

    if live:
        # Bugün buraya düşen tek hareket push_up; o da `curated`, yani bu dal
        # pratikte üretim yapmaz. Yine de DOĞRU olmak zorunda: kapılar bir gün
        # açıldığında sessizce yanlış metin üretmesin.
        honesty = {
            "measured": list(mc.get("measured") or []),
            "notMeasured": permanent,
            # ⭐ Terfi eden HER hareket bu ayrımı taşır. Taşımasaydı, katalogun
            # `measured` satırları ("Body-line alignment over time", "Time
            # until form starts to break") 31 harekette birden PUANLAMA
            # iddiası gibi okunurdu — koordinatörün uyardığı çoğalma tam bu.
            "scoring": scoring_statement(grading_lessons_open),
        }
        coming_soon = []
    else:
        n = len(keys)
        lead = (
            f"Nothing is measured here. The rules for the {name.lower()} are "
            f"written, but {n} {'thing is' if n == 1 else 'things are'} still "
            f"missing before we would run them — and each one alone is enough "
            f"for us to keep this closed."
        )
        honesty = {
            # `scoring` YOK: ölçülen hiçbir şey yokken "bu bir puan değil"
            # demek, olmayan bir şeyi nitelemek olurdu. Ayrım ancak bir
            # `measured` iddiası VARSA anlamlıdır — kapı da bunu böyle sorar.
            # ⚠️ BOŞ: katalogun `measured` listesi bu hareketin ölçüldüğünü
            # DEĞİL, ölçülmek üzere YAZILDIĞINI anlatır. Onu "measured"
            # başlığı altına koymak vaat dili olurdu (M-F-186) — kuyruğa
            # gidiyor, aşağıya.
            "measured": [],
            # ⭐ İKİ AYRI KUYRUK, İKİ AYRI ALAN (JabLab aktarımı, 2026-08-07).
            #
            # Eskiden ikisi TEK listede duruyordu ve kullanıcı *"henüz
            # ölçmedik"* ile *"tek kamera bunu göremez"* arasındaki farkı
            # GÖREMİYORDU. Oysa biri bir gün kapanır, öteki ASLA kapanmaz —
            # ve bir kullanıcının ürünü doğru anlaması tam olarak bu farka
            # bağlı. M-F-287 sınırın SINIFINI yazmayı söylüyordu; bu, sınıfın
            # hangi KUYRUĞA gittiğini de yazıyor.
            "waitingOnMeasurement": [lead]
                + [_blocker_sentence(k, mid, name, cat) for k in keys],
            "notMeasured": permanent,
        }
        designed = list(mc.get("measured") or [])
        headline = _UNIT_NOUN.get(cat.get("engine", {}).get("type"), "Measurement")
        coming_soon = [
            f"{headline} — this movement's rules are written to measure "
            f"{_prose_list(designed)}, and none of it runs today. What would "
            f"open it: {_prose_list([_blocker_short(k) for k in keys])}.",
        ]

    entry = {
        "id": mid,
        "displayName": name,
        "family": cat.get("family"),
        "level": cat.get("level"),
        "class": cls,
        "status": "live" if live else "coming_soon",
        "wave": f"W{cat['wave']}",
        "catalogId": mid,
        # ── Yüzey metadata'sı (Library araması + Movement page başlığı) ──
        # Katalogdan KOPYALANIR, elle girilmez; `--check` drift'i yakalar.
        # Motora (`MovementConfig`) eklenmedi: motor ölçüm katmanıdır, sunum
        # alanı taşımamalı ("motor kullanıcı metni ÜRETMEZ", progress_strings).
        "equipment": list(cat.get("equipment") or []),
        "muscleGroups": list(cat.get("muscleGroups") or []),
        "aliases": list(cat.get("aliases") or []),
        # ⚠️ `engineType` KALDIRILDI (öksüz-anahtar kapısı, J-129). Üretiliyordu
        # ama hiçbir parser okumuyordu — "beyan var, okuyanı yok"un ta kendisi,
        # ve bu turda tam o deseni avlıyordum. Bir yüzey ihtiyaç duyduğu gün
        # katalogdan gelir (`MovementConfig.engineType`), kütüphaneye kopya
        # gerekmiyor.
        "classBadge": class_copy.get("badge"),
        "safetyWarnings": list((cat.get("safety") or {}).get("warnings") or []),
        # ⚠️ Hasat edilmiş eğitmen SAYISI — yüzeyin "referans yok" cümlesini
        # KOŞULLU kurabilmesi için. Ölçüldü: o cümle KOŞULSUZ çiziliyordu ve
        # `push_up`ta aynı sayfanın iki bloğu birbiriyle ÇELİŞİYORDU —
        # üstte *"hiç kayıtlı eğitmen referansımız yok"*, altta *"5 eğitmen,
        # 36 çekim ATTESTED"*. Cümle yazıldığında doğruydu; hasat geldi,
        # cümle yerinde kaldı.
        "referenceSources": len(cat.get("provenance", {}).get("sources") or []),
        # Yalnız GERÇEKTEN bir düğüme bağlıysa yazılır (3/31). `null` taşımak
        # "bağ var ama boş" gibi okunur; alanın YOKLUĞU daha dürüst.
        **({"skillGraphNode": cat["skillGraphNode"]}
           if cat.get("skillGraphNode") else {}),
        "blurb": _blurb(name, live, keys),
        "honesty": honesty,
        # K1: coming_soon'da kurs OLAMAZ. Katalog `courses` beyanı bir HAZIRLIK
        # kaydıdır; kütüphaneye ancak hareket canlıyken ve dersleriyle geçer.
        "courses": [],
        "comingSoonInThisMovement": coming_soon,
        "_source": GENERATED_MARK,
    }
    if not live:
        entry["blockedBy"] = keys
        entry["blockClass"] = "measurement"
        # Kuyruklar TÜRETİLİR, elle yazılmaz — bloker anahtarından.
        entry["blockedByQueue"] = sorted({BLOCKER_QUEUE[k] for k in keys})
    return entry


#: Her bloker anahtarı hangi KUYRUĞA gider (J-125 aktarımı, 2026-08-07).
#:
#: M-F-287 sınırın SINIFINI yazmayı söylüyordu; bu, sınıfın hangi kuyruğa
#: gittiğini ekliyor — ve fark PRATİK: kuyruk, o engeli **kimin** kapatacağını
#: söyler.
#:
#:   `measurement` → kapatması ÖLÇÜM (hasat/çekim). Kod yazarak açılmaz.
#:   `code`        → kapatması KOD. Bu gece açılabilir.
#:   `impossible`  → hiçbir kod ve hiçbir ölçüm kapatmaz (fiziksel sınır).
#:
#: ⚠️ Bu sözlük bir İDDİAYI komuta çeviriyor: *"bu gece hangi hareket
#: açılabilir?"* sorusu artık prose değil, `--queues` çıktısı.
BLOCKER_QUEUE = {
    # Kimlik ön koşulu ölçümle TÜRETİLİR — eşiği kod yazarak uyduramayız.
    "engine.precondition.status!=derived": "measurement",
    # Replay fixture KAYIT gerektirir (gerçek görüntü + beklenen çıktı).
    "replayFixture:missing": "measurement",
    # Eğitmen referansı HASAT işidir.
    "provenance.sources:empty": "measurement",
}

_BLOCKER_SHORT = {
    "engine.precondition.status!=derived": "deriving an identity check from measurement",
    "replayFixture:missing": "running its rules against real recorded footage",
    "provenance.sources:empty": "harvesting a real instructor reference",
}


def _blocker_short(key):
    return _BLOCKER_SHORT[key]


def _prose_list(items):
    """`a, b and c` — Oxford'suz, boş listede dürüst bir sözcük."""
    items = [str(i).rstrip(".").lower() for i in items if str(i).strip()]
    if not items:
        return "nothing"
    if len(items) == 1:
        return items[0]
    return ", ".join(items[:-1]) + " and " + items[-1]


def _blurb(name, live, keys):
    if live:
        return f"{name} — open, with what we measure listed below."
    n = len(keys)
    return (
        f"{name} is in our catalogue and closed. "
        f"{n} {'measurement is' if n == 1 else 'measurements are'} missing "
        f"before we would coach it — named below, in plain terms."
    )


# ── Uygulama ───────────────────────────────────────────────────────────────

def count_open_grading_lessons(lib):
    """BUGÜN gerçekten form notu veren ders sayısı — kilitliler HARİÇ.

    `scoring_statement` bunun üstüne kuruluyor. Kilitli bir dersi saymak,
    henüz verilmeyen bir hükmü verilmiş göstermek olurdu.
    """
    return sum(
        1
        for m in lib["movements"]
        for c in (m.get("courses") or [])
        for l in (c.get("lessons") or [])
        if l.get("gradesFormAgainstReference") and l.get("status") != "locked"
    )


def apply(lib, catalogs, classes):
    """Kütüphaneyi katalogla uzlaştırır; (yeni_lib, rapor) döner."""
    grading_open = count_open_grading_lessons(lib)
    by_id = {m["id"]: m for m in lib["movements"]}
    added, refreshed, drifted = [], [], []

    for mid in sorted(catalogs):
        cat = catalogs[mid]
        fresh = generate_entry(mid, cat, classes, grading_open)
        existing = by_id.get(mid)

        if existing is None:
            by_id[mid] = fresh
            added.append(mid)
            continue

        # ⚠️ `scoring` TÜRETİMLİ bir alandır, prose değil — daraltılmış
        # muafiyetin tam da tarif ettiği sınıf: curated girdi PROSE'undan
        # muaftır, DEĞİŞMEZLERDEN ve türetimli alanlardan değil. Bu yüzden
        # curated girdilerin dürüstlük kutusuna da BURADAN yazılıyor.
        if existing.get("honesty", {}).get("measured"):
            existing.setdefault("honesty", {})["scoring"] = \
                scoring_statement(grading_open)
        elif existing.get("honesty", {}).get("scoring") is not None:
            existing["honesty"].pop("scoring")

        curated = existing.get("honestySource") == "curated"
        fields = DERIVED_FIELDS if curated else DERIVED_FIELDS + (
            "blurb", "honesty", "comingSoonInThisMovement", "status",
            "blockedBy", "blockClass", "blockedByQueue",
        )
        # Kuyruk TÜRETİMLİ alandır — curated girdilerde de yazılır
        # (daraltılmış muafiyet: prose muaf, türetim değil).
        if curated and "blockedBy" in existing:
            existing["blockedByQueue"] = sorted(
                {BLOCKER_QUEUE[k] for k in existing["blockedBy"]
                 if k in BLOCKER_QUEUE})
        for f in fields:
            # OPSİYONEL alanlar: üretimde YOKSA, mevcutta da OLMAMALI —
            # `None` yazmak alanı "var ama boş" hâline getirirdi. `in` ile
            # sorulur, `.get()` ile değil: ikisi `null` taşıyan bir alanda
            # farklı cevap verir ve fark tam da burada önemli.
            if f not in fresh:
                if f in existing:
                    drifted.append(f"{mid}.{f}(kaldırıldı)")
                    existing.pop(f)
                continue
            new = fresh[f]
            if existing.get(f) != new or f not in existing:
                drifted.append(f"{mid}.{f}")
                existing[f] = new
        if not curated:
            existing["_source"] = GENERATED_MARK
        if any(d.startswith(f"{mid}.") for d in drifted):
            refreshed.append(mid)

    # Sıra: canlılar önce, sonra aile, sonra ad — kütüphanenin dosya düzeni
    # kullanıcıya gösterilen sırayı BELİRLEMEZ (o Library ekranının işi) ama
    # diff'i okunur tutar.
    lib["movements"] = sorted(
        by_id.values(),
        key=lambda m: (m.get("status") != "live", m.get("family") or "",
                       m.get("displayName") or ""),
    )
    return lib, {"added": added, "refreshed": refreshed, "drifted": drifted}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--queues", action="store_true",
                    help="hangi hareket HANGİ kuyrukta bekliyor — ve bu gece "
                         "KOD yazarak hangisi açılabilir")
    args = ap.parse_args()

    lib = load(LIB_PATH)
    catalogs = load_catalogs()
    classes = {c["id"]: c for c in load(CLASSES_PATH)["classes"]}

    missing = sorted(set(catalogs) - {m["id"] for m in lib["movements"]})
    _, report = apply(json.loads(json.dumps(lib)), catalogs, classes)

    if args.queues:
        # ⭐ Koordinatörün sorusunun KOMUT hâli: *"kod bekleyenler bu gece
        # açılabilir, ölçüm bekleyenler açılamaz."* Cevabı artık prose değil.
        by_queue = {}
        openable = []
        for m in lib["movements"]:
            qs = set(m.get("blockedByQueue") or [])
            if not qs:
                continue
            for q in qs:
                by_queue.setdefault(q, []).append(m["id"])
            # ÖLÇÜM kuyruğunda HİÇ engeli olmayan hareket, kod yazarak açılır.
            if "measurement" not in qs:
                openable.append(m["id"])
        for q in sorted(by_queue):
            print(f"   {q:12} {len(by_queue[q]):2} hareket")
        print()
        if openable:
            print(f"🟢 KOD yazarak açılabilecek {len(openable)} hareket: "
                  f"{', '.join(sorted(openable))}")
        else:
            print("⛔ KOD yazarak açılabilecek hareket YOK — bloklu her "
                  "hareket en az bir ÖLÇÜM engeli taşıyor.")
            print("   Yani kuyruk ayrımı KULLANICI anlayışını düzeltir, "
                  "terfi kapısını AÇMAZ.")
        return 0

    if args.check:
        problems = []
        if missing:
            problems.append(
                f"KAPSAM: {len(missing)} katalog hareketi kütüphanede YOK "
                f"({', '.join(missing)}) — katalog vitrine sessizce girmeyi "
                f"atlayamaz")
        drift_existing = [d for d in report["drifted"]
                          if d.split(".")[0] not in missing]
        if drift_existing:
            problems.append(
                f"DRIFT: {len(drift_existing)} üretilmiş alan bugün üretilenle "
                f"aynı değil ({', '.join(drift_existing[:8])}"
                f"{'…' if len(drift_existing) > 8 else ''}) — elle düzenlendi "
                f"ya da katalog değişip kütüphane bayatladı")
        if problems:
            print("⛔ terfi kapısı:")
            for p in problems:
                print(f"   - {p}")
            return 1
        print(f"✅ terfi kapısı TEMİZ — {len(catalogs)} katalog hareketinin "
              f"{len(catalogs)}'i kütüphanede, üretilmiş alanlarda drift yok")
        return 0

    new_lib, report = apply(lib, catalogs, classes)
    live = [m["id"] for m in new_lib["movements"] if m.get("status") == "live"]
    print(f"terfi raporu: +{len(report['added'])} yeni · "
          f"{len(report['refreshed'])} tazelenmiş · "
          f"{len(new_lib['movements'])} toplam "
          f"({len(live)} canlı: {live})")
    for mid in report["added"]:
        print(f"   + {mid}")
    for d in report["drifted"]:
        print(f"   ~ {d}")

    if args.write:
        LIB_PATH.write_text(
            json.dumps(new_lib, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8")
        print(f"✍️  yazıldı: {LIB_PATH.relative_to(ROOT)}")
    else:
        print("(kuru koşum — uygulamak için --write)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
