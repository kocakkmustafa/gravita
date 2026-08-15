#!/usr/bin/env python3
"""DEFTER TAZELİĞİ — **İKİ YÖNDE**: eksik (commit→defter) ve öksüz (defter→commit).

## Neden var (G-194, 2026-08-12)

Bugün iki hatta **59 kayıt** kaybı ölçüldü: iş yapıldı, commit'lendi, rapor
edildi — **deftere geçmedi.** Sınıfı JabLab buldu:

    Bir işin YAPILMIŞ olması, KAYDEDİLMİŞ olması değildir.

JabLab'ın yakalama yöntemi *"yeni kaydı yazarken bir önceki numaranın
çapasını ara"* — ucuz ve doğru, **ama kusurun EN AĞIR hâlinde KÖR:** çapa
ancak *sıradaki kaydı yazarken* aranır; **hiç kayıt yazmadığın anı** görmez.

> ***Bir yöntem, kusurun en hafif hâlinde çalışıp en ağır hâlinde kör
> olabilir.***

## 🔴 G-196 — İKİNCİ YÖN EKLENDİ, ve ilk koşumda GERÇEK KUSUR buldu

İlk yazımım (G-194) **tek yönlüydü**: yalnız `commit ∖ defter`. Koordinatör
ölçümü (2026-08-13) bunu `⛔` saydı ve haklıydı — ölçüt *"gedik 0, **iki
yönde**"* istiyor. Ters yön (`defter ∖ commit`) hiç hesaplanmıyordu:
**192 kaydın 128'i** hiçbir kapının bakmadığı taraftaydı.

**Ve ters yön boş çıkmadı.** `G-179` defterde *"planche_lean_deg
adlandırıldı"* diyor; işin commit'i **var** (`9763da8`) ama başlığında
**numara YOK**. ⇒ Bu kusuru **ileri yön yapısal olarak göremez**: commit
numara iddia etmediği için `commit ∖ defter` kümesine hiç girmez.

> ***BİR BAĞIN İKİ UCU VARDIR; TEK UCUNU DENETLEYEN KAPI, BAĞIN
> KOPTUĞUNU DEĞİL YALNIZ BİR UCUNUN EKSİLDİĞİNİ GÖRÜR.***

## İki yön, İKİ DESEN — ve bu ölçümle seçildi, varsayımla değil

Desen genişliğinin iki yöndeki etkisi **ZITTIR** (Ostinato'nun O-110'da
ölçtüğü şey; burada kendi ağacımda yeniden ölçüldü):

* **EKSİK yönü ÇAPALI desen ister** (`^G-NNN`): *"bkz. G-104"* diyen bir
  commit G-104'ü **yazmış** sayılmamalı. *Sözünü etmek ≠ kayıt olmak.*
* **ÖKSÜZ yönü GENİŞ desen ister** (`\\bG-NNN`): kaydın kaynağı gövdede
  anılıyorsa **bağ vardır**. Çapalı desenle ölçseydim **128 sahte öksüz**
  üretirdim; geniş desenle **23**. Fark ölçüldü, tahmin edilmedi.

## Ters yönün BİRİMİ — türetildi, elle liste DEĞİL (koordinatör şartı)

*"Kod değişikliği İDDİA eden kayıt"* tanımı **defterin kendi TÜR sütunundan**
okunur: `görev` iş iddia eder; `bulgu` · `risk` · `karar` · `ders` **etmez**
(ölçüldü: görev 51 · bulgu 49 · risk 12 · karar 10 · ders 4).

⚠️ **M-F-588 KISITI ÖNCE ÖLÇÜLDÜ, sonra tasarlandı.** *"Bir alana ayırt
edici değer eklerken, o alanı okuyan HER SAYACIN hangi dizgeye baktığı ÖNCE
ölçülür."* Ölçüm: `holding/bin/sensor-defter.py` bu defteri **venture dışından**
okuyor (`ventures/*/workspace/DEFTER.md`), satır deseni
`^\\|\\s*([A-Z]{1,3}-\\d+…)\\s*\\|` ve *"kapalı"* tespitini **dizge taramasıyla**
yapıyor. ⇒ Bu kapı defter biçimine **HİÇBİR alan EKLEMEDİ**; zaten var olan
sütunu **okuyor**. Eklemediğim için bozacak bir sayaç da yok.

> ***BİR BİRİMİ VERİDE ZATEN VAROLAN BİR ALANDAN TÜRETMEK, YENİ BİR ALAN
> EKLEYİP HER SAYACI YENİDEN ÖLÇMEKTEN UCUZDUR.***

## Beş tuzak, beşi de tasarıma gömülü

1. **SENTİNEL KARIŞMASI — ve eski çözümüm TAUTOLOJİYDİ (G-196).**
   Depoda `G-999` gibi kasıtlı sahte kayıtlar var. Eski öz-testim bunu
   `git grep -l G-999` ile kanıtlıyordu — **ama aranan dizge bu dosyanın
   KENDİ kaynağında** (docstring + `subprocess` argümanı). Ölçüldü:
   `git grep -l G-999` → 2 dosya, biri **bu dosyanın kendisi**. ⇒ Kontrolün
   *"sentinel depoda VAR"* yarısı **hiçbir koşulda yanlış olamazdı**; dış
   kaynak silinse bile geçerdi.

   > ***BİR DENETİM İKİ TARAFI AYNI KAYNAKTAN OKUYORSA TANIMDIR — VE BİR
   > TARAFINI KENDİNDEN OKUYAN DENETİM, TANIMIN EN SESSİZ HÂLİDİR.***

   Panzehir **iki parçalı**: ① `9xx` aralığı **yapısal olarak** ayrıldı
   (liste değil, aralık) ② dış çapa artık **kendi kaynağını DIŞLAYARAK**
   aranıyor, ve aralık dışlamasının çalıştığı **sentetik korpusta** —
   deponun hâline hiç bakmadan — kanıtlanıyor.
2. **SÖZÜNÜ ETMEK ≠ KAYIT OLMAK.** Yalnız **başlığın BAŞINDAKİ** `G-NNN`
   bir *iddiadır* (yön-1). Gövdedeki anma yalnız *bağ* sayılır (yön-2).
3. **PAYDA DENKLEM olarak denetlenir.** Çıktı *"N commit taradım"* demez;
   `atıflı + atıfsız = rev-list --count` **eşitliğini** sınar. Tutmuyorsa
   kapı **KENDİNE öter**: *bir sayının doğruluğu kendi kanıtı değildir.*
4. **TAVAN ZEHİRLENMESİ — düzyazı bir hüküm kaynağı sanıldı (G-221, 2026-08-16).**
   `G-220`nin kendi commit gövdesi, atılmış bir sabotaj denemesini anlatırken
   *"İlk denemem `G-500` idi"* dedi. **Geniş desen (yön-2) bunu gerçek bir
   BAĞ saydı** — doğru, çünkü öyleydi (metin `G-500`den bahsediyordu). Ama
   tavan (`ceiling`) o zaman `linked`ten türüyordu, ve `linked`e giren HER
   şey tavanı yükseltebiliyordu — bir sabotaj **anlatısı** bile. Sonuç:
   tavan `218`den `501`e **kalıcı olarak** sıçradı (git geçmişi geri
   alınamaz), ve `G-221` (gerçek, o turun gerçek işi) yanlışlıkla *"tavan
   altında, öksüz"* göründü.

   > ***BİR TAVAN, DÜZYAZIDA ANILAN HER SAYIYA AÇIKSA, O TAVANI ÖLÇÜM DEĞİL
   > DÜZYAZI YAZAR.***

   Panzehir: tavan artık **`claimed`ten (yön-1, çapalı)** türüyor, `linked`ten
   değil. Çapalı desen yalnız başlığın BAŞINI okur; bir commit başlığı
   gerçekte kaydetmediği bir işi iddia etmez — bu yüzden prose-anma tavanı
   artık şişiremez. `linked`in kendisi (yön-2, öksüz taraması) DEĞİŞMEDİ;
   yalnız tavan hangi kümeden türediği değişti. Bkz. öz-test ⑧.
5. **PROB NUMARALARI — YAPISAL panzehir TEK BAŞINA yetmez (Ostinato `O-111`,
   orkestratör hükmü `H-35`, 2026-08-16).** Tuzak 4'ün panzehiri tavanı
   bağışık kıldı, ama `linked`in KENDİSİ (öksüz taraması, ki bu doğru — bir
   *varlık* sorusu) `G-500`/`G-501`i hâlâ içeriyor. Beş hat ölçüldü:
   Gravita'nınki YAPISAL, Ostinato'nunki SÖZLEŞMESEL (`9xx` bandı + adıyla
   `PROBE_IDS`) — ve Ostinato'nun `O-111` vakası kanıtladı ki **tek bir prob
   numarası iki yönü BİRDEN bozabilir.** İkisi TAMAMLAYICI, biri ötekinin
   yerine geçmez.
   > ***BİR NUMARADAN SÖZ ETMEK ONU VAR EDER.***
   Panzehir: `PROBE_IDS = {500, 501}` — Ostinato'nun `9xx` sözleşmesi buraya
   da alındı, `_real()` artık ikisini de eler. **Gidişat kuralı yazılı:**
   prob numarası bundan sonra `9xx`ten seçilir; seçilmediyse `PROBE_IDS`e
   ADIYLA girer. Bkz. öz-test ⑨ (etkililik + GEREKÇE-ÇAPASI, ikisi ayrı
   sınanır — tuzak 1'in `G-999` çapasıyla aynı desen).

✅ DEFTER 2026-08-15'ten beri depo İÇİNDE (`workspace/DEFTER.md`, M-F-633 —
kurucu kararı). Bulunamazsa bu kapı **gürültüyle düşer** — bulunamayan bir
dosya üzerinden *"gedik yok"* raporlamak ölçüm değil körlüktür. Ve artık
yokluğu ortam eksikliği değil, **gerçek bir kayıp** demektir.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFTER = ROOT / "workspace" / "DEFTER.md"
SELF = Path(__file__).name

#: YÖN-1 (İDDİA): commit'in KENDİ iddiası — başlığın BAŞINDA `G-NNN`.
_CLAIM = re.compile(r"^(G-\d+)\b")
#: YÖN-2 (BAĞ): metnin herhangi bir yerinde anılan `G-NNN`.
_LINK = re.compile(r"\bG-\d+")

#: Defterdeki kayıt — **İKİ BİÇİM**, ve bunu ölçüm öğretti (G-194).
#: İlk yazımım yalnız `### G-NNN` tanıyordu → **47 yanlış pozitif**: defterin
#: ESKİ bölümü kayıtları **tablo satırı** tutuyor (`| G-043 | görev | …`).
#: → *Bir kapının kapsamı, ölçtüğü şeyin BÜTÜN biçimlerini tanımalıdır.*
#: Ölçüldü (2026-08-13): tablo 129 · prose 75 · kesişim 12 · **birleşik 192**.
_ENTRY = re.compile(r"^(?:### |\| )(G-\d+)\b", re.M)
#: TÜR sütunu — yalnız tablo biçiminde var: `| G-043 | görev | P1 | …`.
_TYPED = re.compile(r"^\|\s*(G-\d+)\s*\|\s*([^|]+?)\s*\|", re.M)

#: `görev` = kod/iş İDDİA EDER. Ötekiler etmez — bu ayrım **defterin kendi
#: sütunundan** gelir, benim sınıflandırmamdan değil.
WORK_TYPES = {"görev"}
NONWORK_TYPES = {"bulgu", "risk", "karar", "ders"}

#: 🔴 SENTİNEL ARALIĞI — `G-9xx` hiçbir zaman gerçek kayıt DEĞİLDİR; curated
#: fikstürlerde ve sabotaj anlatılarında ÖRNEK olarak anılır. **Liste değil
#: ARALIK**: yeni bir sentinel eklendiğinde bakım istemez.
SENTINEL_RANGE = range(900, 1000)

#: 🔴 SABOTAJ PROB NUMARALARI — kayıt DEĞİL, sabotaj anlatısında anılan ve
#: `9xx` ARALIĞININ DIŞINDA seçilmiş (Ostinato `O-111`in kardeşi, orkestratör
#: hükmü `H-35`, 2026-08-16). `G-223`ün kendi vakası: `G-220`nin commit
#: gövdesi *"ilk denemem `G-500`/`G-501` idi"* dedi — bu ikisi `9xx`
#: BANDINDA DEĞİLDİ, `SENTINEL_RANGE` onları göremedi, ve `linked`e
#: karışarak tavanı zehirledi (bkz. `ceiling` yorumu). Yapısal panzehir
#: (tavan artık `claimed`ten türüyor) bunu ÇÖZDÜ — ama `linked`in KENDİSİ
#: hâlâ geniştir (yön-2'nin görevi bu, daraltılmadı) ve 500/501 orada
#: duruyor. Kural artık yazılı: **prob numarası `9xx`ten seçilir**;
#: seçilmediyse buraya ADIYLA girer.
#:
#: ⚠️ MUAFİYETİN DAYANDIĞI VARSAYIM — adıyla: bu numaraların git geçmişinde
#: GEÇTİĞİ ölçümüne dayanır. Öz-test ⑨ bunu GEREKÇE-ÇAPASI olarak sınar:
#: numara geçmişten kaybolursa (rebase/filter-branch) muafiyet boşa koşar
#: ve çapa öter — bu bir KIRILGANLIK değil TASARIM (Ostinato'nun aynı
#: gerekçesi burada da geçerli: bu ağaçta `pull.rebase` ayarlı değil).
PROBE_IDS = {500, 501}

#: ⚖️ BUGÜN ÖLÇÜLEN BAĞ-KOPUKLUĞU BORCU — icat edilmiş eşik DEĞİL, bugünün
#: sayısının kendisi (G-187'nin bu depodaki `6 → 7` panzehiriyle aynı desen).
#:
#: Bunlar **gerçek kusurdur**, muafiyet değil: kaydın işi YAPILDI ve
#: commit'lendi, ama commit **numarayı hiç yazmadı** — bağ koptu. Kapı
#: bugünkü sayıyı taban alır ve **BÜYÜMESİNİ yasaklar**; küçülmesi serbest.
#: Sıfırlamak bu turun işi değil (ölçüm turu), ama **görünmez kalmaları** da
#: kabul edilmedi: her biri ADIYLA burada.
#:
#: ⚠️ Öz-test bu listeyi **çürütülebilir** kılar: her numara defterde HÂLÂ
#: kayıt olmalı. Kayıt silinir/yeniden numaralanırsa çapa öter — *bir
#: muafiyet ya ölçümünü taşır ya TÜRETİLİR* (bu hattın kendi kuralı).
KNOWN_UNLINKED_WORK = {
    10, 84, 92, 93, 98, 118, 122, 123, 128,
}
#: Aynı sınıf, ama **tür sütunu OLMAYAN** prose kayıtlar. Ayrı torba, çünkü
#: birinin birimi TÜRETİLDİ, ötekininki **türetilemedi** — ikisini tek listede
#: toplamak, aynı sayının iki farklı şeyi saymasıydı (Ostinato, O-108).
KNOWN_UNLINKED_UNTYPED = {
    167, 171, 172, 173, 174, 177, 179, 180,
}


def _num(gid: str) -> int:
    return int(gid.split("-")[1])


def _git(*args: str) -> str:
    return subprocess.run(["git", "-C", str(ROOT), *args],
                          capture_output=True, text=True).stdout


def _real(ids) -> set:
    """Sentinel aralığını VE adlandırılmış prob numaralarını ELER."""
    return {g for g in ids
            if _num(g) not in SENTINEL_RANGE and _num(g) not in PROBE_IDS}


def census() -> tuple[int, int, int]:
    """PAYDA DENETİMİ: atıflı + atıfsız = `rev-list --count`.

    Sayı değil DENKLEM, çünkü bir kapı *"N commit taradım"* diyebilir ve N
    yanlış olabilir — bölme kaçırırsa ya da `--format` bozulursa. Denklem
    tutmuyorsa **kapı KENDİNE öter.**
    """
    blob = _git("log", "--format=%H%x01%s%x01%b%x02")
    commits = [c.strip() for c in blob.split("\x02") if c.strip()]
    with_ref = [c for c in commits if _LINK.search(c)]
    total = int((_git("rev-list", "--count", "HEAD") or "0").strip() or 0)
    return len(with_ref), len(commits) - len(with_ref), total


def claimed_ids() -> set:
    """YÖN-1 girdisi: commit BAŞLIĞININ BAŞINDA numara = *iddia*."""
    return _real({m.group(1) for line in _git("log", "--format=%s").splitlines()
                  if (m := _CLAIM.match(line.strip()))})


def linked_ids() -> set:
    """YÖN-2 girdisi: başlık VEYA gövdede anılan numara = *bağ*."""
    return _real(set(_LINK.findall(_git("log", "--format=%s%n%b"))))


def defter_entries() -> tuple[set, dict]:
    if not DEFTER.exists():
        raise SystemExit(
            f"⛔ DEFTER BULUNAMADI ({DEFTER}) — bulunamayan bir dosya "
            f"üzerinden 'gedik yok' raporlamak ölçüm değil KÖRLÜKTÜR.")
    text = DEFTER.read_text(encoding="utf-8")
    ids = _real(set(_ENTRY.findall(text)))
    types = {g: t.strip().strip("*").strip() for g, t in _TYPED.findall(text)
             if _num(g) not in SENTINEL_RANGE}
    return ids, types


def analyse() -> dict:
    claimed, linked = claimed_ids(), linked_ids()
    defter, types = defter_entries()
    # YÖN-1 — iddia edildi, kaydedilmedi.
    missing = sorted(claimed - defter, key=_num)
    # YÖN-2 — kayıt var, bağı yok. Tavan TÜRETİLİR: commit'lenmiş en yüksek
    # numaranın ÜSTÜ "uçuşta"dır (kaydı commit'ten ÖNCE yazmak DOĞRU
    # alışkanlıktır ve ceza almamalı). Muafiyet listesi değil, türetim.
    #
    # ⚠️ TAVAN `claimed`TEN (yön-1, ÇAPALI) türetilir, `linked`TEN (yön-2, GENİŞ)
    # DEĞİL — G-221 vakası (2026-08-16). Bir commit gövdesi, atılmış bir sabotaj
    # denemesini ANLATIRKEN sahte bir numaradan söz edebilir ("G-500 denedim,
    # işe yaramadı"); geniş desen bunu GERÇEK bir bağ sanır ve tavanı o sahte
    # numaraya kalıcı olarak ŞİŞİRİR (git geçmişi geri alınamaz). Çapalı desen
    # bağışıktır: yalnız başlığın BAŞINDAKİ numarayı sayar, ve bir commit
    # başlığı gerçekte KAYDETMEDİĞİ bir işi iddia etmez.
    # > BİR TAVAN, DÜZYAZIDA ANILAN HER SAYIYA AÇIKSA, O TAVANI DÜZYAZI YAZAR —
    # > ÖLÇÜM DEĞİL.
    ceiling = max((_num(g) for g in claimed), default=0)
    unlinked = defter - linked
    inflight = sorted((g for g in unlinked if _num(g) > ceiling), key=_num)
    below = [g for g in unlinked if _num(g) <= ceiling]
    work, untyped, nonwork = [], [], []
    for g in sorted(below, key=_num):
        t = types.get(g)
        if t is None:
            untyped.append(g)
        elif t in WORK_TYPES:
            work.append(g)
        elif t in NONWORK_TYPES:
            nonwork.append(g)
        else:                       # işaretçi satırları vb.
            nonwork.append(g)
    return dict(missing=missing, work=work, untyped=untyped, nonwork=nonwork,
                inflight=inflight, ceiling=ceiling, defter=defter,
                types=types, claimed=claimed, linked=linked)


def run() -> int:
    a = analyse()
    with_ref, without_ref, total = census()
    bad = False

    print(f"   payda: atıflı {with_ref} + atıfsız {without_ref} = "
          f"{with_ref + without_ref} · rev-list {total} · defterde "
          f"{len(a['defter'])} kayıt (türü olan {len(a['types'])})")

    # ⓪ PAYDA — kapı önce KENDİNE bakar.
    if with_ref + without_ref != total:
        print(f"⛔ PAYDA TUTMUYOR: {with_ref}+{without_ref} ≠ {total} — tarama "
              f"commit KAYBEDİYOR; bu kapının HER sonucu şüpheli "
              f"(bir sayının doğruluğu kendi kanıtı değildir)")
        bad = True

    # ⓪b VAKUM — iki yol da dolu mu?
    if not a["claimed"] or not a["linked"] or not a["defter"]:
        print("⛔ VAKUM: taramanın bir yolu BOŞ — 'taze' hükmü GEÇERSİZ "
              f"(iddia {len(a['claimed'])} · bağ {len(a['linked'])} · "
              f"defter {len(a['defter'])})")
        return 1

    # ① YÖN-1: commit iddia etti, defter yazmadı.
    if a["missing"]:
        print(f"⛔ DEFTER GEDİĞİ (yön-1) — {len(a['missing'])} kayıt commit'in "
              f"BAŞLIĞINDA iddia edilmiş, defterde YOK: "
              f"{', '.join(a['missing'])}")
        print("   Bir işin YAPILMIŞ olması, KAYDEDİLMİŞ olması değildir.")
        bad = True

    # ② YÖN-2: kayıt var, hiçbir commit anmıyor.
    new_work = sorted(set(map(_num, a["work"])) - KNOWN_UNLINKED_WORK)
    new_untyped = sorted(set(map(_num, a["untyped"])) - KNOWN_UNLINKED_UNTYPED)
    if new_work or new_untyped:
        print(f"⛔ BAĞ KOPTU (yön-2) — {len(new_work) + len(new_untyped)} YENİ "
              f"kayıt defterde VAR, hiçbir commit anmıyor: "
              f"{', '.join('G-%03d' % n for n in new_work + new_untyped)}")
        print("   Kaydın işi commit'lendiyse commit onu ADIYLA anmalı; "
              "anmıyorsa bağ yalnız hafızada yaşar.")
        bad = True

    if bad:
        return 1

    print(f"✅ defter TAZE — İKİ YÖNDE: eksik 0 · yeni bağ-kopukluğu 0")
    print(f"   yön-1 (İDDİA, çapalı desen): commit başlığında "
          f"{len(a['claimed'])} numara → hepsi defterde")
    print(f"   yön-2 (BAĞ, geniş desen): tavan G-{a['ceiling']:03d} · "
          f"kod iddia ETMEYEN {len(a['nonwork'])} (tür sütunundan TÜRETİLDİ) · "
          f"uçuşta {len(a['inflight'])}")
    print(f"   ⚖️ ÖLÇÜLMÜŞ BORÇ (büyümesi yasak, adıyla): bağı kopuk "
          f"görev {len(a['work'])} · türsüz {len(a['untyped'])}")
    return 0


def _self_test() -> int:
    dead: list[str] = []
    a = analyse()

    # ① TABAN — bugünkü ağaç iki yönde de temiz mi?
    if a["missing"]:
        dead.append(f"TABAN KİRLİ: yön-1 gediği var {a['missing']}")
    # ⚠️ ALT KÜME, EŞİTLİK DEĞİL — ve bu ayrım BEDELLE öğrenildi (G-197).
    #
    # İlk yazımım `!=` ile EŞİTLİK arıyordu. G-196'nın commit MESAJI `G-179`u
    # andı → bağ kuruldu → borç 8'den 7'ye DÜŞTÜ → ve öz-testim bu
    # **İYİLEŞMEYİ KIRMIZI** bastı. Yani aynı gece `metric_support`ta ADIYLA
    # raporladığım kusurun (M-F-598) tıpatıp aynısını kendi kapıma yazdım.
    #
    #   > ***Bir kapı, kendi ürününün İLERLEMESİNİ cezalandırıyorsa, o kapı
    #   > ürünün DÜŞMANIDIR*** — ve bu hattın kendi kuralıdır.
    #
    # 📌 Ve tuzağın biçimi öğretici: kapı **commit'ten ÖNCE** yeşildi (hook
    # o an koştu), **commit'ten SONRA** kırmızı oldu — çünkü kaydı bağlayan
    # şey commit'in KENDİ mesajıydı. *Bir kapının girdisi, o kapıyı taşıyan
    # commit'in kendisiyse, kapı kendi doğuşuyla durum değiştirir.*
    grown_w = sorted(set(map(_num, a["work"])) - KNOWN_UNLINKED_WORK)
    grown_u = sorted(set(map(_num, a["untyped"])) - KNOWN_UNLINKED_UNTYPED)
    if grown_w or grown_u:
        dead.append(
            f"BORÇ BÜYÜDÜ: kayıtlı tabanın DIŞINDA bağı kopuk kayıt var — "
            f"görev {grown_w or '—'} · türsüz {grown_u or '—'}")

    # ② BORCUN ÇÜRÜTÜLEBİLİRLİĞİ — listedeki her numara defterde HÂLÂ kayıt
    #    olmalı. *Bir muafiyet ya ölçümünü taşır ya TÜRETİLİR.*
    live = {_num(g) for g in a["defter"]}
    stale = sorted((KNOWN_UNLINKED_WORK | KNOWN_UNLINKED_UNTYPED) - live)
    if stale:
        dead.append(f"BORÇ LİSTESİ BAYAT: {stale} artık defterde kayıt DEĞİL "
                    f"— muafiyet gerekçesiz koşuyor")

    # ③ İKİ DESENİN ERİŞİMİ — SENTETİK korpusta, deponun HÂLİNDE değil.
    #    (Deponun disiplinine kapı kurmak, iyileşmeyi kusur diye basardı.)
    corpus = ["G-101: başta çapalı — iki desen de görür",
              "fix: bkz. G-102 — yalnız GENİŞ desen görür",
              "refactor: numara yok — hiçbir desen görmez"]
    anchored = len([l for l in corpus if _CLAIM.match(l)])
    wide = len([l for l in corpus if _LINK.search(l)])
    if (anchored, wide) != (1, 2):
        dead.append(f"DESEN ERİŞİMİ bozuk: sentetik korpusta (çapalı 1, "
                    f"geniş 2) beklenirken ({anchored}, {wide}) — ya çapa "
                    f"`^` kaybolmuş ya geniş desen daralmış; ikisi de bu "
                    f"kapının İKİ YÖNÜNÜ birden çökertir")
    if len([l for l in ["G-1 a", "G-2 b"] if _CLAIM.match(l)]) != 2:
        dead.append("tam disiplinli korpusta çapalı desen eksik buluyor — "
                    "çapalı=geniş bir İYİLEŞMEDİR, kusur değil")
    if any(_CLAIM.match(l) for l in []) or _LINK.search("") is not None:
        dead.append("VAKUM: boş girdiden isabet döndü")

    # ④ SENTİNEL — aralık dışlaması SENTETİK girdide kanıtlanır.
    #    ⚠️ Eski hâli `git grep -l G-999` idi ve TAUTOLOJİYDİ: aranan dizge
    #    bu dosyanın KENDİ kaynağında. Artık depoya hiç bakmadan sınanıyor.
    if _real({"G-999", "G-900", "G-042"}) != {"G-042"}:
        dead.append("SENTİNEL SIZDI: `9xx` aralığı elenmiyor — curated "
                    "fikstür girdiye karışabilir")
    if _real({"G-899"}) != {"G-899"}:
        dead.append("SENTİNEL ARALIĞI FAZLA GENİŞ: G-899 elendi, oysa "
                    "ayrılan aralık 900-999")

    # ⑤ DIŞ ÇAPA — sentinel riski CANLI mı? Kendi kaynağımı DIŞLAYARAK ara.
    #    Bu, ④'ün tamamlayıcısı: ④ mekanizmanın çalıştığını, ⑤ korunan
    #    riskin hâlâ var olduğunu ölçer.
    hits = [f for f in _git("grep", "-l", "G-999").split()
            if not f.endswith(SELF)]
    if not hits:
        dead.append("SENTİNEL ÇAPASI ÖLÜ: `G-999` bu dosya DIŞINDA hiçbir "
                    "yerde geçmiyor — aralık muafiyeti gerekçesiz koşuyor "
                    "(gerekçe bayatladı ya da fikstür silindi)")

    # ⑥ SÖZÜNÜ ETMEK ≠ KAYIT — iki yönün desen ayrımı gerçekten çalışıyor mu?
    if _CLAIM.match("bkz. G-182 — bu commit ONUN DEĞİL") is not None:
        dead.append("'sözünü etmek ≠ kayıt' AYRIMI YOK: gövde atfı iddia "
                    "sayılıyor")
    if _CLAIM.match("G-182'nin ölçümüyle ilgili not") is None:
        dead.append("çapalı desen kendi biçimini tanımıyor")

    # ⑦ PAYDA denklemi öz-testte de sınanır.
    w, wo, tot = census()
    if w + wo != tot:
        dead.append(f"PAYDA denklemi tutmuyor ({w}+{wo}≠{tot}) — kapının "
                    f"kendi sayımı commit kaybediyor")

    # ⑧ TAVAN ZEHİRLENMESİ KAPANDI — G-221 vakasının regresyon testi (2026-08-16).
    #    Bir commit gövdesi, atılmış bir sabotaj denemesini ANLATIRKEN sahte
    #    yüksek bir numaradan söz edebilir; bu GERÇEK bir bağdır (yön-2) ama
    #    GERÇEK bir iddia DEĞİLDİR (yön-1). Tavan artık `claimed`ten türediği
    #    için bu düzyazı anması tavanı ŞİŞİRMEMELİ — ve yön-2'nin kendisi de
    #    (başka amaçlarla, örn. mevcut bir kaydı bağlamak) bozulmamalı.
    poison_subject = "G-220: gercek baslik, gercek iddia"
    poison_body = "Ilk denemem G-500 idi ama ise yaramadi, geri aldim."
    poison_blob = poison_subject + "\n" + poison_body
    claimed_from_poison = {m.group(1) for line in poison_blob.splitlines()
                            if (m := _CLAIM.match(line.strip()))}
    linked_from_poison = set(_LINK.findall(poison_blob))
    if claimed_from_poison != {"G-220"}:
        dead.append(f"ÇAPALI DESEN sahte gövde anmasını İDDİA sanıyor: "
                    f"{claimed_from_poison} (yalnız G-220 beklenirdi)")
    if "G-500" not in linked_from_poison:
        dead.append("GENİŞ DESEN artık düzyazı anmasını hiç görmüyor — "
                    "yön-2'nin kendisi bozulmuş (bu AYRI bir kusur olurdu)")

    # ⑨ PROB NUMARALARI — Ostinato'nun `O-111`/`O-116` sözleşmesi, `H-35`
    #    hükmüyle buraya taşındı. ⑧ yalnız YAPISAL panzehiri (tavan artık
    #    `claimed`ten türüyor) sınar; bu, TAMAMLAYICI sözleşmeyi sınar —
    #    500/501 hiçbir hesaba (claimed/linked/defter) GERÇEKTEN karışmıyor
    #    mu. İki taraflı: ① muafiyet ETKİLİ mi (sızmıyor) ② muafiyet BOŞA mı
    #    koşuyor (gerekçesi git geçmişinden silinmiş mi — GEREKÇE-ÇAPASI).
    if _real({"G-500", "G-501", "G-042"}) != {"G-042"}:
        dead.append("PROB SIZDI: G-500/G-501 `_real()`den hâlâ geçiyor — "
                    "prob muafiyeti etkisiz (Ostinato'nun O-111 dersi kayboldu)")
    if "G-500" in claimed_ids() | linked_ids():
        dead.append("PROB SIZDI: G-500 gerçek claimed/linked kümesinde HÂLÂ "
                    "var — filtre `_real()`den geçmeyen bir yoldan besleniyor")
    probe_log = _git("log", "--format=%s%n%b")
    for pid in sorted(PROBE_IDS):
        if f"G-{pid}" not in probe_log:
            dead.append(f"PROB ÇAPASI ÖLÜ: `G-{pid}` git geçmişinde artık "
                        f"YOK — muafiyet gerekçesiz koşuyor, taban daraltılmalı")

    if dead:
        print(f"⛔ {len(dead)} ÖLÜ DESEN (defter tazeliği öz-testi DÜŞTÜ):")
        for d in dead:
            print(f"   - {d}")
        return 1
    # ⚖️ KÜÇÜLME KUSUR DEĞİL — ama SESSİZ de kalmamalı, yoksa taban bayatlar
    # ve bir gün "borç 9" derken gerçek 3 olur. Rapor edilir, kapı yapılmaz.
    paid_w = sorted(KNOWN_UNLINKED_WORK - set(map(_num, a["work"])))
    paid_u = sorted(KNOWN_UNLINKED_UNTYPED - set(map(_num, a["untyped"])))
    paid = ""
    if paid_w or paid_u:
        paid = (f" · ⭐ BORÇ ÖDENDİ (taban daraltılabilir): "
                f"{', '.join('G-%03d' % n for n in paid_w + paid_u)}")
    print(f"✅ 9/9 kapı ateşlendi — İKİ YÖN ayrı desenle sınandı (çapalı 1 ⊆ "
          f"geniş 2, sentetik korpusta) · sentinel aralığı depoya BAKMADAN "
          f"kanıtlandı + dış çapa canlı · borç tabanı ALT KÜME olarak "
          f"sınandı ({len(KNOWN_UNLINKED_WORK)} görev + "
          f"{len(KNOWN_UNLINKED_UNTYPED)} türsüz, hepsi defterde) · "
          f"payda denklemi tutuyor · tavan zehirlenmesi + prob numaraları "
          f"ayrı sınandı{paid}")
    return 0


if __name__ == "__main__":
    sys.exit(_self_test() if "--self-test" in sys.argv else run())
