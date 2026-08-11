#!/usr/bin/env bash
# TEK seferlik kurulum: izlenen hook dizinini git'e bağlar.
#
# `.git/hooks/` depo-dışıdır (taze klonda gelmez) — bu yüzden hook'un
# KENDİSİ `tools/hooks/`te izlenir ve git'e onu kullanmasını söylemek bu
# ADLANDIRILMIŞ kurulum adımıyla olur. Kurulmadan önce düz `git commit`
# hiçbir kapıdan geçmez; bu betiğin varlık sebebi tam olarak bu boşluk.
set -euo pipefail
cd "$(dirname "$0")/.."

git config core.hooksPath tools/hooks
echo "✅ core.hooksPath -> tools/hooks (bu depo için yerel, global DEĞİL)"
echo "   Doğrulama: git config --get core.hooksPath"
