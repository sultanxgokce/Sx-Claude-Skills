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
if kid=$(claude_oturumu "$KURT_TMUX"); then
  D[kurtarici]=ok; [ "$kid" != "?" ] && printf '%s\n' "$kid" > "$DURUM_DIZ/kurtarici-oturum"
else D[kurtarici]=yok; fi
{ bekci_kurulu || [ -n "${TO_BEKCI_YOK:-}" ]; } && D[bekci]=ok || D[bekci]=yok

rc=0; for k in "${!D[@]}"; do [ "${D[$k]}" = ok ] || rc=1; done

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
