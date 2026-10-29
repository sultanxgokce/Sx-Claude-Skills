#!/usr/bin/env bash
# alt-ajan-istem.test.sh — hermetik sınav (geçici depo: sahte AGENT.md + NOTES + aile-registry + kart; sahte el-defteri.sh).
# A1 kimlik yok → rc 3 + "kimlik yok: önce /ise-alim", stdout boş · A2 `## ELLE` verbatim alınır, ekipc üretilmiş bölge alınmaz
# A3 oda+amir aile-registry'den doğru (kanallar _agents/<slug>/ eşlemesi; yorum/alıntı temizlenir) · A4 defter yok (sahte el-defteri rc 3)
# → rc 0, "defter boş, ilk görev" + ⚠ uyarı · A4b başka rc → "ölçülemedi", "defter boş" demez · A5 sır süzme: parola/token/sifre satırı
# basılmaz, "[sır satırı süzüldü]" yazılır · A6 kart cümlesi kart JSON'dan (cumle alanı) · A6b kart yoksa ⚠ + --is ile devam
# A7 ne --is ne --kart → rc 2 · A10 değersiz seçenek rc 2 (döngü yok) · A11 --kart ../ reddi · A8 --sure/--dosyalar basılır, sabit "reiste kalır" satırı var · A9 el-defteri rc 0 çıktısı istemde
# Mutant (gömülü + `--mutant sir`): sır süzgeci kapatılmış GEÇİCİ kopyada A5 kırmızı. `--mutant sir` bütün süiti mutanta karşı koşar
# ve onun rc'sini döner (beklenen KIRMIZI) — kanit.sh olcum --mutasyon <gerçek etiket> bununla kaydedilir.
set -uo pipefail
export LC_ALL=C.UTF-8
HERE="$(cd "$(dirname "$0")" && pwd)"; R="${AJAN_BETIK:-$HERE/alt-ajan-istem.sh}"

MUT_SIR_ESKI="sir_suz() { awk -v d=\"\$SIR_DESEN\" 'BEGIN{IGNORECASE=1} tolower(\$0) ~ d {print \"[sır satırı süzüldü]\"; next} {print}'; }"
MUT_SIR_YENI="sir_suz() { cat; }"
mutant_yaz() {   # $1 hedef kopya · $2 eski · $3 yeni — desen tam bir kez tutmalı
  python3 -I -c '
import sys; s=open(sys.argv[1],encoding="utf-8").read()
assert s.count(sys.argv[3])==1, "mutant deseni tam bir kez tutmalı (bulunan: %d)" % s.count(sys.argv[3])
open(sys.argv[2],"w",encoding="utf-8").write(s.replace(sys.argv[3],sys.argv[4]))' "$R" "$1" "$2" "$3"
}
if [ "${1:-}" = "--mutant" ]; then
  [ "${2:-}" = sir ] || { echo "bilinmeyen mutant: '${2:-}' (olan: sir)" >&2; exit 2; }
  M="$HERE/.mutant-ajan-$$-sir"; trap 'rm -f "$M"' EXIT
  mutant_yaz "$M" "$MUT_SIR_ESKI" "$MUT_SIR_YENI" || exit 2
  echo "=== MUTASYON: sır süzgeci kapatıldı (geçici kopya) — A5 KIRMIZI BEKLENİR ==="
  AJAN_BETIK="$M" bash "$0"; exit $?
fi

T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null; find "$HERE" -maxdepth 1 -name ".mutant-ajan-$$-*" -delete 2>/dev/null' EXIT
G=0; K=0
ok() { if [ "$2" -eq 0 ]; then G=$((G+1)); echo "  ✓ $1"; else K=$((K+1)); echo "  ✗ $1 ${3:-}"; fi; }

SIMDI=1793264400   # 2026-10-29
D="$T/depo"; mkdir -p "$D/_agents/sakird" "$D/_agents/handoff" "$D/_agents/fabrika/kartlar" "$T/bin"
cat > "$D/_agents/sakird/AGENT.md" <<'EOF'
<!-- ekipc:uretilen:basla surum=1 hash=abc -->
# ORTAK-TEMEL: manuel-claude
URETILMIS-BOLGE-ISARETI bu satır isteme GİRMEMELİ
<!-- ekipc:uretilen:bitti -->

## ELLE (ekipc dokunmaz)

