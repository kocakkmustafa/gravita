#!/usr/bin/env python3
"""Gerekçeli-API kapsama kapısı (2026-08-16, orkestratör ataması ①+②, v2).

## v2'de DEĞİŞEN — v1'in kör noktası kendi dersiyle kapatıldı

v1 `ios/Pods/` + `.symlinks/` (DERLEME-ÖNCESİ kaynaklar) taradı. Aynı gece
ölçüldü: `permission_handler_apple` **SPM**'den geliyor, CocoaPods değil —
`ios/Pods/` taraması onu HİÇ görmedi, ve `MediaPipeTasksCommon` `Frameworks/`
altında AYRI bir framework olarak bile PAKETLENMİYOR (statik olarak ANA
Runner yürütülebilirine gömülüyor, sembol sayıları bu yüzden DERLEME-ÖNCESİ
tahminden FARKLI çıkıyor — 12/3 değil 2/1, ölçüldü).

> **BAĞIMLILIK DİZİNİNİ TARAMAK KAYNAKLARI SÖYLER; PAKETİ TARAMAK GÖNDERİLENİ
> SÖYLER.** Bu kapı artık YALNIZ gerçek arşivi/`.app`i tarıyor.

## Bu aracın YAPTIĞI

`flutter build ipa` (ya da en azından `flutter build ios`) çalıştırılmış bir
arşiv/`.app` üzerinde: (1) `Runner` ana yürütülebiliri + `Frameworks/`
altındaki HER `.framework` ikili dosyası `nm -u` ile gerekçeli-API sembolleri
için taranır, (2) `.app` içindeki HER `PrivacyInfo.xcprivacy` bulunur ve
beyan ettiği kategoriler okunur, (3) birinci-taraf kaynak (motion_camera,
permission_handler_apple, `ios/Runner/`) tamamlayıcı olarak `grep` ile
taranır (derlenmiş ikilinin göremediği, ölü-kod-elenmemiş çağrı yerlerini
yakalamak için). Her kategori için: **kullanılıyor mu** VE **HERHANGİ bir
paketlenmiş manifestte beyan edilmiş mi**.

## Bu aracın YAPMADIĞI — sınır, adıyla

⛔ **Gerekçe KODU seçmez, önermez, yazmaz** — yalnız KATEGORİ adı.
⚠️ **"Kategori-bazlı mı çerçeve-bazlı mı toplanıyor" sorusunu ÇÖZMÜYOR.**
Korumacı davranıyor: bir kategori HERHANGİ bir manifestte beyan edilmişse
"kapsanıyor" sayar. Yanlış alarm ÜRETMEZ, ama framework-özgüyse gerçek
boşluğu KAÇIRMIŞ olabilir. Adıyla.
🚫 **Ortam hazır değilse (arşiv yok) "temiz" DEMEZ** — `run_all_gates.sh`ın
"ORTAM KURULMAMIŞ" desenindeki gibi ÜÇÜNCÜ bir hâl (ne yeşil ne kırmızı)
döner, exit 2.

## Sembol kaynağı — DÜRÜST SINIR, güçlendirildi (orkestratörün 2. talebi)

Apple'ın birincil dokümantasyonuna (`developer.apple.com/documentation/
bundleresources/describing-use-of-required-reason-api`) BU OTURUMDA **üç
ayrı denemeyle** erişilmeye çalışıldı (ana sayfa, alternatif URL, haber
duyurusu) — üçü de JS ile render ediliyor, `WebFetch` yalnız sayfa BAŞLIĞINI
döndürdü, gövdeyi ÇEKEMEDİ. **Birincil kaynak DOĞRULAMASI YAPILAMADI.**
Aşağıdaki liste İKİNCİL kaynaklardan (Apple Developer Forums iş parçacıkları
— `/forums/thread/748621`, `/forums/thread/749049`, ikisi de Apple personeli
yanıtları alıntılıyor — + bağımsız bir uyum-özeti, singular.net/blog/
required-reason-apis) ÇAPRAZ DERLENDİ, 2026-08-16 erişimli. Üçü TUTARLI
çıktı ama **eksik/yanlış olabilir** — orkestratör birincil kaynağı ayrıca
doğrulayacağını söyledi, bu liste o doğrulamanın YERİNE geçmez.
"""
from __future__ import annotations

import plistlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARCHIVE = ROOT / "build" / "ios" / "archive" / "Runner.xcarchive"

