#!/usr/bin/env python3
"""Katalog `provenance` bloğunu REFERANS ARTEFAKTINDAN türetir — elle yazılmaz.

Neden ayrı bir araç: bir sayı elle yazıldığı anda ölçümden ayrılabilir ve
ayrıldığını kimse fark etmez. push_up'ta tam bu oldu — 9 eğitmenlik referans
üretildikten sonra bile katalog `status: pending_harvest, consensusN: 0`
diyordu ve hiçbir kapı itiraz etmiyordu (V17 eklenene kadar).

Bu araç YAZAR, `validate_catalog.py` V17 DENETLER. İkisi birlikte çalışınca
katalog iddiası ile ölçüm arasında sessiz sapma imkânsız hale gelir:
araç güncellemeyi unutursa doğrulayıcı kırmızı yanar.

Sözlük:
  pending_harvest       — referans artefaktı yok
  harvested_provisional — referans var ama ≥1 eklem TABAN-bağlı (G-014 kapanmaz)
  harvested_derived     — tüm eklem toleransları varyans-türetimli
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
HARVEST = ROOT / "content" / "harvest"


def main():
    changed = []
    for cfg_path in sorted((ROOT / "content" / "catalog").glob("w*/*.json")):
        cfg = json.loads(cfg_path.read_text())
        ref_path = HARVEST / f"reference.{cfg['id']}.json"
        if not ref_path.exists():
            continue
        ref = json.loads(ref_path.read_text())
        tol = ref.get("tolerances") or {}
        floor = sorted(k for k, v in tol.items() if v.get("source") == "floor")
        derived = sorted(k for k, v in tol.items() if v.get("source") == "variance")
        prov = {
            "sources": sorted(ref.get("instructors") or []),
            "consensusN": len(ref.get("instructors") or []),
            "status": "harvested_provisional" if floor else "harvested_derived",
            # Hangi eklemin toleransı ÖLÇÜMDEN, hangisi TABANDAN geldiği
            # katalogda da görünür: "varyans-türetimli tolerans" iddiası
            # yalnız `derivedJoints` için doğrudur (G-050).
            "derivedJoints": derived,
            "floorBoundJoints": floor,
            "takes": ref.get("takes"),
            "excludedOutliers": len(ref.get("excludedOutlierIds") or []),
            "orderIndependent": ref.get("orderIndependent"),
            "mirrorAgnostic": ref.get("mirrorAgnostic"),
            "$note": (
                "ELLE DÜZENLENMEZ — tools/sync_provenance.py referans "
                "artefaktından türetir, validate_catalog.py V17 denetler."
            ),
        }
        if cfg.get("provenance") != prov:
            cfg["provenance"] = prov
            cfg_path.write_text(
                json.dumps(cfg, indent=2, ensure_ascii=False) + "\n")
            changed.append(
                f"{cfg['id']}: {prov['status']} · {prov['consensusN']} eğitmen · "
                f"{len(derived)} varyans / {len(floor)} taban eklem")
    print("\n".join(changed) if changed else "değişiklik yok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
