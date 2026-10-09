#!/usr/bin/env bash
# kosu-sar.sh — koşu kaydı sarmalayıcısı (Nexus kokpit-ux/05 şema sürüm 1.1, K1-K6). Sürüm 0.3 (global beceri, A290-A293).
#   Kullanım (kanon satırında):  bash /config/.claude/skills/kosu-kaydi/scripts/kosu-sar.sh <is> [--nobetci] -- <eski komut…>
#   Her koşu TAM BİR SATIR yazar (K1): /config/.kosu-kaydi/<kutu>.<YYYY-MM>.jsonl (kutu-yerel; /config/.claude ortak bağ) — özet yok.
#   sonuc: tamam · hata · ayakta-dokunmadim (K4: işin $KOSU_BEYAN dosyasına 'dokunmadim' yazmasıyla YA DA kanon satırında --nobetci
#          bayrağı varken rc 0 + boş çıktı) · atlandi-kilit (rc = KOSU_KILIT_RC, varsayılan 75: 'flock -n -E 75') · olculemedi (126/127)
#   sonraki_planli = CANLI crontab'daki kendi satırının ifadesinden · ifadeden_tahmin = KANON dosyasındaki satırdan (K5);
#   ikisi cron-sonraki.py ile (bağımsız, paket istemez); türetilemezse null + turetilemedi:true. Çelişki kokpitte sarı (A267).
#   sahip = kanon satırının üstündeki '# sahip:' notu (K3), yoksa "bilinmiyor"; kutuk = '# damga:' notu, yoksa null.
#   KANON verilmezse (KOSU_KANON boş) kanon = canlı crontab'ın kendisi: sahip/damga oradan okunur, tahmin = gözlem olur —
#   yani drift ölçülemez (kutu kanon dosyasını bildirmediği sürece). Kutunun adı KOSU_KUTU'dan (crontab başına
#   'KOSU_KUTU=<kutu>' satırı), yoksa DEFAULT_WORKSPACE'ten türer, o da yoksa "bilinmiyor" (konteyner hostname'i uydurma olurdu).
#   Dikişler (sınav): KOSU_KAYIT_DIZ · KOSU_KANON · KOSU_CRONTAB_KOMUT (varsayılan 'crontab -l') · KOSU_KUTU · KOSU_SIMDI.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SURUM="kosu-sar 0.3"
KULLANIM="kullanım: kosu-sar.sh <is> [--nobetci] [--kilit <dosya>] -- <komut…>"
IS="${1:-}"; shift || true; NOBETCI=0; KILIT=""
while [ $# -gt 0 ] && [ "$1" != "--" ]; do
  case "$1" in --nobetci) NOBETCI=1;; --kilit) KILIT="${2:-}"; [ -n "$KILIT" ] || { echo "$KULLANIM (--kilit dosya ister)" >&2; exit 2; }; shift;;
    *) echo "$KULLANIM (bilinmeyen: $1)" >&2; exit 2;; esac; shift
