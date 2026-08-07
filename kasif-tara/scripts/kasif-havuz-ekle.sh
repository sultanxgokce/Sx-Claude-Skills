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
# ÇIKTI:  havuza append + stdout özet {eklenen, atlanan_dup, atlanan_anahtar, atlanan_gecersiz,
#         atlanan_alan, yeni_idler}
# ŞEMA-DIŞI ALAN: şema KAPALI — tanımadığı alan kayda girmez. Ama SESSİZ düşürmez: adı
#   `atlanan_alan`da ve seyir satırında görünür, stderr uyarır. Kayıp meşru olabilir, GÖRÜNMEZ olamaz.
#   Yalnız alan ADI taşınır, DEĞERİ asla (havuz/seyir META kanalı). Kaynak: NÂZIR/s13 kart-92.
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

# ── ROL-KAPISI (ADR-025 K4: bulan ≠ eleyen) ─────────────────────────────────────────────────
# Alt-ajan hangi rolle gönderildiyse `LAYIHA_ROL`'ü taşır (el-kitabındaki dispatch kalıbı koyar).
# Tek bir alt-ajan İKİ rolü birden koşamaz: KAŞİF şapkasıyla heyecanla bulduğunu, beş dakika sonra
# MUCİT şapkasıyla tarafsız yargılayamaz. Değişken BOŞSA kısıt yok (müdürün/Sultan'ın elle koşusu +
# eski çağrılar bozulmaz) — bu bilinçli bir sınırdır: kapı deseni UYGULANDIĞINDA mekanikleştirir,
# deseni hiç kullanmayan bir ajanı yakalayamaz (dürüst sınır, aşağıdaki "Sınırlar"da da yazılı).
if [ -n "${LAYIHA_ROL:-}" ] && [ "${LAYIHA_ROL}" != "kasif" ]; then
  echo "HATA: rol-kapısı — bu motor KAŞİF'in yazma-yüzeyi, alt-ajanın rolü ise '${LAYIHA_ROL}'." >&2
  echo "      ADR-025 K4 (bulan ≠ eleyen): tarama için AYRI bir alt-ajan gönder (LAYIHA_ROL=kasif)." >&2
  exit 2
fi

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

