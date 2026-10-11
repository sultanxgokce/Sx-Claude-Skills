#!/usr/bin/env bash
# ekip-notify.test.sh — notify'ın CANLILIK KAPISI sınavı. HERMETİK: ayrı tmux sunucusu, sahte registry, geçici sinyal defteri.
# Gerçek koltuklara ve gerçek deftere DOKUNMAZ. Ağırlık merkezi: bash satırındaki koltuğa mesaj YAZILMAMASI (kabukta komut olurdu).
set -uo pipefail
D="$(cd "$(dirname "$0")" && pwd)"; T="$(mktemp -d)"; SOCK="notify-test-$$"
trap 'command tmux -L "$SOCK" kill-server 2>/dev/null; rm -r "$T"' EXIT
mkdir -p "$T/handoff"
cat > "$T/handoff/reg.yaml" <<Y
meta:
  yonetici: DOLU
uyeler:
  - id: DOLU
    tmux: "DOLU:0"
  - id: BOS
    tmux: "BOS:0"
Y
tm() { command tmux -L "$SOCK" "$@"; }
tm new-session -d -s DOLU "bash -c 'bash -c \"bash -c \\\"exec -a claude sleep 300\\\"; true\"; true'"
tm new-session -d -s BOS   # gerçek bash satırı — mesaj buraya düşerse Enter'la KOMUT olur
sleep 1
export EKIP_REGISTRY="$T/handoff/reg.yaml" EKIP_SINYAL_LOG="$T/handoff/sinyal.log" EKIP_TMUX_SOCK="$SOCK" EKIP_CANLI_KONTROL=DOLU
unset TMUX_PANE
: > "$EKIP_SINYAL_LOG"
G=0; F=0; ok() { G=$((G+1)); echo "  ✓ $1"; }; no() { F=$((F+1)); echo "  ✗ $1 — $2"; }
MSG="SINAV-MESAJI-$$ echo tehlikeli"

OUT="$(bash "$D/ekip-notify.sh" BOS "$MSG" 2>&1)"; RC=$?
grep -q "eksik_oturum=1" <<<"$OUT" && [ $RC = 1 ] && ok "bash satırındaki koltuk → eksik_oturum, rc=1" || no "bos-ozet" "$OUT rc=$RC"
grep -q "|ping|.*|BOS|oturum-yok|ajan-yok:" "$EKIP_SINYAL_LOG" && ok "defter: ping=oturum-yok (iletildi DEĞİL)" || no "bos-defter" "$(cat "$EKIP_SINYAL_LOG")"
grep -q "|canli|.*|BOS|yok|" "$EKIP_SINYAL_LOG" && ok "defter: canli=yok satırı" || no "bos-canli" "$(cat "$EKIP_SINYAL_LOG")"
sleep 0.5; tm capture-pane -p -t BOS:0 | grep -q "SINAV-MESAJI" && no "bos-kabuk" "MESAJ KABUĞA YAZILDI" || ok "kabuğa hiçbir şey yazılmadı (asıl tehlike)"

# --- dışarıdan çağrı (tmux dışı, kontrol değişkeni YOK): pozitif kontrol registry yöneticisinden (DOLU) çözülmeli ---
: > "$EKIP_SINYAL_LOG"
OUT="$(env -u EKIP_CANLI_KONTROL bash "$D/ekip-notify.sh" BOS "$MSG" 2>&1)"; RC=$?
grep -q "eksik_oturum=1" <<<"$OUT" && grep -q "|canli|.*|BOS|yok|" "$EKIP_SINYAL_LOG" && ok "kontrol değişkeni yokken yönetici koltuğu pozitif kontrol → boş koltuk yine YOK (olcemedim değil)" || no "dis-cagri-yonetici" "$OUT $(cat "$EKIP_SINYAL_LOG")"
sleep 0.3; tm capture-pane -p -t BOS:0 | grep -q "SINAV-MESAJI" && no "dis-cagri-kabuk" "MESAJ KABUĞA YAZILDI" || ok "dış çağrıda da kabuğa hiçbir şey yazılmadı"

OUT="$(bash "$D/ekip-notify.sh" --force BOS "$MSG" 2>&1)"; RC=$?
[ $RC = 1 ] && ! tm capture-pane -p -t BOS:0 | grep -q "SINAV-MESAJI" && ok "--force bile kabuğa yazdırmaz" || no "bos-force" "$OUT rc=$RC"

