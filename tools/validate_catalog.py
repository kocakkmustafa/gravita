#!/usr/bin/env python3
"""Gravita hareket kataloğu nöbetçisi — mekanik denetim betikle yapılır (aile kuralı: LLM-denetim değil).

Denetlenen değişmezler (hepsi bir DEFTER/ADR maddesine bağlı):
  V1  şema: zorunlu alanlar + enum'lar + id benzersizliği
  V2  G-007 / M-F-06 : rep-FSM sinyali `side: "visible"` olmalı — model L/R etiketine bağlanamaz
  V3  G-006          : patlayıcı/checkpoint fazlarının metrikleri `gateableMetrics`e GİREMEZ
  V4  M-F-04 / K8    : `scoreDisplay` kalibrasyon kapısı geçilmeden "numeric" olamaz
  V5  Blueprint §1   : B sınıfı hareket form-hükmü İDDİA EDEMEZ
  V6  G-013 / M-C-03 : her form hatasının perturbasyon genliği, tespit eşiğinden BÜYÜK olmalı
  V7  Dürüstlük      : her form hatasının kullanıcıya söylenecek bir `cue`u var
  V8  C sınıfı katalogda yer alamaz (exclusions.json'a gider)
  V9  timeout        : rep/çok-faz motorlarında fiziksel üst sınır zorunlu (JabLab J-009 dersi)
  V12 ters yönelim   : `expectedOrientation: inverted` -> `structuralCheck: required` ZORUNLU
  V11 uç ayrıklığı   : repFsm'in iki ucu (angleMin/angleMax) ÖRTÜŞEMEZ — örtüşürse her kare
                       her iki uçta sayılır ve motor durmadan "tekrar" üretir
  V10 J-027          : `fastTransition: true` olan motor `signalFilter.cutoffHz` beyan ETMELİ —
                       çekirdek varsayılan yumuşatması hızlı geçişleri söndürür; filtre kesimi
                       eşiklerle BİRLİKTE pinlenir

Çıkış kodu 0 = temiz, 1 = ihlal var.
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOG = ROOT / "content" / "catalog"
FAMILIES = {"push", "pull", "legs", "core", "shoulders", "skill", "barbell", "dbkb", "plyo", "carry"}
PRIORITIES = {"safety", "blocking", "balance", "major_alignment", "minor_form", "optimization"}
ENGINES = {"repFsm", "staticHold", "multiPhaseFsm"}
# V3: bu metrikler patlayıcı/blur fazlardan gelir -> asla progresyon kapısı olamaz
NON_GATEABLE = {"jump_height", "power", "force", "kickup_impulse", "exit_control",
                "punch_velocity", "peak_speed", "explosive_power"}

errors: list[str] = []
warnings: list[str] = []


def err(f, msg):
    errors.append(f"❌ {f}: {msg}")


def warn(f, msg):
    warnings.append(f"⚠️  {f}: {msg}")


def num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


METRICS = json.loads((ROOT / "content" / "schema" / "metrics.json").read_text())["metrics"]


def check_perturbation(f, fe):
    """V6: bozulmuş fixture'ın ULAŞTIĞI değer, hatayı tetikleyen eşiği marjla aşmalı.

    İki tasarım dersi bu fonksiyonda gömülü:
    1) `targetValue` (delta değil): perturbasyon referanstan SAPMA, eşik ise MUTLAK değer.
       Taban değeri sıfır olmayan metriklerde (squat'ta gövde açısı ~35°) ikisi farklı birimde
       konuşur, kontrol doğrulanamaz hale gelir — C-011 tuzağının kaynağı budur.
    2) Marj ÇARPIMSAL DEĞİL, metriğin kendi biriminde MUTLAK: diz açısının tavanı 180°'dir,
       165 × 1.25 = 206 fiziksel olarak imkânsızdır. Marj = metrics.json `noiseBand`.
    """
    det, pert = fe.get("detect"), fe.get("perturbation")
    fid = fe.get("id", "?")
    if not pert:
        if det and det.get("rule") is None:
            warn(f, f"form hatası '{fid}': perturbasyon tanımı yok — fixture bu hatayı üretemez (M-C-03)")
        return
    if not det or not num(det.get("value")):
        return
    metric = det.get("metric")
    if metric not in METRICS:
        err(f, f"form hatası '{fid}': '{metric}' metrics.json'da tanımlı değil — "
               f"tanımsız metrik üzerine eşik yazılamaz")
        return
    spec = METRICS[metric]
    band = spec.get("noiseBand", 0)
    lo, hi = spec.get("range", [float("-inf"), float("inf")])
    thr, op = det["value"], det.get("op", ">")
    tv = pert.get("targetValue")
    if not num(tv):
        err(f, f"form hatası '{fid}': perturbasyon `targetValue` beyan etmiyor — "
               f"delta tek başına eşiği aştığını KANITLAMAZ (G-013 / C-011)")
        return
    if not (lo <= tv <= hi):
        err(f, f"form hatası '{fid}': perturbasyon hedefi {tv}, metriğin fiziksel aralığı "
               f"[{lo}, {hi}] dışında — üretilemeyecek bir fixture")
        return
    margin = (tv - thr) if op in (">", ">=") else (thr - tv)
    if margin < band:
        err(f, f"form hatası '{fid}': perturbasyon hedefi {tv}, eşik {op}{thr} → marj {round(margin, 4)} "
               f"< gürültü bandı {band} ({metric}); fixture toleransın İÇİNDE kalır (G-013 / C-011)")


def check(path):
    f = path.name
    try:
        m = json.loads(path.read_text())
    except Exception as e:
        err(f, f"JSON okunamadı: {e}")
        return None

    for k in ("schemaVersion", "id", "name", "family", "wave", "class",
              "classRationale", "camera", "engine", "measurementContract", "provenance"):
        if k not in m:
            err(f, f"zorunlu alan eksik: {k}")
    if "id" not in m:
        return None

    if m.get("family") not in FAMILIES:
        err(f, f"geçersiz family: {m.get('family')}")

    cls = m.get("class")
    if cls == "C":                                                     # V8
        err(f, "C sınıfı katalogda yer ALAMAZ — exclusions.json'a taşı")
    elif cls not in {"A", "B", "D"}:
        err(f, f"geçersiz class: {cls}")

    eng = m.get("engine", {})
    et = eng.get("type")
    if et not in ENGINES:
        err(f, f"geçersiz engine.type: {et}")

    if et == "repFsm":
        sig = eng.get("signal", {})
        if sig.get("side") != "visible":                                # V2
            err(f, f"engine.signal.side='{sig.get('side')}' — 'visible' olmalı "
                   f"(G-007/M-F-06: model L/R etiketine güvenilmez)")
        if not eng.get("repCountedOn"):
            err(f, "repFsm: repCountedOn eksik")
        # V11: iki uç eşiği ayrık olmalı (faz ADLARINA bakılmaz — motor da bakmıyor)
        open_end = closed_end = None
        for v in (eng.get("phases") or {}).values():
            if not isinstance(v, dict):
                continue
            if num(v.get("angleMin")):
                open_end = v["angleMin"]
            if num(v.get("angleMax")):
                closed_end = v["angleMax"]
        if open_end is None or closed_end is None:
            err(f, "repFsm fazları iki uç tanımlamalı: biri angleMin, biri angleMax")
        elif open_end <= closed_end:
            err(f, f"repFsm uçları ÖRTÜŞÜYOR (angleMin={open_end} ≤ angleMax={closed_end}) — "
                   f"her kare iki uçta birden sayılır, motor durmadan tekrar üretir")
        if not num(eng.get("timeoutMs")):                               # V9
            err(f, "repFsm: timeoutMs eksik — fiziksel üst sınır zorunlu (J-009 dersi)")
        if eng.get("fastTransition"):                                   # V10
            sf = eng.get("signalFilter") or {}
            if not num(sf.get("cutoffHz")):
                err(f, "fastTransition=true ama signalFilter.cutoffHz yok — çekirdek varsayılan "
                       "yumuşatması hızlı geçişi söndürür (J-027); kesim eşiklerle birlikte pinlenir")
            elif not sf.get("rationale_tr") and not sf.get("derivedFrom"):
                warn(f, "signalFilter var ama kesim frekansının NEREDEN türetildiği yazılmamış (J-027)")
    if et == "multiPhaseFsm":
        if len(eng.get("sequence", [])) < 3:
            err(f, "multiPhaseFsm: sequence en az 3 faz içermeli")
        if not num(eng.get("timeoutMs")):                               # V9
            err(f, "multiPhaseFsm: timeoutMs eksik (J-009)")
    if et == "staticHold":
        if not eng.get("formBreak"):
            err(f, "staticHold: formBreak eksik — form kırılması tespit edilmeden tutuş ölçülmez")
    # V12: ters yönelim bir MOTOR TİPİ değil, bir yönelim niteliğidir — bir tutuş
    # da bir tekrar da (HSPU) ters olabilir. `inverted` ise yapısal denetim ŞART:
    # güven kapısı kol↔bacak takasını yakalayamıyor (D1'de ölçüldü).
    if eng.get("expectedOrientation") == "inverted" and eng.get("structuralCheck") != "required":
        err(f, "expectedOrientation=inverted ama structuralCheck='required' değil "
               "(ADR-002: ters yönelimde güven kapısı takası kaçırıyor)")

    mc = m.get("measurementContract", {})
    if not mc.get("measured"):
        err(f, "measurementContract.measured boş — dürüstlük kutusu üretilemez")
    if not mc.get("notMeasured"):
        warn(f, "notMeasured boş — 'neyi ölçmüyoruz' her hareket için yazılmalı")
    if mc.get("scoreDisplay", "band") != "band":                       # V4
        err(f, f"scoreDisplay='{mc.get('scoreDisplay')}' — kalibrasyon kapısı geçilmeden "
               f"sayısal skor gösterilemez (M-F-04/K8)")
    bad = NON_GATEABLE.intersection(mc.get("gateableMetrics", []))      # V3
    if bad:
        err(f, f"gateableMetrics patlayıcı/blur metriği içeriyor: {sorted(bad)} (G-006)")

    checkpoints = set(eng.get("checkpointOnly", []))
    if checkpoints and not eng.get("checkpointRationale_tr"):
        warn(f, "checkpointOnly var ama gerekçesi yazılmamış")

    if cls == "B":                                                     # V5
        joined = " ".join(mc.get("measured", [])).lower()
        for word in ("form verdict", "form score", "alignment"):
            if word in joined:
                err(f, f"B sınıfı '{word}' iddia ediyor — B'de form hükmü YOK (blueprint §1/§8)")

    for fe in m.get("formErrors", []):
        fid = fe.get("id", "?")
        if fe.get("priority") not in PRIORITIES:
            err(f, f"form hatası '{fid}': geçersiz priority {fe.get('priority')}")
        if not fe.get("cue"):                                          # V7
            err(f, f"form hatası '{fid}': cue yok — tespit edip söylemediğimiz hata olamaz")
        check_perturbation(f, fe)                                      # V6

    prov = m.get("provenance", {})
    n = prov.get("consensusN", 0)
    if prov.get("status") in ("consensus_built", "expert_reviewed") and n < 3:
        err(f, f"provenance: status={prov['status']} ama consensusN={n} (<3 kaynak — katalog §6.0)")
    elif prov.get("status") == "pending_harvest":
        warn(f, "provenance: hasat bekliyor — tolerans değerleri henüz kaynak varyansından TÜREMEDİ")

    return m.get("id")


def main():
    files = sorted(CATALOG.rglob("*.json"))
    files = [p for p in files if p.name != "exclusions.json"]
    if not files:
        print("Katalogda hareket yok.")
        return 0
    ids = {}
    for p in files:
        i = check(p)
        if i:
            ids.setdefault(i, []).append(p.name)
    for i, fs in ids.items():
        if len(fs) > 1:
            err(", ".join(fs), f"id çakışması: '{i}'")

    print(f"Denetlenen hareket: {len(files)}")
    for w in warnings:
        print(w)
    for e in errors:
        print(e)
    print(f"\n{'✅ TEMİZ' if not errors else '❌ İHLAL'} — {len(errors)} hata, {len(warnings)} uyarı")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
