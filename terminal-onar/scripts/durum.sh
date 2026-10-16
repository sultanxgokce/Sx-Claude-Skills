#!/usr/bin/env bash
# durum.sh — düzenin beş parçasını ÖLÇER. RC=0 hepsi sağlam · RC=1 en az biri bozuk.
# Salt-okurdur; tek yazdığı şey canlı ana oturumun kimliğidir (onarımda doğru konuşmaya dönmek için).
#   --json   makine çıktısı (web düğmesi için)
set -u
. "$(dirname "$0")/ortak.sh"

declare -A D
tmux_var "$ANA_TMUX" && D[ana_tmux]=ok || D[ana_tmux]=yok
if id=$(claude_oturumu "$ANA_TMUX"); then
  D[ana_claude]=ok; [ "$id" != "?" ] && printf '%s\n' "$id" > "$DURUM_DIZ/ana-oturum"
else D[ana_claude]=yok; fi
if ttyd_saglam && kapi_saglam; then D[web_terminal]=ok
else D[web_terminal]="yok(terminal=$(ttyd_kod),kapı=$(kapi_kod))"; fi
# Kurtarıcı: işaret varken (Sultan 16 Eki, filo geneli kapalı) "kapalı" sağlam sayılır, "yok/düştü" DENMEZ; işaret var ama
# oturum hâlâ açıksa "kapalı ama AÇIK" → bozuk, onar.sh K0 kapatır.
if kurtarici_kapali; then
  claude_oturumu "$KURT_TMUX" >/dev/null && D[kurtarici]="kapalı-ama-AÇIK (onar.sh kapatır)" || D[kurtarici]="$KURT_KAPALI_SEBEP"
elif kid=$(claude_oturumu "$KURT_TMUX"); then
  D[kurtarici]=ok; [ "$kid" != "?" ] && printf '%s\n' "$kid" > "$DURUM_DIZ/kurtarici-oturum"
else D[kurtarici]=yok; fi
# Bekçi (2.3.0): satır KURULU mu değil, son 5 dakikada gerçekten KOŞTU mu (bekci.sh her koşuda iz bırakır; REVAK hata defteri
# 29 Eyl–10 Eki: cron süreci 11 gün yoktu, gösterge satıra bakıp "ok" diyordu). İz yoksa/bayatsa yalnız onar.sh'ın bekçiyi
# az önce kurduğu/doğruladığı 2 dakikalık pencerede "ok" (ilk koşu bekleniyor) — iz uydurulmaz, pencere dolunca kırmızı.
if [ -n "${TO_BEKCI_YOK:-}" ]; then D[bekci]=ok
elif ! bekci_kurulu; then D[bekci]=yok
else
  _son=$(cat "$DURUM_DIZ/bekci.son" 2>/dev/null); _kur=$(cat "$DURUM_DIZ/bekci.kuruldu" 2>/dev/null); _simdi=$(date +%s); _yeni=0
  [[ "$_kur" =~ ^[0-9]+$ ]] && [ $((_simdi - _kur)) -le 120 ] && _yeni=1
  if ! [[ "$_son" =~ ^[0-9]+$ ]]; then [ $_yeni = 1 ] && D[bekci]=ok || D[bekci]="izsiz(kurulu ama hiç koşmadı — zamanlayıcı servisi?)"
  elif [ $((_simdi - _son)) -gt 300 ]; then [ $_yeni = 1 ] && D[bekci]=ok || D[bekci]="durgun($(( (_simdi - _son) / 60 )) dk koşmadı — zamanlayıcı servisi?)"
  else D[bekci]=ok; fi
fi

rc=0; for k in "${!D[@]}"; do [ "${D[$k]}" = ok ] || [ "${D[$k]}" = "$KURT_KAPALI_SEBEP" ] || rc=1; done

if [ "${1:-}" = "--json" ]; then
  printf '{"saglam":%s,"ana_tmux":"%s","ana_claude":"%s","web_terminal":"%s","kurtarici":"%s","bekci":"%s","ana_oturum":"%s","zaman":"%s"}\n' \
    "$([ $rc = 0 ] && echo true || echo false)" "${D[ana_tmux]}" "${D[ana_claude]}" "${D[web_terminal]}" \
    "${D[kurtarici]}" "${D[bekci]}" "$(cat "$DURUM_DIZ/ana-oturum" 2>/dev/null)" "$(date -Is)"
else
  printf 'konuşma odası (tmux %s) : %s\n' "$ANA_TMUX" "${D[ana_tmux]}"
  printf 'konuşma (Claude)          : %s\n' "${D[ana_claude]}"
  printf 'web kapısı + terminal     : %s\n' "${D[web_terminal]}"
  printf 'kurtarıcı ajan            : %s\n' "${D[kurtarici]}"
  printf 'bekçi (dakikalık)         : %s\n' "${D[bekci]}"
  [ -f "$DURUM_DIZ/duraklat" ] && echo "⏸  bekçi DURAKLATILDI ($(cat "$DURUM_DIZ/duraklat"))"
  [ $rc = 0 ] && echo "SONUÇ: sağlam" || echo "SONUÇ: bozuk"
fi
exit $rc
