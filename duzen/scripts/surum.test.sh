#!/usr/bin/env bash
# surum.test.sh — sürüm yüzeyi hermetik sınavı (sahte paket + sahte depo + sahte kurulu kopya).
# S1 goster SKILL.md sürümünü basar · S2 kurulu kopya sürümü eşitse GÜNCEL rc 0 · S3 kurulu sürüm farklıysa BAYAT rc 1
# S4 ekipc kimliği: çekirdek metni birebir gömülü + hash tutuyor → GÜNCEL · S5 çekirdek değişti (gömülü eski) → BAYAT rc 1
# S6 hash gövdeyle tutmuyor → EL-DEĞMİŞ rc 1 · S7 ne kurulu ne işaretli kimlik → rc 3 ÖLÇÜLEMEDİ · S8 --uygula yok rc 2 (yazma yolu yok)
# S9 hiçbir dosyaya yazmaz (sahte depo md5'leri değişmez) · mutant: BAYAT'ı GÜNCEL sayan kopya S5 kırmızı
set -uo pipefail
export LC_ALL=C.UTF-8   # Türkçe karakterli ad/desen: C yerelinde sed y// ve grep -w bozulur (CI/kutu yerelinden bağımsız)
HERE="$(cd "$(dirname "$0")" && pwd)"; R="${SURUM_BETIK:-$HERE/surum.sh}"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null; find "$HERE" -maxdepth 1 -name ".mutant-surum-$$-*" -delete 2>/dev/null' EXIT
G=0; K=0
ok() { if [ "$2" -eq 0 ]; then G=$((G+1)); echo "  ✓ $1"; else K=$((K+1)); echo "  ✗ $1 ${3:-}"; fi; }

# sahte paket: scripts/surum.sh (sınanan betik) + SKILL.md + cekirdek/
P="$T/paket"; mkdir -p "$P/scripts" "$P/cekirdek"; cp "$R" "$P/scripts/surum.sh"
printf -- '---\nname: duzen\nversion: 1.2.3\n---\n' > "$P/SKILL.md"
printf '<!-- kaynak: Sx duzen/cekirdek · Nexus kopyası bu dosyayı okur -->\n# ORTAK-TEMEL manuel\nsatır bir\nsatır iki\n' > "$P/cekirdek/manuel-claude-base.md"
printf '<!-- kaynak: Sx duzen/cekirdek · Nexus kopyası bu dosyayı okur -->\n# ORTAK-TEMEL müdür\nmüdür satırı\n' > "$P/cekirdek/mudur-base.md"
printf '<!-- kaynak: Sx duzen/cekirdek · Nexus kopyası bu dosyayı okur -->\n# ORTAK-TEMEL otonom\notonom satırı\n' > "$P/cekirdek/otonom-ajan-base.md"
printf '<!-- kaynak: Sx duzen/cekirdek · izole kutu -->\n# ORTAK-TEMEL izole\nizole satırı\n' > "$P/cekirdek/izole-kutu-base.md"
printf '<!-- kaynak: Sx duzen/cekirdek · alt personel -->\n# ORTAK-TEMEL alt\nalt personel satırı\n' > "$P/cekirdek/alt-personel-base.md"
S="bash $P/scripts/surum.sh"