# ŞAKİRD — sınavcı (persona-özü)
ELLE-ISARETI bu satır isteme girmeli.
- deneme parola: hunter2-gizli
- workflow-TOKEN yolu: /yok/yer
- sade satır kalır
EOF
cat > "$D/_agents/handoff/aile-registry.yaml" <<'EOF'
# yorum
uyeler:
  - id: BÂNİ
    oda: agentic-os
    amir: SERDAR
    kanallar: [ _agents/bani/NOTES.md ]
  - id: ŞAKİRD
    oda: agentic-os   # Kuzey Yıldızı 3.5
    mod: salt-okur
    amir: "BÂNİ"
    rol: "sınavcı — koltuksuz"
    kanallar: [ _agents/sakird/AGENT.md, _agents/sakird/NOTES.md ]
EOF
printf '{"is":"deneme-is","cumle":"KART-CUMLESI: sınavı yaz ve koştur","durum":"acik"}\n' > "$D/_agents/fabrika/kartlar/deneme-is.json"
cat > "$T/bin/el-defteri.sh" <<'EOF'
#!/bin/sh
case "${SAHTE_DEFTER:-var}" in
  yok) echo "el defteri yok: sahte/NOTES.md (uydurulmadı)" >&2; exit 3 ;;
  cok) echo "patladı" >&2; exit 7 ;;
  *) echo "# EL DEFTERİ · $2"; echo "- SAHTE-DEFTER-SATIRI"; echo "- eski sifre notu: 12345"; exit 0 ;;
esac
EOF
chmod +x "$T/bin/el-defteri.sh"
kos() { DUZEN_SIMDI=$SIMDI DUZEN_EL_DEFTERI_SH="$T/bin/el-defteri.sh" bash "$R" --depo "$D" "$@"; }

kos yokbiri --is "x" >"$T/o1" 2>"$T/e1"; rc=$?
ok "A1 kimlik yok → rc 3 + 'kimlik yok' + '/ise-alim', stdout boş" "$([ $rc -eq 3 ] && grep -q 'kimlik yok' "$T/e1" && grep -q '/ise-alim' "$T/e1" && [ ! -s "$T/o1" ] && echo 0 || echo 1)" "→ rc=$rc $(head -c120 "$T/e1")"

O="$(kos sakird --is "REIS-CUMLESI deneme" --kart deneme-is --dosyalar "a.sh,b.sh" --sure 45 2>"$T/e2")"; rc=$?
ok "A2 ELLE verbatim alınır, üretilmiş bölge alınmaz (rc 0)" "$([ $rc -eq 0 ] && grep -q 'ELLE-ISARETI' <<<"$O" && ! grep -q 'URETILMIS-BOLGE-ISARETI' <<<"$O" && ! grep -q 'ORTAK-TEMEL: manuel' <<<"$O" && echo 0 || echo 1)" "→ rc=$rc $(head -c160 "$T/e2")"
ok "A3 oda+amir registry'den (yorum ve tırnak temizlenmiş), ad ŞAKİRD" "$(grep -q 'Reis (amir): \*\*BÂNİ\*\* · Oda: \*\*agentic-os\*\*' <<<"$O" && grep -q 'sen ŞAKİRD' <<<"$O" && echo 0 || echo 1)" "→ $(grep -m1 'Reis (amir)' <<<"$O")"
ok "A5 sır süzme: parola/token/sifre satırı basılmaz, '[sır satırı süzüldü]' ≥3, sade satır kalır" "$(! grep -q 'hunter2' <<<"$O" && ! grep -qi 'workflow-token' <<<"$O" && ! grep -q '12345' <<<"$O" && [ "$(grep -c '\[sır satırı süzüldü\]' <<<"$O")" -ge 3 ] && grep -q 'sade satır kalır' <<<"$O" && echo 0 || echo 1)" "→ süzülen: $(grep -c 'sır satırı süzüldü' <<<"$O")"
ok "A6 kart cümlesi JSON'dan okunur + reisin --is cümlesi de var" "$(grep -q 'Kart (deneme-is): KART-CUMLESI: sınavı yaz' <<<"$O" && grep -q 'Reisin cümlesi: REIS-CUMLESI' <<<"$O" && echo 0 || echo 1)"
ok "A8 --dosyalar/--sure basılır; 'reiste kalır' sabit satırı var" "$(grep -q 'a.sh,b.sh (yalnız bunlar' <<<"$O" && grep -q 'Süre tavanı: 45 dk' <<<"$O" && grep -q 'sır DEĞERİ reiste kalır' <<<"$O" && echo 0 || echo 1)"
ok "A9 el-defteri çıktısı istemde (SAHTE-DEFTER-SATIRI), ⚠ uyarı yok" "$(grep -q 'SAHTE-DEFTER-SATIRI' <<<"$O" && ! grep -q '^⚠' <<<"$O" && echo 0 || echo 1)" "→ $(grep '^⚠' <<<"$O" | head -2)"