# ── L24 F6 · KAŞİF HAFIZASI (yazma ucu) ─────────────────────────────────────────────────────
# NİÇİN: KAŞİF bugüne dek her turda sıfırdan başlıyordu — dün nereye baktığını bilmiyor, boşa
#   çıkan kaynağa tekrar gidiyor, "aynı şeyi üç ayrı yerde duydum" sinyalini dedup'ta SİLİYORDU.
#   Ve en kötüsü: tur kaydı olmadığı için "taradı bir şey bulamadı" ile "hiç taramadı" AYIRT
#   EDİLEMİYORDU (ölçüldü: son bulgu 2026-07-20, 7 gün sessizlik — hangisi olduğu bilinmiyor).
#
# ÜÇ DEFTER (hepsi repo-yerel, git-izli, hat-yolu üzerinden):
#   kaynaklar.jsonl — hangi kaynağa kaç kez gidildi, verimi ne oldu (bir daha boşa gitme)
#   seyir.jsonl     — HER tur bir satır, bulgu getirmese bile (ölçüm boşluğunu kapatan asıl parça)
#   tekrar.jsonl    — dedup'ta düşen aday sessizce yok olmaz; kaç kez, hangi kaynaklardan geldi
#
# FAIL-SOFT: hafıza YAZILAMAZSA ana iş (havuza ekleme) BOZULMAZ — hafıza ikincildir, kapı değildir.
#   Gerekçe: KAŞİF'in tek işi malzeme taşımak; defteri tutulamadı diye malzeme kaybolmamalı.
# TEST-DİKİŞİ: KASIF_KAYNAKLAR/KASIF_SEYIR/KASIF_TEKRAR — üretimde ayarlanmaz, hermetik testte izole eder.
# HERMETİK TEST KALKANI: KASIF_TEST=1 iken hafıza yolu KENDİLİĞİNDEN türetilmez — testin gerçek
#   deftere yazması ancak yolu AÇIKÇA vermekle olur. Gerekçe firsthand: F3'te mutasyon-testi tam da
#   bu kalkan olmadığı için ortak dizine iki kez sızdı ve elle temizlik gerekti.
_hafiza_dir=""
if [ -n "${KASIF_HAFIZA_DIR:-}" ]; then _hafiza_dir="$KASIF_HAFIZA_DIR"
elif [ "${KASIF_TEST:-0}" != "1" ]; then _hafiza_dir="$(hat_yolu kasif-dir 2>/dev/null || true)"; fi
KAYNAKLAR="${KASIF_KAYNAKLAR:-${_hafiza_dir:+$_hafiza_dir/kaynaklar.jsonl}}"
SEYIR="${KASIF_SEYIR:-${_hafiza_dir:+$_hafiza_dir/seyir.jsonl}}"
TEKRAR="${KASIF_TEKRAR:-${_hafiza_dir:+$_hafiza_dir/tekrar.jsonl}}"

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
# 🔴 `exec 9>… 2>/dev/null` YAZMA: exec komutsuz kullanılınca yönlendirmelerin HEPSİ kalıcı olur →
# `2>/dev/null` betiğin geri kalanında stderr'i susturur ve aşağıdaki insan-okur özet HİÇ görünmez.
# (Ölçüldü 2026-08-07: özet blok yazıldığı günden beri hiç basılmamış.) Susturma yalnız exec'in
# KENDİ hatasına ait olmalı → grupla sınırla.
{ exec 9>"$HAVUZ.lock"; } 2>/dev/null || true
flock 9 2>/dev/null || true

# Bir sonraki b#### id (havuzdaki en büyük b-numarasından +1)
SON="$(jq -rs 'map(.id // empty | select(test("^b[0-9]+$")) | ltrimstr("b") | tonumber) | (max // 0)' "$HAVUZ" 2>/dev/null || echo 0)"
[[ "$SON" =~ ^[0-9]+$ ]] || SON=0

# ── L24 F6 · TUR KİMLİĞİ: t<YYYYMMDD>-<n> ───────────────────────────────────────────────────
# Numara SEYİR defterinden türetilir, havuzdan DEĞİL — kasıtlı: bulgu getirmeyen tur da sayılmalı.
# (Havuzdan türetseydik boş tur hiç numara almaz, "hiç taramadı" ile aynı görünürdü = B8'in kendisi.)
GUN="${TARIH//-/}"
_TUR_N=1
if [ -n "$SEYIR" ] && [ -r "$SEYIR" ]; then
  _n="$(jq -rs --arg g "$GUN" '[ .[] | (.tur // "") | select(startswith("t"+$g+"-")) | ltrimstr("t"+$g+"-") | tonumber? ] | (max // 0)' "$SEYIR" 2>/dev/null || echo 0)"
  [[ "$_n" =~ ^[0-9]+$ ]] && _TUR_N=$((_n+1))
fi
TUR="${KASIF_TUR:-t${GUN}-${_TUR_N}}"

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
      _dupkey: ($blokan | index($key) != null),
      # şema-dışı alanlar: DÜŞÜRÜLÜR ama SESSİZ DEĞİL (NÂZIR/s13 kart-92).
      # Yalnız alan ADI toplanır, DEĞERİ asla — havuz/seyir META kanalıdır.
      _atlanan_alan: (($c | keys) - ["baslik","detay","kanit","tip"]) }
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
# şema-dışı alan adları (tüm adaylar boyunca birleşik, tekil, sıralı) — kayıp GÖRÜNÜR olsun diye.
# "Düşürmek meşru, sessizce düşürmek değil": ad basılır, değer basılmaz.
ATLANAN_ALAN="$(jq -c '[ .[] | ._atlanan_alan[]? ] | unique' <<<"$KARAR" 2>/dev/null || echo '[]')"
E_ALAN=$(jq 'length' <<<"$ATLANAN_ALAN")
CELL="${CELL_ID:-s01}"