kimlik() {  # kimlik <dizin> <gövde-metni> [hash|bozuk]
  mkdir -p "$1"; local g="$2" h
  h="$(printf '%s\n' "$g" | python3 -I -c 'import sys,hashlib; print(hashlib.sha256(sys.stdin.read().encode()).hexdigest())')"
  [ "${3:-hash}" = bozuk ] && h="$(printf '%064d' 0)"
  { printf '<!-- ekipc:uretilen:basla surum=1 hash=%s -->\n' "$h"; printf '%s\n' "$g"; printf '<!-- ekipc:uretilen:bitti -->\n\n## ELLE (ekipc dokunmaz)\nnot\n'; } > "$1/AGENT.md"
}
D1="$T/depo1"; kimlik "$D1/_agents/bani" "$(printf '# ORTAK-TEMEL manuel\nsatır bir\nsatır iki\n\n## KİŞİ\nBÂNİ')"
mkdir -p "$D1/_agents/isaretsiz"; printf '# serbest kimlik\n' > "$D1/_agents/isaretsiz/AGENT.md"
D2="$T/depo2"; kimlik "$D2/_agents/bani" "$(printf '# ORTAK-TEMEL manuel (kaynak: _agents/ekip-os-base/manuel-claude-base.md)\nsatır bir\nESKİ satır\n')"
D4="$T/depo4"; kimlik "$D4/_agents/ares" "$(printf '# ORTAK-TEMEL otonom\notonom satırı\n\n## KİŞİ\nARES')"
D5="$T/depo5"; kimlik "$D5/_agents/ares" "$(printf '# ORTAK-TEMEL otonom (kaynak: _agents/ekip-os-base/otonom-ajan-base.md)\nESKİ otonom satırı\n')"
D6="$T/depo6"; kimlik "$D6/_agents/enis" "$(printf '# ORTAK-TEMEL izole\nizole satırı\n\n## KİŞİ\nENİS')"
D7="$T/depo7"; kimlik "$D7/_agents/bennaa" "$(printf '# ORTAK-TEMEL alt\nalt personel satırı\n\n## KİŞİ\nALT')"
D3="$T/depo3"; kimlik "$D3/_agents/bani" "$(printf '# ORTAK-TEMEL manuel\nsatır bir\nsatır iki\n')" bozuk
K1="$T/kurulu-esit/duzen"; mkdir -p "$K1"; printf -- '---\nname: duzen\nversion: 1.2.3\n---\n' > "$K1/SKILL.md"
K2="$T/kurulu-eski/duzen"; mkdir -p "$K2"; printf -- '---\nname: duzen\nversion: 1.0.0\n---\n' > "$K2/SKILL.md"
ONCE="$(find "$T/depo1" "$T/depo2" "$T/depo3" "$T/depo4" "$T/depo5" "$T/depo6" "$T/depo7" "$P" -type f -exec md5sum {} + | sort)"

