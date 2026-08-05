#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# kapimda.sh — Sultan'ı bekleyen işlerin YAZICISI + LİNT'i (L38-F3/F4 · L39-F1 · MABEYN H2)
#
# NİÇİN VAR (ölçülmüş): kart FORMATI ve ÇİZİCİSİ 2026-07-31'de kuruldu (kapimda.md + `basla`
#   bloğu) ama YAZICI hiç yazılmadı → kartlar elle yazılıyordu, lint yoktu, besleyici yoktu.
#   Sonuç (2026-08-04 canlı vaka): Sultan "onay verdim" dedi, sistem 0 onay gördü; kartların
#   tek yüzü Telegram'daki 2.671 mesajın içindeydi ve Sultan onları BULAMADI. Kartın makine
#   tarafından, kurallara UYULARAK yazılması bu derdin ilk yarısıdır (ikinci yarısı besleyici).
#
# 🔴 LİNT FAIL-CLOSED (L38 §5): kart ancak SEKİZ kapıdan geçerse yazılır —
#   1 dört alan dolu · 2 `Niçin sen` boş→RED (ajanın yapabileceği iş kart olamaz) · 3 tavan-3 ·
#   4 Kısa Ad tekil · 5 jargon/İ1 kalkanı (dosya-yolu·kod-terimi·komut → RED) · 6 tek-eylem ·
#   7 sır-desen · 8 uzunluk. Kapı düşerse kart YAZILMAZ ve sebebi basılır (sessiz kırpma yok).
#
# DEĞİŞMEZLER
#   • A06: bu araç Sultan'ın CEVABINI üretmez/yazmaz. `bitti` yalnız kartın GÖRÜNÜRLÜĞÜNÜ kapatır
#     (kart bir görünürlük yüzeyidir; onay kaydı karar-kartlarında yaşar). Gerekçe ZORUNLU.
#   • Ortak dosya (16 kutu aynı `/config/.claude`) → her yazım flock'lu + atomik (os.replace deseni).
#   • Çizici sözleşmesi KORUNUR: açık kart satırı `^🚦 SENDE · <Kısa Ad>` (basla `_kapimda_blogu`).
#   • KAYNAK UYDURULMAZ (L48/G1): kartın `oda:` damgası türetilemezse "bilinmiyor" yazılır;
#     sahte bir kutu adı basmak alanı ölçülemez kılar (818/818-s01 dersi). Devir kaynağı EZMEZ.
#
# KULLANIM
#   kapimda ac "<Kısa Ad>" --ne "…" --nicin-sen "…" --yapilmazsa "…" --bitince "…" \
#              [--ozet "2-4 cümle gövde"] [--yas "3 gündür bekliyor"] [--engel "ne duruyor"] [--kuru]
#   kapimda bitti "<Kısa Ad>" --gerekce "…" [--federe-tamam <tetik-id>]
#        → kartı kapat (görünürlük; onay DEĞİL). --federe-tamam verilirse SON-HALKA kapısı:
#          bloklu ajan tetiği 'tamam' yapmadıysa kart KAPANMAZ (RC=4) — "Sultan yaptı" yetmez.
#   kapimda devret "<Kısa Ad>" --sahip <AJAN|SULTAN> --gerekce "…" [--sultan-onayi "<Sultan'ın cümlesi>"]
#        → kartın SAHİBİNİ değiştirir (kart taşınmaz — dosya 14 kutuda ortak). Ajan-sahipli kart
#          `🎯 <AJAN> · <ad>` damgası alır ve Sultan'ın tavan-3 sayımına GİRMEZ.
#          SULTAN→AJAN geçişi Sultan-onayı ister (RC=5). 3. devirde kart SULTAN'a döner (⚠️ TIKANDI).
#   kapimda liste                                   # açık kartlar + kaynak odaları (salt-okur)
#        → her satır "• <Kısa Ad>  (oda: <kutu>)". SALT-BİLGİ: kaynak GÖSTERİLİR, liste ona
#          göre SÜZÜLMEZ (süzme Sultan'ın gördüğü çıktıyı değiştirir → ayrı faz, ayrı karar).
#   kapimda lint                                    # dosya-geneli denetim (RC≠0 = bulgu)
#   kapimda adim ekle "<Kısa Ad>" --yapilacak "…" --nerede "…" --bitince "…"
#   kapimda adim goster "<Kısa Ad>"                 # SIRADAKİ tek adımı kopyalanabilir bas
#   kapimda adim ilerle "<Kısa Ad>"                 # Sultan cevapladıktan SONRA çağrılır
#   kapimda adim durum "<Kısa Ad>"
# ÇIKIŞ: 0 tamam · 1 lint-RED / bulgu · 2 kullanım/ortam · 4 son-halka eksik (olur gelmedi)
#        5 = Sultan'ın kapısından izinsiz iş çıkarma denemesi (A06 kapısı)
# ═══════════════════════════════════════════════════════════════════════════
set -uo pipefail

