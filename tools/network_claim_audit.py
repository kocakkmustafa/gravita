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
#: ⛔ BÖLME (JabLab'ın deseni, Lissom'dan uyarlanmış — İCAT DEĞİL, aktarım).
#:
#: ## Neden ipucu listesi YETMİYOR — ÖLÇÜLDÜ (G-188, 2026-08-12)
#:
#: Eski biçim bir İZİN-LİSTESİYDİ: `NETWORK_CAPABLE_HINTS` ile eşleşen paket
#: "şüpheli" sayılır, kalanı hiç sorulmazdı. Kapsam ölçüldü: **63 paketin
#: 2'si** şüpheli bulunuyordu — **%96'sı hiç sınıflandırılmıyordu.** Ve
#: kusur teorik değildi: `google_fonts` kayıtta VARDI ama ipuçlarıyla
#: EŞLEŞMİYORDU (`googleapis`/`google_sign_in` var, `google_fonts` yok) →
#: yani kaydı ZORLANMIYORDU. Biri o satırı silseydi kapı hiç ötmezdi.
#:
#: > Ostinato'nun ölçtüğü zayıf biçimin aynısı: tam-eşleşmeli ret-listesi
#: > 65 paketin 63'ünü görmüyordu.
#:
#: Yeni biçim BÖLME: `pubspec.lock`taki HER paket ya `NETWORK_DEPS_RECORDED`
#: (ağa çıkabilir — adıyla+gerekçesiyle) ya da `NO_NETWORK` kümesinde olmak
#: ZORUNDA. Sınıflanmamış paket = KIRMIZI. Yeni bir bağımlılık eklendiği gün
#: kapı öter ve biri onu sınıflar — liste bakımı yerine **bakımı ZORLAYAN
#: arıza** (aynı desen `tools/metric_support.py`de de kullanıldı).
#:
#: ⚠️ Bu küme bir MUAFİYET listesi DEĞİL: "ağ yapmaz" bir iddiadır ve
#: yanlışsa buraya yazılmış olması onu doğru yapmaz. Kümedeki bir paket ağ
#: yapmaya başlarsa bu dosya YALAN söyler — o yüzden yeni paket eklerken
#: bucket seçimi bir KARARDIR, bir formalite değil.
NO_NETWORK = frozenset({
    "args", "async", "boolean_selector", "characters",
    "clock", "code_assets", "collection", "crypto",
    "fake_async", "ffi", "flutter", "flutter_test",
    "flutter_web_plugins", "gravita_engine", "hooks", "jni",
    "jni_flutter", "jni_util", "leak_tracker", "leak_tracker_flutter_testing",
    "leak_tracker_testing", "lints", "logging", "matcher",
    "material_color_utilities", "meta", "motion_camera", "motion_core",
    "objective_c", "package_config", "path", "path_provider",
    "path_provider_android", "path_provider_foundation", "path_provider_linux", "path_provider_platform_interface",
    "path_provider_windows", "permission_handler", "permission_handler_android", "permission_handler_apple",
    "permission_handler_html", "permission_handler_platform_interface", "permission_handler_windows", "platform",
    "plugin_platform_interface", "pub_semver", "record_use", "sky_engine",
    "source_span", "stack_trace", "stream_channel", "string_scanner",
    "term_glyph", "test_api", "typed_data", "vector_math",
    "vm_service", "web", "xdg_directories", "yaml",
})

#: KAYIT — Gravita'nın kendi manifestinden kurulan, adıyla+gerekçesiyle.
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
    # BÖLME: her paket iki kovadan BİRİNDE olmak zorunda.
    unclassified = [p for p in packages
                    if p not in NETWORK_DEPS_RECORDED and p not in NO_NETWORK]
    ghost = [p for p in NO_NETWORK if p not in packages]
    unrecorded = [p for p in suspects if p not in NETWORK_DEPS_RECORDED]
    stale = [p for p in NETWORK_DEPS_RECORDED if p not in packages]
    violations = []
    if unclassified:
        violations.append(
            f"SINIFLANDIRILMAMIŞ {len(unclassified)} paket: {unclassified} — "
            f"her paket ya NETWORK_DEPS_RECORDED'a (gerekçesiyle) ya "
            f"NO_NETWORK'e girmeli; bölme EKSİK kalamaz")
    if ghost:
        violations.append(
            f"HAYALET KAYIT: {ghost} NO_NETWORK'te ama pubspec.lock'ta YOK — "
            f"bölme bayatladı")
    if unrecorded:
        violations.append(
            f"KAYITSIZ ağa-çıkabilen bağımlılık: {unrecorded} — "
            f"NETWORK_DEPS_RECORDED'a adıyla+gerekçesiyle eklenmeli")
    if stale:
        violations.append(
            f"BAYAT KAYIT: {stale} artık pubspec.lock'ta YOK — "
            f"NETWORK_DEPS_RECORDED'dan silinmeli")
    return violations, suspects



#: ⭐ FONT TESLİMİ — ölçülen HÂL, beyan edilen hâlle karşılaştırılır (G-188).
#:
#: Kusurun şekli, bu vardiyanın ana temasının en temiz örneği: fontlar
#: paketlenmediği için `google_fonts` yüzleri ÇALIŞMA ANINDA
#: `fonts.gstatic.com`tan çekiyor — ve bunu **hiçbir test göremiyor**, çünkü
#: `allowRuntimeFetching` yalnız TEST yapılandırmasında konuşuluyor
#: (`test/flutter_test_config.dart`, üstelik bir YORUMDA). Testler ağsız
#: geçsin diye kurulan iyi niyetli düzenek, davranışı görünmez kıldı.
#:
#:   > Kendi kodunda ağ olmaması, ÜRÜNÜNDE ağ olmaması demek değildir.
#:
#: ⛔ Bu kanal DAVRANIŞI DEĞİŞTİRMEZ (font paketlemek ya da üretimde
#: `allowRuntimeFetching`i kapatmak bir ÜRÜN DURUŞU kararıdır ve kurucudadır)
#: — yalnız hâli ÖLÇER ve beyanla karşılaştırır. İki yönde de öter: fontlar
#: bir gün paketlenirse bu beyan BAYAT olur ve kapı onu söyler.
FONT_DELIVERY_RECORDED = "runtime-fetch"