REQUIRED_REASON_SYMBOLS = {
    "FileTimestamp": {
        "c": ["stat", "fstat", "fstatat", "lstat", "getattrlist",
              "getattrlistbulk", "fgetattrlist", "getattrlistat"],
        "swift": ["creationDate", "modificationDate", "fileModificationDate",
                  "contentModificationDateKey", "creationDateKey"],
    },
    "SystemBootTime": {
        "c": ["mach_absolute_time"],
        "swift": ["systemUptime"],
    },
    "DiskSpace": {
        # ⚠️ getattrlist/fgetattrlist/getattrlistat FileTimestamp'la ORTAK.
        "c": ["statfs", "statvfs", "fstatfs", "fstatvfs", "getattrlist",
              "fgetattrlist", "getattrlistat"],
        "swift": ["volumeAvailableCapacityKey",
                  "volumeAvailableCapacityForImportantUsageKey",
                  "volumeAvailableCapacityForOpportunisticUsageKey",
                  "volumeTotalCapacityKey", "systemFreeSize", "systemSize"],
    },
    "ActiveKeyboards": {
        "c": [],
        "swift": ["activeInputModes"],
    },
    "UserDefaults": {
        "c": [],
        "swift": ["NSUserDefaults", "UserDefaults"],
    },
}


def find_app_bundle() -> Path | None:
    apps = list((ARCHIVE / "Products" / "Applications").glob("*.app")) \
        if ARCHIVE.exists() else []
    return apps[0] if apps else None


def nm_undefined_symbols(binary: Path) -> set[str]:
    out = subprocess.run(["nm", "-u", str(binary)], capture_output=True,
                          text=True).stdout
    return {line.strip().lstrip("_") for line in out.splitlines() if line.strip()}


def find_binaries(app: Path) -> dict[str, Path]:
    """Gerçek pakette GÖNDERİLEN ikili dosyalar — ana yürütülebilir + HER
    embedded framework. `ios/Pods/`e bakmaz; yalnız `.app`in KENDİSİNE."""
    binaries = {}
    main_exe = app / app.stem
    if main_exe.exists() and main_exe.is_file():
        binaries[f"{app.stem} (ana yürütülebilir)"] = main_exe
    for fw in app.glob("Frameworks/*.framework"):
        exe = fw / fw.stem
        if exe.exists() and exe.is_file():
            binaries[fw.stem] = exe
    return binaries


def find_source_targets() -> dict[str, Path]:
    """Tamamlayıcı kaynak taraması — derlenmiş ikilinin (ölü-kod elemesi,
    inlining) gizleyebileceği çağrı yerlerini yakalamak için."""
    targets = {}
    for plugin in ("motion_camera", "permission_handler_apple"):
        link = ROOT / "ios" / ".symlinks" / "plugins" / plugin
        if link.exists():
            resolved = link.resolve()
            src = resolved / "ios" if (resolved / "ios").exists() else resolved
            if src.exists():
                targets[f"{plugin} (kaynak)"] = src
    runner = ROOT / "ios" / "Runner"
    if runner.exists():
        targets["Runner (kaynak)"] = runner
    return targets


def scan_binary(path: Path) -> dict[str, list[str]]:
    hits: dict[str, list[str]] = {c: [] for c in REQUIRED_REASON_SYMBOLS}
    undefined = nm_undefined_symbols(path)
    for category, syms in REQUIRED_REASON_SYMBOLS.items():
        for sym in syms["c"]:
            if sym in undefined:
                hits[category].append(sym)
    return hits


def scan_source(path: Path) -> dict[str, list[str]]:
    hits: dict[str, list[str]] = {c: [] for c in REQUIRED_REASON_SYMBOLS}
    files = [f for f in
             list(path.rglob("*.swift")) + list(path.rglob("*.m")) + list(path.rglob("*.h"))
             if "Package.swift" not in f.name]  # SPM derleme-zamanı betiği, uygulama kodu DEĞİL
    for category, syms in REQUIRED_REASON_SYMBOLS.items():
        for sym in syms["c"] + syms["swift"]:
            pattern = re.compile(r"\b" + re.escape(sym) + r"\b")
            for f in files:
                try:
                    text = f.read_text(encoding="utf-8", errors="ignore")
                except OSError:
                    continue
                if pattern.search(text):
                    hits[category].append(sym)
                    break
    return hits


def declared_categories(manifest_path: Path) -> set[str]:
    try:
        with manifest_path.open("rb") as fh:
            doc = plistlib.load(fh)
    except Exception:
        return set()
    return {
        entry.get("NSPrivacyAccessedAPIType", "").replace("NSPrivacyAccessedAPICategory", "")
        for entry in doc.get("NSPrivacyAccessedAPITypes", [])
        if entry.get("NSPrivacyAccessedAPIType")
    }