DOSYA="${KAPIMDA_DOSYA:-$HOME/.claude/kapimda.md}"
ADIM_DIZIN="${KAPIMDA_ADIM_DIZIN:-$HOME/.claude/kapimda-adim}"
TAVAN="${KAPIMDA_TAVAN:-3}"
KILIT="${KAPIMDA_KILIT:-$DOSYA.lock}"

_hata() { printf 'HATA: %s\n' "$1" >&2; }
_bugun() { date +%F; }

# ── KART KAYNAĞI: hangi kutudan açıldı (L48 · G1 = L47'nin F3'ü · 2026-08-05) ──
# NİÇİN VAR (ölçülmüş): kapımda dosyası 14 kutuda AYNI inode; kartta "bunu kim açtı" alanı
#   HİÇ yoktu. Sonuç (HUZUR'un federe raporu 0f17aa5d): her kutu ötekilerin kartını KENDİ
#   kapısı sanıyor — "kapında 3 iş" dendi, üçü de başka odanın işiydi. Sultan aynı derdi
#   kendi cümlesiyle söyledi: *"bir container'ın işi diğerine gidiyor."*
#
# 🔴 DOĞUŞ ANINDA DAMGALANIR. Kimlik sonradan geri kazanılamaz: kartı yazan an, kutunun
#   hangisi olduğunun bilindiği TEK andır. Zincirin sonraki halkaları (dosya · çizici ·
#   Telegram) kutuyu zaten bilmiyor.
#
# KAYNAK SEÇİMİ — niçin DEFAULT_WORKSPACE:
#   • hostname → İŞE YARAMAZ: docker rastgele hex üretiyor (ör. 3a0d63c53b08).
#   • TUĞRA kutular.json → merkez deposunda; 8 İZOLE kutu o depoyu GÖREMEZ.
#   • DEFAULT_WORKSPACE → İSKÂN her kutuyu bununla doğuruyor (iskan.sh:505), yani
#     izole kutuda da vardır ve depoya bağlı değildir. TEK taşınabilir kaynak budur.
#   ⚠️ Buraya kutu TABLOSU KOPYALANMAZ (TUĞRA'nın "ikinci gerçek yazmak YASAK" kuralı) —
#     tablo değil TÜREV kullanılır: yolun son parçası.
#
# 🔴 UYDURMA YOK: türetilemezse "bilinmiyor" yazılır. Sahte bir kutu adı (ör. hepsine "s01")
#   yanlış-yönlendirmeyi ÇÖZMEZ, ölçülemez hâle getirir — 818 karar kaydının 818'inin "s01"
#   olması tam bu yüzden alanı fiilen öldürmüştü.
_bu_oda() {
  local ws ad
  if [ -n "${KAPIMDA_ODA:-}" ]; then printf '%s' "$KAPIMDA_ODA"; return 0; fi
  ws="${DEFAULT_WORKSPACE:-}"
  ws="${ws%/}"
  [ -n "$ws" ] || { printf 'bilinmiyor'; return 0; }
  # merkez kutunun çalışma alanı proje KÖKÜ'dür (alt-klasör değil) → adı "projects" olurdu
  if [ "$ws" = "/config/projects" ]; then printf 'nexus'; return 0; fi
  ad="${ws##*/}"
  # makine alanı: ASCII küçük harf + rakam + tire (Türkçe damga insan-yüzünde, burada değil)
  ad="$(printf '%s' "$ad" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' | sed 's/-\{1,\}/-/g; s/^-//; s/-$//')"
  [ -n "$ad" ] || ad="bilinmiyor"
  printf '%s' "$ad"
}

