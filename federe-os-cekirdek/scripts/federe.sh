#!/usr/bin/env bash
# federe.sh — Federe Ekip-OS çekirdek-istemcisi (C3/D7 · k0180). Nexus `scripts/federe-tetik.sh`'in
# (FAZ-1 · A1/A4) FİLO-TAŞINABİLİR uyarlaması: Nexus-repo'suz container'da da çalışır (izole-birimler
# Nexus'u GÖREMEZ — skill ortak ~/.claude/skills mount'uyla 10/10 dağıtılır, istemci de yanında gider).
#
#   gonder [--tetikli "<gerekçe≤120>"] <hedef_sNN> "<başlık≤120>" [kart_ref] [not≤500]   → tetik bırak (META-only; --tetikli = zil)
#   gelen [durum] · giden [durum]                             → kutu listele
#   alindi <id> · tamam <id> ["sonuç-notu≤500"] · iptal <id>  → durum-makinesi (ileri-yönlü)
#   dinle                                                      → poll: bekleyenleri yerel-inbox'a yaz + alindi-ACK
#   nabiz "<özet≤200>" [skor 0-100]                            → canlılık-nabzı yaz (A3; eksenler={ozet})
#   durum                                                      → dürüst-3-durum probe (yeşil/kırmızı/doğrulanamadı)
#
# AUTH (sıra): FEDERE_TETIK_TOKEN env → FEDERE_TOKEN_FILE (default ~/.federe/token; GO-1 provizyonu
#   buraya iner, 0600) → DEFTER_ENV_FILE (default Nexus ui/.env — yalnız merkez-container'da vardır).
#   Kimlik SUNUCUDA token'dan türer (cellIdFromBearer) — bu istemci cell BEYAN ETMEZ/EDEMEZ.
# DEĞER-GÜVENLİK: token asla echo/stdout/argv'ye düşmez (curl --config). Sır-desenli gövde yerelde de
#   reddedilir (sunucu 400'üne ek ön-kapı; değer geri-BASILMAZ).
# Exit: 0 ok · 1 API-hata · 2 kullanım/ortam.
set -euo pipefail

for _b in curl jq; do
  command -v "$_b" >/dev/null 2>&1 || { echo "HATA: $_b gerekli (federe-os-cekirdek ön-koşulu — İSKÂN-doğumlu kutuda eksikse kur)" >&2; exit 2; }
done

BASE="${FEDERE_API_BASE:-${DEFTER_API_BASE:-https://nexusapp.up.railway.app}}"
ENV_FILE="${DEFTER_ENV_FILE:-/config/projects/Nexus/ui/.env}"
TOKEN_FILE="${FEDERE_TOKEN_FILE:-$HOME/.federe/token}"
CELL_RE='^s[0-9]{2}$'

# Deterministik teslim-noktası: cwd'den BAĞIMSIZ tek yol (koşuya-göre-değişen inbox = kayıp-mesaj sınıfı).
# Repo-içi inbox istenirse FEDERE_TETIK_INBOX ile sabitlenir (her koşuda AYNI değer — cron-paketi.md).
_inbox() { printf '%s' "${FEDERE_TETIK_INBOX:-$HOME/.federe/tetik-inbox.md}"; }

kullanim() {
  cat >&2 <<'K'
kullanım: federe.sh <komut>
  gonder [--tetikli "<gerekçe≤120>"] <hedef_sNN> "<başlık≤120>" [kart_ref] [not≤500]
  gelen [bekliyor|alindi|tamam|iptal|all]
  giden [bekliyor|alindi|tamam|iptal|all]
  alindi <id> · tamam <id> ["sonuç-notu≤500"] · iptal <id>
  dinle    (poll: bekleyenleri yerel gelen-kutusuna yaz + alindi-ACK)
  nabiz "<özet≤200>" [skor 0-100]
  durum    (dürüst-3-durum probe: token/API/inbox)
K
  exit 2
}

# Sır-desen ön-kapısı (sunucu SIR_DESENLERI ailesi; değer asla geri-basılmaz)
_sir_var() {
  printf '%s' "$1" | grep -qE 'sk-[A-Za-z0-9]{20}|ghp_[A-Za-z0-9]{30}|AKIA[A-Z0-9]{16}|BEGIN (RSA |EC )?PRIVATE KEY|xox[bp]-'
}

