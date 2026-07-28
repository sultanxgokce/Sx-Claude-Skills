#!/usr/bin/env bash
# hat-durtme.sh — otonom fikir-hattının KAPI BEKÇİSİ (ADR-025 icra-5, EK-A §A2/§A3).
#
# NE: cron 30 dakikada bir bunu "dürter". Bu betik LLM ÇAĞIRMAZ, maliyeti ~0. Tek işi karar vermek:
#     "bugün bu adımın koşma hakkı var mı?" — yoksa sessizce çıkar, varsa koşucuyu çağırır.
#
# NİÇİN CRON, NİÇİN MÜDÜR-OTURUMUNDA DEĞİL (EK-A §A2, üç ölçülmüş gerekçe):
#   1) oturum kapalıysa hat durur — fabrika Sultan'ın uyanıklığına asılamaz
#   2) her tur müdürün bağlamını şişirir — ADR-025'in tam tersi (dolu bağlam dar bakar)
#   3) oturum ölümlüdür: 2026-07-25'te tmux sunucusu öldü, içindekiler gitti
#
# ⛔ INERT DOĞAR (F4). Açma bayrağı YOKSA hiçbir şey koşmaz — karar hesaplanır, basılır, çıkılır.
#    Açma ayrı bir Sultan-GO'sudur (F5). Bayrak: <handoff>/hat-acik  (içeriği: oda adı + tarih notu)
#
# TEMEL AYRIM (§A3): dürtme sıklığı ≠ tur sıklığı. Cron sık sorar (bedava), iş günde bir olur (pahalı).
#
# KURALLAR (§A3, birebir):
#   1 Hak günlüktür — tur tamamlandıysa o gün bir daha koşulmaz
#   2 BOŞ dönmek TAMAMLANMADIR (`bitti-bos` terminal) — aynı gün ikinci arama aynı web'i tarar;
#     ısrar fikir değil ÇÖP üretir. Boş tur yine de deftere yazılır → görünmez olmaz
#   3 Çalışamamak tamamlanma DEĞİLDİR (`basarisiz`) → 3 deneme, artan aralık (+30dk, +2sa)
#   4 3'te de olmazsa PES EDER + bildirim + panoda 🔴 — sonsuz deneme alarm yorgunluğu, sessiz pes RASAT faciası
#   5 MUCİT'in tetiği SAAT değil SAYIDIR: süzülmemiş ≥1 malzeme ∧ bugün süzülmedi
#   6 Tek koşu kilidi (flock). Kilit başkasındaysa sessiz çık — DENEME SAYACI ARTMAZ
#     ("ölçemedim ≠ başarısız"; sessiz-ölüm bekçisiyle aynı kural)
#   7 Hak 09:00'da doğar, 18:00'de düşer — gece boşuna deneme yok, ertesi gün taze hak
#
# KULLANIM:
#   hat-durtme.sh                 # cron girişi: karar ver, hak varsa koş
#   hat-durtme.sh --kuru          # yalnız kararı bas, HİÇBİR ŞEY koşma (varsayılan-güvenli inceleme)
#   hat-durtme.sh --durum         # bugünkü durum kâğıdını bas
#   hat-durtme.sh --ac "<sebep>"  # bu odada hattı AÇ (Sultan-GO'su; INERT'ten çıkar)
#   hat-durtme.sh --kapat         # bu odada hattı kapat
#
# OVERRIDE (test kancaları — üretimde kullanılmaz):
#   HAT_KOSUCU  — adımı fiilen koşan komut. Çağrılış: "$HAT_KOSUCU <adim> <tur>"
#                 Tanımsızsa varsayılan başsız-Claude koşucusu kullanılır.
#   HAT_SIMDI   — "YYYY-MM-DDTHH:MM" biçiminde sahte şimdi (saat-kuralı testleri için)
#   HAT_ROOT / CELL_ID — hat-yolu.lib.sh sözleşmesi
#
# DEĞİŞMEZ: bu betik Sultan'a soru SORAMAZ. Belirsizse üretmez, deftere yazar, panoda görünür.

set -euo pipefail

BURASI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$BURASI/../../layiha/scripts/hat-yolu.lib.sh"
# shellcheck source=/dev/null
. "$BURASI/layiha-fabrika-guard.lib.sh" 2>/dev/null || true

ADIMLAR=(kasif mucit)
TERMINAL_DURUMLAR="bitti-dolu bitti-bos pes-etti"
MAKS_DENEME=3
HAK_BASLANGIC=9    # §A3-7
HAK_BITIS=18

