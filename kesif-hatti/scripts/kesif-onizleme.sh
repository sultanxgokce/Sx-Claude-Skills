#!/usr/bin/env bash
# kesif-onizleme.sh — bu kutudaki KEŞİF HATTINI tek ekranda göster (SALT-OKUR).
#
# NE: Ham keşiften Sultan-onayına giden hattın her durağını sayar ve son turu özetler:
#     KAŞİF tarar → bulgu-havuzu (HAM) → MUCİT süzer → mucit-defteri (KARAR) → aday-havuzu
#
# ⚠️ NİYE (Sultan sorusu, 2026-07-28): "ham bulgu ile süzülmüş sentezin farkını, hangi bulgunun
#     hangi etiketi aldığını, neyin tekrar süzmeye girmeyeceğini VS Code'da şeffaf göremiyorum;
#     JSONL okumak bezdirici." Defterler ZATEN doğru tasarlanmış (durum alanı + dedup_key +
#     verdikt defteri) ama okunur bir penceresi yoktu. Bu script o pencere.
#
# ⚠️ NE DEĞİL — SÜZME YAPMAZ. Bu bir GÖRÜNTÜLEYİCİ. "En iyi bulgular" DEMEZ; süzmek MUCİT'in
#     işidir (/mucit-suz). Buradaki "ham havuzdan örnek" listesi bir YARGI DEĞİL, yalnız
#     "henüz süzülmemişlerden en yenileri" penceresidir — aksi hâlde skill, MUCİT'in kararını
#     taklit ederek sahte-sentez üretirdi.
#
# SÜZMEYE UYGUNLUK: /mucit-suz'ün T1 kapısıyla AYNI kural (mucit-t1.sh:199):
#     durum ∈ {ham, kart-red} olanlar süzmeye girer; bitti·cozuluyor·aday-onerildi·kart·elendi HARİÇ.
#     Ayrıca mucit-defteri'nde kaydı olan bulgu BU GÖRÜNTÜLEYİCİDE "süzülmüş" sayılır.
#     ⚠️ 2026-07-28 ölçümü: motorun kendisi (mucit-t1.sh:218) defterE BAKMIYOR — kararı olan
#     bulgu yine de süzmeye giriyor. Yani buradaki "SÜZMEYE HAZIR" sayısı motorun fiilen
#     işleyeceğinden AZ olabilir. Delik uc-elek-suzme-DESIGN F1+F2'de kapatılıyor.
#
# DÜRÜSTLÜK: dosya yoksa "kayıt yok" der, SIFIR yazmaz (yok ≠ boş). Sayı uydurmaz.
# İ1: yalnız BU kutunun defterlerini okur; ssh/ağ yok, hiçbir şey yazmaz.
#
# Kullanım: bash kesif-onizleme.sh [--porcelain]
# Env: KESIF_REPO_ROOT (test/override)
# Çıkış: 0=okundu · 2=ortam hatası (python3 yok / hiçbir defter yok)
set -uo pipefail

PORCELAIN=0
[ "${1:-}" = "--porcelain" ] && PORCELAIN=1
[ $# -gt 1 ] && { echo "kullanım: kesif-onizleme.sh [--porcelain]" >&2; exit 2; }
case "${1:-}" in ""|--porcelain) ;; *) echo "kullanım: kesif-onizleme.sh [--porcelain]" >&2; exit 2 ;; esac

command -v python3 >/dev/null 2>&1 || { echo "HATA: python3 yok — defterler okunamadı." >&2; exit 2; }

ROOT="${KESIF_REPO_ROOT:-}"
[ -n "$ROOT" ] || ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$ROOT" ] || ROOT="$PWD"

ROOT="$ROOT" PORCELAIN="$PORCELAIN" python3 - <<'PY'
import json, io, os, collections, sys

ROOT = os.environ["ROOT"]
POR  = os.environ["PORCELAIN"] == "1"
SLUG = os.path.basename(ROOT.rstrip("/"))

def yol(*p): return os.path.join(ROOT, *p)

def oku(path):
    """(kayitlar, durum) → durum: 'var' | 'yok' | 'bozuk'. YOK ≠ BOŞ (sahte-sıfır yasağı)."""
    if not os.path.exists(path): return [], "yok"
    kayit, bozuk = [], 0
    try:
        for satir in io.open(path, encoding="utf-8", errors="replace"):
            satir = satir.strip()
            if not satir: continue
            try: kayit.append(json.loads(satir))
            except Exception: bozuk += 1
    except Exception:
        return [], "bozuk"
    return kayit, ("bozuk" if bozuk and not kayit else "var")

HAVUZ = yol("_agents/handoff/bulgu-havuzu.jsonl")
ADAY  = yol("_agents/handoff/layiha-aday-havuzu.jsonl")
# mucit-defteri iki yerde yaşayabilir (kutuya göre) — İKİSİ de okunur, birleştirilir.
MUCIT_YOLLARI = [yol("_agents/mucit/mucit-defteri.jsonl"),
                 yol("_agents/handoff/mucit-defteri.jsonl")]
SEYIR = yol("_agents/kasif/seyir.jsonl")
TURLOG = yol("_agents/kasif/tur.log")

bulgular, b_durum = oku(HAVUZ)
adaylar,  a_durum = oku(ADAY)
seyir,    s_durum = oku(SEYIR)

kararlar, k_durum, k_yerler = [], "yok", []
for p in MUCIT_YOLLARI:
    kk, dd = oku(p)
    if dd == "var":
        kararlar += kk; k_durum = "var"; k_yerler.append(os.path.relpath(p, ROOT))

