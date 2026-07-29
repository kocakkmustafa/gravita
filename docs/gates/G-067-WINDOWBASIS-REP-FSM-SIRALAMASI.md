# G-067 — windowBasis sıralaması: Python'a FSM portu YOK, iki aracın sırası yeterli

**Koordinatör hükmü (M-F-101):** G-066'nın metodolojik sınırını (kanonik
script Gravita'nın FSM-tamamlanmış-tekrar penceresini kullanmıyordu) FSM'i
Python'a taşımadan çöz — sıralama sorunu: **önce Dart rep-slicer, sonra
kanonik damga.** Damgaya `windowBasis: confidence-gate | rep-fsm` ekle.

## Uygulama

1. **`packages/gravita_engine/tool/slice_deep_reps_squat.dart`** (yeni) —
   ürünün rep-FSM'ini koşturur, `formErrors.shallow_depth` (İSİMLİ,
   `rom_bottom_angle≤110°`) eşiğini geçen her DERİN tekrarı kendi fixture
   dosyasına keser (ham `t/detected/lm/world` kayıtları AYNEN kopyalanır,
   yeniden hesaplanmaz). Çıktı: `~/motion-harvest/gravita-squat/landmarks-
   rep-sliced/`.
2. **`tools/hip_knee_coupling_canonical.py`** güncellendi: `--dir` ve
   `--window-basis {confidence-gate,rep-fsm}` argümanları eklendi. Yalnız
   `rep-fsm` modu `content/harvest/hip_knee_coupling.bodyweight_squat.json`'a
   YAZAR (kimlik-kapılama kaynağı budur); `confidence-gate` modu yalnız
   ham fixture'ları damgalar (triyaj-bilgisi, provisional).

## Dilimleme sonucu (Dart rep-slicer)

400 toplam tekrar, **260 derin** (rom_bottom_angle≤110°). 16 eğitmenden
**3'ü SIFIR derin-tekrar dilimi** üretti: **Minus The Gym, School of
Calisthenics, Vast Fitness Academy.** Koordinatör yalnız Vast Fitness'ın
noSignal'e döneceğini öngörmüştü — **ölçüm iki eğitmen DAHA buldu**, aynı
sınıf kontaminasyon (FSM hiç derin tekrar doğrulamadı).

## Sonuç: 12/16 PASS, 1 FAIL, 3 noSignal (windowBasis=rep-fsm)

| Eğitmen | n | r (rep-fsm) | r (confidence-gate) | Gate |
|---|---|---|---|---|
| K boges | 3684 | 0,982 | 0,980 | PASS |
| Sebastian Oreb | 219 | 0,980 | 0,857 | PASS |
| Strength Side | 2396 | 0,973 | 0,950 | PASS |
| THENX | 4045 | 0,971 | 0,963 | PASS |
| TappBrothers | 101 | 0,958 | 0,642 | PASS |
| Jeremy Ethier | 646 | 0,896 | 0,853 | PASS |
| WeShape | 807 | 0,912 | 0,941 | PASS |
| Jeff Nippard | 1804 | 0,867 | 0,880 | PASS |
| GMB Fitness (Praxis) | 62 | 0,692 | 0,808 | PASS |
| Squat University | 1566 | 0,677 | 0,732 | PASS |
| Calisthenicmovement | 211 | 0,579 | 0,616 | PASS |
| Tom Merrick | 1594 | 0,274 | 0,442 | PASS |
| **FitnessFAQs** | **10** | **-0,233** | 0,495 | **FAIL (YENİ)** |
| Minus The Gym | 0 | — | 0,971 | **noSignal** |
| School of Calisthenics | 0 | — | 0,707 | **noSignal** |
| Vast Fitness Academy | 0 | — | 0,821 | **noSignal (öngörülen)** |

**Beklenmeyen bulgu: FitnessFAQs artık REDDEDİLİYOR (r=-0,233).** Sebep açık:
yalnız **1 derin-tekrar dilimi** var (n=10 kare-çifti) — bu kadar küçük bir
örneklemde işaret gürültüye BATABİLİR (bir tekrarın son birkaç karesinde
kalça/diz açısı neredeyse durağan kalır, düşük varyans korelasyonu
istikrarsızlaştırır). confidence-gate modunda (n=4642, rep-FSM'siz, muhtemelen
konuşma/geçiş kareleri dahil) r=0,495 GEÇİYORDU — ama o sayı da aynı
kontaminasyon riskini taşıyordu. **Bu, güvenilir bir "confounder" hükmü
DEĞİL** — n=10'un istatistiksel gücü yok, teyit için FitnessFAQs'tan yeni
derin-tekrar hasadı gerekir. `thinEvidence:true` işaretlendi, kesin ret
olarak muamele edilmiyor.

**TappBrothers ÜÇ bağımsız ölçümde de PASS** (2D-eski: RED [formül-artefaktı]
→ confidence-gate-kanonik: 0,642 → rep-fsm-kanonik: 0,958) — sağlam.

## Ne değişti

- `content/harvest/hip_knee_coupling.bodyweight_squat.json`: artık
  `windowBasis:"rep-fsm"` ile yazılıyor, kimlik-kapılama kaynağı bu.
- `identity-triage.bodyweight_squat.json`: rep-fsm sayılarıyla yeniden
  yazıldı (12 pass/1 fail/3 noSignal).
- `triage-profile.gravita.v2.json`: `hipKneeCoupling.basis` nihai sayılarla
  güncellendi, eşik (0,2) hâlâ PROVISIONAL.
- Ham fixture'lar (`~/motion-harvest/gravita-squat/landmarks/*.json`)
  `provenance.hipKneeCoupling.windowBasis:"confidence-gate"` ile yeniden
  damgalandı (triyaj-bilgisi, kimlik-kapılama için değil).

## Kanıt / komutlar

```bash
cd packages/gravita_engine
dart run tool/slice_deep_reps_squat.dart

V=motion-core/lib/tools/fixture_pipeline/.venv/bin/python
$V tools/hip_knee_coupling_canonical.py --dir ~/motion-harvest/gravita-squat/landmarks --window-basis confidence-gate --stamp
$V tools/hip_knee_coupling_canonical.py --dir ~/motion-harvest/gravita-squat/landmarks-rep-sliced --window-basis rep-fsm --stamp
```
