#!/usr/bin/env bash
# kapimda.test.sh — yazıcı + 8 lint kapısı + adım motoru HERMETİK sınaması (MABEYN H2 · L38-F3/L39-F1)
# Gerçek ~/.claude/kapimda.md'ye DOKUNMAZ (KAPIMDA_DOSYA ile geçici dosyaya yönlendirilir).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$HERE/kapimda.sh"
gecti=0; dustu=0
ok()   { echo "PASS  $1"; gecti=$((gecti+1)); }
kotu() { echo "FAIL  $1"; dustu=$((dustu+1)); }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

export KAPIMDA_DOSYA="$T/kapimda.md" KAPIMDA_ADIM_DIZIN="$T/adim" KAPIMDA_KILIT="$T/lock"
kos(){ bash "$SUT" "$@"; }
# geçerli kart alanları (jargonsuz, Sultan-dilinde)
G_NE="bana 'kasa erişimi aç' de, adımları önüne koyayım"
G_NICIN="kasa paneline giriş yalnız sende; ajanın oraya erişimi yok"
G_YAP="ekip iki işe de başlayamaz, kutu boşa çalışır"
G_BIT="'kasa bitti' de"

bash -n "$SUT" && ok "G0 sözdizimi" || kotu "G0 sözdizimi bozuk"

# ── K-kapıları: RED yolları ──────────────────────────────────────────────────
kos ac "Test Kart" --ne "$G_NE" --nicin-sen "$G_NICIN" --yapilmazsa "$G_YAP" >/dev/null 2>&1
[ $? -eq 1 ] && ok "K1 eksik alan (--bitince yok) → RED" || kotu "K1 eksik alanla açtı"

kos ac "Test Kart" --ne "$G_NE" --nicin-sen "kısa" --yapilmazsa "$G_YAP" --bitince "$G_BIT" >/dev/null 2>&1
[ $? -eq 1 ] && ok "K2 'Niçin sen' cümle değil → RED" || kotu "K2 boş-gerekçeyle açtı"

kos ac "Yollu Kart" --ne "şu dosyayı aç: /config/projects/x.sh" --nicin-sen "$G_NICIN" \
   --yapilmazsa "$G_YAP" --bitince "$G_BIT" >/dev/null 2>&1
[ $? -eq 1 ] && ok "K5 dosya-yolu → RED (Sultan-dili kalkanı)" || kotu "K5 yol kaçtı"

kos ac "Komutlu Kart" --ne "git push yap sonra bana haber ver" --nicin-sen "$G_NICIN" \
   --yapilmazsa "$G_YAP" --bitince "$G_BIT" >/dev/null 2>&1
[ $? -eq 1 ] && ok "K5 komut-terimi → RED" || kotu "K5 komut kaçtı"

kos ac "Cok Is" --ne "panele gir; sonra anahtarı üret ve bana ver" --nicin-sen "$G_NICIN" \
   --yapilmazsa "$G_YAP" --bitince "$G_BIT" >/dev/null 2>&1
[ $? -eq 1 ] && ok "K6 çok-eylem → RED (adım-kartına böl)" || kotu "K6 çok-eylem kaçtı"

SAHTE="ghp_$(printf 'a%.0s' $(seq 1 30))"
kos ac "Sirli Kart" --ne "$G_NE" --nicin-sen "$G_NICIN" --yapilmazsa "$SAHTE" --bitince "$G_BIT" >/dev/null 2>&1
[ $? -eq 1 ] && ok "K7 sır-deseni → RED" || kotu "K7 sır kaçtı"

kos ac "Uzun Kart" --ne "$(printf 'x%.0s' $(seq 1 300))" --nicin-sen "$G_NICIN" \
   --yapilmazsa "$G_YAP" --bitince "$G_BIT" >/dev/null 2>&1
[ $? -eq 1 ] && ok "K8 uzunluk → RED" || kotu "K8 uzunluk kaçtı"

# RED yollarında dosya KİRLENMEDİ mi (fail-closed kanıtı)
[ ! -s "$KAPIMDA_DOSYA" ] || ! grep -q "🚦 SENDE" "$KAPIMDA_DOSYA" 2>/dev/null \
  && ok "RED yolları dosyaya HİÇ yazmadı (fail-closed)" || kotu "RED yolu dosyayı kirletti"

# ── mutlu yol ────────────────────────────────────────────────────────────────
kos ac "Kasa Erisimi" --ne "$G_NE" --nicin-sen "$G_NICIN" --yapilmazsa "$G_YAP" --bitince "$G_BIT" \
   --yas "1 gündür bekliyor" --engel "iki iş hiç başlayamadı" >/dev/null 2>&1
[ $? -eq 0 ] && ok "M1 geçerli kart açıldı" || kotu "M1 geçerli kart açılmadı"
grep -qx "🚦 SENDE · Kasa Erisimi" "$KAPIMDA_DOSYA" && ok "M2 çizici sözleşmesi (satır-başı damga)" || kotu "M2 damga formatı yanlış"
grep -q "Niçin sen: $G_NICIN" "$KAPIMDA_DOSYA" && ok "M3 dört alan yazıldı" || kotu "M3 alan eksik"
grep -q "1 gündür bekliyor · iki iş hiç başlayamadı" "$KAPIMDA_DOSYA" && ok "M4 yaş+engel satırı" || kotu "M4 yaş satırı yok"

# çizicinin gerçek grep'i kaç kart görüyor
[ "$(grep -cP '^🚦 SENDE · ' "$KAPIMDA_DOSYA")" -eq 1 ] && ok "M5 basla-çizicisi 1 kart görür" || kotu "M5 çizici sayımı yanlış"

kos ac "Kasa Erisimi" --ne "$G_NE" --nicin-sen "$G_NICIN" --yapilmazsa "$G_YAP" --bitince "$G_BIT" >/dev/null 2>&1
[ $? -eq 1 ] && ok "K4 aynı ad ikinci kez → RED" || kotu "K4 mükerrer ad açtı"

