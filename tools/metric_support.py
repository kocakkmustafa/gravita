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


def derive() -> tuple[set[str], set[str], dict[str, set[str]]]:
    """(byName'de üretilenler, adlandırılmış boşluklar, özel-durum haritası).

    Üçüncü dönüş: metrik → o metriğin ÇÖZÜLEBİLDİĞİ konum sınıfları.
    """
    metrics = (SRC / "metrics.dart").read_text()
    body = metrics[metrics.index("byName"):]
    implemented = set(re.findall(
        r"'([a-z_0-9]+)'\s*=>", body[:body.index("_ => null")]))
    gap_block = re.search(
        r"unimplemented\s*=\s*<String>\{(.*?)\n  \};", metrics, re.S)
    named_gaps = set(re.findall(r"'([a-z_0-9]+)'", gap_block.group(1)))

    special: dict[str, set[str]] = {}
    unknown: list[str] = []
    for path in sorted(SRC.glob("*_engine.dart")):
        text = path.read_text()
        for m in _SPECIAL_CASE.finditer(text):
            metric = m.group(2)
            func = _enclosing_function(text, m.start())
            position = _FUNCTION_POSITION.get(func)
            if position is None:
                unknown.append(f"{path.name}:{func}() → '{metric}'")
                continue
            special.setdefault(metric, set()).add(position)
    if unknown:
        raise SystemExit(
            "⛔ TANINMAYAN konumda metrik özel-durumu bulundu — sessizce "
            "varsayılamaz, SINIFLANDIRILMALI (tools/metric_support.py "
            f"_FUNCTION_POSITION): {unknown}")
    return implemented, named_gaps, special


def unresolvable(metric: str, position: str,
                 sets: tuple[set[str], set[str], dict[str, set[str]]]) -> bool:
    """[metric], [position] konumunda ürün tarafından ÜRETİLEMİYOR mu?"""
    implemented, _named_gaps, special = sets
    if metric in implemented:
        return False
    return position not in special.get(metric, set())


def _self_test() -> int:
    """Kendi kapısı — bulması GEREKENİ bulabildiğini kanıtlar.

    ⚠️ Pozitif kontrolün ÜÇ katmanı (aile kuralı, M-F-505 + G-182):
    ① ARAÇ bir şey bulabiliyor mu · ② DİZGE doğru mu ·
    ③ KAPSAM: cevabın yaşayabileceği YERLERİN HEPSİNE mi bakıyorum.
    Bu öz-test üçünü de sınıyor; ③ olmadan `feet_off_ground` yanlış-pozitif
    veriyordu ve ilk iki katman GEÇMİŞTİ.
    """
    sets = derive()
    implemented, named_gaps, special = sets
    fails: list[str] = []

    # ① ARAÇ: bilinen bir uygulanmış metrik bulunuyor.
    if "knee_angle" not in implemented:
        fails.append("byName ayrıştırması boş/kırık — 'knee_angle' yok")
    # ② DİZGE: bilinen bir adlandırılmış boşluk bulunuyor.
    if "planche_lean_deg" not in named_gaps:
        fails.append("unimplemented ayrıştırması kırık — 'planche_lean_deg' yok")
    # ③ KAPSAM: motorda özel-durumlu metrik BULUNUYOR ve konumu DAR.
    if special.get("feet_off_ground") != {ENTRY}:
        fails.append(
            "motor taraması kırık — 'feet_off_ground' yalnız _enters()'te "
            f"beklenirdi, bulunan: {special.get('feet_off_ground')}")
    # TERS İKİZ: uydurma bir metrik hiçbir kümede olmamalı.
    if not unresolvable("zzqq_metric", ENTRY, sets):
        fails.append("uydurma metrik ÇÖZÜLEBİLİR sayıldı — kapı ateşlenmiyor")
    # TERS İKİZ 2: özel-durumlu metrik YANLIŞ konumda çözülebilir SAYILMAMALI.
    if not unresolvable("feet_off_ground", CHECK, sets):
        fails.append(
            "'feet_off_ground' CHECK konumunda çözülebilir sanıldı — konum "
            "ayrımı çalışmıyor")

    if fails:
        for f in fails:
            print(f"  ❌ {f}")
        print("⛔ metric_support öz-testi DÜŞTÜ")
        return 1
    print(f"✅ metric_support öz-testi: uygulanmış {len(implemented)} · "
          f"adlandırılmış boşluk {len(named_gaps)} · motor özel-durumu "
          f"{len(special)} (3 katmanlı pozitif kontrol + 2 ters ikiz)")
    return 0


if __name__ == "__main__":
    sys.exit(_self_test() if "--self-test" in sys.argv else _self_test())