# $1(ops)=quiet: token-kaynağını stderr'e ADINI basar (değeri asla)
_token() {
  if [[ -n "${FEDERE_TETIK_TOKEN:-}" ]]; then printf '%s' "$FEDERE_TETIK_TOKEN"; return 0; fi
  if [[ -f "$TOKEN_FILE" ]]; then head -1 "$TOKEN_FILE" | tr -d '[:space:]'; return 0; fi
  if [[ -f "$ENV_FILE" ]]; then
    grep '^DEFTER_SERDAR_TOKEN=' "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"'\'
    return 0
  fi
  echo "HATA: token kaynağı yok (FEDERE_TETIK_TOKEN env · $TOKEN_FILE · $ENV_FILE)" >&2
  return 2
}

_token_kaynagi() { # yalnız AD döner (probe için; değer değil)
  if [[ -n "${FEDERE_TETIK_TOKEN:-}" ]]; then echo "env:FEDERE_TETIK_TOKEN"
  elif [[ -f "$TOKEN_FILE" ]]; then echo "dosya:$TOKEN_FILE"
  elif [[ -f "$ENV_FILE" ]]; then echo "env-dosyası:$ENV_FILE"
  else echo "YOK"; fi
}

# $1=method $2=path [$3=json-body] — token --config ile (argv/ps sızıntısı YOK)
_api() {
  local tok; tok="$(_token)" || return 2
  [[ -n "$tok" ]] || { echo "HATA: token boş" >&2; return 2; }
  if [[ "$1" == "GET" ]]; then
    curl -sS --max-time 20 \
      --config <(printf 'header = "Authorization: Bearer %s"\n' "$tok") "$BASE$2"
  else
    curl -sS --max-time 20 -X "$1" \
      --config <(printf 'header = "Authorization: Bearer %s"\n' "$tok") \
      -H "Content-Type: application/json" -d "$3" "$BASE$2"
  fi
}

_listele() { # $1=yon $2=durum
  local durum="${2:-bekliyor}"
  case "$durum" in bekliyor|alindi|tamam|iptal|all) ;; *) echo "HATA: durum enum-dışı: $durum" >&2; exit 2 ;; esac
  local resp; resp="$(_api GET "/api/filo/tetik?yon=$1&durum=$durum")" || { rc=$?; [ "$rc" -eq 2 ] && exit 2; exit 1; }
  if echo "$resp" | jq -e '.error' >/dev/null 2>&1; then
    echo "❌ $(echo "$resp" | jq -r '.error')"; exit 1
  fi
  local adet; adet="$(echo "$resp" | jq -r '.adet // 0')"
  if [[ "$adet" == "0" ]]; then echo "📭 kayıt yok ($1/$durum)"; return 0; fi
  echo "📬 $adet kayıt ($1/$durum):"
  # b0060 (2026-07-31): `not` alanı GÖNDERİLİYOR (POST :133-135, ≤500 META) ve GET tam kaydı
  # döndürüyor — ama okuma ucu onu HİÇ basmıyordu. Gönderen "not yazdım" der, alan taraf yalnız
  # başlığı görürdü; 7 MİHENK talebi bu yüzden yalnız başlıktan triyaj edilebildi. Not artık
  # girintili ikinci satır olarak basılır (varsa); yoksa satır aynen eskisi gibi tek satır kalır.
  echo "$resp" | jq -r '.tetikler[] | "  • [\(.id)] \(.durum) · \(.kaynakCell)→\(.hedefCell) · \(.tip) · \(.baslik)\(if .kartRef then " (\(.kartRef))" else "" end)" + (if (.not // "") != "" then "\n      ↳ \(.not)" else "" end)'
}

