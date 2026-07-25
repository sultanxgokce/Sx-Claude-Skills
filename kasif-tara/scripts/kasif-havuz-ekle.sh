#!/usr/bin/env bash
# kasif-havuz-ekle.sh — KAŞİF'in TEK yazma-yüzeyi: dış-tarama bulgularını bulgu-havuzuna EKLER.
# (DİVAN k0054, doktrin §5/§9: "KEŞŞAF dış-tarama → ham-malzeme; DEFTERE DOKUNMAZ").
#
# KAŞİF deftere/karta/arza DOKUNAMAZ — yalnız BURADAN havuza ham-malzeme yazar. Bu script mekanik
# yazma-kapısıdır: şema-doğrula (fail-closed) + havuz-dedup (tekrar-tarama idempotent) + id-artır + append.
# MİHENK-etiketleme + kart-dedup DOWNSTREAM MUCİT-T1'de yapılır (çift-iş yok); burada yalnız havuz-içi
# tekrar (aynı bulguyu iki taramada iki kez ekleme) engellenir.
#
# GİRDİ:  --girdi <candidates.json>  → JSON dizi: [{baslik, detay, kanit, [tip]}] (kanit=kaynak-URL/alıntı ZORUNLU)
# ÇIKTI:  havuza append + stdout özet {eklenen, atlanan_dup, atlanan_anahtar, atlanan_gecersiz, yeni_idler}
# RC: 0=başarı (0 eklenen de 0) · 2=girdi/şema hatası (fail-closed).
#
# FİLO-ALANLARI (SANCAK A2 dilim-3 · k0124 · EYALET-KANUNU §5): her yeni satıra
#   cell      = CELL_ID (default s01) — bulguyu HANGİ birimin keşşafı getirdi
#   dedup_key = norm(baslik) — DETERMİNİSTİK çift-anahtarı: aynı anahtar havuzda "ham/aday"
#               durumda VARSA aday atlanır (Jaccard bulanık-katmanın GARANTİ tamamlayıcısı;
#               iki sancağın keşşafı aynı fikri iki kez sokamaz — içerik-merkezileştirmeden,
#               hash-anahtarla). "islendi/kart-bağlı" eski kayıt YENİDEN-girişi ENGELLEMEZ
#               (nüks = yeni sinyal). Eski alansız-satırlar okuma-anında norm'lanır (göç yok).
# DEĞER-GÜVENLİK: sır basmaz; salt-hesap + append.
set -euo pipefail

# ── yol-çözümü (L24 F3: paket-içi) ──────────────────────────────────────────────────────────
# Bu script artık ortak-mount'taki `kasif-tara` paketinde yaşıyor; `hucre-baglam.lib.sh` PAKETE
# GİRMEZ. Gerekçe: o kitaplık kökü SCRIPT dizininden hesaplar → paket dizini (ortak-mount, git-repo
# DEĞİL) kök sayılır, veri 10 container'ın ortak dizinine düşer (İ1 ihlali) ve sync'in `rmSync`'i
# bir sonraki kurulumda onu siler. Yerine kökü CWD'den çözen `hat-yolu.lib.sh` (L24 F1).
PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HAT_LIB="${HAT_YOLU_LIB:-$PAKET/../layiha/scripts/hat-yolu.lib.sh}"
[ -r "$HAT_LIB" ] || { echo "HATA: hat-yolu.lib.sh yok: $HAT_LIB — 'layiha' paketi kurulu mu?" >&2; exit 2; }
# shellcheck source=/dev/null
source "$HAT_LIB"

if [ -n "${KASIF_HAVUZ:-}" ]; then HAVUZ="$KASIF_HAVUZ"
else HAVUZ="$(hat_yolu bulgu-havuzu)" || exit 2; fi
DEDUP_ESIK="${KASIF_DEDUP_ESIK:-0.6}"
TARIH="${KASIF_TARIH:-$(date -u +%Y-%m-%d)}"
GIRDI=""
KAYNAK="kasif"   # --kaynak ile geçersiz-kılınır (EYALET-KANUNU §7: sağlık-bulgusu kaynak=sancak-saglik)

command -v jq >/dev/null 2>&1 || { echo "HATA: jq yok" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --girdi) GIRDI="${2:?}"; shift ;;
    --havuz) HAVUZ="${2:?}"; shift ;;
    --tarih) TARIH="${2:?}"; shift ;;
    --kaynak) KAYNAK="${2:?}"; shift ;;
    *) echo "HATA: bilinmeyen bayrak: $1" >&2; exit 2 ;;
  esac; shift
