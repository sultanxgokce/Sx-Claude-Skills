#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# seans-kur.sh — seans kapılarını PATH'e bağlayan İDEMPOTENT kurucu.
#
# NİÇİN VAR (2026-07-30 ölçümü): beş Türkçe kapı (basla · sessiongetir · yenisession ·
# gruba · yardim) yazılmış, birleştirilmiş ve dağıtılmıştı — AMA hiçbiri PATH'te değildi:
#   for c in basla sessiongetir yenisession gruba yardim; do command -v $c; done  → beşi YOK
# Yani `basla` karşılama ekranı VARDI ve hiçbir kutudan çağrılamıyordu. Bu betik o son
# kabloyu takar. Emsal: infra/kapi/kapi-kur.sh (~/.local/bin/kapi symlink deseni).
#
# SÖZLEŞME:
#   · İdempotent — ikinci koşum hiçbir şeyi bozmaz, "zaten bağlı" der.
#   · symlink-DIŞI bir dosyayı ASLA ezmez (kullanıcının kendi betiği korunur) → uyarır, atlar.
#   · PATH'te hedef dizin yoksa SESSİZ KALMAZ: nasıl ekleneceğini yazar.
#   · --kontrol → hiçbir şey yazmaz, yalnız durum basar (kuru-koşu).
# EXIT: 0 tamam · 1 en az bir kapı bağlanamadı · 2 kullanım/ortam hatası
# ─────────────────────────────────────────────────────────────────────────────
set -u

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HEDEF_DIZIN="${SEANS_BIN_DIR:-$HOME/.local/bin}"
KAPILAR="basla sessiongetir yenisession gruba yardim"
KONTROL=0
[ "${1:-}" = "--kontrol" ] && KONTROL=1

grn(){ printf '\033[32m%s\033[0m\n' "$*"; }
red(){ printf '\033[31m%s\033[0m\n' "$*"; }
ylw(){ printf '\033[33m%s\033[0m\n' "$*"; }

fail=0
[ "$KONTROL" -eq 1 ] || mkdir -p "$HEDEF_DIZIN" 2>/dev/null || { red "hedef dizin oluşturulamadı: $HEDEF_DIZIN"; exit 2; }

for k in $KAPILAR; do
  kaynak="$HERE/$k"
  hedef="$HEDEF_DIZIN/$k"
  if [ ! -f "$kaynak" ]; then
    red "  ✗ $k — kaynak yok: $kaynak"; fail=$((fail+1)); continue
  fi
  [ -x "$kaynak" ] || { [ "$KONTROL" -eq 1 ] || chmod +x "$kaynak" 2>/dev/null; }

  if [ -L "$hedef" ]; then
    mevcut="$(readlink "$hedef")"
    if [ "$mevcut" = "$kaynak" ]; then grn "  = $k — zaten bağlı"; continue; fi
    if [ "$KONTROL" -eq 1 ]; then ylw "  ↻ $k — başka yere bakıyor ($mevcut) → düzeltilecek"; continue; fi
    ln -sfn "$kaynak" "$hedef" && grn "  ↻ $k — hedef düzeltildi" || { red "  ✗ $k — symlink yazılamadı"; fail=$((fail+1)); }
    continue
  fi

  if [ -e "$hedef" ]; then
    # symlink DEĞİL, gerçek dosya/dizin → DOKUNMA (kullanıcının kendi şeyi olabilir)
    ylw "  ⚠ $k — symlink olmayan bir dosya var, DOKUNULMADI: $hedef"
    fail=$((fail+1)); continue
  fi

  if [ "$KONTROL" -eq 1 ]; then ylw "  + $k — bağlanacak"; continue; fi
  ln -s "$kaynak" "$hedef" && grn "  + $k — bağlandı" || { red "  ✗ $k — symlink yazılamadı"; fail=$((fail+1)); }
done

# PATH kapısı: dizin PATH'te değilse sessiz kalmaz (yoksa kapılar yine çağrılamaz).
case ":$PATH:" in
  *":$HEDEF_DIZIN:"*) grn "  ✓ PATH: $HEDEF_DIZIN görünüyor" ;;
  *)
     # KAPILAR BAĞLI AMA ÇAĞRILAMAZ — bu, bugün 11 kutuda fiilen yaşandı (Sultan: "sedir
     # projemde basla yok"). Symlink kurmak yetmiyor; dizin PATH'te olmalı. Emsal:
     # infra/kapi/kapi-kur.sh'in .bashrc marker-bloğu deseni.
     if [ "$KONTROL" -eq 1 ]; then
       ylw "  ⚠ PATH'te YOK: $HEDEF_DIZIN → .bashrc'ye marker-blok EKLENECEK"
     elif [ -n "${SEANS_PATH_BLOK_YOK:-}" ]; then
       ylw "  ⚠ PATH'te YOK: $HEDEF_DIZIN (blok-yazımı SEANS_PATH_BLOK_YOK ile kapatılmış)"
       fail=$((fail+1))
     else
       RC="${SEANS_BASHRC:-$HOME/.bashrc}"
       if [ -f "$RC" ] && grep -q '# >>> seans-path >>>' "$RC" 2>/dev/null; then
         ylw "  ⚠ PATH'te YOK ama .bashrc bloğu ZATEN var → yeni terminal aç (ya da: source $RC)"
       else
         { printf '\n# >>> seans-path >>>\n'
           printf '# seans kapıları (basla · sessiongetir · yenisession · gruba · yardim) buradan çağrılır.\n'
           printf '# seans-kur.sh ekledi; kaldırmak için bu blok silinir.\n'
           printf 'case ":$PATH:" in *":%s:"*) ;; *) export PATH="%s:$PATH" ;; esac\n' "$HEDEF_DIZIN" "$HEDEF_DIZIN"
           printf '# <<< seans-path <<<\n'
         } >> "$RC" 2>/dev/null \
           && grn "  + PATH bloğu eklendi → $RC  (etkin olması için YENİ TERMİNAL aç ya da: source $RC)" \
           || { red "  ✗ PATH bloğu yazılamadı: $RC"; fail=$((fail+1)); }
       fi
     fi
     ;;
esac

if [ "$KONTROL" -eq 1 ]; then
  echo; ylw "kuru-koşu: hiçbir şey yazılmadı. Uygulamak için argümansız çalıştır."
  exit 0
fi

echo
if [ "$fail" -eq 0 ]; then grn "seans kapıları hazır: $KAPILAR"; exit 0; fi
red "seans kurulumu $fail sorunla bitti (yukarıya bak)"; exit 1
