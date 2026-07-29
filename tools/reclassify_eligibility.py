#!/usr/bin/env python3
"""M-F-120 uygulaması: kaynak-uygunluğu KANONİK rig ile yeniden sınıflandır.

Neden gerekli (G-072): Gravita'nın hasadı `scratch/2026-07-29-gravita-harvest/`
altındaki BAYAT bir rig kopyasıyla koşmuştu — o kopyada M-F-45'in sınıf-düzeyi
muafiyet mekanizması (`passive_execution_possible`) HİÇ YOKTU. Yani doktrin
ailede zaten vardı, Gravita eski aletle ölçüyordu.

Bu araç hiçbir sınıflandırma mantığı YAZMAZ — kanonik rig'in kendi
`rom_mode.classify()`'ını çağırır (kopya-sürüklenmesi sınıfı hata, bu gece
hipKneeCoupling'de bir kez avlandı: G-065/G-066).

Ham video YENİDEN İNDİRİLMEZ: manifestlerdeki `title`/`description`
(+ varsa transkript) yeterli — sınıflandırma ZATEN yalnız metne bakar.

Kullanım:
    python3 tools/reclassify_eligibility.py --library ~/motion-harvest/gravita-squat \
        --movement bodyweight_squat [--apply]

`--apply` verilmezse HİÇBİR ŞEY YAZILMAZ (kuru koşum + tablo).
"""
import argparse
import json
import sys
import types
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# Kanonik rig: origin/main'den scratch'e materyalize edildi, SHA kayıtlı.
RIG_DIR = (ROOT.parent.parent.parent / "scratch" / "2026-07-30-rig-canonical"
           / "harvest_rig")
RIG_SHA_FILE = RIG_DIR.parent / "RIG_SHA.txt"
PROFILE = ROOT / "content" / "harvest" / "triage-profile.gravita.v2.json"

sys.path.insert(0, str(RIG_DIR))

# `harvest.py` modül düzeyinde `cv2` import ediyor (indirme/çıkarma hattı için)
# ve bu makinede kurulu değil — ham video YENİDEN İNDİRİLMEDİĞİ için de
# gerekmiyor. cv2'yi boş bir modülle karşılayıp kanonik modülü GERÇEKTEN
# import ediyoruz: `load_rom_policy` upstream'in kendi kodu olarak çalışır.
# Fonksiyonu elle kopyalamak kopya-sürüklenmesi riskidir ve bu gece bir kez
# avlandı (G-065/G-066: Gravita'nın kendi 2D formülü kanonikten sapmıştı).
# Stub YALNIZ import'u karşılar; cv2 GERÇEKTEN çağrılırsa AttributeError
# verir — sessiz yanlış sonuç değil, gürültülü hata.
sys.modules.setdefault("cv2", types.ModuleType("cv2"))

