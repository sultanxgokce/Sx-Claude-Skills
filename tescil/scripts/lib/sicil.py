#!/usr/bin/env python3
"""sicil.py — Mühürdarlık · sicil (isabet bölümü) + ders çıkarma + askı (G11 · S9 · S10; kadro şeması §6-§7).

Alt-komutlar (sicil.sh çağırır):
  isabet <mühürdar> --gorev G --gereklilik Gi --muhur ✓|✗ --sultan katiliyorum|saglanmadi --kaynak <ref>
         [--neden "<Sultan'ın tek cümlesi>"] [--g-tur <tur>] [--bassiz] [--el-kitabi-surum v]
  durum  <mühürdar> [--json]
  ders   <mühürdar> [--json]
  ders-bagla <mühürdar> --isabet-ts <ts> --ders D-NNN

Kayıt yeri: personelin özlük dosyası `<SICIL_DIZIN>/<personel_no>.yaml` → `isabet:` bölümü (append-only; silinmez, ters
kayıtla düzeltilir). Yeni defter KURULMAZ (S9). Satır §6 biçimidir + üç ek alan: `g_tur` (gereklilik türü — ders çıkarma
gruplar), `neden` (Sultan'ın tek cümlesi), `kaynak` (Sultan'ın kaydı — A06). Satırlar JSON nesnesidir (YAML alt kümesi).

🔴 A06: `sultan:` alanı Sultan'ın hükmüdür; ajan üretemez. Yazıcı yalnız Sultan'ın KAYDINA dayanarak yazar: `--kaynak`
   teslim ekranı kararı (`teslim:<kimlik>`) ya da D1 damgası (`YYYY-MM-DD Sultan: … (sohbet · <ref> · "<kırpık>" · beyan:<AJAN>)`).
   Kaynaksız / biçimsiz → rc 2, satır yazılmaz.
RC: 0 tamam · 2 kullanım/biçim/kaynak · 3 ölçülemedi (özlük dosyası yok, YAML okunamadı) — yazılmaz.
"""
import datetime
import json
import os
import re
import sys

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None

HERE = os.path.dirname(os.path.abspath(__file__))
SICIL_DIZIN = os.environ.get("SICIL_DIZIN", "/config/projects/Nexus/_agents/federe/sicil")
TARIF_KAYDI = os.environ.get("TARIF_KAYDI", "/config/.claude/skills/tarif-kaydi/veri/kadro-tarifleri.json")
EL_KITABI = os.environ.get("EL_KITABI", os.path.join(HERE, "..", "..", "SKILL.md"))
VARSAYILAN_ESIK = {"kacirma": 2, "pencere": 10}   # Sultan S10 (21 Eki): son 10 mühürde 2 kaçırma
D1 = re.compile(r'^\d{4}-\d{2}-\d{2} Sultan: .+ \(sohbet · \S+ · ".+" · beyan:\S+\)$')
TESLIM = re.compile(r"^teslim:[A-Za-z0-9_.-]{6,}$")
DERS_ID = re.compile(r"^D-\d{3}$")


def hata(m, rc=2):
    print(f"✗ {m}", file=sys.stderr)
    sys.exit(rc)


def simdi():
    # mikrosaniye: ts satırın anahtarıdır (ders-bagla ts ile bağlar); saniyede birden çok satır düşebilir (sınavda ölçüldü)
    return datetime.datetime.now().astimezone().isoformat(timespec="microseconds")


def ozluk_bul(ad):
    """mühürdarın özlük dosyası: `persona:` alanı ada eşit (casefold) olan TEK dosya."""
    if not os.path.isdir(SICIL_DIZIN):
        hata(f"sicil dizini yok: {SICIL_DIZIN} — ölçülemedi", 3)
    bulunan = []
    for f in sorted(os.listdir(SICIL_DIZIN)):
        if not f.endswith(".yaml"):
            continue
        with open(os.path.join(SICIL_DIZIN, f), encoding="utf-8") as h:
            for satir in h:
                m = re.match(r"^persona:\s*(\S+)", satir)
                if m and m.group(1).strip("\"'").casefold() == ad.casefold():
                    bulunan.append(os.path.join(SICIL_DIZIN, f)); break
    if not bulunan:
        hata(f"{ad} için özlük dosyası YOK ({SICIL_DIZIN}) — isabet yazılmadı; özlük açmak KÂHYA'nın işi (/ise-alim)", 3)
    if len(bulunan) > 1:
        hata(f"{ad} için birden çok özlük dosyası: {', '.join(os.path.basename(b) for b in bulunan)} — hangisi bilinmeden yazılmaz", 3)
    return bulunan[0]


