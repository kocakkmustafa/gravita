#!/usr/bin/env python3
"""Gravita hareket kataloğu nöbetçisi — mekanik denetim betikle yapılır (aile kuralı: LLM-denetim değil).

Denetlenen değişmezlerin LİSTESİ koddaki `INVARIANTS` kaydındadır ve sayısı
oradan TÜRETİLİR — elle yazılmış bir başlık listesi, değişmez eklendikçe sessizce
bayatlıyordu (V15/V16/V17 eklendi, başlık 14'te kalmıştı; commit mesajlarımda
"16 değişmez" yazdım, gerçek 17'ydi). Sayı artık kaynaktan gelir.

Çıkış kodu 0 = temiz, 1 = ihlal var.
"""
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from sync_provenance import _extract as _extract_reference  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOG = ROOT / "content" / "catalog"
FAMILIES = {"push", "pull", "legs", "core", "shoulders", "skill", "barbell", "dbkb", "plyo", "carry"}
PRIORITIES = {"safety", "blocking", "balance", "major_alignment", "minor_form", "optimization"}
ENGINES = {"repFsm", "staticHold", "multiPhaseFsm"}
# V3: bu metrikler patlayıcı/blur fazlardan gelir -> asla progresyon kapısı olamaz
NON_GATEABLE = {"jump_height", "power", "force", "kickup_impulse", "exit_control",
                "punch_velocity", "peak_speed", "explosive_power"}

