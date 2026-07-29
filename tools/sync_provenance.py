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

⚠️ G-063/G-064 (2026-07-29, koordinatör M-F-90): referans artefaktı ARTIK
motion-core'un kanonik şeması (`motion-core/reference@1`) — Gravita'nın eski
düz şeması (`instructors`/`tolerances`/`takes` kök-düzeyinde) YOK. Alanlar
`result.*`/`tolerance.perJointSource` altında ve TARAF-BAŞINA (left_x/right_x
ayrı, eski "x" tek-çift değil). Bu araç ikisini de okuyabilir (eski şema
henüz referansı olmayan/eski kalan hareketler için bozulmasın).
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
HARVEST = ROOT / "content" / "harvest"


def _pair(joint_id):
    return joint_id.replace("left_", "").replace("right_", "")


def _extract(ref):
    """Kanonik (motion-core/reference@1) veya eski Gravita şemasından
    (`build_reference.dart`'ın ürettiği düz format) ortak bir sözlüğe okur."""
    if ref.get("schema") == "motion-core/reference@1":
        result = ref.get("result") or {}
        per_joint = (ref.get("tolerance") or {}).get("perJointSource") or {}
        # Taraf-başına kaynağı ÇİFT'e indirger: bir çiftin BİR tarafı bile
        # taban-bağlıysa "varyans-türetimli" iddiası o çift için YANLIŞTIR
        # (G-050 — zayıf halka kadar güçlü).
        pairs = {}
        for joint, source in per_joint.items():
            key = _pair(joint)
            pairs.setdefault(key, set()).add(source)
        floor = sorted(k for k, srcs in pairs.items() if "floor" in srcs)
        derived = sorted(k for k, srcs in pairs.items() if srcs == {"variance"})
        sources = sorted(set(result.get("sources") or []))
        return {
            "sources": sources,
            "consensusN": result.get("distinctSources", len(sources)),
            "floor": floor,
            "derived": derived,
            "takes": result.get("contributingTakes"),
            "excludedOutliers": len(result.get("excludedOutlierIds") or []),
            "unreliableJoints": result.get("unreliableJoints") or [],
            "mirrorAgnostic": ref.get("$mirrorAgnostic"),
            # Kanonik şema `orderIndependent` (M-F-48) taşımıyor;
            # mirrorGapMeasured/searchDecisive en yakın eşdeğeri — ölçülmüşse
            # VE kararlıysa sıra-bağımsız sayılır, ölçülmemişse bilinmiyor
            # (True varsayımı YOK — V17 kuralı sessizce atlanmasın).
            "orderIndependent": (
                result.get("mirrorGapMeasured") and result.get("mirrorSearchDecisive")
                if result.get("mirrorGapMeasured") is not None else None
            ),
        }
    # Eski şema (build_reference.dart) — geriye dönük uyumluluk.
    tol = ref.get("tolerances") or {}
    return {
        "sources": sorted(ref.get("instructors") or []),
        "consensusN": len(ref.get("instructors") or []),
        "floor": sorted(k for k, v in tol.items() if v.get("source") == "floor"),
        "derived": sorted(k for k, v in tol.items() if v.get("source") == "variance"),
        "takes": ref.get("takes"),
        "excludedOutliers": len(ref.get("excludedOutlierIds") or []),
        "unreliableJoints": ref.get("unreliableJoints") or [],
        "mirrorAgnostic": ref.get("mirrorAgnostic"),
        "orderIndependent": ref.get("orderIndependent"),
    }


def main():
    changed = []
    for cfg_path in sorted((ROOT / "content" / "catalog").glob("w*/*.json")):
        cfg = json.loads(cfg_path.read_text())
        ref_path = HARVEST / f"reference.{cfg['id']}.json"
        if not ref_path.exists():
            continue
        ref = json.loads(ref_path.read_text())
        e = _extract(ref)
        prov = {
            "sources": e["sources"],
            "consensusN": e["consensusN"],
            "status": "harvested_provisional" if e["floor"] else "harvested_derived",
            # Hangi eklemin toleransı ÖLÇÜMDEN, hangisi TABANDAN geldiği
            # katalogda da görünür: "varyans-türetimli tolerans" iddiası
            # yalnız `derivedJoints` için doğrudur (G-050).
            "derivedJoints": e["derived"],
            "floorBoundJoints": e["floor"],
            "takes": e["takes"],
            "excludedOutliers": e["excludedOutliers"],
            "orderIndependent": e["orderIndependent"],
            "mirrorAgnostic": e["mirrorAgnostic"],
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
                f"{len(e['derived'])} varyans / {len(e['floor'])} taban eklem")
    print("\n".join(changed) if changed else "değişiklik yok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
