#!/usr/bin/env bash
# sicil.sh — Mühürdarlık · sicil (isabet bölümü) · ders çıkarma · askı (G11 · S9 · S10). Mantık lib/sicil.py'de.
#   sicil.sh isabet <mühürdar> --gorev G --gereklilik Gi --muhur ✓|✗ --sultan katiliyorum|saglanmadi --kaynak <Sultan kaydı>
#                   [--neden "<Sultan'ın tek cümlesi>"] [--g-tur <tur>] [--bassiz] [--el-kitabi-surum v]
#   sicil.sh durum <mühürdar> [--json]          son 10 mühür: temiz · ders-cikarma (1 kaçırma) · askida (2 kaçırma)
#   sicil.sh ders <mühürdar> [--json]           tekrar eden kaçırma türü → el kitabı ders günlüğüne kural taslağı
#   sicil.sh ders-bagla <mühürdar> --isabet-ts <ts> --ders D-NNN
#   sicil.sh muhur <mühürdar> --gorev G --verdikt V        (muhurdar.sh her mühürde kendisi çağırır; pencere bundan sayılır)
#   sicil.sh teslim-isle <mühürdar> --kaynak <ref> --muhur-dir <deneme-dir>   (geçit: Sultan'ın tek teslim kararı → bütün satırlar)
# A06: --kaynak Sultan'ın kaydıdır; SICIL_KAYNAK_DOGRULA <kaynak> (geçit sağlar) kaydı JSON basar, hüküm yalnız ondan alınır.
#   Doğrulayıcı yoksa rc 3 (yazılmaz); kayıt yoksa ya da satırı doğrulamıyorsa rc 2.
# RC: 0 tamam · 2 kullanım/biçim/kaynak · 3 ölçülemedi (özlük dosyası yok — yazılmaz; özlük KÂHYA'nın işi)
# Ortam: SICIL_DIZIN (varsayılan Nexus _agents/federe/sicil) · TARIF_KAYDI (eşik) · EL_KITABI (ders günlüğü)
set -uo pipefail
[ $# -gt 0 ] || { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/sicil.py" "$@"
