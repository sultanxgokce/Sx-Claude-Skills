#!/usr/bin/env bash
# bekci-yorum.test.sh — bekçi işareti YALNIZ cron satırının sonunda sayılır; metninde işaret geçen YORUM satırı korunur (hermetik).
#
# Niçin (17 Eki 2026, BÂNİ bulgusu · kart terminal-onar-bekci-yorum-korur): kanon crontab-abc'nin açıklama yorumu
# "(işaret yorumu '# terminal-onar-bekci' dahil)" diyordu; bekci_kur canlı crontab'ı düzeltirken o YORUMU bekçi satırı sandı,
# yerine bekçi satırını yazdı ve asıl satırı "çift kopya" sayıp sildi (canlı code kutusu, 20:26). bekci_kurulu da asıl satır
# yokken yorum yüzünden "kurulu" diyebilirdi. Sahte crontab (okur + yazar); gerçek crontab'a DOKUNULMAZ.
set -u
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gecen=0; kalan=0
kapi() { if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
T=$(mktemp -d); trap 'python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$T"' EXIT
mkdir -p "$T/bin" "$T/proje" "$T/durum"
CT="$T/crontab.txt"
printf '#!/usr/bin/env bash\ncase "$1" in -l) cat "%s" 2>/dev/null;; -) cat > "%s";; esac\nexit 0\n' "$CT" "$CT" > "$T/bin/crontab"
chmod +x "$T/bin/crontab"
# ortak.sh PATH'in başına /usr/bin koyar → sahteler kopyanın sonunda öne alınır (bekci-iz.test.sh dersi)
M="$T/calisma"; mkdir -p "$M"; cp -r "$KOK/scripts" "$M/"
printf '\nexport PATH="$TO_SAHTE_BIN:$PATH"\n' >> "$M/scripts/ortak.sh"
kos() { # ortak.sh kaynaklanır, verilen kabuk kodu koşar
  env -i PATH="$T/bin:/usr/bin:/bin" TO_SAHTE_BIN="$T/bin" HOME="$T" TO_KUTU=sinav TO_PROJE="$T/proje" TO_DURUM_DIZ="$T/durum" \
    TO_CRONTAB="$T/bin/crontab" TO_BECERI_KOK="$M" CORTEX_ACCESS_ENV="$T/yok.env" TO_KAPI_PORT=1 TO_TTYD_SOKET="$T/yok.sock" \
    bash -c ". \"\$TO_BECERI_KOK/scripts/ortak.sh\" >/dev/null 2>&1; $1"
}
BEKCI="$(kos 'printf %s "$BEKCI_SATIR"')"; ACILIS="$(kos 'printf %s "$ACILIS_SATIR"')"
[ -n "$BEKCI" ] && [ -n "$ACILIS" ] || { echo "✗ fikstür: BEKCI_SATIR/ACILIS_SATIR okunamadı"; exit 1; }
# kanon crontab-abc'nin GERÇEK yorum satırları (720-725, 17 Eki origin/main) — ikisi işaret metnini taşır
Y1='# ── 🖥️ terminal-onar BEKÇİSİ (canlıda vardı, kanonda yoktu → kayda alındı 13 Eki 2026, kart cron-canli-kayit · SERDAR) ──'
Y2="# tutulur (işaret yorumu '# terminal-onar-bekci' dahil) — yoksa bekci_kurulu() eşleşmez ve ikinci kopya doğar."
Y3="  # girintili yorum da yorumdur  # terminal-onar-bekci"
Y4="# @reboot satırı için açıklama  # terminal-onar-acilis"
kur() { kos 'bekci_kur "$TO_PROJE/.oda/cron" canli'; }
say() { grep -cxF -- "$1" "$CT"; }

echo "── Y kanon yorumu + doğru bekçi satırı: hiçbir şey değişmez"
printf 'PATH=/usr/bin:/bin\n%s\n%s\n%s\n%s\n%s\n0 3 * * * echo gece\n' "$Y1" "$Y2" "$Y3" "$BEKCI" "$Y4" > "$CT"; cp "$CT" "$T/once.txt"
out="$(kur)"
kapi "Y1 crontab BAYT BAYT aynı kaldı (yorum bekçi satırı sanılmadı)" "aynı" "$(cmp -s "$CT" "$T/once.txt" && echo aynı || echo "DEĞİŞTİ: $(diff "$T/once.txt" "$CT" | head -3 | tr '\n' ' ')")"
kapi "Y1b sonuç 'canlı crontab düzeltildi' DEMEDİ" "0" "$(printf '%s' "$out" | grep -c 'canlı crontab düzeltildi')"
kapi "Y2 işaret metinli kanon yorumu korundu" "1" "$(say "$Y2")"
kapi "Y2b girintili yorum korundu" "1" "$(say "$Y3")"
kapi "Y2c açılış işaretli yorum korundu" "1" "$(say "$Y4")"
kapi "Y2d asıl bekçi satırı TEK ve yerinde" "1" "$(say "$BEKCI")"

echo "── Y yalnız yorum işareti taşıyor, asıl satır yok"
printf '%s\n%s\n' "$Y1" "$Y2" > "$CT"
kapi "Y3 bekci_kurulu: asıl satır yokken 'kurulu' DEMEZ (yorum sayılmaz)" "1" "$(kos 'bekci_kurulu; echo $?')"
kur >/dev/null
kapi "Y3b bekci_kur asıl satırı EKLEDİ" "1" "$(say "$BEKCI")"
kapi "Y3c yorum yine korundu" "1" "$(say "$Y2")"
kapi "Y3d artık kurulu" "0" "$(kos 'bekci_kurulu; echo $?')"

echo "── eski davranış korunur: çift kopya tekilleşir · eski yol kanoniğe çevrilir"
printf '%s\n%s\n%s\n' "$BEKCI" "$Y2" "$BEKCI" > "$CT"; kur >/dev/null
kapi "Y4 iki asıl satır → tek" "1" "$(say "$BEKCI")"
kapi "Y4b aradaki yorum korundu" "1" "$(say "$Y2")"
printf '%s\n* * * * * bash /eski/ortak/yol/bekci.sh  # terminal-onar-bekci\n' "$Y2" > "$CT"; out="$(kur)"
kapi "Y5 eski yollu satır kanonik satıra çevrildi" "1" "$(say "$BEKCI")"
kapi "Y5b eski yol kalmadı" "0" "$(grep -c '/eski/ortak/yol' "$CT")"
kapi "Y5c bu kez 'düzeltildi' dedi (gerçek değişiklik)" "1" "$(printf '%s' "$out" | grep -c 'canlı crontab düzeltildi')"

echo "── .oda/cron (kalıcı dosya) da aynı kural"
printf 'TZ=Europe/Istanbul\n%s\n%s\n%s\n%s\n' "$Y2" "$Y4" "$BEKCI" "$ACILIS" > "$T/proje/.oda/cron"; cp "$T/proje/.oda/cron" "$T/oda-once.txt"
printf '%s\n' "$BEKCI" > "$CT"; kur >/dev/null
kapi "Y6 .oda/cron bayt bayt aynı (iki yorum korundu)" "aynı" "$(cmp -s "$T/proje/.oda/cron" "$T/oda-once.txt" && echo aynı || echo DEĞİŞTİ)"

echo "── mutasyon (kopya üstünde)"
mut() { # $1 ad · $2 sed · $3 beklenen-ısırma-kapısı komutu
  local MM="$T/mut"; python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$MM"; cp -r "$M" "$MM"
  sed -i "$2" "$MM/scripts/ortak.sh"
  if cmp -s "$MM/scripts/ortak.sh" "$M/scripts/ortak.sh"; then kalan=$((kalan+1)); echo "  ✗ $1: sed hiçbir şeyi değiştirmedi"; return; fi
  if TO_BECERI_KOK_M="$MM" eval "$3"; then kalan=$((kalan+1)); echo "  ✗ $1: mutant YAŞIYOR"; else gecen=$((gecen+1)); echo "  ✓ $1: mutant ısırıldı"; fi
}
kosm() { env -i PATH="$T/bin:/usr/bin:/bin" TO_SAHTE_BIN="$T/bin" HOME="$T" TO_KUTU=sinav TO_PROJE="$T/proje" TO_DURUM_DIZ="$T/durum" \
    TO_CRONTAB="$T/bin/crontab" TO_BECERI_KOK="$T/mut" CORTEX_ACCESS_ENV="$T/yok.env" TO_KAPI_PORT=1 TO_TTYD_SOKET="$T/yok.sock" \
    bash -c ". \"\$TO_BECERI_KOK/scripts/ortak.sh\" >/dev/null 2>&1; $1"; }
y1_aynimi() { printf '%s\n%s\n%s\n' "$Y1" "$Y2" "$BEKCI" > "$CT"; cp "$CT" "$T/m-once.txt"; kosm 'bekci_kur "$TO_PROJE/.oda/cron" canli' >/dev/null; cmp -s "$CT" "$T/m-once.txt"; }
mut "M1 desen eski (işaret satırın HERHANGİ yerinde) olunca yorum bekçi satırına çevrilir" \
  "s|^BEKCI_DESEN=.*|BEKCI_DESEN='# terminal-onar-bekci'|" y1_aynimi
kurulu_degil() { printf '%s\n' "$Y2" > "$CT"; [ "$(kosm 'bekci_kurulu; echo $?')" = 1 ]; }
mut "M2 bekci_kurulu eski desene dönünce yorum yüzünden 'kurulu' der" \
  "s|^bekci_kurulu() {.*|bekci_kurulu() { \${TO_CRONTAB:-crontab} -l 2>/dev/null \| grep -q '# terminal-onar-bekci'; }|" kurulu_degil

echo; echo "GECEN=$gecen DUSEN=$kalan"
[ "$kalan" -eq 0 ]
