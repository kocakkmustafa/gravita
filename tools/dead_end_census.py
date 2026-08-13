#!/usr/bin/env python3
"""ÇIKMAZ SOKAK SAYIMI — `A4`ün ölçüsü, beyanı değil.

## Ne sayıyor

*Çıkmaz sokak*, ailenin Choreia'da ölçtüğü tanımla: **kartına gidilir,
sayfası açılır, başlatılacak bir şey YOKTUR** (M-F-569). Sayı bir kusur
listesi değildir — Choreia'nın 34 stilinin 33'ü çıkmazdı ve bu bir
*gerçekti*, bir arıza değil.

> ***GEZİLEBİLİRLİK VARILABİLİRLİĞİ ÖLÇER, YARARLILIĞI DEĞİL.***

## ⛔ VARILAMAYAN BİR YER ÇIKMAZ SOKAK DEĞİLDİR (Lissom kuralı)

Lissom'un 9 engelli testi çıkmaz **sayılmadı**: `library_screen` onları
**dokunulamaz** satır olarak, gerekçesiyle basıyordu. Aynısı bu ağaçta
DERSLER için geçerli — `progress_view.dart` dersleri basar ama **hiçbir
dokunma işleyicisi taşımaz** (ölçüldü, ve aşağıda her koşumda YENİDEN
ölçülür: [_ders_yuzeyi_dokunulamaz]).

⇒ Sayım **HAREKET düzeyindedir.** Ders düzeyi kapsam dışıdır ve bu bir
karardır, unutma değil — kapsamın gerekçesi **düzyazı değil, kaynaktan
türetiliyor**. Dersler bir gün dokunulabilir olursa bu araç **öter** ve
sınıflandırma yeniden yapılır.

## ⛔ SINIRIM — blokerleri DOĞRULAMAM (kapının kapısı kurulmaz)

`validate_library.py` her blokeri zaten doğruluyor ve artık bloklamıyorsa
**BAYAT KİLİT** diye ötüyor (K9). Bu araç blokerleri **doğrulanmış kabul
eder** ve yalnız onları **SINIFLANDIRIR**.

> ***KAPININ KAPISINI DENETLEYEN KAPI KURULMAZ.***

## 🪤 HARF ÇARPIŞMASI — `class` alanı bu taksonomi DEĞİLDİR

`library.json`daki `"class": "A"` **KAMERA sınıfıdır** (*"yandan görünür"*).
A4 taksonomisinin `A` sınıfıyla **hiçbir ilgisi yoktur**. Bu modül kendi
sınıfını `bosluk_sinifi` diye adlandırır; `class` alanı **hiç okunmaz**.

> ***AYNI HARF, İKİ BİRİM — ve bu ağaçta ikisi de aynı dosyada yaşıyor.***

## Ne ASSERT eder, ne yalnız RAPOR eder

**ASSERT (yapı):** payda vakumu · bölme denklemi · her çıkmazın SINIFLI
olması · bilinmeyen bloker anahtarı · kapsam varsayımının hâlâ geçerliliği.

**YALNIZ RAPOR (içerik):** dağılımın kendisi. Dağılım **ürünün ilerlemesidir**
ve bir kapı ilerlemeyi kırmızıya çeviremez — bu hattın `M-F-598` bedeli.

> ***BİR ÖZ-TEST ÜRÜNÜN BİÇİMİNE ÇAPALANIR, İÇERİĞİNE DEĞİL.***
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "content" / "library.json"
PROGRESS_VIEW = ROOT / "lib" / "app" / "progress_view.dart"

# ── TAKSONOMİ ──────────────────────────────────────────────────────────────
# Kaynak: `ventures/motion-core/workspace/YAYIN-HAZIRLIK-OLCUTU.md`, A4 altı.
# ⚠️ Adlar İNGİLİZCE harf ama BİRİM taksonomidir — `library.json`ın `class`
# alanıyla karıştırılmasın diye sabitler `BOSLUK_` önekli.
BOSLUK_A = "A"        # içerik HİÇ yazılmamış            → içerik kapasitesi
BOSLUK_A_UC = "A'"    # içerik başlamış, REFERANS yok    → hasat turu
BOSLUK_B = "B"        # içerik VAR, BAĞLI değil          → HAT kapatır
BOSLUK_C = "C"        # kart hiç olmamalıydı             → HAT kapatır
BOSLUK_D = "D"        # tam + bağlı, BİLEREK kapalı      → kurucu
BOSLUK_E = "E"        # ölçüm YETENEĞİ yok (alet eksik)  → çekirdek/motor işi

#: Bloker anahtarı → boşluk sınıfı. **TAM eşleşme.**
#:
#: Gerekçeler tek tek ölçüldü (G-202) ve üçü aynı köke iniyor: bu harekete
#: ait **kayıtlı eğitmen görüntüsü yok**. Hasat indiği gün üçü birden düşer.
_BLOKER_SINIF_TAM = {
    # Referansın kendisi boş — taksonominin A′ tanımının birebir hâli.
    "provenance.sources:empty": BOSLUK_A_UC,
    # Replay fikstürü = kayıtlı görüntü + beklenen çıktı. VERİ eksiği, alet değil.
    "replayFixture:missing": BOSLUK_A_UC,
    # Kimlik ön koşulu ölçümden TÜRETİLİR; türetecek görüntü yok ⇒ hasada bağlı.
    "engine.precondition.status!=derived": BOSLUK_A_UC,
}

#: ÖNEKLİ anahtarlar — kuyruğu değişken olanlar.
#:
#: ⚠️ `metric:unimplemented@…` **E**dir, A′ değil: hasat inse bile kalkmaz,
#: çünkü eksik olan veri değil **motorun üretemediği bir büyüklük**. Bu ayrım
#: bu ağaçta bağımsız olarak zaten ödenmişti (`G-182` → `tools/metric_support.py`
#: tam da *"hasat sonunda kalkar sanılan ama kalkmayan"* blokeri için yazıldı).
#: ⇒ Taksonomi burada yeni bir şey UYDURMUYOR, ürünün zaten bildiği ayrımı
#: adlandırıyor.
_BLOKER_SINIF_ONEK = {
    "metric:unimplemented@": BOSLUK_E,
    # Referans VAR ama iddia edilen eklemi KAPSAMIYOR. Kök yine referans →
    # A′. ⚠️ ŞERH: taksonomi *"referans YOK"* diyor, buradaki *"referans
    # YETERSİZ"*. Ayrım koordinatöre TAŞINDI (G-202); tek başıma aileye
    # sınıf EKLEMEM (M-F-77: başka hattı etkiler).
    "provenance.derivedJoints:excludes:": BOSLUK_A_UC,
}


#: 🔴 BU ARACIN GÖREMEDİĞİ SINIFLAR — ve nerede ölçüldükleri.
#:
#: Bir sınıfa `0` basmak *"yok"* demektir; bu araç yalnız `blockedBy`
#: anahtarlarını ve katalog içeriğini görür. Göremediği yerde **sayı değil
#: ADRES** basar.
#:
#: > ***BİR ÖLÇÜMÜN GÖRMEDİĞİNİ YAZMAK, O ÖLÇÜMÜN YANLIŞ OKUNMASINI
#: > ENGELLEYEN TEK ŞEYDİR*** (Choreia, M-F-569)
_GORULMEYEN = {
    BOSLUK_B: "test/startable_reach_test.dart (varılabilirlik WIDGET katmanı; "
              "bugün 1: push_up)",
    BOSLUK_C: "yargı kalemi — 'bu kart hiç olmamalıydı' koddan TÜRETİLEMEZ",
    BOSLUK_D: "bu üründe YAPISAL olarak olamaz — validate_library K11 "
              "blokersiz kapanışı zaten yasaklıyor",
}


#: 🔇 SESSİZLİK DEDEKTÖRÜ — `A3`ün ölçüsü, ve `A4`le AYNI PAYDAYI paylaşır.
#:
#: Ailenin hükmü (M-F-573 ④, beş hatta bağlayıcı):
#: > ***BOŞ TEK BAŞINA BİR KUSUR DEĞİLDİR; KUSUR, BOŞLUĞUN SESSİZ OLMASIDIR.***
#: ⇒ ölçülecek sayı **oran değil, SESSİZ ORANI** — ve ikisi BİRLİKTE basılır:
#: > ***BİR KURALIN DEĞERİ, ONSUZ ÖLÇÜLECEK SAYIYLA ONUNLA ÖLÇÜLEN SAYININ
#: > FARKI KADARDIR*** (JabLab'da fark %33, ve o fark tamamen kullanıcıya
#: > söylenen cümlelerden oluşuyordu).
#:
#: ⚠️ **ÇERÇEVE İÇERİK SAYILMAZ** (M-F-573'ün dört disiplininden biri):
#: başlık, rozet, sekme adı *"bu yüzey dolu"* saydırmaz — aksi hâlde her ekran
#: **tanım gereği** dolu olurdu ve *koşulsuz doğru bir kapı hiçbir şey ölçmez*.
#: Bu yüzden sebep, kullanıcıya BASILAN `honesty` listelerinden okunur;
#: `blockedBy` (iç bloker anahtarları) **sebep sayılmaz** — o makine dili.
def beyanli(hareket: dict) -> bool:
    """Bu boş yüzey, NEDEN boş olduğunu KULLANICIYA söylüyor mu?

    ⚠️ Bu fonksiyon **paylaşımlıdır**: gerçek sayım da, öz-testin pozitif
    kontrolü de AYNI kodu çağırır.
    > ***BİR POZİTİF KONTROL, ÖLÇTÜĞÜ ŞEYİN AYNISINI ÇALIŞTIRMIYORSA KENDİ
    > KOPYASINI DOĞRULAR*** (JabLab, M-F-577).
    """
    honesty = hareket.get("honesty") or {}
    return bool(honesty.get("waitingOnMeasurement") or honesty.get("notMeasured"))


class SayimHatasi(SystemExit):
    """Kapının kırmızısı — sessiz varsayım yerine gürültülü arıza."""


def sinifla(blokerler: list[str]) -> set[str]:
    """SAF: bloker anahtarları → boşluk sınıfları. Dosya OKUMAZ.

    Bilinmeyen bir anahtar **yükseltir**. Sessizce *"öteki"* kovasına atmak,
    bir gün yeni bir bloker sınıfını sayımın dışında bırakırdı ve **sayı
    değişmediği için kimse fark etmezdi.**
    """
    siniflar: set[str] = set()
    bilinmeyen: list[str] = []
    for anahtar in blokerler:
        if anahtar in _BLOKER_SINIF_TAM:
            siniflar.add(_BLOKER_SINIF_TAM[anahtar])
            continue
        for onek, sinif in _BLOKER_SINIF_ONEK.items():
            if anahtar.startswith(onek):
                siniflar.add(sinif)
                break
        else:
            bilinmeyen.append(anahtar)
    if bilinmeyen:
        raise SayimHatasi(
            "⛔ BİLİNMEYEN bloker anahtarı — sınıflandırılmalı "
            f"(tools/dead_end_census.py _BLOKER_SINIF_*): {bilinmeyen}")
    return siniflar


def _yorumsuz(dart: str) -> str:
    """Dart kaynağından YORUMLARI söker.

    🔴 Aile kuralı: ***metin tarayan bir kapı YORUMLARI kodla aynı sayar.***
    Bu araç `progress_view.dart`ta dokunma işleyicisi arıyor; *"onTap
    kullanmıyoruz"* diyen tek bir yorum satırı, kapsam kapısını **yanlış
    yönde** tetiklerdi.
    """
    dart = re.sub(r"/\*.*?\*/", "", dart, flags=re.S)
    return re.sub(r"//[^\n]*", "", dart)


#: Dokunma işleyicisi imzaları — bir yüzeyi HEDEF yapan şeyler.
_DOKUNMA = re.compile(r"\b(onTap|onPressed|InkWell|GestureDetector)\b")


def _ders_yuzeyi_dokunulamaz(kaynak: str) -> bool:
    """Ders yüzeyi hâlâ dokunulamaz mı? (kapsam varsayımının ÖLÇÜMÜ)

    Bu, düzyazı bir şerhin yerine geçen **türetim**dir: A7 (c)'de bu hattın
    ödediği bedel, *sebebin doc-comment'te yaşaması* ve her koşumda
    türetilmemesiydi.
    """
    return not _DOKUNMA.search(_yorumsuz(kaynak))


def _icerik_bos(girdi: dict | None) -> bool:
    """Katalog girdisinde YAZILMIŞ içerik var mı? (A sınıfının ölçüsü)

    `A` = *içerik HİÇ yazılmamış*. Bu, blokerlerden **türetilemez** — bir
    hareket hiç içeriği olmadan da `provenance.sources:empty` taşıyabilir.
    ⇒ Ayrı kaynaktan, katalogdan ölçülür.
    """
    if girdi is None:
        return True
    return not (girdi.get("cues") or girdi.get("formErrors"))


def sayim(lib: dict, katalog: dict[str, dict] | None = None) -> dict:
    """SAF: `library.json` sözlüğü (+ katalog) → sayım. Dosya OKUMAZ.

    Bölme: `payda = başlatılabilir(beyan) ⊎ çıkmaz`.

    [katalog] verilmezse `A` sınıfı **ölçülmemiş** sayılır ve raporda sayı
    yerine adres basılır — *ölçülmeyen bir sınıfa 0 yazmak yasak.*
    """
    hareketler = lib.get("movements") or []
    if not hareketler:
        raise SayimHatasi(
            "⛔ VAKUM — hiç hareket bulunamadı. Kaynağın BİÇİMİ desenden "
            "ayrışmış olabilir; '0 çıkmaz' EN KOLAY SAHTELENEN sayıdır.")

    baslatilabilir = [m for m in hareketler if m.get("status") == "live"]
    cikmaz = [m for m in hareketler if m.get("status") != "live"]

    if len(baslatilabilir) + len(cikmaz) != len(hareketler):
        raise SayimHatasi("⛔ BÖLME tutmadı — kovalar paydayı kapatmıyor.")

    dagilim: dict[str, list[str]] = {}
    bloker_sayimi: dict[str, int] = {}
    sinifsiz: list[str] = []
    for m in cikmaz:
        blokerler = m.get("blockedBy") or []
        for b in blokerler:
            bloker_sayimi[b] = bloker_sayimi.get(b, 0) + 1
        siniflar = sinifla(blokerler)
        if not siniflar:
            sinifsiz.append(m.get("id", "?"))
            continue
        # `A`, blokerden DEĞİL katalogdan gelir — ayrı kaynak, ayrı soru.
        if katalog is not None and _icerik_bos(katalog.get(m.get("catalogId"))):
            siniflar.add(BOSLUK_A)
        for s in siniflar:
            dagilim.setdefault(s, []).append(m.get("id", "?"))

    if sinifsiz:
        raise SayimHatasi(
            "⛔ SINIFSIZ ÇIKMAZ — bir çıkmazın hiç blokeri yok, yani NEDEN "
            f"çıkmaz olduğu ölçülemiyor: {sinifsiz}")

    # 🔇 SESSİZ ORANI — `A3`. Aynı payda, farklı soru: A4 *"kaç çıkmaz ve
    # NİYE"* der, A3 *"kaçı bunu KULLANICIYA söylüyor"*.
    sessiz = [m.get("id", "?") for m in cikmaz if not beyanli(m)]

    return {
        "a_olculdu": katalog is not None,
        "sessiz": sessiz,
        "payda": len(hareketler),
        "baslatilabilir": [m.get("id", "?") for m in baslatilabilir],
        "cikmaz": [m.get("id", "?") for m in cikmaz],
        "dagilim": dagilim,
        "bloker_sayimi": bloker_sayimi,
    }


def derive() -> dict:
    """OKUMA katmanı — gerçek içeriği okur, sayımı saf katmana devreder."""
    if not _ders_yuzeyi_dokunulamaz(PROGRESS_VIEW.read_text()):
        raise SayimHatasi(
            "⛔ KAPSAM VARSAYIMI BAYATLADI — `progress_view.dart` artık bir "
            "dokunma işleyicisi taşıyor. Dersler VARILABİLİR hâle gelmişse "
            "ders düzeyi de sayıma girmeli (Lissom kuralı: varılamayan bir "
            "yer çıkmaz sokak DEĞİLDİR — tersi de doğru).")
    katalog = {}
    for p in sorted((ROOT / "content" / "catalog").glob("w*/*.json")):
        girdi = json.loads(p.read_text())
        katalog[girdi["id"]] = girdi
    if not katalog:
        raise SayimHatasi(
            "⛔ VAKUM — katalog boş. `A` sınıfı 'içerik yok' diye ölçülürdü "
            "ve HEPSİ A çıkardı; ölçüm değil, dosya yolu kusuru olurdu.")
    return sayim(json.loads(LIB.read_text()), katalog)


# ── ÖZ-TEST ────────────────────────────────────────────────────────────────
#: ⛔ SENTETİK FİKSTÜR — ÜRÜN İÇERİĞİ DEĞİL. `_fx` ekli id'ler bilerek:
#: gerçek bir hareketle karışırlarsa öz-test yine ürüne çapalanır ve
#: ürün ilerleyince kırmızıya döner (bu hattın M-F-598 bedeli).
_FX_LIB = {
    "movements": [
        {"id": "acik_fx", "status": "live"},
        # içeriği VAR (katalogda cues taşır) → A DEĞİL
        {"id": "hasat_fx", "status": "coming_soon",
         "catalogId": "hasat_kat_fx",
         "blockedBy": ["provenance.sources:empty", "replayFixture:missing"]},
        # katalogda girdisi YOK → içerik hiç yazılmamış → A
        {"id": "alet_fx", "status": "coming_soon",
         "catalogId": "alet_kat_fx",
         "blockedBy": ["provenance.sources:empty",
                       "metric:unimplemented@entry"]},
    ],
}

_FX_DART_KOD = "Widget row() => InkWell(onTap: _open, child: Text('x'));"
_FX_DART_YORUM = """
// Bu yüzeyde onTap YOKTUR ve olmamalı; InkWell kullanmıyoruz.
/* GestureDetector de yok. */
Widget row() => Text('x');
"""


def _oter(ad: str, beklenen: str, cagri) -> list[str]:
    """Bir sabotajın ÖTTÜĞÜNÜ değil, **DOĞRU SEBEPLE** öttüğünü sınar.

    > ***ÖTME KANIT DEĞİL, ÖTME SEBEBİ KANITTIR*** (bu hattın `2.11` kuralı).

    Aynı istisna tipini paylaşan iki ikizden biri hiç çalışmasa bile, yalnız
    `except`e bakan bir öz-test **yeşil** kalır — komşusunun ötmesi onun
    kanıtı sanılır (gölgelenme).
    """
    try:
        cagri()
    except SayimHatasi as e:
        if beklenen not in str(e):
            return [f"{ad}: ÖTTÜ ama BAŞKA sebeple → {str(e)[:70]}"]
        return []
    return [f"{ad}: hiç ötmedi — kapı ölü"]


def _self_test() -> int:
    """Kendi kapısı — SINIFLANDIRMAYI sentetik girdiye karşı sınar.

    ⚠️ ***ÖTME KANIT DEĞİL, ÖTME SEBEBİ KANITTIR*** (bu hattın `2.11` kuralı):
    her sabotaj **izole** ve beklenen mesajı **adıyla** aranıyor — iki kapıyı
    birden kıran bir sabotajın yeşili *"kapı çalışıyor"* diye okunurdu.
    """
    hatalar: list[str] = []

    # ═══ A. SINIFLANDIRMA — sentetik, üründen bağımsız ═══
    if sinifla(["provenance.sources:empty"]) != {BOSLUK_A_UC}:
        hatalar.append("referans-boş A′ sınıflanmadı")
    if sinifla(["metric:unimplemented@entry"]) != {BOSLUK_E}:
        hatalar.append("metrik-eksik E sınıflanmadı")
    # POZİTİF İKİZ (M-F-194): iki farklı sınıf AYRI AYRI çıkmalı — tek sınıfa
    # çökerse kapı "her şeye A′" diyor olurdu ve ters ikizler bunu göremezdi.
    if sinifla(["provenance.sources:empty",
                "metric:unimplemented@entry"]) != {BOSLUK_A_UC, BOSLUK_E}:
        hatalar.append("iki sınıf tek kovaya çöktü — ayrım ölü")
    # TERS İKİZ: bilinmeyen anahtar YÜKSELTMELİ — ve SEBEBİYLE.
    hatalar += _oter("BİLİNMEYEN bloker", "BİLİNMEYEN bloker anahtarı",
                     lambda: sinifla(["ekran_henuz_yapilmadi"]))

    # ═══ B. SAYIM — sentetik fikstür ═══
    s = sayim(_FX_LIB)
    if s["payda"] != 3 or len(s["baslatilabilir"]) != 1 or len(s["cikmaz"]) != 2:
        hatalar.append(f"fikstür bölmesi ayrıştı: {s['payda']} / "
                       f"{s['baslatilabilir']} / {s['cikmaz']}")
    if sorted(s["dagilim"].get(BOSLUK_E, [])) != ["alet_fx"]:
        hatalar.append("E sınıfı fikstürde yanlış harekete düştü")
    # `A` — AYRI KAYNAK (katalog), ayrı ikiz çifti.
    fx_kat = {"hasat_kat_fx": {"cues": ["x"]}}  # `alet_fx`in girdisi YOK → A
    sa = sayim(_FX_LIB, fx_kat)
    if sorted(sa["dagilim"].get(BOSLUK_A, [])) != ["alet_fx"]:
        hatalar.append("içeriksiz hareket A sınıflanmadı")
    # POZİTİF İKİZ: içeriği OLAN çıkmaz A sayılMAMALI, yoksa kapı
    # "her çıkmaz A" diyor olurdu ve ters ikiz bunu göremezdi.
    if "hasat_fx" in sa["dagilim"].get(BOSLUK_A, []):
        hatalar.append("içeriği OLAN hareket A sanıldı — ayrım ölü")
    # Katalog verilmezse `A` ÖLÇÜLMEMİŞ sayılmalı (sahte sıfır yasağı).
    if sayim(_FX_LIB)["a_olculdu"]:
        hatalar.append("katalogsuz sayım `A`yı ölçülmüş sandı")
    # TERS İKİZ: VAKUM ötmeli — "0 çıkmaz" en kolay sahtelenen sayıdır.
    hatalar += _oter("VAKUM", "VAKUM", lambda: sayim({"movements": []}))
    # TERS İKİZ: blokersiz çıkmaz ötmeli (NEDEN'i ölçülemeyen çıkmaz).
    # ⚠️ Bu ikiz, VAKUM ikiziyle AYNI istisnayı fırlatır; mesaj aranmasaydı
    # biri ötüp öteki hiç çalışmasa da öz-test yeşil kalırdı (gölgelenme).
    hatalar += _oter(
        "SINIFSIZ çıkmaz", "SINIFSIZ ÇIKMAZ",
        lambda: sayim({"movements": [{"id": "sessiz_fx",
                                      "status": "coming_soon"}]}))

    # ═══ B2. SESSİZLİK (A3) — ters ve pozitif ikiz, AYNI dedektörle ═══
    # Fikstürdeki iki çıkmazın ikisi de `honesty` TAŞIMIYOR ⇒ ikisi de sessiz.
    if sorted(s["sessiz"]) != ["alet_fx", "hasat_fx"]:
        hatalar.append(f"sessizlik dedektörü fikstürde ayrıştı: {s['sessiz']}")
    # POZİTİF İKİZ: sebep KONUNCA susmalı. Bu olmadan dedektör *"her şeye
    # sessiz"* diyor olabilirdi ve ters ikiz bunu göremezdi (M-F-194).
    beyanli_fx = {
        "movements": [
            {"id": "acik_fx", "status": "live"},
            {"id": "beyanli_fx", "status": "coming_soon",
             "catalogId": "k_fx",
             "blockedBy": ["provenance.sources:empty"],
             "honesty": {"waitingOnMeasurement": ["Kayıtlı referans yok."]}},
        ],
    }
    if sayim(beyanli_fx)["sessiz"]:
        hatalar.append("GEREKÇELİ boş yüzey sessiz sayıldı — dedektör kör")
    # ⚠️ ÇERÇEVE İÇERİK SAYMAZ: yalnız `blockedBy` taşıyan (yani kullanıcıya
    # HİÇBİR cümle basmayan) bir hareket **sessizdir**. Bu ikiz olmasaydı
    # dedektör iç bloker anahtarlarını *"sebep"* sayabilirdi.
    ic_anahtar_fx = {
        "movements": [
            {"id": "acik_fx", "status": "live"},
            {"id": "sadece_bloker_fx", "status": "coming_soon",
             "catalogId": "k_fx",
             "blockedBy": ["provenance.sources:empty", "replayFixture:missing"]},
        ],
    }
    if sayim(ic_anahtar_fx)["sessiz"] != ["sadece_bloker_fx"]:
        hatalar.append("iç bloker anahtarı kullanıcı SEBEBİ sanıldı — "
                       "çerçeve içerik sayılıyor")

    # ═══ C. KAPSAM KAPISI — yorum/kod ayrımı (aile kuralı) ═══
    if _ders_yuzeyi_dokunulamaz(_FX_DART_KOD):
        hatalar.append("GERÇEK dokunma işleyicisi görülmedi — kapsam kapısı kör")
    # 🔴 POZİTİF KONTROLÜN EN ÖNEMLİSİ: yalnız YORUMDA geçen işleyici
    # kapıyı tetiklememeli. Bu olmadan kapı, kodu yorumdan ayırmadığını
    # kanıtlayamazdı — ve zehrin yönü SESSİZ olurdu.
    if not _ders_yuzeyi_dokunulamaz(_FX_DART_YORUM):
        hatalar.append("YORUMDAKİ işleyici kapıyı tetikledi — yorum≠kod ayrımı ölü")

    # ═══ D. OKUMA — gerçek ağaç, yalnız BİÇİM (içerik ÇAPALANMAZ) ═══
    canli = derive()
    if canli["payda"] <= 0:
        hatalar.append("GERÇEK ağaçta payda boş (VAKUM)")

    if hatalar:
        for h in hatalar:
            print(f"  ❌ {h}")
        print("⛔ dead_end_census öz-testi DÜŞTÜ")
        return 1
    # ⚠️ Sayı GRUPLARA bölünerek basılıyor: tek bir toplam, bir grubun
    # tamamen ölmesini gizleyebilirdi (`run_all_gates`ın kendi varlık
    # sebebinin öz-test ölçeğindeki hâli).
    print(f"✅ dead_end_census öz-testi: sınıflandırma 4 · sayım 4 · "
          f"A-sınıfı 3 · SESSİZLİK 3 · kapsam 2 (yorum≠kod) · "
          f"OKUMA gerçek ağaçta biçim: payda {canli['payda']} "
          f"· sessiz {len(canli['sessiz'])}")
    return 0


def _rapor() -> int:
    c = derive()
    cikmaz = len(c["cikmaz"])
    print(f"ÇIKMAZ SOKAK SAYIMI — hareket düzeyi (ders düzeyi kapsam dışı: "
          f"dersler dokunulamaz)")
    print(f"  payda {c['payda']} = başlatılabilir(beyan) "
          f"{len(c['baslatilabilir'])} ⊎ çıkmaz {cikmaz}")
    print("  boşluk sınıfı dağılımı (bir çıkmaz BİRDEN ÇOK sınıf taşıyabilir):")
    for sinif in (BOSLUK_A, BOSLUK_A_UC, BOSLUK_B, BOSLUK_C, BOSLUK_D, BOSLUK_E):
        if sinif == BOSLUK_A and not c["a_olculdu"]:
            print(f"    {sinif:3s}  ⛔ ölçülmedi (katalog verilmedi)")
            continue
        if sinif in _GORULMEYEN:
            # 🔴 SAHTE SIFIR YASAĞI — ölçütün kuralı: *`⛔` ile `bilinmiyor`
            # AYNI KOVAYA GİRMEZ.* Bu araç yalnız `blockedBy` anahtarlarını ve
            # katalog içeriğini görür; göremediği bir sınıfa `0` basmak, o
            # sınıfın YOK olduğunu iddia etmek olurdu.
            #
            # ⚠️ Ve bu, ölçülmüş bir kusurun panzehiri: `B` gerçekten 0
            # DEĞİL (`push_up`), ama bu araç onu göremez. `0` basılsaydı iki
            # kapı aynı kelimeyi ölçüp AYRI sayı verir ve ikisi de susardı.
            print(f"    {sinif:3s}  ⛔ bu araç ölçmez → {_GORULMEYEN[sinif]}")
            continue
        uyeler = c["dagilim"].get(sinif, [])
        isim = "" if len(uyeler) > 3 else (" · " + ", ".join(uyeler) if uyeler else "")
        print(f"    {sinif:3s} {len(uyeler):3d}{isim}")
    # ── A3: SESSİZ ORANI — iki sayı BİRLİKTE, çünkü farkları kuralın değeri
    bos_oran = 100.0 * cikmaz / c["payda"]
    sessiz_oran = 100.0 * len(c["sessiz"]) / c["payda"]
    print(f"  🔇 A3 — boş oranı %{bos_oran:.0f} ({cikmaz}/{c['payda']}) ↔ "
          f"SESSİZ oranı %{sessiz_oran:.0f} ({len(c['sessiz'])}/{c['payda']})"
          + (f" · sessizler: {c['sessiz']}" if c["sessiz"] else ""))
    print(f"     fark %{bos_oran - sessiz_oran:.0f} — kuralın DEĞERİ bu kadar; "
          "tamamı kullanıcıya söylenen cümlelerden")
    print("     ⛔ bu araç yalnız İÇERİK sessizliğini görür. Beyan-açık ama "
          "BAŞLATILAMAYAN bir hareket de sessiz bir yüzeydir ve o "
          "test/startable_reach_test.dart'ta ölçülür (bugün 1: push_up).")
    toplam = sum(c["bloker_sayimi"].values())
    print(f"  bloker ÖRNEĞİ sayımı (payda {toplam}, {cikmaz} çıkmaz üzerinden):")
    for k, v in sorted(c["bloker_sayimi"].items(), key=lambda x: -x[1]):
        print(f"    {v:3d}  {k}")
    # ⚠️ ÖZET EN SONA — `run_all_gates.sh` stdout'un **son anlamlı satırını**
    # özet diye basıyor. Sıralamayı düşünmeden yazsaydım kapı listesinde
    # *"1 metric:unimplemented@entry"* görünürdü: doğru bir satır, ama
    # ölçümün cevabı değil.
    #   > Doğru olan bir şeyin, YANLIŞ YERDE durması. (G-190'ın rapor dersi)
    siniflar = "·".join(
        f"{s}{len(c['dagilim'].get(s, []))}"
        for s in (BOSLUK_A, BOSLUK_A_UC, BOSLUK_B, BOSLUK_C, BOSLUK_D, BOSLUK_E)
        if c["dagilim"].get(s))
    print(f"✅ çıkmaz {cikmaz}/{c['payda']} · sınıf {siniflar} "
          f"· beyan-açık {len(c['baslatilabilir'])}")
    return 0


if __name__ == "__main__":
    sys.exit(_self_test() if "--self-test" in sys.argv else _rapor())
