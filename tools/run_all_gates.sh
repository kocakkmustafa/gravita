#!/usr/bin/env bash
# TÜM kapılar — tek komut, tek özet, KAPSAMI YAZILI.
#
# ## Neden bu betik var (J-145 aktarımı, 2026-08-07)
#
# JabLab kırk kez *"N/N yeşil"* bildirmiş; o **app süitiydi** ve **motor
# süiti başka bir bulgudan beri KIRMIZIYDI.** Üç gerçek kusur o kırmızının
# altında saklandı.
#
#   > Bir kapının yeşili, o kapının KAPSADIĞI kadar geçerlidir.
#   > İki süitli bir depoda "testler yeşil" cümlesi EKSİK bir cümledir.
#
# Bu depoda **ÜÇ** koşum var (app · motor · içerik kapıları) ve bu betik
# üçünü de koşturur. Elle koşturulan bir alt küme, bir daha "yeşil"
# denmesine yetmesin.
#
# ## KAPSAM — bu betiğin ÖLÇMEDİĞİ şeyler (bilerek)
#
# `tools/` altındaki 10 dosya BURADA KOŞMAZ ve bu bir karardır, unutma değil:
# `a5_anatomical_probe` · `anatomical_copying_signature` · `harvest_queue` ·
# `hip_knee_coupling_canonical` · `mirror_vs_foreshortening` ·
# `mode_naming_probe` · `reclassify_eligibility` · `sync_provenance` ·
# `hip_knee_coupling_per_rep` · `build_replay_fixture` (H-23 denetimi,
# 2026-08-16 — bu ikisi listede YOKTU, unutulmuştu; ikisi de aynı ölçütü
# karşılıyor, adıyla eklendi).
# Ölçüldü: hiçbirinde `--check` ya da `--self-test` yok; üçü zorunlu
# argüman istiyor. Bunlar HASAT/ANALİZ araçlarıdır — bir durumu denetlemez,
# bir çıktı üretirler. Kapı gibi koşturmak, koştuğu için doğru sanılan bir
# şey üretirdi.
#
# Ayrıca ÖLÇMEZ: cihaz davranışı (sim'de kamera yok) · biçim/konum
# karışıklığı (ΔE renk uzaklığı ölçer, YERLEŞİM değil) · `validate_catalog`ın 7 kanıtsız
# değişmezi (betiğin kendi çıktısı onları her koşumda basar).
#
# `validate_privacy_manifest_coverage` da BURADA KOŞMAZ (2026-08-16, G-252'de
# aile katmanına taşındı: `motion-core/workspace/tools/validate_privacy_
# manifest_coverage.py gravita`) — GERÇEK bir `flutter build ipa` arşivi ister
# (dakikalar sürer, bu betiğin hızlı-kapı amacına aykırı). Ortam yoksa kendi
# "ORTAM KURULMAMIŞ" hâlini (exit 2) döner, ama bu SÜİTE bağlanmadı — release
# provası sonrası elle koşulur.
set -uo pipefail
cd "$(dirname "$0")/.."

line() { printf '%s\n' "────────────────────────────────────────────"; }

# ── ORTAM ÖN-KAPISI: build/ hedefi kurulu mu? ───────────────────────────
# "yok" burada NE yeşil NE kırmızıdır — ÜÇÜNCÜ HÂLDİR (Choreia hükmü,
# M-F-444): sessiz atlama da opak `flutter` tool-crash'i de yasak. Bu
# kapı olmadan SÜİT 1 `PathNotFoundException` ile OPAK çöker (G-125) ve
# kırmızı bir ÜRÜN kusuru sanılır — oysa eksik olan tek şey kurulum.
if [ -L build ]; then
  target="$(readlink build)"
  if [ ! -d "$target" ]; then
    line
    echo "🟡 ORTAM KURULMAMIŞ — build/ sembolik linkinin hedefi yok: $target"
    echo "   Bu bir ÜRÜN kusuru değil; kurulum adımı atlanmış."
    echo "   Kurulum: ./tools/setup_build_dir.sh"
    line
    exit 2
  fi
elif [ ! -e build ]; then
  line
  echo "🟡 ORTAM KURULMAMIŞ — build/ hiç yok (symlink bile kurulmamış)."
  echo "   Kurulum: ./tools/setup_build_dir.sh"
  line
  exit 2
fi

fail=0
# Süit sayaçları — HER BİRİ AYRI. Tek toplam sayı, ikinci bir süitin
# kırmızısını gizleyebilir; bu betiğin varlık sebebi tam olarak o gizlenme.
app_n="?"; eng_n="?"; py_ok=0; py_total=0