_kart_oda() { # $1=ad → kartın oda damgası (yoksa "" — eski kartlar damgasızdır)
  awk -v ad="$1" '
    $0 ~ ("^(🚦 SENDE|🎯 [^·]+|⚠️ TIKANDI) · " ad "$") {icinde=1; next}
    icinde && /^oda: / {sub(/^oda: /,""); print; exit}
    icinde && /^```$/ {exit}' "$DOSYA" 2>/dev/null
}

# ── açık kart adları (çizici ile AYNI sözleşme: satır-başı damga) ──
_acik_adlar() { grep -oP '^🚦 SENDE · \K.*' "$DOSYA" 2>/dev/null || true; }
_acik_sayi()  { _acik_adlar | grep -c . || true; }

# ── LİNT KAPILARI ────────────────────────────────────────────────────────────
# Jargon/İ1 kalkanı: Sultan-yüzü metinde dosya-yolu · uzantı · komut · kod-terimi ARANMAZ.
# (Kartın amacı "ne yapman gerekiyor"u insan diliyle söylemek; yol/komut adım-kartına aittir
#  ve orada bile tek-satır kopyalanabilir olur.)
_jargon_var() {
  printf '%s' "$1" | grep -qE '(^|[[:space:]])/[A-Za-z0-9_.-]+/|\.(sh|md|json|ts|tsx|py|ya?ml|env)([[:space:]]|$)|`|_agents|scripts/|\bgit \b|\bbash \b|\bnpm \b|\bcurl \b|\bdocker \b|\bsudo \b'
}
_sir_var() {
  printf '%s' "$1" | grep -qE 'sk-[A-Za-z0-9]{20}|ghp_[A-Za-z0-9]{30}|AKIA[A-Z0-9]{16}|BEGIN (RSA |EC )?PRIVATE KEY|xox[bp]-'
}
# Tek-eylem: "Ne yapman gerekiyor" iki ayrı iş taşıyorsa adım-kartına bölünmeli (L39).
_cok_eylem() {
  printf '%s' "$1" | grep -qE '(;|,[[:space:]]*(sonra|ard[ıi]ndan)|[[:space:]]sonra[[:space:]].*[[:space:]]ve[[:space:]])'
}

_lint_kart() { # $1=ad $2=ne $3=nicin $4=yapilmazsa $5=bitince $6=ozet ; RC=1 → RED
  local ad="$1" ne="$2" nicin="$3" yapilmazsa="$4" bitince="$5" ozet="$6" red=0
  local alan
  # K1 — dört alan dolu
  for alan in "ne:$ne" "nicin-sen:$nicin" "yapilmazsa:$yapilmazsa" "bitince:$bitince"; do
    [ -n "${alan#*:}" ] || { _hata "K1 zorunlu alan boş: --${alan%%:*}"; red=1; }
  done
  # K2 — `Niçin sen` gerçekten Sultan'ı işaret etmeli (boş DEĞİL yeter değil; kısa-boş da RED)
  if [ -n "$nicin" ] && [ "${#nicin}" -lt 12 ]; then
    _hata "K2 'Niçin sen' bir cümle olmalı (ajanın yapabileceği iş kart olamaz): '$nicin'"; red=1
  fi
  # K3 — tavan
  local n; n="$(_acik_sayi)"
  if [ "$n" -ge "$TAVAN" ]; then
    _hata "K3 tavan dolu: $n açık kart (tavan $TAVAN). Önce birini kapat — sıraya sessizce eklenmez."; red=1
  fi
  # K4 — ad tekil
  if _acik_adlar | grep -qxF "$ad"; then _hata "K4 bu ad zaten açık: '$ad'"; red=1; fi
  [ -n "$ad" ] || { _hata "K4 Kısa Ad zorunlu"; red=1; }
  # K5 — jargon/İ1
  local metin="$ad
$ne
$nicin
$yapilmazsa
$bitince
$ozet"
  if _jargon_var "$metin"; then
    _hata "K5 jargon/yol/komut yakalandı — kart Sultan-dilinde olmalı (yol ve komut adım-kartına ait)"; red=1
  fi
  # K6 — tek-eylem
  if _cok_eylem "$ne"; then
    _hata "K6 'Ne yapman gerekiyor' birden çok iş taşıyor — adım-kartına böl (kapimda adim ekle)"; red=1
  fi
  # K7 — sır
  if _sir_var "$metin"; then _hata "K7 sır-deseni yakalandı — karta sır yazılamaz (değer basılmadı)"; red=1; fi
  # K8 — uzunluk
  [ "${#ozet}" -le 600 ] || { _hata "K8 gövde çok uzun (${#ozet} > 600)"; red=1; }
  for alan in "$ne" "$nicin" "$yapilmazsa" "$bitince"; do
    [ "${#alan}" -le 240 ] || { _hata "K8 alan çok uzun (${#alan} > 240)"; red=1; }
  done
  return $red
}