O4="$(SAHTE_DEFTER=yok kos sakird --is "ilk iş" 2>"$T/e4")"; rc=$?
ok "A4 defter yok (rc 3) → istem yine üretilir rc 0, 'defter boş, ilk görev' + ⚠ uyarı satırı" "$([ $rc -eq 0 ] && grep -q 'defter boş, ilk görev' <<<"$O4" && grep -q '^⚠ el defteri yok' <<<"$O4" && echo 0 || echo 1)" "→ rc=$rc"
O4b="$(SAHTE_DEFTER=cok kos sakird --is "ilk iş" 2>/dev/null)"; rc=$?
ok "A4b el-defteri başka rc (7) → 'ölçülemedi' der, 'defter boş' DEMEZ, rc 0" "$([ $rc -eq 0 ] && grep -q 'ölçülemedi: el-defteri.sh rc 7' <<<"$O4b" && ! grep -q 'defter boş' <<<"$O4b" && echo 0 || echo 1)" "→ rc=$rc"

kos sakird >"$T/o7" 2>"$T/e7"; rc=$?
ok "A7 ne --is ne --kart → rc 2, stdout boş" "$([ $rc -eq 2 ] && [ ! -s "$T/o7" ] && grep -q 'iş yok' "$T/e7" && echo 0 || echo 1)" "→ rc=$rc"
O6="$(kos sakird --is "x" --kart yok-kart 2>/dev/null)"; rc=$?
ok "A6b kart bulunamazsa ⚠ uyarı + --is ile devam, rc 0" "$([ $rc -eq 0 ] && grep -q '^⚠ kart bulunamadı' <<<"$O6" && grep -q 'Reisin cümlesi: x' <<<"$O6" && echo 0 || echo 1)" "→ rc=$rc"

timeout 5 bash "$R" sakird --is >"$T/o10" 2>"$T/e10"; rc=$?
ok "A10 değersiz seçenek (--is sonda) → rc 2 + 'bir değer ister', döngüye girmez (göz tur 1)" "$([ $rc -eq 2 ] && grep -q 'bir değer ister' "$T/e10" && [ ! -s "$T/o10" ] && echo 0 || echo 1)" "→ rc=$rc (124 = zaman aşımı/döngü)"
printf '{"cumle":"DIZIN-DISI-KART"}\n' > "$T/disari.json"
kos sakird --is "x" --kart "../../../../$(basename "$T")/disari" >"$T/o11" 2>"$T/e11"; rc=$?
ok "A11 --kart ../ yolu reddedilir → rc 2, dizin dışı JSON isteme girmez (göz tur 1)" "$([ $rc -eq 2 ] && ! grep -q 'DIZIN-DISI-KART' "$T/o11" && grep -q 'kart iş adı' "$T/e11" && echo 0 || echo 1)" "→ rc=$rc"

if [ -z "${AJAN_BETIK:-}" ]; then
  echo "── mutasyon (gömülü): süzgeç kapatılınca A5 düşmeli"
  M="$HERE/.mutant-ajan-$$-sir"
  if mutant_yaz "$M" "$MUT_SIR_ESKI" "$MUT_SIR_YENI"; then
    o="$(AJAN_BETIK="$M" bash "$0" 2>&1)"; ok "mutant 'sir' → A5 kırmızı (MUTASYON: sır süzgeci kapatıldı)" "$(grep -q '✗ A5 ' <<<"$o" && echo 0 || echo 1)" "→ $(grep -E '✗' <<<"$o" | head -2)"
  else ok "mutant 'sir': desen tutmadı (betik değişti, mutant yeniden yazılmalı)" 1; fi
fi
echo "== $G geçti · $K düştü =="; [ "$K" -eq 0 ]
