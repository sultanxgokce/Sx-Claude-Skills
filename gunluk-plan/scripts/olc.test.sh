#!/usr/bin/env bash
# olc.test.sh — günün ölçüm aracının sınavı. HERMETİK: sahte bir kök ve sahte bir çıpa aracı
# kurar; GERÇEK depoya, gerçek deftere, gerçek çıpaya DOKUNMAZ.
#
# 🔴 NİÇİN VAR: bu aracın hiç sınavı yoktu ve 6. kaynağı aylarca HER ajana SERDAR'ın defterini
#    okuttu (CEZERÎ bildirdi, 2026-10-06). İki zarar: yanlış ize bakan ajan yanlış plan yazar,
#    ve bir ajanın günlük izi onu görmesi gerekmeyen odalara sızar. Sınavın ağırlık merkezi
#    bu yüzden tek bir cümledir: BAŞKASININ DEFTERİ BASILMAZ — bulamazsan "ölçemedim" de.
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; A="$D/olc.sh"
TMP="$(mktemp -d)"; trap 'find "$TMP" -delete 2>/dev/null' EXIT
G=0; K=0
kapi(){ if [ "$2" = "$3" ]; then G=$((G+1)); printf '  🟢 %s\n' "$1"; else K=$((K+1)); printf '  🔴 %s — beklenen [%s] görülen [%s]\n' "$1" "$3" "$2"; fi; }

# ── sahte kök: içinde BAŞKASININ defteri BİLEREK var (sızıntı kapısının yemi)
KOK="$TMP/kok"; mkdir -p "$KOK/_agents/handoff"
printf 'SERDAR-GIZLI-SATIR-1\nSERDAR-GIZLI-SATIR-2\n' > "$KOK/_agents/handoff/serdar-defter.md"
printf 'DENEME-KENDI-IZIM-1\nDENEME-KENDI-IZIM-2\n'   > "$KOK/_agents/handoff/deneme-defter.md"
mkdir -p "$KOK/_agents/handoff"
printf 'KONUM-ESKI\n'  > "$KOK/_agents/handoff/konumlu-konum-20260101.md"
command sleep 0.05
printf 'KONUM-YENI\n'  > "$KOK/_agents/handoff/konumlu-konum-20260202.md"

# ── sahte beceri dizini: çıpa aracı yerine güdük bir betik (kimliği O söyler)
SK="$TMP/sk"; mkdir -p "$SK/gunluk-plan/scripts"
yeni_arac(){ printf '#!/usr/bin/env bash\ncase "${1:-}" in ajan) echo "%s";; *) exit 2;; esac\n' "$1" \
  > "$SK/gunluk-plan/scripts/cipa.sh"; }
eski_arac(){ printf '#!/usr/bin/env bash\nexit 2\n' > "$SK/gunluk-plan/scripts/cipa.sh"; }

kos(){ GUNLUK_PLAN_KOK="$KOK" GUNLUK_PLAN_SK="$SK" bash "$A" 2>&1; }
alti(){ printf '%s\n' "$1" | sed -n '/6\/7/,/7\/7/p'; }

# ── O1 · kimlik SORULUR: aracın söylediği ajanın kendi defteri okunur
yeni_arac deneme
O="$(alti "$(kos)")"
kapi "O1 kimlik çıpa aracından SORULUR; o ajanın kendi defteri okunur" \
     "$(grep -c 'DENEME-KENDI-IZIM-2' <<<"$O")/$(grep -c 'deneme-defter.md' <<<"$O")" "1/1"
kapi "O1b kendi defteri varken BAŞKASININ defteri basılmaz" \
     "$(grep -c 'SERDAR-GIZLI' <<<"$O")" "0"

# ── O2 · ÇEKİRDEK KAPI: kendi izi YOKKEN başkasının defteri basılmaz, 'ölçemedim' denir
yeni_arac izsiz
O="$(alti "$(kos)")"
kapi "O2 kendi izi yoksa SIZINTI YOK + 'ölçemedim' + aradığı adlar yazılı" \
     "$(grep -c 'SERDAR-GIZLI' <<<"$O")/$(grep -c 'ölçemedim' <<<"$O")/$(grep -c 'izsiz-defter.md' <<<"$O")" \
     "0/1/1"

# ── O3 · araç eski/yok: kimlik sorulamıyorsa yine SUSAR
eski_arac
O="$(alti "$(kos)")"
kapi "O3 çıpa aracı 'ajan' desteklemiyorsa ölçemedim der, başkasının defterini BASMAZ" \
     "$(grep -c 'SERDAR-GIZLI' <<<"$O")/$(grep -c 'ölçemedim' <<<"$O")" "0/1"
rm -f -- "$SK/gunluk-plan/scripts/cipa.sh"
O="$(alti "$(kos)")"
kapi "O3b araç hiç yoksa da aynı davranış (fail-closed)" \
     "$(grep -c 'SERDAR-GIZLI' <<<"$O")/$(grep -c 'ölçemedim' <<<"$O")" "0/1"

# ── O4 · 'bilinmiyor' kimliği kendi dosyası sayılmaz
yeni_arac bilinmiyor
O="$(alti "$(kos)")"
kapi "O4 kimlik 'bilinmiyor' ise defter uydurulmaz (ölçemedim)" \
     "$(grep -c 'ölçemedim' <<<"$O")" "1"

