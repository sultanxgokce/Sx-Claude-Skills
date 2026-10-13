#!/usr/bin/env bash
# Mutasyon kapısı: korumayı bozan her değişiklik kayit-koru.test.sh'ı KIRMIZIYA döndürmeli.
# Desen bulunamazsa mutasyon "uygulanmadı" sayılır ve kapı DÜŞER (sessiz yeşil yok).
# Kullanım: mutasyon.sh <depo-kökü>
set -u
KOK="${1:?depo kökü}"
gecen=0; kalan=0
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete; rmdir "$T"' EXIT
kos() { # kos <ad> <python-replace: eski> <yeni> [kaçıncı-eşleşme(0=hepsi,1=ilk,2=ikinci)]
  local ad="$1" eski="$2" yeni="$3" kac="${4:-0}" d="$T/$1"
  mkdir -p "$d"; cp -r "$KOK/iskan" "$d/"
  if ! ESKI="$eski" YENI="$yeni" KAC="$kac" python3 - "$d/iskan/scripts/iskan.sh" <<'PY'
import os, sys
p=sys.argv[1]; s=open(p).read(); e=os.environ["ESKI"]; y=os.environ["YENI"]; k=int(os.environ["KAC"])
n=s.count(e)
if n==0: sys.exit(3)
if k==0: s=s.replace(e,y)
else:
    if n<k: sys.exit(3)
    i=-1
    for _ in range(k): i=s.index(e,i+1)
    s=s[:i]+y+s[i+len(e):]
open(p,"w").write(s)
PY
  then echo "  ✗ $ad: DESEN BULUNAMADI — mutasyon uygulanmadı"; kalan=$((kalan+1)); return; fi
  if bash "$d/iskan/scripts/kayit-koru.test.sh" >"$d/cikti.txt" 2>&1; then
    echo "  ✗ $ad: sınav YEŞİL kaldı — bu bozulmayı yakalamıyor"; kalan=$((kalan+1))
  else
    echo "  ✓ $ad: kırmızı ($(grep -c '✗' "$d/cikti.txt") kapı düştü)"; gecen=$((gecen+1))
  fi
}
# pozitif kontrol: dokunulmamış kopya YEŞİL olmalı
mkdir -p "$T/temiz"; cp -r "$KOK/iskan" "$T/temiz/"
if bash "$T/temiz/iskan/scripts/kayit-koru.test.sh" >/dev/null 2>&1; then echo "  ✓ P0 pozitif kontrol: mutasyonsuz kopya yeşil"; gecen=$((gecen+1)); else echo "  ✗ P0 mutasyonsuz kopya kırmızı"; kalan=$((kalan+1)); fi

kos M1-ey-kapisi-yok   '_ey_kayit_koru "$reg_yeni" apply || exit $?' ':' 1
kos M2-ue-kapisi-yok   '_ey_kayit_koru "$reg_yeni" apply || exit $?' ':' 2
kos M3-hep-ekleme-say  "grep -q '^-'; then" "grep -q '^NEVER'; then"
kos M4-varsayilan-kabul '"${ISKAN_EY_KAYIT_FARK:-dur}" = "kabul"' '"${ISKAN_EY_KAYIT_FARK:-kabul}" = "kabul"'
kos M5-dry-run-durur   'if [ "$mod" = "dry-run" ]; then' 'if [ "$mod" = "HIC" ]; then'
kos M6-olculemedi-yesil '[ "$olculemedi" -gt 0 ] && exit 2' ':'
kos M7-fark-yonu-ters  '<(printf '"'"'%s\n'"'"' "$kanon") <(printf '"'"'%s\n'"'"' "$kutu")' '<(printf '"'"'%s\n'"'"' "$kutu") <(printf '"'"'%s\n'"'"' "$kanon")'
kos M8-kanonsuz-ayni   'echo "  ✗ $p: kanon-yok' 'ayni=$((ayni+1)); echo "  ✓ $p: kanon-yok'
kos M10-fetch-geri-geldi '  local kanon_sha kanon_zaman' '  git -C "$EY_REPO_DIR" fetch -q origin main 2>/dev/null; local kanon_sha kanon_zaman'
# desen-eksik kapısı: var olmayan desen kapıyı DÜŞÜRMELİ (bu satırın kendisi kırmızı beklenir → tersine sayılır)
kos_beklenen_red=$kalan; kos M9-desen-eksik 'BU_DESEN_YOK_123' 'x' >/dev/null
if [ "$kalan" -eq $((kos_beklenen_red+1)) ]; then echo "  ✓ M9 desen-eksik kapısı: uygulanmayan mutasyon DÜŞTÜ (sessiz yeşil yok)"; kalan=$((kalan-1)); gecen=$((gecen+1)); else echo "  ✗ M9 desen-eksik kapısı çalışmıyor"; kalan=$((kalan+1)); fi
echo "== mutasyon: $gecen geçti / $kalan kaldı =="
[ "$kalan" -eq 0 ]
