#!/usr/bin/env bash
# hat-durtme.test.sh — kapı bekçisinin karar kuralları (EK-A §A3 1-7) + INERT sözleşmesi.
#
# NİÇİN BU TESTLER: hattın tamamı "ne zaman koşulur, ne zaman koşulmaz" kararına asılı. Yanlış
# karar iki yönde de pahalı: fazla koşarsa çöp seli üretir (R1), az koşarsa sessizce ölür (R4 —
# bu sistemde İKİ kez gerçekleşti: hat 8 gün, RASAT 5 gün). Bu yüzden karar motoru saf tutuldu
# ve yedi kuralın her biri ayrı kapıyla kilitlendi.
#
# Koşum: bash hat-durtme.test.sh   (bağımlılık: python3, flock)

set -uo pipefail
BURASI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DURTME="$BURASI/hat-durtme.sh"
IZLE="$BURASI/hat-izle.sh"
gecen=0; kalan=0

bekle() { if [ "$2" = "0" ]; then printf '  ✓ %s\n' "$1"; gecen=$((gecen+1));
          else printf '  ✗ %s%s\n' "$1" "${3:+ — $3}"; kalan=$((kalan+1)); fi; }
icerir() { case "$1" in *"$2"*) printf 0 ;; *) printf 1 ;; esac; }

# Her kapı temiz bir sahte proje alır (git kökü şart — hat-yolu.lib.sh fail-closed).
alan_kur() {
  local d; d="$(mktemp -d)"
  git -C "$d" init -q 2>/dev/null
  mkdir -p "$d/_agents/handoff"
  printf '%s' "$d"
}

# Sahte koşucu: RC'yi dosyadan okur → başarı/başarısızlık senaryoları LLM çağırmadan kurulur.
kosucu_kur() {
  local d="$1" rc="$2" f="$1/kosucu.sh"
  cat >"$f" <<EOF
#!/usr/bin/env bash
echo "sahte-kosucu: adim=\$1 tur=\$2" >>"$d/kosucu.log"
exit $rc
EOF
  chmod +x "$f"; printf '%s' "$f"
}

durt() {  # <alan> <saat> [ek-argumanlar...]
  local d="$1" saat="$2"; shift 2
  HAT_ROOT="$d" HAT_SIMDI="2026-07-28T$saat" HAT_KOSUCU="${KOSUCU:-}" \
    bash "$DURTME" "$@" 2>&1
}

printf '\n  hat-durtme — kapı bekçisi testleri\n\n'

# ── G0 · sözdizimi ───────────────────────────────────────────────────────────────────────────
bash -n "$DURTME"; bekle "G0a hat-durtme.sh sözdizimi" "$?"
bash -n "$IZLE";   bekle "G0b hat-izle.sh sözdizimi"   "$?"

# ── G1 · INERT sözleşmesi: açma bayrağı yokken HİÇBİR ŞEY koşmaz ─────────────────────────────
# Bu, F4'ün tek değişmezi. Kırılırsa hat kendiliğinden canlanır — en pahalı regresyon.
D="$(alan_kur)"; KOSUCU="$(kosucu_kur "$D" 0)"
CIKTI="$(durt "$D" "10:00")"
bekle "G1a bayraksız koşu YOK (INERT)" "$(icerir "$CIKTI" "KAPALI (INERT)")" "$CIKTI"
bekle "G1b koşucu hiç çağrılmadı" "$([ ! -f "$D/kosucu.log" ] && echo 0 || echo 1)"

# ── G2 · açıldıktan sonra koşar (Kural 7 penceresi içinde) ───────────────────────────────────
durt "$D" "10:00" --ac "test" >/dev/null
CIKTI="$(durt "$D" "10:00")"
bekle "G2a açık hatta tarama koştu" "$(icerir "$CIKTI" "tamamlandı")" "$CIKTI"
bekle "G2b koşucu fiilen çağrıldı" "$([ -f "$D/kosucu.log" ] && echo 0 || echo 1)"