#: Değişmez kaydı — TEK ADRES. Başlık, çıktı ve sayı hep buradan türer.
INVARIANTS = {
    "V1": "şema: zorunlu alanlar + enum'lar + id benzersizliği",
    "V2": "G-007/M-F-06: rep-FSM sinyali `side: visible` olmalı",
    "V3": "G-006: patlayıcı/checkpoint metrikleri gateableMetrics'e giremez",
    "V4": "M-F-04/K8: scoreDisplay kalibrasyon kapısı olmadan 'numeric' olamaz",
    "V5": "Blueprint §1: B sınıfı form-hükmü iddia edemez",
    "V6": "G-013/M-C-03: perturbasyon genliği tespit eşiğinden büyük olmalı",
    "V7": "her form hatasının kullanıcıya söylenecek bir cue'u var",
    "V8": "C sınıfı katalogda yer alamaz",
    "V9": "J-009: rep/çok-faz motorlarında timeout zorunlu",
    "V10": "J-027: fastTransition -> signalFilter.cutoffHz beyanı zorunlu",
    "V11": "repFsm'in iki ucu (angleMin/angleMax) örtüşemez",
    "V12": "ADR-001: expectedOrientation=inverted -> structuralCheck required",
    "V13": "skillGraphNode gerçek bir düğüme işaret etmeli",
    "V14": "M-F-43/45: passiveExecutionPossible beyan edilmeli",
    "V15": "G-043: hareket-kimliği precondition beyanı (derived|pending)",
    "V16": "G-054: ROM hata eşiği SAYIM eşiğiyle ulaşılabilir olmalı",
    "V17": "M-F-63: referans artefaktı ile katalog provenance'ı çelişemez",
}

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

    # V15: hareket-kimliği ön koşulu BEYAN edilmeli; hasat kuyruğundakiler
    # TÜRETİLMİŞ olmalı. Tekrar FSM'i sinyal ekleminin salınımını sayar,
    # hareketi değil — ayakta el hareketi de "tekrar" üretir (G-043).
    pre = (m.get("engine") or {}).get("precondition")
    if not isinstance(pre, dict) or pre.get("status") not in ("derived", "pending"):
        err(f, "engine.precondition BEYAN edilmemiş (status: derived|pending) — "
               "beyansız hareket, ayakta el hareketini tekrar sayar (G-043)")
    elif pre["status"] == "derived" and not pre.get("conditions"):
        err(f, "precondition.status=derived ama conditions BOŞ — türetilmiş "
               "diyen beyan koşul taşımak zorunda")
    elif pre["status"] == "pending" and m.get("id") in _harvested_ids():
        err(f, f"'{m.get('id')}' için tekrar çıkarımı yapılmış ama precondition "
               "türetilmemiş — hasatta kullanıcı beyanı YOKTUR (üründeki "
               "calibrationGate'in karşılığı hasatta ölçümdür); türetilmeden "
               "çıkarılan tekrarlar referansa giremez")

    # V16: ROM hata eşiği SAYIM eşiğiyle ulaşılabilir olmalı.
    #
    # Sayım eşiği hatayı KAPILAR: bir tekrar sayılmak için dibe inmek zorundaysa,
    # "yeterince inmedin" hatası o tekrar için hiçbir zaman doğru olamaz. Şema
    # bunu göremez (iki alan da geçerli), replay gösterir — 5 harekette birden
    # aynı çelişki vardı (G-054) ve sığ çalışan kullanıcı sıfır tekrar + sıfır
    # geri bildirim alıyordu: sessiz-hiçlik, en kötü sonuç.
    #
    # Doğru tasarım: SAYIM eşiği cömert dış sınır, HATA eşiği onun içindeki
    # kalite çizgisi.
    eng = m.get("engine") or {}
    if eng.get("type") == "repFsm":
        amin = amax = None
        for v in (eng.get("phases") or {}).values():
            if isinstance(v, dict):
                if "angleMin" in v:
                    amin = v["angleMin"]
                if "angleMax" in v:
                    amax = v["angleMax"]
        for e in m.get("formErrors") or []:
            d = e.get("detect") or {}
            mt, op, val = d.get("metric"), d.get("op"), d.get("value")
            if mt == "rom_bottom_angle" and op in (">", ">=") and amax is not None \
                    and val >= amax:
                err(f, f"'{e['id']}' ULAŞILAMAZ: tekrar sayılmak için dip ≤{amax}° "
                       f"olmalı, hata ise >{val}° istiyor — hiçbir SAYILAN tekrar "
                       f"bu hatayı tetikleyemez (V16/G-054)")
            if mt == "rom_top_angle" and op in ("<", "<=") and amin is not None \
                    and val <= amin:
                err(f, f"'{e['id']}' ULAŞILAMAZ: tekrar sayılmak için tepe ≥{amin}° "
                       f"olmalı, hata ise <{val}° istiyor (V16/G-054)")

    # V17: REFERANS ARTEFAKTI ile katalog provenance'ı ÇELİŞEMEZ.
    #
    # Bu değişmez bir bayrak denetiminden fazlası: referans artefaktındaki
    # `source: floor|variance`, eğitmen sayısı ve sıra/ayna bayrakları buraya
    # bağlanana kadar OKUYANI YOKTU — özenle yazılmış, kimsenin sormadığı
    # provenance. Okuyanı olmayan bayrak süstür; ya bağlanır ya kaldırılır.
    #
    # Sözlük: pending_harvest (referans yok) · harvested_provisional (referans
    # var ama ≥1 eklem TABAN-bağlı → G-014 kapanmaz) · harvested_derived
    # (tüm eklemler varyans-türetimli).
    ref_path = ROOT / "content" / "harvest" / f"reference.{m.get('id')}.json"
    prov0 = m.get("provenance") or {}
    if ref_path.exists():
        try:
            ref = json.loads(ref_path.read_text())
        except Exception as e:
            err(f, f"referans artefaktı okunamadı: {e}")
            ref = None
        if ref:
            # Kanonik (motion-core/reference@1) VE eski Gravita şeması ortak
            # okuyucudan geçer (sync_provenance.py) — iki şema iki yerde
            # ayrı ayrı yorumlanırsa tam bu gece tekrar sessiz sapma olur.
            e = _extract_reference(ref)
            n_inst = e["consensusN"]
            floor = e["floor"]
            want = "harvested_provisional" if floor else "harvested_derived"
            if prov0.get("status") != want:
                err(f, f"provenance.status='{prov0.get('status')}' ama referans "
                       f"artefaktı '{want}' diyor "
                       f"({len(floor)} eklem taban-bağlı) — katalog iddiası "
                       f"ölçümle çelişiyor (V17)")
            if prov0.get("consensusN") != n_inst:
                err(f, f"provenance.consensusN={prov0.get('consensusN')} ama "
                       f"referans {n_inst} eğitmenden türedi (V17)")
            # M-F-46 kural 7: sıra-bağımsız DEĞİL ve ayna-duyarsız DEĞİLSE
            # taraf-bağımlı hüküm yasak. ADR-003 zaten taraf adı yasaklıyor;
            # burada MEKANİK olarak da doğrulanır.
            # Eğitmenlerin ANLAŞAMADIĞI eklem skorlanamaz: dağılımı bu kadar
            # geniş bir eklemde hüküm vermek, kullanıcıyı öğretmenlerin kendi
            # aralarında anlaşamadığı bir şey için cezalandırmaktır.
            for j in e["unreliableJoints"]:
                base = j.replace("left_", "").replace("right_", "")
                gm = ((m.get("measurementContract") or {}).get("gateableMetrics") or [])
                if any(base in g for g in gm):
                    err(f, f"'{j}' referansta GÜVENİLMEZ (eğitmenler anlaşamıyor) "
                           f"ama gateableMetrics onu kapı metriği yapıyor — "
                           f"anlaşmazlık üzerine hüküm kurulamaz (V17)")
            # `orderIndependent` None ise (kanonik şemada ölçülemedi — n>18
            # tükenmez-arama sınırı) BİLİNMİYOR demektir, "sıra-bağımsız"
            # VARSAYILMAZ; yalnız mirrorAgnostic tek başına kurtarıyor.
            order_ok = e["orderIndependent"] is True
            if not order_ok and not e["mirrorAgnostic"]:
                sig = ((m.get("engine") or {}).get("signal") or {})
                if sig.get("side") != "visible":
                    err(f, "referans sıra-bağımsız DEĞİL/BİLİNMİYOR ve ayna-duyarsız "
                           "DEĞİL → M-F-46 kural 7: taraf-bağımlı hüküm verilemez, "
                           "signal.side 'visible' olmalı (V17)")
    elif prov0.get("status") not in (None, "pending_harvest"):
        err(f, f"provenance.status='{prov0.get('status')}' ama referans "
               f"artefaktı YOK — hasat edilmiş iddiası kanıtsız (V17)")

    if not isinstance(m.get("passiveExecutionPossible"), bool):           # V14
        err(f, "passiveExecutionPossible BEYAN edilmemiş — `unknown` kaynak "
               "muafiyeti (M-F-45) beyansız kullanılamaz; fail-closed kural gereği "
               "beyan yoksa kaynak referansa giremez")
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