# ── zaman (test-enjekte edilebilir) ──────────────────────────────────────────────────────────
simdi_iso() { printf '%s' "${HAT_SIMDI:-$(date +%Y-%m-%dT%H:%M)}"; }
bugun()     { simdi_iso | cut -dT -f1; }
saat()      { simdi_iso | cut -dT -f2 | cut -d: -f1 | sed 's/^0//;s/^$/0/'; }
# Epok — "sonraki denemenin vakti geldi mi" karşılaştırması için.
epok() { date -d "$(simdi_iso)" +%s 2>/dev/null || printf '0'; }

DURUM_DOSYA="$(hat_yolu hat-durum)" || exit 2
GUNLUK="$(hat_yolu hat-gunluk)"     || exit 2
ACIK_BAYRAK="$(hat_yolu handoff-dir)/hat-acik" || exit 2
KILIT="$(hat_yolu handoff-dir)/.hat-durtme.lock"
mkdir -p "$(dirname "$DURUM_DOSYA")"

oda() { hostname 2>/dev/null || printf 'bilinmeyen-oda'; }

# ── durum kâğıdı ─────────────────────────────────────────────────────────────────────────────
# GÜNLÜKTÜR: tarih değişince kâğıt sıfırlanır ve tur numarası yenilenir. Eski kâğıt korunmaz —
# kalıcı iz `hat-gunluk.jsonl` ile `seyir.jsonl`'dedir (kâğıt yalnız "bugün" içindir).
durum_oku() {
  local g; g="$(bugun)"
  python3 - "$DURUM_DOSYA" "$g" <<'PY'
import json, os, sys
yol, gun = sys.argv[1], sys.argv[2]
bos = {"gun": gun, "tur": "t%s-1" % gun.replace("-", ""),
       "kasif": {"durum": "bekliyor", "deneme": 0, "ts": "", "sonraki": 0, "not": ""},
       "mucit": {"durum": "bekliyor", "deneme": 0, "ts": "", "sonraki": 0, "not": ""}}
try:
    d = json.load(open(yol))
except Exception:
    d = None
# Gün değiştiyse kâğıt TAZEDİR — dünün "pes-etti"si bugünü kilitlemez (§A3-7 taze hak).
if not isinstance(d, dict) or d.get("gun") != gun:
    d = bos
for a in ("kasif", "mucit"):
    d.setdefault(a, dict(bos[a]))
print(json.dumps(d, ensure_ascii=False))
PY
}

durum_yaz() {
  local icerik="$1" gecici
  gecici="$(mktemp "${DURUM_DOSYA}.XXXXXX")"
  printf '%s\n' "$icerik" >"$gecici"
  mv -f "$gecici" "$DURUM_DOSYA"   # atomik değiştirme — yarım kâğıt okunmaz
}

durum_guncelle() {  # <json> <adim> <alan=deger> ...
  local json="$1" adim="$2"; shift 2
  python3 - "$json" "$adim" "$@" <<'PY'
import json, sys
d = json.loads(sys.argv[1]); adim = sys.argv[2]
for cift in sys.argv[3:]:
    k, _, v = cift.partition("=")
    d[adim][k] = int(v) if v.lstrip("-").isdigit() else v
print(json.dumps(d, ensure_ascii=False))
PY
}

alan() {  # <json> <adim> <alan>
  python3 -c 'import json,sys; print(json.loads(sys.argv[1])[sys.argv[2]].get(sys.argv[3], ""))' "$1" "$2" "$3"
}

gunluk_yaz() {  # <adim> <karar> <sebep>
  printf '{"ts":"%s","oda":"%s","adim":"%s","karar":"%s","sebep":"%s"}\n' \
    "$(simdi_iso)" "$(oda)" "$1" "$2" "$3" >>"$GUNLUK"
}