# ── G3 · Kural 1: aynı gün İKİNCİ tur YOK ────────────────────────────────────────────────────
CIKTI="$(durt "$D" "11:00")"
bekle "G3 tamamlanan adım aynı gün tekrar koşmaz" "$(icerir "$CIKTI" "bugun-tamamlandi")" "$CIKTI"

# ── G4 · Kural 7: hak penceresi (09:00 öncesi / 18:00 sonrası kapalı) ────────────────────────
D="$(alan_kur)"; KOSUCU="$(kosucu_kur "$D" 0)"; durt "$D" "10:00" --ac "test" >/dev/null
CIKTI="$(durt "$D" "07:00")"
bekle "G4a 07:00'de hak yok" "$(icerir "$CIKTI" "hak-penceresi-disi")" "$CIKTI"
CIKTI="$(durt "$D" "19:00")"
bekle "G4b 19:00'da hak yok" "$(icerir "$CIKTI" "hak-penceresi-disi")" "$CIKTI"
bekle "G4c pencere dışında koşucu çağrılmadı" "$([ ! -f "$D/kosucu.log" ] && echo 0 || echo 1)"

# ── G5 · Kural 3+4: başarısızlık → 3 deneme → pes ────────────────────────────────────────────
D="$(alan_kur)"; KOSUCU="$(kosucu_kur "$D" 2)"; durt "$D" "09:00" --ac "test" >/dev/null
CIKTI="$(durt "$D" "09:00")"
bekle "G5a 1. başarısızlık → tekrar denenecek" "$(icerir "$CIKTI" "deneme 1/3")" "$CIKTI"
# Bekleme aralığı dolmadan dürtülürse koşmamalı (Kural 3'ün artan-aralık yarısı)
CIKTI="$(durt "$D" "09:10")"
bekle "G5b bekleme aralığı dolmadan koşmaz" "$(icerir "$CIKTI" "bekleme-araligi")" "$CIKTI"
CIKTI="$(durt "$D" "10:00")"
bekle "G5c aralık dolunca 2. deneme" "$(icerir "$CIKTI" "deneme 2/3")" "$CIKTI"
CIKTI="$(durt "$D" "13:00")"
bekle "G5d 3. denemede PES" "$(icerir "$CIKTI" "PES EDİLDİ")" "$CIKTI"
# Kural 4: sessiz pes YOK — çıkış kodu vermeli ki cron/bekçi duysun (federation dersi)
HAT_ROOT="$D" HAT_SIMDI="2026-07-28T13:30" HAT_KOSUCU="$KOSUCU" bash "$DURTME" >/dev/null 2>&1
bekle "G5e pes sonrası o gün bir daha denenmez" "$?"

# ── G6 · Kural 4 · sesi çıkıyor mu: pes ANINDA RC≠0 ─────────────────────────────────────────
D="$(alan_kur)"; KOSUCU="$(kosucu_kur "$D" 2)"; durt "$D" "09:00" --ac "t" >/dev/null
durt "$D" "09:00" >/dev/null; durt "$D" "10:00" >/dev/null
HAT_ROOT="$D" HAT_SIMDI="2026-07-28T13:00" HAT_KOSUCU="$KOSUCU" bash "$DURTME" >/dev/null 2>&1
rc=$?
bekle "G6 pes anında RC=1 (sessiz ölmez)" "$([ "$rc" = "1" ] && echo 0 || echo 1)" "rc=$rc"

# ── G7 · Kural 5: MUCİT saat değil SAYI ile tetiklenir ──────────────────────────────────────
D="$(alan_kur)"; KOSUCU="$(kosucu_kur "$D" 0)"; durt "$D" "09:00" --ac "t" >/dev/null
CIKTI="$(durt "$D" "09:00")"
bekle "G7a malzeme yokken MUCİT koşmaz" "$(icerir "$CIKTI" "suzulmemis-malzeme-yok")" "$CIKTI"
D="$(alan_kur)"; KOSUCU="$(kosucu_kur "$D" 0)"; durt "$D" "09:00" --ac "t" >/dev/null
printf '{"id":"b1","durum":"ham"}\n' >"$D/_agents/handoff/bulgu-havuzu.jsonl"
CIKTI="$(durt "$D" "09:00")"
bekle "G7b malzeme varken MUCİT koşar" "$(icerir "$CIKTI" "mucit  🟢")" "$CIKTI"

