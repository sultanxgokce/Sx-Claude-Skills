#!/usr/bin/env bash
# kasif-kur.sh — layiha/fikir-hattının TEZGÂHINI bu odada kurar (L24 F3, Şart-2 "tek tuş").
#
# NE: Rol (el-kitabı + motor) ortak-mount'ta TEK kopya durur ve senkron iner; TEZGÂH (veri) her odada
#   YERELDİR. Bu betik o tezgâhı üretir: boş defterler + dizinler + nötr kanon. "Tek rol, on tezgâh".
#
# ⛔ ASLA ÜZERİNE YAZMAZ. Var olan her dosya olduğu gibi bırakılır (idempotent) — bu betiği ikinci kez
#   koşmak veri kaybettirmez, `--kontrol` ile önce bakabilirsin.
#
# 🔒 DOĞUŞTA KAPALI (Sultan-kararı K4): yeni kurulan oda üretime KAPALI doğar; yetenek her yerde, izin
#   Sultan'da. Kapatma YALNIZ ilk kurulumda yapılır (kurulum-damgası yoksa) — Sultan sonradan açtıysa
#   betiği tekrar koşmak odayı YENİDEN KAPATMAZ.
#
# Kullanım:
#   kasif-kur.sh [--kontrol]     # --kontrol = dry-run: neyin VAR/EKSİK olduğunu basar, hiçbir şey yazmaz
#
# Çıkış: 0 OK · 2 ortam hatası (git-siz dizin → tezgâh kurulamaz; İ1 gereği ortak dizine kurulmaz)
set -euo pipefail

PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HAT_LIB="${HAT_YOLU_LIB:-$PAKET/../layiha/scripts/hat-yolu.lib.sh}"
[ -r "$HAT_LIB" ] || { echo "HATA: hat-yolu.lib.sh yok: $HAT_LIB — 'layiha' paketi kurulu mu?" >&2; exit 2; }
# shellcheck source=/dev/null
source "$HAT_LIB"

KONTROL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --kontrol|-n) KONTROL=1 ;;
    -h|--help) sed -n '2,18p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "HATA: bilinmeyen bayrak: $1 (yalnız --kontrol)" >&2; exit 2 ;;
  esac; shift
done

KOK="$(hat_root)" || exit 2
ONEK="$(hat_onek)" || exit 2
DAMGA="$ONEK/_agents/kasif/.kurulum"

echo "Tezgâh kökü : $KOK"
echo "Hücre-öneki : $ONEK"
if [ "$KONTROL" = "1" ]; then echo "MOD         : --kontrol (hiçbir şey yazılmayacak)"; fi
echo

YAPILACAK=0

_dizin() { # $1=yol $2=etiket
  if [ -d "$1" ]; then echo "  ✓ VAR    $2"
  else
    echo "  + KURUL  $2"; YAPILACAK=$((YAPILACAK+1))
    [ "$KONTROL" = "1" ] || mkdir -p -- "$1"
  fi
}
_bos_dosya() { # $1=yol $2=etiket
  if [ -e "$1" ]; then echo "  ✓ VAR    $2"
  else
    echo "  + KURUL  $2 (boş)"; YAPILACAK=$((YAPILACAK+1))
    if [ "$KONTROL" != "1" ]; then mkdir -p -- "$(dirname -- "$1")"; : > "$1"; fi
  fi
}

echo "── dizinler ──"
_dizin "$(hat_yolu handoff-dir)"          "_agents/handoff"
_dizin "$(hat_yolu kasif-dir)"            "_agents/kasif"
_dizin "$(hat_yolu kasif-knowledge-dir)"  "_agents/kasif/knowledge"
_dizin "$(hat_yolu mucit-dir)"            "_agents/mucit"

echo
echo "── defterler (boş doğar) ──"
_bos_dosya "$(hat_yolu bulgu-havuzu)"         "bulgu-havuzu.jsonl (KAŞİF'in yazdığı ham-malzeme)"
_bos_dosya "$(hat_yolu mucit-defteri)"        "mucit-defteri.jsonl (DİVAN fikir-hattı)"
_bos_dosya "$(hat_yolu mucit-defteri-layiha)" "mucit-defteri-layiha.jsonl (layiha bandı — ayrı kota)"
_bos_dosya "$(hat_yolu aday-havuzu)"          "layiha-aday-havuzu.jsonl (taslak adaylar)"
_bos_dosya "$(hat_yolu layiha-defteri)"       "layiha-defteri.jsonl (terfi etmiş gerçek layihalar)"

echo
echo "── kanon (nötr; oda kendi değerlerini yazar) ──"
KANON="$(hat_yolu mucit-dir)/kanon.json"
if [ -e "$KANON" ]; then
  echo "  ✓ VAR    _agents/mucit/kanon.json"
else
  echo "  + KURUL  _agents/mucit/kanon.json (kart_kaynagi.base BOŞ → ağ çağrısı YOK)"
  YAPILACAK=$((YAPILACAK+1))
  if [ "$KONTROL" != "1" ]; then
    mkdir -p -- "$(dirname -- "$KANON")"
    cat > "$KANON" <<'JSON'
{
  "v": 1,
  "_not": "MUCİT eleğinin odaya-özgü ayarları. base BOŞ bırakılırsa hiçbir ağ çağrısı yapılmaz (varsayılan).",
  "kart_kaynagi": { "base": "", "env_dosyasi": "", "token_anahtari": "" },
  "profiller": {
    "divan":  { "tavan": 3,  "periyot": "hafta" },
    "layiha": { "tavan": 10, "periyot": "gun" }
  }
}
JSON
  fi
fi

echo
echo "── üretim anahtarı (K4: doğuşta KAPALI) ──"
FABRIKA="$PAKET/../layiha-fabrikasi/scripts/layiha-fabrika.sh"
if [ -e "$DAMGA" ]; then
  echo "  ✓ ATLA   bu oda daha önce kurulmuş (kurulum-damgası var) — anahtara DOKUNULMAZ"
elif [ ! -x "$FABRIKA" ] && [ ! -r "$FABRIKA" ]; then
  echo "  ⚠ ATLA   layiha-fabrikasi paketi yok ($FABRIKA) — anahtar ayarlanamadı"
else
  echo "  + KAPAT  bu oda üretime kapalı doğacak (Sultan açana dek)"
  YAPILACAK=$((YAPILACAK+1))
  if [ "$KONTROL" != "1" ]; then
    bash "$FABRIKA" kapat --yerel --sebep "yeni kurulum — Sultan açana dek kapalı (K4)" >/dev/null
    printf 'kurulum: %s\n' "$(date -u +%FT%TZ)" > "$DAMGA"
  fi
fi

echo
if [ "$KONTROL" = "1" ]; then
  echo "── ÖZET: $YAPILACAK adım eksik (hiçbir şey yazılmadı). Kurmak için: kasif-kur.sh"
else
  echo "── ÖZET: tezgâh hazır. $YAPILACAK adım uygulandı, gerisi zaten vardı."
  echo "   Bu oda ÜRETİME KAPALI. Açmak için:  bash <layiha-fabrikasi>/scripts/layiha-fabrika.sh ac"
fi
exit 0
