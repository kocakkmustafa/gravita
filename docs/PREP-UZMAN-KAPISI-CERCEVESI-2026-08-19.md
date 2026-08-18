# PREP — Uzman Kapısı Boşluğu: Strength/Calisthenics Uzmanı Araştırması (2026-08-19)

**Oturum:** GRAVITA (PREP lane) · **Sorun:** roadmap §14 (`MANUAL-GRAVITA-EXPERT-20260818`) ve aile roadmap'i §10 "iki alan uzmanı review'u" + "Hula, prenatal/senior, combat ve yüksek risk strength içerikleri isimli uzman/partner kapısı olmadan aktif olmaz" diyor — ama uzmanı NEREDEN/NASIL bulacağı, hangi yeterlilik barını geçmesi gerektiği ve ne kadar ödeneceği hiçbir dosyada tanımlı değil. Bu doküman o boşluğu dolduran bir ÇERÇEVE TASLAĞIdır — gerçek sözleşme/ödeme kurucu R3 kapısıdır (protokol §6, "Hukukçu, uzman, eğitmen, demonstratör ve lisans sözleşmeleri").

⚠️ **Dürüstlük notu:** Aşağıdaki isimler/kurumlar (NSCA, NASM vb.) ve rakamlar WebSearch ile 2026-08-19'da doğrulanmış GERÇEK, genel pazar verisidir (kaynaklar §5'te). **Hiçbir spesifik insan adayla temas kurulmadı, hiç kimsenin uygunluğu/ücreti teyit edilmedi** — bu bir pazar-taraması + çerçeve, bir "adayı bulundu" raporu değil.

## 1. Neden bir yeterlilik çerçevesi gerekiyor

Roadmap'in kendi güvenlik disiplini (`content/catalog/*.json`'daki her hareketin `safety.warnings`, `formErrors[].priority:"safety"` alanları) zaten mühendislik tarafında ciddi — ama motor/içerik ekibinin (bu oturumun) kendi kendini denetlemesi yeterli değil: aile orkestrasyonu §10 açıkça **"İki alan uzmanı review'u"**nu minimum süreç şartı yapıyor. Gravita'nın W2 dalgasında zaten inversion/skill hareketleri var (`wall_handstand`, `tuck_planche` — ikisi de `class:A` ama `family:"skill"`, D1 ters-duruş mimarisine bağlı) ve W3+ barbell dalgası geliyor (roadmap §4) — yüksek-risk kapı bu noktada zorunlu hâle geliyor, isteğe bağlı değil.

## 2. Önerilen yeterlilik bar (iki kademeli)

### Kademe 1 — Standart hareket review'u (29 mevcut + gelecek W1/W2 hareketleri)
- **Taban sertifika:** NSCA-CSCS (Certified Strength & Conditioning Specialist) TERCİH; NASM-CPT/ACE-CPT/ISSA kabul edilebilir alternatif.
- **Neden CSCS öncelikli:** ABD'de strength & conditioning için endüstri-standart akreditasyon; roadmap'in "wellness dili, tıbbi dil yasak" kısıtıyla uyumlu (CSCS klinik değil performans/kondisyon odaklı).
- **Ek şart:** en az bir hareketin `formErrors`/`safety` alanlarını okuyup yazılı geri bildirim verebilecek düzeyde biyomekanik okuryazarlığı (CV/portföyde gösterilmeli).

### Kademe 2 — Yüksek-risk hareket review'u (inversion/rings/barbell/plyometric — aile roadmap'i §10)
- **Ek şart:** kalisthenics/jimnastik-bitişik özelleşme. **Önemli piyasa gerçeği (araştırıldı):** 2026 itibarıyla NCCA-akredite, yalnızca-kalistenik bir sertifika YOK. Piyasa pratiği: genel akredite CPT (NASM/ACE/ISSA) + üstüne kalistenik-özel eğitim (ör. GMB Fitness tarzı programlar, Calisthenics Association, benzeri) katmanlanıyor.
- Gravita'nın kendi W2 hareketleri (`wall_handstand`, `tuck_planche`) ve roadmap'in `D1` ters-duruş mimarî şartı (bkz. `app/CLAUDE.md` "D1 — TERS-DURUŞ FİZİBİLİTESİ") göz önüne alınca, bu kademedeki adayın **handstand/planche progresyon koçluğunda doğrulanabilir tecrübesi** (kendi içerik/öğrenci geçmişi) aranmalı.
- Bar/rings/barbell dalgası (W3-W4-W5, roadmap §4) henüz aktif değil — bu kademe kapısı W3 başlamadan önce kapanmak ZORUNDA, şimdiden değil (aile roadmap'i: "final inventory'den silinmez" ama "isimli uzman/partner kapısı olmadan aktif olmaz").

## 3. Sourcing kanalları (gerçek, doğrulanabilir)

| Kanal | Ne için uygun | Not |
|---|---|---|
| **NSCA'nın kendi CSCS dizini** (nsca.com) | Kademe 1, kimlik doğrulaması yerleşik (sertifika NSCA'dan) | En düşük sahtecilik riski — sertifika numarası doğrulanabilir |
| **Upwork / Truelancer** (fitness/strength freelancer kategorisi) | Kademe 1, portföy+yorum geçmişiyle hızlı tarama | Ücret aralığı platformda görünür, pazarlık esnek |
| **Gravita'nın KENDİ harvest kuyruğundaki eğitmenler** (`content/harvest/queue.gravita.json`) | Potansiyel Kademe 2 — THENX, Tom Merrick, GMB Fitness, FitnessFAQs, Squat University gibi kanallar zaten Gravita'nın TAM hedef hareket setinde (squat/push-up) yayın yapan, tanınır kalistenik/güç eğitmenleri | ⚠️ Yalnız İSİM — hiçbiriyle temas kurulmadı, uygunluk/ücret/çıkar-çatışması (aynı zamanda kaynak-video sağlayıcısı olabilirler) değerlendirilmedi. Kurucu kapısında ilk değerlendirilecek liste olarak öneriliyor, "seçildi" değil |
| **Üniversite spor bilimi bölümleri** (adjunct/danışmanlık) | Kademe 2, biyomekanik derinlik | Genelde kurumsal sözleşme süreci daha yavaş |