# ── karar motoru — tek saf fonksiyon (test edilebilirliğin kalbi) ────────────────────────────
# stdout: "kos" | "kapali:<sebep>"   — yan etkisi YOK, hiçbir şey yazmaz.
karar() {
  local json="$1" adim="$2" d dn snk s
  d="$(alan "$json" "$adim" durum)"
  dn="$(alan "$json" "$adim" deneme)"
  snk="$(alan "$json" "$adim" sonraki)"
  s="$(saat)"

  # Kural 1+2: terminal durum → o gün kapalı (boş dönmek de tamamlanmadır)
  case " $TERMINAL_DURUMLAR " in
    *" $d "*) printf 'kapali:bugun-tamamlandi(%s)' "$d"; return 0 ;;
  esac
  # Yarım kalmış koşu: başka bir süreç işi almış olabilir → kilit ayıklar, burada bekle
  [ "$d" = "kosuyor" ] && { printf 'kapali:zaten-kosuyor'; return 0; }

  # Kural 7: hak penceresi
  if [ "$s" -lt "$HAK_BASLANGIC" ] || [ "$s" -ge "$HAK_BITIS" ]; then
    printf 'kapali:hak-penceresi-disi(%02d:00 disinda %02d-%02d)' "$s" "$HAK_BASLANGIC" "$HAK_BITIS"; return 0
  fi

  # Kural 3+4: başarısızlıkta artan aralık, 3'te pes
  if [ "$d" = "basarisiz" ]; then
    if [ "$dn" -ge "$MAKS_DENEME" ]; then printf 'kapali:pes-esigi'; return 0; fi
    if [ "$snk" -gt 0 ] && [ "$(epok)" -lt "$snk" ]; then
      printf 'kapali:bekleme-araligi(%s sn kaldi)' "$(( snk - $(epok) ))"; return 0
    fi
  fi

  # Kural 5: MUCİT saat değil SAYI ile tetiklenir
  if [ "$adim" = "mucit" ] && [ "$(suzulmemis_sayisi)" -eq 0 ]; then
    printf 'kapali:suzulmemis-malzeme-yok'; return 0
  fi

  printf 'kos'
}

# Havuzda MUCİT'ten geçmemiş ("ham") malzeme sayısı. Havuz yoksa 0 — fail-closed (boşuna koşmayız).
suzulmemis_sayisi() {
  local havuz; havuz="$(hat_yolu bulgu-havuzu)" || { printf '0'; return 0; }
  [ -f "$havuz" ] || { printf '0'; return 0; }
  python3 - "$havuz" <<'PY'
import json, sys
n = 0
for satir in open(sys.argv[1], encoding="utf-8", errors="replace"):
    satir = satir.strip()
    if not satir:
        continue
    try:
        if (json.loads(satir).get("durum") or "").lower() == "ham":
            n += 1
    except Exception:
        pass   # bozuk satır sayılmaz — sayaç yanlış YÜKSEK olmasın (boşuna koşu üretir)
print(n)
PY
}

# ── koşucu ───────────────────────────────────────────────────────────────────────────────────
# Varsayılan: başsız Claude (EK-A §A2 — tmux ekip-oturumu AÇILMAZ, direktif delinmez).
# El-kitabındaki dispatch kalıbının AYNISI kullanılır: iki tetik, tek sistem.
varsayilan_kosucu() {
  local adim="$1" tur="$2"
  command -v claude >/dev/null 2>&1 || { printf 'claude bulunamadi\n' >&2; return 2; }
  local komut
  case "$adim" in
    kasif) komut="/kasif-tara" ;;
    mucit) komut="/mucit-suz"  ;;
    *)     printf 'bilinmeyen adim: %s\n' "$adim" >&2; return 2 ;;
  esac
  LAYIHA_ROL="otonom" LAYIHA_TUR="$tur" \
    claude --print "$komut

Bu koşu OTONOM hattan geldi (tur: $tur). El-kitabındaki akışın aynısını uygula.
Sultan'a soru soramazsın: belirsizsen ÜRETME, gerekçeyi deftere yaz, panoda görünsün."
}

kosucuyu_cagir() {
  local adim="$1" tur="$2"
  if [ -n "${HAT_KOSUCU:-}" ]; then "$HAT_KOSUCU" "$adim" "$tur"; else varsayilan_kosucu "$adim" "$tur"; fi
}

# ── açma/kapama (INERT sözleşmesi) ───────────────────────────────────────────────────────────
acik_mi() { [ -f "$ACIK_BAYRAK" ]; }

# ── komutlar ─────────────────────────────────────────────────────────────────────────────────
case "${1:-}" in
  --durum)
    durum_oku | python3 -m json.tool 2>/dev/null || durum_oku
    exit 0 ;;
  --ac)
    [ -n "${2:-}" ] || { printf 'HATA: --ac "<sebep>" (niçin açıldığı kayda geçer)\n' >&2; exit 2; }
    mkdir -p "$(dirname "$ACIK_BAYRAK")"
    printf '{"ts":"%s","oda":"%s","sebep":"%s"}\n' "$(simdi_iso)" "$(oda)" "$2" >"$ACIK_BAYRAK"
    printf 'hat AÇILDI · oda=%s · sebep=%s\n' "$(oda)" "$2"
    printf '⚠️  bundan sonra cron dürttükçe gerçek koşu olur. Kapatmak: %s --kapat\n' "${0##*/}"
    exit 0 ;;
  --kapat)
    rm -f "$ACIK_BAYRAK"; printf 'hat KAPATILDI · oda=%s (INERT — hiçbir şey koşmaz)\n' "$(oda)"; exit 0 ;;
  --kuru) KURU=1 ;;
  "")     KURU=0 ;;
  *)      printf 'kullanım: %s [--kuru|--durum|--ac "<sebep>"|--kapat]\n' "${0##*/}" >&2; exit 2 ;;