def oku(yol):
    if yaml is None:
        hata("PyYAML yok — sicil okunamadı (ölçülemedi)", 3)
    try:
        with open(yol, encoding="utf-8") as h:
            return yaml.safe_load(h) or {}
    except yaml.YAMLError as e:
        hata(f"özlük dosyası YAML değil ({os.path.basename(yol)}): {e}", 3)


def isabetler(d):
    """(isabet satırları, ders bağları) — bağ satırı `tur: ders-bagi` taşır, isabet sayılmaz."""
    tum = d.get("isabet") or []
    return [x for x in tum if isinstance(x, dict) and not x.get("tur")], \
           [x for x in tum if isinstance(x, dict) and x.get("tur") == "ders-bagi"]


def ekle(yol, kayit):
    """append-only: `isabet:` dosyanın SON üst düzey anahtarı olmalı (yoksa açılır); yazdıktan sonra geri okunur."""
    with open(yol, encoding="utf-8") as h:
        metin = h.read()
    ust = [m.group(1) for m in re.finditer(r"^([a-z_]+):", metin, re.M)]
    if "isabet" in ust and ust[-1] != "isabet":
        hata(f"{os.path.basename(yol)}: isabet bölümü dosyanın sonunda değil ({ust[-1]} ondan sonra) — sona eklenemez, elle bakılmalı")
    ek = ("" if metin.endswith("\n") else "\n") + ("" if "isabet" in ust else "isabet:\n")
    ek += "  - " + json.dumps(kayit, ensure_ascii=False) + "\n"
    with open(yol, "a", encoding="utf-8") as h:
        h.write(ek)
    son = (oku(yol).get("isabet") or [None])[-1]   # yazdığını DOĞRULA (CLAUDE.md: "yazdım" yetmez, geri oku)
    if son != kayit:
        hata(f"{os.path.basename(yol)}: yazılan satır geri okunamadı — dosyaya bak", 3)


def esik():
    try:
        with open(TARIF_KAYDI, encoding="utf-8") as h:
            t = json.load(h)
        for u in t.get("uzmanliklar", []):
            if u.get("id") == "muhurdarlik" and isinstance(u.get("sicil_esigi"), dict):
                e = u["sicil_esigi"]
                if isinstance(e.get("kacirma"), int) and isinstance(e.get("pencere"), int) and e["kacirma"] > 0 and e["pencere"] > 0:
                    return e, "tarif kaydı"
    except (OSError, ValueError):
        pass
    return VARSAYILAN_ESIK, "varsayılan (Sultan S10)"


def argv_al(argv, bayraklar, tekli=()):
    a = {}; i = 0; konum = []
    while i < len(argv):
        if argv[i] in tekli:
            a[argv[i][2:]] = True; i += 1
        elif argv[i] in bayraklar:
            if i + 1 >= len(argv):
                hata(f"{argv[i]} değer ister")
            a[argv[i][2:].replace("-", "_")] = argv[i + 1]; i += 2
        elif argv[i].startswith("--"):
            hata(f"bilinmeyen bayrak: {argv[i]}")
        else:
            konum.append(argv[i]); i += 1
    return a, konum


