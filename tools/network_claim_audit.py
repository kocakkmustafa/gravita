#!/usr/bin/env python3
""""Video bu cihazda kalır" iddiasının ÜÇ kanaldan denetimi (A3, O-080 şekli).

Ostinato'nun (motion-core ailesi) O-080 reçetesinden — YALNIZ BİÇİM alındı,
`NETWORK_DEPS_RECORDED` sözlüğü ve regex'ler Gravita'ya özel TÜRETİLDİ.

## Neden var (koordinatör bulgusu, 2026-08-11)

`live_strings.dart`/`library_strings.dart`/`progress_strings.dart`'ta "video
bu cihazda kalır, hiç çıkmaz" iddiası VAR ve BUGÜN doğru (ağ/telemetri paketi
0, `pubspec.yaml`'da doğrudan tek ağ-yetenekli bağımlılık yok) — ama HİÇBİR
kapı bunu enforce etmiyordu. *Korunmayan doğru iddia gelecekteki bir yalandır.*

## Üç kanal (hiçbiri diğerini geçersiz kılmaz)

1. **Kod izi** — Gravita'nın KENDİ `lib/`i doğrudan bir yükleme çağrısı
   (POST/PUT/WebSocket/multipart/ham `HttpClient`) taşıyor mu? İddia da
   varsa bu bir ÇELİŞKİ, kapı öter.
2. **Bağımlılık kaydı** — `pubspec.lock`taki (TRANSİTİF dahil, `pubspec.yaml`
   DEĞİL — `http` paketi tam olarak bu yüzden görünmezdi: doğrudan bağımlılık
   değil, `google_fonts`un TRANSİTİF vasıtası) HER ağa-çıkabilen paket
   `NETWORK_DEPS_RECORDED`de adıyla ve GEREKÇESİYLE kayıtlı olmalı. Kayıtsız
   biri belirirse kapı öter. ⛔ "ağa çıkan = kötü" YANLIŞ (O-057): kayıt bir
   muafiyet LİSTESİ değil, her satır "bu bağımlılık iddiayı NEDEN
   yalanlamıyor"un yazılı cevabıdır.
3. **Vakum koruması** — iddia HİÇBİR taranan yüzeyde bulunamıyorsa bu da
   KIRMIZI: ya iddia bilerek kaldırıldı (kapı da emekli edilmeli) ya tarama
   kırık. Sessiz "geçti" hiçbir zaman doğru değildir.

`--self-test`: her kanalı kasıtlı ihlalle ateşler.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
LOCK = ROOT / "pubspec.lock"

# ─────────────────────────────────────────────────────────────────────────
# YEREL SABİTLER (Gravita'ya özel — kopyalanmadı, türetildi)
# ─────────────────────────────────────────────────────────────────────────

# Kanal 3: iddianın KENDİSİ — gerçek sevk edilmiş metinden türetildi
# (lib/app/live_strings.dart:48, library_strings.dart:299,
# progress_strings.dart civarı). Üç ayrı ekranda üç ayrı cümle, ortak kök:
# "cihazda kalır / cihazdan çıkmaz".
CLAIM_PATTERN = re.compile(
    r"(never leaves (it|this device)|stored on this device only|"
    r"stays on (this|your) device)", re.I)

# Kanal 1: KOD İZİ — Gravita kendi `lib/`inde bir yükleme çağrısı taşıyor mu.
# Ham `dart:io` HttpClient de dahil (paket olmadan da yazılabilir).
UPLOAD_TRACE_PATTERN = re.compile(
    r"\bHttpClient\s*\(|\.postUrl\s*\(|\.putUrl\s*\(|"
    r"WebSocket\.connect\s*\(|MultipartRequest\s*\(|"
    r"\bhttp\.post\s*\(|\bhttp\.put\s*\(|\bDio\s*\(", re.I)

# Kanal 2: BAĞIMLILIK-AİLESİ İPUCU LİSTESİ — hangi paket ADLARI ağa-çıkma
# YETENEĞİ taşır (kullanmak zorunda değil, yeteneği var). Başlangıç noktası;
# `pubspec.lock`a karşı DOĞRULANIR, icat edilmez.
NETWORK_CAPABLE_HINTS = (
    "http", "dio", "cupertino_http", "cronet_http", "web_socket_channel",
    "socket_io_client", "grpc", "graphql", "firebase_core", "firebase_",
    "sentry", "amplitude", "mixpanel", "segment", "posthog", "supabase",
    "googleapis", "google_sign_in", "connectivity_plus",
)

#: KAYIT — Gravita'nın kendi manifestinden kurulan, adıyla+gerekçesiyle.
#: Muafiyet LİSTESİ değil: her satır "bu bağımlılık iddiayı NEDEN
#: yalanlamıyor"un yazılı cevabı (koordinatör ölçütü, 2026-08-11).
NETWORK_DEPS_RECORDED = {
    "google_fonts": (
        "Public Sans/Roboto Mono asset olarak PAKETLENMEDİ; ilk "
        "render'da yazı tipi cihazda yoksa fonts.gstatic.com'dan GET ile "
        "çeker. Bu bir TİPOGRAFİ varlığı isteğidir — kamera karesi, poz "
        "landmark'ı, seans/tekrar verisi TAŞIMAZ. İddia 'video bu cihazda "
        "kalır' der, 'uygulama hiç ağa çıkmaz' DEMEZ; ikisi FARKLI iddia. "
        "Test'te `flutter_test_config.dart`in `_NoNetwork` HttpOverrides'ı "
        "bu isteği zaten öldürüyor (indirilemezse sistem fontuna düşer)."
    ),
    "http": (
        "DOĞRUDAN bağımlılık DEĞİL — `google_fonts`un TRANSİTİF vasıtası "
        "(pubspec.lock'ta var, pubspec.yaml'da YOK; ölçüldü: `lib/` "
        "içinde `package:http` hiç import edilmiyor, yalnız google_fonts "
        "kullanıyor). Kayıt google_fonts satırına atıflı, ayrı bir "
        "kullanım yok."
    ),
    "http_parser": (
        "`http`in TRANSİTİF vasıtası — kendisi ağa ÇIKMAZ, yalnız "
        "medya-tipi/başlık METNİNİ ayrıştırır (saf parsing kütüphanesi, "
        "I/O yok). İsim eşleşmesi (`http` öneki) bu taramanın ipucu "
        "listesini tetikledi; kayıt bu YANLIŞ-POZİTİFİ SUSTURMAK için "
        "değil, neden zararsız olduğunu YAZILI bırakmak için var."
    ),
}


def sh(*args):
    return subprocess.run(args, cwd=ROOT, capture_output=True,
                           text=True, check=False)


def channel_code_trace():
    """Kanal 1: `lib/` KENDİ kodu bir yükleme çağrısı taşıyor mu."""
    hits = []
    for f in LIB.rglob("*.dart"):
        text = f.read_text(encoding="utf-8", errors="replace")
        for m in UPLOAD_TRACE_PATTERN.finditer(text):
            line_no = text.count("\n", 0, m.start()) + 1
            hits.append(f"{f.relative_to(ROOT)}:{line_no}: {m.group(0)!r}")
    return hits


def _lockfile_packages():
    """`pubspec.lock`taki TÜM paketler (transitif dahil) — yaml'sız oku
    (üçüncü-taraf bağımlılık icat etmemek için el yordamıyla ayrıştırılır:
    dosya YAML ama biçimi sabit, `name: X` satırları güvenilir)."""
    text = LOCK.read_text(encoding="utf-8")
    names = []
    in_packages = False
    for line in text.splitlines():
        if line.startswith("packages:"):
            in_packages = True
            continue
        if not in_packages:
            continue
        m = re.match(r"^  (\S+):$", line)
        if m:
            names.append(m.group(1))
    return names


def channel_dependency_registry():
    """Kanal 2: ağa-çıkabilen HER paket kayıtlı mı."""
    if not LOCK.exists():
        return (["pubspec.lock YOK — `flutter pub get` çalıştırılmamış, "
                  "bağımlılık ağacı DOĞRULANAMIYOR"], [])
    packages = _lockfile_packages()
    suspects = [
        p for p in packages
        if any(p == hint or p.startswith(hint) for hint in NETWORK_CAPABLE_HINTS)
    ]
    unrecorded = [p for p in suspects if p not in NETWORK_DEPS_RECORDED]
    stale = [p for p in NETWORK_DEPS_RECORDED if p not in packages]
    violations = []
    if unrecorded:
        violations.append(
            f"KAYITSIZ ağa-çıkabilen bağımlılık: {unrecorded} — "
            f"NETWORK_DEPS_RECORDED'a adıyla+gerekçesiyle eklenmeli")
    if stale:
        violations.append(
            f"BAYAT KAYIT: {stale} artık pubspec.lock'ta YOK — "
            f"NETWORK_DEPS_RECORDED'dan silinmeli")
    return violations, suspects


def channel_vacuum(claim_hits):
    """Kanal 3: iddia HİÇBİR yüzeyde bulunamıyorsa bu da kırmızı."""
    if not claim_hits:
        return [
            "VAKUM: 'cihazda kalır' iddiası taranan hiçbir yüzeyde "
            "BULUNAMADI — ya iddia kaldırıldı (bu kapı EMEKLİ edilmeli) "
            "ya CLAIM_PATTERN kırık (regex sevk edilen metne artık uymuyor)"
        ]
    return []


def find_claims():
    hits = []
    for f in LIB.rglob("*.dart"):
        text = f.read_text(encoding="utf-8", errors="replace")
        for m in CLAIM_PATTERN.finditer(text):
            line_no = text.count("\n", 0, m.start()) + 1
            hits.append(f"{f.relative_to(ROOT)}:{line_no}")
    return hits


def run():
    claim_hits = find_claims()
    trace_hits = channel_code_trace()
    dep_violations, suspects = channel_dependency_registry()
    vacuum_violations = channel_vacuum(claim_hits)

    violations = []
    if claim_hits and trace_hits:
        violations.append(
            f"ÇELİŞKİ: 'cihazda kalır' iddiası VAR ({len(claim_hits)} yer) "
            f"AMA kod izinde yükleme çağrısı da VAR: {trace_hits}")
    violations += dep_violations
    violations += vacuum_violations
    return violations, claim_hits, trace_hits, suspects


def main():
    if "--self-test" in sys.argv:
        return _self_test()

    violations, claim_hits, trace_hits, suspects = run()
    if violations:
        print(f"⛔ {len(violations)} İHLAL:")
        for v in violations:
            print(f"   - {v}")
        return 1
    print(
        f"✅ ağ-iddiası TEMİZ — iddia {len(claim_hits)} yüzeyde bulundu · "
        f"kod izinde yükleme çağrısı 0 · ağa-çıkabilen {len(suspects)} "
        f"bağımlılık ({', '.join(sorted(suspects))}) hepsi kayıtlı+gerekçeli")
    return 0


def _self_test():
    print("kapı ateşleme sınaması (kasıtlı ihlaller):")
    ok = True
    fired = 0

    violations, claim_hits, trace_hits, suspects = run()
    if violations:
        print(f"   ⛔ TABAN KİRLİ — mutasyonsuz ağaç ihlal veriyor: {violations}")
        return 1
    print("   ✅ taban temiz (mutasyonsuz ağaç ihlalsiz)")

    # Kanal 1: GERÇEK bir yükleme izi geçici dosyaya yazılıp taranıyor —
    # regex'in KENDİSİ sınanıyor, "if claim_hits and trace_hits" mantığı
    # değil (o zaten trivial bir `and`, ayrı sınamaya değmez).
    probe = LIB / "__network_audit_selftest_probe__.dart"
    probe.write_text("final c = HttpClient();\n", encoding="utf-8")
    try:
        hit = any("__network_audit_selftest_probe__" in h
                  for h in channel_code_trace())
        print(f"   {'✅' if hit else '⛔'} Kanal-1 kod izi regex'i: "
              f"{'yakalandı' if hit else 'YAKALANMADI — SAHTE KAPI'}")
        ok = ok and hit
        fired += 1
    finally:
        probe.unlink(missing_ok=True)

    # Kanal 2: sahte bir "kayıtsız ağa-çıkan paket" senaryosu — gerçek
    # sözlükten GEÇİCİ olarak bir girdiyi çıkarıp aynı denetimi tekrar çalıştır.
    # ⚠️ `google_fonts` DEĞİL: hint-listesi onu isim eşleşmesiyle YAKALAMAZ
    # (adı ağ ipucusu taşımıyor — bu yüzden `http`in kendisi tescilli).
    # `http`i çıkarmak ÇEKİRDEK varsayımı sınar: gerçekten suspects'te mi.
    _, suspects_before = channel_dependency_registry()
    if "http" not in suspects_before:
        print("   ⛔ Kanal-2 fikstürü YANLIŞ varsayım yapıyor — "
              "'http' artık suspects'te değil, testi güncelle")
        ok = False
        fired += 1
    else:
        saved = NETWORK_DEPS_RECORDED.pop("http")
        try:
            dep_violations, _ = channel_dependency_registry()
            hit = any("KAYITSIZ" in v for v in dep_violations)
            print(f"   {'✅' if hit else '⛔'} Kanal-2 kayıtsız bağımlılık: "
                  f"{'yakalandı' if hit else 'YAKALANMADI — SAHTE KAPI'}")
            ok = ok and hit
            fired += 1
        finally:
            NETWORK_DEPS_RECORDED["http"] = saved

    # Kanal 2b: BAYAT kayıt — sözlüğe olmayan bir paket ekle.
    NETWORK_DEPS_RECORDED["olmayan_paket_xyz"] = "test"
    try:
        dep_violations, _ = channel_dependency_registry()
        hit = any("BAYAT KAYIT" in v for v in dep_violations)
        print(f"   {'✅' if hit else '⛔'} Kanal-2 bayat kayıt: "
              f"{'yakalandı' if hit else 'YAKALANMADI — SAHTE KAPI'}")
        ok = ok and hit
        fired += 1
    finally:
        del NETWORK_DEPS_RECORDED["olmayan_paket_xyz"]

    # Kanal 3: VAKUM — sahte (boş) claim listesiyle çağır.
    vacuum_violations = channel_vacuum([])
    hit = any("VAKUM" in v for v in vacuum_violations)
    print(f"   {'✅' if hit else '⛔'} Kanal-3 vakum koruması: "
          f"{'yakalandı' if hit else 'YAKALANMADI — SAHTE KAPI'}")
    ok = ok and hit
    fired += 1

    print(f"✅ {fired}/{fired} kapı ateşlendi" if ok
          else "⛔ bazı kapılar ateşlenmedi")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
