#!/usr/bin/env bash
# mutasyon-olc.sh — sınav, bozuk aracı YAKALIYOR mu? Aracın geçici kopyaları tek tek bozulur; her bozuk kopyada
# sınav KIRMIZI dönmelidir. Gerçek araca ve gerçek kayda dokunulmaz.
# rc: 0 bütün bozukluklar yakalandı · 1 en az biri kaçtı · 3 ölçülemedi
set -uo pipefail
KOK="$(git rev-parse --show-toplevel)"; SUT="$KOK/canli-sayfa/scripts/canli-sayfa.sh"; SINAV="$KOK/canli-sayfa/scripts/canli-sayfa.test.sh"
T="$(mktemp -d /tmp/canli-sayfa-mut.XXXXXX)" || exit 3
trap 'find "$T" -delete' EXIT
python3 - "$SUT" "$T" <<'PY' || { echo "ÖLÇÜLEMEDİ · bozuk kopyalar üretilemedi"; exit 3; }
import sys
s = open(sys.argv[1], encoding="utf-8").read()
M = {
 "01-canli-olmayan-kayda-giriyor": ('*) echo "canli-degil ${kod:-cevap-yok}"; return 3 ;;', '*) echo "kapali ${kod:-cevap-yok}"; return 0 ;;'),
 "02-kapisiz-sayfa-onaysiz-giriyor": ('if [ "$giris" = acik ] && [ "$acik" != evet ]; then', 'if false; then'),
 "03-https-aranmiyor": ('if u.scheme != "https": sys.exit(', 'if False: sys.exit('),
 "04-soru-isareti-aranmiyor": ('if u.query or u.fragment or "?" in h or "#" in h: sys.exit(', 'if False: sys.exit('),
 "05-kullanici-adi-aranmiyor": ('if u.username or u.password or "@" in u.netloc: sys.exit(', 'if False: sys.exit('),
 "06-port-aranmiyor": ('if u.port: sys.exit(', 'if False: sys.exit('),
 "07-nokta-nokta-aranmiyor": ('if any(p in (".", "..") for p in y.split("/")): sys.exit(', 'if False: sys.exit('),
 "08-sir-deseni-aranmiyor": ("if printf '%s' \"$d\" | grep -qEi '(parola", "if false && printf '%s' \"$d\" | grep -qEi '(parola"),
 "09-sultan-dili-aranmiyor": ("if printf '%s' \"$d\" | grep -qE '`", "if false && printf '%s' \"$d\" | grep -qE '`"),
 "10-emekli-menude-gorunuyor": ('if hepsi or k["durum"] == "canli": S.append(k)', 'S.append(k)'),
 "11-bozuk-kayit-yutuluyor": ('B.append(os.path.basename(f)); continue', 'continue'),
 "12-ilk-tarih-korunmuyor": ('"eklendi": eski.get("eklendi") if isinstance(eski.get("eklendi"), str) and eski.get("eklendi") else simdi,', '"eklendi": simdi,'),
 "13-kapi-degisimi-gorulmuyor": ('elif [ "$y" != "$g" ]; then', 'elif false; then'),
 "14-kilitli-sayfa-acik-sayiliyor": ('401|403) echo "kapali $kod"', '401|403) echo "acik $kod"'),
 "15-adressiz-yonlenme-kapali-sayiliyor": ('"") echo "olculemedi $kod-yonlenme-adresi-yok"; return 3 ;;', '"") echo "kapali $kod"; return 0 ;;'),
 "16-baska-yere-yonlenen-kapali-sayiliyor": ('*) echo "yonleniyor $kod"', '*) echo "kapali $kod"'),
 "17-ad-kelime-sayisi-aranmiyor": ('[ "$(printf \'%s\' "$ad" | wc -w)" -le 4 ] ||', 'true ||'),
 "18-kutu-zorunlu-degil": ('printf \'%s\' "$kutu" | grep -qE \'^[a-z0-9][a-z0-9-]{0,30}$\' ||', 'true ||'),
 "19-ekleyen-zorunlu-degil": ('printf \'%s\' "$ekleyen" | grep -qE', 'true || printf \'%s\' "$ekleyen" | grep -qE'),
 "20-https-olmayan-kayit-menuye-geciyor": (' or not k["adres"].startswith("https://")', ''),
 "21-emekli-gerekcesiz": ('[ "${#gerekce}" -ge 10 ] ||', 'true ||'),
 "22-uzunluk-aranmiyor": ('[ "${#d}" -le "$n" ] ||', 'true ||'),
 "23-dogrula-acilmayani-gormuyor": ('if [ "$r" -ne 0 ]; then echo "✗ AÇILMIYOR', 'if false; then echo "✗ AÇILMIYOR'),
 "25-ayri-adresler-ayni-dosyaya-dusuyor": ('urllib.parse.quote(sys.argv[1][len("https://"):], safe=".-_~")', 'urllib.parse.quote(sys.argv[1][len("https://"):], safe=".-_~").replace("%2F", "_")'),
 "26-baska-adresin-kaydi-eziliyor": ('ayni_adres_mi "$f" "$a" || hata "bu dosya adında BAŞKA bir adresin kaydı var; üzerine yazılmadı: $f" 3', 'true'),
 "27-emekli-baska-adresin-kaydina-dokunuyor": ('ayni_adres_mi "$f" "$a" || hata "bu dosya adında BAŞKA bir adresin kaydı var; dokunulmadı: $f" 3', 'true'),
 "28-emekli-gerekcesi-suzulmuyor": ('    metin_denetle "gerekçe" "$gerekce" 200', '    true'),
 "29-degersiz-secenek-asili-birakiyor": ('[ "$#" -ge 2 ] || hata "$1 bir değer ister"', 'true'),
 "30-olcer-girdiyi-yutuyor": ('_ "$a" 2>/dev/null </dev/null)"', '_ "$a" 2>/dev/null)"'),
 "31-tek-cumle-aranmiyor": ("if printf '%s' \"$2\" | grep -qE '[.!?;…][[:space:]]+[^[:space:]]'; then", "if false; then"),
 "32-tek-cumle-denetimi-cagrilmiyor": ('; tek_cumle_denetle "ne" "$ne"', ''),
 "24-eksik-alanli-kayit-menuye-geciyor": ('if not all(isinstance(k.get(a), str) and k[a] for a in ALAN): raise ValueError', 'pass'),
}
for ad, (a, b) in M.items():
    assert s.count(a) == 1, (ad, s.count(a))
    open(f"{sys.argv[2]}/{ad}.sh", "w", encoding="utf-8").write(s.replace(a, b))
PY
k=0
for b in "$T"/*.sh; do
  ad="$(basename "$b" .sh)"
  cikti="$(CANLI_SAYFA_TEST_SUT="$b" timeout 400 bash "$SINAV" 2>&1)"; rc=$?
  [ "$rc" -ne 124 ] || { echo "✗ SÜRE DOLDU: $ad"; k=1; continue; }
  n="$(printf '%s\n' "$cikti" | grep -c '^  ✗')"
  if [ "$rc" -ne 0 ] && [ "$n" -ge 1 ]; then echo "✓ yakalandı: $ad ($n kapı kırmızı)"; else echo "✗ KAÇTI: $ad (rc=$rc)"; k=1; fi
  printf '%s\n' "$cikti" | grep '^  ✗' | head -2 | sed 's/^/     /'
done
cikti="$(bash "$SINAV" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then echo "✓ karşı sınama: gerçek araç aynı sınavdan yeşil geçiyor ($(printf '%s\n' "$cikti" | tail -1))"; else echo "✗ gerçek araç kırmızı"; k=1; fi
exit "$k"
