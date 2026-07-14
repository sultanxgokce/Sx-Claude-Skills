#!/usr/bin/env python3
"""muhur.py — MUHUR.md verdikt-kartı üretici + şema-lint (tescil lib; DİVAN K5, k0054).

Alt-komutlar:
  uret --out <deneme-dir> --kart --deneme --head-sha [--katman2 G3=GECTI[:not]]... [--tatbikat]
       gereklilik.json + kanit/G*.json okur → MUHUR.md + muhur-ozet.json yazar.
       RC = verdikt: 0=GECTI · 1=KALDI · 3=KATMAN2-BEKLIYOR|ESKALASYON.
  red  --out <deneme-dir> --kart --deneme --ad <red-adi> [--sebep S]... [--head-sha sha]
       İSİMLİ-RED MUHUR'u yazar (tescil koşulmadı). RC=4.
  lint <deneme-dir> [--tescil-root <dir>]
       MUHUR.md + kanıt şema-doğrulaması; şemasız/çıplak-geçti → RC=1.
       --tescil-root: jenerik-G dedektörü (son-20 kart komut-sha örtüşmesi >%70 → UYARI-satırı).

KALDI-paketi kuralı (SKILL.md §6): yalnız {düşen-G, komut, beklenen-vs-gözlenen (ham-kuyruk+RC),
sınıf}; iç-muhakeme motora dönmez. sinif default İŞ-EKSİK; GEREKLİLİK-MUĞLAK teşhisi MÜHÜRDAR
gerekçe + düzeltme-diff'i ile koyar (deneme-sayacı yanmaz — dongu-sayac tarafı).
"""
import glob
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone

VERDIKTLER = ("GECTI", "KALDI", "ESKALASYON", "KATMAN2-BEKLIYOR", "RED")
RC_MAP = {"GECTI": 0, "KALDI": 1, "ESKALASYON": 3, "KATMAN2-BEKLIYOR": 3, "RED": 4}
KANIT_ZORUNLU = (
    "g_id", "komut", "komut_sha256", "worktree_head_sha", "zaman_utc",
    "exit_code", "beklenen", "gozlenen", "sonuc", "kanit_turu",
    "stdout_stderr_ham", "cikti_tam_sha256",
)
KUYRUK_TAVAN = 2048  # KALDI-paketi çıktı-kuyruğu (bayt)


def utc():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def sha256_dosya(yol):
    h = hashlib.sha256()
    with open(yol, "rb") as f:
        for parca in iter(lambda: f.read(65536), b""):
            h.update(parca)
    return h.hexdigest()


def oku_json(yol):
    with open(yol, "r", encoding="utf-8") as f:
        return json.load(f)


def _skill_version():
    # version tek-evi SKILL.md frontmatter (ADR-001 hizası) — buradan okunur.
    skill_md = os.path.join(os.path.dirname(__file__), "..", "..", "SKILL.md")
    try:
        with open(skill_md, "r", encoding="utf-8") as f:
            for satir in f:
                m = re.match(r"^version:\s*(\S+)", satir)
                if m:
                    return m.group(1)
    except OSError:
        pass
    return "bilinmiyor"