## 4. Ücret çerçevesi (gerçek pazar verisiyle, WebSearch 2026-08-19)

| Referans | Aralık |
|---|---|
| Genel serbest fitness profesyoneli (ABD) | $40–90/saat |
| Serbest biyomekanik danışman | $50–100/saat |
| Genel fitness danışmanlığı | $25–50/saat |
| Düşük-uçlu serbest koçluk işleri | $17–53/saat |

**Önerilen yapı — SAAT DEĞİL PARÇA-BAŞI (Gravita'nın iş biriminin "hareket" olması nedeniyle bütçelenmesi daha kolay):**
- **Kademe 1 review, standart hareket:** hareket başı sabit ücret önerisi — bir hareketin tam paketini (`classRationale`, `engine.phases`, `formErrors[].detect` eşikleri, `safety.warnings`, `measurementContract`) okuyup yazılı onay/düzeltme vermek tahmini 20-40 dk sürer → $50/saat üst-orta pazar noktasından **~$25-35/hareket** kaba tahmin (uzmanın kendi teklifi esas alınmalı, bu yalnız bütçe-planlama çıpası).
- **Kademe 2 review, yüksek-risk hareket:** daha derin inceleme (video/demo talep edebilir) → $50-100/saat aralığından **1-1.5 saat/hareket** kaba tahmin.
- **20 hareketlik paid-foundation batch'i** (GRA-P1-002, roadmap §11) için kaba bütçe çıpası: ~18 standart + ~2 yüksek-risk (wall_handstand/tuck_planche) → yaklaşık $450-630 (standart) + $150-300 (yüksek-risk) = **kabaca $600-900 bant** — bu bir TEKLİF DEĞİL, kurucunun bütçe kararı için başlangıç çıpası; gerçek rakam adayın kendi teklifiyle değişir.

## 5. Önerilen taahhüt yapısı

1. **Tanışma/tarama görüşmesi** (ücretsiz veya sembolik, çoğu freelancer platformu böyle çalışır) — Kademe 1/2 uygunluğunu doğrula.
2. **Pilot paket:** squat+push_up'ın MEVCUT `formErrors`/`safety` alanlarını retroaktif review ettir (zaten canlı, düşük risk, ucuz pilot) — uzmanın çalışma kalitesini/hızını gerçek veriyle ölç, sonra ölçeklendir.
3. **Onay kaydı:** roadmap'in kendi şeması zaten bunu bekliyor — `docs/content/expert-approvals.json` (henüz YOK, GRA-P1-002'nin "Create later" listesinde) her onay için `approvalId` + tarih + kapsam (hangi movementId'ler) + uzman kimliği referansı taşımalı; **sertifika numarası veya sözleşme METNİ dosyaya asla yazılmaz** (protokol §3.4 "sırlar mesajlara/workspace'e yazılmaz" ilkesiyle aynı disiplin — yalnız güvenli konum referansı).
4. **Yüksek-risk kademe için ayrıca:** demonstrator release formu (görüntüsü kullanılan kişinin izni) — bu AYRI bir hukuk kalemi, `MANUAL-GRAVITA-EXPERT-20260818`'in kendi "Adımlar" listesinde zaten var, bu doküman onu tekrarlamıyor.

## 6. Kurucu kapısına ne gidiyor (R3, protokol §6)

- Gerçek bir adayla temas + sözleşme + ödeme — **hiçbiri bu oturumda yapılamaz/yapılmadı.**
- Bu çerçeve `MANUAL-GRAVITA-EXPERT-20260818` paketinin "Ön koşul: movement class/safety/review packet" satırını dolduran girdi olarak orkestratöre/MASTER'a iletilmeye hazır.

## Kaynaklar (WebSearch, 2026-08-19)
- [CSCS Certification | NSCA](https://www.nsca.com/certification/cscs/)
- [$17-$53/hr Freelance Fitness Coach Jobs | ZipRecruiter](https://www.ziprecruiter.com/Jobs/Freelance-Fitness-Coach)
- [Best Freelance Personal Trainers for Hire | Upwork](https://www.upwork.com/hire/physical-fitness-trainers/)
- [25 Best Freelance Physical Fitness for Hire | Truelancer](https://www.truelancer.com/physical-fitness-freelancers)
- [Best Calisthenics Coach Certifications | TrainerAcademy](https://traineracademy.org/certifications/best-calisthenics-coach-certifications/)
- [Biomechanics Specialist Salary: Hourly Rate | ZipRecruiter](https://www.ziprecruiter.com/Salaries/Biomechanics-Specialist-Salary)
- [Average Fitness Consultant Hourly Pay | PayScale](https://www.payscale.com/research/US/Job=Fitness_Consultant/Hourly_Rate/53290d1c/Health-and-Wellness)
