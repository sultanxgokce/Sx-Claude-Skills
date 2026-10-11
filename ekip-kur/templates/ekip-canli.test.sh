#!/usr/bin/env bash
# ekip-canli.test.sh — canlılık probunun sınavı. HERMETİK: ayrı tmux sunucusu (-L) + sahte registry; gerçek koltuklara dokunmaz.
set -uo pipefail
D="$(cd "$(dirname "$0")" && pwd)"; T="$(mktemp -d)"; SOCK="canli-test-$$"
trap 'command tmux -L "$SOCK" kill-server 2>/dev/null; rm -r "$T"' EXIT
cat > "$T/reg.yaml" <<Y
uyeler:
  - id: DOLU
    tmux: "DOLU:0"
  - id: BOS
    tmux: "BOS:0"
  - id: DIYALOG
    tmux: "DIYALOG:0"
  - id: KAPALI
    tmux: "KAPALI:0"
Y
tm() { command tmux -L "$SOCK" "$@"; }
# ⚠️ bash -c SON komutu exec-eder (ara kademe yutulur) → her kademeye '; true' eklenir ki zincir pane(bash)→bash→claude (torun) olsun
tm new-session -d -s DOLU    "bash -c 'bash -c \"bash -c \\\"exec -a claude sleep 300\\\"; true\"; true'"
tm new-session -d -s BOS     "sleep 300"
tm new-session -d -s DIYALOG "bash -c 'printf \"\\n  dialog waiting · Showing detailed transcript\\n\"; exec -a claude sleep 300'"
sleep 1
export EKIP_REGISTRY="$T/reg.yaml" EKIP_TMUX_SOCK="$SOCK"; unset TMUX_PANE
G=0; F=0
ok() { G=$((G+1)); echo "  ✓ $1"; }; no() { F=$((F+1)); echo "  ✗ $1 — $2"; }
run() { OUT="$(bash "$D/ekip-canli.sh" "$@" 2>/dev/null)"; RC=$?; }

run DOLU --kontrol DOLU;    [ $RC = 0 ] && grep -q "^DOLU	canli	torun" <<<"$OUT" && ok "dolu koltuk torunda canlı" || no "dolu" "$OUT rc=$RC"
run BOS --kontrol DOLU;     [ $RC = 0 ] && grep -q "^BOS	yok" <<<"$OUT" && ok "boş koltuk yok" || no "boş" "$OUT rc=$RC"
run DIYALOG --kontrol DOLU; [ $RC = 0 ] && grep -q "^DIYALOG	bekliyor" <<<"$OUT" && ok "diyalogdaki koltuk bekliyor" || no "diyalog" "$OUT rc=$RC"
run KAPALI --kontrol DOLU;  [ $RC = 0 ] && grep -q "^KAPALI	oturum-yok" <<<"$OUT" && ok "oturumsuz koltuk oturum-yok (negatif kontrol)" || no "kapalı" "$OUT rc=$RC"
run BOS;                    [ $RC = 3 ] && grep -q "olcemedim" <<<"$OUT" && ok "kontrolsüz → ölçemedim rc=3, 'yok' demedi" || no "kontrolsüz" "$OUT rc=$RC"
run BOS --kontrol BOS;      [ $RC = 3 ] && grep -q "prob kör" <<<"$OUT" && ok "kontrol koltuğu boşsa prob kör → ölçemedim" || no "kör" "$OUT rc=$RC"
run BOS --kontrol DOLU --derinlik 1; [ $RC = 3 ] && ok "derinlik 1'de torun görülmez → kontrol düşer → ölçemedim (yok DEĞİL)" || no "derinlik" "$OUT rc=$RC"
EKIP_AJAN_RE='ZZZ' run BOS --kontrol DOLU; [ $RC = 3 ] && ok "mutasyon: desen öldürülünce prob kör → ölçemedim" || no "mutasyon-desen" "$OUT rc=$RC"
run all --kontrol DOLU;     [ $RC = 0 ] && [ "$(wc -l <<<"$OUT")" = 4 ] && ok "all dört satır" || no "all" "$OUT rc=$RC"
run YOKBIRI --kontrol DOLU; [ $RC = 1 ] && ok "registry dışı üye rc=1" || no "yok-üye" "rc=$RC"
# metin-içi yanlış pozitif: ekranda 'dialog waiting' sözü SATIR ORTASINDA geçen dolu koltuk → canli kalmalı
tm new-session -d -s DOLU2 "bash -c 'printf \"mektup: ekranda dialog waiting görüldü\\n\"; exec -a claude sleep 300'"
printf '  - id: DOLU2\n    tmux: "DOLU2:0"\n' >> "$T/reg.yaml"; sleep 0.3
run DOLU2 --kontrol DOLU;   [ $RC = 0 ] && grep -q "^DOLU2	canli" <<<"$OUT" && ok "metin içi 'dialog waiting' yanlış pozitif ÜRETMEZ" || no "yanlış-pozitif" "$OUT rc=$RC"
# --- SINIRDA (BASİRET, 11 Ekim): gerçek ekrandaki birebir baytlar: "  ⎿" + boşluk + BÖLÜNMEZ boşluk (c2 a0) + metin ---
# Ekran satırları dosyaya yazılıp cat'lenir (printf kaçışları tmux komut satırında bozulmasın diye).
NB=$'\xc2\xa0'
printf '● iş yapıyorum\n  ⎿ %sYou'"'"'ve reached your Fable limit. Run /usage-credits to continue or switch\n     models with /model.\n' "$NB" > "$T/sinir.txt"
printf '  ⎿ %sYou'"'"'ve reached your Fable limit. Run /usage-credits\n  ⎿ %sSet model to Opus 5.5\n' "$NB" "$NB" > "$T/acildi.txt"
printf '● ekranları bastım\n  ⎿ %s--- CARSI\n       ⎿ %sYou'"'"'ve reached your Fable limit. Run /usage-credits\n' "$NB" "$NB" > "$T/alinti.txt"
for k in SINIR ACILDI ALINTI; do
  f="$(tr A-Z a-z <<<"$k")"; [ "$k" = ACILDI ] && f=acildi
  tm new-session -d -s "$k" "bash -c 'cat $T/$f.txt; exec -a claude sleep 300'"
  printf '  - id: %s\n    tmux: "%s:0"\n' "$k" "$k" >> "$T/reg.yaml"
