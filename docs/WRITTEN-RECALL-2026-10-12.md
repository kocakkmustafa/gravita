# Yazılı hatırlama ve geri bildirim — 12 Ekim 2026

Bu ek, mevcut kaynak derslerini okuma/aktif hatırlama ile çalıştırır. Hareket veya ekipman gerekmez. Öğrenen yazılı cevabı kaynaktan ayrı kurup karşılaştırır. Fiziksel uygunluk, tekniğin doğruluğu, demonstrasyon/lisans ve tam müfredat kabulü verilmez.

| Onaylı alan | Mevcut ders/birim | Yeni okuma | Açık kapsam |
|---|---:|---:|---|
| bodyweight | 56 | 2 | Written 56-lesson pathway exists; actual mechanics, readiness, demonstration and configured-vs-available camera feedback remain separate. |
| dbkb | 25 | 2 | Three written handling/transition strands exist; equipment-specific load/support, personal suitability and demonstrated transfers remain open. |
| barbell | 0 | 2 | No dedicated complete barbell course was located. Missing exact setup/transfer instruction, suitable verified supports, demonstrations and loaded-feedback acceptance require expert/equipment evidence. |
| rings | 0 | 2 | No dedicated complete bar/ring course was located. Missing attachment/support verification, staged support/pull teaching, demonstration and learner feedback require expert/equipment evidence. |
| hands | 0 | 2 | Handstand/planche graphs exist (15/6 nodes), but are not full lessons. Exact preparation, entry/exit and loaded balance teaching need expert/equipment evidence; S2 inversion policy is preserved. |

Kaynak dosyaları ve bölüm referansları `lib/app/study_review_content.dart` içindeki `sourceRefs` alanındadır. Eski ders metinleri, süre/doz, sensör eşikleri, fiziksel kabul ve ders ilerlemesi değiştirilmez.

`study_review.dart` durumları ayrı tutar: denenmedi → örneği yeniden oku; belirsiz → kesin terimi/geçişi adlandır ve uygun eğitmene soru hazırla; tek fark → yalnız aynı yazılı noktayı düzeltip kaynağı gizleyerek yeniden hatırla; durdum → bitir, hareket/ekipman görevini tekrar etmeyi önerme. Notlar geçicidir; kalıcı sağlık/hesap/ilerleme kaydı yoktur.

`test/study_review_test.dart` TR/EN dar ekran/büyük metin, kaynak cevabının gizlenip açılması, dört farklı geri bildirim ve çıkışta not/durum atılmasını sınar. Gerçek cihaz, fiziksel öğretim, sensör ve mağaza testi değildir.

Gizlilik kaynağı ayrı korunur: privacy test, manifest ve pubspec/lock byte’ları değişmedi. Son kullanıcı talimatıyla normal pub cache üzerinde offline/enforce-lockfile çözümleme generated package config’i yeniledi; lock ve package graph aynıdır. Kanonik config ile yeni okuma testleri 8/8 geçti; privacy testinde 16/17 kontrol geçti, ana ölçüm DiskSpace/statfs beyan farkında FAIL kaldı. Bu kaynak tokenı SQLite linked-binary kanıtı değildir; SDK/binary provenance HOLD sürer. S2 yönelim politikası aynıdır.