# ── kart yazımı (flock + atomik) ─────────────────────────────────────────────
_kart_yaz() { # $1..$6 kart alanları
  local ad="$1" ne="$2" nicin="$3" yapilmazsa="$4" bitince="$5" ozet="$6" yas="$7" engel="$8" oda="${9:-bilinmiyor}"
  local blok tmp
  # `oda:` başlığın HEMEN ALTINA girer (L47 §7.1 şeması) — çizici sözleşmesi `^🚦 SENDE · `
  # satır-başı damgasına bakar, altındaki satırlar onu BOZMAZ (geri-alınabilirliğin anahtarı).
  blok="$(printf '```\n🚦 SENDE · %s\noda: %s\n%s%s\n\n%s\n\nNe yapman gerekiyor: %s\nNiçin sen: %s\nYapılmazsa: %s\nBitince: %s\n```\n' \
    "$ad" "$oda" "${yas:-bugün açıldı}" "${engel:+ · $engel}" "${ozet:-$ne}" "$ne" "$nicin" "$yapilmazsa" "$bitince")"
  tmp="$(mktemp)"
  # ÇAPA: "+N kart daha bekliyor." satırı — kart onun ÜSTÜNE girer (dosyanın insan-yazımı
  # başlık/kural bölümleri bozulmaz). Çapa yoksa dosya sonuna eklenir ve çapa oluşturulur.
  if grep -qE '^\*\*\+[0-9]+ kart daha bekliyor\.' "$DOSYA" 2>/dev/null; then
    awk -v blok="$blok" '
      /^\*\*\+[0-9]+ kart daha bekliyor\./ && !yazildi { print blok; yazildi=1 }
      { print }
    ' "$DOSYA" > "$tmp"
  else
    cat "$DOSYA" > "$tmp" 2>/dev/null || true
    printf '\n%s\n**+0 kart daha bekliyor.** (Tavan %s; sıradakiler buraya tek satır olarak düşer.)\n' "$blok" "$TAVAN" >> "$tmp"
  fi
  mv "$tmp" "$DOSYA"
}