_gecis() { # $1=id $2=durum [$3=sonuc_not]
  local id="${1:?id gerekli}" durum="$2" nt="${3:-}"
  local body
  body="$(jq -nc --arg i "$id" --arg d "$durum" --arg n "$nt" \
    '{id:$i, durum:$d} + (if $n=="" then {} else {sonuc_not:$n} end)')"
  local resp; resp="$(_api PATCH /api/filo/tetik "$body")" || { rc=$?; [ "$rc" -eq 2 ] && exit 2; exit 1; }
  if echo "$resp" | jq -e '.ok == true' >/dev/null 2>&1; then
    echo "✅ [$id] → $durum"
  else
    echo "❌ $(echo "$resp" | jq -r '.error // "beklenmedik-yanıt"')"; exit 1
  fi
}

cmd="${1:-}"; [[ -n "$cmd" ]] || kullanim
case "$cmd" in
  gonder)
    # --tetikli "<gerekçe≤120>" (L42-F2 · MABEYN F0.4): tetik zil-META'sıyla düşer; merkez
    # oda-zil turu YALNIZ zil'lileri okuyup hedef odayı uyandırmayı dener. Gerekçesiz zil yok.
    # 🔴 BAYRAK KAPISI (2026-08-08, NÂZIR bulgusu · 14 oda etkileniyor).
    # ESKİ DAVRANIŞ: yalnız `--tetikli` ve YALNIZ 2. konumda tanınırdı; başka her `--xyz`
    # sessizce KONUMSAL METİN sayılırdı. Ölçülen sonuç: `--tip tetik --baslik "…"` yazan bir
    # çağrıda başlık `--tip` oldu ve mesaj BİR SAAT kuyrukta bekledi — hedefi hiç bulmadı.
    # Sınıf: "hatayı sessizce yutan araç". `layiha-defteri.sh liste`de RC=2 ile kapatılmıştı
    # (L24 F4), burada açıktı. Artık tanınmayan bayrak DURDURUR ve geçerli listeyi basar.
    zil=0; zil_sebep=""
    while [ $# -gt 1 ]; do
      case "${2:-}" in
        --tetikli)
          zil=1; zil_sebep="${3:-}"; shift 2
          [[ -n "$zil_sebep" && ${#zil_sebep} -le 120 ]] || { echo "HATA: --tetikli gerekçe ister (≤120) — gerekçesiz zil yok" >&2; exit 2; }
          ;;
        --*)
          echo "HATA: tanınmayan bayrak: '${2}'" >&2
          echo "  gonder için geçerli bayraklar: --tetikli \"<gerekçe≤120>\"
  (--sinif <mesaj|is|devir> HENÜZ YOK: sunucuda `tip` alanı `tetik|durdur` için alınmış,
   iş-sınıfı ayrı alan + göç istiyor — istemciye sunucu hazır olmadan konmadı, yoksa
   bayrak sessizce yutulurdu; düzeltilen hastalığın aynısı olurdu.)" >&2
          echo "  (sessizce konumsal-metin saymıyorum — eski davranış mesajı kuyrukta kaybediyordu)" >&2
          exit 2 ;;
        *) break ;;
      esac
    done
    hedef="${2:-}"; baslik="${3:-}"; kart="${4:-}"; nt="${5:-}"
    [[ "$hedef" =~ $CELL_RE ]] || { echo "HATA: hedef sNN formatında olmalı (ör. s04)" >&2; exit 2; }
    [[ -n "$baslik" && ${#baslik} -le 120 ]] || { echo "HATA: başlık zorunlu, ≤120" >&2; exit 2; }
    [[ ${#nt} -le 500 ]] || { echo "HATA: not ≤500 (içerik-kanalı değil — META)" >&2; exit 2; }
    _sir_var "$baslik$kart$nt$zil_sebep" && { echo "HATA: sır-desen tespit — META-kanala sır yazılamaz" >&2; exit 2; }
    body="$(jq -nc --arg h "$hedef" --arg b "$baslik" --arg k "$kart" --arg n "$nt" --arg zs "$zil_sebep" --argjson z "$([ "$zil" -eq 1 ] && echo true || echo false)" \
      '{hedef_cell:$h, baslik:$b} + (if $k=="" then {} else {kart_ref:$k} end) + (if $n=="" then {} else {not:$n} end) + (if $z then {zil:true, zil_sebep:$zs} else {} end)')"
    resp="$(_api POST /api/filo/tetik "$body")" || { rc=$?; [ "$rc" -eq 2 ] && exit 2; exit 1; }
    if echo "$resp" | jq -e '.ok == true' >/dev/null 2>&1; then
      echo "📨 tetik bırakıldı: $(echo "$resp" | jq -r '"\(.id) · \(.kaynak_cell)→\(.hedef_cell)"')"
    else
      echo "❌ $(echo "$resp" | jq -r '.error // "beklenmedik-yanıt"')"; exit 1
    fi
    ;;
  gelen) _listele gelen "${2:-bekliyor}" ;;
  giden) _listele giden "${2:-all}" ;;
  alindi) _gecis "${2:-}" alindi ;;
  tamam)  _gecis "${2:-}" tamam "${3:-}" ;;
  iptal)  _gecis "${2:-}" iptal ;;
  dinle)
    # ⚖️ TESLİMAT ≠ ÜSTLENME (L37-F0, 2026-07-31 — sahte-makbuz panzehiri)
    #
    # ESKİ DAVRANIŞ: `dinle` her tetiği gelen-kutusuna yazar VE durumunu KOŞULSUZ `alindi`ya
    # çevirirdi. Gönderen tarafta bu "muhatabım işi üstlendi" anlamına geliyordu — oysa hiç
    # kimse üstlenmemişti; kayıt yalnız kimsenin bakmadığı bir dosyaya düşmüştü.
    # Ölçülen sonuç: 7 MİHENK talebi 8 gün 20 saat boyunca "teslim alındı" damgalı bekledi;
    # kuyruk, hiç iş yapılmasa bile SONSUZA DEK TEMİZ görünüyordu.
    #
    # YENİ DAVRANIŞ: `dinle` yalnız TESLİM EDER (gelen-kutusuna yazar) — durum `bekliyor`
    # KALIR. `alindi` damgasını yalnız bir SAHİP basar: `federe.sh alindi <id>`.
    # Böylece "kuyrukta bekleyen" sayısı gerçeği söyler ve sahipsizlik görünür olur.
    #
    # MÜKERRER-YAZIM: ACK basılmadığı için her poll aynı tetikleri döndürür → görülen id'ler
    # bir durum dosyasında tutulur; gelen-kutusuna her tetik YALNIZ BİR KEZ yazılır.
    # `--ack` bayrağı eski davranışı korur (geriye-uyum; otomasyon kırılmasın).
    INBOX="$(_inbox)"
    ACK=0; [ "${2:-}" = "--ack" ] && ACK=1
    GORULEN="${FEDERE_GORULEN:-$(dirname "$INBOX")/gorulen-tetikler.txt}"
    resp="$(_api GET "/api/filo/tetik?yon=gelen&durum=bekliyor")" || { rc=$?; [ "$rc" -eq 2 ] && exit 2; exit 1; }
    if echo "$resp" | jq -e '.error' >/dev/null 2>&1; then
      echo "❌ $(echo "$resp" | jq -r '.error')"; exit 1
    fi
    adet="$(echo "$resp" | jq -r '.adet // 0')"
    if [[ "$adet" == "0" ]]; then echo "📭 bekleyen tetik yok"; exit 0; fi
    mkdir -p "$(dirname "$INBOX")"; touch "$GORULEN"
    ts="$(date -u +%Y-%m-%dT%H:%MZ)"
    ackfail=0; yeni=0
    while IFS=$'\t' read -r id kaynak tip baslik kart; do
      if ! grep -qxF "$id" "$GORULEN" 2>/dev/null; then
        printf -- '- [%s] %s %s ← %s: %s%s\n' "$ts" "$tip" "$id" "$kaynak" "$baslik" \
          "${kart:+ ($kart)}" >> "$INBOX"
        printf '%s\n' "$id" >> "$GORULEN"
        yeni=$((yeni+1))
      fi
      if [ "$ACK" -eq 1 ]; then
        # _gecis hata-yolunda exit çağırır → subshell'e al ki tek ACK-hatası batch'i öldürmesin
        # (409 eşzamanlılık/anlık-ağ = beklenen sınıf; ACK'lenmeyen sonraki poll'da tekrar gelir).
        if ( _gecis "$id" alindi >/dev/null 2>&1 ); then :; else
          ackfail=$((ackfail+1)); echo "⚠️ ACK düşmedi: $id" >&2
        fi
      fi
    done < <(echo "$resp" | jq -r '.tetikler[] | [.id, .kaynakCell, .tip, .baslik, (.kartRef // "")] | @tsv')
    if [ "$ACK" -eq 1 ]; then
      if [ "$ackfail" -gt 0 ]; then
        echo "📥 $adet tetik çekildi → $INBOX (ACK: $((adet-ackfail)) ok · $ackfail düşmedi — ACK'siz olanlar sonraki poll'da tekrar gelir)"
        exit 1
      fi
      echo "📥 $adet tetik teslim-alındı → $INBOX (alindi-ACK basıldı)"
      exit 0
    fi
    # Varsayılan yol: teslim edildi, ÜSTLENİLMEDİ. Sayı gerçeği söyler.
    echo "📥 $adet bekleyen tetik ($yeni yeni) → $INBOX · SAHİPSİZ — üstlenmek için: federe.sh alindi <id>"
    ;;
  nabiz)
    ozet="${2:-}"; skor="${3:-}"
    [[ -n "$ozet" && ${#ozet} -le 200 ]] || { echo "HATA: özet zorunlu, ≤200 (yalnız-META)" >&2; exit 2; }
    _sir_var "$ozet" && { echo "HATA: sır-desen tespit — nabız-özetine sır yazılamaz" >&2; exit 2; }
    if [[ -n "$skor" ]]; then
      [[ "$skor" =~ ^[0-9]+$ ]] && [ "$skor" -ge 0 ] && [ "$skor" -le 100 ] \
        || { echo "HATA: skor 0-100 tamsayı" >&2; exit 2; }
    fi
    body="$(jq -nc --arg o "$ozet" --arg s "$skor" \
      '{eksenler:{ozet:$o}, kaynak:"federe-os-cekirdek"} + (if $s=="" then {skor:null} else {skor:($s|tonumber)} end)')"
    resp="$(_api POST /api/filo/nabiz "$body")" || { rc=$?; [ "$rc" -eq 2 ] && exit 2; exit 1; }
    if echo "$resp" | jq -e '.ok == true' >/dev/null 2>&1; then
      echo "💓 nabız yazıldı: $(echo "$resp" | jq -r '"cell=\(.cell) skor=\(.skor // "-")"')"
    else
      echo "❌ $(echo "$resp" | jq -r '.error // "beklenmedik-yanıt"')"; exit 1
    fi
    ;;
  durum)
    # Dürüst-3-durum probe (report-only, exit 0): yeşil · kırmızı(fail:neden) · doğrulanamadı.
    kaynak="$(_token_kaynagi)"
    echo "🔎 federe-os-çekirdek durum-probu"
    echo "  • bağımlılıklar: curl+jq OK (ön-koşul başta doğrulandı)"
    echo "  • API tabanı: $BASE"
    echo "  • inbox yolu: $(_inbox)"
    if [[ "$kaynak" == "YOK" ]]; then
      echo "  • token: YOK (bu birimin token'ı henüz provizyonlanmadı — kutu-kutu vault, Sultan-eli) → API: DOĞRULANAMADI (tokensız probe atılmadı)"
      echo "  ℹ️ sahte-yeşil basılmaz: kimlik gelene dek bu birim federe-kanalda 'doğrulanamadı' sayılır."
      exit 0
    fi
    echo "  • token kaynağı: $kaynak (değer basılmaz)"
    if resp="$(_api GET "/api/filo/tetik?yon=gelen&durum=bekliyor" 2>&1)"; then
      if echo "$resp" | jq -e '.adet' >/dev/null 2>&1; then
        echo "  • API: YEŞİL (gelen-kutusu okunabildi; bekleyen=$(echo "$resp" | jq -r '.adet'))"
      else
        echo "  • API: KIRMIZI (fail: $(echo "$resp" | jq -r '.error // "beklenmedik-yanıt"' 2>/dev/null || echo 'yanıt çözülemedi'))"
      fi
    else
      echo "  • API: KIRMIZI (fail: erişim/ağ hatası)"
    fi
    ;;
  *) kullanim ;;
esac
