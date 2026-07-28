#!/usr/bin/env bash
# layiha-aday-havuzu.sh — layiha aday-havuzu komut-yüzeyi (L24 FAZ-1, layiha-defteri.sh deseni).
#
# NE: `_agents/handoff/layiha-aday-havuzu.jsonl`'deki taslak-layiha adaylarını listeler/gösterir,
#     Sultan onayladığında TERFİ eder (aday → gerçek layiha, layiha-defteri.sh'e devrederek).
#     Defter (`layiha-defteri.jsonl`) yalnız terfi-edilmiş kayıtları görür — havuz "temiz" kalır.
#
# Kullanım:
#   layiha-aday-havuzu.sh liste [--top N] [--sinif sultan|muhendislik|urun] [--min-pct N] [--hepsi] [--porcelain]
#   layiha-aday-havuzu.sh goster <id|slug>
#   layiha-aday-havuzu.sh terfi <id|slug> [<id|slug> ...] [--gerekce "..."]
#   layiha-aday-havuzu.sh durum
#
# Havuz-konumu (per-container — L24 F3'ten beri `hat-yolu.lib.sh` üzerinden, TEK kapı):
#   1) $LAYIHA_ADAY_HAVUZ (env override)  2) <hat-kökü>/_agents/handoff/layiha-aday-havuzu.jsonl
#   ⛔ 3. kademe KALDIRILDI: eski sürüm git-kökü bulamayınca `$HOME/.claude/...`'a düşüyordu; `$HOME=/config`
#      ve `/config/.claude` 10 container'ın ORTAK fiziksel dizini → ilk yanlış-dizin çağrısı bütün odaların
#      aday-havuzunu tek dosyada birleştirirdi (İ1 ihlali, geri-alınamaz). Artık git-siz yerde RC=2 + reçete
#      (Sultan-kararı K1, 2026-07-25). Kök `--git-common-dir`'den çözülür → worktree'ler ayrışmaz.
#
# Terfi zinciri: layiha-defteri.sh binary'si $LAYIHA_DEFTERI_BIN (env override) yoksa kardeş-paketten
#   (<paket>/../layiha/scripts/layiha-defteri.sh) alınır — kurulu ve repo-içi düzende aynı şekilde çalışır.
#
# Çıkış: 0 OK · 2 girdi/ortam/atomiklik-hatası
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then echo "HATA: python3 yok." >&2; exit 2; fi

PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HAT_LIB="${HAT_YOLU_LIB:-$PAKET/../layiha/scripts/hat-yolu.lib.sh}"
[ -r "$HAT_LIB" ] || { echo "HATA: hat-yolu.lib.sh yok: $HAT_LIB — 'layiha' paketi kurulu mu?" >&2; exit 2; }
# shellcheck source=/dev/null
source "$HAT_LIB"

_defteri_bin() {
  if [ -n "${LAYIHA_DEFTERI_BIN:-}" ]; then printf '%s' "$LAYIHA_DEFTERI_BIN"; return; fi
  printf '%s' "$PAKET/../layiha/scripts/layiha-defteri.sh"
}

if [ -n "${LAYIHA_ADAY_HAVUZ:-}" ]; then HAVUZ="$LAYIHA_ADAY_HAVUZ"
else HAVUZ="$(hat_yolu aday-havuzu)" || exit 2; fi
DEFTERI_BIN="$(_defteri_bin)"
CMD="${1:-liste}"; shift || true

python_args() {
  python3 - "$@" <<'PY'
import sys, json
d={}; a=sys.argv[1:]; i=0
while i < len(a):
    k=a[i]
    if k.startswith("--"):
        key=k[2:]
        if i+1 < len(a) and not a[i+1].startswith("--"): d[key]=a[i+1]; i+=2
        else: d[key]=True; i+=1
    else: i+=1
print(json.dumps(d))
PY
}

case "$CMD" in
  liste)
    ARGS="$(python_args "$@")"
    HAVUZ="$HAVUZ" ADAY_ARGS="$ARGS" python3 - <<'PY'
import os, json, io, signal
signal.signal(signal.SIGPIPE, signal.SIG_DFL)  # `| head` gibi kırpılmış-pipe'larda sessiz-çık

havuz = os.environ["HAVUZ"]
a = json.loads(os.environ["ADAY_ARGS"])
top = a.get("top")
sinif = a.get("sinif")
min_pct = a.get("min-pct")
hepsi = bool(a.get("hepsi"))
porc = bool(a.get("porcelain"))

recs = []
if os.path.exists(havuz):
    with io.open(havuz, encoding="utf-8") as f:
        for l in f:
            if l.strip():
                try: recs.append(json.loads(l))
                except Exception: pass