def main() -> int:
    # ── VAKUM KORUMASI (H-62) ────────────────────────────────────────────
    empty_categories = [c for c, v in REQUIRED_REASON_SYMBOLS.items()
                        if not v["c"] and not v["swift"]]
    if empty_categories:
        print(f"⛔ VAKUM: {empty_categories} kategorisinin sembol listesi BOŞ "
              f"— kapı KÖR (kusur yok DEMİYOR, arayacağı bir şey YOK).")
        return 1

    # ── ORTAM ÖN-KAPISI (run_all_gates.sh'ın deseniyle aynı: üçüncü hâl) ──
    app = find_app_bundle()
    if app is None:
        print("🟡 ORTAM KURULMAMIŞ — gerçek arşiv yok "
              f"({ARCHIVE} altında `.app` bulunamadı).")
        print("   Bu bir ÜRÜN kusuru DEĞİL; ölçüm henüz YAPILAMADI.")
        print("   Önce: flutter build ipa")
        return 2

    binaries = find_binaries(app)
    sources = find_source_targets()
    if not binaries:
        print(f"⛔ VAKUM: {app} içinde TARANACAK ikili dosya bulunamadı — kapı KÖR.")
        return 1

    manifests = {p.relative_to(app): p for p in app.rglob("*.xcprivacy")}
    if not manifests:
        print(f"⛔ VAKUM: {app} içinde HİÇBİR .xcprivacy bulunamadı (Runner'ın "
              f"kendisi bile) — kapı muhtemelen YANLIŞ dizini tarıyor, KÖR.")
        return 1

    declared_by: dict[str, set[str]] = {str(rel): declared_categories(p)
                                        for rel, p in manifests.items()}
    declared_anywhere: set[str] = set()
    for cats in declared_by.values():
        declared_anywhere |= cats

    used_by: dict[str, list[tuple[str, list[str]]]] = {c: [] for c in REQUIRED_REASON_SYMBOLS}
    for name, path in binaries.items():
        hits = scan_binary(path)
        for category, syms in hits.items():
            if syms:
                used_by[category].append((f"{name} [ikili]", syms))
    for name, path in sources.items():
        hits = scan_source(path)
        for category, syms in hits.items():
            if syms:
                used_by[category].append((f"{name} [kaynak]", syms))

    print("═══ GEREKÇELİ-API KAPSAMA KAPISI (gerçek arşiv) ═══\n")
    print(f"Taranan paket: {app}")
    print(f"Taranan ikili ({len(binaries)}): {', '.join(binaries)}")
    print(f"Taranan kaynak ({len(sources)}): {', '.join(sources)}")
    print(f"Bulunan manifest ({len(manifests)}): {', '.join(str(r) for r in manifests)}\n")

    problems = []
    for category in REQUIRED_REASON_SYMBOLS:
        uses = used_by[category]
        is_declared = category in declared_anywhere
        if not uses:
            print(f"  ⚪ {category}: kullanım YOK")
            continue
        who = "; ".join(f"{n} ({','.join(s)})" for n, s in uses)
        if is_declared:
            declarers = [r for r, c in declared_by.items() if category in c]
            print(f"  ✅ {category}: KULLANILIYOR ({who}) — BEYAN EDİLMİŞ ({', '.join(declarers)})")
        else:
            print(f"  🔴 {category}: KULLANILIYOR ({who}) — HİÇBİR manifestte BEYAN EDİLMEMİŞ")
            problems.append(category)

    print()
    if problems:
        print(f"⛔ {len(problems)} kategori kullanılıyor ama HİÇBİR YERDE beyan "
              f"edilmemiş: {problems}")
        print("   (Bu araç HANGİ gerekçe kodunun yazılacağını SÖYLEMEZ.)")
        return 1
    print("✅ Kullanılan HER kategori en az bir manifestte beyan edilmiş "
          "(gerçek arşivdeki TÜM manifestler toplamında).")
    print("\n⚠️ Bu kapı KATEGORİ-bazlı 'beyan var mı' sorusuna cevap verir; "
          "'kategori-bazlı mı çerçeve-bazlı mı toplanıyor' sorusu AÇIK "
          "(bu aracın docstring'inde adıyla).")
    print("⚠️ [kaynak] etiketli isabetler YORUM SATIRLARINI AYIRT ETMEZ "
          "(basit regex — motion_camera'da ölçüldü: tek isabet bir yorumdu, "
          "gerçek çağrı değil). [ikili] etiketli isabetler OTORİTEDİR "
          "(derlenmiş, gerçekten gönderilen kod); [kaynak] yalnız İNSAN "
          "GÖZÜYLE hızlı doğrulama için — belirtilen dosya/satırı oku.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
