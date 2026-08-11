#!/usr/bin/env bash
# `build/` sembolik linkini YEREL olarak üretir — mutlak yol repoya girmez.
#
# ## Neden var (koordinatör ölçümü, 2026-08-11 — üç hatta birden)
#
# `build` daha önce kurucunun kullanıcı adını taşıyan MUTLAK bir yola
# (`/Users/mustafakaankocak/gravita_buildout`) işaret eden bir sembolik
# link olarak git'e COMMIT'LENMİŞTİ (G-125). Neden orada: bu repo
# `~/Documents/` altında, yani iCloud'a senkronlanıyor; Flutter'ın
# `build/`ı binlerce küçük dosya üretir ve iCloud senkronu bunlarla
# codesign/derleme sorunları çıkarır (aile deneyimi: LifeOS + Gravita'da
# ölçüldü). Çözüm doğruydu — `build/`ı iCloud DIŞINA çıkarmak — ama YOLUN
# KENDİSİ commit'lenmişti: başka bir makinede (başka $HOME) taze klon =
# sarkan symlink = `flutter test` OPAK tool-crash'i (`PathNotFoundException`)
# = ürün kusuru SANILAN bir kapı kırmızısı.
#
# Bu betik symlink'i HER makinede YENİDEN üretir, `$HOME`den türeterek —
# repoda YOK, `.gitignore`de `/build` ile açıkça dışlanıyor (G-125).
# İdempotent: hedef zaten doğruysa hiçbir şeyi değiştirmez.
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET="${HOME}/gravita_buildout"
mkdir -p "$TARGET"

if [ -L build ] && [ "$(readlink build)" = "$TARGET" ]; then
  echo "✅ build/ zaten doğru hedefe bağlı: $TARGET"
  exit 0
fi

if [ -e build ] && [ ! -L build ]; then
  echo "⛔ 'build' bir sembolik link DEĞİL (gerçek dosya/dizin) — elle incele, üzerine YAZILMADI."
  exit 1
fi

ln -sfn "$TARGET" build
echo "✅ build/ -> $TARGET (bu makineye özgü, repoya girmiyor)"
