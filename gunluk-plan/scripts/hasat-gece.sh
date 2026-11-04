#!/usr/bin/env bash
# hasat-gece.sh — GECELİK OTOMATİK HASAT (görev …QCJYWG · SERDAR 4 Kas kararı): havuzda kapısı HASAT=OLUR veren kayıtları
#   `hasat.sh ac --kip otomatik` ile göreve çevirir. Cron'dan çağrılır; elle de koşulabilir.
#
#   hasat-gece.sh [--kuru | --gercek] [--tavan N] [--kutu K]
#
# KİP: varsayılan KURU (hiçbir şey açmaz, "açardı" yazar). Gerçek kip yalnız AÇIK --gercek ile; cron satırındaki bayrağı SERDAR çevirir.
# KURALLAR (SERDAR'ın kararı):
#   · yalnız HASAT=OLUR (hasat.sh durum) · günde en çok TAVAN (vars. 3) · hiçbiri OLUR değilse günlüğe olur=0 yazar, başka bir şey yapmaz.
#   · doğrulamayı (hasat.sh dogrula) bu betik YAZMAZ: kapıyı açan ölçümü bir ajan yapar, cron uyduramaz.
#   · SINIFLI kayıt (kapı alanı dolu ya da başlık/özet para · silme · dış yüzey · yetki sözü taşıyor) otomatik AÇILMAZ → günlüğe "atlandi-sinifli".
#   · doğan görev SAHİPSİZ kalmaz: kaydın atananı, yoksa kaydın odasının müdürü (aile-registry oda_muduru). Çözülemezse AÇILMAZ → "atlandi-sahipsiz".
#   · ölçülemeyen kayıt (HASAT=ÖLÇÜLEMEDİ) açılmaz, sayılır. Aynı kayıttan ikinci görev açmayı hasat.sh'ın tekilleştirmesi önler.
#   · "GÜNDE EN ÇOK TAVAN" KOŞULAR ARASI korunur: gerçek kipte her açılış HASAT_GECE_DURUM dosyasına "<gün> <kayıt> <atanan>" yazılır; aynı günün ikinci koşusu
#     (elle ya da cron tekrarı) o günkü açılışları tavandan düşer. Kuru kip dosyayı yalnız OKUR (açardı sayısı gerçek kiple aynı çıksın), hiç yazmaz.
#   · KİP GEÇİŞİ OTOMATİK DEĞİL (SERDAR 4 Kas, QCJYWG: "ilk 3 gece kuru kipte koşar, sonucu mektupla getir, gerçek kipe ben geçireceğim"): betikte gece sayacı
#     yoktur; cron satırındaki --kuru bayrağını --gercek yapmak SERDAR'ın elindedir. Otomatik geçiş o kararla çelişirdi.
# Günlüğün son satırı özet satırıdır: "<ISO> hasat-gece kip=… olur=N acilan=K atlandi_sinifli=S atlandi_sahipsiz=U atlandi_dogmus=D olmaz=M olculemedi=L rc=0"
# Ortam (sınav): GOREV_SH · HASAT_SH · ILE_REGISTRY · HASAT_GECE_ZAMAN · HASAT_GECE_DOGAN_OKU · HASAT_GECE_DURUM · HASAT_GECE_GUN
# rc: 0 koştu (olur=0 dahil) · 2 kullanım · 3 defter okunamadı (ÖLÇÜLEMEDİ: "olur=0" UYDURULMAZ)
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
GOREV="${GOREV_SH:-$(bash "$KOK/gorev-yolu.sh" 2>/dev/null)}"; HASAT="${HASAT_SH:-$KOK/hasat.sh}"
REGISTRY="${ILE_REGISTRY:-/config/projects/Nexus/_agents/handoff/aile-registry.yaml}"
KIP=kuru; TAVAN=3; KUTU=code
DURUM="${HASAT_GECE_DURUM:-/config/.filo/hasat-gece-durum.log}"; BUGUN="${HASAT_GECE_GUN:-$(date +%F)}"
while [ $# -gt 0 ]; do
  case "$1" in
    --kuru) KIP=kuru; shift ;; --gercek) KIP=gercek; shift ;;
    --tavan|--kutu) [ $# -ge 2 ] || { echo "HATA: $1 değer ister" >&2; exit 2; }; if [ "$1" = --tavan ]; then TAVAN="$2"; else KUTU="$2"; fi; shift 2 ;;
    *) echo "kullanım: hasat-gece.sh [--kuru|--gercek] [--tavan N] [--kutu K]" >&2; exit 2 ;;
  esac
