#!/usr/bin/env python3
"""Bir metriğin ÜRÜNDE gerçekten üretilip üretilmediğini — ve HANGİ KONUMDA
üretildiğini — Dart kaynaklarından TÜRETİR.

## Neden var (G-182 → koordinatör onayı, 2026-08-12)

`tuck_planche`ın beyan ettiği üç bloker (`precondition!=derived` ·
`replayFixture:missing` · `provenance.sources:empty`) hasat sonunda kalkar
ve terfi kapısı *"terfi edilebilir"* der. Ama `holdEntry.requires`teki
`planche_lean_deg` metriğini hiçbir katman ÜRETMİYOR; `hold_engine.dart`
giriş koşulunu `v != null && !v.isNaN && cond.holds(v)` ile değerlendirdiği
için **tutuş HİÇ başlamaz.** Hareket `live` etiketiyle açılır ve kullanıcı
tuck planche'ta dururken uygulama hiçbir şey saymaz, hiçbir şey söylemez.

> Maliyet, ölçüm yapılmadığında en pahalı anda düşer: **hasattan SONRA.**

## ⛔ ELLE LİSTE TUTULMAZ (koordinatör kısıtı 1) — ve bunun bir bedeli var

Bu modülün ilk hâli bir sabitti (`ENGINE_IMPLEMENTED = {...}`) ve tam da bu
yüzden yanlış bir bulgu üretti: `burpee` *"başlamaz"* sanıldı, çünkü kapsam
**tek dosyaydı** (`metrics.dart`ın `unimplemented` kümesi). Oysa
`feet_off_ground`, `multiphase_engine.dart`ta `GroundReference` ile ÖZEL
DURUM olarak uygulanmış.

> ***Bir metriğin bir KATMANDA eksik olması, ÜRÜNDE eksik olduğunu ölçmez.***

Elle tutulan bir liste o yanlışı **kalıcılaştırır** ve kimse fark etmez.
Bu yüzden kaynak = **üç motorun taranması**, çıktı = destek haritası.

## Bilinmeyen ÖZEL DURUM = GÜRÜLTÜLÜ ARIZA (sessiz varsayım yok)

Motorlarda metrik-adıyla özel durum, `<şey>Metric == 'ad'` biçiminde yazılır.
Böyle bir satır TANINMAYAN bir fonksiyonda bulunursa bu modül **yükseltir**:
sessizce "her yerde çalışır" ya da "hiç çalışmaz" varsaymak, ikisi de bir
gün yanlış cevap verir. Yeni bir özel durum eklendiğinde kapı kırmızı yanar
ve biri onu SINIFLAR — liste bakımı yerine, bakımı ZORLAYAN bir arıza.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "packages" / "gravita_engine" / "lib" / "src"

#: Konum sınıfları. Bir metrik "uygulanmış" olabilir ve yine de belirli bir
#: konumda ÇÖZÜLEMEZ olabilir — konum, şiddeti belirler.
ENTRY = "entry"     # giriş/ön koşul: çözülemezse hareket HİÇ BAŞLAMAZ
CHECK = "check"     # form-break / faz kontrolü: çözülemezse KURAL SESSİZ

#: Motorun hangi fonksiyonunun hangi konumu değerlendirdiği — bu eşleme
#: metrik ADI içermez (yasak olan oydu), motorun YAPISINI tarif eder.
#: Tanınmayan bir fonksiyonda özel durum bulunursa `derive()` yükseltir.
_FUNCTION_POSITION = {
    "_enters": ENTRY,      # multiphase: faz girişi
    "_runChecks": CHECK,   # multiphase: faz içi kontroller
}

_SPECIAL_CASE = re.compile(r"(\w*[Mm]etric)\s*==\s*'([a-z_0-9]+)'")
_FUNC_HEAD = re.compile(r"^\s{2}(?:[\w<>?, ]+\s)?(_?\w+)\s*\(", re.M)

#: Dart anahtar kelimeleri fonksiyon adı DEĞİLDİR. Bu satır olmadan tarama
#: `  if (` gibi bir satırı "if() fonksiyonu" sanıp TANINMAYAN konum diye
#: yükseltiyordu — arıza yönü doğruydu (sessiz varsaymadı) ama sebebi
#: ayrıştırıcının kendisiydi. Doğrulayıcının kendisi de denetlenir.
_NOT_A_FUNCTION = {"if", "for", "while", "switch", "return", "catch", "assert"}


def _enclosing_function(text: str, index: int) -> str:
    """`index` konumundaki satırı içeren fonksiyonun adı (en yakın önceki)."""
    best = "?"
    for m in _FUNC_HEAD.finditer(text):
        if m.start() > index:
            break
        if m.group(1) in _NOT_A_FUNCTION:
            continue
        best = m.group(1)
    return best


def _parse_metrics(text: str) -> tuple[set[str], set[str]]:
    """SAF AYRIŞTIRICI — metin girer, küme çıkar. Dosya OKUMAZ (G-201).

    Ayrılmasının sebebi kapının kendi kusuruydu: öz-test ayrıştırmayı
    **ürünün canlı durumu** üzerinden sınıyordu ve ürün ilerleyince kapı
    kırmızıya dönüyordu. Ayrıştırma artık **sentetik girdiyle** sınanabilir.
    """
    body = text[text.index("byName"):]
    implemented = set(re.findall(
        r"'([a-z_0-9]+)'\s*=>", body[:body.index("_ => null")]))
    gap_block = re.search(
        r"unimplemented\s*=\s*<String>\{(.*?)\n  \};", text, re.S)
    if gap_block is None:
        raise SystemExit(
            "⛔ `unimplemented` bloğu BULUNAMADI — kaynağın BİÇİMİ desenden "
            "ayrışmış olabilir. (Eskiden burada sessiz bir AttributeError "
            "vardı: biçim kayması, ayrıştırma kusuru gibi görünürdü.)")
    named_gaps = set(re.findall(r"'([a-z_0-9]+)'", gap_block.group(1)))
    return implemented, named_gaps


def _parse_engines(sources: dict[str, str]) -> dict[str, set[str]]:
    """SAF AYRIŞTIRICI — {dosya adı: metin} girer, özel-durum haritası çıkar.

    Tanınmayan konumda özel durum bulursa **yükseltir** (modülün kurucu
    kuralı): sessizce *"her yerde çalışır"* ya da *"hiç çalışmaz"* varsaymak,
    ikisi de bir gün yanlış cevap verir.
    """
    special: dict[str, set[str]] = {}
    unknown: list[str] = []
    for name, text in sorted(sources.items()):
        for m in _SPECIAL_CASE.finditer(text):
            metric = m.group(2)
            func = _enclosing_function(text, m.start())
            position = _FUNCTION_POSITION.get(func)
            if position is None:
                unknown.append(f"{name}:{func}() → '{metric}'")
                continue
            special.setdefault(metric, set()).add(position)
    if unknown:
        raise SystemExit(
            "⛔ TANINMAYAN konumda metrik özel-durumu bulundu — sessizce "
            "varsayılamaz, SINIFLANDIRILMALI (tools/metric_support.py "
            f"_FUNCTION_POSITION): {unknown}")
    return special


def derive() -> tuple[set[str], set[str], dict[str, set[str]]]:
    """(byName'de üretilenler, adlandırılmış boşluklar, özel-durum haritası).

    Üçüncü dönüş: metrik → o metriğin ÇÖZÜLEBİLDİĞİ konum sınıfları.
    **OKUMA katmanı**: gerçek kaynağı okur, ayrıştırmayı saf katmana devreder.
    """
    implemented, named_gaps = _parse_metrics((SRC / "metrics.dart").read_text())
    special = _parse_engines(
        {p.name: p.read_text() for p in sorted(SRC.glob("*_engine.dart"))})
    return implemented, named_gaps, special


def unresolvable(metric: str, position: str,
                 sets: tuple[set[str], set[str], dict[str, set[str]]]) -> bool:
    """[metric], [position] konumunda ürün tarafından ÜRETİLEMİYOR mu?"""
    implemented, _named_gaps, special = sets
    if metric in implemented:
        return False
    return position not in special.get(metric, set())


#: ⛔ SENTETİK FİKSTÜR — ÜRÜN KAYNAĞI DEĞİL. Adları bilerek `_fx` ekliyle
#: yazıldı: gerçek bir metrikle karışırlarsa öz-test yine ürüne çapalanır.
_FX_METRICS = """
  static double? byName(String id, PoseFrame f) => switch (id) {
        'knee_fx' => 1.0,
        'hip_fx' => 2.0,
        _ => null,
      };

  static const Set<String> unimplemented = <String>{
    'planche_fx',
    'lever_fx',
  };
"""

#: `unimplemented` bloğu OLMAYAN fikstür — BİÇİM kayması ikizi.
_FX_METRICS_NO_GAPS = """
  static double? byName(String id, PoseFrame f) => switch (id) {
        'knee_fx' => 1.0,
        _ => null,
      };
"""

_FX_ENGINE = """
class _MultiphaseFx {
  bool _enters(PhaseSpec p) {
    if (p.entryMetric == 'entry_fx') return true;
    return false;
  }

  void _runChecks(PhaseSpec p) {
    if (p.ruleMetric == 'check_fx') {}
  }
}
"""

#: TANINMAYAN fonksiyonda özel durum — yükseltme ikizi.
_FX_ENGINE_UNKNOWN = """
class _GhostFx {
  void _mystery(PhaseSpec p) {
    if (p.entryMetric == 'ghost_fx') {}
  }
}
"""


def _self_test() -> int:
    """Kendi kapısı — AYRIŞTIRMAYI sentetik girdiye, OKUMAYI gerçek kaynağa
    karşı sınar (M-F-598 hükmü, G-201).

    ## Neden bölündü — kapının KENDİ kusuru

    Eski öz-test beş kontrolünün beşini de **ürünün canlı durumundan**
    okuyordu. Biri (`'planche_lean_deg' in named_gaps`) o metriğin
    **UYGULANMAMIŞ KALMASINI** şart koşuyordu: metrik uygulandığı gün —
    yani **istenen şey olduğu gün** — kapı, ayrıştırıcı kusursuzken
    kırmızıya dönecekti.

    > ***BİR KAPI, KENDİ ÜRÜNÜNÜN İLERLEMESİNİ CEZALANDIRIYORSA ÜRÜNÜN
    > DÜŞMANIDIR.***

    Panzehir gevşetme DEĞİL, **ayırma**: ayrıştırıcı artık kendi fikstürüyle
    sınanıyor; gerçek kaynak hâlâ okunuyor ama ondan yalnız **BİÇİM**
    bekleniyor.

    > ***BİR ÖZ-TEST ÜRÜNÜN BİÇİMİNE ÇAPALANIR, İÇERİĞİNE DEĞİL — içerik
    > ürünün İLERLEMESİDİR, ve ilerleme bir kapıyı kırmızıya çeviremez.***

    ⚠️ Pozitif kontrolün ÜÇ katmanı (M-F-505 + G-182) korundu ve **genişledi**:
    ① ARAÇ · ② DİZGE · ③ KAPSAM — üçü de artık fikstür üzerinde, ayrıca
    canlı ağaçta ölçülemeyen iki ikiz (yükseltme · biçim kayması) eklendi.
    """
    fails: list[str] = []

    # ═══ A. AYRIŞTIRMA — SENTETİK girdiye karşı (ürün durumundan bağımsız) ═══
    fx_impl, fx_gaps = _parse_metrics(_FX_METRICS)
    # ① ARAÇ + ② DİZGE
    if fx_impl != {"knee_fx", "hip_fx"}:
        fails.append(f"byName ayrıştırması fikstürde ayrıştı: {fx_impl}")
    if fx_gaps != {"planche_fx", "lever_fx"}:
        fails.append(f"unimplemented ayrıştırması fikstürde ayrıştı: {fx_gaps}")
    # ③ KAPSAM: iki konum sınıfı da doğru ayrılıyor.
    fx_special = _parse_engines({"multiphase_engine.dart": _FX_ENGINE})
    if fx_special != {"entry_fx": {ENTRY}, "check_fx": {CHECK}}:
        fails.append(f"motor taraması fikstürde ayrıştı: {fx_special}")

    # İKİZ: tanınmayan konum YÜKSELTİLMELİ (canlı ağaçta sınanamıyordu —
    # gerçek motorlarda tanınmayan fonksiyon YOK, o yüzden bu kontrol
    # ancak fikstürle var olabilir).
    try:
        _parse_engines({"ghost_engine.dart": _FX_ENGINE_UNKNOWN})
        fails.append("TANINMAYAN konum yükseltilmedi — sessiz varsayım kapısı ölü")
    except SystemExit:
        pass

    # İKİZ: BİÇİM kayması yakalanmalı (eskiden sessiz AttributeError'dı).
    try:
        _parse_metrics(_FX_METRICS_NO_GAPS)
        fails.append("`unimplemented` bloğunun YOKLUĞU yakalanmadı")
    except SystemExit:
        pass

    fx_sets = (fx_impl, fx_gaps, fx_special)
    # TERS İKİZ: uydurma metrik hiçbir kümede olmamalı.
    if not unresolvable("zzqq_fx", ENTRY, fx_sets):
        fails.append("uydurma metrik ÇÖZÜLEBİLİR sayıldı — kapı ateşlenmiyor")
    # TERS İKİZ 2: özel-durumlu metrik YANLIŞ konumda çözülebilir SAYILMAMALI.
    if not unresolvable("entry_fx", CHECK, fx_sets):
        fails.append("'entry_fx' CHECK konumunda çözülebilir sanıldı")
    # POZİTİF İKİZ (yokluk kapısının yanına varlık ikizi, M-F-194): DOĞRU
    # konumda çözülebilir SAYILMALI, yoksa kapı "her şeye hayır" diyor olurdu.
    if unresolvable("entry_fx", ENTRY, fx_sets):
        fails.append("'entry_fx' DOĞRU konumda çözülemez sanıldı — kapı kör")
    if unresolvable("knee_fx", CHECK, fx_sets):
        fails.append("uygulanmış metrik konum yüzünden çözülemez sanıldı")

    # ═══ B. OKUMA — GERÇEK kaynak, yalnız BİÇİM (içerik ÇAPALANMAZ) ═══
    # Buradaki tek beklenti: desen gerçek ağaçta HÂLÂ bir şey buluyor.
    # Hangi metriğin uygulandığı/uygulanmadığı ÜRÜNÜN İŞİ, kapının değil.
    live_impl, live_gaps, live_special = derive()
    if not live_impl:
        fails.append(
            "GERÇEK ağaçta hiç uygulanmış metrik bulunamadı — desen kaynağın "
            "biçiminden ayrışmış olabilir (VAKUM)")

    if fails:
        for f in fails:
            print(f"  ❌ {f}")
        print("⛔ metric_support öz-testi DÜŞTÜ")
        return 1
    print(f"✅ metric_support öz-testi: AYRIŞTIRMA fikstürde 9 kontrol "
          f"(3 katman + 2 ikiz + 4 ters/pozitif ikiz) · OKUMA gerçek ağaçta "
          f"biçim: uygulanmış {len(live_impl)} · boşluk {len(live_gaps)} · "
          f"özel-durum {len(live_special)}")
    return 0


if __name__ == "__main__":
    sys.exit(_self_test() if "--self-test" in sys.argv else _self_test())
