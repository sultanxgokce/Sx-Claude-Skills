#!/usr/bin/env bash
# kimlik-bekcisi.sh — beş koltuğun kimliği oturum yenilenince YÜKLENİR durumda mı? (BASİRET, 11 Ekim 2026)
#
# NİÇİN: 10-11 Ekim'de iki yeni kutuda (MAİŞET · ENİS) aynı eksik çıktı: kimlik kancası hiçbir yere
#   bağlı değildi, rol satırları yer tutucuydu. Elle onarıldı; ama kutuyu yeniden yerleştiren araç
#   (iskan ekip-yerlestir) rol alanlarını ve ayarları yeniden üretebilir (merkez, A323). Onarım
#   sessizce geri giderse ilk fark eden, kimliğini kaybetmiş bir koltuk olur. Bu bekçi onu ilk gün yakalar.
#
# Beş kapı (hepsi ölçülür, hiçbiri varsayılmaz):
#   1 rol satırları yer tutucu DEĞİL       (ekip-registry · beş üye)
#   2 SessionStart kancası BAĞLI            (.claude/settings.json → ekip-self-recognition.sh)
#   3 proje yönergesi VAR ve beşine hitap ediyor (CLAUDE.md · koltuk listesinde **AD** kalın; dosya yolunda
#     küçük harfle geçmek hitap sayılmaz — sınavın M6 mutasyonu bunu yakaladı)
#   4 her koltuğun görev kartı VAR          (_agents/handoff/<id>-gorev-brifi.md · "Tek cümle")
#   5 kanca her koltuk için kartı BASIYOR   (kancanın kendisi koşturulur — dosya var ≠ yükleniyor)
#
# Çıkış: 0 hepsi yeşil · 1 en az bir kapı kırmızı · 3 ölçemedim (python3 yok gibi) — yeşil DEĞİL.
# Kök: KIMLIK_KOK (sınav için) yoksa betiğin bir üst dizini.
set -uo pipefail
KOK="${KIMLIK_KOK:-$(cd "$(dirname "$0")/.." && pwd)}"
REG="$KOK/_agents/handoff/ekip-registry.yaml"
command -v python3 >/dev/null 2>&1 || { echo "ÖLÇEMEDİM: python3 yok"; exit 3; }
[ -f "$REG" ] || { echo "ÖLÇEMEDİM: registry yok ($REG)"; exit 3; }

KIRMIZI=0
kirmizi() { KIRMIZI=$((KIRMIZI+1)); echo "  ✗ $*"; }
yesil()   { echo "  ✓ $*"; }

UYELER="$(python3 -I - "$REG" <<'PY'
import re,sys
for l in open(sys.argv[1],encoding="utf-8"):
    m=re.match(r"\s*-\s*id:\s*(\S+)",l)
    if m: print(m.group(1))
PY
)"
SAYI=$(printf '%s\n' "$UYELER" | grep -c .)
[ "$SAYI" -ge 1 ] || { echo "ÖLÇEMEDİM: registry'de üye çözülemedi"; exit 3; }

# 1 · rol satırları
YER="$(python3 -I - "$REG" <<'PY'
import re,sys
cur=None; bad=[]; seen=set()
for l in open(sys.argv[1],encoding="utf-8"):
    m=re.match(r"\s*-\s*id:\s*(\S+)",l)
    if m: cur=m.group(1); continue
    m=re.match(r'\s*rol:\s*"?(.*?)"?\s*$',l)
    if m and cur:
        seen.add(cur); r=m.group(1)
        if (not r.strip()) or re.search(r"deneme-üyesi|FAZ-\d|yer ?tutucu|placeholder|TODO",r,re.I): bad.append(cur)
print(" ".join(bad)); print(len(seen))
PY
)"
BAD="$(sed -n 1p <<<"$YER")"; ROLLU="$(sed -n 2p <<<"$YER")"
if [ -n "$BAD" ]; then kirmizi "rol satırı yer tutucu: $BAD"
elif [ "$ROLLU" != "$SAYI" ]; then kirmizi "rol satırı eksik: $ROLLU/$SAYI üyede rol var"
else yesil "rol satırları gerçek ($SAYI/$SAYI)"; fi

# 2 · kanca bağlı mı
S="$KOK/.claude/settings.json"
if [ ! -f "$S" ]; then kirmizi "kanca bağlı değil: .claude/settings.json yok"
elif python3 -I - "$S" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
ok=any("ekip-self-recognition.sh" in h.get("command","")
       for e in d.get("hooks",{}).get("SessionStart",[]) for h in e.get("hooks",[]))
sys.exit(0 if ok else 1)
PY
then yesil "SessionStart kancası bağlı"
else kirmizi "kanca bağlı değil: settings.json'da SessionStart → ekip-self-recognition yok"; fi

# 3 · proje yönergesi
C="$KOK/CLAUDE.md"
if [ ! -f "$C" ]; then kirmizi "proje yönergesi yok (CLAUDE.md)"
else
  eksik=""; for id in $UYELER; do grep -qF "**$id**" <(python3 -I -c "import unicodedata,sys;print(unicodedata.normalize('NFKD',open(sys.argv[1],encoding='utf-8').read()).encode('ascii','ignore').decode().upper())" "$C") || eksik="$eksik $id"; done
  if [ -n "$eksik" ]; then kirmizi "yönerge şu koltukları anmıyor:$eksik"
  else yesil "proje yönergesi beş koltuğa hitap ediyor"; fi
fi

# 4 · kartlar
kartsiz=""; for id in $UYELER; do
  k="$KOK/_agents/handoff/$(tr '[:upper:]' '[:lower:]' <<<"$id")-gorev-brifi.md"
  { [ -f "$k" ] && grep -qF '**Tek cümle**' "$k"; } || kartsiz="$kartsiz $id"
done
if [ -n "$kartsiz" ]; then kirmizi "görev kartı yok/eksik:$kartsiz"; else yesil "görev kartları yerinde ($SAYI/$SAYI)"; fi

# 5 · kanca gerçekten kartı basıyor mu (koşturulur)
H="$KOK/scripts/ekip-self-recognition.sh"
if [ ! -f "$H" ]; then kirmizi "kanca betiği yok"
else
  basmayan=""; for id in $UYELER; do
    out="$(EKIP_REGISTRY="$REG" bash "$H" "$id" 2>/dev/null)"
    grep -q 'görev kartın: _agents' <<<"$out" && grep -qF 'Tek cümle' <<<"$out" || basmayan="$basmayan $id"
  done
  if [ -n "$basmayan" ]; then kirmizi "kanca kartı basmıyor:$basmayan"; else yesil "kanca her koltuğa kartını basıyor ($SAYI/$SAYI)"; fi
fi

if [ $KIRMIZI -gt 0 ]; then echo "SONUÇ: KIRMIZI ($KIRMIZI kapı) — kimlik yenilemede yüklenmeyebilir"; exit 1; fi
echo "SONUÇ: YEŞİL — beş kapı ($SAYI koltuk)"