done
case "$TAVAN" in ''|*[!0-9]*) echo "HATA: --tavan sayı olmalı: '$TAVAN'" >&2; exit 2 ;; esac
[ "$TAVAN" -ge 1 ] || { echo "HATA: --tavan en az 1" >&2; exit 2; }
ZAMAN="${HASAT_GECE_ZAMAN:-$(date -Is)}"
SINIF_SOZ='para|ödeme|odeme|fatura|ücret|ucret|bütçe|butce|satın al|satin al|abonelik|sil(me|in|ince|er|mek)?([^a-zçğıöşü]|$)|kaldır|yetki|izin ver|erişim izni|erisim izni|dış yüz|dis yuz|herkese aç|herkese ac|canlıya çık|canliya cik'

SATIRLAR="$(bash "$GOREV" liste --kutu "$KUTU" 2>/dev/null)"; GRC=$?
if [ "$GRC" -ne 0 ] || [ -z "$SATIRLAR" ]; then
  echo "$ZAMAN hasat-gece kip=$KIP olur=? acilan=0 olculemedi=defter rc=3"; exit 3
fi
ONCEKI=0; [ ! -r "$DURUM" ] || ONCEKI="$(grep -c "^$BUGUN " "$DURUM" 2>/dev/null)"
case "$ONCEKI" in ''|*[!0-9]*) ONCEKI=0 ;; esac
KALAN=$((TAVAN - ONCEKI)); [ "$KALAN" -ge 0 ] || KALAN=0
if [ "$KIP" = gercek ]; then   # günlük tavan dosyaya dayanır: yazılamıyorsa gerçek kip HİÇBİR ŞEY açmaz (sayaç sessizce işlemez olurdu)
  mkdir -p "$(dirname "$DURUM")" 2>/dev/null; : >> "$DURUM" 2>/dev/null || { echo "$ZAMAN hasat-gece kip=gercek olur=? acilan=0 olculemedi=durum-dosyasi ($DURUM yazılamıyor) rc=3"; exit 3; }
fi
HAVUZ="$(printf '%s\n' "$SATIRLAR" | awk '$1 ~ /^gorev_/ && $3 == "havuz"')"

oda_muduru() {   # oda adı → oda müdürü adı (boş = çözülemedi)
  [ -r "$REGISTRY" ] || return 0
  python3 - "$REGISTRY" "$1" <<'PY'
import re, sys
reg, oda = sys.argv[1], sys.argv[2]
bloklar, cur = [], None
for s in open(reg, encoding="utf-8"):
    m = re.match(r"\s*-\s*id:\s*([^\s#]+)", s)
    if m: cur = {"id": m.group(1), "oda": None, "mudur": False}; bloklar.append(cur); continue
    if cur is None: continue
    m = re.match(r"\s+oda:\s*([^\s#]+)", s)
    if m and cur["oda"] is None: cur["oda"] = m.group(1)
    if re.match(r"\s+oda_muduru:\s*evet", s): cur["mudur"] = True
print(next((b["id"] for b in bloklar if b["oda"] == oda and b["mudur"]), ""))
PY
}

dogan_var() {   # kaydın doğan görevi var mı? → 0 var · 1 yok · 3 okunamadı (hasat.sh ac kayıt başına tekilleştirmez: kayıt havuzda kalır, her gece yeniden OLUR verir)
  local n jy uc
  if [ -n "${HASAT_GECE_DOGAN_OKU:-}" ]; then n="$(bash "$HASAT_GECE_DOGAN_OKU" "$1" 2>/dev/null)" || return 3
  else
    jy="${DEFTER_JETON_YOL:-/config/defter-jeton}"; uc="${DEFTER_UC:-http://cloudtop-defter:8791}"
    [ -r "$jy" ] || return 3
    n="$(curl -sS -m 15 -H "x-defter-jeton: $(tr -d '\n' < "$jy")" "$uc/kayit/$1" 2>/dev/null | python3 -c 'import sys,json; k=json.load(sys.stdin).get("kayit") or {}; print(len(k.get("dogan_gorevler") or []))' 2>/dev/null)" || return 3
  fi
  case "$n" in ''|*[!0-9]*) return 3 ;; esac
  [ "$n" -gt 0 ]
}

