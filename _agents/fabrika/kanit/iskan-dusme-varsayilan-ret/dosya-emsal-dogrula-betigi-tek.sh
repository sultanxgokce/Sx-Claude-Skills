#!/usr/bin/env bash
# emsal-dogrula.sh — ENİS/SIHHAT emsali (11 Eki) için DOĞRULAMA ölçümü: beklenen davranış tutarsa rc=0, tutmazsa rc=1.
# Niçin: iskan kuru koşumu "plan-exit=3" döner; fabrika kanıt aracı rc=3'ü "sarı/ölçülemedi" okur. Bu sarmalayıcı
# iddiayı açık sınar (çıkış kodu + çıktı işaretleri) — yeşil "beklenen oldu", kırmızı "olmadı" demektir.
# Kullanım: emsal-dogrula.sh <iskan.sh yolu> <beklenti: korumasiz|red|uyar>
#   korumasiz = BASİRET'in A323 iddiası (0.10.2): düşen üye GÖRÜNÜR (uye-dusuyor: SIHHAT) ama KORUNMAZ (plan SIHHAT'sız basılır, rc=3)
#   red       = 0.10.3 varsayılan: uye-dusuyor + uye-dusme-reddi, rc=1, PLAN basılmaz
#   uyar      = 0.10.3 ISKAN_EY_DUSME=uyar: uye-dusuyor + uye-dusme-uyari-modu, plan basılır (SIHHAT'sız), rc=3
# Girdi: aynı canlı ENİS kaydı + 11 Eki'deki SIHHAT'sız roster; --dry-run (hiçbir yere yazmaz).
set -u
ISKAN="$1"; BEK="$2"
out="$(env ${BEK_ENV:-} ISKAN_EY_ROSTER="ENIS:yonetici MURSIT:uye" ISKAN_CLOUDTOP_REPO_DIR=/config/projects/cloudtop \
  bash "$ISKAN" ekip-yerlestir enis --dry-run 2>&1)"; rc=$?
printf '%s\n' "$out"
var()  { grep -qF -- "$1" <<<"$out"; }
plan_var=0; var "-- PLAN" && plan_var=1
sihhat_planda=0; grep -qE -- '^ +- SIHHAT \(' <<<"$out" && sihhat_planda=1
echo "── ölçülen: rc=$rc · uye-dusuyor:SIHHAT=$(var 'uye-dusuyor: SIHHAT' && echo 1 || echo 0) · plan=$plan_var · SIHHAT-planda=$sihhat_planda · red=$(var 'uye-dusme-reddi' && echo 1 || echo 0) · uyar-modu=$(var 'uye-dusme-uyari-modu' && echo 1 || echo 0)"
ok=1
case "$BEK" in
  korumasiz) [ "$rc" = 3 ] && var 'uye-dusuyor: SIHHAT' && [ $plan_var = 1 ] && [ $sihhat_planda = 0 ] && ! var 'uye-dusme-reddi' && ok=0 ;;
  red)       [ "$rc" = 1 ] && var 'uye-dusuyor: SIHHAT' && var 'uye-dusme-reddi' && [ $plan_var = 0 ] && ok=0 ;;
  uyar)      [ "$rc" = 3 ] && var 'uye-dusuyor: SIHHAT' && var 'uye-dusme-uyari-modu' && [ $plan_var = 1 ] && [ $sihhat_planda = 0 ] && ok=0 ;;
  *) echo "beklenti tanınmıyor: $BEK" >&2; exit 2 ;;
esac
[ $ok = 0 ] && echo "── HÜKÜM: beklenen '$BEK' davranışı TUTTU" || echo "── HÜKÜM: beklenen '$BEK' davranışı TUTMADI"
exit $ok