def _yaz(out, satirlar, ozet):
    with open(os.path.join(out, "MUHUR.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(satirlar) + "\n")
    with open(os.path.join(out, "muhur-ozet.json"), "w", encoding="utf-8") as f:
        json.dump(ozet, f, ensure_ascii=False, indent=1)
        f.write("\n")


def _entegrasyon_bloku():
    return [
        "",
        "## Entegrasyon",
        "- Kart-durum flip'ini tescil YAPMAZ — verdikt raporlanır; flip `scripts/dongu-sayac.sh`",
        "  → tek-boğaz GECISLER-route yolundadır. dongu-sayac `gecti|kaldi` MUHUR.md-varlık şartlıdır.",
        "- Telemetri: `scripts/telemetri-append.sh` → `_agents/tescil/telemetri.jsonl`.",
    ]


def cmd_uret(argv):
    a = {"katman2": [], "tatbikat": False}
    i = 0
    while i < len(argv):
        if argv[i] == "--out":
            a["out"] = argv[i + 1]; i += 2
        elif argv[i] == "--kart":
            a["kart"] = argv[i + 1]; i += 2
        elif argv[i] == "--deneme":
            a["deneme"] = int(argv[i + 1]); i += 2
        elif argv[i] == "--head-sha":
            a["head_sha"] = argv[i + 1]; i += 2
        elif argv[i] == "--katman2":
            a["katman2"].append(argv[i + 1]); i += 2
        elif argv[i] == "--tatbikat":
            a["tatbikat"] = True; i += 1
        else:
            sys.stderr.write(f"muhur.py uret: bilinmeyen argüman {argv[i]}\n"); return 2
    out = a.get("out")
    if not out or "kart" not in a:
        sys.stderr.write("kullanım: muhur.py uret --out <dir> --kart <k####> [--deneme n] [--head-sha sha] [--katman2 G=V]... [--tatbikat]\n")
        return 2
    ger = oku_json(os.path.join(out, "gereklilik.json"))
    deneme = a.get("deneme", 1)

    # Katman-2 girdileri: "G3=GECTI[:not]"
    katman2 = {}
    for k in a["katman2"]:
        m = re.match(r"^(G\d+)=(GECTI|KALDI|EMIN-DEGILIM)(?::(.*))?$", k)
        if not m:
            sys.stderr.write(f"muhur.py: geçersiz --katman2 girdisi: {k!r} (G<i>=GECTI|KALDI|EMIN-DEGILIM[:not])\n")
            return 2
        katman2[m.group(1)] = {"sonuc": m.group(2), "not": m.group(3) or ""}

    mekanik = [g for g in ger["g"] if g["tur"] != "llm-yargi"]
    oznel = [g for g in ger["g"] if g["tur"] == "llm-yargi"]

    kanitlar = {}
    for g in mekanik:
        yol = os.path.join(out, "kanit", f"{g['id']}.json")
        if not os.path.isfile(yol):
            sys.stderr.write(f"muhur.py: kanıt eksik: {yol} (önce tescil-run G-koşuları)\n")
            return 2
        kanitlar[g["id"]] = (oku_json(yol), sha256_dosya(yol), os.path.relpath(yol, out))

    dusen = [gid for gid, (k, _, _) in kanitlar.items() if k["sonuc"] != "GECTI"]
    oznel_acik = [g["id"] for g in oznel if g["id"] not in katman2]
    oznel_eskalasyon = [gid for gid, v in katman2.items() if v["sonuc"] == "EMIN-DEGILIM"]
    oznel_kaldi = [gid for gid, v in katman2.items() if v["sonuc"] == "KALDI"]

    if dusen or oznel_kaldi:
        verdikt = "KALDI"
    elif oznel_eskalasyon:
        verdikt = "ESKALASYON"  # "emin değilim" → GEÇTİ değil (SKILL.md §3)
    elif oznel_acik:
        verdikt = "KATMAN2-BEKLIYOR"
    else:
        verdikt = "GECTI"

    sv = _skill_version()
    L = [
        f"# MÜHÜR — {a['kart']} · deneme-{deneme}",
        f"kart: {a['kart']}",
        f"deneme: {deneme}",
        f"verdikt: {verdikt}",
        f"zaman_utc: {utc()}",
        f"worktree_head_sha: {a.get('head_sha') or '(verilmedi)'}",
        f"gereklilik_sha256: {ger['gereklilik_sha256']}",
        f"tip: {ger['tip']}",
        f"vites: {ger['vites']}",
        f"tescil_skill_version: {sv}",
        f"g_toplam: {len(ger['g'])}",
        f"g_gecti: {len(mekanik) - len(dusen) + sum(1 for v in katman2.values() if v['sonuc'] == 'GECTI')}",
        f"g_kaldi: {len(dusen) + len(oznel_kaldi)}",
        f"g_oznel: {len(oznel)}",
        f"tatbikat: {'evet' if a['tatbikat'] else 'hayir'}",
        "",
        "## G-özet",
        "| G | tur | sonuc | rc | kanit (sha256) |",
        "|---|-----|-------|----|----------------|",
    ]
    for g in mekanik:
        k, ksha, krel = kanitlar[g["id"]]
        L.append(f"| {g['id']} | {g['tur']} | {k['sonuc']} | {k['exit_code']} | {krel} ({ksha}) |")
    for g in oznel:
        if g["id"] in katman2:
            v = katman2[g["id"]]
            L.append(f"| {g['id']} | llm-yargi | {v['sonuc']} | - | katman2 (izole-rubrik: {g.get('rubrik')}) |")
        else:
            L.append(f"| {g['id']} | llm-yargi | KATMAN2-BEKLIYOR | - | (rubrik: {g.get('rubrik')}) |")

    if verdikt == "KALDI":
        L += ["", "## KALDI-paketi", "> Motora dönen TEK içerik budur (iç-muhakeme verbatim dönmez — SKILL.md §6)."]
        for gid in dusen:
            k, _, _ = kanitlar[gid]
            kuyruk = (k.get("stdout_stderr_ham") or "")[-KUYRUK_TAVAN:]
            L += [
                f"### {gid}",
                f"- komut: `{k['komut']}`",
                f"- beklenen: rc={k['beklenen']['rc']}" + (f" · desen=`{k['beklenen']['desen']}`" if k['beklenen'].get('desen') else ""),
                f"- gozlenen: rc={k['gozlenen']['rc']}" + (f" · desen_eslesti={k['gozlenen'].get('desen_eslesti')}" if k['beklenen'].get('desen') else ""),
                "- cikti_kuyrugu (redakte, ≤2KB):",
                "```",
                kuyruk.strip(),
                "```",
                "- sinif: İŞ-EKSİK  <!-- varsayılan; GEREKLİLİK-MUĞLAK teşhisi = gerekçe + düzeltme-diff'i şart (SKILL.md §6) -->",
            ]
        for gid in oznel_kaldi:
            L += [f"### {gid}", f"- katman2: KALDI ({katman2[gid]['not']})", "- sinif: İŞ-EKSİK  <!-- varsayılan -->"]
    if katman2:
        L += ["", "## Katman-2 (izole-rubrik sonuçları)"]
        for gid, v in sorted(katman2.items()):
            L.append(f"- {gid}: {v['sonuc']}" + (f" — {v['not']}" if v["not"] else ""))
    if verdikt == "ESKALASYON":
        L += ["", "> Katman-2 'EMIN-DEGILIM' → GEÇTİ DEĞİL; Sultan/SERDAR-eskalasyonu (SKILL.md §3)."]
    L += _entegrasyon_bloku()

    ozet = {
        "kart": a["kart"], "deneme": deneme, "verdikt": verdikt, "rc": RC_MAP[verdikt],
        "tip": ger["tip"], "vites": ger["vites"], "g_toplam": len(ger["g"]),
        "g_dusen": dusen + oznel_kaldi, "oznel_acik": oznel_acik,
        "tatbikat": a["tatbikat"], "zaman_utc": utc(), "tescil_skill_version": sv,
    }
    _yaz(out, L, ozet)
    print(f"MUHUR.md yazıldı: verdikt={verdikt} (rc={RC_MAP[verdikt]})")
    return RC_MAP[verdikt]


def cmd_red(argv):
    a = {"sebepler": []}
    i = 0
    while i < len(argv):
        if argv[i] == "--out":
            a["out"] = argv[i + 1]; i += 2
        elif argv[i] == "--kart":
            a["kart"] = argv[i + 1]; i += 2
        elif argv[i] == "--deneme":
            a["deneme"] = int(argv[i + 1]); i += 2
        elif argv[i] == "--ad":
            a["ad"] = argv[i + 1]; i += 2
        elif argv[i] == "--sebep":
            a["sebepler"].append(argv[i + 1]); i += 2
        elif argv[i] == "--head-sha":
            a["head_sha"] = argv[i + 1]; i += 2
        else:
            sys.stderr.write(f"muhur.py red: bilinmeyen argüman {argv[i]}\n"); return 2
    if "out" not in a or "kart" not in a or "ad" not in a:
        sys.stderr.write("kullanım: muhur.py red --out <dir> --kart <k####> --ad <red-adi> [--sebep S]...\n")
        return 2
    os.makedirs(a["out"], exist_ok=True)
    deneme = a.get("deneme", 1)
    L = [
        f"# MÜHÜR — {a['kart']} · deneme-{deneme}",
        f"kart: {a['kart']}",
        f"deneme: {deneme}",
        "verdikt: RED",
        f"red_adi: {a['ad']}",
        f"zaman_utc: {utc()}",
        f"worktree_head_sha: {a.get('head_sha') or '(verilmedi)'}",
        f"tescil_skill_version: {_skill_version()}",
        "",
        "## İSİMLİ-RED gerekçesi",
    ] + [f"- {s}" for s in (a["sebepler"] or ["(gerekçe verilmedi)"])] + [
        "",
        "> Tescil KOŞULMADI — kart 'gereklilik-eksik/jenerik' etiketiyle SERDAR'a döner",
        "> (sevk-disiplinini geriye zorlar, Değişmez-2). Deneme-sayacı YANMAZ.",
    ] + _entegrasyon_bloku()
    ozet = {"kart": a["kart"], "deneme": deneme, "verdikt": "RED", "red_adi": a["ad"],
            "sebepler": a["sebepler"], "rc": 4, "zaman_utc": utc()}
    _yaz(a["out"], L, ozet)
    print(f"MUHUR.md yazıldı: verdikt=RED ({a['ad']}) (rc=4)")
    return 4


def _muhur_basligi(yol):
    alanlar = {}
    with open(yol, "r", encoding="utf-8") as f:
        for satir in f:
            m = re.match(r"^([a-z0-9_]+):\s*(.*)$", satir.strip())
            if m:
                alanlar[m.group(1)] = m.group(2).strip()
            if satir.startswith("## "):
                break
    return alanlar


def cmd_lint(argv):
    if not argv:
        sys.stderr.write("kullanım: muhur.py lint <deneme-dir> [--tescil-root <dir>]\n")
        return 2
    out = argv[0]
    tescil_root = None
    if "--tescil-root" in argv:
        tescil_root = argv[argv.index("--tescil-root") + 1]
    hatalar, uyarilar = [], []

    muhur_yolu = os.path.join(out, "MUHUR.md")
    if not os.path.isfile(muhur_yolu):
        print(f"✗ GEÇERSİZ: MUHUR.md yok ({out}) — çıplak-'geçti' beyanı kanıt değildir")
        return 1
    b = _muhur_basligi(muhur_yolu)
    for alan in ("kart", "deneme", "verdikt", "zaman_utc", "tescil_skill_version"):
        if alan not in b:
            hatalar.append(f"MUHUR.md başlık-alanı eksik: {alan}")
    verdikt = b.get("verdikt", "")
    if verdikt not in VERDIKTLER:
        hatalar.append(f"geçersiz verdikt: {verdikt!r} ({'|'.join(VERDIKTLER)})")

    kanit_sha_map = {}
    if verdikt != "RED":
        for alan in ("worktree_head_sha", "gereklilik_sha256", "tip", "vites", "g_toplam"):
            if alan not in b:
                hatalar.append(f"MUHUR.md başlık-alanı eksik: {alan}")
        ger_yolu = os.path.join(out, "gereklilik.json")
        if not os.path.isfile(ger_yolu):
            hatalar.append("gereklilik.json anlık-görüntüsü yok (kör-protokol girdisi kanıtlanamıyor)")
        else:
            ger = oku_json(ger_yolu)
            if b.get("gereklilik_sha256") and b["gereklilik_sha256"] != ger["gereklilik_sha256"]:
                hatalar.append("gereklilik_sha256 uyuşmuyor (MUHUR ↔ gereklilik.json)")
            mekanik = [g for g in ger["g"] if g["tur"] != "llm-yargi"]
            if not ger["g"]:
                hatalar.append("hiç G yok — çıplak-verdikt geçersiz")
            if not any(g["davranis"] or g["tur"] in ("api-check", "e2e-check") for g in ger["g"]):
                hatalar.append("≥1 DAVRANIŞ-G yok (gereklilik-jenerik sınıfı MUHUR'a sızmış)")
            turler = [g["tur"] for g in ger["g"]]
            if ger["tip"] == "ui" and "e2e-check" not in turler:
                hatalar.append("iş-tipi asgari-kanıt İHLALİ: TIP=ui için ≥1 e2e-check şart (mock-only yeşil YASAK)")
            if ger["tip"] == "kod" and not any(t in ("api-check", "e2e-check") for t in turler):
                hatalar.append("iş-tipi asgari-kanıt İHLALİ: TIP=kod için ≥1 api-check|e2e-check şart (tsc/build yetmez)")
            for g in mekanik:
                yol = os.path.join(out, "kanit", f"{g['id']}.json")
                if not os.path.isfile(yol):
                    hatalar.append(f"kanıt-dosyası yok: kanit/{g['id']}.json")
                    continue
                try:
                    k = oku_json(yol)
                except (json.JSONDecodeError, OSError) as e:
                    hatalar.append(f"kanit/{g['id']}.json parse-hatası: {e}")
                    continue
                eksik = [alan for alan in KANIT_ZORUNLU if alan not in k]
                if eksik:
                    hatalar.append(f"kanit/{g['id']}.json şema-eksik alanlar: {', '.join(eksik)}")
                if k.get("komut_sha256") != hashlib.sha256((k.get("komut") or "").encode()).hexdigest():
                    hatalar.append(f"kanit/{g['id']}.json komut_sha256 uyuşmuyor (kanıt-bütünlüğü)")
                if verdikt == "GECTI" and k.get("sonuc") != "GECTI":
                    hatalar.append(f"verdikt=GECTI ama {g['id']} sonuc={k.get('sonuc')} — tutarsız")
                kanit_sha_map[g["id"]] = k.get("komut_sha256")
            if verdikt == "GECTI":
                # öznel G'lerin tamamı Katman-2 GECTI olmalı (MUHUR gövde-kontrolü)
                with open(muhur_yolu, encoding="utf-8") as f:
                    govde = f.read()
                for g in ger["g"]:
                    if g["tur"] == "llm-yargi" and not re.search(rf"^- {g['id']}: GECTI", govde, re.M):
                        hatalar.append(f"verdikt=GECTI ama öznel {g['id']} için Katman-2 GECTI kaydı yok")

    # Jenerik-G dedektörü (uyarı — RC etkilemez; SKILL.md §9)
    if tescil_root and kanit_sha_map and os.path.isdir(tescil_root):
        bu_kart = b.get("kart")
        digerleri = sorted(
            (d for d in glob.glob(os.path.join(tescil_root, "k*")) if os.path.isdir(d)
             and os.path.basename(d) != bu_kart),
            key=os.path.getmtime, reverse=True)[:20]
        havuz = set()
        for d in digerleri:
            for kj in glob.glob(os.path.join(d, "deneme-*", "kanit", "G*.json")):
                try:
                    havuz.add(oku_json(kj).get("komut_sha256"))
                except (json.JSONDecodeError, OSError):
                    pass
        if havuz:
            ortusme = sum(1 for s in kanit_sha_map.values() if s in havuz) / len(kanit_sha_map)
            if ortusme > 0.70:
                uyarilar.append(f"jenerik-gereklilik: G-komut-sha örtüşmesi %{round(ortusme * 100)} (>70, son-{len(digerleri)} kart) — kopyala-yapıştır-G şüphesi")

    for u in uyarilar:
        print(f"⚠ UYARI: {u}")
    if hatalar:
        print(f"✗ GEÇERSİZ ({muhur_yolu}):")
        for h in hatalar:
            print(f"  - {h}")
        return 1
    print(f"✓ geçerli: {muhur_yolu} (verdikt={verdikt})")
    return 0


def main():
    if len(sys.argv) < 2:
        sys.stderr.write("kullanım: muhur.py <uret|red|lint> ...\n")
        return 2
    komut = sys.argv[1]
    if komut == "uret":
        return cmd_uret(sys.argv[2:])
    if komut == "red":
        return cmd_red(sys.argv[2:])
    if komut == "lint":
        return cmd_lint(sys.argv[2:])
    sys.stderr.write(f"bilinmeyen alt-komut: {komut}\n")
    return 2


if __name__ == "__main__":
    sys.exit(main())