def cmd_isabet(argv):
    a, k = argv_al(argv, ("--gorev", "--gereklilik", "--muhur", "--sultan", "--kaynak", "--neden", "--g-tur", "--el-kitabi-surum"), ("--bassiz",))
    if len(k) != 1:
        hata("kullanım: isabet <mühürdar> --gorev G --gereklilik Gi --muhur ✓|✗ --sultan katiliyorum|saglanmadi --kaynak <ref> …")
    ad = k[0]
    for z in ("gorev", "gereklilik", "muhur", "sultan"):
        if not a.get(z):
            hata(f"--{z} zorunlu")
    if a["muhur"] not in ("✓", "✗"):
        hata("--muhur ✓ ya da ✗")
    if a["sultan"] not in ("katiliyorum", "saglanmadi"):
        hata("--sultan katiliyorum ya da saglanmadi")
    kaynak = (a.get("kaynak") or "").strip()
    if not (D1.match(kaynak) or TESLIM.match(kaynak)):
        hata("--kaynak Sultan'ın KAYDI olmalı: 'teslim:<kimlik>' (teslim ekranı kararı) ya da D1 damgası "
             "'YYYY-MM-DD Sultan: … (sohbet · <ref> · \"<kırpık>\" · beyan:<AJAN>)' — Sultan'ın hükmü üretilmez (A06); satır yazılmadı")
    if a["sultan"] == "saglanmadi" and not (a.get("neden") or "").strip():
        hata("--neden zorunlu: 'sağlanmadı' Sultan'ın tek cümlesiyle gelir (ders çıkarma bundan beslenir)")
    yol = ozluk_bul(ad)
    kayit = {"ts": simdi(), "gorev": a["gorev"], "gereklilik": a["gereklilik"], "muhur": a["muhur"], "sultan": a["sultan"],
             "kacirma": "e" if (a["muhur"] == "✓" and a["sultan"] == "saglanmadi") else "h",
             "bassiz": "e" if a.get("bassiz") else "h", "el_kitabi_surum": a.get("el_kitabi_surum"), "ders": None,
             "g_tur": a.get("g_tur"), "neden": (a.get("neden") or "").strip() or None, "kaynak": kaynak}
    ekle(yol, kayit)
    print(f"✓ isabet yazıldı: {ad} ({os.path.basename(yol)}) · {a['gorev']} {a['gereklilik']} · mühür {a['muhur']} · Sultan {a['sultan']}"
          + (" · KAÇIRMA" if kayit["kacirma"] == "e" else ""))
    return 0


def hesap(ad):
    yol = ozluk_bul(ad); d = oku(yol); isb, baglar = isabetler(d); e, ek = esik()
    gorevler = []   # mühür = görev teslimi; sıra = yazım sırası (append-only)
    for x in isb:
        if x.get("gorev") not in gorevler:
            gorevler.append(x.get("gorev"))
    pencere = gorevler[-e["pencere"]:]
    kacirmali = [g for g in pencere if any(x.get("gorev") == g and x.get("kacirma") == "e" for x in isb)]
    n = len(kacirmali)
    durum = "askida" if n >= e["kacirma"] else ("ders-cikarma" if n >= 1 else "temiz")
    return {"muhurdar": ad, "personel": os.path.basename(yol)[:-5], "muhur_sayisi": len(gorevler), "pencere": len(pencere),
            "kacirmali_muhur": n, "kacirmali_gorevler": kacirmali, "esik": e, "esik_kaynagi": ek, "durum": durum,
            "bagli_ders": {b.get("hedef_ts"): b.get("ders") for b in baglar}}, isb, baglar


def cmd_durum(argv):
    a, k = argv_al(argv, (), ("--json",))
    if len(k) != 1:
        hata("kullanım: durum <mühürdar> [--json]")
    h, _, _ = hesap(k[0])
    gereken = {"temiz": [], "ders-cikarma": [f"ders çıkarma vazifesi: sicil.sh ders {k[0]}"],
               "askida": ["atama ASKIDA (uzmanlık durumu askida)", f"el kitabı güncelleme: sicil.sh ders {k[0]} → ders günlüğü",
                          "yeniden yeterlilik sınavı (diploma)"]}[h["durum"]]
    h["gereken"] = gereken
    if a.get("json"):
        print(json.dumps(h, ensure_ascii=False)); return 0
    print(f"mühürdar {h['muhurdar']} · personel {h['personel']} · {h['muhur_sayisi']} mühür (son {h['pencere']}'u sayıldı) · "
          f"kaçırmalı mühür {h['kacirmali_muhur']} · eşik {h['esik']['kacirma']}/{h['esik']['pencere']} ({h['esik_kaynagi']})")
    print(f"durum: {h['durum']}")
    for g in gereken:
        print(f"  gereken: {g}")
    return 0


def gunluk_dersleri():
    try:
        with open(EL_KITABI, encoding="utf-8") as h:
            metin = h.read()
    except OSError:
        hata(f"el kitabı okunamadı: {EL_KITABI}", 3)
    if "## 12 · Ders günlüğü" not in metin:
        hata("el kitabında '## 12 · Ders günlüğü' bölümü yok — ders bağlanamaz", 3)
    return set(re.findall(r"^- \*\*(D-\d{3})\*\*", metin.split("## 12 · Ders günlüğü", 1)[1], re.M))