if b_durum == "yok" and k_durum == "yok" and a_durum == "yok":
    sys.stderr.write("HATA: bu kutuda keşif-hattı defteri bulunamadı (_agents/handoff/bulgu-havuzu.jsonl …)\n")
    sys.stderr.write("   → doğru dizinde misin? KESIF_REPO_ROOT=<yol> ile de verebilirsin.\n")
    sys.exit(2)

# ── sayımlar ────────────────────────────────────────────────────────────────
durum_say = collections.Counter(b.get("durum", "ham") for b in bulgular)
tip_say   = collections.Counter(b.get("tip", "?") for b in bulgular)
verdikt   = collections.Counter(k.get("verdikt", "?") for k in kararlar)
karar_verilen = {k.get("bulgu_id") for k in kararlar if k.get("bulgu_id")}

# T1-uygunluk: mucit-t1.sh ile AYNI kural + defterde kaydı olanı çıkar
UYGUN_DURUM = {"ham", "kart-red"}
suzmeye_hazir = [b for b in bulgular
                 if b.get("durum", "ham") in UYGUN_DURUM and b.get("id") not in karar_verilen]

son_tur = seyir[-1] if seyir else None
son_log = ""
if os.path.exists(TURLOG):
    try:
        satirlar = [l.strip() for l in io.open(TURLOG, encoding="utf-8", errors="replace") if l.strip()]
        son_log = satirlar[-1] if satirlar else ""
    except Exception: pass

def n(x): return "kayıt yok" if x == "yok" else ("bozuk" if x == "bozuk" else None)

if POR:
    w = sys.stdout.write
    w("slug\t%s\n" % SLUG)
    w("havuz\t%s\t%d\n" % (b_durum, len(bulgular)))
    for d, c in sorted(durum_say.items()): w("havuz-durum\t%s\t%d\n" % (d, c))
    for t, c in sorted(tip_say.items()):   w("havuz-tip\t%s\t%d\n" % (t, c))
    w("karar\t%s\t%d\n" % (k_durum, len(kararlar)))
    for v, c in sorted(verdikt.items()):   w("karar-verdikt\t%s\t%d\n" % (v, c))
    w("aday\t%s\t%d\n" % (a_durum, len(adaylar)))
    w("suzmeye-hazir\t%d\n" % len(suzmeye_hazir))
    if son_log: w("son-tur\t%s\n" % son_log)
    for b in suzmeye_hazir[-5:]:
        w("ornek\t%s\t%s\t%s\n" % (b.get("id","?"), b.get("tip","?"), b.get("baslik","")[:90]))
    sys.exit(0)

# ── insan-okur ──────────────────────────────────────────────────────────────
print("🔭 KEŞİF HATTI · %s" % SLUG)
print("")
print("   KAŞİF tarar → HAM havuz → MUCİT süzer → KARAR defteri → ADAY havuzu → sen")
print("")

if n(b_durum): print("HAM havuz        %s" % n(b_durum))
else:
    parca = " · ".join("%s %d" % (t, c) for t, c in sorted(tip_say.items(), key=lambda x: -x[1]))
    print("HAM havuz        %-4d (%s)" % (len(bulgular), parca))
    for d, c in sorted(durum_say.items(), key=lambda x: -x[1]):
        etiket = {"ham": "henüz dokunulmamış", "cozuldu": "çözülmüş",
                  "elendi-kalici": "kalıcı elendi — olgu-temelli, geri gelmez",
                  "cozuluyor-mvp": "çözülüyor", "yanlis-alarm": "yanlış alarm",
                  "kart-red": "kart reddedildi", "aday-onerildi": "aday olarak sunuldu"}.get(d, d)
        print("                   · %-18s %d   (%s)" % (d, c, etiket))

if n(k_durum): print("KARAR defteri    %s   → MUCİT bu kutuda hiç süzmemiş" % n(k_durum))
else:
    print("KARAR defteri    %-4d (%s)" % (len(kararlar), ", ".join(k_yerler)))
    for v, c in sorted(verdikt.items(), key=lambda x: -x[1]):
        etiket = {"elendi": "elendi (kalıcı mı geçici mi: gerekçeye bağlı — bkz not alanı)",
                  "aday-arzi": "ADAY oldu → sana sunuldu",
                  "preview": "kalibrasyon önizlemesi (deftere yazılmadı)",
                  "mihenk-alani": "ürün/pazar alanı — ayrı hat",
                  "cap-ertelendi": "hafta tavanı doluydu, ertelendi",
                  "tema": "AYLIK SENTEZ teması → /layiha ile ilerler (kotaya saymaz)",
                  "dogum": "doğum kaydı"}.get(v, v)
        print("                   · %-18s %d   (%s)" % (v, c, etiket))

if n(a_durum): print("ADAY havuzu      %s" % n(a_durum))
else:          print("ADAY havuzu      %-4d  (Sultan onayı bekleyen sentezler)" % len(adaylar))

print("")
print("SÜZMEYE HAZIR    %d bulgu   (durum ∈ ham/kart-red · defterde kaydı yok)" % len(suzmeye_hazir))
if son_log:
    print("SON TUR          %s" % son_log)
elif son_tur:
    print("SON TUR          %s · aday=%s eklenen=%s" % (son_tur.get("tur","?"), son_tur.get("aday","?"), son_tur.get("eklenen","?")))
else:
    print("SON TUR          kayıt yok")

if suzmeye_hazir:
    print("")
    print("HAM havuzdan örnek — en yeni 5 (⚠️ bu bir YARGI DEĞİL; süzmek MUCİT'in işi: /mucit-suz)")
    for b in suzmeye_hazir[-5:]:
        print("  %-6s %-8s %s" % (b.get("id","?"), b.get("tip","?"), b.get("baslik","")[:88]))

print("")
print("süzme turu başlat: /mucit-suz kalibrasyon   ·   defterler: _agents/handoff/*.jsonl")
PY
