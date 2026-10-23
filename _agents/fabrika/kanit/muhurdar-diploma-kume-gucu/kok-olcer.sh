#!/usr/bin/env bash
# kok-olcer.sh <tescil/scripts dizini> — SIGKILL artığı ölçümü: yavaş sahte yargıçla gerçek 'diploma.sh sina' başlar, kök açılınca
#   süreç grubu kill -9 ile öldürülür (finally koşmaz), sonra dürüst sahte yargıçla ikinci 'sina' koşar. Sayılan: ikinci koşudan
#   SONRA geçici dizinde kalan diploma-kok-* sayısı. Çıkış 0 = artık 0 · 1 = artık kaldı · 3 = ölçülemedi (kök hiç açılmadı).
set -uo pipefail
S="$(cd "$1" && pwd)"; T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T"' EXIT
mkdir -p "$T/tmp" "$T/yavas" "$T/durust" "$T/defter" "$T/sicil"; printf 'persona: KOK-OLCUM\npersonel_no: 99.002\n' > "$T/sicil/99.002.yaml"
printf '#!/usr/bin/env bash\ncat >/dev/null; sleep 60\n' > "$T/yavas/claude"
printf '#!/usr/bin/env bash\ni="$(cat)"; if printf "%%s" "$i" | grep -qE "çarpımlarını|FAILED \\\\(|42 ms|- \\\\[ \\\\]"; then k=KALDI; else k=GECTI; fi\nprintf "{\\"structured_output\\":{\\"karar\\":\\"%%s\\",\\"not\\":\\"s\\"}}" "$k"\n' > "$T/durust/claude"
chmod +x "$T"/yavas/claude "$T"/durust/claude
ND="$(dirname "$(command -v node)")"; PY="$(dirname "$(command -v python3)")"
kos() { env TMPDIR="$T/tmp" PATH="$T/$1:$ND:$PY:/usr/bin:/bin" MUHURDAR_MODEL=claude DIPLOMA_DEFTERI="$T/defter/d.jsonl" SICIL_DIZIN="$T/sicil" \
  setsid bash "$S/diploma.sh" sina KOK-OLCUM --kanit "$T/kanit-$1" > "$T/$1.log" 2>&1 < /dev/null; }
# fonksiyonsuz, doğrudan arka plan: $! setsid'in kurduğu grubun lideri olsun (fonksiyon & ile ara alt kabuk lider olmaz, kill boşa gider)
env TMPDIR="$T/tmp" PATH="$T/yavas:$ND:$PY:/usr/bin:/bin" MUHURDAR_MODEL=claude DIPLOMA_DEFTERI="$T/defter/d.jsonl" SICIL_DIZIN="$T/sicil" \
  setsid bash "$S/diploma.sh" sina KOK-OLCUM --kanit "$T/kanit-yavas" > "$T/yavas.log" 2>&1 < /dev/null & sp=$!
for _ in $(seq 150); do ls -d "$T/tmp"/diploma-kok-* >/dev/null 2>&1 && break; sleep 0.1; done
sleep 1; kill -9 -- "-$sp" 2>/dev/null || { echo "ÖLÇÜLEMEDİ: süreç grubu öldürülemedi"; exit 3; }; wait "$sp" 2>/dev/null
n1=$(ls -d "$T/tmp"/diploma-kok-* 2>/dev/null | wc -l); echo "kill -9 sonrası kalan kök: $n1"
[ "$n1" -ge 1 ] || { echo "ÖLÇÜLEMEDİ: kök hiç açılmadı"; exit 3; }
kos durust; echo "ikinci sınav rc=$? · $(grep -m1 'süpürüldü' "$T/durust.log" || echo 'süpürme satırı yok')"
n2=$(ls -d "$T/tmp"/diploma-kok-* 2>/dev/null | wc -l); echo "ikinci sınavdan sonra kalan kök: $n2"
[ "$n2" = 0 ]
