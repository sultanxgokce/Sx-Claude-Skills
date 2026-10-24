#!/usr/bin/env bash
# oda-ortam.test.sh — kadro kayıt kökü (2.17.0 · gorev_01M554PCYA0HWM6TM4KXY4E72V): kutuya özel <proje>/.oda/ortam izin listeli
# okunur, kapıya TEK işlevden (kapi_kayit_ortami) geçer; GERÇEK kapı süreci iskelet kökte bu ortamla başlatılıp /api/kadro ölçülür.
# Hermetik: geçici dizin, sahte koltuk listesi; gerçek tmux'a, gerçek kayda, canlı kapıya dokunmaz. + 3 mutant (kopya üstünde).
# kabuk-testleri: sure=120
set -uo pipefail
export KOLTUK_TUZ="$(mktemp -d)/tuz"   # 2.24.0: kimlik tuzu geçici yolda (gerçek $HOME'a dokunulmaz)
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; KOK="$(dirname "$D")"
G=0; K=0; ok(){ G=$((G+1)); echo "  ✓ $1"; }; kirmizi(){ K=$((K+1)); echo "  ✗ $1"; }
esit(){ [ "$1" = "$2" ] && ok "$3" || kirmizi "$3 :: '$1' ≠ '$2'"; }
T="$(mktemp -d)"; KAPI_PID=""
trap '[ -n "$KAPI_PID" ] && kill "$KAPI_PID" 2>/dev/null; rm -r -f -- "$T"' EXIT
PROJE="$T/proje iskelet"; mkdir -p "$PROJE/.oda" "$T/durum" "$T/ekip/_agents/handoff"
KAYIT="$T/ekip/_agents/handoff/aile-registry.yaml"
printf 'uyeler:\n  - id: AJAN1\n    tmux: "ajan1:0"\n    rol: "birinci"\n  - id: AJAN2\n    tmux: "ajan2:0"\n    rol: "ikinci"\n' > "$KAYIT"
ORTAK="${ORTAK_SH:-$D/ortak.sh}"
yukle(){ env -i PATH="$PATH" HOME="$T" TO_KUTU=sinav TO_PROJE="$PROJE" TO_DURUM_DIZ="$T/durum" "$@" bash -c '. "$0" >/dev/null 2>&1; printf "%s\n%s\n%s\n" "${AILE_REGISTRY:-}" "$ODA_ORTAM_RED" "$(kapi_kayit_ortami)"' "$ORTAK"; }

echo "— O1 izinli satır okunur, kapıya geçer (boşluklu yol dahil)"
printf '# merkez kutusu: ekip kaydı Nexus deposunda\nAILE_REGISTRY=%s\n' "$KAYIT" > "$PROJE/.oda/ortam"
mapfile -t R < <(yukle)
esit "${R[0]}" "$KAYIT" "O1a AILE_REGISTRY ortama alındı"
esit "${R[1]}" "0" "O1b reddedilen satır 0"
esit "$(env -i sh -c "${R[2]} sh -c 'printf %s\"|\"%s \"\$TO_PROJE\" \"\$AILE_REGISTRY\"'")" "$PROJE|$KAYIT" "O1c kapi_kayit_ortami boşluklu yolları bozmadan iletir (TO_PROJE + AILE_REGISTRY)"

echo "— O2 izin listesi dışı / göreli / var olmayan satırlar REDDEDİLİR"
printf 'PATH=/kotu\nKAPI_PORT=1\nAILE_REGISTRY=goreli/yol.yaml\nISKAN_REGISTRY=/yok/boyle/dosya.yaml\nbozuk satır\n' > "$PROJE/.oda/ortam"
mapfile -t R < <(yukle)
esit "${R[0]}" "" "O2a geçersiz AILE_REGISTRY alınmadı"
esit "${R[1]}" "5" "O2b beş satır reddedildi (PATH · KAPI_PORT · göreli · yok · bozuk)"
case "${R[2]}" in *KAPI_PORT*|*kotu*|*ISKAN*) kirmizi "O2c kapı ortamına izinsiz değer sızdı: ${R[2]}" ;; *) ok "O2c kapı ortamında yalnız TO_PROJE" ;; esac