# ── KART DEVRİ (L47 · F5 · 2026-08-04) ─────────────────────────────────────
# NİÇİN: Sultan'ın örneği — *"SİNAN container'ında Sultan kapısında biriken işlerin bazıları
#   SERDAR gerektirebilir; o zaman SİNAN o kartları SERDAR etiketli atabilir, SERDAR'ın
#   kapısına şutlayabilir."* Bugüne dek kartta "bu kimin" alanı YOKTU.
# 🔴 TAŞIMA YOK: kapımda dosyası 14 kutuda AYNI inode. Devir yalnız BİR SATIR değiştirir;
#   kart hiçbir yere gitmez. Federe/kurye zincirine bağımlılık yok (o zincir yarım: oda-zil
#   12 turdur zil=0 — zile bel bağlamak kartı kaybettirirdi).
# DAMGA: sahibi ajan olan kart `🎯 <AJAN> · <ad>` olur → Sultan'ın kapısı (`🚦 SENDE · `)
#   yalnız KENDİ işlerini sayar; tavan-3 de yalnız Sultan-kartlarına uygulanır. Çizici
#   sözleşmesi bozulmaz (grep aynen çalışır, ajan-kartları o grep'e düşmez).
_kart_sahibi() { # $1=ad → SULTAN | <AJAN> | "" (kart yok)
  grep -m1 -E "^(🚦 SENDE|🎯 [^·]+) · $(printf '%s' "$1" | sed 's/[][\.*^$/]/\\&/g')\$" "$DOSYA" 2>/dev/null \
    | sed -E 's/^🚦 SENDE · .*/SULTAN/; s/^🎯 ([^·]+) · .*/\1/' | sed 's/[[:space:]]*$//'
}
_devir_sayaci() { # $1=ad → mevcut devir sayısı
  local n; n="$(awk -v ad="$1" '
    $0 ~ ("^(🚦 SENDE|🎯 [^·]+) · " ad "$") {icinde=1; next}
    icinde && /^devir: [0-9]+$/ {sub(/^devir: /,""); print; exit}
    icinde && /^```$/ {exit}' "$DOSYA" 2>/dev/null)"
  printf '%s' "${n:-0}"
}
_kart_devret() { # $1=ad $2=yeni-sahip $3=gerekce $4=eski-sahip $5=yeni-devir-sayisi $6=tikandi(0/1) $7=oda(ops)
  local ad="$1" yeni="$2" ger="$3" eski="$4" say="$5" tik="$6" oda="${7:-}" tmp; tmp="$(mktemp)"
  # 🔴 `oda:` KART DEVRİNDE KORUNUR, YENİDEN YAZILMAZ: alan "kartı KİM AÇTI" demektir,
  #   "kart ŞU AN kimde" demek DEĞİL (o `sahip` damgasıdır). Devreden kutu, kartı açan kutu
  #   olmak zorunda değil; buraya kendi adını yazmak kaynağı SİLER. Damgasız eski kartlara
  #   da köken UYDURULMAZ — damgasız kalırlar.
  awk -v ad="$ad" -v yeni="$yeni" -v ger="$ger" -v eski="$eski" -v say="$say" -v tik="$tik" \
      -v oda="$oda" -v gun="$(_bugun)" '
    $0 ~ ("^(🚦 SENDE|🎯 [^·]+|⚠️ TIKANDI) · " ad "$") {
      if (tik == "1")            print "⚠️ TIKANDI · " ad
      else if (yeni == "SULTAN") print "🚦 SENDE · " ad
      else                       print "🎯 " yeni " · " ad
      if (oda != "") print "oda: " oda
      print "devir: " say
      print "↳ devir " gun ": " eski " → " (tik=="1" ? "SULTAN (üç kez el değiştirdi — hakem Sultan)" : yeni) " · gerekçe: " ger
      bulundu=1; next }
    /^oda: / && bulundu==1 && !oatlandi { oatlandi=1; next }
    /^devir: [0-9]+$/ && bulundu==1 && !atlandi { atlandi=1; next }
    { print }
    END { if (!bulundu) exit 3 }
  ' "$DOSYA" > "$tmp" || { rm -f "$tmp"; return 3; }
  mv "$tmp" "$DOSYA"
}

_kart_kapat() { # $1=ad $2=gerekce $3=olur(ops)
  local ad="$1" ger="$2" olur="${3:-}" tmp; tmp="$(mktemp)"
  awk -v ad="$ad" -v ger="$ger" -v olur="$olur" -v gun="$(_bugun)" '
    $0 == "🚦 SENDE · " ad {
      print "✅ KAPANDI " gun " · " ad
      print "kapanış: " ger
      if (olur != "") print "olur: " olur
      bulundu=1; next }
    { print }
    END { if (!bulundu) exit 3 }
  ' "$DOSYA" > "$tmp" || { rm -f "$tmp"; return 3; }
  mv "$tmp" "$DOSYA"
}

# ── SON-HALKA: bloklu ajandan "çözüldü" oluru (MABEYN H3 · L37-F9) ──────────
# NİÇİN: Sultan bir engeli kaldırdı diye iş çözülmüş SAYILMAZ — bunu ancak ENGELLENEN taraf
#   söyleyebilir. Ölçülmüş desen: "gönderildi ≠ ulaştı ≠ üstlenildi ≠ çözüldü"; bu zincirin
#   son halkası bugüne dek hiç kapanmıyordu (Sultan adımı yapıyor, ajan hâlâ duvara çarpıyordu).
# NASIL: kartın ilgili olduğu federe tetiğin durumu okunur — `tamam` ise olur GELMİŞTİR.
#   `--federe-tamam <id>` verilirse kanıt ZORUNLUDUR: tetik `tamam` değilse kart KAPANMAZ (RC=4).
#   Kanıtsız kapatma hâlâ mümkün (`--gerekce` ile) ama o zaman "olur:" satırı yazılmaz —
#   kaydın kendisi hangi kapanışın kanıtlı olduğunu gösterir (sahte-yeşil ayırt edilebilir).
_olur_dogrula() { # $1=tetik-id → 0=tamam(olur var) · 4=henüz değil · 2=okunamadı
  local id="$1" fed="${FEDERE_SH:-/config/.claude/skills/federe-os-cekirdek/scripts/federe.sh}"
  [ -x "$fed" ] || [ -r "$fed" ] || { _hata "federe istemcisi yok — olur DOĞRULANAMADI"; return 2; }
  local cikti; cikti="$(bash "$fed" giden all 2>/dev/null | grep -F "$id" | head -1)" || true
  [ -n "$cikti" ] || { _hata "tetik bulunamadı: $id (olur doğrulanamadı)"; return 2; }
  printf '%s' "$cikti" | grep -q " tamam " && return 0
  _hata "tetik '$id' henüz 'tamam' değil — bloklu ajan çözüldü DEMEDİ (kart açık kalır)"
  return 4
}

# ── adım planı ───────────────────────────────────────────────────────────────
_plan_yolu() { printf '%s/%s.md' "$ADIM_DIZIN" "$1"; }

_plan_oku() { # $1=yol $2=anahtar
  sed -n "s/^$2: *//p" "$1" 2>/dev/null | head -1
}

_adim_ekle() { # ad yapilacak nerede bitince
  local ad="$1" yap="$2" ner="$3" bit="$4" yol; yol="$(_plan_yolu "$ad")"
  mkdir -p "$ADIM_DIZIN"
  if [ ! -f "$yol" ]; then
    printf '# %s — adım planı\nkart: %s (kapimda.md)\ntoplam: 0\nsuanki: 1\ndurum: açık\n\n' "$ad" "$ad" > "$yol"
  fi
  local toplam; toplam="$(_plan_oku "$yol" toplam)"; toplam=$(( ${toplam:-0} + 1 ))
  printf '### adim %s\nYapılacak: %s\nNerede: %s\nBitince: %s\n\n' "$toplam" "$yap" "$ner" "$bit" >> "$yol"
  sed -i "s/^toplam: .*/toplam: $toplam/" "$yol"
  printf 'adım %s eklendi → %s\n' "$toplam" "$ad"
}

_adim_goster() { # ad
  local ad="$1" yol; yol="$(_plan_yolu "$ad")"
  [ -f "$yol" ] || { _hata "'$ad' için adım planı yok"; return 2; }
  local toplam suanki; toplam="$(_plan_oku "$yol" toplam)"; suanki="$(_plan_oku "$yol" suanki)"
  [ "${suanki:-1}" -le "${toplam:-0}" ] || { printf '✅ %s · tüm adımlar bitti (%s/%s)\n' "$ad" "$toplam" "$toplam"; return 0; }
  local blok; blok="$(awk -v n="### adim $suanki" '$0==n{f=1;next} /^### adim /{f=0} f' "$yol")"
  printf '```\n🛠️ ŞİMDİ SEN · %s · adım %s/%s\n%s```\n' "$ad" "$suanki" "$toplam" \
    "$(printf '%s\n' "$blok" | sed '/^$/d')
"
}

_adim_ilerle() { # ad
  local ad="$1" yol; yol="$(_plan_yolu "$ad")"
  [ -f "$yol" ] || { _hata "'$ad' için adım planı yok"; return 2; }
  local toplam suanki; toplam="$(_plan_oku "$yol" toplam)"; suanki="$(_plan_oku "$yol" suanki)"
  suanki=$(( ${suanki:-1} + 1 ))
  sed -i "s/^suanki: .*/suanki: $suanki/" "$yol"
  if [ "$suanki" -gt "${toplam:-0}" ]; then
    sed -i "s/^durum: .*/durum: TAMAM — tüm adımlar bitti/" "$yol"
    printf '✅ %s · tüm adımlar bitti (%s/%s)\n' "$ad" "$toplam" "$toplam"
  else
    printf '→ %s · sıradaki adım %s/%s (göstermek için: kapimda adim goster)\n' "$ad" "$suanki" "$toplam"
  fi
}

# ── dosya-geneli lint ────────────────────────────────────────────────────────
_lint_dosya() {
  local bulgu=0 n; n="$(_acik_sayi)"
  [ "$n" -le "$TAVAN" ] || { _hata "tavan aşıldı: $n açık kart (> $TAVAN)"; bulgu=1; }
  # her açık kartta dört alan var mı
  local ad
  while IFS= read -r ad; do
    [ -n "$ad" ] || continue
    local govde; govde="$(awk -v a="🚦 SENDE · $ad" '$0==a{f=1} f{print} f && /^```$/ && $0=="```"{if(++c==1) exit}' "$DOSYA")"
    local alan
    for alan in "Ne yapman gerekiyor:" "Niçin sen:" "Yapılmazsa:" "Bitince:"; do
      printf '%s' "$govde" | grep -qF "$alan" || { _hata "kart '$ad' eksik alan: $alan"; bulgu=1; }
    done
  done < <(_acik_adlar)
  [ "$bulgu" -eq 0 ] && printf '✅ kapımda temiz — %s açık kart (tavan %s)\n' "$n" "$TAVAN"
  return $bulgu
}

