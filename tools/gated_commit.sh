#!/usr/bin/env bash
# Kapıdan GEÇMEDEN commit ETMEYEN tek giriş noktası.
#
# ## Neden var — ölçülmüş bir kusur, benim kendi zincirimde
#
# Gece boyunca şunu yazdım:
#
#     ./tools/run_all_gates.sh 2>&1 | tail -4 ; git add … && git commit …
#
# İki kusur ÜST ÜSTE:
#   ① `| tail` boru hattının çıkış kodunu SON komuta bağlar; `tail` her
#      zaman 0 döner ve kırmızıyı YUTAR. (JabLab'ın J-190'ı.)
#   ② Ayırıcı zaten `;` — yani boru düzelse bile commit koşulsuz koşardı.
#
# Yani kapı çıktısı hiçbir zaman KAPI değildi, yalnızca BİLGİYDİ.
# `run_all_gates.sh` doğru davranıyordu (kırmızıda `exit 1`); onu ben
# atıyordum. → *Bir kapının doğru olması, çağrıldığı yerin doğru olmasını
# garanti etmez.*
#
# Kullanım:
#   tools/gated_commit.sh -F mesaj.txt dosya1 dosya2 …
#   ALLOW_RED=1 tools/gated_commit.sh …   # bilerek kırmızı commit (K14 gibi)
set -euo pipefail
cd "$(dirname "$0")/.."

if ! ./tools/run_all_gates.sh; then
  if [[ "${ALLOW_RED:-}" == "1" ]]; then
    echo "⚠️  KAPI KIRMIZI — ALLOW_RED=1 ile bilerek geçiliyor."
    echo "   Bu bir muafiyet LİSTESİ değil, tek seferlik ve AÇIKÇA verilen"
    echo "   bir karar: commit mesajı kırmızının SEBEBİNİ yazmak zorunda."
  else
    echo "⛔ KAPI KIRMIZI — commit YAPILMADI."
    exit 1
  fi
fi
exec git commit "$@"