# ── K3 tavan ────────────────────────────────────────────────────────────────
kos ac "Ikinci Kart" --ne "$G_NE" --nicin-sen "$G_NICIN" --yapilmazsa "$G_YAP" --bitince "$G_BIT" >/dev/null 2>&1
kos ac "Ucuncu Kart" --ne "$G_NE" --nicin-sen "$G_NICIN" --yapilmazsa "$G_YAP" --bitince "$G_BIT" >/dev/null 2>&1
kos ac "Dorduncu Kart" --ne "$G_NE" --nicin-sen "$G_NICIN" --yapilmazsa "$G_YAP" --bitince "$G_BIT" >/dev/null 2>&1
[ $? -eq 1 ] && ok "K3 tavan-3 aşıldı → RED (sessiz sıraya atmaz)" || kotu "K3 tavanı deldi"
[ "$(grep -cP '^🚦 SENDE · ' "$KAPIMDA_DOSYA")" -eq 3 ] && ok "K3b dosyada tam 3 kart" || kotu "K3b kart sayısı yanlış"

# ── bitti ────────────────────────────────────────────────────────────────────
kos bitti "Kasa Erisimi" >/dev/null 2>&1
[ $? -eq 2 ] && ok "B1 --gerekce yoksa kapatmaz" || kotu "B1 gerekçesiz kapattı"
kos bitti "Kasa Erisimi" --gerekce "Sultan kasada kimliği açtı, blokaj düştü" >/dev/null 2>&1
[ $? -eq 0 ] && ok "B2 kart kapandı" || kotu "B2 kapatma düştü"
grep -q "^✅ KAPANDI .* · Kasa Erisimi" "$KAPIMDA_DOSYA" && ok "B3 KAPANDI damgası + tarih" || kotu "B3 damga yok"
grep -q "kapanış: Sultan kasada kimliği açtı" "$KAPIMDA_DOSYA" && ok "B4 gerekçe yazıldı" || kotu "B4 gerekçe yok"
[ "$(grep -cP '^🚦 SENDE · ' "$KAPIMDA_DOSYA")" -eq 2 ] && ok "B5 açık kart 3→2" || kotu "B5 sayım yanlış"
kos bitti "Olmayan Kart" --gerekce "x" >/dev/null 2>&1
[ $? -eq 1 ] && ok "B6 olmayan kartı kapatmaya çalışınca RC=1 (sessiz başarı yok)" || kotu "B6 hayalet kapatma"

# ── SON-HALKA: bloklu ajandan "çözüldü" oluru (MABEYN H3) ────────────────────
# Sahte federe: verilen id'nin durumunu fixture'dan basar.
cat > "$T/federe.sh" <<EOF
#!/usr/bin/env bash
[ "\$1" = "giden" ] && cat "$T/tetikler.txt" 2>/dev/null
exit 0
EOF
chmod +x "$T/federe.sh"
kos_f(){ FEDERE_SH="$T/federe.sh" bash "$SUT" "$@"; }

kos ac "Olur Karti" --ne "$G_NE" --nicin-sen "$G_NICIN" --yapilmazsa "$G_YAP" --bitince "$G_BIT" >/dev/null 2>&1
printf '  • [tetik-1] alindi · s01→s04 · tetik · is
' > "$T/tetikler.txt"
kos_f bitti "Olur Karti" --gerekce "Sultan adimi yapti" --federe-tamam tetik-1 >/dev/null 2>&1
[ $? -eq 4 ] && ok "S1 olur gelmeden kart KAPANMADI (RC=4)" || kotu "S1 olursuz kapattı"
grep -qx "🚦 SENDE · Olur Karti" "$KAPIMDA_DOSYA" && ok "S2 kart açık kaldı" || kotu "S2 kart kapandı!"

printf '  • [tetik-1] tamam · s01→s04 · tetik · is
' > "$T/tetikler.txt"
kos_f bitti "Olur Karti" --gerekce "Sultan adimi yapti" --federe-tamam tetik-1 >/dev/null 2>&1
[ $? -eq 0 ] && ok "S3 olur gelince kart kapandı" || kotu "S3 olur geldi ama kapanmadı"
grep -q "^olur: bloklu ajan doğruladı" "$KAPIMDA_DOSYA" && ok "S4 olur-satırı kanıtla yazıldı" || kotu "S4 olur satırı yok"

kos ac "Kanitsiz Kart" --ne "$G_NE" --nicin-sen "$G_NICIN" --yapilmazsa "$G_YAP" --bitince "$G_BIT" >/dev/null 2>&1
kos bitti "Kanitsiz Kart" --gerekce "artık gerek kalmadı" >/dev/null 2>&1
[ $? -eq 0 ] && ok "S5 kanıtsız kapatma hâlâ mümkün (--federe-tamam opsiyonel)" || kotu "S5 kanıtsız kapatma kırıldı"
awk '/^✅ KAPANDI .* · Kanitsiz Kart$/{f=1;next} f&&/^olur:/{print "VAR";exit} f&&/^$/{exit}' "$KAPIMDA_DOSYA" | grep -q VAR   && kotu "S6 kanıtsız kapanışa olur-satırı yazdı" || ok "S6 kanıtsız kapanışta olur-satırı YOK (ayırt edilebilir)"

printf '' > "$T/tetikler.txt"
kos ac "Hayalet Tetik" --ne "$G_NE" --nicin-sen "$G_NICIN" --yapilmazsa "$G_YAP" --bitince "$G_BIT" >/dev/null 2>&1
kos_f bitti "Hayalet Tetik" --gerekce "x" --federe-tamam yok-boyle-id >/dev/null 2>&1
[ $? -eq 2 ] && ok "S7 tetik bulunamadı → RC=2 (doğrulanamadı ≠ tamam)" || kotu "S7 hayalet tetiği kabul etti"
kos bitti "Hayalet Tetik" --gerekce "temizlik" >/dev/null 2>&1
kos bitti "Olur Karti" --gerekce "temizlik" >/dev/null 2>&1

# ── liste + lint ─────────────────────────────────────────────────────────────
kos liste 2>/dev/null | grep -q "Ikinci Kart" && ok "L1 liste açık kartları basar" || kotu "L1 liste yanlış"
kos lint >/dev/null 2>&1; [ $? -eq 0 ] && ok "L2 lint temiz dosyada RC=0" || kotu "L2 lint yanlış kırmızı"

