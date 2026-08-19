#!/usr/bin/env python3
"""RELEASE İMZASI SESSİZ-DÜŞÜŞ KAPISI (GRA-P0-003) — kaynak-metin denetimi.

## Neden var

`android/app/build.gradle.kts` (G-192, 2026-08-12) zaten iki parçalı bir
kapı taşıyor: ① `signingConfig` seçimi (`key.properties` VARSA gerçek imza,
`allowDebugSigning` bayrağı VARSA debug, aksi hâlde `null`) ② ayrı bir
`gradle.taskGraph.whenReady` bloğu — release görevi çalışırken imza kimliği
YOKSA ve debug'a bilerek geçilmediyse `GradleException` fırlatır. Aile
emsalleri (Lissom `release_signing_check.py`, Ostinato
`validate_release_signing.py`) bu deseni AYNI aileden ama farklı gradle
yapılarına karşı ölçüyor — Gravita'nın yapısı onlardan FARKLI: enforcement
`release { }` bloğunun İÇİNDE değil, AYRI bir `whenReady` bloğunda. Bir
kapının deseni başka bir hattan birebir kopyalanırsa Gravita'nın gerçek
yapısını hiç görmez (`release { }` içinde `GradleException` arardı, hiç
bulamazdı) — bu yüzden bu dosya Gravita'nın GERÇEK kaynağına göre yazıldı.

⚠️ Bu kapı imza ÜRETMEZ ve keystore ARAMAZ. Keystore kurucunun kalemidir ve
workspace'te DURMAZ (`~/.secrets/yula/`). Kapının sorusu tek: *release,
imzasızken SESSİZCE üretilebiliyor mu?*

    python3 tools/validate_release_signing.py            # gerçek dosyayla
    python3 tools/validate_release_signing.py --self-test # sabotaj + pozitif ikiz
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GRADLE = ROOT / "android" / "app" / "build.gradle.kts"


def check(src: str) -> list[str]:
    """Kusurları döndürür; boş liste = geçti. Yorumlar DÜŞÜLÜR — bir kuralın
    yorumda geçmesi onu uygulamaz (aile dersi: kelimenin varlığı, çağrının
    çalıştığı değildir)."""
    code = re.sub(r"//[^\n]*", " ", src)
    problems: list[str] = []

    # ① Seçim mantığı: key.properties VARSA gerçek imza, YOKSA null/debug —
    #    hiçbir dalda "her zaman debug" gibi koşulsuz bir düşüş olmamalı.
    m = re.search(r"signingConfig\s*=\s*when\s*\{(.*?)\n\s{4}\}", code, re.S)
    if m is None:
        problems.append(
            "`signingConfig = when { … }` seçim bloğu bulunamadı — kapı "
            "ölçemediği bir şeyi geçirmez (yapı değiştiyse kapı da "
            "güncellenmeli)"
        )
    else:
        selection = m.group(1)
        if "keyPropsFile.exists()" not in selection:
            problems.append(
                "seçim bloğu gerçek keystore varlığını (`keyPropsFile."
                "exists()`) KONTROL ETMİYOR — koşulsuz bir imza yoluna "
                "düşebilir"
            )
        if "-> null" not in selection and "else -> null" not in selection:
            problems.append(
                "seçim bloğunun `else` dalı `null` DEĞİL — imza kimliği "
                "yokken ve debug'a bilerek geçilmediğinde SESSİZ bir "
                "imzaya (debug'a) düşebilir"
            )

    # ② Gürültülü durdurucu: AYRI bir whenReady bloğu, release görevinde
    #    imza kimliği yokken GradleException fırlatmalı — key.properties
    #    yokluğu VE debug'a bilerek geçilmemiş olması BİRLİKTE.
    w = re.search(r"gradle\.taskGraph\.whenReady\s*\{(.*)\z", code, re.S)
    if w is None:
        problems.append(
            "`gradle.taskGraph.whenReady { … }` durdurucu bloğu YOK — "
            "seçim mantığı `null` dese bile hiçbir görev bunu GÜRÜLTÜLÜ "
            "durdurmaz, imzasız artefakt sessizce üretilebilir"
        )
        return problems

    block = w.group(1)
    if "throw GradleException(" not in block:
        problems.append(
            "`whenReady` bloğunda `throw GradleException(` YOK — durdurucu "
            "sessiz, konuşmuyor"
        )
    if "allowDebugSigning" not in block:
        problems.append(
            "`whenReady` bloğu `allowDebugSigning` bayrağını hiç OKUMUYOR — "
            "debug'a bilerek geçiş açık bir KARAR olamaz, ya hep engellenir "
            "ya hiç ayırt edilmez"
        )
    if "keyProps.exists()" not in block and "keyPropsFile.exists()" not in block:
        problems.append(
            "`whenReady` bloğu gerçek keystore varlığını KONTROL ETMİYOR — "
            "her release görevini (gerçek imza varken bile) durdurabilir "
            "ya da hiç durdurmayabilir"
        )
    # Görev filtresi: release görevleri dışındaki (debug build vb.) işleri
    # yanlışlıkla durdurmamalı — filtre olmadan kapı FAZLA GENİŞ olur.
    if '.contains("Release")' not in block and 'name.contains("Release")' not in block:
        problems.append(
            "`whenReady` bloğu RELEASE görevlerine daraltılmamış görünüyor "
            "— debug build'leri de yanlışlıkla durdurabilir (fazla-geniş "
            "kapı, ürünün kendi düşmanı olur)"
        )

    return problems


def _self_test() -> int:
    ok = 0
    total = 0

    def expect(name: str, src: str, *, shouldFail: bool) -> None:
        nonlocal ok, total
        total += 1
        problems = check(src)
        fired = bool(problems)
        if fired == shouldFail:
            ok += 1
        else:
            state = "ateşlendi" if fired else "SESSİZ kaldı"
            print(f"⛔ {name}: {state} (beklenen: "
                  f"{'ateşlensin' if shouldFail else 'sessiz kalsın'})")
            for p in problems:
                print(f"   · {p}")

    # POZİTİF İKİZ: Gravita'nın GERÇEK, bugün doğru olan yapısının küçük bir
    # kopyası — hiçbir kural ateşlenmemeli.
    real_shape = """
    android {
        signingConfigs {
            if (keyPropsFile.exists()) {
                create("release") { }
            }
        }
        buildTypes {
            release {
                signingConfig = when {
                    keyPropsFile.exists() -> signingConfigs.getByName("release")
                    allowDebugSigning -> signingConfigs.getByName("debug")
                    else -> null
                }
            }
        }
    }
    gradle.taskGraph.whenReady {
        val releaseTasks = allTasks.filter {
            it.project == project && it.name.contains("Release")
        }
        if (releaseTasks.isEmpty()) return@whenReady
        val keyProps = rootProject.file("key.properties")
        val allowDebug = (project.findProperty("allowDebugSigning") as String?) == "true"
        if (keyProps.exists()) return@whenReady
        if (allowDebug) {
            logger.warn("debug ile imzalanıyor")
            return@whenReady
        }
        throw GradleException("imzasız release")
    }
    """
    expect("pozitif ikiz (gerçek yapı)", real_shape, shouldFail=False)

    # SABOTAJ ①: whenReady bloğu TAMAMEN silinmiş — seçim mantığı dursa bile
    # hiçbir şey durdurmaz.
    no_enforcement = re.sub(
        r"gradle\.taskGraph\.whenReady.*", "", real_shape, flags=re.S)
    expect("sabotaj: whenReady silindi", no_enforcement, shouldFail=True)

    # SABOTAJ ②: whenReady kalıyor ama GradleException kaldırılmış (sessizce
    # geçiyor).
    no_throw = real_shape.replace(
        'throw GradleException("imzasız release")', "// (durdurulmuyor)")
    expect("sabotaj: GradleException kaldırıldı", no_throw, shouldFail=True)

    # SABOTAJ ③: allowDebugSigning kontrolü kaldırılmış — debug'a düşüş artık
    # bilerek bir KARAR değil.
    no_optin = real_shape.replace(
        'val allowDebug = (project.findProperty("allowDebugSigning") as String?) == "true"',
        'val allowDebug = true  // her zaman izinli — kapı kördü',
    ).replace("allowDebugSigning", "REMOVED_NAME")
    expect("sabotaj: allowDebugSigning bayrağı kaldırıldı", no_optin,
           shouldFail=True)

    # SABOTAJ ④: görev filtresi kaldırılmış (her görevde durur, fazla geniş).
    no_filter = real_shape.replace(
        'it.name.contains("Release")', 'true')
    expect("sabotaj: görev filtresi kaldırıldı (fazla-geniş)", no_filter,
           shouldFail=True)

    # VAKUM: yorumda geçen kelimeler kapıyı geçirmemeli.
    commented_only = """
    // throw GradleException ve allowDebugSigning burada sadece YORUMDA geçiyor
    // keyPropsFile.exists() de yorumda
    """
    expect("vakum: yalnız yorumda geçen kelimeler", commented_only,
           shouldFail=True)

    print(f"  öz-test: {ok}/{total} {'✅' if ok == total else '⛔'}")
    return 0 if ok == total else 1


def main() -> int:
    if "--self-test" in sys.argv:
        return _self_test()

    if not GRADLE.exists():
        print(f"⛔ {GRADLE.relative_to(ROOT)} yok")
        return 1
    problems = check(GRADLE.read_text(encoding="utf-8"))
    if problems:
        print("⛔ RELEASE İMZASI KAPISI — kırmızı:")
        for p in problems:
            print(f"   · {p}")
        return 1
    print("✅ release imzası: sessiz düşüş YOK (seçim mantığı + gürültülü "
          "durdurucu + görev-daraltmalı allowDebugSigning opt-in ikisi de "
          "sağlam)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
