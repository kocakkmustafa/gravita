#!/usr/bin/env python3
"""G1/D1 veri toplama — Wikimedia Commons (açık API, lisans metadata kaynakta).

Protokol: docs/gates/G1-D1-PROTOKOL.md §4, §7.
Ham medya repoya girmez; yalnız türetilmiş landmark/metrik çıktıları girer.
"""
import json, os, re, sys, time, urllib.parse, urllib.request

API = "https://commons.wikimedia.org/w/api.php"
UA = "YulaMotion-D1-FeasibilityGate/0.1 (research measurement; contact: kocakmkaan@gmail.com)"

INV_TERMS = [
    "handstand", "Adho Mukha Vrksasana", "headstand yoga", "Sirsasana",
    "handstand gymnastics", "acroyoga handstand", "handstand beach",
    "Salamba Sirsasana", "handstand wall", "gymnast handstand",
]
UPR_TERMS = [
    "Tadasana", "Virabhadrasana", "yoga standing pose", "gymnast standing",
    "person standing full body portrait", "athlete standing full body",
]

def api(params):
    params = dict(params, format="json", formatversion=2)
    url = API + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.load(r)

def strip_html(s):
    return re.sub(r"<[^>]+>", "", s or "").strip()

def search(term, limit=40):
    try:
        d = api({
            "action": "query", "generator": "search", "gsrsearch": f'filetype:bitmap {term}',
            "gsrnamespace": "6", "gsrlimit": str(limit),
            "prop": "imageinfo", "iiprop": "url|size|mime|extmetadata",
            "iiurlwidth": "900",
        })
    except Exception as e:
        print(f"  ! {term}: {e}", file=sys.stderr)
        return []
    return d.get("query", {}).get("pages", [])

def collect(terms, bucket, want, seen):
    out = []
    for term in terms:
        if len(out) >= want:
            break
        pages = search(term)
        print(f"  [{bucket}] '{term}' -> {len(pages)} sonuç")
        for p in pages:
            if len(out) >= want:
                break
            ii = (p.get("imageinfo") or [{}])[0]
            if not ii or ii.get("mime") not in ("image/jpeg", "image/png"):
                continue
            w, h = ii.get("width", 0), ii.get("height", 0)
            if w < 400 or h < 400:
                continue
            title = p["title"]
            if title in seen:
                continue
            em = ii.get("extmetadata", {})
            lic = strip_html(em.get("LicenseShortName", {}).get("value", ""))
            # Protokol §7: yalnız açıkça özgür lisanslar
            if not lic or not re.match(r"(CC0|CC BY|Public domain|PDM|GFDL)", lic, re.I):
                continue
            seen.add(title)
            out.append({
                "bucket": bucket,
                "title": title,
                "file": re.sub(r"[^A-Za-z0-9._-]", "_", title.replace("File:", "")),
                "thumb_url": ii.get("thumburl") or ii.get("url"),
                "descriptionurl": ii.get("descriptionurl"),
                "license": lic,
                "license_url": strip_html(em.get("LicenseUrl", {}).get("value", "")),
                "artist": strip_html(em.get("Artist", {}).get("value", ""))[:160],
                "width": w, "height": h,
            })
        time.sleep(0.4)
    return out

def download(items, root):
    ok = []
    for it in items:
        d = os.path.join(root, it["bucket"])
        os.makedirs(d, exist_ok=True)
        path = os.path.join(d, it["file"])
        if not path.lower().endswith((".jpg", ".jpeg", ".png")):
            path += ".jpg"
        it["path"] = path
        if os.path.exists(path) and os.path.getsize(path) > 5000:
            ok.append(it); continue
        try:
            req = urllib.request.Request(it["thumb_url"], headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r, open(path, "wb") as f:
                f.write(r.read())
            ok.append(it)
        except Exception as e:
            print(f"  ! indirilemedi {it['title']}: {e}", file=sys.stderr)
        time.sleep(0.25)
    return ok

if __name__ == "__main__":
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "media")
    seen = set()
    print("INV (ters-duruş) toplanıyor...")
    inv = collect(INV_TERMS, "inv", 60, seen)
    print("UPR (dik kontrol) toplanıyor...")
    upr = collect(UPR_TERMS, "upr", 40, seen)
    items = download(inv, root) + download(upr, root)
    with open(os.path.join(root, "veri-envanteri.json"), "w") as f:
        json.dump(items, f, indent=2, ensure_ascii=False)
    print(f"\nİndirildi: {sum(1 for i in items if i['bucket']=='inv')} INV + "
          f"{sum(1 for i in items if i['bucket']=='upr')} UPR")
    lic = {}
    for i in items:
        lic[i["license"]] = lic.get(i["license"], 0) + 1
    print("Lisans dağılımı:", lic)