# ── append: her geçerli-aday'a b#### id ver, havuz-şemasında yaz ──
YENI_IDLER=()
i=0
while [[ $i -lt $N ]]; do
  SON=$((SON+1))
  ID="$(printf 'b%04d' "$SON")"
  YENI_IDLER+=("$ID")
  jq -c -n --arg id "$ID" --arg tarih "$TARIH" --arg kay "$KAYNAK" --arg cell "$CELL" --arg tur "$TUR" \
    --argjson c "$(jq -c ".[$i]" <<<"$GECERLI")" \
    '{id:$id, kaynak:$kay, tip:$c.tip, baslik:$c.baslik, detay:$c.detay,
      kanit:$c.kanit, tarih:$tarih, durum:"ham", kart:null, cell:$cell, dedup_key:$c._key,
      tur:$tur}' >> "$HAVUZ"
  i=$((i+1))
done

# özet
idler_json="$([[ ${#YENI_IDLER[@]} -gt 0 ]] && printf '%s\n' "${YENI_IDLER[@]}" | jq -R . | jq -cs . || echo '[]')"

# ── L24 F6 · HAFIZAYI YAZ ───────────────────────────────────────────────────────────────────
# FAIL-SOFT sözleşmesi: bu blok ne yaparsa yapsın, yukarıdaki havuz-yazımını GERİ ALMAZ ve
# script'in çıkış kodunu DEĞİŞTİRMEZ. Defter tutulamadı diye taşınan malzeme kaybolmamalı.
KAYNAK_SAYISI=0
_hafiza_yaz() {
  local dizin
  # Yol yoksa (git-siz dizin ya da env verilmemiş) sessizce atla — İ1 gereği asla tahmini yola yazma.
  [ -n "${KAYNAKLAR:-}" ] || [ -n "${SEYIR:-}" ] || [ -n "${TEKRAR:-}" ] || return 0
  for dizin in "$(dirname -- "${KAYNAKLAR:-/dev/null}")" "$(dirname -- "${SEYIR:-/dev/null}")" "$(dirname -- "${TEKRAR:-/dev/null}")"; do
    [ "$dizin" = "/dev" ] || mkdir -p -- "$dizin" 2>/dev/null || true
  done

  # ── 1) KAYNAK KÜTÜPHANESİ: hangi adrese kaç kez gidildi, ne getirdi ──
  # Amaç: "buraya bakmıştım, boş çıkmıştı" bilgisini kalıcı kılmak. URL kanıt alanından çıkarılır
  # (kanıt zaten ZORUNLU ve çoğunlukla kaynak-URL'dir); URL taşımayan alıntı-kanıtlar atlanır.
  if [ -n "${KAYNAKLAR:-}" ]; then
    local yeni mevcut birlesik
    yeni="$(jq -c --argjson idler "$idler_json" '
      [ to_entries[] | .key as $i | .value |
        ((.kanit // "") | capture("(?<u>https?://[^\\s\")<>]+)"; "g") | .u) as $u |
        { url: $u, bulgu: ($idler[$i] // null) } ]' <<<"$GECERLI" 2>/dev/null || echo '[]')"
    mevcut="[]"
    [ -r "$KAYNAKLAR" ] && mevcut="$(jq -cs '.' "$KAYNAKLAR" 2>/dev/null || echo '[]')"
    birlesik="$(jq -c -n --argjson eski "$mevcut" --argjson yeni "$yeni" \
      --arg tur "$TUR" --arg tarih "$TARIH" '
      def urlkey: sub("^https?://";"") | sub("[?#].*$";"") | sub("/+$";"") | ascii_downcase;
      def urlhost: sub("^https?://";"") | split("/")[0] | ascii_downcase;
      ($yeni | map(. + {k: (.url | urlkey), h: (.url | urlhost)}) | group_by(.k)) as $gruplu |
      ($eski | map({key: (.url_key // ""), value: .}) | from_entries) as $idx |
      ( $gruplu | map(
          .[0].k as $k | .[0].url as $url | .[0].h as $host |
          ([ .[] | .bulgu | select(. != null) ]) as $yeni_idler |
          ($idx[$k] // null) as $e |
          if $e == null then
            { url_key:$k, url:$url, host:$host, ilk:$tarih, son:$tarih, ziyaret:1,
              turlar:[$tur], bulgu_idler:$yeni_idler, verim:($yeni_idler|length), durum:"aktif" }
          else
            $e + { son:$tarih, ziyaret:(($e.ziyaret // 0) + 1),
                   turlar:(((($e.turlar // []) + [$tur])) | unique),
                   bulgu_idler:((($e.bulgu_idler // []) + $yeni_idler) | unique),
                   verim:(((($e.bulgu_idler // []) + $yeni_idler) | unique) | length) }
          end ) ) as $guncel |
      ($guncel | map(.url_key)) as $dokunulan |
      ( ($eski | map(select((.url_key // "") as $k | ($dokunulan | index($k)) == null))) + $guncel )
    ' 2>/dev/null || echo '')"
    if [ -n "$birlesik" ]; then
      KAYNAK_SAYISI="$(jq 'length' <<<"$birlesik" 2>/dev/null || echo 0)"
      local tmp; tmp="$(mktemp "${KAYNAKLAR}.XXXXXX" 2>/dev/null)" || tmp=""
      if [ -n "$tmp" ]; then
        jq -c '.[]' <<<"$birlesik" > "$tmp" 2>/dev/null && mv -f -- "$tmp" "$KAYNAKLAR" || rm -f -- "$tmp"
      fi
    fi
  fi

  # ── 2) TEKRAR SİNYALİ: dedup'ta düşen aday sessizce yok olmasın ──
  # Bugüne dek "aynı şeyi üç ayrı yerde duydum" bilgisi SİLİNİYORDU. Oysa tekrar bir GÜRÜLTÜ
  # olabileceği gibi bir GÜÇLENME sinyali de olabilir — kararı Sultan/MUCİT versin diye kaydediyoruz.
  if [ -n "${TEKRAR:-}" ]; then
    local dusen mevcutT birlesikT
    dusen="$(jq -c '[ .[] | select(._gecerli and (._dup or ._dupkey)) |
              { k: ._key, baslik: .baslik, kanit: (.kanit // "") } ]' <<<"$KARAR" 2>/dev/null || echo '[]')"
    if [ "$(jq 'length' <<<"$dusen" 2>/dev/null || echo 0)" != "0" ]; then
      mevcutT="[]"
      [ -r "$TEKRAR" ] && mevcutT="$(jq -cs '.' "$TEKRAR" 2>/dev/null || echo '[]')"
      birlesikT="$(jq -c -n --argjson eski "$mevcutT" --argjson yeni "$dusen" \
        --arg tur "$TUR" --arg tarih "$TARIH" '
        def urlhost: (capture("https?://(?<h>[^/\\s\")<>]+)") // {h:""}) | .h | ascii_downcase;
        ($yeni | group_by(.k)) as $g |
        ($eski | map({key: (.dedup_key // ""), value: .}) | from_entries) as $idx |
        ( $g | map(
            .[0].k as $k | .[0].baslik as $b |
            ([ .[] | .kanit | urlhost | select(. != "") ]) as $hostlar |
            ($idx[$k] // null) as $e |
            if $e == null then
              { dedup_key:$k, baslik:$b, kez:(.|length), ilk:$tarih, son:$tarih,
                hostlar:($hostlar|unique), turlar:[$tur] }
            else
              $e + { kez:(($e.kez // 0) + (.|length)), son:$tarih,
                     hostlar:((($e.hostlar // []) + $hostlar) | unique),
                     turlar:((($e.turlar // []) + [$tur]) | unique) }
            end ) ) as $guncel |
        ($guncel | map(.dedup_key)) as $dokunulan |
        ( ($eski | map(select((.dedup_key // "") as $k | ($dokunulan | index($k)) == null))) + $guncel )
      ' 2>/dev/null || echo '')"
      if [ -n "$birlesikT" ]; then
        local tmpT; tmpT="$(mktemp "${TEKRAR}.XXXXXX" 2>/dev/null)" || tmpT=""
        if [ -n "$tmpT" ]; then
          jq -c '.[]' <<<"$birlesikT" > "$tmpT" 2>/dev/null && mv -f -- "$tmpT" "$TEKRAR" || rm -f -- "$tmpT"
        fi
      fi
    fi
  fi

  # ── 3) SEYİR (tur günlüğü): HER koşuda bir satır — bulgu getirmese de ──
  # B8'in ölçüm boşluğunu kapatan asıl parça: bundan sonra "taradı bulamadı" ile "hiç taramadı"
  # ayırt edilebilir, çünkü ikincisinde bu satır HİÇ oluşmaz.
  if [ -n "${SEYIR:-}" ]; then
    jq -c -n --arg tur "$TUR" --arg tarih "$TARIH" --arg kay "$KAYNAK" --arg cell "$CELL" \
      --argjson aday "$(jq 'length' <<<"$KARAR" 2>/dev/null || echo 0)" \
      --argjson eklenen "$N" --argjson dup "$E_DUP" --argjson anahtar "$E_ANAHTAR" \
      --argjson sema "$E_GECERSIZ" --argjson idler "$idler_json" \
      --argjson alan "${ATLANAN_ALAN:-[]}" \
      --argjson kaynak_sayisi "${KAYNAK_SAYISI:-0}" \
      '{v:1, tur:$tur, tarih:$tarih, kaynak:$kay, cell:$cell,
        aday:$aday, eklenen:$eklenen,
        atlanan:{dup:$dup, anahtar:$anahtar, sema:$sema, alan:$alan},
        yeni_idler:$idler, kaynak_kutuphanesi:$kaynak_sayisi}' >> "$SEYIR" 2>/dev/null || true
  fi
  return 0
}
_hafiza_yaz 2>/dev/null || true
{
  echo "── KAŞİF havuz-ekle özeti ──"
  echo "   eklenen        : $N   ${idler_json}"
  echo "   atlanan (dup)  : $E_DUP  (havuzda zaten benzer başlık)"
  echo "   atlanan (anahtar): $E_ANAHTAR  (deterministik çift-anahtar; ham/aday kayıtla birebir)"
  echo "   atlanan (şema) : $E_GECERSIZ  (başlık/kanıt boş — fail-closed)"
  if [ "$E_ALAN" != "0" ]; then
    echo "   ⚠️ atlanan ALAN : $E_ALAN  $ATLANAN_ALAN"
    echo "      ↳ bu adlar şemada yok, kayda GİRMEDİ. Bilerek yapıyorsan sorun yok;"
    echo "        bilmiyorsan gönderen taraf bilgi kaybediyor demektir."
  fi
  echo "   tur            : $TUR   ·   kaynak-kütüphanesi: ${KAYNAK_SAYISI:-0} adres"
} >&2
jq -c -n --argjson e "$N" --argjson d "$E_DUP" --argjson a "$E_ANAHTAR" --argjson g "$E_GECERSIZ" \
  --argjson alan "$ATLANAN_ALAN" --argjson idler "$idler_json" \
  '{eklenen:$e, atlanan_dup:$d, atlanan_anahtar:$a, atlanan_gecersiz:$g,
    atlanan_alan:$alan, yeni_idler:$idler}'
exit 0
