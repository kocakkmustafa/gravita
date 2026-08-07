#!/usr/bin/env python3
"""'Neden yok?' sayfasının KULLANICI ALTKÜMESİNİ üretir.

## Neden bir üretim adımı var, dosya doğrudan paketlenmiyor

`content/catalog/exclusions.json` bir DERLEME DEFTERİDİR: her bölümde
kullanıcıya dönük `userReason`'ın yanında iki iç alan durur —
`internalRule_tr` (Türkçe kural gerekçesi, ör. *"Sınıf C blanket kuralı;
tek tek makine tartışılmaz"*) ve `reconsiderIf` (yol haritası dili, ör.
*"Rep counting alone is not the product"*). İkisi de ürün kararlarının
kaydıdır, kullanıcı metni değil.

Dosyayı olduğu gibi asset yapmak o iki alanı da uygulamaya sokardı. Bu araç
YALNIZ kullanıcıya dönük alanları `content/exclusions.page.json`'a çıkarır.
Tek kaynak yine `exclusions.json` — sayfa ondan ÜRETİLİR, elle yazılmaz
(W0 §1: *"tek sayfa — exclusions.json'dan üretilir"*).

## Neden bu sayfa Library'nin BOŞ SONUÇ hâlinin yerine geçiyor

W0 §4 (dar-app algısı yasağı): *"leg press"* arayan kullanıcı boş sonuç
DEĞİL, ilgili bölümü görür. Bu yüzden `searchTerms` alanı da burada üretilir:
her bölümün `title` + `examples` sözcükleri aramanın eşleşeceği kelime
kümesidir. Ekran kendi eşleştirme sözlüğünü KURMAZ — kurarsa iki sözlük
ayrışır ve arama sessizce körelir.

    python3 tools/build_exclusions_page.py           # kuru koşum
    python3 tools/build_exclusions_page.py --write
    python3 tools/build_exclusions_page.py --check   # drift kapısı
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "content" / "catalog" / "exclusions.json"
OUT = ROOT / "content" / "exclusions.page.json"

#: Kullanıcıya GİDEN alanlar. Bu listede olmayan her alan iç kalır — beyaz
#: liste, kara liste değil: yarın `exclusions.json`'a eklenecek yeni bir iç
#: alan sessizce sızmasın (kara liste olsaydı sızardı).
USER_FIELDS = ("id", "title", "examples", "userReason", "movementClass",
               # ⭐ SINIF kullanıcıya GİDER (J-153): "kamera göremiyor" örtük
               # bir VAAT taşır, "bu bir çizgi" taşımaz. Sınıf olmadan yedi
               # kalem tek çerçevede okunuyor ve AUTHORITY olanlar
               # "teknoloji çözer" diye anlaşılıyor.
               #
               # ⚠️ `reconsiderIf` YİNE GİRMİYOR: sınıfı ondan türettik ama
               # kendisi yol haritası dili taşıyor ("V2+", "W3'de planlı") —
               # yani YAPISAL VAAT (J-150). Sınıf çıkar, takvim çıkmaz.
               "limitClass")


def _search_terms(section):
    """Bölümün arama sözcükleri — başlık + örneklerden TÜRETİLİR.

    Küçük harf, noktalama yok, 2 harften kısa parçalar atılır. "Leg press"
    hem *leg press* hem *press* hem *leg* ile bulunur; kullanıcı tam adı
    bilmek zorunda değil.
    """
    terms = set()
    for raw in [section["title"]] + list(section.get("examples") or []):
        low = raw.lower()
        terms.add(low)
        for word in re.split(r"[^a-z0-9]+", low):
            if len(word) > 2:
                terms.add(word)
    return sorted(terms)


def build(src):
    return {
        "schemaVersion": 1,
        "$generatedBy": "tools/build_exclusions_page.py — ELLE DÜZENLEME. "
                        "Kaynak: content/catalog/exclusions.json",
        "pageTitle": src["pageTitle"],
        "pageIntro": src["pageIntro"],
        "sections": [
            {**{k: s[k] for k in USER_FIELDS if k in s},
             "searchTerms": _search_terms(s)}
            for s in src["sections"]
        ],
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    page = build(json.loads(SRC.read_text(encoding="utf-8")))
    text = json.dumps(page, ensure_ascii=False, indent=2) + "\n"

    if args.check:
        if not OUT.exists():
            print(f"⛔ {OUT.relative_to(ROOT)} YOK — üretilmemiş")
            return 1
        if OUT.read_text(encoding="utf-8") != text:
            print(f"⛔ DRIFT: {OUT.relative_to(ROOT)} kaynaktan üretilenle "
                  f"aynı değil — elle düzenlendi ya da exclusions.json "
                  f"değişip sayfa bayatladı")
            return 1
        print(f"✅ 'Neden yok?' sayfası kaynağıyla AYNI — "
              f"{len(page['sections'])} bölüm")
        return 0

    leaked = sorted({k for s in json.loads(SRC.read_text(encoding='utf-8'))["sections"]
                     for k in s} - set(USER_FIELDS))
    print(f"{len(page['sections'])} bölüm · uygulamaya GİRMEYEN iç alanlar: "
          f"{', '.join(leaked) or '(yok)'}")
    if args.write:
        OUT.write_text(text, encoding="utf-8")
        print(f"✍️  yazıldı: {OUT.relative_to(ROOT)}")
    else:
        print("(kuru koşum — uygulamak için --write)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
