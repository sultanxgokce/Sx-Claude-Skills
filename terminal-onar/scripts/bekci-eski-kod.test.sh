#!/usr/bin/env bash
# bekci-eski-kod.test.sh — dakikalık bekçi kapının DİSKTEKİ KODDAN ESKİ çalıştığını görünce bir kez yeniler (2.35.0 · kart kapi-bekci-eski-kod · görev …WHRJ).
#   Hermetik: sahte ps/pgrep/tmux/crontab; kapi-yenile.sh YERİNE çağrı sayan kukla (gerçek kapı doğmaz, HUP yok); durum.sh/dava-gunluk.sh kukla.
#   Ölçülen: E1 eski → yenile 1 kez + günlük + damga · E2 aynı kod → ikinci yenileme YOK · E3 kod yeniden değişti → yine 1 · E4 kapı güncel → 0
#            E5 ölçülemedi (süreç yok) → 0, damga yok · E6 duraklat → 0 · E7 yenileme düşerse damga yazılmaz, günlükte DÜŞTÜ, sonraki turda tekrar
#   Mutant (bekci-eski-kod.mutasyon.sh): blok kaldırılınca E1 düşer.
set -u
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gecen=0; kalan=0
kapi() { if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
T=$(mktemp -d); D="$T/durum"; mkdir -p "$D" "$T/bin" "$T/proje"; trap 'python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$T"' EXIT
printf '#!/usr/bin/env bash\n[ "$1" = -l ] && cat "%s/crontab.txt" 2>/dev/null; exit 0\n' "$T" > "$T/bin/crontab"
printf '#!/usr/bin/env bash\nexit 1\n' > "$T/bin/tmux"
# sahte ps: '-o etimes= -p' → $T/etimes · sahte pgrep: $T/canli varsa pid 1234 (kapı süreci), yoksa yok
printf '#!/usr/bin/env bash\ncase "$*" in *etimes*) cat "%s/etimes" 2>/dev/null ;; *) /usr/bin/ps "$@" ;; esac\n' "$T" > "$T/bin/ps"
printf '#!/usr/bin/env bash\ncase "$*" in *sunucu.mjs*) [ -f "%s/canli" ] && { cat "%s/canli"; exit 0; } || exit 1 ;; *) exit 1 ;; esac\n' "$T" "$T" > "$T/bin/pgrep"
chmod +x "$T/bin/"*
M="$T/calisma"; mkdir -p "$M/kapi"; cp -r "$KOK/scripts" "$M/"; printf '// sahte kapı\n' > "$M/kapi/sunucu.mjs"
printf '\nexport PATH="$TO_SAHTE_BIN:$PATH"\n' >> "$M/scripts/ortak.sh"
# kuklalar: kapi-yenile çağrı sayar (KAPI_YENILE_RC ile düşürülebilir), durum.sh ok der (bekçi orada biter), dava-gunluk sessiz
printf '#!/usr/bin/env bash\necho "yenile $(date +%%s)" >> "%s/yenile.log"; exit "${KAPI_YENILE_RC:-0}"\n' "$D" > "$M/scripts/kapi-yenile.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$M/scripts/durum.sh"; printf '#!/usr/bin/env bash\nexit 0\n' > "$M/scripts/dava-gunluk.sh"
kos() { env -i PATH="$T/bin:/usr/bin:/bin" TO_SAHTE_BIN="$T/bin" HOME="$T" TO_KUTU=sinav TO_PROJE="$T/proje" TO_DURUM_DIZ="$D" TO_CRONTAB="$T/bin/crontab" \
      TO_BECERI_KOK="$M" CORTEX_ACCESS_ENV="$T/yok.env" TO_KAPI_PORT=1 TO_TTYD_SOKET="$T/yok.sock" KAPI_YENILE_RC="${KAPI_YENILE_RC:-0}" bash "$M/scripts/bekci.sh" >/dev/null 2>&1; echo $?; }
say() { grep -c '^yenile' "$D/yenile.log" 2>/dev/null || echo 0; }
sifirla() { rm -f "$D/yenile.log" "$D/kapi-kod.son" "$D/gunluk.log" "$D/duraklat"; }
eski_kur() { sifirla; echo 1234 > "$T/canli"; echo 7200 > "$T/etimes"; touch "$M/kapi/sunucu.mjs"; }   # süreç 2 sa önce doğmuş, kod ŞİMDİ değişmiş
guncel_kur() { sifirla; echo 1234 > "$T/canli"; echo 60 > "$T/etimes"; touch -d '3 hours ago' "$M/kapi/sunucu.mjs"; }

echo "── E eski kod → bir kez yenile"
eski_kur; rc=$(kos)
kapi "E1 kapı eski kodla → kapi-yenile 1 kez, rc 0" "1 0" "$(say) $rc"
kapi "E1b günlük: 'eski kodla çalışıyor → yeniliyor' + 'yenilendi'" "1 1" "$(grep -c 'eski kodla çalışıyor' "$D/gunluk.log") $(grep -c 'kapı yenilendi' "$D/gunluk.log")"
kapi "E1c damga dosyası (kapi-kod.son) yazıldı, sayı" "e" "$([[ "$(cat "$D/kapi-kod.son" 2>/dev/null)" =~ ^[0-9]+(\.[0-9]+)?$ ]] && echo e || echo h)"
echo 7300 > "$T/etimes"; rc=$(kos)
kapi "E2 aynı kod, süreç hâlâ eski görünse de (yenileme kuklaydı) İKİNCİ yenileme YOK (damga)" "1" "$(say)"
sleep 1; touch "$M/kapi/sunucu.mjs"; rc=$(kos)
kapi "E3 kod yeniden değişti → yine bir kez yenile (toplam 2)" "2" "$(say)"
echo "── E güncel / ölçülemedi / duraklat"
guncel_kur; rc=$(kos)
kapi "E4 kapı güncel (süreç koddan yeni) → yenileme 0, damga yok, rc 0" "0 h 0" "$(say) $([ -f "$D/kapi-kod.son" ] && echo e || echo h) $rc"
eski_kur; rm -f "$T/canli"; rc=$(kos)
kapi "E5 süreç yok (ölçülemedi, rc 2) → DOKUNMAZ: yenileme 0, damga yok" "0 h" "$(say) $([ -f "$D/kapi-kod.son" ] && echo e || echo h)"
eski_kur; printf 'sınav\n' > "$D/duraklat"; rc=$(kos)
kapi "E6 duraklat varken eski kod bile olsa yenileme 0" "0" "$(say)"
echo "── E yenileme düşerse"
eski_kur; rc=$(KAPI_YENILE_RC=1 kos)
kapi "E7 kapi-yenile düşerse damga YAZILMAZ, günlükte DÜŞTÜ; sonraki turda yeniden denenir (toplam 2)" "h 1 2" "$([ -f "$D/kapi-kod.son" ] && echo e || echo h) $(grep -c 'yenileme DÜŞTÜ' "$D/gunluk.log") $(KAPI_YENILE_RC=1 kos >/dev/null; say)"
echo "── mutasyon"
MU="$T/mut"; mkdir -p "$MU"; cp -r "$M/scripts" "$MU/"; cp -r "$M/kapi" "$MU/"
python3 - "$MU/scripts/bekci.sh" <<'PY'
import sys,re; p=sys.argv[1]; s=open(p,encoding='utf-8').read()
i=s.index('_ke="$(bash "$BETIK_DIZ/kapi-eski-mi.sh"'); j=s.index('\nfi\n', i)+4   # dış if'in sonu (iç fi'ler girintili, '\nfi\n' yalnız dışta)
s2=s[:i]+s[j:]; assert s2!=s and '_ke=' not in s2 and 'kapi-kod.son' not in s2; open(p,'w',encoding='utf-8').write(s2)
PY
eski_kur; rc=$(M="$MU" kos)
kapi "X1 MUTASYON: eski-kod bloğu kaldırılınca yenileme 0 (sınav bunu E1'de ısırır)" "0" "$(say)"
echo; echo "bekci-eski-kod.test: $gecen geçti · $kalan kaldı"; [ "$kalan" = 0 ]