# ── adım motoru ──────────────────────────────────────────────────────────────
kos adim ekle "Ikinci Kart" --yapilacak "panele gir" --nerede "kasa paneli" --bitince "girdim de" >/dev/null 2>&1
kos adim ekle "Ikinci Kart" --yapilacak "yeni kimlik oluştur" --nerede "aynı sayfa" --bitince "oluşturdum de" >/dev/null 2>&1
[ -f "$T/adim/Ikinci Kart.md" ] && ok "A1 adım planı diske yazıldı" || kotu "A1 plan yok"
grep -q "^toplam: 2" "$T/adim/Ikinci Kart.md" && ok "A2 toplam sayacı" || kotu "A2 sayaç yanlış"
OUT="$(kos adim goster "Ikinci Kart" 2>&1)"
printf '%s' "$OUT" | grep -q "adım 1/2" && ok "A3 SIRADAKİ tek adım basıldı" || kotu "A3 adım gösterimi yanlış"
printf '%s' "$OUT" | grep -q "yeni kimlik" && kotu "A4 iki adımı birden bastı (L39 ihlali)" || ok "A4 yalnız TEK adım basıldı"
kos adim ilerle "Ikinci Kart" >/dev/null 2>&1
kos adim goster "Ikinci Kart" 2>&1 | grep -q "adım 2/2" && ok "A5 ilerle sıradakine geçti" || kotu "A5 ilerleme yanlış"
kos adim ilerle "Ikinci Kart" 2>&1 | grep -q "tüm adımlar bitti" && ok "A6 son adımdan sonra TAMAM" || kotu "A6 bitiş yanlış"
kos adim ekle "Yollu Adim" --yapilacak "şu dosyayı düzenle: /config/x.md" --nerede "editör" --bitince "oldu de" >/dev/null 2>&1
[ $? -eq 1 ] && ok "A7 adım metninde yol → RED" || kotu "A7 adımda yol kaçtı"

# ══ L47/F5 · KART DEVRİ kapıları ═══════════════════════════════════════════
# Sultan'ın isteği: "SİNAN o kartları SERDAR etiketli atabilir, SERDAR'ın kapısına şutlayabilir."
_dev_yeni(){ D="$T/dev$RANDOM.md"; printf '# baslik\n\n```\n🚦 SENDE · Test Kart\nbugün açıldı\n\ngövde\n\nNe yapman gerekiyor: x\nNiçin sen: y\nYapılmazsa: z\nBitince: w\n```\n**+0 kart daha bekliyor.** (Tavan 3;)\n' > "$D"; printf '%s' "$D"; }
_dk(){ KAPIMDA_DOSYA="$1" bash "$SUT" "${@:2}"; }

D="$(_dev_yeni)"; _dk "$D" devret "Test Kart" --sahip SINAN --gerekce "başlangıç" --sultan-onayi "devret" >/dev/null 2>&1
out="$(_dk "$D" devret "Test Kart" --sahip SERDAR --gerekce "altyapı işi" 2>&1)"
{ printf '%s' "$out" | grep -q 'SINAN → SERDAR' && grep -q '^🎯 SERDAR · Test Kart$' "$D"; } \
  && ok "D1 ajan→ajan devri serbest, damga 🎯 <AJAN>" || kotu "D1 ajan→ajan devri"

D="$(_dev_yeni)"; _dk "$D" devret "Test Kart" --sahip SERDAR --gerekce "bana düşer" >/dev/null 2>&1
{ [ $? -eq 5 ] && grep -q '^🚦 SENDE · Test Kart$' "$D"; } \
  && ok "D2 Sultan kapısından onaysız iş çıkarılamaz (A06/RC=5)" || kotu "D2 A06 kapısı delindi"

D="$(_dev_yeni)"; _dk "$D" devret "Test Kart" --sahip SERDAR --gerekce "altyapı" --sultan-onayi "sen hallet" >/dev/null 2>&1
grep -q 'Sultan: "sen hallet"' "$D" && ok "D3 Sultan-onayı verbatim karta yazılır" || kotu "D3 onay kayda geçmedi"

D="$(_dev_yeni)"; _dk "$D" devret "Test Kart" --sahip SERDAR --sultan-onayi "ok" >/dev/null 2>&1
[ $? -eq 2 ] && ok "D4 gerekçesiz devir reddedilir (sessiz devir yok)" || kotu "D4 gerekçesiz devir geçti"

D="$(_dev_yeni)"; _dk "$D" devret "Test Kart" --sahip SERDAR --gerekce g --sultan-onayi ok >/dev/null 2>&1
[ "$(_dk "$D" liste 2>/dev/null | head -1)" = "kapında iş yok." ] \
  && ok "D5 ajana devredilen kart Sultan'ın kapısından düşer" || kotu "D5 sayım ayrışmadı"

D="$(_dev_yeni)"
_dk "$D" devret "Test Kart" --sahip A --gerekce g --sultan-onayi ok >/dev/null 2>&1
_dk "$D" devret "Test Kart" --sahip B --gerekce g >/dev/null 2>&1
out="$(_dk "$D" devret "Test Kart" --sahip C --gerekce g 2>&1)"
{ printf '%s' "$out" | grep -q 'TIKANDI' && grep -q '^⚠️ TIKANDI · Test Kart$' "$D"; } \
  && ok "D6 3. devirde kart Sultan'a döner (pinpon panzehiri)" || kotu "D6 pinpon panzehiri"
[ "$(grep -c '^devir: ' "$D")" = "1" ] && ok "D7 devir sayacı tek satır" || kotu "D7 mükerrer sayaç"
[ "$(grep -c '^↳ devir ' "$D")" -ge 3 ] && ok "D8 her devir gerekçesiyle kayda düşer" || kotu "D8 devir kaydı eksik"

D="$(_dev_yeni)"; _dk "$D" devret "Yok Boyle" --sahip X --gerekce g >/dev/null 2>&1
[ $? -eq 1 ] && ok "D9 olmayan kart devredilemez" || kotu "D9 hayalî kart devredildi"

D="$(_dev_yeni)"; grep -q '^🚦 SENDE · Test Kart$' "$D" \
  && ok "D10 dokunulmamış kartın damgası birebir aynı (geriye-uyum)" || kotu "D10 geriye-uyum bozuldu"


# ── ODA DAMGASI (L48 · G1 = L47'nin F3'ü · 2026-08-05) ──────────────────────
# NİÇİN: kapımda dosyası 14 kutuda AYNI inode ve kartta "bunu kim açtı" alanı YOKTU →
# her kutu ötekinin işini kendi kapısı sanıyordu (HUZUR ölçtü: "kapında 3 iş", üçü de
# başka oda). Aşağıdaki kapılar damganın DOĞUŞ ANINDA basıldığını, UYDURULMADIĞINI ve
# çizici sözleşmesini BOZMADIĞINI kilitler.
_oda_yeni(){ O="$T/oda$RANDOM.md"; printf '%s' "$O"; }
_ok(){ KAPIMDA_DOSYA="$1" bash "$SUT" "${@:2}"; }
OG_AC=(--ne "$G_NE" --nicin-sen "$G_NICIN" --yapilmazsa "$G_YAP" --bitince "$G_BIT")