def channel_font_delivery():
    """Kanal 4: font yüzleri PAKETLİ mi, yoksa çalışma anında mı çekiliyor."""
    uses = [f"{f.relative_to(ROOT)}" for f in LIB.rglob("*.dart")
            if "GoogleFonts." in f.read_text(encoding="utf-8", errors="replace")]
    pubspec = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    bundled = bool(re.search(r"^\s*fonts:\s*$", pubspec, re.M)) or bool(
        list(ROOT.glob("assets/**/*.ttf")) + list(ROOT.glob("assets/**/*.otf")))
    actual = "runtime-fetch" if (uses and not bundled) else (
        "bundled" if bundled else "unused")
    if actual != FONT_DELIVERY_RECORDED:
        return ([f"FONT TESLİMİ beyanla UYUŞMUYOR: ölçülen '{actual}', "
                 f"beyan '{FONT_DELIVERY_RECORDED}' — beyan bayatladı ya da "
                 f"davranış sessizce değişti"], uses)
    return ([], uses)


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
    font_violations, font_uses = channel_font_delivery()

    violations = []
    if claim_hits and trace_hits:
        violations.append(
            f"ÇELİŞKİ: 'cihazda kalır' iddiası VAR ({len(claim_hits)} yer) "
            f"AMA kod izinde yükleme çağrısı da VAR: {trace_hits}")
    violations += dep_violations
    violations += vacuum_violations
    violations += font_violations
    return violations, claim_hits, trace_hits, suspects, font_uses


def main():
    if "--self-test" in sys.argv:
        return _self_test()

    violations, claim_hits, trace_hits, suspects, font_uses = run()
    if violations:
        print(f"⛔ {len(violations)} İHLAL:")
        for v in violations:
            print(f"   - {v}")
        return 1
    # ⚠️ ÖZET, KAPSAMI YAZAR. Eski satır yalnız "ağa-çıkabilen 2 bağımlılık"
    # diyordu ve okuyan "63 paket denetlendi, 2'si ağ yapıyor" sanıyordu;
    # gerçekte 61 paket HİÇ SORULMAMIŞTI. Bir özetin sayısı, o sayının
    # KAÇTA KAÇ üstünden çıktığını söylemiyorsa bir güven yanılsaması üretir.
    total = len(_lockfile_packages())
    net = sorted(NETWORK_DEPS_RECORDED)
    print(
        f"✅ ağ-iddiası TEMİZ — iddia {len(claim_hits)} yüzeyde bulundu · "
        f"kod izinde yükleme çağrısı 0 · BÖLME {total}/{total} paket "
        f"sınıflandırılmış: ağa-çıkabilen {len(net)} ({', '.join(net)}) "
        f"adıyla+gerekçesiyle kayıtlı, kalan {total - len(net)} ağ yapmaz")
    # ⚠️ Bu satır bir UYARI değil bir ÖLÇÜM: ürün font yüzlerini çalışma
    # anında çekiyor ve bu artık SESSİZ değil. Duruş kararı kurucuda.
    print(f"   ℹ️ font teslimi: {FONT_DELIVERY_RECORDED} — yüzler paketli "
          f"DEĞİL, çalışma anında indiriliyor ({len(font_uses)} dosya "
          f"`GoogleFonts.` çağırıyor). Ürün duruşu kararı KURUCUDA.")
    return 0


def _self_test():
    print("kapı ateşleme sınaması (kasıtlı ihlaller):")
    ok = True
    fired = 0

    violations, claim_hits, trace_hits, suspects, _fonts = run()
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

    # Kanal 2c: BÖLME EKSİKLİĞİ — bir paketi iki kovadan da çıkar.
    # ⚠️ Bu ikiz olmadan bölme "63/63" der ve HİÇBİR ŞEY ölçmemiş olurdu:
    # koşulsuz doğru bir kapı, kapı değildir.
    global NO_NETWORK
    victim = next(iter(NO_NETWORK))
    saved_set = NO_NETWORK
    NO_NETWORK = frozenset(x for x in NO_NETWORK if x != victim)
    try:
        dep_violations, _ = channel_dependency_registry()
        hit = any("SINIFLANDIRILMAMIŞ" in v for v in dep_violations)
        print(f"   {'✅' if hit else '⛔'} Kanal-2c bölme eksikliği: "
              f"{'yakalandı' if hit else 'YAKALANMADI — SAHTE KAPI'}")
        ok = ok and hit
        fired += 1
    finally:
        NO_NETWORK = saved_set

    # Kanal 4: FONT TESLİMİ beyanı — beyanı bozup ölçümün çeliştiğini gör.
    global FONT_DELIVERY_RECORDED
    saved_font = FONT_DELIVERY_RECORDED
    FONT_DELIVERY_RECORDED = "bundled"
    try:
        font_violations, _ = channel_font_delivery()
        hit = any("UYUŞMUYOR" in v for v in font_violations)
        print(f"   {'✅' if hit else '⛔'} Kanal-4 font teslimi beyanı: "
              f"{'yakalandı' if hit else 'YAKALANMADI — SAHTE KAPI'}")
        ok = ok and hit
        fired += 1
    finally:
        FONT_DELIVERY_RECORDED = saved_font

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