def keep(r):
    if not hepsi and r.get("durum") != "aday":
        return False
    if sinif and r.get("sinif") != sinif:
        return False
    if min_pct is not None:
        try:
            if r.get("pct", 0) < float(min_pct): return False
        except ValueError:
            pass
    return True

sel = [r for r in recs if keep(r)]
sel.sort(key=lambda r: -r.get("pct", 0))
if top:
    try: sel = sel[:int(top)]
    except ValueError: pass

GLYPH = {"sultan": "🕶️", "muhendislik": "🔧", "urun": "📦"}
DURUM = {"aday": "aday", "terfi-edildi": "🏅 terfi-edildi", "emekli": "🗄️ emekli"}

if porc:
    for r in sel:
        print("\t".join([r.get("id",""), str(r.get("pct","")), r.get("sinif",""), r.get("durum",""),
                          r.get("baslik",""), r.get("goal",""), r.get("slug","")]))
    print("#OZET\ttoplam=%d" % len(sel))
else:
    baslik = "TÜM adaylar" if hepsi else "aday-havuzu (durum=aday)"
    print("🗂️ LAYİHA ADAY-HAVUZU · %s · %d kayıt" % (baslik, len(sel)))
    print("")
    if not sel:
        print("  (kayıt yok)")
    for r in sel:
        glyph = GLYPH.get(r.get("sinif", ""), "•")
        durum_etiketi = "" if r.get("durum") == "aday" else "  [%s]" % DURUM.get(r.get("durum"), r.get("durum",""))
        print("  %s  %%%s  %s  %s%s" % (r.get("id","?"), r.get("pct","?"), glyph, r.get("baslik",""), durum_etiketi))
        goal = r.get("goal", "")
        if goal:
            print("        %s" % goal)
PY
  ;;
  goster)
    KEY="${1:-}"
    [ -n "$KEY" ] || { echo "HATA: goster <id|slug>" >&2; exit 2; }
    HAVUZ="$HAVUZ" KEY="$KEY" python3 - <<'PY'
import os, json, io, sys

havuz = os.environ["HAVUZ"]; key = os.environ["KEY"]
if not os.path.exists(havuz):
    sys.stderr.write("HATA: havuz yok: %s\n" % havuz); sys.exit(2)
found = None
with io.open(havuz, encoding="utf-8") as f:
    for l in f:
        if not l.strip(): continue
        r = json.loads(l)
        if r.get("id","").lower() == key.lower() or r.get("slug") == key:
            found = r; break
if not found:
    sys.stderr.write("HATA: aday bulunamadı: %s\n" % key); sys.exit(2)

r = found
skor = r.get("skor", {}) or {}
print("🗂️ %s  ·  %%%s  ·  %s" % (r.get("id","?"), r.get("pct","?"), r.get("sinif","")))
print("")
print("BAŞLIK: %s" % r.get("baslik",""))
print("")
print("GOAL: %s" % r.get("goal",""))
if r.get("nicin_degerli"):
    print("")
    print("NİÇİN DEĞERLİ: %s" % r.get("nicin_degerli"))
print("")
print("ALT-SKORLAR: değer=%s · yapılabilirlik=%s · kanıt-gücü=%s · uyum=%s · jüri=%s" % (
    skor.get("deger",""), skor.get("yapilabilirlik",""), skor.get("kanit_gucu",""), skor.get("uyum",""), skor.get("juri","")))
if skor.get("gerekce"):
    print("GEREKÇE: %s" % skor.get("gerekce"))
print("")
print("KANIT: %s" % r.get("kanit",""))
print("")
print("DOKÜMAN: %s" % r.get("dokuman",""))
print("DURUM: %s" % r.get("durum",""))
t = r.get("terfi") or {}
if t.get("layiha_kodu"):
    print("TERFİ: %s → %s (%s)" % (r.get("id"), t.get("layiha_kodu"), t.get("tarih","")))
PY
  ;;
  durum)
    HAVUZ="$HAVUZ" python3 - <<'PY'
import os, json, io, collections

havuz = os.environ["HAVUZ"]
recs = []
if os.path.exists(havuz):
    with io.open(havuz, encoding="utf-8") as f:
        for l in f:
            if l.strip():
                try: recs.append(json.loads(l))
                except Exception: pass

durum_say = collections.Counter(r.get("durum","?") for r in recs)
sinif_say = collections.Counter(r.get("sinif","?") for r in recs if r.get("durum") == "aday")

print("🗂️ LAYİHA ADAY-HAVUZU · ÖZET · toplam=%d" % len(recs))
print("")
print("DURUM:")
for k in ("aday", "terfi-edildi", "emekli"):
    print("  %-14s %d" % (k, durum_say.get(k, 0)))