O="$(_oda_yeni)"; DEFAULT_WORKSPACE=/config/projects/tellal _ok "$O" ac "Kaynak Kart" "${OG_AC[@]}" >/dev/null 2>&1
grep -q '^oda: tellal$' "$O" && ok "O1 kart doğuş anında oda damgası taşır" || kotu "O1 damga basılmadı"
[ "$(awk '/^🚦 SENDE · Kaynak Kart$/{getline; print}' "$O")" = "oda: tellal" ] \
  && ok "O2 damga başlığın HEMEN altında (L47 §7.1 şeması)" || kotu "O2 damga yanlış yerde"

O="$(_oda_yeni)"; DEFAULT_WORKSPACE=/config/projects _ok "$O" ac "Merkez Kart" "${OG_AC[@]}" >/dev/null 2>&1
grep -q '^oda: nexus$' "$O" && ok "O3 merkez kutusu 'nexus' (yolun son parçası 'projects' DEĞİL)" \
  || kotu "O3 merkez kutu adı yanlış"

# 🔴 UYDURMA YOK: kaynak yoksa sahte bir kutu adı basmak, alanı 818/818-s01 gibi ÖLDÜRÜR.
O="$(_oda_yeni)"; ( unset DEFAULT_WORKSPACE; _ok "$O" ac "Koksuz Kart" "${OG_AC[@]}" ) >/dev/null 2>&1
grep -q '^oda: bilinmiyor$' "$O" && ok "O4 türetilemeyen kaynak UYDURULMAZ → bilinmiyor" \
  || kotu "O4 kaynak uyduruldu ya da alan düştü"

O="$(_oda_yeni)"; KAPIMDA_ODA=huzur DEFAULT_WORKSPACE=/config/projects _ok "$O" ac "Elle Kart" "${OG_AC[@]}" >/dev/null 2>&1
grep -q '^oda: huzur$' "$O" && ok "O5 açık kutu-üstgeçişi (KAPIMDA_ODA) türetimi ezer" || kotu "O5 üstgeçiş çalışmadı"

# ÇİZİCİ SÖZLEŞMESİ: `basla` ve `/kapimda` satır-başı `^🚦 SENDE · ` damgasına bakar.
O="$(_oda_yeni)"; DEFAULT_WORKSPACE=/config/projects/akar _ok "$O" ac "Cizici Kart" "${OG_AC[@]}" >/dev/null 2>&1
{ grep -q '^🚦 SENDE · Cizici Kart$' "$O" && [ "$(grep -c '^🚦 SENDE · ' "$O")" = "1" ]; } \
  && ok "O6 çizici sözleşmesi BOZULMADI (satır-başı damga aynen)" || kotu "O6 çizici sözleşmesi kırıldı"

# DEVİR: `oda` = kartı KİM AÇTI; `sahip` = kart ŞU AN kimde. Devreden kutu kaynağı EZEMEZ.
O="$(_oda_yeni)"; DEFAULT_WORKSPACE=/config/projects/tellal _ok "$O" ac "Devir Kart" "${OG_AC[@]}" >/dev/null 2>&1
DEFAULT_WORKSPACE=/config/projects _ok "$O" devret "Devir Kart" --sahip SERDAR --gerekce "altyapı işi" \
  --sultan-onayi "sen hallet" >/dev/null 2>&1
{ grep -q '^oda: tellal$' "$O" && ! grep -q '^oda: nexus$' "$O"; } \
  && ok "O7 devirde kaynak KORUNUR (devreden kutu kendi adını yazmaz)" || kotu "O7 devir kaynağı ezdi"
[ "$(grep -c '^oda: ' "$O")" = "1" ] && ok "O8 devirden sonra tek oda satırı (mükerrer yok)" || kotu "O8 mükerrer oda satırı"

# GERİYE-UYUM: damgasız eski kartlara köken UYDURULMAZ (HUZUR'un şartı).
D="$(_dev_yeni)"; DEFAULT_WORKSPACE=/config/projects _dk "$D" devret "Test Kart" --sahip SERDAR \
  --gerekce g --sultan-onayi ok >/dev/null 2>&1
grep -q '^oda: ' "$D" && kotu "O9 damgasız eski karta köken uyduruldu" \
  || ok "O9 damgasız eski karta köken UYDURULMAZ"

O="$(_oda_yeni)"; DEFAULT_WORKSPACE=/config/projects/sedir _ok "$O" ac "Liste Kart" "${OG_AC[@]}" >/dev/null 2>&1
DEFAULT_WORKSPACE=/config/projects/sedir _ok "$O" liste 2>/dev/null | grep -q 'Liste Kart  (oda: sedir)' \
  && ok "O10 liste kaynağı gösterir" || kotu "O10 liste kaynağı göstermedi"

# BUGÜNÜN REGRESYONU (ilk koşumda yakalandı): liste satır-satır yazınca erken kapanan
# okuyucu SIGPIPE üretiyor, `pipefail` altında komut BAŞARISIZ görünüyordu.
DEFAULT_WORKSPACE=/config/projects/sedir _ok "$O" liste 2>/dev/null | grep -q 'Liste Kart' \
  && ok "O12 liste erken-kapanan okuyucuya karşı düşmez (boru kırılması)" || kotu "O12 liste boruda düştü"

# ── G2 · VARSAYILAN GÖRÜNÜM = KENDİ ODAN (2026-08-05) ──────────────────────────
# Sözleşme: başka odanın işi GİZLENMEZ, susturulur — dipnotta sayılır, --hepsi ile açılır.
P="$(_oda_yeni)"
DEFAULT_WORKSPACE=/config/projects/sedir _ok "$P" ac "Sedir Isi" "${OG_AC[@]}" >/dev/null 2>&1
DEFAULT_WORKSPACE=/config/projects/tellal _ok "$P" ac "Tellal Isi" "${OG_AC[@]}" >/dev/null 2>&1

CIK="$(DEFAULT_WORKSPACE=/config/projects/sedir _ok "$P" liste 2>/dev/null)"
printf '%s' "$CIK" | grep -q 'Sedir Isi' \
  && ok "P1 varsayılan liste KENDİ odanın işini gösterir" || kotu "P1 kendi işi görünmüyor"