echo "— O3 açık ortam kazanır · O4 dosya yoksa yalnız TO_PROJE"
printf 'AILE_REGISTRY=%s\n' "$KAYIT" > "$PROJE/.oda/ortam"; echo 'uyeler: []' > "$T/acik.yaml"
mapfile -t R < <(yukle AILE_REGISTRY="$T/acik.yaml")
esit "${R[0]}" "$T/acik.yaml" "O3 açıkça verilen AILE_REGISTRY dosyadakini ezmez"
mv "$PROJE/.oda/ortam" "$T/ortam.yedek"; mapfile -t R < <(yukle)
esit "${R[0]}" "" "O4a dosya yok → AILE_REGISTRY yok"
case "${R[2]}" in TO_PROJE=*AILE*) kirmizi "O4b fazladan alan: ${R[2]}" ;; TO_PROJE=*) ok "O4b yalnız TO_PROJE" ;; *) kirmizi "O4b TO_PROJE yok: ${R[2]}" ;; esac
mv "$T/ortam.yedek" "$PROJE/.oda/ortam"

echo "— O5 onar.sh kapıyı bu işlevle başlatır"
esit "$(grep -c 'TO_KUTU=$KUTU $(kapi_kayit_ortami) exec node $KAPI_DIZ/sunucu.mjs' "$D/onar.sh")" "1" "O5 başlatma satırı kapi_kayit_ortami'yi taşır"

echo "— O6 GERÇEK kapı: iskelet kökte önce kayıtsız, ayarla çalışan (canlıdaki '0 kişi · 8 kayıtsız' hatasının birebir sınavı)"
LISTE="$T/liste.sh"; printf '#!/usr/bin/env bash\n[ "$1" = --liste ] || exit 2\nprintf "ajan1\\t5\\t1\\tajan\\tbos\\t\\najan2\\t5\\t1\\tajan\\tbos\\t\\nsinav-ana\\t5\\t1\\tajan\\tbos\\t\\n"\n' > "$LISTE"; chmod +x "$LISTE"
kapi_olc(){  # $1 = kapi_kayit_ortami çıktısı → "calisan kayitsiz kapatilabilir_sayisi"
  local PORT=18798 SIFRE=sinav-parolasi-1234
  env -i PATH="$PATH" HOME="$T" sh -c "$1 KAPI_PORT=$PORT KAPI_TABAN=/sinav TO_KUTU=sinav TO_DURUM_DIZ='$T/durum' KAPI_TTYD_SOKET='$T/ttyd.sock' SINAV__TERMINAL_SIFRE=$SIFRE KAPI_KOLTUK_BETIK='$LISTE' TO_ANA_TMUX=sinav-ana KAPI_EKIPC= KAPI_OTURUM_DIZ='$T/oturum-yok' exec node '$KOK/kapi/sunucu.mjs'" >"$T/kapi.out" 2>"$T/kapi.err" &
  KAPI_PID=$!
  node -e "
    const P=$PORT; const bek=(ms)=>new Promise(r=>setTimeout(r,ms));
    (async()=>{ for(let i=0;i<60;i++){ await bek(100); try{ if((await fetch('http://127.0.0.1:'+P+'/sinav/giris')).status===200) break; }catch{} }
      const g=await fetch('http://127.0.0.1:'+P+'/sinav/giris',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({parola:'$SIFRE'})});
      const c='kapi='+((g.headers.get('set-cookie')||'').match(/kapi=([^;]+)/)||[])[1];
      const j=await (await fetch('http://127.0.0.1:'+P+'/sinav/api/kadro',{headers:{cookie:c}})).json();
      console.log((j.sayilar||{}).calisan, (j.kayitsiz||[]).length, (j.kayitsiz||[]).filter(o=>o.kapatilabilir).length); })().catch(e=>console.log('HATA',e.message));"
  kill "$KAPI_PID" 2>/dev/null; wait "$KAPI_PID" 2>/dev/null; KAPI_PID=""
}
mv "$PROJE/.oda/ortam" "$T/ortam.yedek"
esit "$(kapi_olc "$(env -i PATH="$PATH" HOME="$T" TO_KUTU=sinav TO_PROJE="$PROJE" TO_DURUM_DIZ="$T/durum" bash -c '. "$0" >/dev/null 2>&1; kapi_kayit_ortami' "$ORTAK")")" "0 2 0" "O6a ÖNCE (ayar yok): 0 çalışan · 2 kayıtsız · hiçbiri kapatılabilir değil (içlerinde Claude var)"
mv "$T/ortam.yedek" "$PROJE/.oda/ortam"
esit "$(kapi_olc "$(env -i PATH="$PATH" HOME="$T" TO_KUTU=sinav TO_PROJE="$PROJE" TO_DURUM_DIZ="$T/durum" bash -c '. "$0" >/dev/null 2>&1; kapi_kayit_ortami' "$ORTAK")")" "2 0 0" "O6b SONRA (ayar var): 2 çalışan · 0 kayıtsız"

