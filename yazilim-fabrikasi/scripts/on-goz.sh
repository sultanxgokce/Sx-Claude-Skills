#!/usr/bin/env bash
# on-goz.sh — GÖZE GÖNDERMEDEN ÖNCE yazanın kendi denetimi ("ön göz"). Bağımsız gözün yerine GEÇMEZ; ona hazırlar.
#
# NİÇİN (W42 haftalık değerlendirme E1 · gorev_01M5CYPSK57KYPXXW42W7H1EBA): ilk turda 5/E geçen iş %24
# (ölçüldü: ilk-tur-olc.py, origin/main DENETIM-1.json — Nexus 16/90 · cloudtop 40/159 · Sx 30/116). İlk turda
# kalan işlerin 610 bulgusunun %23'ü kanıt bayat/eksik, %21'i sınav yetersiz, %19'u kapsam/kart, %17'si kenar durum —
# çoğu yazanın kendi soracağı türden. Göz turu yakıt gibi yanıyor; hedef ilk turda %50.
#
# NE YAPAR (iki katman):
#   1) MEKANİK KONTROLLER — göze gidecek pakette en sık bulunan eksikleri makine yakalar:
#      kanıt manifesti · kod ölçümden SONRA değişti mi (bayat kanıt) · "sonra" ölçümü kırmızı mı · önce/sonra çifti ·
#      mutant izi · ölçümün sonucu göze sığıyor mu · kart başka depoyu anıyor mu · commit'lenmemiş kod · PR başı ·
#      PR gövdesinde dürüst sınır.
#   2) KENDİNE SOR — kart cümlesi maddelere bölünür, $DZ/ON-GOZ.md tablosu açılır: her madde için KANIT (hangi ölçüm)
#      · KENAR DURUMLAR (boş/eksik veri, hata yolu) · SINAV (hangi kapı/mutant). Boş hücre ("…") kalırsa rc 2.
#      Tablo yazanın; araç yalnız doldurulup doldurulmadığını ölçer — "doğru doldu mu" sorusu gözün.
#
# Kullanım: on-goz.sh <iş> [--pr N]     → rc 0 hazır · 2 eksik var (kırmızı kontrol ya da boş hücre) · 3 ölçülemedi
#   Sonuç $DZ/ON-GOZ.json'a yazılır (baş sha'sıyla) — denetçi ilk turda okur.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IS="${1:-}"; shift || true; PR=""
while [ $# -gt 0 ]; do case "$1" in --pr) PR="${2:-}"; shift 2 ;; *) echo "bilinmeyen: $1" >&2; exit 2 ;; esac; done
[ -n "$IS" ] || { echo "kullanım: on-goz.sh <iş> [--pr N]" >&2; exit 2; }
DEPO="${KANIT_DEPO:-$(git rev-parse --show-toplevel 2>/dev/null)}"; [ -n "$DEPO" ] || { echo "✗ depo kökü bulunamadı" >&2; exit 3; }
KART_DEPO="${KART_DEPO:-$(c="$(git -C "$DEPO" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" && [ -n "$c" ] && dirname "$c")}"
[ -n "$KART_DEPO" ] || KART_DEPO="$DEPO"
KART="$KART_DEPO/_agents/fabrika/kartlar/$IS.json"; [ -f "$KART" ] || { echo "✗ kart yok: $KART — önce kart.sh ac" >&2; exit 3; }
DZ="$DEPO/_agents/fabrika/kanit/$IS"; mkdir -p "$DZ"
KANIT_RC=0; KANIT_CIKTI="$(KANIT_DEPO="$DEPO" python3 "$HERE/kanit.py" dogrula "$IS" 2>&1)" || KANIT_RC=$?
PR_BAS=""; PR_GOVDE=""
if [ -n "$PR" ]; then
  GH="${FABRIKA_GH:-gh}"
  PR_BAS="$(cd "$DEPO" && "$GH" pr view "$PR" --json headRefOid -q .headRefOid 2>/dev/null)"
  PR_GOVDE="$(cd "$DEPO" && "$GH" pr view "$PR" --json body -q .body 2>/dev/null)"
fi
export DEPO KART DZ IS PR PR_BAS PR_GOVDE KANIT_RC KANIT_CIKTI HERE
python3 - <<'PY'
import json, os, re, subprocess, sys, datetime
E = os.environ; DEPO, DZ, IS = E["DEPO"], E["DZ"], E["IS"]
kart = json.load(open(E["KART"])); cumle = kart.get("cumle") or ""
def git(*a): return subprocess.run(["git", "-C", DEPO, *a], capture_output=True, text=True).stdout
K = []   # (ad, renk, ne)
def kayit(ad, renk, ne): K.append({"ad": ad, "renk": renk, "ne": ne})

# K1 · kanıt manifesti (araç imzalı, sha'lar tutuyor)
if E["KANIT_RC"] == "0": kayit("kanit-manifesti", "yesil", "manifest sağlam")
else: kayit("kanit-manifesti", "kirmizi", "kanıt doğrulanmadı: " + E["KANIT_CIKTI"].strip().splitlines()[-1][:160] if E["KANIT_CIKTI"].strip() else "kanıt yok")
try: man = json.load(open(os.path.join(DZ, "KANIT.json")))
except Exception: man = {"kayitlar": []}
olcumler = [r for r in man.get("kayitlar", []) if r.get("tur") == "olcum"]

# değişen ÜRETİM dosyaları: tabana göre + commit'lenmemiş; kanıt dizini hariç
taban = git("merge-base", "HEAD", os.environ.get("ON_GOZ_TABAN", "origin/main")).strip()
degisen = set(git("diff", "--name-only", taban, "HEAD").split()) if taban else set()
kirli = set(x[3:] for x in git("status", "--porcelain").splitlines() if x[3:])
uretim = lambda s: {f for f in s if not f.startswith("_agents/fabrika/")}
degisen, kirli = uretim(degisen), uretim(kirli)

# K2 · commit'lenmemiş üretim kodu (göze giden fark commit'lerden okunur — kirli ağaç görünmez)
if kirli: kayit("kirli-agac", "kirmizi", "commit'lenmemiş üretim değişikliği: " + ", ".join(sorted(kirli))[:200])
else: kayit("kirli-agac", "yesil", "üretim değişikliklerinin hepsi commit'li")

# K3 · BAYAT KANIT — kod son ölçümden SONRA değiştiyse ölçüm o kodu görmemiştir
def zaman(s):
    try: return datetime.datetime.fromisoformat(s)
    except Exception: return None
son_olcum = max((zaman(r.get("zaman", "")) for r in olcumler if r.get("asama") in ("sonra", "tek")), default=None, key=lambda z: z or datetime.datetime.min.replace(tzinfo=datetime.timezone.utc))
# Kanıtta ölçüm anının ağaç izi yok; zaman tek başına yetmez (ölç → kodu ve kanıtı BİRLİKTE commit'le kalıbında commit
# ölçümden sonradır ama ölçülen hâli taşır). Ayrım: ölçümden sonraki bir commit dosyaya dokunup KANIT.json'a DOKUNMUYORSA
# kod ölçülmeden değişmiştir. Commit'lenmemiş dosyada mtime ölçülür (dal değiştirmek mtime'ı yeniler; yalnız kirlide bakılır).
KJ = f"_agents/fabrika/kanit/{IS}/KANIT.json"
bayat = []
if son_olcum:
    for f in sorted(degisen | kirli):
        p = os.path.join(DEPO, f)
        if f in kirli and os.path.exists(p):
            z = datetime.datetime.fromtimestamp(os.path.getmtime(p), datetime.timezone.utc)
            if z > son_olcum + datetime.timedelta(seconds=2): bayat.append(f"{f} (commit'siz, {z.astimezone():%H:%M:%S})")
            continue
        for sat in git("log", "--format=%H %cI", f"{taban}..HEAD", "--", f).splitlines() if taban else []:
            h, ci = sat.split(" ", 1); z = zaman(ci)
            if z and z > son_olcum + datetime.timedelta(seconds=2) and KJ not in git("show", "--name-only", "--format=", h).split():
                bayat.append(f"{f} ({h[:8]} {z.astimezone():%H:%M:%S}, kanıtsız commit)"); break
if not olcumler: kayit("bayat-kanit", "kirmizi", "hiç ölçüm yok — kanıtsız adım 4 yok")
elif bayat: kayit("bayat-kanit", "kirmizi", f"kod son 'sonra/tek' ölçümden ({son_olcum.astimezone():%H:%M:%S}) SONRA değişti: " + "; ".join(bayat)[:240] + " — yeniden ölç")
else: kayit("bayat-kanit", "yesil", "son ölçümden sonra ölçülmeden değişen üretim kodu yok")

# K4 · "sonra"/"tek" ölçümü kırmızı mı (önce kırmızı beklenir)
kotu = [r["etiket"] for r in olcumler if r.get("asama") in ("sonra", "tek") and r.get("renk") != "yesil"]
kayit("sonra-kirmizi", "kirmizi" if kotu else "yesil", ("kırmızı/sarı sonra ölçümü: " + ", ".join(kotu)) if kotu else "sonra ölçümlerinin hepsi yeşil")

# K5 · önce/sonra çifti
once = {r["etiket"] for r in olcumler if r.get("asama") == "once"}; sonra = {r["etiket"] for r in olcumler if r.get("asama") == "sonra"}
yetim = sorted(once - sonra)
if yetim: kayit("olcum-cifti", "kirmizi", "önce ölçümü var, sonrası yok: " + ", ".join(yetim))
elif not once and not any(r.get("tur") == "kare" for r in man.get("kayitlar", [])): kayit("olcum-cifti", "sari", "önce ölçümü yok — görünmez işte ölçüm çifti beklenir (değişimi ne gösteriyor?)")
else: kayit("olcum-cifti", "yesil", f"{len(once & sonra)} önce/sonra çifti")

# K6 · mutant izi (sınav kendi kapısını ölçüyor mu)
metin = ""
for r in olcumler:
    try: metin += open(os.path.join(DZ, r["dosya"]), errors="replace").read()
    except Exception: pass
kayit("mutant-izi", "yesil" if re.search(r"mutant", metin, re.I) else "sari", "ölçümlerde mutant sonucu var" if re.search(r"mutant", metin, re.I) else "hiçbir ölçümde mutant sonucu yok — sınav bozulunca kırmızı veriyor mu?")

# K7 · sonuç satırı göze gidiyor mu (denetçi ölçüm özeti yoksa ilk 60 satır gider)
ozetli = "olcum_ozeti" in open(E.get("ON_GOZ_DENETCI") or os.path.join(E["HERE"], "denetci.sh"), errors="replace").read()
tasan = []
if not ozetli:
    for r in olcumler:
        try: L = open(os.path.join(DZ, r["dosya"]), errors="replace").read().splitlines()
        except Exception: continue
        if len(L) > 60 and any(re.search(r"SONUÇ|✗", x) for x in L[60:]): tasan.append(f"{r['dosya']} ({len(L)} satır)")
kayit("goze-sigar", "sari" if tasan else "yesil", ("sonuç/✗ satırı ilk 60 satırın DIŞINDA (bu denetçi yalnız başı görür): " + ", ".join(tasan)) if tasan else "ölçüm sonuçları göze ulaşıyor")

# K8 · kart cümlesi BAŞKA depoyu anıyor mu (depo başına kart)
bu = os.path.basename(git("rev-parse", "--path-format=absolute", "--git-common-dir").strip().rstrip("/").removesuffix("/.git")) or os.path.basename(DEPO)
DEPOLAR = {"Nexus": r"\bNexus\b", "cloudtop": r"\bcloudtop\b", "Sx-Claude-Skills": r"\bSx\b|Sx-Claude-Skills", "akar": r"\bakar\b", "mmex": r"\bmmex\b|\bMMEx\b"}
baska = [d for d, p in DEPOLAR.items() if d.lower() != bu.lower() and re.search(p, cumle)]
kayit("kart-depo", "sari" if baska else "yesil", (f"kart cümlesi başka depoyu anıyor ({', '.join(baska)}) — iş o depoya da yayılıyorsa depo başına kart; göz bu PR'da öbür yarıyı göremez") if baska else "kart tek depoda")

# K9 · PR başı = yerel HEAD · K10 · dürüst sınır
bas = git("rev-parse", "HEAD").strip()
if not E["PR"]: kayit("pr-basi", "sari", "PR verilmedi (--pr N) — göze giden baş ölçülemedi")
elif E["PR_BAS"] != bas: kayit("pr-basi", "kirmizi", f"PR başı {E['PR_BAS'][:8] or 'okunamadı'} ≠ yerel {bas[:8]} — push et, sonra göze gönder (eski fark = yanan tur)")
else: kayit("pr-basi", "yesil", f"PR başı yerel HEAD ({bas[:8]})")
if E["PR"]:
    s = bool(re.search(r"dürüst sınır|bilinen sınır|NE ÖLÇMEZ|NEYİ SAVUNMAZ|ölçmez|ölçülmez|^#+ .*\bsınır", E["PR_GOVDE"], re.I | re.M))   # "sınırsız" sayılmaz
    kayit("durust-sinir", "yesil" if s else "sari", "PR gövdesinde dürüst sınır var" if s else "PR gövdesinde 'dürüst sınır' yok — neyi ölçmediğini yaz (göz sorar)")

# KENDİNE SOR tablosu — kart cümlesi maddelere bölünür; yazan doldurur
tablo = os.path.join(DZ, "ON-GOZ.md")
if not os.path.exists(tablo):
    govde = re.sub(r"\s*\((?:gorev_|W\d)[^)]*\)\s*$", "", cumle)
    parcalar = [p.strip(" .;") for p in re.split(r"\s+·\s+|;\s+|\s+\+\s+|\(\d+\)\s*", govde) if len(p.strip(" .;")) >= 8] or [govde]
    with open(tablo, "w") as f:
        f.write(f"# Ön göz — {IS}\n\nKart: {cumle}\n\nHer satırı DOLDUR (… kalmasın). Göz aynı soruları soracak: talep ⟷ kanıt yan yana.\n\n")
        f.write("| # | Kart maddesi | Kanıt (hangi ölçüm/kare) | Kenar durumlar (boş · eksik veri · hata yolu) | Sınav (kapı/mutant) |\n|---|---|---|---|---|\n")
        for i, p in enumerate(parcalar, 1): f.write(f"| {i} | {p} | … | … | … |\n")
        f.write("\n**Dürüst sınır** (neyi ölçmüyor): …\n")
bos = open(tablo).read().count("…")
renk = {"kirmizi": "✗", "sari": "⚠", "yesil": "✓"}
for k in K: print(f"  {renk[k['renk']]} {k['ad']}: {k['ne']}")
print(f"  {'✓' if bos == 0 else '✗'} kendine-sor: {('tablo dolu' if bos == 0 else f'{bos} boş hücre (…) — doldur')}: {os.path.relpath(tablo, DEPO)}")
kirmizi = [k for k in K if k["renk"] == "kirmizi"]
rc = 2 if (kirmizi or bos) else 0
json.dump({"is": IS, "bas": bas, "zaman": datetime.datetime.now().astimezone().isoformat(timespec="seconds"), "pr": E["PR"] or None,
           "kontroller": K, "bos_hucre": bos, "rc": rc}, open(os.path.join(DZ, "ON-GOZ.json"), "w"), ensure_ascii=False, indent=1)
print(("✓ ÖN GÖZ TAMAM — göze gönder: denetci.sh " + IS + (" --pr " + E["PR"] if E["PR"] else "")) if rc == 0 else
      f"✗ ÖN GÖZ: {len(kirmizi)} kırmızı kontrol" + (f" · {bos} boş hücre" if bos else "") + " — düzelt, sonra göze gönder (her eksik bir göz turu yakar)")
sys.exit(rc)
PY