def cmd_ders(argv):
    a, k = argv_al(argv, (), ("--json",))
    if len(k) != 1:
        hata("kullanım: ders <mühürdar> [--json]")
    h, isb, baglar = hesap(k[0])
    bagli = {b.get("hedef_ts") for b in baglar}
    acik = [x for x in isb if x.get("kacirma") == "e" and x.get("ts") not in bagli]
    gruplar = {}
    for x in acik:
        gruplar.setdefault(x.get("g_tur") or "(türsüz)", []).append(x)
    tekrar = {t: xs for t, xs in gruplar.items() if len({x.get("gorev") for x in xs}) >= 2}   # ≥2 AYRI görevde aynı tür
    mevcut = gunluk_dersleri()
    sonraki = f"D-{(max([int(d[2:]) for d in mevcut] or [0]) + 1):03d}"
    if a.get("json"):
        print(json.dumps({"muhurdar": k[0], "acik_kacirma": len(acik), "tekrar_eden": {t: [x["ts"] for x in xs] for t, xs in tekrar.items()},
                          "sonraki_ders": sonraki}, ensure_ascii=False)); return 0
    print(f"── ders çıkarma · {k[0]} · bağlanmamış kaçırma {len(acik)} · tekrar eden tür {len(tekrar)}")
    for t, xs in gruplar.items():
        print(f"  {t}: {len(xs)} kaçırma · {len({x.get('gorev') for x in xs})} görev{' — TEKRAR EDEN' if t in tekrar else ''}")
    for t, xs in tekrar.items():
        print(f"\n### Ders taslağı ({sonraki}) — tekrar eden kaçırma türü: {t}")
        for x in xs:
            print(f"- Sultan: \"{x.get('neden')}\" ({x.get('gorev')} {x.get('gereklilik')} · {x.get('ts')})")
        print(f"Kural (el kitabı §12'ye '- **{sonraki}** …' satırı olarak, PR ile): '{t}' türündeki gereklilikte mühürdar şunu da sınar: <yukarıdaki cümlelerden türeyen ölçüt>")
        print(f"Bağla: sicil.sh ders-bagla {k[0]} --isabet-ts <ts> --ders {sonraki}  (her satır için)")
    if not tekrar:
        print("  tekrar eden tür yok — tek kaçırma ders çıkarmada konuşulur, kural yazılmaz (S10: 1 kaçırma = ders çıkarma)")
    return 0


def cmd_ders_bagla(argv):
    a, k = argv_al(argv, ("--isabet-ts", "--ders"))
    if len(k) != 1 or not a.get("isabet_ts") or not a.get("ders"):
        hata("kullanım: ders-bagla <mühürdar> --isabet-ts <ts> --ders D-NNN")
    if not DERS_ID.match(a["ders"]):
        hata("--ders D-NNN biçiminde olmalı")
    if a["ders"] not in gunluk_dersleri():
        hata(f"{a['ders']} el kitabının ders günlüğünde YOK — önce kuralı el kitabına yaz (PR), sonra bağla")
    yol = ozluk_bul(k[0]); isb, baglar = isabetler(oku(yol))
    hedef = [x for x in isb if x.get("ts") == a["isabet_ts"] and x.get("kacirma") == "e"]
    if not hedef:
        hata(f"{a['isabet_ts']} zamanlı KAÇIRMA satırı yok — yalnız kaçırma bir derse bağlanır")
    if any(b.get("hedef_ts") == a["isabet_ts"] for b in baglar):
        hata(f"{a['isabet_ts']} zaten bir derse bağlı")
    ekle(yol, {"ts": simdi(), "tur": "ders-bagi", "hedef_ts": a["isabet_ts"], "ders": a["ders"]})
    print(f"✓ {k[0]} · {a['isabet_ts']} kaçırması {a['ders']} dersine bağlandı (ters kayıt; özgün satır değişmedi)")
    return 0


def main():
    if len(sys.argv) < 2:
        hata("kullanım: sicil.py isabet|durum|ders|ders-bagla …")
    k = {"isabet": cmd_isabet, "durum": cmd_durum, "ders": cmd_ders, "ders-bagla": cmd_ders_bagla}.get(sys.argv[1])
    if not k:
        hata(f"bilinmeyen alt komut: {sys.argv[1]}")
    return k(sys.argv[2:])


if __name__ == "__main__":
    sys.exit(main())