# ── O5 · konum dosyası yedeği: EN YENİSİ seçilir
yeni_arac konumlu
O="$(alti "$(kos)")"
kapi "O5 defter yoksa kendi konum dosyası okunur ve EN YENİSİ seçilir" \
     "$(grep -c 'KONUM-YENI' <<<"$O")/$(grep -c 'KONUM-ESKI' <<<"$O")" "1/0"

# ── O6 · SALT-OKUR: araç sahte köke hiçbir şey yazmaz/değiştirmez
yeni_arac deneme
once="$(find "$KOK" -type f -printf '%p %s %T@\n' | sort | sha256sum)"
kos >/dev/null
sonra="$(find "$KOK" -type f -printf '%p %s %T@\n' | sort | sha256sum)"
kapi "O6 SALT-OKUR: ölçüm aracı ölçtüğü şeyi değiştirmez" "$([ "$once" = "$sonra" ] && echo ayni || echo degisti)" "ayni"

# ── O7 · SIZINTI SAYIMI (küme geneli): hiçbir kimlikte başkasının satırı geçmez
sizinti=0
# NOT: kimlik listesinde 'serdar' YOK — çünkü SERDAR koşarsa o defter ONUN KENDİ izidir ve
#   okunması doğrudur. Ölçülen şey başkasının izine erişim; her kimlik ayrıca ortam-taklidiyle
#   de koşulur (GUNLUK_PLAN_AJAN=serdar), ve o da sızdırmamalı.
for kim in deneme izsiz bilinmiyor konumlu; do
  yeni_arac "$kim"
  n="$(kos | grep -c 'SERDAR-GIZLI')" || n=0
  sizinti=$((sizinti + n))
  # ortam taklidi de aynı kümede ölçülür (yeşil sonuç "seçilmiş dört kimlik" demesin)
  n2="$(GUNLUK_PLAN_AJAN=serdar GUNLUK_PLAN_KOK="$KOK" GUNLUK_PLAN_SK="$SK" bash "$A" 2>&1 | grep -c 'SERDAR-GIZLI')" || n2=0
  sizinti=$((sizinti + n2))
done
kapi "O7 dört kimlik × (araç + ortam-taklidi) toplam sızıntı satırı" "$sizinti" "0"

# ── O9/O10 · KİMLİK TAKLİDİ: ortam değişkeni ikinci bir türetme OLARAK kullanılamaz
#    (bağımsız göz tur-1, 2026-10-06). Güdük araç ortamı bilerek YOK SAYAR; eğer olc.sh
#    kimliği kendi hesaplıyorsa 'serdar' adını alır ve onun defterini basar.
yeni_arac deneme
O="$(GUNLUK_PLAN_AJAN=serdar GUNLUK_PLAN_KOK="$KOK" GUNLUK_PLAN_SK="$SK" bash "$A" 2>&1 | sed -n '/6\/7/,/7\/7/p')"
kapi "O9 ortam 'serdar' derken bile kimlik ARAÇTAN gelir (ikinci türetme yok)" \
     "$(grep -c 'SERDAR-GIZLI' <<<"$O")/$(grep -c 'DENEME-KENDI-IZIM-2' <<<"$O")" "0/1"
kapi "O10 MUTASYON: ortam kısayolu geri eklenirse taklit TUTAR (kapı süs değil)" \
     "$(M2="$TMP/olc-mutant2.sh"; python3 - "$A" "$M2" <<'PY'
import sys
k,h=sys.argv[1],sys.argv[2]
s=open(k,encoding="utf-8").read()
s=s.replace('  local a arac\n  arac=', '  local a arac\n  a="${GUNLUK_PLAN_AJAN:-}"; [ -n "$a" ] && { printf \'%s\' "$a"; return; }\n  arac=',1)
open(h,"w",encoding="utf-8").write(s)
PY
       GUNLUK_PLAN_AJAN=serdar GUNLUK_PLAN_KOK="$KOK" GUNLUK_PLAN_SK="$SK" bash "$TMP/olc-mutant2.sh" 2>&1 | sed -n '/6\/7/,/7\/7/p' | grep -c 'SERDAR-GIZLI')" "2"

# ── MUTASYON · çivili yol geri gelirse sızıntı kapıları KIRMIZI olmalı
M="$TMP/olc-mutant.sh"
python3 - "$A" "$M" <<'PY'
import sys
kaynak, hedef = sys.argv[1], sys.argv[2]
s = open(kaynak, encoding="utf-8").read()
bas = s.find('bolum "6/7')
son = s.find('bolum "7/7')
eski = ('bolum "6/7 · Dün nerede bıraktım"\n'
        'd="$KOK/_agents/handoff/serdar-defter.md"\n'
        '[ -f "$d" ] && tail -12 "$d" || olcemedim "defter bulunamadı: $d"\n\n')
open(hedef, "w", encoding="utf-8").write(s[:bas] + eski + s[son:])
PY
yeni_arac izsiz
O="$(GUNLUK_PLAN_KOK="$KOK" GUNLUK_PLAN_SK="$SK" bash "$M" 2>&1 | sed -n '/6\/7/,/7\/7/p')"
kapi "O8 MUTASYON: çivili yol geri gelince BAŞKASININ defteri basılır (kapı süs değil)" \
     "$(grep -c 'SERDAR-GIZLI' <<<"$O")" "2"

echo; echo "SONUÇ: $G geçti · $K kaldı"
[ "$K" -eq 0 ]