OLUR=0; ACILAN=0; SINIFLI=0; SAHIPSIZ=0; DOGMUS=0; OLMAZ=0; OLCULEMEDI=0
while IFS= read -r satir; do
  [ -n "$satir" ] || continue
  id="${satir%%[[:space:]]*}"
  # 1) ölç: kapı OLUR mu?
  cikti="$(bash "$HASAT" durum "$id" 2>/dev/null)"; hrc=$?
  case "$hrc:$cikti" in
    0:*HASAT=OLUR*) OLUR=$((OLUR+1)) ;;
    3:*) OLCULEMEDI=$((OLCULEMEDI+1)); echo "$ZAMAN hasat-gece $id olculemedi"; continue ;;
    *) OLMAZ=$((OLMAZ+1)); continue ;;
  esac
  # 2) sınıflı mı? (kapı alanı dolu ya da sınıf sözü) → açılmaz
  kapi="$(printf '%s' "$satir" | sed -n 's/.*kapi: *\([^ ]*\).*/\1/p')"
  if [ -n "$kapi" ] || printf '%s' "$satir" | grep -qiE "$SINIF_SOZ"; then
    SINIFLI=$((SINIFLI+1)); echo "$ZAMAN hasat-gece $id atlandi-sinifli${kapi:+ (kapi: $kapi)}"; continue
  fi
  # 3) sahibi: kaydın atananı, yoksa odanın müdürü; ikisi de yoksa AÇILMAZ
  atanan="$(printf '%s' "$satir" | awk '{print $6}')"; oda="$(printf '%s' "$satir" | sed -n 's/.*oda: *\([^ ]*\).*/\1/p')"
  case "$atanan" in ''|-) atanan="" ;; esac
  [ -n "$atanan" ] || { [ -z "$oda" ] || atanan="$(oda_muduru "$oda")"; }
  if [ -z "$atanan" ]; then SAHIPSIZ=$((SAHIPSIZ+1)); echo "$ZAMAN hasat-gece $id atlandi-sahipsiz (atanan yok, oda müdürü çözülemedi${oda:+: oda=$oda})"; continue; fi
  # 4) bu kayıt ZATEN doğurdu mu? (kayıt havuzda kalır; tekilleştirme olmazsa her gece aynı görev yeniden açılırdı)
  dogan_var "$id"; drc=$?
  case "$drc" in
    0) DOGMUS=$((DOGMUS+1)); echo "$ZAMAN hasat-gece $id atlandi-dogmus (doğan görevi var)"; continue ;;
    1) ;;
    *) OLCULEMEDI=$((OLCULEMEDI+1)); echo "$ZAMAN hasat-gece $id olculemedi (doğan görev okunamadı; açılmadı)"; continue ;;
  esac
  # 5) tavan: sınıflı/sahipsiz kayıtlar yukarıda zaten günlüğe düştü; tavan yalnız AÇILACAKLARI sınırlar
  [ "$ACILAN" -lt "$KALAN" ] || { echo "$ZAMAN hasat-gece $id tavan-doldu (en çok $TAVAN; bugün önceden açılan $ONCEKI)"; continue; }
  # 6) aç (gerçek) ya da "açardı" (kuru)
  if [ "$KIP" = gercek ]; then
    if bash "$HASAT" ac "$id" "gece hasadı: kapı OLUR, sınıfsız, sahibi $atanan" --kip otomatik --atanan "$atanan" >/dev/null 2>&1; then
      ACILAN=$((ACILAN+1)); echo "$BUGUN $id $atanan" >> "$DURUM" 2>/dev/null || echo "$ZAMAN hasat-gece UYARI durum dosyası yazılamadı ($DURUM): günlük tavan korunamaz"; echo "$ZAMAN hasat-gece $id acildi → $atanan"
    else echo "$ZAMAN hasat-gece $id acma-reddedildi (hasat.sh ac rc≠0)"; fi
  else
    ACILAN=$((ACILAN+1)); echo "$ZAMAN hasat-gece $id KURU: acardi → $atanan"
  fi
done <<< "$HAVUZ"
echo "$ZAMAN hasat-gece kip=$KIP olur=$OLUR acilan=$ACILAN atlandi_sinifli=$SINIFLI atlandi_sahipsiz=$SAHIPSIZ atlandi_dogmus=$DOGMUS olmaz=$OLMAZ olculemedi=$OLCULEMEDI rc=0"
exit 0
