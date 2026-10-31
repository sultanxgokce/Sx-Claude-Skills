#!/usr/bin/env bash
# kapi-yenile.test.sh — kapi-yenile.sh'ın KARAR mantığı (sıcak tazele mi, web-yenile'ye düş mü) çalıştırılarak ölçülür. Hermetik:
# curl · pgrep · kill · sha256sum · onar.sh sahte; ağ/tmux yok. Kapının kendisi (SIGHUP) kapi/kapi-yenile.test.mjs'de gerçek süreçle ölçülür.
#
# 🔴 ortak.sh PATH'in BAŞINA /usr/bin'i koyar → sahteler ortak.sh'tan SONRA öne alınır (kurtarici-kapali.test.sh dersi, 16 Eki).
set -u
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gecen=0; kalan=0
kapi() { if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
T=$(mktemp -d); D="$T/durum"; mkdir -p "$D" "$T/bin" "$T/calisma"
trap 'rm -r -- "$T"' EXIT
cp -r "$KOK/scripts" "$KOK/kapi" "$T/calisma/"
cat >> "$T/calisma/scripts/ortak.sh" <<'EOF'
export PATH="$TO_SAHTE_BIN:$PATH"
kill() { "$TO_SAHTE_BIN/kill" "$@"; }    # kill bash YERLEŞİĞİ — PATH'teki sahte onu geçemez, fonksiyon geçer
EOF
printf '#!/usr/bin/env bash\necho "ONAR --web-yenile çağrıldı: $*" >> "$TO_DURUM_DIZ/onar.log"; exit 0\n' > "$T/calisma/scripts/onar.sh"
# sahte curl: x-kapi-pano başlığını $T/sunulan dosyasından okur (her çağrıda; "SIGHUP sonrası değişti"yi sahte kill üretir)
printf '#!/usr/bin/env bash\n[ -f "%s/sunulan" ] || exit 7\nprintf "HTTP/1.1 200 OK\\r\\nx-kapi-pano: %%s\\r\\n\\r\\n" "$(cat %s/sunulan)"\n' "$T" "$T" > "$T/bin/curl"
# sahte pgrep: canlı pid $T/canli dosyasından; sahte kill: -HUP → $T/hup'a yazar ve (senaryo izin veriyorsa) sunulan sha'yı diske eşitler; -0 → canlı mı
cat > "$T/bin/pgrep" <<EOF
#!/usr/bin/env bash
[ -f "$T/canli" ] && cat "$T/canli"
EOF
cat > "$T/bin/kill" <<EOF
#!/usr/bin/env bash
case "\$1" in
  -HUP) echo "HUP \$2" >> "$T/hup"; [ -f "$T/hup-olur" ] && cp "$T/disk-sha" "$T/sunulan"; [ -f "$T/hup-oldurur" ] && { rm -f "$T/canli" "$T/sunulan"; }; exit 0 ;;
  -0) [ -f "$T/canli" ] ;;
esac
EOF
printf '#!/usr/bin/env bash\nprintf "%%s  -\\n" "$(cat %s/disk-sha)"\n' "$T" > "$T/bin/sha256sum"
chmod +x "$T/bin/"* "$T/calisma/scripts/onar.sh"
# sahte ps TESTİN BAŞINDA kurulur (H2): '-o etimes=' sorgusu $T/etimes'ten gelir, dosya yoksa BOŞ döner → kapı yaşı ölçülemez, eski akış.
# Kurulmazsa A-D bölümleri gerçek ps'i çağırır; taze çekilmiş CI makinesinde 1234 numaralı GERÇEK bir süreç olabilir ve dosya zamanı o sürecin
# başlangıcından yeni göründüğü için sınav 'kapı ESKİ' koluna girer (main'de 13 kaldı). Yerelde 1234 yok, sınav tesadüfen yeşildi.
printf '#!/usr/bin/env bash\ncase "$*" in *etimes*) cat "%s/etimes" 2>/dev/null ;; *) /usr/bin/ps "$@" ;; esac\n' "$T" > "$T/bin/ps"; chmod +x "$T/bin/ps"
printf 'abcdef123456' > "$T/disk-sha"
kos() { env -i PATH="$T/bin:/usr/bin:/bin" TO_SAHTE_BIN="$T/bin" HOME="$T" TO_KUTU=sinav TO_PROJE="$T" TO_DURUM_DIZ="$D" TO_BECERI_KOK="$T/calisma" \
  CORTEX_ACCESS_ENV="$T/yok.env" TO_KAPI_PORT=1 TO_TTYD_SOKET="$T/yok.sock" bash "$T/calisma/scripts/kapi-yenile.sh" "$@" 2>&1; }