echo "— M mutasyon (ortak.sh kopyası üstünde)"
mut(){ local ad="$1" sed_="$2" bek="$3"; shift 3; local MR="$T/ortak-mut.sh"; sed -e "$sed_" "$ORTAK" > "$MR"
  if cmp -s "$MR" "$ORTAK"; then kirmizi "$ad: sed değiştirmedi"; return; fi
  local out; out="$(ORTAK_SH="$MR" "$@")"; [ "$out" != "$bek" ] && ok "$ad: mutant ısırıldı" || kirmizi "$ad: mutant YAŞIYOR ($out)"; }
mut_izin(){ printf 'KAPI_PORT=1\n' > "$PROJE/.oda/ortam.m"; env -i PATH="$PATH" HOME="$T" TO_KUTU=sinav TO_PROJE="$PROJE" TO_DURUM_DIZ="$T/durum" TO_ODA_ORTAM="$PROJE/.oda/ortam.m" bash -c '. "$0" >/dev/null 2>&1; printf %s "${KAPI_PORT:-yok}"' "$ORTAK_SH"; }
mut "M1 izin listesi kalkınca KAPI_PORT sızar → O2 yakalar" 's/    case "$ad" in AILE_REGISTRY|ISKAN_REGISTRY) ;; \*) ODA_ORTAM_RED=$((ODA_ORTAM_RED+1)); continue ;; esac/    :/' "yok" mut_izin
mut_var(){ printf 'AILE_REGISTRY=/yok/boyle.yaml\n' > "$PROJE/.oda/ortam.m"; env -i PATH="$PATH" HOME="$T" TO_KUTU=sinav TO_PROJE="$PROJE" TO_DURUM_DIZ="$T/durum" TO_ODA_ORTAM="$PROJE/.oda/ortam.m" bash -c '. "$0" >/dev/null 2>&1; printf %s "${AILE_REGISTRY:-yok}"' "$ORTAK_SH"; }
mut "M2 dosya-var denetimi kalkınca var olmayan yol alınır → O2 yakalar" 's/    \[ -f "$deger" \] || { ODA_ORTAM_RED=$((ODA_ORTAM_RED+1)); continue; }/    :/' "yok" mut_var
mut_ilet(){ env -i PATH="$PATH" HOME="$T" TO_KUTU=sinav TO_PROJE="$PROJE" TO_DURUM_DIZ="$T/durum" bash -c '. "$0" >/dev/null 2>&1; kapi_kayit_ortami' "$ORTAK_SH" | grep -c AILE_REGISTRY; }
mut "M3 kapi_kayit_ortami AILE_REGISTRY'yi iletmezse → O1c/O6b yakalar" "s/  \[ -n \"\${AILE_REGISTRY:-}\" \] && printf ' AILE_REGISTRY=%q' \"\$AILE_REGISTRY\"/  :/" "1" mut_ilet

echo; echo "GECEN=$G DUSEN=$K"; [ "$K" -eq 0 ]