done; sleep 0.5
run SINIR --kontrol DOLU;  [ $RC = 0 ] && grep -q "^SINIR	sinirda	" <<<"$OUT" && ok "son sonuç sınır mesajı → sinirda" || no "sinirda" "$OUT rc=$RC"
run ACILDI --kontrol DOLU; [ $RC = 0 ] && grep -q "^ACILDI	canli" <<<"$OUT" && ok "sınırdan sonra yeni sonuç (model değişti) → canli" || no "acildi" "$OUT rc=$RC"
run ALINTI --kontrol DOLU; [ $RC = 0 ] && grep -q "^ALINTI	canli" <<<"$OUT" && ok "başka ekranın ALINTISI yanlış pozitif ÜRETMEZ (reisin ekranı)" || no "alinti" "$OUT rc=$RC"
run SINIR --kontrol SINIR; [ $RC = 0 ] && grep -q "^SINIR	sinirda" <<<"$OUT" && ok "sınırdaki koltuk pozitif kontrol olabilir (süreç var → prob kör değil)" || no "sinir-kontrol" "$OUT rc=$RC"
EKIP_SINIR_RE='ZZZ' run SINIR --kontrol DOLU; grep -q "^SINIR	canli" <<<"$OUT" && ok "mutasyon: sınır deseni öldürülünce sinirda kaybolur (kapı süs değil)" || no "mut-sinir" "$OUT"
EKIP_SINIR_RE="^  ⎿ +You've (reached|hit) your [^ ]+ limit" run SINIR --kontrol DOLU; grep -q "^SINIR	canli" <<<"$OUT" && ok "ilk (hatalı) desen bölünmez boşluğu kaçırır — kanıt saklı" || no "mut-eski" "$OUT"
# --- YENİDEN AÇILIŞ (BASİRET, 11 Ekim 17:3x): --resume ile açılan koltuk dünkü sınır satırını yeniden basar ---
# Gerçek vaka: beş koltuk 17:31'de açıldı, ölçüm dördüne sinirda dedi ve notify mesajları engelledi.
SID_ESKI=11111111-2222-3333-4444-555555555555; SID_YENI=66666666-7777-8888-9999-000000000000
mkdir -p "$T/kayit/proje"; export EKIP_KAYIT_KOK="$T/kayit"
printf '{"timestamp":"2026-10-10T19:24:08.564Z","type":"assistant","isApiErrorMessage":true,"message":{"content":"You'"'"'ve reached your Fable limit."}}\n' > "$T/kayit/proje/$SID_ESKI.jsonl"
tm new-session -d -s ESKISINIR "bash -c 'cat $T/sinir.txt; exec -a \"claude --resume $SID_ESKI\" sleep 300'"
tm new-session -d -s YENISINIR "bash -c 'cat $T/sinir.txt; exec -a \"claude --resume $SID_YENI\" sleep 300'"
printf '  - id: ESKISINIR\n    tmux: "ESKISINIR:0"\n  - id: YENISINIR\n    tmux: "YENISINIR:0"\n' >> "$T/reg.yaml"; sleep 1.2
printf '{"timestamp":"%s","type":"assistant","isApiErrorMessage":true,"message":{"content":"You'"'"'ve reached your Fable limit."}}\n' "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" > "$T/kayit/proje/$SID_YENI.jsonl"
run ESKISINIR --kontrol DOLU; [ $RC = 0 ] && grep -q "^ESKISINIR	canli	.*ÖNCEKİ süreçten" <<<"$OUT" && ok "sınır satırı süreçten ESKİ → canli (yeniden açılış yanlış alarm vermez)" || no "eski-sinir" "$OUT rc=$RC"
run YENISINIR --kontrol DOLU; [ $RC = 0 ] && grep -q "^YENISINIR	sinirda" <<<"$OUT" && ok "sınır kaydı süreçten YENİ → sinirda (gerçek sınır kaçmaz)" || no "yeni-sinir" "$OUT rc=$RC"
# ALINTI (DÜLGER, 11 Ekim): kayıtta sınır cümlesini ALINTILAYAN yeni bir satır (sınav diff'i, mektup) gerçek olay DEĞİLDİR
printf '{"timestamp":"%s","type":"user","message":{"content":"sınav dosyası: You'"'"'ve reached your Fable limit satırı"}}\n' "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" >> "$T/kayit/proje/$SID_ESKI.jsonl"
run ESKISINIR --kontrol DOLU; [ $RC = 0 ] && grep -q "^ESKISINIR	canli" <<<"$OUT" && ok "kayıttaki YENİ ama ALINTI satır (isApiErrorMessage yok) sinirda üretmez" || no "alinti-kayit" "$OUT rc=$RC"
EKIP_KAYIT_KOK="$T/yok" run ESKISINIR --kontrol DOLU; grep -q "^ESKISINIR	sinirda" <<<"$OUT" && ok "kayıt bulunamazsa sinirda KORUNUR (bilinmeyen ≠ temiz)" || no "kayitsiz" "$OUT"
unset EKIP_KAYIT_KOK
echo; echo "SONUÇ: $G geçti · $F düştü"; [ $F = 0 ]