# ⚠️ RAPOR KATMANI DÜZELTİLDİ (G-190, koordinatör ölçümü 2026-08-12).
#
# Eski gövde `2>&1` ile stderr'i stdout'a KATIYOR ve ✅ satırının yanına
# birleşik çıktının SON SATIRINI basıyordu. Araç sonucunu stdout'a basıp
# ardından stderr'e bir uyarı düşürürse (flutter'ın "Waiting for another
# flutter command to release the startup lock…" satırı gibi) özet, sonucu
# değil O GÜRÜLTÜYÜ gösteriyordu. Deterministik olarak yeniden üretildi.
#
# ⛔ HÜKÜM DEĞİŞMEDİ ve değişmemeli: yeşil/kırmızı kararı ÇIKIŞ KODUNDAN
# geliyor, yani kapı yanlış geçirmiyordu. Kusur yalnız GÖSTERİLEN satırdaydı.
#
#   > Doğru olan bir şeyin, yanlış bir şey TAŞIMASI.
#
# Panzehir: iki akım AYRI okunur. Özet stdout'un anlamlı son satırıdır;
# stdout sessizse stderr'e düşülür ama ETİKETLENİR — gürültüyü sonuç gibi
# sunmak, bu düzeltmenin kapattığı kusurun ta kendisidir.
run() {                       # run <ad> <komut...>
  local name="$1"; shift
  local out err rc summary
  err="$(mktemp)"
  out="$("$@" 2>"$err")" && rc=0 || rc=$?

  summary="$(printf '%s' "$out" | grep -v '^[[:space:]]*$' | tail -1)"
  if [ -z "$summary" ]; then
    summary="(stdout sessiz) $(grep -v '^[[:space:]]*$' "$err" | tail -1)"
  fi
  if [ "$rc" -ne 0 ]; then
    # Kırmızıda SEBEP çoğu araçta stderr'dedir; varsa o gösterilir.
    local ederr
    ederr="$(grep -v '^[[:space:]]*$' "$err" | tail -1)"
    [ -n "$ederr" ] && summary="$ederr"
  fi
  rm -f "$err"

  if [ "$rc" -eq 0 ]; then
    printf '  ✅ %-34s %s\n' "$name" "$(printf '%s' "$summary" | cut -c1-58)"
    return 0
  fi
  printf '  ❌ %-34s %s\n' "$name" "$(printf '%s' "$summary" | cut -c1-58)"
  fail=1
  return 1
}

# Dart süitlerinin GEÇEN TEST SAYISINI çıkarır ("00:06 +127: All tests…").
# ⚠️ AYNI KUSUR BURADA DA VARDI ve gösterilen bir SAYI üretiyor: stderr
# birleştirilince son satır bir uyarı olabiliyor, sayı deseni tutmuyor ve
# "app /" gibi BOŞ bir sayı basılıyordu. stdout AYRI okunuyor; ayrıca son
# satır değil, sayı deseni TUTAN son satır aranıyor (araçlar sonuç satırından
# sonra özet/uyarı basabilir).
count_dart() {
  local out
  out="$("$@" 2>/dev/null)" || { printf 'KIRMIZI'; return 1; }
  printf '%s' "$out" | grep -oE '\+[0-9]+' | tail -1 | tr -d '+'
}

line; echo "SÜİT 1 — app kabuğu ($(ls test/*.dart | wc -l | tr -d ' ') dosya)"; line
app_n="$(count_dart flutter test)" || fail=1
run "flutter test" flutter test

line; echo "SÜİT 2 — gravita_engine ($(ls packages/gravita_engine/test/*.dart | wc -l | tr -d ' ') dosya)"; line
eng_n="$(count_dart bash -c "cd packages/gravita_engine && dart test")" || fail=1
run "dart test" bash -c "cd packages/gravita_engine && dart test"