def _harvested_ids():
    """Tekrar ÇIKARIMI yapılmış hareketler — bunlar için ön koşul TÜRETİLMİŞ olmalı.

    Ölçüt kuyruk DEĞİL, çıkarım artefaktıdır: aday keşfi serbesttir (kuyruğa
    hareket eklemek bir iddia taşımaz), yasak olan kimlik kapısı olmadan tekrar
    çıkarıp onu referansa sokmaktır.
    """
    return {p.name[len("reps."):-len(".json")]
            for p in (ROOT / "content" / "harvest").glob("reps.*.json")}


def _skill_graph_nodes():
    """Tüm beceri ağacı paketlerindeki düğüm kimlikleri."""
    ids = set()
    for p in (ROOT / "content" / "skill-graph").glob("*.json"):
        try:
            for n in json.loads(p.read_text()).get("nodes", []):
                ids.add(n["id"])
        except Exception as e:
            errors.append(f"❌ {p.name}: beceri ağacı okunamadı: {e}")
    return ids


def main():
    files = sorted(CATALOG.rglob("*.json"))
    files = [p for p in files if p.name != "exclusions.json"]
    if not files:
        print("Katalogda hareket yok.")
        return 0
    graph_nodes = _skill_graph_nodes()
    ids = {}
    for p in files:
        i = check(p)
        if i:
            ids.setdefault(i, []).append(p.name)
        # V13: kopuk beceri-ağacı referansı
        try:
            node = json.loads(p.read_text()).get("skillGraphNode")
        except Exception:
            node = None
        if node and node not in graph_nodes:
            err(p.name, f"skillGraphNode '{node}' hiçbir beceri ağacında yok — "
                        f"kullanıcıyı var olmayan düğüme yollar")
    for i, fs in ids.items():
        if len(fs) > 1:
            err(", ".join(fs), f"id çakışması: '{i}'")

    print(f"Denetlenen hareket: {len(files)} · değişmez: {len(INVARIANTS)}")
    for w in warnings:
        print(w)
    for e in errors:
        print(e)
    print(f"\n{'✅ TEMİZ' if not errors else '❌ İHLAL'} — {len(errors)} hata, {len(warnings)} uyarı")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
