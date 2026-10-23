#!/usr/bin/env bash
# olc-havuz.sh — kart 11f0z0-serdar ölçüm çifti (aynı betik önce/sonra; yalnız retro.py değişir):
#   merkez → hermetik depoda sahte `bulgu.sh havuz-cek` (2 ham + 1 acik kayıt) ile `merkez --yenile` koşar,
#            MERKEZ.md'deki havuz satırı sayısını basar (`- gorev_<26> · …`). Beklenen: önce 0 · sonra 2.
#   suzum  → damgasız BİR havuz satırı taşıyan sabit MERKEZ.md'de `suzum` koşar, rc'sini `suzum_rc=N` diye basar.
#            Beklenen: önce 0 (eski araç bölümü görmez) · sonra 1 (damgasız havuz satırı kırmızı).
# Betik kendi başına hep rc 0 ile biter: ölçülen DEĞER stdout'tadır, betiğin başarısı değil.
set -uo pipefail
R="${RETRO_PY:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/retro/scripts/retro.py}"
T="$(mktemp -d)"; trap 'rm -r -f -- "$T"' EXIT
KOK="$T/depo"; mkdir -p "$KOK/_agents/x" "$KOK/kopru" "$KOK/_agents/handoff/retro/2026-W43"
printf '# X\n' > "$KOK/_agents/x/NOTES.md"
cat > "$KOK/kopru/defter.jsonl" <<'J'
{"id":"gorev_01M5M55BRC0V3G8A200PYTVZV9","tarih":"2026-10-23","baslik":"mihenk: PR'da testleri koşan küçük bir iş akışı gerek","durum":"ham","kaynak":"defter"}
{"id":"gorev_01M5M7Y1F90HTSRADKETDCX24C","tarih":"2026-10-23","baslik":"Denetçi düzeltme turu eski DENETIM kaydında tam fark gönderiyor","durum":"ham","kaynak":"defter"}
{"id":"gorev_01M5M0000000000000000ACIK0","tarih":"2026-10-22","baslik":"Sırada olan kayıt (havuzda değil)","durum":"acik","kaynak":"defter"}
J
printf '#!/usr/bin/env bash\n[ "$1" = havuz-cek ] || exit 2\ncat "%s"\n' "$KOK/kopru/defter.jsonl" > "$KOK/kopru/bulgu.sh"
export RETRO_BUGUN=2026-10-23 RETRO_KOK="$KOK" RETRO_DEPO_KOKU="$T/yok" RETRO_BULGU_SH="$KOK/kopru/bulgu.sh"
M="$KOK/_agents/handoff/retro/2026-W43/MERKEZ.md"
case "${1:-merkez}" in
  merkez)
    python3 "$R" merkez --ajanlar X --yenile >"$T/merkez.out" 2>&1; mrc=$?
    n=0; [ -f "$M" ] && n="$(grep -cE '^- gorev_[0-9A-Z]{26} · ' "$M")"
    echo "merkez_rc=$mrc havuz_satiri=$n"; exit 0 ;;
  suzum)
    cat > "$M" <<'MD'
# 🔁 MERKEZ RETROSU · 2026-W43
_yazildi: 2026-10-23T12:00:00+03:00
_arac: retro.py sabit-fikstür

## Katılım (araç yazdı)
| Ajan | Durum | Not |
|---|---|---|
| X | ÇALIŞMADI | bu hafta iz yok (NOTES/kart) — retro zorunlu değil |

## Süzüm — her öneri bir damga alır: `→ gorev_<id>` (görev defterine girdi) ya da `→ RED: <gerekçe ≥10 karakter>`
_(geçerli kutu retrosunda öneri yok)_

## Havuz süzümü — görev defterindeki 'havuz' kayıtları (`bulgu.sh havuz-cek` · durum=ham) · damga: `→ gorev_<kendi id>` (Sırada'ya alınır) ya da `→ RED: <gerekçe ≥10 karakter>`
- gorev_01M5M55BRC0V3G8A200PYTVZV9 · mihenk: PR'da testleri koşan küçük bir iş akışı gerek →
MD
    python3 "$R" suzum >"$T/suzum.out" 2>&1; src=$?
    echo "suzum_rc=$src"; exit 0 ;;
  *) echo "kullanım: olc-havuz.sh merkez|suzum" >&2; exit 2 ;;
esac