diger = set(durum_say) - {"aday", "terfi-edildi", "emekli"}
for k in diger:
    print("  %-14s %d" % (k, durum_say[k]))
print("")
print("SINIF DAĞILIMI (yalnız aday):")
for k in ("sultan", "muhendislik", "urun"):
    print("  %-14s %d" % (k, sinif_say.get(k, 0)))
PY
  ;;
  terfi)
    # pozitif argümanları (id/slug), --gerekce ve Sultan-onayını ayır
    IDS=(); GEREKCE=""; SULTAN_ONAY=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --gerekce) GEREKCE="${2:-}"; shift 2 ;;
        --sultan-onay) SULTAN_ONAY=1; shift ;;
        --*) shift ;;
        *) IDS+=("$1"); shift ;;
      esac
    done
    [ "${#IDS[@]}" -gt 0 ] || { echo "HATA: terfi <id|slug> [<id|slug> ...] --sultan-onay [--gerekce \"...\"]" >&2; exit 2; }

    # ⚖️ SULTAN KİLİDİ (ADR-025 · otonom-fikir-hatti-DESIGN §11-9 / R3)
    # Taslak → GERÇEK layiha geçişi, fikir-hattındaki TEK insan kapısıdır. Bu komut bugüne kadar
    # kilitsizdi ve yalnız "çağıranı yok" diye güvendeydi — otonom hat bağlandığı an onay kapısı
    # SESSİZCE buharlaşırdı. Bayrağı ajan kendi iradesiyle koyamaz; Sultan'ın açık emri gerekir
    # (Yetki-Sınırı: insan-adına onay alanına ajan yazamaz).
    if [ "$SULTAN_ONAY" -ne 1 ]; then
      echo "HATA: taslağı GERÇEK layihaya çevirmek YALNIZ Sultan onayıyla olur (--sultan-onay)." >&2
      echo "      Bu, fikir-hattındaki tek insan kapısıdır; otomatik akış onu atlayamaz." >&2
      echo "      Adayı önce göster: layiha-aday-havuzu.sh goster ${IDS[0]}" >&2
      exit 2
    fi

    IDS_JSON="$(python3 -c "import json,sys; print(json.dumps(sys.argv[1:]))" "${IDS[@]}")"

    # Kök, havuzla AYNI kapıdan (hat-yolu) gelir — eski `git rev-parse --show-toplevel` worktree'de
    # ANA checkout yerine worktree'yi kök sanıyordu (B6 split-brain'in terfi-yüzü).
    HAT_KOK="$(hat_root)" || exit 2
    HAVUZ="$HAVUZ" DEFTERI_BIN="$DEFTERI_BIN" IDS_JSON="$IDS_JSON" GEREKCE="$GEREKCE" HAT_KOK="$HAT_KOK" python3 - <<'PY'
import os, json, io, sys, subprocess, re

havuz = os.environ["HAVUZ"]
defteri_bin = os.environ["DEFTERI_BIN"]
ids = json.loads(os.environ["IDS_JSON"])
gerekce = os.environ.get("GEREKCE", "")

if not os.path.exists(havuz):
    sys.stderr.write("HATA: havuz yok: %s\n" % havuz); sys.exit(2)

recs = []
with io.open(havuz, encoding="utf-8") as f:
    for l in f:
        if l.strip():
            try: recs.append(json.loads(l))
            except Exception: pass

by_key = {}
for r in recs:
    by_key[r.get("id","").lower()] = r
    if r.get("slug"): by_key.setdefault(r.get("slug"), r)

# --- 1) TÜM adayları ÖNCE doğrula (atomiklik: biri geçersizse hiçbiri terfi etmez) ---
root = os.environ["HAT_KOK"]

hedefler = []
for key in ids:
    r = by_key.get(key) or by_key.get(key.lower())
    if r is None:
        sys.stderr.write("HATA: aday bulunamadı: %s — hiçbir terfi uygulanmadı\n" % key)
        sys.exit(2)
    if r.get("durum") != "aday":
        sys.stderr.write("HATA: %s zaten durum=%s (yalnız durum=aday terfi edilebilir) — hiçbir terfi uygulanmadı\n" % (r.get("id"), r.get("durum")))
        sys.exit(2)
    dokuman = os.path.join(root, "_agents", "spec", "taslak-layiha", "%s-DESIGN.md" % r["slug"])
    if not os.path.exists(dokuman):
        sys.stderr.write("HATA: doküman yok: %s (%s) — hiçbir terfi uygulanmadı\n" % (dokuman, r.get("id")))
        sys.exit(2)
    hedefler.append(r)

