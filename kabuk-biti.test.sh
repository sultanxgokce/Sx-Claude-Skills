#!/usr/bin/env bash
# kabuk-biti.test.sh — beceri betiklerinin ÇALIŞTIRMA BİTİ depoda var mı? (kalıcı kapı)
#
# NİÇİN (15 Eki 2026, BÂNİ): terminal-onar 2.9.0 kurulurken sync-skills duman testi "compact.sh: ÇALIŞTIRILAMAZ (izin yok)"
# ile kırmızı düştü — dosya depoya 100644 girmişti. Kurulu kopyada elle chmod +x düzeltir ama bir sonraki kurulum aynı biti
# yeniden düşürür. Ölçüldü: depoda 46 beceri betiği bitsizdi (39'u scripts/ altında — bu kartın kapsamı; 7'si arac/ altında); duman testi yalnız
# kurulan beceriyi görür, ötekiler sessizce bekliyordu. Bu kapı depo genelini her CI koşusunda ölçer
# (.github/workflows/lint.yml "Kabuk sınamaları": her *.test.sh keşfedilir ve koşturulur — çağıranı CI'dır).
#
# Kapsam: üst düzey beceri dizinlerinin scripts/ · arac/ · kapi/ altındaki *.sh (#325 yalnız scripts/ idi; arac/ altındaki 7 dosya
# arac-calistirma-biti kartıyla eklendi). `_agents/` kanıt dizinleri kapsam dışı (kayıt, koşturulmaz). Pozitif kontrol: en az bir
# 100755 betik GÖRÜLMELİ (araç kör değil).
set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || dirname "$0")" || exit 3
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
DESEN='^[^_][^/]*/(scripts|arac|kapi)/[^/]*\.sh$'
LISTE="$(git ls-files -s | awk -v d="$DESEN" '$4 ~ d {print $1, $4}')"
[ -n "$LISTE" ]; g $? "beceri betikleri bulundu (araç görüyor): $(printf '%s\n' "$LISTE" | wc -l) dosya"
OLAN=$(printf '%s\n' "$LISTE" | awk '$1=="100755"' | wc -l); [ "$OLAN" -ge 1 ]; g $? "pozitif kontrol: en az bir 100755 betik var ($OLAN)"
BITSIZ="$(printf '%s\n' "$LISTE" | awk '$1!="100755" {print $2}')"
[ -z "$BITSIZ" ]; g $? "🔴 çalıştırma biti olmayan beceri betiği YOK (sync-skills duman testi bu yüzden düşüyordu)"
[ -n "$BITSIZ" ] && { echo "     bitsiz:"; printf '%s\n' "$BITSIZ" | sed 's/^/       /'; echo "     düzeltme: git update-index --chmod=+x <dosya>"; }
echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