O="$($S goster)"; ok "S1 goster → 1.2.3" "$([ "$O" = 1.2.3 ] && echo 0 || echo 1)" "→ $O"
O="$($S denetle --depo "$T/bos" --kurulu "$K1")"; rc=$?; ok "S2 kurulu sürüm eşit → GÜNCEL rc 0" "$([ $rc -eq 0 ] && grep -q 'GÜNCEL' <<<"$O" && echo 0 || echo 1)" "→ rc=$rc"
O="$($S denetle --depo "$T/bos" --kurulu "$K2")"; rc=$?; ok "S3 kurulu v1.0.0 ≠ kaynak v1.2.3 → BAYAT rc 1 (kurulum komutu yazılı)" "$([ $rc -eq 1 ] && grep -q 'BAYAT' <<<"$O" && grep -q 'sync-skills.mjs --skill duzen' <<<"$O" && echo 0 || echo 1)" "→ rc=$rc"
O="$($S denetle --depo "$D1" --kurulu /yok)"; rc=$?; ok "S4 çekirdek birebir gömülü + hash tutar → bani GÜNCEL, işaretsiz 1 sayılır, rc 0" "$([ $rc -eq 0 ] && grep -q 'bani: GÜNCEL' <<<"$O" && grep -q 'işaretsiz 1' <<<"$O" && echo 0 || echo 1)" "→ rc=$rc $O"
O="$($S denetle --depo "$D2" --kurulu /yok)"; rc=$?; ok "S5 gömülü metin çekirdekten sapmış → bani BAYAT rc 1 (temel adı yazılı)" "$([ $rc -eq 1 ] && grep -q 'bani: BAYAT' <<<"$O" && grep -q 'manuel-claude-base' <<<"$O" && echo 0 || echo 1)" "→ rc=$rc"
O="$($S denetle --depo "$D3" --kurulu /yok)"; rc=$?; ok "S6 hash gövdeyle tutmuyor → EL-DEĞMİŞ rc 1" "$([ $rc -eq 1 ] && grep -q 'bani: EL-DEĞMİŞ' <<<"$O" && echo 0 || echo 1)" "→ rc=$rc"
O="$($S denetle --depo "$T/bos" --kurulu /yok 2>&1)"; rc=$?; ok "S7 ne kurulu ne işaretli kimlik → rc 3 ÖLÇÜLEMEDİ" "$([ $rc -eq 3 ] && grep -q 'ÖLÇÜLEMEDİ' <<<"$O" && echo 0 || echo 1)" "→ rc=$rc"
$S denetle --depo "$D1" --uygula >/dev/null 2>&1; rc=$?; ok "S8 --uygula yok: rc 2 (1.0.0 yalnız raporlar)" "$([ $rc -eq 2 ] && echo 0 || echo 1)" "→ rc=$rc"
O="$($S denetle --depo "$D4" --kurulu /yok)"; rc=$?; ok "S10 otonom çekirdek birebir gömülü → ares GÜNCEL rc 0 (otonom-ajan-base adı yazılı)" "$([ $rc -eq 0 ] && grep -q 'ares: GÜNCEL (otonom-ajan-base' <<<"$O" && echo 0 || echo 1)" "→ rc=$rc $O"
O="$($S denetle --depo "$D5" --kurulu /yok)"; rc=$?; ok "S11 otonom gömülü metin sapmış → ares BAYAT rc 1 (temel: otonom-ajan-base yazılı)" "$([ $rc -eq 1 ] && grep -q 'ares: BAYAT' <<<"$O" && grep -q 'temel: otonom-ajan-base' <<<"$O" && echo 0 || echo 1)" "→ rc=$rc $O"
O="$($S denetle --depo "$D6" --kurulu /yok)"; rc=$?; ok "S12 izole kutu çekirdeği birebir gömülü → enis GÜNCEL rc 0 (izole-kutu-base adı yazılı)" "$([ $rc -eq 0 ] && grep -q 'enis: GÜNCEL (izole-kutu-base' <<<"$O" && echo 0 || echo 1)" "→ rc=$rc $O"
O="$($S denetle --depo "$D7" --kurulu /yok)"; rc=$?; ok "S13 alt personel çekirdeği birebir gömülü → bennaa GÜNCEL rc 0 (alt-personel-base adı yazılı)" "$([ $rc -eq 0 ] && grep -q 'bennaa: GÜNCEL (alt-personel-base' <<<"$O" && echo 0 || echo 1)" "→ rc=$rc $O"
SONRA="$(find "$T/depo1" "$T/depo2" "$T/depo3" "$T/depo4" "$T/depo5" "$T/depo6" "$T/depo7" "$P" -type f -exec md5sum {} + | sort)"
ok "S9 hiçbir dosyaya yazmadı (md5 kümesi aynı)" "$([ "$ONCE" = "$SONRA" ] && echo 0 || echo 1)"

if [ -z "${SURUM_BETIK:-}" ]; then
  echo "── mutasyon"
  mut() { local M="$HERE/.mutant-surum-$$-$1"; python3 -I - "$R" "$M" "$2" "$3" <<'PY' || { ok "mutant $1: desen tutmadı" 1; return; }
import sys; s=open(sys.argv[1],encoding='utf-8').read(); o=s; s=s.replace(sys.argv[3],sys.argv[4]); assert s!=o; open(sys.argv[2],'w',encoding='utf-8').write(s)
PY
    local o; o="$(SURUM_BETIK="$M" bash "$0" 2>&1)"; ok "mutant '$1' → $4 kırmızı" "$(grep -q "✗ $4 " <<<"$o" && echo 0 || echo 1)" "→ $(grep -E '✗' <<<"$o" | head -2)"; }
  mut bayat-guncel-sayilir 'temeller[a] and temeller[a] in g' 'temeller[a]' S5
  mut hash-bakmaz '.hexdigest()!=stored' '.hexdigest()!=stored and False' S6
  mut otonom-temeli-tanimaz '"otonom-ajan-base","izole-kutu-base","alt-personel-base")' '"izole-kutu-base","alt-personel-base")' S10
  mut izole-temeli-tanimaz '"otonom-ajan-base","izole-kutu-base","alt-personel-base")' '"otonom-ajan-base","alt-personel-base")' S12
  mut alt-temeli-tanimaz '"izole-kutu-base","alt-personel-base")' '"izole-kutu-base")' S13
fi
echo "== $G geçti · $K düştü =="; [ "$K" -eq 0 ]