done
[[ -n "$GIRDI" && -f "$GIRDI" ]] || { echo "HATA: --girdi <candidates.json> gerekli/yok" >&2; exit 2; }
[[ -f "$HAVUZ" ]] || { echo "HATA: havuz yok: $HAVUZ" >&2; exit 2; }

# SF1 · yazma-hedefi SABİT: KAŞİF güvenilmez web-içeriği okur (prompt-injection yüzeyi) → ham-satır
# YALNIZ kanonik havuza gitmeli; --havuz/KASIF_HAVUZ ile başka bir JSONL'e yönlendirilemez. Test = KASIF_TEST=1.
# (kanonik yol TEMBEL hesaplanır: KASIF_TEST=1 hermetik koşularda git-kökü aranmaz.)
if [[ "${KASIF_TEST:-0}" != "1" ]]; then
  KANONIK_HAVUZ="$(hat_yolu bulgu-havuzu)" || exit 2
  if [[ "$(realpath -m "$HAVUZ")" != "$(realpath -m "$KANONIK_HAVUZ")" ]]; then
    echo "HATA: KAŞİF yalnız kanonik havuza yazar ($KANONIK_HAVUZ). Test için KASIF_TEST=1." >&2; exit 2
  fi
fi

# Girdi + havuz bütünlüğü (fail-closed)
jq -e 'type=="array"' "$GIRDI" >/dev/null 2>&1 || { echo "HATA: girdi JSON-dizi değil: $GIRDI" >&2; exit 2; }
jq empty "$HAVUZ" 2>/dev/null || { echo "HATA: havuz bozuk-JSONL — fail-closed durduruldu: $HAVUZ" >&2; exit 2; }

# SF3 · eşzamanlı /kasif-tara koşuları id-çakışmasın — oku-max→append kritik-bölümü flock ile serileştir
# (lock süreç-çıkışında serbest kalır; icra-birimi taze-koşu → zamanlı+manuel örtüşme gerçekçi).
exec 9>"$HAVUZ.lock" 2>/dev/null || true
flock 9 2>/dev/null || true

# Bir sonraki b#### id (havuzdaki en büyük b-numarasından +1)
SON="$(jq -rs 'map(.id // empty | select(test("^b[0-9]+$")) | ltrimstr("b") | tonumber) | (max // 0)' "$HAVUZ" 2>/dev/null || echo 0)"
[[ "$SON" =~ ^[0-9]+$ ]] || SON=0

