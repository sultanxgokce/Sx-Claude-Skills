#!/usr/bin/env bash
# etiket-olcer.sh <kanit.sh> — kötü etiketle her üretici komut ne yapıyor? (geçici depo; gerçek kanıta dokunmaz)
# Satır: <komut> <etiket> → rc · kayıt sayısı (önce→sonra) · stderr'in son satırı (kırpık)
set -uo pipefail
K="$1"; T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete; rmdir "$T"' EXIT
( cd "$T" && git init -q -b main ) >/dev/null 2>&1; export KANIT_DEPO="$T"
bash "$K" olcum is-e iyi --asama tek -- echo 1 >/dev/null 2>&1
printf 'rapor\n' > "$T/rapor.txt"
say() { python3 -c 'import json,sys
try: print(len(json.load(open(sys.argv[1]))["kayitlar"]))
except Exception: print("yok")' "$T/_agents/fabrika/kanit/is-e/KANIT.json"; }
for et in "a/b" "../kac" "" "." ".."; do
  for kip in olcum dosya canli; do
    o="$(say)"
    case $kip in
      olcum) bash "$K" olcum is-e "$et" --asama tek -- echo 1 >/dev/null 2>"$T/e" ;;
      dosya) bash "$K" dosya is-e "$et" "$T/rapor.txt" >/dev/null 2>"$T/e" ;;
      canli) bash "$K" canli is-e "$et" --kaynak "dosya:$T/rapor.txt" --desen rapor >/dev/null 2>"$T/e" ;;
    esac; rc=$?
    printf '%-6s %-8s → rc=%s · kayıt %s→%s · %s\n' "$kip" "'$et'" "$rc" "$o" "$(say)" "$(tail -1 "$T/e" | cut -c1-110)"
  done
done
printf 'kaçış denetimi: kanıt dizini dışına yazılan dosya: %s\n' "$(find "$T/_agents/fabrika/kanit" -maxdepth 1 -type f -name 'olcum-*' | wc -l) üst dizinde · $(find "$T/_agents/fabrika" -maxdepth 1 -name '*kac*' | wc -l) kanit dışında"
