#!/usr/bin/env bash
# Mutasyon (koltuk-kayit-okuyucu): açıcı/kayıt seçimini boz → sınav KIRMIZI olmalı. Kopyada koşar; pozitif kontrol + desen-yok kapısı.
K="$(cd "$(dirname "$0")/../../../.." && pwd)/terminal-onar"; M="$(mktemp -d)"; trap 'find "$M" -mindepth 1 -delete; rmdir "$M"' EXIT; r=0
kopya(){ find "$M" -mindepth 1 -delete; cp -r "$K/scripts" "$K/kapi" "$M/"; }
# sınav türüne göre koşucu: .mjs → node (bash ile koşmak HER ZAMAN düşer = sahte kırmızı)
kos(){ case "$1" in *.mjs) (cd "$M" && node "$1") >/dev/null 2>&1 ;; *) bash "$M/$1" >/dev/null 2>&1 ;; esac; }
kopya; if kos scripts/koltuk-ac.test.sh; then echo "  ✓ pozitif kontrol (koltuk-ac) YEŞİL"; else echo "  ✗ pozitif kontrol (koltuk-ac) KIRMIZI"; r=1; fi
kopya; if kos kapi/tarayici-sinav.mjs; then echo "  ✓ pozitif kontrol (tarayıcı) YEŞİL"; else echo "  ✗ pozitif kontrol (tarayıcı) KIRMIZI"; r=1; fi
mut(){ kopya; python3 -c 'import sys;p,a,b=sys.argv[1:4];s=open(p).read()
if a not in s: sys.exit(1)
open(p,"w").write(s.replace(a,b,1))' "$M/$1" "$2" "$3" || { echo "  ✗ $4 → desen yok"; r=1; return; }
  if kos "${5:-scripts/koltuk-ac.test.sh}"; then echo "  ✗ $4 → YEŞİL kaldı"; r=1; else echo "  ✓ $4 → kırmızı"; fi; }
mut scripts/koltuk-ac.sh 'if [ -f "$BASLAT" ] && [ -f "$ISKAN" ]; then' 'if false; then' "KO1 İSKÂN açıcısı hiç seçilmiyor (2.4.0 hâli: kayıtlı koltuk 'kayıtsız')"
mut scripts/koltuk-ac.sh '  ACICI=baslat; KAYIT="$ISKAN"' '  ACICI=baslat; KAYIT="$PROJE/_agents/handoff/aile-registry.yaml"' "KO2 İSKÂN'da kayıt aile-registry'den okunuyor (iki kopya → yanlış rol)"
mut scripts/koltuk-ac.sh 'case "$_ea" in *--resume-if-known*) ACICI=ekip-ac ;; esac' 'ACICI=ekip-ac' "KO3 grid ekip-ac.sh da açıcı sayılıyor (koltuk kapanır, geri gelmez)"
mut scripts/koltuk-ac.sh '        if tmux_var "$AD"; then echo "açıldı:' '        if true; then echo "açıldı:' "KO4 düşen baslat-claude'a 'açıldı' deniyor"
mut scripts/koltuk-ac.sh '{ [ "$YOL" = ekip-ac ] || [ "$YOL" = baslat ]; } && resume_var' '[ "$YOL" = ekip-ac ] && resume_var' "KO5 İSKÂN koltuğunda konuşma varken resume=false"
mut scripts/koltuk-ac.sh 'CWD="$(cwd_bul "$ROL")"; [ -d "${CWD:-}" ] || CWD="$PROJE"' 'CWD="$PROJE"' "KO6 kayıttaki çalışma dizini yok sayılıyor"
mut kapi/genel/uygulama.js "j.durum !== 'canli' && j.yol !== 'baslat');" "j.durum !== 'canli');" "KO7 İSKÂN koltuğunda iki düğme aynı işi yapıyor (Eski görünür)" kapi/tarayici-sinav.mjs
mut kapi/genel/uygulama.js ": j.yol === 'baslat' ? \`kayıtlı rol" ": j.yol === 'baslat-yok' ? \`kayıtlı rol" "KO8 ekran İSKÂN koltuğunu 'kayıtsız' yazıyor" kapi/tarayici-sinav.mjs
exit $r