# ── argüman ayrıştırma ───────────────────────────────────────────────────────
KOMUT="${1:-}"; shift 2>/dev/null || true
NE=""; NICIN=""; YAPILMAZSA=""; BITINCE=""; OZET=""; YAS=""; ENGEL=""; GEREKCE=""; FEDERE_TAMAM=""
YAPILACAK=""; NEREDE=""; KURU=0; SAHIP=""; SULTAN_ONAYI=""
AD=""
if [ "$KOMUT" = "adim" ]; then ALT="${1:-}"; shift 2>/dev/null || true; fi
[ $# -gt 0 ] && case "${1:-}" in --*) ;; *) AD="$1"; shift ;; esac
while [ $# -gt 0 ]; do
  case "$1" in
    --ne) NE="${2:-}"; shift 2 ;;
    --nicin-sen) NICIN="${2:-}"; shift 2 ;;
    --yapilmazsa) YAPILMAZSA="${2:-}"; shift 2 ;;
    --bitince) BITINCE="${2:-}"; shift 2 ;;
    --ozet) OZET="${2:-}"; shift 2 ;;
    --yas) YAS="${2:-}"; shift 2 ;;
    --engel) ENGEL="${2:-}"; shift 2 ;;
    --gerekce) GEREKCE="${2:-}"; shift 2 ;;
    --federe-tamam) FEDERE_TAMAM="${2:-}"; shift 2 ;;
    --yapilacak) YAPILACAK="${2:-}"; shift 2 ;;
    --nerede) NEREDE="${2:-}"; shift 2 ;;
    --sahip) SAHIP="${2:-}"; shift 2 ;;
    --sultan-onayi) SULTAN_ONAYI="${2:-}"; shift 2 ;;
    --kuru) KURU=1; shift ;;
    *) _hata "bilinmeyen bayrak: $1"; exit 2 ;;
  esac
