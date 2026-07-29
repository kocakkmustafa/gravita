# M-talebi — `motion_core-v0.4.0` linter'ında kalan iki boşluk

**Tarih:** 2026-07-29 (tur 11) · **Karşılaştırılan:** `tools/validate_catalog.py` (11 değişmez, 20 hareket) ↔ `phase_config.dart` v0.4.0

## Çekirdeğe GİRMİŞ olanlar (teyit)

| Benim | Çekirdek | Durum |
|---|---|---|
| V9 timeout zorunlu | değişmez #1 (J-009) | ✅ |
| V11 uç örtüşmesi | değişmez #9 | ✅ |
| V6 perturbasyon ≥ eşik | değişmez #11 + `noiseBand` | ✅ |
| G-016 fiziksel menzil | metrik kaydında `range` zorunlu | ✅ |
| V2 taraf politikası | `sideResolution` zorunlu alan | ✅ |
| — | bilinmeyen alan = sert hata (M-J-03) | ✅ |

## ❌ Boşluk 1 (P1) — `cutoffHz` "zorunlu" YAZIYOR ama zorlanmıyor

`MetricSpec.cutoffHz` doc-yorumu: *"Mandatory for fast-transition metrics
(G-V10/J-027)"*. Ama `_expectKeys` çağrısında `optional` kümesinde:

```dart
required: const {'unit', 'range', 'noiseBand', 'baseline'},
optional: const {'interval', 'cutoffHz', r'$doc'},
```

Koşullu bir kontrol yok — hızlı-geçişli bir metrik `cutoffHz`siz yazılırsa
linter susuyor.

Bu tam olarak **"ifade edilemeyen kural uygulanmaz"** durumunun bir adım
ötesi: kural düzyazıda ifade edilmiş ama kodda değil, yani okuyan uyar,
yazan uymayabilir. J-027'nin bedeli somuttu (çekirdek varsayılan yumuşatması
hızlı geçişleri söndürüyor); bende `mountain_climber` bu yüzden
`fastTransition: true` + `signalFilter.cutoffHz: 6.0` taşıyor ve **V10 betikle
zorlanıyor**.

**Talep:** metrik ya da onu kullanan teknik `fastTransition` işaretliyse
`cutoffHz` zorunlu olsun (derleme anı kontrolü).

## ❌ Boşluk 2 (P1) — `ErrorSpec`'te SÖYLENECEK SÖZ yok

```dart
final class ErrorSpec {
  final String code;          // ne tespit edildi
  final Marker evaluateAt;    // nerede değerlendirilir
  final Condition condition;  // hangi koşulda
  final ErrorPriority priority; // hangi sırayla söylenir
  // ... cue YOK
}
```

`cue` çekirdekte yalnız `cue_gate.dart` (NE ZAMAN susulur) ve
`feedback_prioritizer.dart` (hangi sırayla) içinde geçiyor — ikisi de
*zamanlama*, *içerik* değil.

Ürünün çekirdek vaadi sesli koçluk. Söylenecek sözü taşımayan bir hata kaydı
iki kötü sonuçtan birini üretir: (a) tespit edilir ve sessizce düşer, (b)
metinler UI katmanında yazılır ve tespit kuralından **bağımsız olarak kayar**
— dürüstlük kutusunda çözdüğümüz drift probleminin aynısı (180 hareketin elle
yazılmış metni motorla kaçınılmaz olarak ayrışır).

Bende her form hatası `cue` taşıyor (İngilizce, tek cümle, telefon uzaktayken
anlaşılır) ve **V7 bunu zorunlu kılıyor**: *"tespit edip söylemediğimiz hata
olamaz."*

**Talep:** `ErrorSpec`e `cue` (veya i18n için `cueRef`) zorunlu alan. Metin
sözlüğü çekirdeğe sızmasın diye `cueRef` + app-side sözlük de kabul —
önemli olan **hata kaydının söyleyecek bir şeyi olduğunun derleme anında
garanti edilmesi**.

## ℹ️ Boşluk DEĞİL — değişmez #10 (ölü metrik) linter'da olamaz

Taslak #10 "sabit değer üreten metrik yükleme anında reddedilir" diyor. Ama
bir metriğin sabit üretip üretmediği ancak **koşturularak** bilinir; config
linter'ı bunu göremez. Doğru yeri **harness** (Lissom'un A10 deseniyle aynı
katman: "doğru duruşta guard=0" da bir harness kanıtı). Çekirdekte olmaması
eksiklik değil, doğru yerleştirme — yalnız taslak metninde "yükleme anında"
ifadesi yanıltıcı, "kapı koşumunda" olmalı.

## ℹ️ Bilerek app-side kalanlar (talep değil)

V3 `gateableMetrics` (patlayıcı metrik progresyon kapısı olamaz) · V4
`scoreDisplay` (K8) · V5 sınıf-B form hükmü yasağı · V8 sınıf-C katalog dışı.
Bunlar **sunum sözleşmesi**, faz-config değil — Gravita'da kalmaları doğru.