printf '%s' "$CIK" | grep -q 'Tellal Isi' \
  && kotu "P2 başka odanın işi varsayılan listeye sızdı" || ok "P2 başka odanın işi varsayılan listede YOK"
printf '%s' "$CIK" | grep -q '1 iş başka odalarda' \
  && ok "P3 saklanan iş SESSİZCE yutulmaz — dipnotta sayılır" || kotu "P3 dipnot yok (sessiz yutma)"
printf '%s' "$CIK" | grep -q -- '--hepsi' \
  && ok "P4 tam listeye çıkış yolu gösterilir" || kotu "P4 çıkış yolu gösterilmedi"

CIK="$(DEFAULT_WORKSPACE=/config/projects/sedir _ok "$P" liste --hepsi 2>/dev/null)"
printf '%s' "$CIK" | grep -q 'Sedir Isi' && printf '%s' "$CIK" | grep -q 'Tellal Isi' \
  && ok "P5 --hepsi tüm odaları gösterir" || kotu "P5 --hepsi eksik"

# Damgasız (eski) kart "başka odanın" DEĞİL, "bilinmeyen"dir → gizlemek kanıtsız varsayım olur.
Q="$(_oda_yeni)"
printf '```\n🚦 SENDE · Damgasiz Is\nbugün açıldı\n\nozet\n\nNe yapman gerekiyor: x\nNiçin sen: y\nYapılmazsa: z\nBitince: w\n```\n' > "$Q"
DEFAULT_WORKSPACE=/config/projects/sedir _ok "$Q" liste 2>/dev/null | grep -q 'Damgasiz Is' \
  && ok "P6 damgasız eski kart GİZLENMEZ (kanıtsız varsayımla iş saklanmaz)" || kotu "P6 damgasız kart kayboldu"

# Kendi odanda iş yokken ekran boş görünmemeli — kaç iş nerede, tek satır.
CIK="$(DEFAULT_WORKSPACE=/config/projects/huma _ok "$P" liste 2>/dev/null)"
printf '%s' "$CIK" | grep -q 'kapında iş yok' && printf '%s' "$CIK" | grep -q '2 iş başka odalarda' \
  && ok "P7 kendi odan boşken bile 'başka odada N iş' görünür" || kotu "P7 boş ekran sessiz kaldı"

O="$(_oda_yeni)"; DEFAULT_WORKSPACE=/config/projects/mihenk _ok "$O" ac "Kapanan Kart" "${OG_AC[@]}" >/dev/null 2>&1
_ok "$O" bitti "Kapanan Kart" --gerekce "halloldu" >/dev/null 2>&1
grep -q '^oda: mihenk$' "$O" && ok "O13 kart kapanınca kaynak izi SİLİNMEZ" || kotu "O13 kapanışta iz kayboldu"
_ok "$O" lint >/dev/null 2>&1; [ $? -eq 0 ] && ok "O14 yeni alan linti kırmızıya düşürmez" || kotu "O14 lint yanlış kırmızı"

# ══ L39 · SULTAN-TALİMAT FORMATI — 9 karar (2026-08-11 gece) ═══════════════════
# Kaynak: _agents/spec/sultan-talimat-formati-DESIGN.md §9. Damga `🛠️ ŞİMDİ SEN` ve
# `adım i/N` zaten kuruluydu (kararlar #1/#2 kısmen); burada MEKANİZMAYA bağlanan üç
# yeni kapı test edilir: K9 kart-çapası (#4/#8) · K10 N-dürüstlüğü (#2/R8) · yumuşak-kilit
# (#3) · A06 cevap-alanı koruması (#6). Her biri MUTASYON-KANITLI: önce kırmızı üretiliyor
# mu diye bakılır (negatif-test), sonra düzeltilip yeşile döndüğü doğrulanır.
_l39_env(){ L39D="$(mktemp -d)"; }
_l39(){ KAPIMDA_DOSYA="$L39D/kapimda.md" KAPIMDA_ADIM_DIZIN="$L39D/adim" bash "$SUT" "$@"; }