done

mkdir -p "$(dirname "$DOSYA")" 2>/dev/null || true
touch "$DOSYA" 2>/dev/null || { _hata "kapımda dosyası yazılamıyor: $DOSYA"; exit 2; }

case "$KOMUT" in
  ac)
    [ -n "$AD" ] || { _hata "Kısa Ad zorunlu: kapimda ac \"<Kısa Ad>\" --ne … --nicin-sen … --yapilmazsa … --bitince …"; exit 2; }
    _lint_kart "$AD" "$NE" "$NICIN" "$YAPILMAZSA" "$BITINCE" "$OZET" || {
      printf '⛔ kart AÇILMADI — lint kapısı (yukarıdaki sebepler)\n' >&2; exit 1; }
    [ "$KURU" -eq 1 ] && { printf '✅ lint temiz (kuru koşu — yazılmadı): %s\n' "$AD"; exit 0; }
    ODA="$(_bu_oda)"
    flock "$KILIT" bash -c "$(declare -f _kart_yaz _bugun); DOSYA='$DOSYA' TAVAN='$TAVAN' _kart_yaz \"\$@\"" _ \
      "$AD" "$NE" "$NICIN" "$YAPILMAZSA" "$BITINCE" "$OZET" "$YAS" "$ENGEL" "$ODA" || { _hata "yazım düştü"; exit 1; }
    printf '🚦 kart açıldı: %s  (oda: %s · açık: %s/%s)\n' "$AD" "$ODA" "$(_acik_sayi)" "$TAVAN"
    ;;
  bitti)
    [ -n "$AD" ] || { _hata "Kısa Ad zorunlu"; exit 2; }
    [ -n "$GEREKCE" ] || { _hata "--gerekce zorunlu (kart neden Sultan'da değil artık?)"; exit 2; }
    OLUR=""
    if [ -n "$FEDERE_TAMAM" ]; then
      _olur_dogrula "$FEDERE_TAMAM"; drc=$?
      [ "$drc" -eq 0 ] || { printf '⛔ kart KAPANMADI — son-halka eksik (bloklu ajanın oluru yok)\n' >&2; exit "$drc"; }
      OLUR="bloklu ajan doğruladı (federe tetik $FEDERE_TAMAM → tamam)"
    fi
    flock "$KILIT" bash -c "$(declare -f _kart_kapat _bugun); DOSYA='$DOSYA' _kart_kapat \"\$@\"" _ "$AD" "$GEREKCE" "$OLUR"
    rc=$?
    [ "$rc" -eq 3 ] && { _hata "'$AD' adlı açık kart yok"; exit 1; }
    [ "$rc" -eq 0 ] || { _hata "kapatma düştü"; exit 1; }
    printf '✅ kart kapandı: %s\n' "$AD"
    ;;
  devret)
    [ -n "$AD" ] || { _hata "Kısa Ad zorunlu: kapimda devret \"<Kısa Ad>\" --sahip <AJAN|SULTAN> --gerekce \"…\""; exit 2; }
    [ -n "$SAHIP" ] || { _hata "--sahip zorunlu (kime devrediliyor?)"; exit 2; }
    [ -n "$GEREKCE" ] || { _hata "--gerekce zorunlu — sessiz devir YOK"; exit 2; }
    ESKI="$(_kart_sahibi "$AD")"
    [ -n "$ESKI" ] || { _hata "'$AD' adlı açık kart yok"; exit 1; }
    [ "$ESKI" = "$SAHIP" ] && { _hata "kart zaten $SAHIP'te"; exit 2; }
    # 🔴 A06 KAPISI: Sultan'ın kapısından iş ÇIKARMAK bir karardır. Ajan kendi kendine
    #   "bu bana düşer" deyip Sultan'ın listesini temizleyemez. Sultan'ın verbatim sözü
    #   ZORUNLU ve karta YAZILIR (denetlenebilir). Bu sözü uydurmak, sahte onay yazmakla
    #   AYNI sınıf ihlaldir — kanıt karttadır.
    if [ "$ESKI" = "SULTAN" ] && [ "$SAHIP" != "SULTAN" ] && [ -z "$SULTAN_ONAYI" ]; then
      _hata "Sultan'ın kapısından iş çıkarmak Sultan-onayı ister → --sultan-onayi \"<Sultan'ın kendi cümlesi>\""; exit 5
    fi
    SAY="$(_devir_sayaci "$AD")"; SAY=$((SAY+1)); TIK=0
    # PİNPON PANZEHİRİ: 3 kez el değiştirdiyse sahibi belli değildir → hakem Sultan.
    if [ "$SAY" -ge "${KAPIMDA_SUT_TAVANI:-3}" ] && [ "$SAHIP" != "SULTAN" ]; then TIK=1; SAHIP="SULTAN"; fi
    GER="$GEREKCE"; [ -n "$SULTAN_ONAYI" ] && GER="$GEREKCE (Sultan: \"$SULTAN_ONAYI\")"
    KART_ODA="$(_kart_oda "$AD")"
    flock "$KILIT" bash -c "$(declare -f _kart_devret _bugun); DOSYA='$DOSYA' _kart_devret \"\$@\"" _ \
      "$AD" "$SAHIP" "$GER" "$ESKI" "$SAY" "$TIK" "$KART_ODA"
    rc=$?
    [ "$rc" -eq 0 ] || { _hata "devir düştü"; exit 1; }
    if [ "$TIK" -eq 1 ]; then
      printf '⚠️ TIKANDI: %s → %s kez el değiştirdi, kart SULTAN'"'"'a döndü (hakem Sultan)\n' "$AD" "$SAY"
    else
      printf '🎯 devredildi: %s · %s → %s (devir %s)\n' "$AD" "$ESKI" "$SAHIP" "$SAY"
    fi
    ;;
  liste)
    n="$(_acik_sayi)"
    [ "$n" -gt 0 ] || { printf 'kapında iş yok.\n'; exit 0; }
    # G1 SALT-BİLGİ: kaynak kutu GÖSTERİLİR ama FİLTRELENMEZ. Listeyi kutuya göre süzmek
    # Sultan'ın gördüğü çıktıyı değiştirir → ayrı faz, ayrı Sultan-kararı (G2).
    # 🔴 ÇIKTI TEK PARÇADA basılır (satır-satır DEĞİL): `set -o pipefail` altında
    #   `kapimda liste | grep -q …` gibi ERKEN KAPANAN bir okuyucu, satır-satır yazan
    #   döngüye SIGPIPE gönderip komutu başarısız gösteriyordu (ilk koşumda yakalandı —
    #   L1 kapısı kırmızıya döndü). Tek `printf` bu yüzey-farkını kapatır.
    _cikti="🚦 kapında $n iş:"
    while IFS= read -r _a; do
      [ -n "$_a" ] || continue
      _o="$(_kart_oda "$_a")"
      _cikti="$_cikti"$'\n'"  • $_a${_o:+  (oda: $_o)}"
    done < <(_acik_adlar)
    printf '%s\n' "$_cikti"
    ;;
  lint) _lint_dosya ;;
  adim)
    [ -n "$AD" ] || { _hata "Kısa Ad zorunlu"; exit 2; }
    case "${ALT:-}" in
      ekle)
        [ -n "$YAPILACAK" ] && [ -n "$NEREDE" ] && [ -n "$BITINCE" ] || { _hata "adim ekle: --yapilacak --nerede --bitince zorunlu"; exit 2; }
        if _jargon_var "$YAPILACAK"; then _hata "adım metni jargon taşıyor (tek-satır kopyalanabilir komut hariç yol/kod yazma)"; exit 1; fi
        _adim_ekle "$AD" "$YAPILACAK" "$NEREDE" "$BITINCE" ;;
      goster) _adim_goster "$AD" ;;
      ilerle) _adim_ilerle "$AD" ;;
      durum)
        yol="$(_plan_yolu "$AD")"; [ -f "$yol" ] || { _hata "'$AD' için adım planı yok"; exit 2; }
        printf '%s · adım %s/%s · %s\n' "$AD" "$(_plan_oku "$yol" suanki)" "$(_plan_oku "$yol" toplam)" "$(_plan_oku "$yol" durum)" ;;
      *) _hata "adim alt-komutu: ekle|goster|ilerle|durum"; exit 2 ;;
    esac ;;
  ""|-h|--help|yardim)
    sed -n '/^# KULLANIM/,/^# ÇIKIŞ/p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) _hata "bilinmeyen komut: $KOMUT (ac|bitti|devret|liste|lint|adim)"; exit 2 ;;
esac