import rom_mode  # noqa: E402  (kanonik sınıflandırıcı)
from harvest import load_rom_policy  # noqa: E402  (kanonik politika okuyucu)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--library", required=True,
                    help="hasat kütüphanesi (manifests/ + landmarks/ içerir)")
    ap.add_argument("--movement", required=True)
    ap.add_argument("--apply", action="store_true",
                    help="manifest + fixture provenance'ını GERÇEKTEN güncelle")
    # KONTROL koşumu: uygunluk değişimini İKİ etkiye ayırmak için.
    # (a) M-F-120 sınıf muafiyeti (unknown → uygun) ve (b) KANONİK sınıflandırıcının
    # bayat kopyadan farkı (bazı modlar değişiyor: WEAK_PASSIVE ayrımı, J-058
    # birinci-şahıs sınıfı). Muafiyeti kapatıp koşarsak yalnız (b) görünür.
    # Yalnız TEŞHİS içindir — `--apply` ile birlikte kullanılamaz.
    ap.add_argument("--pep-override", choices=["true", "false"],
                    help="TEŞHİS: movementRomPolicy'yi ezip pep'i zorla "
                         "(etki ayrıştırma kontrolü; --apply ile kullanılamaz)")
    args = ap.parse_args()
    if args.pep_override and args.apply:
        print("⛔ --pep-override yalnız teşhis içindir, --apply ile kullanılamaz "
              "(politika dosyası tek doğruluk kaynağıdır).")
        return 1

    if not RIG_DIR.exists():
        print(f"⛔ kanonik rig yok: {RIG_DIR}\n"
              f"   `git show origin/main:tools/harvest_rig/*.py` ile materyalize et.")
        return 1
    rig_sha = (RIG_SHA_FILE.read_text(encoding="utf-8").strip()
               if RIG_SHA_FILE.exists() else "UNKNOWN")
    # Bayat kopya bu aracın çözdüğü hatanın ta kendisi — sessizce kabul etmiyoruz.
    if not hasattr(rom_mode, "FIRST_PERSON_DEMO_MARKERS"):
        print("⛔ rig kopyası BAYAT görünüyor (FIRST_PERSON_DEMO_MARKERS yok, "
              "J-058/M-F-104). Kanonik sürümle değiştir.")
        return 1

    lib = Path(args.library).expanduser()
    pep = load_rom_policy(str(PROFILE), args.movement)
    if args.pep_override:
        pep = args.pep_override == "true"
        print(f"⚠️  TEŞHİS KOŞUMU: pep politikadan DEĞİL, elle {pep} verildi\n")
    print(f"kanonik rig: {rig_sha[:12]} · hareket: {args.movement}")
    print(f"movementRomPolicy → passive_execution_possible = {pep} "
          f"({'MUAF (structurally-active)' if not pep else 'fail-closed AYNEN'})\n")

    transcripts = lib / "transcripts"
    rows, changed = [], []
    for mf in sorted((lib / "manifests").glob("*.json")):
        m = json.loads(mf.read_text(encoding="utf-8"))
        vid = m.get("video_id")
        spoken = ""
        tp = transcripts / f"{vid}.json"
        if tp.exists():
            spoken = " ".join(seg.get("text", "")
                              for seg in json.loads(tp.read_text(encoding="utf-8")))
        v = rom_mode.classify(
            title=m.get("title") or "", description=m.get("description") or "",
            transcript=spoken, passive_execution_possible=pep,
        )
        before = (m.get("rom_mode"), bool(m.get("reference_eligible")))
        after = (v.mode, v.reference_eligible)
        rows.append((m.get("channel", "?"), vid, before, after,
                     bool(spoken)))
        if before != after:
            changed.append((mf, m, v))

    print(f"{'kanal':24} {'önce':22} {'sonra':22} transkript")
    for ch, _vid, before, after, has_tr in rows:
        b = f"{before[0]}/{'UYGUN' if before[1] else 'uygun-değil'}"
        a = f"{after[0]}/{'UYGUN' if after[1] else 'uygun-değil'}"
        mark = "→" if before != after else " "
        print(f"{mark} {ch[:22]:22} {b:22} {a:22} {'var' if has_tr else 'YOK'}")

    n_before = sum(1 for *_x, in () ) or sum(1 for r in rows if r[2][1])
    n_after = sum(1 for r in rows if r[3][1])
    print(f"\nuygun kaynak: {n_before} → {n_after} "
          f"({len(changed)} manifest değişti)")

    if not args.apply:
        print("\n(kuru koşum — hiçbir şey yazılmadı; --apply ile uygula)")
        return 0

    fx_dir = lib / "landmarks"
    stamped = 0
    for mf, m, v in changed:
        m["rom_mode"] = v.mode
        m["reference_eligible"] = v.reference_eligible
        m.setdefault("stages", []).append({
            "stage": "romMode",
            "status": v.mode,
            **v.to_detail(),
            "source": "reclassify_eligibility.py (M-F-120)",
            "rigSha": rig_sha,
        })
        mf.write_text(json.dumps(m, ensure_ascii=False, indent=2), encoding="utf-8")

        fx = fx_dir / f"{m['video_id']}.full.json"
        if fx.exists():
            doc = json.loads(fx.read_text(encoding="utf-8"))
            prov = doc.get("provenance", {})
            prov["romMode"] = v.mode
            prov["referenceEligible"] = v.reference_eligible
            prov["$eligibilityBasis"] = (
                f"M-F-120 sınıf-düzeyi muafiyet (passive_execution_possible="
                f"{pep}); kanonik rig {rig_sha[:12]} rom_mode.classify()")
            doc["provenance"] = prov
            fx.write_text(json.dumps(doc, ensure_ascii=False), encoding="utf-8")
            stamped += 1

    print(f"\n✅ uygulandı: {len(changed)} manifest · {stamped} fixture damgalandı")
    print("⚠️  rep-dilimli fixture'lar (landmarks-rep-sliced/) YENİDEN "
          "ÜRETİLMELİ — dilimleyici provenance'ı ham fixture'dan kopyalar.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
