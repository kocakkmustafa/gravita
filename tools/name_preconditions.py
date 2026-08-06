#!/usr/bin/env python3
"""Bekleyen hareketlerin `precondition.rationale`'ını İSİMLİ hâle getirir.

## Bulunan durum (ölçüldü, 2026-08-06)

31 katalog hareketinin 30'u `precondition.status: pending` ve otuzunun
rationale metni **birbirinin AYNISI** — tek bir kopyala-yapıştır paragraf:

    "HENÜZ TÜRETİLMEDİ (G-043). Bu hareketin kimlik ön koşulu ölçümle
     türetilmedi; hasat sırası gelmedi. ..."

Doğru ama İŞE YARAMAZ. Otuz farklı hareketin otuz farklı sayım sinyali var
ve kimlik kapısının hangi ölçünün üstüne kurulacağı harekete göre değişiyor.
Tek metin, kuyruğu okunamaz kılıyor: "sırası gelmedi" bir kayıt değil, bir
kaydın YOKLUĞU.

## Ne türetiliyor (ve ne türetilMİYOR)

Her hareketin rationale'ı ARTEFAKTINDAN kurulur:

  · **sayım sinyali** — `engine.signal.joint` (repFsm) · `holdEntry.requires`
    metrikleri (staticHold) · `sequence`in ilk kapısı (multiPhaseFsm)
  · **motor tipi** ve neyin sayılacağı
  · **kamera kurulumu** ve bugünkü kısmi koruma (`camera.calibrationGate`)

⛔ **EŞİK ÜRETİLMİYOR.** Bu araç bir harekete "kimlik kapın şu metrik şu
değerin üstünde olmalı" DEMEZ ve diyemez — o değer ancak hasat ölçümünden
türer (G-014/G-050 sınıfı). Araç yalnız *hangi ölçünün üstüne kurulacağı
sorusunun henüz cevaplanmadığını* isimlendirir. Bir boşluğu adlandırmak ile
doldurmak arasındaki fark, bu ürünün tamamı.

    python3 tools/name_preconditions.py            # kuru koşum
    python3 tools/name_preconditions.py --write
    python3 tools/name_preconditions.py --check    # drift kapısı
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG_ROOT = ROOT / "content" / "catalog"

MARK = "[üretilmiş: tools/name_preconditions.py]"


def signal_phrase(cat):
    """Hareketin SAYIM SİNYALİ — kendi motor blokundan, tek cümlede."""
    e = cat.get("engine", {})
    kind = e.get("type")
    if kind == "repFsm":
        sig = e.get("signal", {})
        joint = sig.get("joint", "?")
        counted = e.get("repCountedOn", "?")
        return (f"tekrar sayacı `{joint}` eklem açısının salınımını izliyor "
                f"(`{counted}` geçişinde sayıyor)")
    if kind == "staticHold":
        metrics = [r.get("metric") for r in
                   (e.get("holdEntry", {}).get("requires") or [])]
        joined = ", ".join(f"`{m}`" for m in metrics) or "(giriş koşulu yok)"
        return (f"tutuş girişi {joined} ölçüsüne bakıyor ve süreyi oradan "
                f"başlatıyor")
    if kind == "multiPhaseFsm":
        seq = e.get("sequence") or []
        first = (seq[0].get("enter", {}) if seq else {}).get("metric", "?")
        return (f"{len(seq)} fazlı dizi `{first}` ölçüsüyle açılıyor ve "
                f"fazlar birbirini tetikliyor")
    return "sayım sinyali bu motor tipinde tanımlı değil"


def build_rationale(cat):
    cam = cat.get("camera", {})
    gate = cam.get("calibrationGate")
    name = cat.get("name", cat.get("id"))
    protection = (
        f"Bugünkü kısmi koruma `camera.calibrationGate` ({cam.get('setup')}): "
        f"kullanıcı hareketi KENDİ seçiyor ve pozisyona giriyor."
        if gate else
        f"Bu harekette `camera.calibrationGate` KAPALI ({cam.get('setup')}) — "
        f"yani bugün kısmi koruma bile yok."
    )
    return (
        f"HENÜZ TÜRETİLMEDİ — {name} kimlik ön koşulu ölçümle kurulmadı. "
        f"Motor tarafı: {signal_phrase(cat)}. "
        f"Sinyalin kendisi KİMLİK DEĞİLDİR: aynı eklem/ölçü başka bir "
        f"bağlamda da aynı biçimde salınır, ve kimlik kapısı olmadan motor "
        f"hareketi değil salınımı sayar (G-043). "
        f"Eksik olan şey İSİMLİDİR: bu hareketin kimliğinin HANGİ ölçünün "
        f"üstüne kurulacağı ve o ölçünün eşiği, hasat ölçümünden türetilmedi. "
        f"⛔ Eşik BURADA UYDURULMAZ (G-014/G-050): taban değeri varsayılandır, "
        f"ölçüm değil. {protection} "
        f"Kapı bu yüzden `status=derived` şart koşuyor. {MARK}"
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    changed, drifted = [], []
    for wave in sorted(p for p in CATALOG_ROOT.iterdir() if p.is_dir()):
        for path in sorted(wave.glob("*.json")):
            cat = json.loads(path.read_text(encoding="utf-8"))
            pre = (cat.get("engine") or {}).get("precondition") or {}
            # `derived` olanın rationale'ı HASAT ÖLÇÜMÜNÜ anlatıyor (push_up:
            # "85 tekrarın 65'i gövdesi 50-90° eğimli kayıtlardan geldi").
            # Onu üretilmiş metinle ezmek gerçek bir ölçümü silmek olurdu.
            if pre.get("status") != "pending":
                continue
            fresh = build_rationale(cat)
            if pre.get("rationale") == fresh:
                continue
            drifted.append(cat["id"])
            if args.write:
                pre["rationale"] = fresh
                path.write_text(
                    json.dumps(cat, ensure_ascii=False, indent=2) + "\n",
                    encoding="utf-8")
                changed.append(cat["id"])

    if args.check:
        if drifted:
            print(f"⛔ DRIFT: {len(drifted)} bekleyen hareketin rationale'ı "
                  f"üretilenle aynı değil ({', '.join(drifted[:6])}"
                  f"{'…' if len(drifted) > 6 else ''})")
            return 1
        print("✅ bekleyen hareketlerin rationale'ları güncel ve İSİMLİ")
        return 0

    print(f"{len(drifted)} hareketin rationale'ı tazelenecek")
    if args.write:
        print(f"✍️  {len(changed)} dosya yazıldı")
    else:
        print("(kuru koşum — uygulamak için --write)")
        if drifted:
            print("\nörnek çıktı:")
            sample = json.loads(
                next(CATALOG_ROOT.glob(f"*/{drifted[0]}.json"))
                .read_text(encoding="utf-8"))
            print("   " + build_rationale(sample))
    return 0


if __name__ == "__main__":
    sys.exit(main())