# ⚠️ H-23 denetimi (2026-08-16) bu satırın KENDİSİNİ bayat buldu: "8 araç"
# 2026-08-13'ten kalmaydı, depo o zamandan beri büyüdü — gerçek sayı 11
# (aşağıdaki `gate` çağrılarının sardığı DİSTİNCT .py dosyası; --check/
# --self-test varyantları ayrı araç sayılmaz). Bu betiğin kendi başlığı,
# denetlediği tam sınıfın (bayat sayı iddiası) canlı bir örneğiydi.
line; echo "SÜİT 3 — içerik kapıları (14 araç)"; line
gate() { py_total=$((py_total+1)); if run "$@"; then py_ok=$((py_ok+1)); fi; }
gate "calisthenics_course --check"  python3 tool/generate_calisthenics_course.py --check
gate "reference_model"             python3 tools/validate_reference_model.py
gate "reference_model --self-test" python3 tools/validate_reference_model.py --self-test
gate "validate_library"            python3 tools/validate_library.py
gate "validate_library --self-test" python3 tools/validate_library.py --self-test
gate "validate_catalog"            python3 tools/validate_catalog.py
gate "validate_catalog --self-test" python3 tools/validate_catalog.py --self-test
gate "promote_library --check"     python3 tools/promote_library.py --check
gate "exclusions_page --check"     python3 tools/build_exclusions_page.py --check
gate "skill_tree_index --check"    python3 tools/build_skill_tree_index.py --check
gate "name_preconditions --check"  python3 tools/name_preconditions.py --check
gate "network_claim_audit"         python3 tools/network_claim_audit.py
gate "network_claim_audit --self-test" python3 tools/network_claim_audit.py --self-test
# ⚠️ `metric_support` BURAYA GİRİYOR çünkü ÖZ-TESTİ VAR — yukarıdaki kapsam
# şerhinin ölçütü tam olarak bu ("hiçbirinde --check ya da --self-test yok").
# Öz-testi üç katmanlı: ARAÇ · DİZGE · KAPSAM (üçüncüsü olmadan `burpee`
# yanlış-pozitif vermişti ve ilk iki katman GEÇMİŞTİ).
gate "metric_support --self-test" python3 tools/metric_support.py --self-test
# ⚠️ `dead_end_census` A4'ün İÇERİK yarısını sayar (payda + boşluk sınıfı
# dağılımı). Yürüyüş yarısı Dart'ta: `test/startable_reach_test.dart` —
# ikisi AYRI soru sorar ve bilerek ayrı evlerde durur.
# ⛔ Bu kapı blokerleri DOĞRULAMAZ (o `validate_library` K9'un işi);
# yalnız SINIFLANDIRIR — kapının kapısını denetleyen kapı kurulmaz.
gate "dead_end_census"            python3 tools/dead_end_census.py
# ⭐ G-216 (koordinatör H-17): dağılım artık ARTEFAKTA yazılı ve bu kapı onu
# canlı ölçümle karşılaştırıyor. Rapor basmak yetmezdi — stdout'a basılan bir
# sayı, kimse okumazsa ölçülmemiş sayılır; ayrışırsa da kimse görmez.
gate "dead_end_census --check"    python3 tools/dead_end_census.py --check
gate "dead_end_census --self-test" python3 tools/dead_end_census.py --self-test
# ✅ DEFTER 2026-08-15'ten beri depo İÇİNDE (`workspace/`) — bu kapı deponun kendi içeriğini
# değil, deponun HAFIZAYLA UYUMUNU ölçüyor. Bugün ölçüldü ki beş hattın
# hiçbirinde böyle bir kapı yoktu ve iki hatta 59 kayıt kaybı vardı.
gate "defter_freshness"             python3 tools/defter_freshness.py
gate "defter_freshness --self-test" python3 tools/defter_freshness.py --self-test
# ⭐ H-58 (orkestratör, 2026-08-16): $-önekli bir "bu sayı bayatlayabilir"
# notunun SIFIR okuyucusu vardı — yazmak koruma değildi. Bu kapı
# docs/store/listing.json + STORE-LISTING-TASLAK.md'deki hareket sayılarını
# content/library.json'ın GERÇEK sayımına karşı sınar.
gate "validate_store_listing"            python3 tools/validate_store_listing.py
gate "validate_store_listing --self-test" python3 tools/validate_store_listing.py --self-test
# ⭐ GRA-P0-003: release imzası sessiz-düşüş kapısı (aile emsali: Lissom/
# Ostinato — burada Gravita'nın GERÇEK, farklı gradle yapısına göre yazıldı).
gate "validate_release_signing"            python3 tools/validate_release_signing.py
gate "validate_release_signing --self-test" python3 tools/validate_release_signing.py --self-test

line
if [ "$fail" -eq 0 ]; then
  echo "✅ ÜÇ SÜİTİN ÜÇÜ DE YEŞİL"
  echo "   app ${app_n}/${app_n} · engine ${eng_n}/${eng_n} · python ${py_ok}/${py_total}"
  echo "   ⚠️ Kapsam dışı (bilerek): 10 hasat aracı · cihaz davranışı ·"
  echo "      biçim/konum karışıklığı · validate_catalog'un 7 kanıtsız değişmezi"
else
  echo "❌ EN AZ BİR SÜİT KIRMIZI"
  echo "   app ${app_n} · engine ${eng_n} · python ${py_ok}/${py_total}"
  echo "   ⚠️ Tek toplam sayıya BAKMA — yukarıdaki ❌ satırı hangi süit olduğunu söyler."
fi
line
exit "$fail"