# dedup (aynı kayıt iki kez verilmişse)
gorulen = set(); tekil = []
for r in hedefler:
    if r.get("id") in gorulen: continue
    gorulen.add(r.get("id")); tekil.append(r)
hedefler = tekil

if not os.path.exists(defteri_bin):
    sys.stderr.write("HATA: layiha-defteri.sh bulunamadı: %s — hiçbir terfi uygulanmadı\n" % defteri_bin)
    sys.exit(2)

# --- 2) her hedef için dokümanı taşı + defteri.sh ekle çağır (hepsi doğrulandıktan SONRA uygula) ---
tarih = subprocess.check_output(["date", "+%F"]).decode().strip()

sonuclar = []  # (id, slug, layiha_kodu)
for r in hedefler:
    slug = r["slug"]
    eski_dokuman = os.path.join(root, "_agents", "spec", "taslak-layiha", "%s-DESIGN.md" % slug)
    yeni_dokuman_rel = "_agents/spec/%s-DESIGN.md" % slug
    yeni_dokuman = os.path.join(root, yeni_dokuman_rel)

    if not os.path.exists(eski_dokuman):
        sys.stderr.write("HATA: doküman yok: %s — %s terfi edilemedi (önceki adımlar geri alınmadı, elle kontrol gerekir)\n" % (eski_dokuman, r.get("id")))
        sys.exit(2)

    # git mv varsa onu kullan, yoksa mv
    moved = False
    try:
        subprocess.run(["git", "mv", eski_dokuman, yeni_dokuman], check=True, cwd=root,
                        stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        moved = True
    except Exception:
        pass
    if not moved:
        os.makedirs(os.path.dirname(yeni_dokuman), exist_ok=True)
        os.replace(eski_dokuman, yeni_dokuman)

    # ilk satırı statü-değişimine çevir + son satıra terfi-notu ekle
    with io.open(yeni_dokuman, encoding="utf-8") as f:
        lines = f.read().splitlines()
    if lines and lines[0].startswith("> Statü:"):
        lines[0] = "> Statü: SALT-ARAŞTIRMA — İNŞA YOK"
    else:
        lines.insert(0, "> Statü: SALT-ARAŞTIRMA — İNŞA YOK")
    with io.open(yeni_dokuman, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    # layiha-defteri.sh ekle çağrısı — L-kodunu al
    resume = "%s işini inşa edelim" % slug
    cmd = [defteri_bin, "ekle", "--slug", slug, "--konu", r.get("baslik",""),
           "--dokuman", yeni_dokuman_rel, "--resume", resume]
    try:
        out = subprocess.check_output(cmd, cwd=root, stderr=subprocess.STDOUT).decode()
    except subprocess.CalledProcessError as e:
        sys.stderr.write("HATA: layiha-defteri.sh ekle başarısız (%s): %s\n" % (slug, e.output.decode() if e.output else str(e)))
        sys.exit(2)

    m = re.search(r"\b(L\d+)\b", out)
    layiha_kodu = m.group(1) if m else "?"

    with io.open(yeni_dokuman, "a", encoding="utf-8") as f:
        f.write("\n> Terfi: aday %s → layiha %s (%s)\n" % (r.get("id"), layiha_kodu, tarih))

    sonuclar.append((r.get("id"), slug, layiha_kodu))

# --- 3) havuz kaydını damgala (tek yazma-geçişi, tüm terfiler tamamlandıktan sonra) ---
terfi_id_set = {s[0] for s in sonuclar}
kod_by_id = {s[0]: s[2] for s in sonuclar}
out_lines = []
with io.open(havuz, encoding="utf-8") as f:
    for l in f:
        if not l.strip():
            continue
        r = json.loads(l)
        if r.get("id") in terfi_id_set:
            r["durum"] = "terfi-edildi"
            r["terfi"] = {"tarih": tarih, "layiha_kodu": kod_by_id[r["id"]], "gerekce": gerekce}
        out_lines.append(json.dumps(r, ensure_ascii=False) + "\n")
with io.open(havuz, "w", encoding="utf-8") as f:
    f.writelines(out_lines)

kalan = sum(1 for l in out_lines if json.loads(l).get("durum") == "aday")
print("OK: %d aday terfi etti:" % len(sonuclar))
for aid, slug, kod in sonuclar:
    print("  %s (%s) → %s" % (aid, slug, kod))
print("Havuzda %d aday kaldı (durum=aday)." % kalan)
PY
  ;;
  *) echo "HATA: bilinmeyen komut: $CMD (liste|goster|terfi|durum)" >&2; exit 2;;
esac
