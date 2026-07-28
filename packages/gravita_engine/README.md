# gravita_engine

Gravita'nın hareket motoru. `motion_core`'u **pinli** sürümle tüketir (`motion_core-v0.1.0`); çekirdeğe kod yazmaz (M-F-03: motion-core sahibi koordinatör oturum).

## Neyi kanıtlıyor

| Test | Ne gösteriyor |
|---|---|
| `d1_axis_swap_regression_test.dart` | D1 kapısında ölçülen **gerçek** kol↔bacak takası kareleri: #21'de güven kapısı geçiriyor (vis 0.93), yapısal denetim reddediyor. "Güven ≠ doğruluk" artık çalışan bir regresyon testi. |
| `structural_false_reject_test.dart` | Aşırı-katılığın bedeli: varsayılan `bilateralTolerance` 66 doğru karenin %32'sini reddediyor (0.60'ta %6). Kaçıran denetim kadar aşırı-katı denetim de ürünü bozar. |

Fixture'lar türetilmiş landmark verisidir (Wikimedia Commons kaynaklı, lisansları `test/fixtures/*.json` içinde). Ham medya repoda yoktur.

## Çekirdek sürümünü yükseltirken
`pubspec.yaml`'daki `ref` değişimi = DEFTER kaydı + bu testlerin yeniden koşulması. Testler v0.1.0 davranışını **sabitler**; çekirdek iyileşince kırılırlar ve bilinçli güncellenirler.

```bash
dart pub get && dart test
```
