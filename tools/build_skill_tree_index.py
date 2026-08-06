#!/usr/bin/env python3
"""Beceri ağacı paketlerinin ÖZET indeksini üretir.

## Neden var

Kütüphane ekranı beceri ağaçları hakkında bir cümle kuruyor ("kaç ağaç
taslak hâlde, hangileri, eşikleri doğrulandı mı"). O cümledeki her sayı ve
her ad `content/skill-graph/*.json`'dan GELMEK zorunda:

  · elle yazılmış "2 tree" bir üçüncü paket eklendiği gün SESSİZCE yalan olur
  · ekranın düğüm adlarından ("tuck_planche", "chest_to_wall") hangi ağaca
    ait olduğunu TAHMİN etmesi ise uydurulmuş bir eşleştirmedir — ilk
    yazışımda tam olarak bunu yapmıştım ve düzeltilen kusur budur

Paketlerin KENDİSİ paketlenmiyor: `nodes[]` doğrulanmamış eşik değerleri
taşıyor (`status: DRAFT — thresholds ... NOT yet validated`). Onları
uygulamaya sokmak, ölçülmemiş bir eşiği bir kapı gibi çizmeye DAVET olurdu.
İndeks yalnız "ne var, hangi durumda" der.

    python3 tools/build_skill_tree_index.py --write
    python3 tools/build_skill_tree_index.py --check
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = ROOT / "content" / "skill-graph"
OUT = ROOT / "content" / "skill-trees.index.json"


def _is_draft(status):
    """DRAFT beyanı — pakedin KENDİ `status` alanından, kanaatten değil."""
    return "draft" in (status or "").strip().lower()[:8]


def build():
    trees = []
    for path in sorted(SRC_DIR.glob("*.json")):
        pack = json.loads(path.read_text(encoding="utf-8"))
        nodes = pack.get("nodes") or []
        trees.append({
            "packId": pack["packId"],
            # Başlık paketin id'sinden türer ("gravita.handstand" → "Handstand").
            # Paket kendi görünen adını taşımıyor; taşıdığı gün buraya o gelir.
            "displayName": pack["packId"].rsplit(".", 1)[-1].replace("_", " ").title(),
            "packVersion": pack.get("packVersion"),
            "nodeCount": len(nodes),
            # ⚠️ TEK ÖNEMLİ ALAN: eşikleri doğrulanmış mı. Ekran ağacı
            # ÇİZMEME kararını buna dayandırıyor, bir yorum satırına değil.
            "thresholdsValidated": not _is_draft(pack.get("status")),
            "nodeIds": [n["id"] for n in nodes if "id" in n],
        })
    return {
        "schemaVersion": 1,
        "$generatedBy": "tools/build_skill_tree_index.py — ELLE DÜZENLEME. "
                        "Kaynak: content/skill-graph/*.json",
        "trees": trees,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    text = json.dumps(build(), ensure_ascii=False, indent=2) + "\n"
    index = json.loads(text)

    if args.check:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print(f"⛔ DRIFT: {OUT.relative_to(ROOT)} kaynaktan üretilenle "
                  f"aynı değil (ya da yok)")
            return 1
        validated = sum(1 for t in index["trees"] if t["thresholdsValidated"])
        print(f"✅ beceri ağacı indeksi güncel — {len(index['trees'])} paket, "
              f"{validated}'i eşik-doğrulanmış")
        return 0

    for t in index["trees"]:
        print(f"   · {t['displayName']}: {t['nodeCount']} düğüm · "
              f"eşikler {'DOĞRULANDI' if t['thresholdsValidated'] else 'TASLAK'}")
    if args.write:
        OUT.write_text(text, encoding="utf-8")
        print(f"✍️  yazıldı: {OUT.relative_to(ROOT)}")
    else:
        print("(kuru koşum — uygulamak için --write)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