sifirla() { rm -f "$T/hup" "$T/hup-olur" "$T/hup-oldurur" "$T/canli" "$T/sunulan" "$D/onar.log" "$D/kapi.pid"; }
onar_sayisi() { c=$(grep -c "web-yenile" "$D/onar.log" 2>/dev/null); echo "${c:-0}"; }

echo "── sahteler devrede mi (ortak.sh PATH tuzağı)"
kapi "H1 sahte curl/pgrep ortak.sh'tan sonra da öndedir" "sahte" "$(kos --kuru >/dev/null; env -i PATH="$T/bin:/usr/bin:/bin" TO_SAHTE_BIN="$T/bin" TO_KUTU=sinav TO_DURUM_DIZ="$D" TO_BECERI_KOK="$T/calisma" bash -c '. "$TO_BECERI_KOK/scripts/ortak.sh"; [ "$(command -v pgrep)" = "$TO_SAHTE_BIN/pgrep" ] && echo sahte || echo GERÇEK')"
kapi "H2 sahte ps A-D'den ÖNCE kurulu: etimes dosyası yokken gerçek (var olan) bir pid için de BOŞ döner — CI'da 1234 gerçek süreç olabilir" "bos" "$(rm -f "$T/etimes"; v=$(env -i PATH="$T/bin:/usr/bin:/bin" ps -o etimes= -p 1 | tr -d ' '); [ -z "$v" ] && echo bos || echo "gercek:$v")"

echo "── A · zaten güncel"
sifirla; echo 1234 > "$T/canli"; echo 1234 > "$D/kapi.pid"; cp "$T/disk-sha" "$T/sunulan"
c=$(kos); rc=$?
kapi "A1 sunulan sha = disk sha → 'zaten güncel', rc 0" "0" "$rc"
kapi "A1b SIGHUP gönderilmez, onar çağrılmaz" "0" "$(( $( [ -f "$T/hup" ] && wc -l < "$T/hup" || echo 0 ) + $(onar_sayisi) ))"

sifirla; echo 1234 > "$T/canli"; echo 1234 > "$D/kapi.pid"; printf 'kapali' > "$T/sunulan"
c=$(kos); rc=$?
kapi "A2 pano köprüsü kapalı (KAPI_PANO=0 → başlık 'kapali') → 'tazelenecek şey yok', rc 0, SIGHUP/onar yok" "e" "$([ $rc = 0 ] && grep -q 'KAPALI' <<<"$c" && [ ! -f "$T/hup" ] && [ "$(onar_sayisi)" = 0 ] && echo e || echo "h:$c")"

echo "── B · sıcak tazeleme (yeni kapı: kapi.pid = canlı pid)"
sifirla; echo 1234 > "$T/canli"; echo 1234 > "$D/kapi.pid"; printf 'eskieski0000' > "$T/sunulan"; : > "$T/hup-olur"
c=$(kos); rc=$?
kapi "B1 rc 0 ve 'tazelendi … bağlantı kopmadı' der" "e" "$([ $rc = 0 ] && grep -q 'tazelendi.*bağlantı kopmadı' <<<"$c" && echo e || echo "h:$c")"
kapi "B2 SIGHUP tam bir kez, doğru pid'e" "HUP 1234" "$(cat "$T/hup")"
kapi "B3 onar.sh --web-yenile ÇAĞRILMAZ" "0" "$(onar_sayisi)"
kapi "B4 günlük satırı sha ve pid taşır" "1" "$(grep -c 'kapi-yenile: pano.js tazelendi (sha abcdef123456, pid 1234' "$D/gunluk.log")"