# ── G8 · --kuru: karar hesaplanır ama HİÇBİR ŞEY koşmaz ─────────────────────────────────────
D="$(alan_kur)"; KOSUCU="$(kosucu_kur "$D" 0)"; durt "$D" "09:00" --ac "t" >/dev/null
CIKTI="$(durt "$D" "09:00" --kuru)"
bekle "G8a kuru koşu kararı gösterir" "$(icerir "$CIKTI" "KOŞARDI")" "$CIKTI"
bekle "G8b kuru koşuda koşucu çağrılmadı" "$([ ! -f "$D/kosucu.log" ] && echo 0 || echo 1)"

# ── G9 · gün değişince taze hak (dünün pes'i bugünü kilitlemez) ─────────────────────────────
D="$(alan_kur)"; KOSUCU="$(kosucu_kur "$D" 2)"; durt "$D" "09:00" --ac "t" >/dev/null
durt "$D" "09:00" >/dev/null; durt "$D" "10:00" >/dev/null; durt "$D" "13:00" >/dev/null
KOSUCU="$(kosucu_kur "$D" 0)"
CIKTI="$(HAT_ROOT="$D" HAT_SIMDI="2026-07-29T09:00" HAT_KOSUCU="$KOSUCU" bash "$DURTME" 2>&1)"
bekle "G9 ertesi gün hak yenilenir" "$(icerir "$CIKTI" "tamamlandı")" "$CIKTI"

# ── G10 · İ1: git kökü olmayan dizinde ortak dizine YAZMAZ ──────────────────────────────────
D="$(mktemp -d)"   # git init YOK
CIKTI="$(cd "$D" && HAT_SIMDI="2026-07-28T10:00" bash "$DURTME" 2>&1; printf '|rc=%s' "$?")"
bekle "G10a git-siz dizinde RC=2" "$(icerir "$CIKTI" "|rc=2")" "$CIKTI"
bekle "G10b ortak dizine hat-durum.json düşmedi" \
      "$([ ! -f /config/.claude/hat-durum.json ] && echo 0 || echo 1)"

# ── G11 · pano salt-okur ve dört işareti basıyor ────────────────────────────────────────────
D="$(alan_kur)"; KOSUCU="$(kosucu_kur "$D" 0)"; durt "$D" "09:00" --ac "t" >/dev/null
durt "$D" "09:00" >/dev/null
ONCE="$(find "$D/_agents" -type f | sort | xargs sha256sum 2>/dev/null | sha256sum)"
CIKTI="$(HAT_ROOT="$D" HAT_SIMDI="2026-07-28T09:30" bash "$IZLE" 2>&1)"
SONRA="$(find "$D/_agents" -type f | sort | xargs sha256sum 2>/dev/null | sha256sum)"
bekle "G11a pano tur numarasını gösterir" "$(icerir "$CIKTI" "tur: t20260728-1")" "$CIKTI"
bekle "G11b pano hiçbir şeye YAZMAZ" "$([ "$ONCE" = "$SONRA" ] && echo 0 || echo 1)"
CIKTI="$(HAT_ROOT="$D" HAT_SIMDI="2026-07-28T09:30" bash "$IZLE" --ozet 2>&1)"
bekle "G11c tek-satır özet çalışır" "$(icerir "$CIKTI" "hat:")" "$CIKTI"

# ── G12 · --kapat INERT'e geri döndürür (geri-alınabilirlik) ────────────────────────────────
D="$(alan_kur)"; KOSUCU="$(kosucu_kur "$D" 0)"; durt "$D" "09:00" --ac "t" >/dev/null
durt "$D" "09:00" --kapat >/dev/null
D2="$D"; rm -f "$D2/_agents/handoff/hat-durum.json"
CIKTI="$(durt "$D" "10:00")"
bekle "G12 kapatınca yine INERT" "$(icerir "$CIKTI" "KAPALI (INERT)")" "$CIKTI"

printf '\n  özet: %d geçti · %d kaldı\n\n' "$gecen" "$kalan"
[ "$kalan" -eq 0 ]
