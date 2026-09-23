#!/usr/bin/env bash
# gun-sonu.sh — gün sonu özeti DEFTERDEN üretilir, elle yazılmaz (K6-b/c, Sultan 22 Eyl 2026).
#
# Kaynaklar: <depo>/_agents/fabrika/kartlar/*.json (iş kartları) + <depo>/_agents/fabrika/karne.jsonl (denetimler).
# Üç bölüm: SULTAN'A GİDENLER (sınıf işi) · İÇERİDE BİTİRDİKLERİMİZ (Sultan'ın veto hakkı) · TIKANANLAR; ek: açık işler.
# Her satır bir karta bağlıdır; kartta olmayan şey özete giremez.
#
# Kullanım: gun-sonu.sh [--gun YYYY-MM-DD] [--yaz]   (--yaz: <depo>/_agents/fabrika/gun-sonu/<gün>.md dosyasına da yazar)
# rc: 0 üretildi · 3 defter yok (ölçülemedi)
set -uo pipefail
GUN="$(date +%F)"; YAZ=0
while [ $# -gt 0 ]; do case "$1" in --gun) GUN="$2"; shift 2 ;; --yaz) YAZ=1; shift ;; *) shift ;; esac; done
c="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" && DEPO="${KANIT_DEPO:-$(dirname "$c")}" || DEPO="${KANIT_DEPO:-}"
[ -n "$DEPO" ] || { echo "✗ depo kökü bulunamadı" >&2; exit 3; }
KD="$DEPO/_agents/fabrika/kartlar"; KARNE="$DEPO/_agents/fabrika/karne.jsonl"
ls "$KD"/*.json >/dev/null 2>&1 || { echo "◻ kart defteri yok ($KD) — özet üretilemez (ölçülemedi)"; exit 3; }
OZET="$(python3 - "$KD" "$KARNE" "$GUN" <<'PY'
import json,sys,glob,os
kd,karne,gun=sys.argv[1:]
kartlar=[json.load(open(p)) for p in sorted(glob.glob(os.path.join(kd,"*.json")))]
den={}
if os.path.exists(karne):
    for l in open(karne,encoding="utf-8"):
        if l.strip():
            r=json.loads(l)
            if r.get("olay")=="denetim": den[r["is"]]=r
def bugun(k):  # o gün açılmış YA DA o gün kapanmış
    return k["zaman"][:10]==gun or (k.get("bitis","")[:10]==gun)
g=[k for k in kartlar if bugun(k)]
sultan=[k for k in g if k["sultan"]]
icerde=[k for k in g if not k["sultan"] and k["durum"]=="bitti"]
tik=[k for k in g if k["durum"]=="tikandi"]
acik=[k for k in kartlar if k["durum"]=="acik"]
def puan(k):
    p=k.get("puan"); d=den.get(k["is"])
    if p: return f"{p['kod']}/5 {p['dogru']} · {p['tur']} tur"
    if d: return f"{d['puan']}/5 {d['dogru']} · {d['tur']} tur"
    return "puan YOK"
out=[f"# GÜN SONU · {gun} · {len(g)} iş (kart defterinden üretildi, elle satır yok)",""]
out.append(f"## Sultan'a gidenler ({len(sultan)})")
for k in sultan: out.append(f"- [{k['durum']}] **{k['is']}** — {k['cumle']} · sınıf: {', '.join(k['siniflar'])} · sahip {k['aldi']} · {puan(k)} · kanıt {'var' if k.get('kanit_var') else 'yok'}{' · PR '+k['pr'] if k.get('pr') else ''}")
out.append(""); out.append(f"## İçeride bitirdiklerimiz ({len(icerde)}) — 'bunu bana sormalıydınız' dersen sınıf kuralı bu vakayla düzelir")
for k in icerde: out.append(f"- **{k['is']}** — {k['cumle']} · sahip {k['aldi']} · {puan(k)} · kanıt {'var' if k.get('kanit_var') else '⚠ YOK'}{' · PR '+k['pr'] if k.get('pr') else ''}")
out.append(""); out.append(f"## Tıkananlar ({len(tik)})")
for k in tik: out.append(f"- **{k['is']}** — {k['cumle']} · yol: {k['tikanma']['yol']} · neden: {k['tikanma']['neden']} · sahip {k['aldi']}")
# 🔴 Kaçışlar Sultan'ın önüne gelir (23 Eyl kararı): sessiz delik olmaktan çıkar, kayda geçen istisna olur.
import os as _os
kac=_os.path.join(_os.path.dirname(kd),"kacis-defteri.log")  # kd=<depo>/_agents/fabrika/kartlar
sat=[l.strip() for l in open(kac,encoding="utf-8")] if _os.path.exists(kac) else []
bugun_kac=[l for l in sat if l[:10]==gun]
out.append(""); out.append(f"## Kapı kaçışları ({len(bugun_kac)}) — her biri bir istisnadır, veto hakkın var")
for l in bugun_kac:
    par=[x.strip() for x in l.split("|")]
    out.append(f"- {par[0][11:16]} · gerekçe: {par[2] if len(par)>2 else '?'} · komut: `{(par[3] if len(par)>3 else '?')[:70]}`")
if not bugun_kac: out.append("- (bugün kapı atlanmadı)")
out.append(""); out.append(f"## Açık işler ({len(acik)})")
for k in acik: out.append(f"- {k['is']} — sahip {k['aldi']} · açıldı {k['zaman'][:16]}{' · SULTAN' if k['sultan'] else ''}")
print("\n".join(out))
PY
)" || exit 3
printf '%s\n' "$OZET"
if [ "$YAZ" -eq 1 ]; then mkdir -p "$DEPO/_agents/fabrika/gun-sonu"; printf '%s\n' "$OZET" > "$DEPO/_agents/fabrika/gun-sonu/$GUN.md"; echo "→ yazıldı: _agents/fabrika/gun-sonu/$GUN.md"; fi
