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
# `tools/` altındaki 8 dosya BURADA KOŞMAZ ve bu bir karardır, unutma değil:
# `a5_anatomical_probe` · `anatomical_copying_signature` · `harvest_queue` ·
# `hip_knee_coupling_canonical` · `mirror_vs_foreshortening` ·
# `mode_naming_probe` · `reclassify_eligibility` · `sync_provenance`.
# Ölçüldü: hiçbirinde `--check` ya da `--self-test` yok; ikisi zorunlu
# argüman istiyor. Bunlar HASAT/ANALİZ araçlarıdır — bir durumu denetlemez,
# bir çıktı üretirler. Kapı gibi koşturmak, koştuğu için doğru sanılan bir
# şey üretirdi.
#
# Ayrıca ÖLÇMEZ: cihaz davranışı (sim'de kamera yok) · biçim/konum
# karışıklığı (ΔE renk uzaklığı ölçer, YERLEŞİM değil) · `validate_catalog`ın 7 kanıtsız
# değişmezi (betiğin kendi çıktısı onları her koşumda basar).
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

run() {                       # run <ad> <komut...>
  local name="$1"; shift
  local out
  if out="$("$@" 2>&1)"; then
    printf '  ✅ %-34s %s\n' "$name" "$(printf '%s' "$out" | tail -1 | cut -c1-58)"
    return 0
  else
    printf '  ❌ %-34s %s\n' "$name" "$(printf '%s' "$out" | tail -1 | cut -c1-58)"
    fail=1
    return 1
  fi
}

# Dart süitlerinin GEÇEN TEST SAYISINI çıkarır ("00:06 +127: All tests…").
count_dart() {
  local out
  out="$("$@" 2>&1)" || { printf 'KIRMIZI'; return 1; }
  printf '%s' "$out" | tail -1 | sed -n 's/.*+\([0-9]*\).*/\1/p'
}

line; echo "SÜİT 1 — app kabuğu ($(ls test/*.dart | wc -l | tr -d ' ') dosya)"; line
app_n="$(count_dart flutter test)" || fail=1
run "flutter test" flutter test

line; echo "SÜİT 2 — gravita_engine ($(ls packages/gravita_engine/test/*.dart | wc -l | tr -d ' ') dosya)"; line
eng_n="$(count_dart bash -c "cd packages/gravita_engine && dart test")" || fail=1
run "dart test" bash -c "cd packages/gravita_engine && dart test"

line; echo "SÜİT 3 — içerik kapıları (8 araç)"; line
gate() { py_total=$((py_total+1)); if run "$@"; then py_ok=$((py_ok+1)); fi; }
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

line
if [ "$fail" -eq 0 ]; then
  echo "✅ ÜÇ SÜİTİN ÜÇÜ DE YEŞİL"
  echo "   app ${app_n}/${app_n} · engine ${eng_n}/${eng_n} · python ${py_ok}/${py_total}"
  echo "   ⚠️ Kapsam dışı (bilerek): 8 hasat aracı · cihaz davranışı ·"
  echo "      biçim/konum karışıklığı · validate_catalog'un 7 kanıtsız değişmezi"
else
  echo "❌ EN AZ BİR SÜİT KIRMIZI"
  echo "   app ${app_n} · engine ${eng_n} · python ${py_ok}/${py_total}"
  echo "   ⚠️ Tek toplam sayıya BAKMA — yukarıdaki ❌ satırı hangi süit olduğunu söyler."
fi
line
exit "$fail"