echo "── C · düşüşler (bağlantı bir kez kopar, SÖYLENİR)"
sifirla; printf 'eskieski0000' > "$T/sunulan"   # kapı süreci yok ama curl cevap veriyor (tutarsız) → yine de web-yenile
c=$(kos); kapi "C1 kapı süreci yok → onar --web-yenile'ye düşer ve söyler" "e" "$(grep -q 'kapı süreci yok → onar.sh --web-yenile' <<<"$c" && [ "$(onar_sayisi)" = 1 ] && echo e || echo "h:$c")"
sifirla; echo 1234 > "$T/canli"; printf 'eskieski0000' > "$T/sunulan"   # kapi.pid YOK → eski sürüm
c=$(kos); kapi "C2 🔴 kapi.pid yok (eski kapı) → SIGHUP GÖNDERİLMEZ (onu öldürürdü), web-yenile'ye düşer" "e" "$([ ! -f "$T/hup" ] && grep -q 'eski sürüm' <<<"$c" && [ "$(onar_sayisi)" = 1 ] && echo e || echo "h:$c")"
sifirla; echo 1234 > "$T/canli"; echo 999 > "$D/kapi.pid"; printf 'eskieski0000' > "$T/sunulan"   # pid uyuşmuyor (bayat dosya)
c=$(kos); kapi "C3 kapi.pid ≠ canlı pid (bayat) → SIGHUP yok, web-yenile" "e" "$([ ! -f "$T/hup" ] && grep -q 'eski sürüm' <<<"$c" && echo e || echo "h:$c")"
sifirla; echo 1234 > "$T/canli"; echo 1234 > "$D/kapi.pid"; printf 'eskieski0000' > "$T/sunulan"   # SIGHUP gider ama sha dönmez
c=$(kos); kapi "C4 SIGHUP sonrası sha dönmezse (5 sn) web-yenile'ye düşer, sebebi söyler" "e" "$(grep -q 'sha dönmedi' <<<"$c" && [ "$(onar_sayisi)" = 1 ] && echo e || echo "h:$c")"
sifirla; echo 1234 > "$T/canli"; echo 1234 > "$D/kapi.pid"; printf 'eskieski0000' > "$T/sunulan"; : > "$T/hup-oldurur"
c=$(kos); kapi "C5 SIGHUP kapıyı öldürdüyse beklemeden web-yenile'ye düşer ('öldü' der)" "e" "$(grep -q 'SIGHUP sonrası öldü' <<<"$c" && [ "$(onar_sayisi)" = 1 ] && echo e || echo "h:$c")"

echo "── D · --kuru hiçbir şey yapmaz"
sifirla; echo 1234 > "$T/canli"; echo 1234 > "$D/kapi.pid"; printf 'eskieski0000' > "$T/sunulan"; : > "$T/hup-olur"
c=$(kos --kuru); kapi "D1 kuru: yolu söyler, SIGHUP/onar yok" "e" "$(grep -q 'KURU: kapı 1234 SIGHUP' <<<"$c" && [ ! -f "$T/hup" ] && [ "$(onar_sayisi)" = 0 ] && echo e || echo "h:$c")"
sifirla; printf 'eskieski0000' > "$T/sunulan"
c=$(kos --kuru); kapi "D2 kuru + kapı yok: düşüşü söyler, onar ÇAĞRILMAZ" "e" "$(grep -q 'web-yenile' <<<"$c" && [ "$(onar_sayisi)" = 0 ] && echo e || echo "h:$c")"

echo "── K · çağıran"
kapi "K1 komut.sh kapi-yenile bu betiğe gider" "1" "$(grep -c 'kapi-yenile) shift; exec bash "\$D/kapi-yenile.sh"' "$KOK/scripts/komut.sh")"
kapi "K2 kapi-sinav.test.sh kapı tarafı sınavını (kapi-yenile.test.mjs) koşturur" "1" "$(grep -c 'node kapi-yenile.test.mjs' "$KOK/kapi/kapi-sinav.test.sh")"

echo "── MUTASYON (beklenen kırmızı): pid eşleşme kapısı sökülürse eski kapıya SIGHUP gider mi"
M="$T/mutant"; mkdir -p "$M"; cp -r "$T/calisma/scripts" "$T/calisma/kapi" "$M/"
python3 - "$M/scripts/kapi-yenile.sh" <<'PY'
import sys; p=sys.argv[1]; s=open(p,encoding='utf-8').read()
i=s.index('[ -n "$kayit" ] && [ "$kayit" = "$pid" ] || dus'); j=s.index('\n',i)
s=s[:i]+'true'+s[j:]; open(p,'w',encoding='utf-8').write(s)
PY
sifirla; echo 1234 > "$T/canli"; printf 'eskieski0000' > "$T/sunulan"; : > "$T/hup-oldurur"
env -i PATH="$T/bin:/usr/bin:/bin" TO_SAHTE_BIN="$T/bin" HOME="$T" TO_KUTU=sinav TO_PROJE="$T" TO_DURUM_DIZ="$D" TO_BECERI_KOK="$M" \
  CORTEX_ACCESS_ENV="$T/yok.env" TO_KAPI_PORT=1 TO_TTYD_SOKET="$T/yok.sock" bash "$M/scripts/kapi-yenile.sh" >/dev/null 2>&1
