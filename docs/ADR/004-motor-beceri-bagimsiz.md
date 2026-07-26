# ADR-004 — Motor beceri-bağımsız, beceri içerik-paket

**Durum:** kabul (2026-07-26) · **Kaynak:** kurucu direktifi (başlangıç promptu: *"darboğaz yaratma"*) + `00-AILE-MIMARISI §1.1` (vizyon tavansız) · **Detay:** [`../G4-BECERI-GRAFI-TASARIMI.md`](../G4-BECERI-GRAFI-TASARIMI.md)

## Bağlam
V1'in merkezi handstand. Ama vizyon tavansızdır: L-sit, pistol, muscle-up hazırlığı, press handstand, planche hazırlığı, jimnastik şekilleri (plan §17). Handstand'i koda gömmek, her yeni beceriyi mühendislik işi yapar.

## Karar
- **Kodda:** graf yürütme, kriter değerlendirme, kilit/açma, ilerleme durumu, güvenlik zorlaması, gerekçe üretimi.
- **Versiyonlu JSON pakette:** düğümler, ön-koşullar, açma kriterleri, drill'ler, cue metinleri, güvenlik notları.
- Yeni beceri = **yeni JSON**. Kod değişikliği yok. Paketler `packVersion` taşır ve her denemeye yazılır (ADR-005).
- Kriterler serbest metin değil **yorumlanabilir yapı** (`{metric, op, value, aggregate, window}`) → her açma kararı kullanıcıya gerekçelendirilebilir (plan §15).

## Motorun zorladığı, içeriğin kıramadığı değişmezler
1. Güvenlik ön-koşulu zorlaması (duvar-önce; `freestanding` `chest_to_wall`+`heel_pulls` olmadan açılmaz).
2. Ağrı-durdurma üstünlüğü (dal kilitlenir, oturum durur).
3. Her açmaya otomatik `analysis_confidence` şartı.
4. Tekrarlanabilirlik penceresi (tek seferlik başarı açma yapmaz).

## Sonuçlar
- ✅ V1 paketi 15 düğüm içeriyor ve `l_sit_prep` / `pistol_prep` **handstand zincirine bağlı olmayan ayrı dallar** olarak zaten var — beceri-bağımsızlığın çalışan kanıtı.
- ✅ Uzman (calisthenics/`movement-science-advisor`) kriterleri **kod bilmeden** düzenleyebilir.
- ⚠️ Paket şeması sözleşmedir: kırıcı değişiklik `schemaVersion` artırımı + geçiş kodu ister.
- Eşik değerleri şu an plandan devralındı; **fizyolojik doğrulama borcu açık** (G4 §7 / D-1).

## Reddedilen alternatifler
- **Beceriyi koda gömmek:** her yeni beceri sürüm işi; vizyonla çelişir.
- **Kriterleri serbest metin bırakmak:** değerlendirilemez, gerekçelendirilemez, test edilemez.
- **Kriterleri sunucudan çekmek:** çevrimdışı çekirdek şartıyla (plan §3.7) çelişir; paket uygulamayla gelir, güncelleme opsiyonel.
