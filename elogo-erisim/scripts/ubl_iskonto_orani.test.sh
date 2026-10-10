#!/usr/bin/env bash
# Satır iskonto ORANI kısaltılmadan yazılıyor mu?
#
# Niçin (MUHASİP ölçümü, 2026-09-30 · gerçek kesim hazırlığı): oran `:.2f` ile iki haneye
# kırpılıyordu. Tedarikçi faturasında oran 70,122; "70.12" yazılınca okuyan
# 47.304,00 × %70,12 = 33.169,56 hesaplıyor, bizim tutarımız 33.170,51 → 95 kuruş GÖRÜNÜR
# tutarsızlık. Kuruş kapısı bunu GÖRMÜYORDU: tutarı sınıyor, oran METNİNİ sınamıyordu.
# 🔴 Sahte yeşil sınıfı — ölçüt adının söylediğini değil, onunla korele başka şeyi ölçüyordu.
set -u
K="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gecen=0; kalan=0
kapi(){ if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
o(){ python3 -c "
import sys; sys.path.insert(0,'$K')
from decimal import Decimal
import ubl_ortak as U
v=None if '$1'=='YOK' else Decimal('$1')
print(U._oran_metni(v))" 2>/dev/null; }

echo "── MUHASİP'in gerçek vakası"
kapi "O1 70,122 kısaltılmadan yazılır" "70.122" "$(o 70.122)"
kapi "O2 kesirli biçim (0,701220) korunur" "0.70122" "$(o 0.701220)"

echo "── ölçülen fatura deseni bozulmaz"
kapi "O3 tam sayı oran iki haneli yazılır" "30.00" "$(o 30)"
kapi "O4 zaten iki haneli oran aynı kalır" "30.00" "$(o 30.00)"
kapi "O5 tek haneli ondalık tamamlanır" "12.50" "$(o 12.5)"
kapi "O6 oran yoksa 0" "0" "$(o YOK)"

echo "── biçim tuzakları"
kapi "O7 bilimsel gösterim ÜRETİLMEZ" "h" "$(case "$(o 0.000001)" in *E*|*e*) echo e;; *) echo h;; esac)"

echo "── ÇAĞIRAN gerçekten kullanıyor mu (vekil-ölçüt panzehiri)"
kapi "O8 gövdede kırpan biçim KALMADI" "0" "$(grep -c 'iskonto_orani:\.2f' "$K/ubl_ortak.py")"
kapi "O9 oran yazımı yardımcıdan geçiyor" "1" "$(grep -c 'MultiplierFactorNumeric", _oran_metni' "$K/ubl_ortak.py")"

echo
echo "SONUÇ: $gecen geçti · $kalan kaldı"
[ "$kalan" -eq 0 ]