kapi "X1 MUTANT eski kapıya SIGHUP gönderir ve onu öldürür (C2 bunu yakalar)" "e" "$([ -f "$T/hup" ] && [ ! -f "$T/canli" ] && echo e || echo h)"

echo "── E · kapı diskteki koddan ESKİ çalışıyor (2.34.0 · WHRJ): SIGHUP yetmez, tam yeniden başlatma"
# sahte ps: '-o etimes= -p <pid>' → $T/etimes (süreç yaşı sn); kapi-eski-mi.sh gerçek find/date ile sunucu.mjs'in yaşını kıyaslar
# (sahte ps en başta kuruldu — H2)
eski_kur() { sifirla; echo 1234 > "$T/canli"; echo 1234 > "$D/kapi.pid"; cp "$T/disk-sha" "$T/sunulan"; echo 7200 > "$T/etimes"; touch "$T/calisma/kapi/sunucu.mjs"; }   # süreç 2 sa önce, kod ŞİMDİ
eski_kur; c=$(kos); rc=$?
kapi "E1 pano sha aynı olsa da kod süreçten yeni → 'ESKİ' der, SIGHUP YOK, onar --web-yenile bir kez" "e" "$(grep -q 'diskteki koddan ESKİ' <<<"$c" && [ ! -f "$T/hup" ] && [ "$(onar_sayisi)" = 1 ] && echo e || echo "h:$c")"
kapi "E1b günlüğe düşüş sebebi yazılır" "1" "$(grep -c 'kapi-yenile: kapı diskteki koddan ESKİ' "$D/gunluk.log")"
eski_kur; rm -f "$D/onar.log"; c=$(kos --kuru); rc=$?
kapi "E2 kuru kipte yolu söyler (web-yenile), onar ÇAĞRILMAZ, rc 0" "e" "$([ $rc = 0 ] && grep -q 'ESKİ.*web-yenile' <<<"$c" && [ "$(onar_sayisi)" = 0 ] && echo e || echo "h:$c")"
eski_kur; find "$T/calisma/kapi" -name '*.mjs' -exec touch -d '3 hours ago' {} +; c=$(kos); rc=$?
kapi "E3 kod süreçten eskiyse (güncel kapı) eski akış: 'zaten güncel', onar yok" "e" "$([ $rc = 0 ] && grep -q 'zaten güncel' <<<"$c" && [ "$(onar_sayisi)" = 0 ] && echo e || echo "h:$c")"
eski_kur; rm -f "$T/etimes"; find "$T/calisma/kapi" -name '*.mjs' -exec touch -d '3 hours ago' {} +; printf 'eskieski0000' > "$T/sunulan"; : > "$T/hup-olur"; c=$(kos); rc=$?
kapi "E4 kod yaşı ÖLÇÜLEMEZSE (ps yaş vermez) sıcak tazeleme akışı aynen sürer (SIGHUP, bağlantı kopmadı)" "e" "$([ $rc = 0 ] && grep -q 'bağlantı kopmadı' <<<"$c" && echo e || echo "h:$c")"

echo "── MUTASYON (beklenen kırmızı): kod-yaşı kapısı sökülürse eski kodlu kapıya yalnız 'zaten güncel' denir mi"
M2="$T/mutant2"; mkdir -p "$M2"; cp -r "$T/calisma/scripts" "$T/calisma/kapi" "$M2/"
python3 - "$M2/scripts/kapi-yenile.sh" <<'PY'
import sys; p=sys.argv[1]; s=open(p,encoding='utf-8').read()
a='if [ "$eski_rc" = 1 ]; then'; assert s.count(a)==1; s=s.replace(a,'if false; then'); open(p,'w',encoding='utf-8').write(s)
PY
eski_kur
cm=$(env -i PATH="$T/bin:/usr/bin:/bin" TO_SAHTE_BIN="$T/bin" HOME="$T" TO_KUTU=sinav TO_PROJE="$T" TO_DURUM_DIZ="$D" TO_BECERI_KOK="$M2" \
  CORTEX_ACCESS_ENV="$T/yok.env" TO_KAPI_PORT=1 TO_TTYD_SOKET="$T/yok.sock" bash "$M2/scripts/kapi-yenile.sh" 2>&1)
kapi "X2 MUTANT kod-yaşı kapısı yokken eski kodlu kapı 'zaten güncel' sayılır, onar çağrılmaz (E1 bunu yakalar)" "e" "$(grep -q 'zaten güncel' <<<"$cm" && [ "$(onar_sayisi)" = 0 ] && echo e || echo h)"

echo
echo "kapi-yenile.test: $gecen geçti · $kalan kaldı"
[ "$kalan" = 0 ]