# ── K9 · kart-çapası: kartsız adım-bloğu YASAK ────────────────────────────────
_l39_env; touch "$L39D/kapimda.md"
out="$(_l39 adim ekle "Hayalet Kart" --yapilacak "kasa panelini aç" --nerede "kasa paneli" --bitince "girdim de" 2>&1)"; rc=$?
{ [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q "K9"; } \
  && ok "K9 kartsız adım-bloğu → RED (açık 🚦 SENDE kartı yok)" || kotu "K9 kartsız adım geçti"
[ ! -f "$L39D/adim/Hayalet Kart.md" ] && ok "K9b RED yolunda plan dosyası HİÇ yazılmadı (fail-closed)" || kotu "K9b plan yazıldı"

# kart açılınca aynı çağrı geçer — negatif-test yeşile döner mi?
_l39 ac "Gercek Kart" "${OG_AC[@]}" >/dev/null 2>&1
_l39 adim ekle "Gercek Kart" --yapilacak "kasa panelini aç" --nerede "kasa paneli" --bitince "girdim de" >/dev/null 2>&1
[ $? -eq 0 ] && ok "K9c açık kartlı adım-bloğu normal ekleniyor (mutasyon geri alınca yeşil)" || kotu "K9c geçerli ekleme kırıldı"

# ── K10 · N-dürüstlüğü: bildirilen N ile dosyadaki gerçek adım sayısı eşleşmeli ─
_l39_env
_l39 ac "N Karti" "${OG_AC[@]}" >/dev/null 2>&1
_l39 adim ekle "N Karti" --yapilacak "kasa panelini aç" --nerede "kasa paneli" --bitince "girdim de" >/dev/null 2>&1
_l39 adim ekle "N Karti" --yapilacak "yeni kimlik oluştur" --nerede "aynı sayfa" --bitince "oluşturdum de" >/dev/null 2>&1
sed -i 's/^toplam: 2/toplam: 9/' "$L39D/adim/N Karti.md"
out="$(_l39 adim goster "N Karti" 2>&1)"; rc=$?
{ [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q "K10"; } \
  && ok "K10 uydurma N (toplam≠gerçek adım sayısı) → RED" || kotu "K10 uydurma N kaçtı"
_l39 lint >/dev/null 2>&1; [ $? -eq 1 ] && ok "K10b bozuk plan genel lint'i de kırmızıya düşürür" || kotu "K10b lint yakalamadı"
sed -i 's/^toplam: 9/toplam: 2/' "$L39D/adim/N Karti.md"
_l39 adim goster "N Karti" >/dev/null 2>&1
[ $? -eq 0 ] && ok "K10c N düzeltilince yeşile döner (mutasyon geri alındı)" || kotu "K10c düzeltme sonrası hâlâ kırmızı"

# ── Damga şablonu — 🛠️ ŞİMDİ SEN · <Ad> · adım i/N (Sultan-kararı #1/#2) ────────
out="$(_l39 adim goster "N Karti" 2>&1)"
printf '%s' "$out" | grep -qF "🛠️ ŞİMDİ SEN · N Karti · adım 1/2" && ok "F1 damga şablonu birebir (#1/#2)" || kotu "F1 damga yanlış"

# ── Yumuşak-kilit (Sultan-kararı #3): uyarı basılır, ENGELLENMEZ ───────────────
out2="$(_l39 adim goster "N Karti" 2>&1)"; rc2=$?
printf '%s' "$out2" | grep -q "yumuşak-kilit" && printf '%s' "$out2" | grep -q "2. kez" \
  && ok "YK1 aynı karta 2. açık adım-bloğu → UYARI satırı" || kotu "YK1 uyarı basılmadı"
printf '%s' "$out2" | grep -qF "🛠️ ŞİMDİ SEN · N Karti · adım 1/2" \
  && ok "YK2 uyarıya rağmen blok yine de basılır" || kotu "YK2 blok bastırıldı"
[ "$rc2" -eq 0 ] && ok "YK3 yumuşak-kilit ENGELLEMEZ (RC=0 — sert-kilit bilerek reddedildi)" || kotu "YK3 sert-kilide döndü"

_l39 ac "N Karti 2" "${OG_AC[@]}" >/dev/null 2>&1
_l39 adim ekle "N Karti 2" --yapilacak "ekranı aç" --nerede "panel" --bitince "açtım de" >/dev/null 2>&1
out3="$(_l39 adim goster "N Karti 2" 2>&1)"
printf '%s' "$out3" | grep -q "'N Karti' kartının adımı da Sultan'da açık bekliyor" \
  && ok "YK4 başka kartın açık adımı çapraz-hatırlatılır" || kotu "YK4 çapraz hatırlatma yok"

_l39 adim ilerle "N Karti" >/dev/null 2>&1
out4="$(_l39 adim goster "N Karti" 2>&1)"
printf '%s' "$out4" | grep -q "2. kez basılıyor" \
  && kotu "YK5 ilerle sonrası hâlâ kendi-tekrar uyarısı basıyor" || ok "YK5 ilerle sonrası aynı-kart uyarısı SUSAR (bekliyor=hayir)"

# ── A06 cevap-alanı koruması (Sultan-kararı #6) ────────────────────────────────
_l39_env; touch "$L39D/kapimda.md"
printf 'cevap: Evet\n' >> "$L39D/kapimda.md"
_l39 lint >/dev/null 2>&1
[ $? -eq 1 ] && ok "A06-1 ajan-yazımı 'cevap:' alanı kapimda.md'de → lint RED" || kotu "A06-1 kaçtı"

_l39_env
_l39 ac "A06 Karti" "${OG_AC[@]}" >/dev/null 2>&1
_l39 adim ekle "A06 Karti" --yapilacak "kasa panelini aç" --nerede "kasa paneli" --bitince "girdim de" >/dev/null 2>&1
_l39 lint >/dev/null 2>&1; [ $? -eq 0 ] && ok "A06-2 temiz plan lint'i kırmızıya düşürmez" || kotu "A06-2 yanlış kırmızı"
printf 'sultan_response: evet\n' >> "$L39D/adim/A06 Karti.md"
_l39 lint >/dev/null 2>&1
[ $? -eq 1 ] && ok "A06-3 plan dosyasındaki 'sultan_response:' alanı → lint RED" || kotu "A06-3 kaçtı"

# ── L49 · SAHİP-KÖR OLMAYAN TEKİLLİK + DEVREDİLMİŞ KARTIN KAPANIŞI (2026-08-11) ──
# Ölçülmüş vaka: "Tescil Bekleyen İşler" kartı SERDAR'a devredildi, K4 ve besleyici onu
# GÖRMEDİ → aynı gün iki kez yeniden açıldı. Aşağıdaki kapılar o kör-noktayı kilitler ve
# EN KRİTİĞİ D5: tavan-3 semantiği DEĞİŞMEMELİ (devredilmiş kart Sultan'ın 3'ünü YEMEZ).
_l49_env() { L49D="$(mktemp -d)"; export KAPIMDA_DOSYA="$L49D/kapimda.md" \
  KAPIMDA_ADIM_DIZIN="$L49D/adim" KAPIMDA_KILIT="$L49D/lock" KAPIMDA_ODA="l49"; }
_l49_ac() { kos ac "$1" --ne "$G_NE" --nicin-sen "$G_NICIN" --yapilmazsa "$G_YAP" --bitince "$G_BIT"; }

_l49_env
_l49_ac "Devir Karti" >/dev/null 2>&1
kos devret "Devir Karti" --sahip SERDAR --gerekce "SERDAR bakacak" --sultan-onayi "Evet, sen devral" >/dev/null 2>&1
grep -qx "🎯 SERDAR · Devir Karti" "$KAPIMDA_DOSYA" && ok "L49-0 kart SERDAR'a devredildi (ön-koşul)" || kotu "L49-0 devir olmadı"

_l49_ac "Devir Karti" >/dev/null 2>&1
[ $? -eq 1 ] && ok "L49-1 devredilmiş kartın adıyla İKİNCİ kart AÇILAMAZ (K4 sahip-kör değil)" || kotu "L49-1 mükerrer kart açıldı"
[ "$(grep -c ' · Devir Karti$' "$KAPIMDA_DOSYA")" -eq 1 ] && ok "L49-1b dosyada tek kart satırı var" || kotu "L49-1b kart çoğaldı"

out="$(kos sahip "Devir Karti" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "SERDAR" ] && ok "L49-2 'sahip' devredilmiş kartın sahibini basar" || kotu "L49-2 sahip yanlış: rc=$rc out=$out"
kos sahip "Hic Olmayan Kart" >/dev/null 2>&1
[ $? -eq 1 ] && ok "L49-2b olmayan kart → RC 1 (kart yok)" || kotu "L49-2b olmayan karta RC 1 dönmedi"

kos bitti "Devir Karti" --gerekce "kaynak boşaldı" >/dev/null 2>&1
[ $? -eq 0 ] && ok "L49-3 devredilmiş kart 'bitti' ile KAPANIR (eskiden RC 3'tü)" || kotu "L49-3 devredilmiş kart kapanmadı"
grep -qx "✅ KAPANDI $(date +%F) · Devir Karti" "$KAPIMDA_DOSYA" && ok "L49-3b kapanış damgası yazıldı" || kotu "L49-3b damga yok"

# TIKANDI kartı da tekillik sayımına girer (3. devirde kart bu damgayı alır)
_l49_env
_l49_ac "Tikanik Kart" >/dev/null 2>&1
kos devret "Tikanik Kart" --sahip SERDAR --gerekce "g1" --sultan-onayi "Evet" >/dev/null 2>&1
kos devret "Tikanik Kart" --sahip HAFIZ --gerekce "g2" >/dev/null 2>&1
kos devret "Tikanik Kart" --sahip GOZCU --gerekce "g3" >/dev/null 2>&1
grep -qx "⚠️ TIKANDI · Tikanik Kart" "$KAPIMDA_DOSYA" && ok "L49-4 üçüncü devirde TIKANDI damgası (ön-koşul)" || kotu "L49-4 TIKANDI olmadı"
_l49_ac "Tikanik Kart" >/dev/null 2>&1
[ $? -eq 1 ] && ok "L49-4b TIKANDI kartın adıyla ikinci kart AÇILAMAZ" || kotu "L49-4b mükerrer açıldı"

# 🔴 REGRESYON ZIRHI — tavan-3 SEMANTİĞİ DEĞİŞMEDİ
_l49_env
_l49_ac "Devredilen A" >/dev/null 2>&1
kos devret "Devredilen A" --sahip SERDAR --gerekce "SERDAR bakacak" --sultan-onayi "Evet" >/dev/null 2>&1
_l49_ac "Sultan 1" >/dev/null 2>&1
_l49_ac "Sultan 2" >/dev/null 2>&1
_l49_ac "Sultan 3" >/dev/null 2>&1
[ $? -eq 0 ] && ok "L49-5 devredilmiş kart Sultan'ın TAVAN-3'ünü YEMEZ (3 Sultan kartı hâlâ açılır)" || kotu "L49-5 REGRESYON: tavan semantiği bozuldu"
_l49_ac "Sultan 4" >/dev/null 2>&1
[ $? -eq 1 ] && ok "L49-5b tavan hâlâ 3'te kapanıyor (gevşemedi)" || kotu "L49-5b tavan gevşedi"
[ "$(kos liste 2>/dev/null | grep -c '•')" -eq 3 ] && ok "L49-6 'liste' Sultan-yüzü değişmedi (devredilmiş kart görünmez)" || kotu "L49-6 liste yüzeyi değişti"

# ══ L49-B · GÖVDE TAZELEME (2026-08-12) ═══════════════════════════════════════
# Ölçülmüş canlı vaka: kart açıldığı andaki sayıyı DONDURUYORDU — gövdede "iki oda talebi
# cevapsız" yazarken besleyicinin AYNI GÜN ölçtüğü gerçek sayı 48'di. Aşağıdaki kapılar
# hem tazelemenin ÇALIŞTIĞINI hem de kart KİMLİĞİNE dokunmadığını kilitler.
_tz_env(){ TZD="$(mktemp -d)"; export KAPIMDA_DOSYA="$TZD/kapimda.md" \
  KAPIMDA_ADIM_DIZIN="$TZD/adim" KAPIMDA_KILIT="$TZD/lock" KAPIMDA_ODA="tzoda"; }
_tz_ac(){ kos ac "$1" --ne "$G_NE" --nicin-sen "$G_NICIN" --yapilmazsa "$G_YAP" --bitince "$G_BIT" \
  --ozet "Şu an 2 oda talebi cevapsız." --engel "2 oda talebi cevapsız"; }

_tz_env
_tz_ac "Sahipsiz Talepler" >/dev/null 2>&1
cp "$KAPIMDA_DOSYA" "$TZD/once.md"
kos tazele "Sahipsiz Talepler" --ozet "Şu an 48 oda talebi cevapsız." --engel "48 oda talebi cevapsız" >/dev/null 2>&1
[ $? -eq 0 ] && ok "T1 tazele RC 0" || kotu "T1 tazele düştü"
grep -q "Şu an 48 oda talebi cevapsız\." "$KAPIMDA_DOSYA" && ok "T2 gövdedeki SAYI güncellendi (donmuş sayı panzehiri)" || kotu "T2 sayı güncellenmedi"
grep -q "48 oda talebi cevapsız$" "$KAPIMDA_DOSYA" && ok "T3 engel satırı güncellendi" || kotu "T3 engel güncellenmedi"
grep -q "Şu an 2 oda talebi cevapsız" "$KAPIMDA_DOSYA" && kotu "T4 eski sayı gövdede kaldı (çift-gerçek)" || ok "T4 eski sayı kalmadı"

# ⭐ EN KRİTİK REGRESYON ZIRHI — KART KİMLİĞİ DEĞİŞMEDİ
grep -qx "🚦 SENDE · Sahipsiz Talepler" "$KAPIMDA_DOSYA" && ok "T5 açılış damgası birebir aynı" || kotu "T5 damga bozuldu"
grep -qx "oda: tzoda" "$KAPIMDA_DOSYA" && ok "T6 oda (kaynak) damgası korundu" || kotu "T6 oda damgası ezildi"
grep -q "^bugün açıldı · " "$KAPIMDA_DOSYA" && ok "T7 --yas verilmedi → açılış-yaşı KORUNDU" || kotu "T7 açılış damgası ezildi"
{ grep -qF "Ne yapman gerekiyor: $G_NE" "$KAPIMDA_DOSYA" && grep -qF "Niçin sen: $G_NICIN" "$KAPIMDA_DOSYA" \
  && grep -qF "Yapılmazsa: $G_YAP" "$KAPIMDA_DOSYA" && grep -qF "Bitince: $G_BIT" "$KAPIMDA_DOSYA"; } \
  && ok "T8 dört alan (kart sözleşmesi) DEĞİŞMEDİ" || kotu "T8 kart alanları tazelemede ezildi"
[ "$(diff "$TZD/once.md" "$KAPIMDA_DOSYA" | grep -c '^<')" -eq 2 ] \
  && ok "T9 yalnız İKİ satır değişti (yaş/engel + özet) — başka hiçbir satıra dokunulmadı" \
  || kotu "T9 tazeleme fazla satıra dokundu: $(diff "$TZD/once.md" "$KAPIMDA_DOSYA" | grep -c '^<')"

# ── İDEMPOTENT: aynı içerikle ikinci tazele dosyayı DEĞİŞTİRMEZ ────────────────
cp "$KAPIMDA_DOSYA" "$TZD/ikinci-once.md"
out="$(kos tazele "Sahipsiz Talepler" --ozet "Şu an 48 oda talebi cevapsız." --engel "48 oda talebi cevapsız" 2>&1)"
[ $? -eq 0 ] && ok "T10 idempotent tazele RC 0" || kotu "T10 idempotent tazele düştü"
cmp -s "$TZD/ikinci-once.md" "$KAPIMDA_DOSYA" && ok "T11 aynı içerikle 2. tazele dosyayı DEĞİŞTİRMEDİ" || kotu "T11 gereksiz yazım yapıldı"
printf '%s' "$out" | grep -q "zaten güncel" && ok "T12 değişmediği kullanıcıya söylenir (sessiz değil)" || kotu "T12 sessiz geçti"

# ── YALNIZ VERİLEN ALAN: verilmeyen alana DOKUNULMAZ ──────────────────────────
kos tazele "Sahipsiz Talepler" --engel "50 oda talebi cevapsız" >/dev/null 2>&1
{ grep -q "Şu an 48 oda talebi cevapsız\." "$KAPIMDA_DOSYA" && grep -q "50 oda talebi cevapsız$" "$KAPIMDA_DOSYA"; } \
  && ok "T13 yalnız --engel verildi → özet DOKUNULMADI" || kotu "T13 verilmeyen alan ezildi"
kos tazele "Sahipsiz Talepler" --yas "3 gündür bekliyor" >/dev/null 2>&1
grep -q "^3 gündür bekliyor · 50 oda talebi cevapsız$" "$KAPIMDA_DOSYA" \
  && ok "T14 --yas verilince yaş güncellenir, engel korunur" || kotu "T14 yaş/engel birleşimi bozuldu"

# ── DEVREDİLMİŞ / TIKANMIŞ KART DA TAZELENİR (sahip kim olursa olsun gövde doğru olmalı) ──
_tz_env
_tz_ac "Tescil Bekleyen Isler" >/dev/null 2>&1
kos devret "Tescil Bekleyen Isler" --sahip SERDAR --gerekce "SERDAR bakacak" --sultan-onayi "Evet, sen devral" >/dev/null 2>&1
kos tazele "Tescil Bekleyen Isler" --ozet "Şu an 48 oda talebi cevapsız." >/dev/null 2>&1
[ $? -eq 0 ] && grep -q "Şu an 48 oda talebi cevapsız" "$KAPIMDA_DOSYA" \
  && ok "T15 devredilmiş (🎯) kart da tazelenir" || kotu "T15 devredilmiş kart tazelenemedi"
grep -qx "🎯 SERDAR · Tescil Bekleyen Isler" "$KAPIMDA_DOSYA" && ok "T16 devir damgası korundu" || kotu "T16 devir damgası ezildi"
[ "$(grep -c '^↳ devir ' "$KAPIMDA_DOSYA")" -eq 1 ] && ok "T17 devir geçmişi (↳) korundu" || kotu "T17 devir geçmişi bozuldu"
[ "$(grep -c '^devir: ' "$KAPIMDA_DOSYA")" -eq 1 ] && ok "T18 devir sayacı korundu" || kotu "T18 devir sayacı bozuldu"

_tz_env
_tz_ac "Tikanik Tazele" >/dev/null 2>&1
kos devret "Tikanik Tazele" --sahip A --gerekce g --sultan-onayi ok >/dev/null 2>&1
kos devret "Tikanik Tazele" --sahip B --gerekce g >/dev/null 2>&1
kos devret "Tikanik Tazele" --sahip C --gerekce g >/dev/null 2>&1
kos tazele "Tikanik Tazele" --ozet "Şu an 7 iş bekliyor." >/dev/null 2>&1
{ [ $? -eq 0 ] && grep -qx "⚠️ TIKANDI · Tikanik Tazele" "$KAPIMDA_DOSYA" && grep -q "Şu an 7 iş bekliyor" "$KAPIMDA_DOSYA"; } \
  && ok "T19 tıkanmış (⚠️) kart da tazelenir, damgası korunur" || kotu "T19 tıkanmış kart tazelemesi"

# ── RED yolları ───────────────────────────────────────────────────────────────
_tz_env; touch "$KAPIMDA_DOSYA"
out="$(kos tazele "Hic Olmayan Kart" --ozet "bir şey" 2>&1)"; rc=$?
{ [ "$rc" -eq 1 ] && [ -n "$out" ]; } && ok "T20 kart yoksa RC 1 + tek satır sebep (sessiz başarı yok)" || kotu "T20 hayalet tazeleme"
_tz_ac "Lint Karti" >/dev/null 2>&1
cp "$KAPIMDA_DOSYA" "$TZD/lint-once.md"
kos tazele "Lint Karti" >/dev/null 2>&1
[ $? -eq 2 ] && ok "T21 alansız tazele → RC 2 (kullanım)" || kotu "T21 alansız tazele geçti"
kos tazele "Lint Karti" --ozet "şu dosyaya bak: /config/projects/x.sh" >/dev/null 2>&1
[ $? -eq 1 ] && ok "T22 jargon/yol → RED (lint tazelemede de koşar)" || kotu "T22 jargon kaçtı"
kos tazele "Lint Karti" --engel "$SAHTE" >/dev/null 2>&1
[ $? -eq 1 ] && ok "T23 sır-deseni → RED" || kotu "T23 sır kaçtı"
kos tazele "Lint Karti" --ozet "$(printf 'x%.0s' $(seq 1 700))" >/dev/null 2>&1
[ $? -eq 1 ] && ok "T24 uzunluk → RED" || kotu "T24 uzunluk kaçtı"
cmp -s "$TZD/lint-once.md" "$KAPIMDA_DOSYA" && ok "T25 RED yolları dosyaya HİÇ yazmadı (fail-closed)" || kotu "T25 RED yolu dosyayı kirletti"
kos lint >/dev/null 2>&1; [ $? -eq 0 ] && ok "T26 tazelenmiş dosya lint'ten geçer" || kotu "T26 tazeleme lint'i kırdı"

echo; echo "── SONUÇ: $gecti geçti · $dustu kaldı ──"
[ "$dustu" -eq 0 ]