# Mevcut havuz-başlıkları + anahtar-durum çiftleri (dedup kaynakları)
# DURUM-FARKINDALIK (k0124): yalnız ham/aday kayıtlar bloklar — işlenmiş/kart-bağlı kayıt
# yeniden-girişi ENGELLEMEZ (nüks = yeni sinyal; haftalık sağlık-döngüsü buna muhtaç).
# Önceki davranış işlenmişleri de blokluyordu (kalıcı-bastırma) — bilinçli düzeltme.
HAVUZ_BASLIKLAR="$(jq -cs '[ .[] | select(((.durum // "ham") == "ham") or ((.durum // "ham") == "aday")) | .baslik // empty ]' "$HAVUZ")"
HAVUZ_ANAHTARLAR="$(jq -cs '
  def trlower: gsub("İ";"i")|gsub("I";"ı")|gsub("Ş";"ş")|gsub("Ğ";"ğ")|gsub("Ç";"ç")|gsub("Ö";"ö")|gsub("Ü";"ü");
  def norm: trlower | ascii_downcase | gsub("[^a-zçğıöşü0-9 ]"; " ") | gsub("  +"; " ") | ltrimstr(" ") | rtrimstr(" ");
  [ .[] | {k: (.dedup_key // ((.baslik // "") | norm)), d: (.durum // "ham")} | select(.k != "") ]' "$HAVUZ")"

# ── mekanik süzme: geçerlilik (baslik+kanit) + havuz-dedup (Jaccard + deterministik-anahtar) ──
# norm/tokens/jaccard = mucit-t1.sh ile AYNI kanon (Türkçe-normalize dahil).
KARAR="$(jq -c -n \
  --slurpfile aday "$GIRDI" \
  --argjson mevcut "$HAVUZ_BASLIKLAR" \
  --argjson manahtar "$HAVUZ_ANAHTARLAR" \
  --argjson esik "$DEDUP_ESIK" '
  def trlower: gsub("İ";"i")|gsub("I";"ı")|gsub("Ş";"ş")|gsub("Ğ";"ğ")|gsub("Ç";"ç")|gsub("Ö";"ö")|gsub("Ü";"ü");
  def norm: trlower | ascii_downcase | gsub("[^a-zçğıöşü0-9 ]"; " ") | gsub("  +"; " ") | ltrimstr(" ") | rtrimstr(" ");
  def tokens: norm | split(" ") | map(select(length>2)) | unique;
  def jaccard($a;$b): ($a+$b|unique) as $u | if ($u|length)==0 then 0 else (($a|length)+($b|length)-($u|length)) / ($u|length) end;
  ($mevcut | map(tokens)) as $mtok |
  ([ $manahtar[] | select(.d == "ham" or .d == "aday") | .k ]) as $blokan |
  [ $aday[0][] |
    . as $c |
    (($c.baslik // "") | gsub("\\s";"") | length > 0) as $baslikli |
    (($c.kanit  // "") | gsub("\\s";"") | length > 0) as $kanitli |
    ($c.baslik // "" | tokens) as $ctok |
    (($c.baslik // "") | norm) as $key |
    ([ $mtok[] | jaccard($ctok; .) ] | max // 0) as $ortusme |
    { baslik:$c.baslik, detay:($c.detay // ""), kanit:($c.kanit // ""), tip:($c.tip // "bulgu"),
      _key:$key, _gecerli: ($baslikli and $kanitli), _dup: ($ortusme >= $esik),
      _dupkey: ($blokan | index($key) != null) }
  ] |
  # parti-içi tekrar: aynı anahtarın ikinci+ geçerli-adayı da anahtar-atlanır (ilk kazanır)
  reduce to_entries[] as $e ({seen:{}, out:[]};
    ($e.value._key) as $k |
    if ($e.value._gecerli and ($e.value._dup|not) and ($e.value._dupkey|not))
    then (if (.seen[$k] // false)
          then .out += [$e.value + {_dupkey:true}]
          else .seen[$k] = true | .out += [$e.value] end)
    else .out += [$e.value] end
  ) | .out
')"

GECERLI="$(jq -c '[ .[] | select(._gecerli and (._dup|not) and (._dupkey|not)) ]' <<<"$KARAR")"
E_GECERSIZ=$(jq '[ .[] | select(._gecerli|not) ] | length' <<<"$KARAR")
E_DUP=$(jq '[ .[] | select(._gecerli and ._dup) ] | length' <<<"$KARAR")
E_ANAHTAR=$(jq '[ .[] | select(._gecerli and (._dup|not) and ._dupkey) ] | length' <<<"$KARAR")
N=$(jq 'length' <<<"$GECERLI")
CELL="${CELL_ID:-s01}"

# ── append: her geçerli-aday'a b#### id ver, havuz-şemasında yaz ──
YENI_IDLER=()
i=0
while [[ $i -lt $N ]]; do
  SON=$((SON+1))
  ID="$(printf 'b%04d' "$SON")"
  YENI_IDLER+=("$ID")
  jq -c -n --arg id "$ID" --arg tarih "$TARIH" --arg kay "$KAYNAK" --arg cell "$CELL" \
    --argjson c "$(jq -c ".[$i]" <<<"$GECERLI")" \
    '{id:$id, kaynak:$kay, tip:$c.tip, baslik:$c.baslik, detay:$c.detay,
      kanit:$c.kanit, tarih:$tarih, durum:"ham", kart:null, cell:$cell, dedup_key:$c._key}' >> "$HAVUZ"
  i=$((i+1))
done

# özet
idler_json="$([[ ${#YENI_IDLER[@]} -gt 0 ]] && printf '%s\n' "${YENI_IDLER[@]}" | jq -R . | jq -cs . || echo '[]')"
{
  echo "── KAŞİF havuz-ekle özeti ──"
  echo "   eklenen        : $N   ${idler_json}"
  echo "   atlanan (dup)  : $E_DUP  (havuzda zaten benzer başlık)"
  echo "   atlanan (anahtar): $E_ANAHTAR  (deterministik çift-anahtar; ham/aday kayıtla birebir)"
  echo "   atlanan (şema) : $E_GECERSIZ  (başlık/kanıt boş — fail-closed)"
} >&2
jq -c -n --argjson e "$N" --argjson d "$E_DUP" --argjson a "$E_ANAHTAR" --argjson g "$E_GECERSIZ" --argjson idler "$idler_json" \
  '{eklenen:$e, atlanan_dup:$d, atlanan_anahtar:$a, atlanan_gecersiz:$g, yeni_idler:$idler}'
exit 0