done
[ "${1:-}" = "--" ] || { echo "$KULLANIM" >&2; exit 2; }; shift
[[ "$IS" =~ ^[a-z0-9-]+$ ]] || { echo "geçersiz iş adı: $IS" >&2; exit 2; }
[ $# -gt 0 ] || { echo "komut yok" >&2; exit 2; }
KILIT_RC="${KOSU_KILIT_RC:-75}"   # --kilit ile kilit alınamayınca yazılan rc (EX_TEMPFAIL); komut hiç koşmaz → atlandi-kilit
# Kilidi SARMALAYICI alır (sezgi yok): kanon satırındaki 'flock -n' yerine '--kilit <dosya>'. flock alt komutun rc'sini olduğu gibi
# geçirdiği için "75 geldi → kilitti" çıkarımı kesin değildi (bağımsız göz, tur 4); burada kilit alınamadığını flock'un kendisi söyler.
_kutu_adi() {  # KOSU_KUTU → DEFAULT_WORKSPACE son parçası (kapimda ile aynı türetme) → bilinmiyor
  if [ -n "${KOSU_KUTU:-}" ]; then printf '%s' "$KOSU_KUTU"; return; fi
  local ws="${DEFAULT_WORKSPACE:-}"; ws="${ws%/}"
  [ -n "$ws" ] || { printf 'bilinmiyor'; return; }
  [ "$ws" = "/config/projects" ] && { printf 'nexus'; return; }
  local ad; ad="$(printf '%s' "${ws##*/}" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' | sed 's/-\{1,\}/-/g; s/^-//; s/-$//')"
  printf '%s' "${ad:-bilinmiyor}"
}
KUTU="$(_kutu_adi)"
DIZ="${KOSU_KAYIT_DIZ:-/config/.kosu-kaydi}"; mkdir -p "$DIZ"   # KUTU-YEREL: /config/.claude ortak bağdır (nazir'de Sultan kapısı, A291)
CRONTAB_KOMUT="${KOSU_CRONTAB_KOMUT:-crontab -l}"
KANON="${KOSU_KANON:-}"; KANON_GECICI=""
if [ -z "$KANON" ]; then  # kanon bildirilmemiş → canlı crontab kanon yerine geçer (drift ölçülemez, sahip okunur)
  KANON_GECICI="$(mktemp)"; $CRONTAB_KOMUT > "$KANON_GECICI" 2>/dev/null || true; KANON="$KANON_GECICI"
fi
_an() { date -Iseconds; }

# kanon satırı → sahip · damga · ifade (satırın hemen üstündeki yorum bloğundan)
_kanon_oku() {  # <dosya> → "sahip|damga|ifade"
  awk -v is="$IS" '
    /^#/ { if ($0 ~ /^# sahip:/) {s=$0; sub(/^# sahip:[ \t]*/,"",s)} ; if ($0 ~ /^# damga:/) {d=$0; sub(/^# damga:[ \t]*/,"",d)}; next }
    /^[0-9*@]/ { if (index($0, "kosu-sar.sh " is " ") > 0) { n=split($0,a," "); ifade=(a[1] ~ /^@/) ? a[1] : a[1]" "a[2]" "a[3]" "a[4]" "a[5];
                   # satır SONU etiketi (… # <ad> sahip:<ROL> damga:<yol>) satır üstü notu EZER: canlıya yalnız o taşınır (NÂZIR, A292)
                   k=index($0,"#"); if (k>0) { son=substr($0,k); if (match(son,/sahip:[^ \t]+/)) s=substr(son,RSTART+6,RLENGTH-6); if (match(son,/damga:[^ \t]+/)) d=substr(son,RSTART+6,RLENGTH-6) }
                   print s "|" d "|" ifade; exit } ; s=""; d="" ; next }
    { s=""; d="" }' "$1" 2>/dev/null
}
_canli_ifade() {  # canlı crontab'daki kendi satırının ifadesi
  $CRONTAB_KOMUT 2>/dev/null | awk -v is="$IS" '/^[0-9*@]/ && index($0, "kosu-sar.sh " is " ")>0 { n=split($0,a," "); print (a[1] ~ /^@/) ? a[1] : a[1]" "a[2]" "a[3]" "a[4]" "a[5]; exit }'
}
_sonraki() {  # <ifade> → ISO ya da boş
  [ -n "$1" ] || return 0
  python3 "$HERE/cron-sonraki.py" "$1" "${KOSU_SIMDI:-}" 2>/dev/null || true
}
_json() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1], ensure_ascii=False))' "$1"; }
_jnull() { if [ -n "$1" ]; then _json "$1"; else echo null; fi; }

KANON_BILGI="$(_kanon_oku "$KANON")"
SAHIP="${KANON_BILGI%%|*}"; REST="${KANON_BILGI#*|}"; DAMGA="${REST%%|*}"; KANON_IFADE="${REST#*|}"
[ "$KANON_BILGI" = "" ] && { SAHIP=""; DAMGA=""; KANON_IFADE=""; }
[ -n "$SAHIP" ] || SAHIP="bilinmiyor"

