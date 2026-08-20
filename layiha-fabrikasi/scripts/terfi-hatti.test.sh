#!/usr/bin/env bash
# terfi-hatti.test.sh — terfi zincirinin İKİ değişmezini sınar (hermetik, ağsız).
#
# NİÇİN VAR: 2026-08-14'te defter `--dogrula`yı zorunlu yaptı, çağıran havuz güncellenmedi
#   → terfi 6 gün boyunca FİİLEN İMKÂNSIZDI ve **kimse denemediği için görünmedi**
#   (NÂZIR bulgusu f728dc35). Bir daha sessiz kalmasın diye bu sınav yazıldı.
set -uo pipefail
SUT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/layiha-aday-havuzu.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
GECTI=0; KALDI=0
ok(){ printf '  ✓ %s\n' "$1"; GECTI=$((GECTI+1)); }
no(){ printf '  ✗ %s\n' "$1"; KALDI=$((KALDI+1)); }

mkdir -p "$T/root/_agents/spec/taslak-layiha" "$T/bin"
( cd "$T/root" && git init -q . && git config user.email t@t && git config user.name t ) >/dev/null 2>&1
printf '{"id":"A001","slug":"deneme","baslik":"Deneme","durum":"aday"}\n' > "$T/havuz.jsonl"
printf '#!/usr/bin/env bash\nexit 2\n' > "$T/bin/red.sh";  chmod +x "$T/bin/red.sh"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" > "%s/args.txt"\necho "kayit L99 acildi"\n' "$T" > "$T/bin/kabul.sh"; chmod +x "$T/bin/kabul.sh"
_taslak(){ printf '%s' "$1" > "$T/root/_agents/spec/taslak-layiha/deneme-DESIGN.md"; }
_kos(){ ( cd "$T/root" && LAYIHA_ADAY_HAVUZ="$T/havuz.jsonl" LAYIHA_DEFTERI_BIN="$1" \
        bash "$SUT" terfi A001 --sultan-onay --gerekce t ) >"$T/out" 2>&1; echo $?; }

echo "== T1: belgede 'Doğrulama:' YOK → RED, belge TAŞINMAZ, mesaj reçeteyi söyler =="
_taslak '# D
> Statü: TASLAK
Govde.
'
rc=$(_kos "$T/bin/kabul.sh")
[ "$rc" = 2 ] && ok "rc=2" || no "rc=$rc (2 bekleniyordu)"
grep -q 'Doğrulama: <komut>' "$T/out" && ok "hata mesajı reçeteyi veriyor" || no "reçete yok"
[ -f "$T/root/_agents/spec/taslak-layiha/deneme-DESIGN.md" ] && ok "belge taşınmadı" || no "belge taşındı"

echo "== T2: satır VAR ama DEFTER REDDEDİYOR → belge TAŞINMAZ (ana değişmez) =="
_taslak '# D
> Statü: TASLAK
Doğrulama: bash scripts/deneme.test.sh
Govde.
'
rc=$(_kos "$T/bin/red.sh")
[ "$rc" = 2 ] && ok "rc=2" || no "rc=$rc"
[ -f "$T/root/_agents/spec/taslak-layiha/deneme-DESIGN.md" ] \
  && ok "DEĞİŞMEZ: defter kabul etmedi → artefakt taşınmadı" || no "DEĞİŞMEZ İHLALİ: belge taşındı"

echo "== T3: defter KABUL → --dogrula geçer, belge taşınır =="
rc=$(_kos "$T/bin/kabul.sh")
[ "$rc" = 0 ] && ok "rc=0" || no "rc=$rc"
grep -q -- '--dogrula' "$T/args.txt" 2>/dev/null && ok "--dogrula geçti" || no "--dogrula geçmedi"
[ "$(grep -A1 -- '--dogrula' "$T/args.txt" 2>/dev/null | tail -1)" = "bash scripts/deneme.test.sh" ] \
  && ok "değer belgeden okundu" || no "değer yanlış"
[ -f "$T/root/_agents/spec/deneme-DESIGN.md" ] && ok "belge taşındı" || no "belge taşınmadı"
[ ! -f "$T/root/_agents/spec/taslak-layiha/deneme-DESIGN.md" ] && ok "eski yerde yok" || no "eski yerde de duruyor"

printf '\nSONUÇ: %d geçti, %d kaldı\n' "$GECTI" "$KALDI"
[ "$KALDI" -eq 0 ]
