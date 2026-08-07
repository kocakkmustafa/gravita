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
# Ayrıca ÖLÇMEZ: cihaz davranışı (sim'de kamera yok) · görsel ayırt
# edilebilirlik (WCAG luminans ölçer) · `validate_catalog`ın 7 kanıtsız
# değişmezi (betiğin kendi çıktısı onları her koşumda basar).
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
line() { printf '%s\n' "────────────────────────────────────────────"; }
run() {                       # run <ad> <komut...>
  local name="$1"; shift
  local out
  if out="$("$@" 2>&1)"; then
    printf '  ✅ %-34s %s\n' "$name" "$(printf '%s' "$out" | tail -1 | cut -c1-60)"
  else
    printf '  ❌ %-34s %s\n' "$name" "$(printf '%s' "$out" | tail -1 | cut -c1-60)"
    fail=1
  fi
}

line; echo "SÜİT 1 — app kabuğu ($(ls test/*.dart | wc -l | tr -d ' ') dosya)"; line
run "flutter test" flutter test

line; echo "SÜİT 2 — gravita_engine ($(ls packages/gravita_engine/test/*.dart | wc -l | tr -d ' ') dosya)"; line
run "dart test" bash -c "cd packages/gravita_engine && dart test"

line; echo "SÜİT 3 — içerik kapıları (6)"; line
run "validate_library"            python3 tools/validate_library.py
run "validate_library --self-test" python3 tools/validate_library.py --self-test
run "validate_catalog"            python3 tools/validate_catalog.py
run "validate_catalog --self-test" python3 tools/validate_catalog.py --self-test
run "promote_library --check"     python3 tools/promote_library.py --check
run "exclusions_page --check"     python3 tools/build_exclusions_page.py --check
run "skill_tree_index --check"    python3 tools/build_skill_tree_index.py --check
run "name_preconditions --check"  python3 tools/name_preconditions.py --check

line
if [ "$fail" -eq 0 ]; then
  echo "✅ ÜÇ SÜİTİN ÜÇÜ DE YEŞİL"
  echo "   ⚠️ Kapsam dışı (bilerek): 8 hasat aracı · cihaz davranışı ·"
  echo "      görsel ayırt edilebilirlik · validate_catalog'un 7 kanıtsız değişmezi"
else
  echo "❌ EN AZ BİR SÜİT KIRMIZI — yukarıdaki ❌ satırlarına bak"
fi
line
exit "$fail"