BEYAN_DOSYA="$(mktemp)"; export KOSU_BEYAN="$BEYAN_DOSYA"
BASLANGIC="$(_an)"; T0=$(date +%s); ATLANDI=0
if [ -n "$KILIT" ]; then
  exec 8>>"$KILIT" || { echo "kilit dosyası açılamadı: $KILIT" >&2; exit 2; }
  flock -n 8 || ATLANDI=1
fi
if [ "$ATLANDI" -eq 1 ]; then RC="$KILIT_RC"; CIKTI_VAR=0   # kilit dolu: komut KOŞMADI
elif [ "$NOBETCI" -eq 1 ]; then   # nöbetçi kipi: beyan KANON satırında (--nobetci); çıktı boş + rc 0 = ayaktaydı, dokunmadı (K4, NÂZIR A291)
  CIKTI_DOSYA="$(mktemp)"; if "$@" | tee "$CIKTI_DOSYA"; then RC=0; else RC=$?; fi
  [ -s "$CIKTI_DOSYA" ] && CIKTI_VAR=1 || CIKTI_VAR=0; rm -f "$CIKTI_DOSYA"
else
  if "$@"; then RC=0; else RC=$?; fi; CIKTI_VAR=1
fi
BITIS="$(_an)"; SURE=$(( $(date +%s) - T0 ))
BEYAN="$(tr -d '[:space:]' < "$BEYAN_DOSYA" 2>/dev/null || true)"; rm -f "$BEYAN_DOSYA"
if [ "$ATLANDI" -eq 1 ]; then SONUC="atlandi-kilit"   # kilit dolu, komut koşmadı — hata DEĞİL (A293); yalnız sarmalayıcının kendi kilidi sayılır
elif [ "$RC" -eq 0 ] && { [ "$BEYAN" = "dokunmadim" ] || { [ "$NOBETCI" -eq 1 ] && [ "$CIKTI_VAR" -eq 0 ]; }; }; then SONUC="ayakta-dokunmadim"
elif [ "$RC" -eq 0 ]; then SONUC="tamam"
elif [ "$RC" -eq 127 ] || [ "$RC" -eq 126 ]; then SONUC="olculemedi"   # rc olduğu gibi kalır (126 ≠ 127), yalnız sonuç sınıfı
else SONUC="hata"; fi

CANLI_IFADE="$(_canli_ifade)"
PLANLI="$(_sonraki "$CANLI_IFADE")"; TAHMIN="$(_sonraki "$KANON_IFADE")"
if [ -n "$TAHMIN" ]; then TAHMIN_B=true; else TAHMIN_B=false; fi
if [ -z "$PLANLI" ] || [ -z "$TAHMIN" ]; then TURETILEMEDI=true; else TURETILEMEDI=false; fi

DOSYA="$DIZ/$KUTU.$(date +%Y-%m).jsonl"
printf '{"is":%s,"kutu":%s,"sahip":%s,"baslangic":%s,"bitis":%s,"sure_sn":%s,"rc":%s,"sonuc":%s,"kutuk":%s,"sonraki_planli":%s,"ifadeden_tahmin":%s,"tahmin":%s,"turetilemedi":%s,"defter_ref":null,"sarmalayici":%s}\n' \
  "$(_json "$IS")" "$(_json "$KUTU")" "$(_json "$SAHIP")" "$(_json "$BASLANGIC")" "$(_json "$BITIS")" "$SURE" "$RC" "$(_json "$SONUC")" \
  "$(_jnull "$DAMGA")" "$(_jnull "$PLANLI")" "$(_jnull "$TAHMIN")" "$TAHMIN_B" "$TURETILEMEDI" "$(_json "$SURUM")" >> "$DOSYA"
[ -n "$KANON_GECICI" ] && rm -f "$KANON_GECICI"
exit "$RC"