: > "$EKIP_SINYAL_LOG"
OUT="$(bash "$D/ekip-notify.sh" DOLU "$MSG" 2>&1)"; RC=$?
grep -q "gonderildi=1" <<<"$OUT" && ok "dolu koltuğa gönderildi" || no "dolu-gonder" "$OUT rc=$RC"
grep -q "|canli|.*|DOLU|canli|torun" "$EKIP_SINYAL_LOG" && ok "defter: canli=canli torun" || no "dolu-canli" "$(cat "$EKIP_SINYAL_LOG")"
grep -qE "\|ping\|.*\|DOLU\|(iletildi|dogrulanamadi)\|" "$EKIP_SINYAL_LOG" && ok "defter: ping satırı eski hükümle (iletildi/dogrulanamadi), oturum-yok değil" || no "dolu-ping" "$(cat "$EKIP_SINYAL_LOG")"

: > "$EKIP_SINYAL_LOG"
OUT="$(EKIP_AJAN_RE='ZZZ' bash "$D/ekip-notify.sh" DOLU "$MSG" 2>&1)"; RC=$?
grep -q "gonderildi=1" <<<"$OUT" && grep -q "|canli|.*|DOLU|olcemedim|" "$EKIP_SINYAL_LOG" && ok "mutasyon: prob kör → olcemedim, gönderim ESKİ davranış (yok uydurulmaz)" || no "kor-prob" "$OUT $(cat "$EKIP_SINYAL_LOG")"

: > "$EKIP_SINYAL_LOG"
OUT="$(EKIP_AJAN_RE='ZZZ' bash "$D/ekip-notify.sh" BOS "$MSG" 2>&1)"; RC=$?
grep -q "|canli|.*|BOS|olcemedim|" "$EKIP_SINYAL_LOG" && ok "kör probla boş koltuk 'yok' DENMEZ (olcemedim) — dürüst sınır" || no "kor-bos" "$(cat "$EKIP_SINYAL_LOG")"
tm send-keys -t BOS:0 C-u   # kör probda kabuğa yazılmış olabilir; sınav temizliği (bilinçli: mutasyon durumu)

# --- SINIRDA (BASİRET, 11 Ekim): ajan var ama kullanım sınırında → gönderilmez, defter "sinirda" ---
NB=$'\xc2\xa0'
printf '  ⎿ %sYou'"'"'ve reached your Fable limit. Run /usage-credits\n' "$NB" > "$T/sinir.txt"
tm new-session -d -s SINIR "bash -c 'cat $T/sinir.txt; exec -a claude sleep 300'"
printf '  - id: SINIR\n    tmux: "SINIR:0"\n' >> "$T/handoff/reg.yaml"; sleep 0.5
: > "$EKIP_SINYAL_LOG"
OUT="$(bash "$D/ekip-notify.sh" SINIR "$MSG" 2>&1)"; RC=$?
grep -q "engellendi=1" <<<"$OUT" && [ $RC = 1 ] && ok "sınırdaki koltuk → gönderilmedi (engellendi), rc=1" || no "sinir-ozet" "$OUT rc=$RC"
grep -q "|ping|.*|SINIR|sinirda|" "$EKIP_SINYAL_LOG" && ok "defter: ping=sinirda (iletildi DEĞİL)" || no "sinir-defter" "$(cat "$EKIP_SINYAL_LOG")"
sleep 0.3; tm capture-pane -p -t SINIR:0 | grep -q "SINAV-MESAJI" && no "sinir-yazildi" "mesaj sınırdaki koltuğa yazıldı" || ok "sınırdaki koltuğa hiçbir şey yazılmadı"
: > "$EKIP_SINYAL_LOG"
OUT="$(bash "$D/ekip-notify.sh" --force SINIR "$MSG" 2>&1)"; RC=$?
grep -q "engellendi=1" <<<"$OUT" && [ $RC = 1 ] && grep -q "|ping|.*|SINIR|sinirda|" "$EKIP_SINYAL_LOG" && ok "--force bile sınırdaki koltuğu açmaz (koşulsuz kural)" || no "sinir-force" "$OUT rc=$RC"
sleep 0.3; tm capture-pane -p -t SINIR:0 | grep -q "SINAV-MESAJI" && no "sinir-force-yazildi" "--force ile sınırdaki koltuğa yazıldı" || ok "--force ile de sınırdaki koltuğa hiçbir şey yazılmadı"
echo; echo "SONUÇ: $G geçti · $F düştü"; [ $F = 0 ]