esac

# Fabrika kill-switch'i hattı da kapatır — iki ayrı düğme tutmuyoruz.
if declare -f layiha_fabrika_kapali_mi >/dev/null 2>&1 && layiha_fabrika_kapali_mi 2>/dev/null; then
  printf 'hat kapalı: fabrika kill-switch açık\n'; gunluk_yaz "-" "kapali" "fabrika-kill-switch"; exit 0
fi

# Kural 6: tek koşu kilidi. Kilit başkasındaysa SESSİZ çık ve sayacı ARTIRMA.
exec 9>"$KILIT"
if ! flock -n 9; then
  gunluk_yaz "-" "atlandi" "kilit-baskasinda(deneme-artmadi)"
  printf 'başka bir dürtme koşuyor — sessiz çıkıldı (deneme sayacı artmadı)\n'; exit 0
fi

JSON="$(durum_oku)"
TUR="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["tur"])' "$JSON")"
CIKIS=0

for adim in "${ADIMLAR[@]}"; do
  K="$(karar "$JSON" "$adim")"
  if [ "$K" != "kos" ]; then
    printf '%-6s ⚪ %s\n' "$adim" "${K#kapali:}"
    gunluk_yaz "$adim" "kapali" "${K#kapali:}"
    continue
  fi

  if [ "$KURU" = "1" ]; then
    printf '%-6s 🟢 KOŞARDI (kuru koşu — hiçbir şey çalıştırılmadı)\n' "$adim"
    gunluk_yaz "$adim" "kuru-kosardi" "hak-var"
    continue
  fi
  if ! acik_mi; then
    printf '%-6s ⚪ hak var AMA hat bu odada KAPALI (INERT) — açmak: %s --ac "<sebep>"\n' "$adim" "${0##*/}"
    gunluk_yaz "$adim" "kapali" "hat-inert(acma-bayragi-yok)"
    continue
  fi

  # ── gerçek koşu ────────────────────────────────────────────────────────────────────────────
  JSON="$(durum_guncelle "$JSON" "$adim" durum=kosuyor "ts=$(simdi_iso)")"; durum_yaz "$JSON"
  gunluk_yaz "$adim" "kosuyor" "tur=$TUR"

  if kosucuyu_cagir "$adim" "$TUR"; then
    # Boş mu dolu mu: adımın kendi defterine bakmak yerine koşucunun çıktısına güveniyoruz —
    # koşucu RC=0 verdiyse tur TAMAMLANMIŞTIR. "Dolu mu" ayrımını pano defterlerden okur.
    JSON="$(durum_guncelle "$JSON" "$adim" durum=bitti-dolu "ts=$(simdi_iso)")"; durum_yaz "$JSON"
    printf '%-6s 🟢 tamamlandı (tur=%s)\n' "$adim" "$TUR"
    gunluk_yaz "$adim" "bitti" "tur=$TUR"
  else
    rc=$?
    dn="$(alan "$JSON" "$adim" deneme)"; dn=$(( dn + 1 ))
    if [ "$dn" -ge "$MAKS_DENEME" ]; then
      JSON="$(durum_guncelle "$JSON" "$adim" durum=pes-etti "deneme=$dn" "ts=$(simdi_iso)" "not=rc=$rc")"
      durum_yaz "$JSON"
      printf '%-6s 🔴 %d denemede de olmadı — PES EDİLDİ (rc=%d)\n' "$adim" "$dn" "$rc"
      gunluk_yaz "$adim" "pes-etti" "deneme=$dn rc=$rc"
      CIKIS=1   # Kural 4: sessiz pes YOK — çıkış kodu veriyoruz ki cron/bekçi duysun
    else
      # Artan aralık: 1. başarısızlıktan sonra +30dk, 2.'den sonra +2sa
      bekleme=$(( dn == 1 ? 1800 : 7200 ))
      JSON="$(durum_guncelle "$JSON" "$adim" durum=basarisiz "deneme=$dn" "ts=$(simdi_iso)" \
              "sonraki=$(( $(epok) + bekleme ))" "not=rc=$rc")"
      durum_yaz "$JSON"
      printf '%-6s 🟡 başarısız (deneme %d/%d, rc=%d) — %d dk sonra tekrar\n' \
        "$adim" "$dn" "$MAKS_DENEME" "$rc" "$(( bekleme / 60 ))"
      gunluk_yaz "$adim" "basarisiz" "deneme=$dn rc=$rc"
    fi
  fi
done

exit "$CIKIS"
