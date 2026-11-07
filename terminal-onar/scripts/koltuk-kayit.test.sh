#!/usr/bin/env bash
# koltuk-kayit.test.sh — kutu yeniden doğunca personel koltukları bekçiyle auto modda geri gelir (2.46.0 · kart koltuk-geri-donus-auto ·
#   görev …W38BCZ madde 1-2). HERMETİK: sahte tmux (oturum = dosya), sahte pgrep, sahte claude (hiç çalıştırılmaz); GERÇEK tmux
#   sunucusuna ve gerçek oturumlara DOKUNULMAZ (H1 her koşuda ölçer), tuş gönderimi yok. Bekçi UÇTAN UCA koşar (bekci.sh → koltuk-kayit.sh don);
#   bekçinin öteki adımları kukla (durum.sh ok der, kapi-yenile/dava-gunluk sessiz).
#   Yeniden doğuş = doğuş damgasının değişmesi (TO_DOGUS) + sahte tmux oturumlarının silinmesi (recreate'te tmux ölür).
#   Mutantlar (KOLTUK_KAYIT_MUTANT=N, kopya üstünde; kanıtta tek tek kayıt): 1 bekçideki dönüş satırı söküldü → P1 düşer ·
#   2 "bu doğuşta canlıyken kapanan koltuk açılmaz" kuralı söküldü → K1 düşer · 3 izin atlatma savunma kapısı söküldü → N8 düşer.
set -u
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gecen=0; kalan=0
kapi() { if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=[$2] gerçek=[$3]"; fi; }
T=$(mktemp -d); trap 'python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$T"' EXIT
D="$T/durum"; O="$T/oturum"; mkdir -p "$D" "$O" "$T/bin" "$T/proje"
# ── sahteler ─────────────────────────────────────────────────────────────────────────────────────────────
cat > "$T/bin/tmux" <<S
#!/usr/bin/env bash
{ printf '%q ' "\$@"; echo; } >> "$T/tmux.iz"
case "\$1" in
  has-session) t="\${3#=}"; [ -e "$O/\$t" ]; exit ;;
  new-session) shift; ad=""; cwd=""
    while [ \$# -gt 1 ]; do case "\$1" in -s) ad="\$2"; shift 2 ;; -c) cwd="\$2"; shift 2 ;; -d) shift ;; *) break ;; esac; done
    [ -f "$T/new-dusur" ] && exit 1
    printf '%s\n' "\$ad|\$cwd|\$1" >> "$T/acilan.iz"
    [ -f "$T/olu-dogar" ] || printf '%s\n' "\$1" > "$O/\$ad"; exit 0 ;;
  *) exit 1 ;;
esac
S
cat > "$T/bin/pgrep" <<S
#!/usr/bin/env bash
case "\$*" in *--resume*) for i in \$(cat "$T/baska-yerde" 2>/dev/null); do case "\$*" in *"\$i"*) echo 4242; exit 0 ;; esac; done ;; esac
exit 1
S
printf '#!/usr/bin/env bash\n[ "$1" = -l ] && exit 0; exit 0\n' > "$T/bin/crontab"
printf '#!/usr/bin/env bash\necho "SAHTE CLAUDE ÇALIŞTI $*" >> "%s/claude-calisti"\n' "$T" > "$T/bin/claude"
chmod +x "$T/bin/"*
M="$T/calisma"; mkdir -p "$M/kapi"; cp -r "$KOK/scripts" "$M/"; printf '// sahte kapı\n' > "$M/kapi/sunucu.mjs"
printf '\nexport PATH="$TO_SAHTE_BIN:$PATH"\n' >> "$M/scripts/ortak.sh"   # ortak.sh /usr/bin'i öne koyar → sahteler yeniden öne (bekci-iz dersi)
printf '#!/usr/bin/env bash\nexit 0\n' > "$M/scripts/durum.sh"; printf '#!/usr/bin/env bash\nexit 0\n' > "$M/scripts/dava-gunluk.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$M/scripts/kapi-yenile.sh"
if [ "${KOLTUK_KAYIT_MUTANT:-0}" = 1 ]; then   # mutant: bekçinin dönüş satırı sökülür
  python3 - "$M/scripts/bekci.sh" <<'PY'
import sys; p=sys.argv[1]; s=open(p,encoding='utf-8').read()
satir=[l for l in s.splitlines(True) if 'koltuk-kayit.sh" don' in l]
assert len(satir)==1, 'mutant çapası bulunamadı'
open(p,'w',encoding='utf-8').write(s.replace(satir[0],''))
PY
  echo "‼ MUTANT 1: bekci.sh dönüş satırı söküldü (beklenen düşen kapı: P1)"
elif [ "${KOLTUK_KAYIT_MUTANT:-0}" = 2 ] || [ "${KOLTUK_KAYIT_MUTANT:-0}" = 3 ]; then
  python3 - "$M/scripts/koltuk-kayit.sh" "$KOLTUK_KAYIT_MUTANT" <<'MUT'
import sys; p, m = sys.argv[1], sys.argv[2]; s = open(p, encoding='utf-8').read()
capa = {'2': 'canli)    _hal "$ad" kapandi', '3': '*dangerously*|*bypassPermissions*|*--allow-dangerously*)'}[m]
yeni = {'2': 'canli)    ;; _x_kapandi)', '3': '_mutant_kapali_)'}[m]
assert s.count(capa) == 1, 'mutant çapası bulunamadı'
open(p, 'w', encoding='utf-8').write(s.replace(capa, yeni))
MUT
  [ "$KOLTUK_KAYIT_MUTANT" = 2 ] && echo "‼ MUTANT 2: bilerek kapatılan koltuk kuralı söküldü (beklenen düşen kapı: K1)"
  [ "$KOLTUK_KAYIT_MUTANT" = 3 ] && echo "‼ MUTANT 3: savunma kapısı söküldü (beklenen düşen kapı: N8)"
fi
ortam() { env -i PATH="$T/bin:/usr/bin:/bin" TO_SAHTE_BIN="$T/bin" HOME="$T" TO_KUTU=sinav TO_PROJE="$T/proje" TO_DURUM_DIZ="$D" \
  TO_CRONTAB="$T/bin/crontab" TO_BECERI_KOK="$M" CORTEX_ACCESS_ENV="$T/yok.env" TO_KAPI_PORT=1 TO_TTYD_SOKET="$T/yok.sock" TO_KABUK_YOK=1 \
  TO_ANA_TMUX=sinav-ana TO_CLAUDE="${SAHTE_CL:-$T/bin/claude}" TO_DOGUS="$DOGUS" KOLTUK_DONUS_TAVAN="${TAVAN:-2}" "$@"; }
bekci() { ortam bash "$M/scripts/bekci.sh" >/dev/null 2>&1; }
kk() { ortam bash "$M/scripts/koltuk-kayit.sh" "$@"; }
yeniden_dog() { DOGUS="$1"; find "$O" -mindepth 1 -delete; }    # recreate: tmux oturumlarının hepsi ölür, doğuş damgası değişir
acilan() { local n; n="$(grep -c "^$1|" "$T/acilan.iz" 2>/dev/null)"; echo "${n:-0}"; }   # bu koltuk için kaç new-session
hal() { awk -F'\t' -v a="$1" '$1==a{print $3}' "$D/koltuk-donus.durum" 2>/dev/null; }
gun() { local n; n="$(grep -c -- "koltuk $1: .*$2" "$D/gunluk.log" 2>/dev/null)"; echo "${n:-0}"; }
denendi() { local n; n="$(grep -c "^new-session .*-s $1 " "$T/tmux.iz" 2>/dev/null)"; echo "${n:-0}"; }   # açılış DENEMESİ (düşenler dahil)
cwd() { mkdir -p "$T/is/$1"; printf '%s' "$T/is/$1"; }
konusma() { local k; k="$(printf '%s' "$2" | sed 's/[^A-Za-z0-9]/-/g')"; mkdir -p "$T/.claude/projects/$k"; : > "$T/.claude/projects/$k/$1.jsonl"; }
S_A=aaaaaaaa-1111-4111-8111-111111111111; S_B=bbbbbbbb-2222-4222-8222-222222222222; S_C=cccccccc-3333-4333-8333-333333333333
S_E=eeeeeeee-5555-4555-8555-555555555555; S_F=ffffffff-6666-4666-8666-666666666666
DOGUS=A

echo "── H · hermetiklik"
kapi "H1 ortak.sh yüklendikten sonra tmux SAHTE (gerçek sunucuya dokunulmaz)" "sahte" \
  "$(ortam bash -c '. "$TO_BECERI_KOK/scripts/ortak.sh"; [ "$(command -v tmux)" = "$TO_SAHTE_BIN/tmux" ] && echo sahte || echo GERÇEK' 2>/dev/null)"
bekci
kapi "H2 kayıt yokken bekçi turu: hiçbir koltuk açılmaz, durum dosyası doğmaz" "0 h" "$(acilan '.*') $([ -f "$D/koltuk-donus.durum" ] && echo e || echo h)"

echo "── Y · kayıt yazımı (madde 1)"
for k in a b c; do cwd "$k" >/dev/null; done
kk yaz koltuk-a ROLA "$S_A" "$(cwd a)"; r1=$?
kk yaz koltuk-b ROLB "$S_B" "$(cwd b)"; kk yaz koltuk-c ROLC "$S_C" "$(cwd c)"
kapi "Y1 yaz rc 0, üç satır, her satır dört sütun (izin modu sütunu YOK)" "0 3 4" \
  "$r1 $(grep -vc '^#' "$D/koltuklar.tsv") $(grep -v '^#' "$D/koltuklar.tsv" | awk -F'\t' '{print NF}' | sort -u | tr '\n' ' ' | sed 's/ $//')"
kk yaz koltuk-a ROLA "$S_A" "$(cwd a)"
kapi "Y2 aynı ad yeniden yazılınca satır çoğalmaz" "1" "$(grep -c '^koltuk-a	' "$D/koltuklar.tsv")"
kk yaz koltuk-x ROLX "bozuk-kimlik" "$(cwd a)" 2>/dev/null; r2=$?
kk yaz koltuk-x ROLX "" "$(cwd a)" 2>/dev/null; r3=$?
kk yaz koltuk-x ROLX "$S_E" "$T/yok-dizin" 2>/dev/null; r4=$?
kk yaz "kol:tuk" ROLX "$S_E" "$(cwd a)" 2>/dev/null; r5=$?
kk yaz koltuk-x "$(printf 'RO\tL')" "$S_E" "$(cwd a)" 2>/dev/null; r6=$?
kapi "Y3 bozuk kimlik · boş kimlik · olmayan dizin · ':'li ad · sekmeli rol → rc 2, kayda GİRMEZ" "2 2 2 2 2 0" "$r2 $r3 $r4 $r5 $r6 $(grep -c '^koltuk-x' "$D/koltuklar.tsv")"
kk yaz koltuk-x ROLX "$S_E" "$(cwd a)"; kk sil koltuk-x
kapi "Y4 sil satırı kaldırır, ötekiler kalır" "0 3" "$(grep -c '^koltuk-x' "$D/koltuklar.tsv") $(grep -vc '^#' "$D/koltuklar.tsv")"
for k in a b c; do s="S_$(printf '%s' "$k" | tr a-z A-Z)"; konusma "${!s}" "$(cwd "$k")"; done

echo "── P · doğuş A: koltuklar canlı → bekçi hiçbirine dokunmaz"
for k in a b c; do : > "$O/koltuk-$k"; done
bekci; bekci
kapi "P0 canlı ve kayıtlı koltuğa DOKUNULMAZ (new-session 0), hal canli" "0 0 0 canli" "$(acilan koltuk-a) $(acilan koltuk-b) $(acilan koltuk-c) $(hal koltuk-a)"

echo "── P · yeniden doğuş B: tmux öldü → bekçi auto modda geri açar"
yeniden_dog B; bekci
kapi "P1 🔴 ilk turda tavan kadar (2) koltuk açıldı: a ve b, c sırada" "1 1 0 bekliyor" "$(acilan koltuk-a) $(acilan koltuk-b) $(acilan koltuk-c) $(hal koltuk-c)"
cmd_a="$(grep '^koltuk-a|' "$T/acilan.iz" | head -1)"
kapi "P2 komut: kayıttaki dizinde, --resume <kayıttaki kimlik> --permission-mode auto" "e e e" \
  "$(case "$cmd_a" in "koltuk-a|$T/is/a|"*) echo e;; *) echo h;; esac) $(case "$cmd_a" in *"--resume $S_A --permission-mode auto") echo e;; *) echo h;; esac) $(case "$cmd_a" in *"$T/bin/claude --resume"*) echo e;; *) echo h;; esac)"
kapi "P3 komut bellek ve sıkıştırma ortamını taşır (ana koltukla aynı)" "e" "$(case "$cmd_a" in *MALLOC_ARENA_MAX=2*CLAUDE_CODE_AUTO_COMPACT_WINDOW=600k*) echo e;; *) echo h;; esac)"
kapi "P4 günlükte geri açılış satırı (a için 1)" "1" "$(gun koltuk-a 'yeniden doğuştan sonra geri açıldı')"
bekci
kapi "P5 ikinci tur: a ve b İKİNCİ kez açılmaz, c şimdi açıldı" "1 1 1" "$(acilan koltuk-a) $(acilan koltuk-b) $(acilan koltuk-c)"
bekci; bekci
kapi "P6 sonraki turlar da hiçbirini yeniden açmaz, hepsi canli" "1 1 1 canli canli canli" "$(acilan koltuk-a) $(acilan koltuk-b) $(acilan koltuk-c) $(hal koltuk-a) $(hal koltuk-b) $(hal koltuk-c)"
kapi "P7 sahte claude hiç ÇALIŞTIRILMADI (komut yalnız sahte tmux'a verildi)" "h" "$([ -f "$T/claude-calisti" ] && echo e || echo h)"

echo "── K · bilerek kapatılan koltuk (Kadro dondur, boşta taraması) geri AÇILMAZ"
rm -f "$O/koltuk-a"; bekci; bekci
kapi "K1 bu doğuşta canlıyken kapanan koltuk: açılmaz, hal kapandi, günlükte TEK satır" "1 kapandi 1" "$(acilan koltuk-a) $(hal koltuk-a) $(gun koltuk-a 'bilerek kapatılmış')"
yeniden_dog C; bekci; bekci
kapi "K2 sonraki yeniden doğuşta da dönmez (kutu ölürken kapalıydı); b ve c döner" "1 2 2 gorulmedi" "$(acilan koltuk-a) $(acilan koltuk-b) $(acilan koltuk-c) $(hal koltuk-a)"

echo "── Y · açılıp yaşamayan koltuk döngüye girmez"
yeniden_dog D; : > "$T/olu-dogar"; bekci; bekci; bekci; rm -f "$T/olu-dogar"
kapi "Y5 açıldı ama yaşamadı → bu doğuşta yeniden DENENMEZ (b için toplam 3 = önceki 2 + 1), hal yasamadi, günlükte TEK satır" "3 yasamadi 1" \
  "$(acilan koltuk-b) $(hal koltuk-b) $(gun koltuk-b 'yaşamadı')"
for k in b c; do : > "$O/koltuk-$k"; done; bekci          # D'de insan elle açtı → canlı görüldü
yeniden_dog E; : > "$T/new-dusur"; bekci; bekci; bekci; rm -f "$T/new-dusur"
kapi "Y6 tmux oturumu kurulamazsa (new-session düşer): hal yasamadi, bu doğuşta TEK deneme (b, c)" "yasamadi 1 1" "$(hal koltuk-c) $(( $(denendi koltuk-b) - 3 )) $(( $(denendi koltuk-c) - 3 ))"

echo "── N · negatif: kimlik bozuk/boş · dizin yok · konuşma yok · başka yerde açık · ana koltuk · izin modu sütunu"
# kayda elle bozuk satırlar (yazıcı bunları reddeder; dosya başka yoldan bozulmuş gibi) — hepsi doğuş F'de canlı, G'de ölü
cat >> "$D/koltuklar.tsv" <<K
koltuk-bos	ROLN		$(cwd a)
koltuk-bozuk	ROLN	--dangerously-skip-permissions	$(cwd a)
koltuk-dizinsiz	ROLN	$S_E	$T/yok-dizin
koltuk-konusmasiz	ROLN	$S_F	$(cwd b)
koltuk-baska	ROLN	$S_E	$(cwd c)
sinav-ana	ANA	$S_A	$(cwd a)
koltuk-izinli	ROLN	$S_F	$(cwd c)	bypassPermissions
K
konusma "$S_E" "$(cwd c)"; konusma "$S_F" "$(cwd c)"; echo "$S_E" > "$T/baska-yerde"
yeniden_dog F; for k in koltuk-bos koltuk-bozuk koltuk-dizinsiz koltuk-konusmasiz koltuk-baska sinav-ana koltuk-izinli; do : > "$O/$k"; done
TAVAN=20 bekci
yeniden_dog G; TAVAN=20 bekci; TAVAN=20 bekci; TAVAN=20 bekci
kapi "N1 boş kimlik → açılmaz, hal bozuk, sebep günlükte TEK satır" "0 bozuk 1" "$(acilan koltuk-bos) $(hal koltuk-bos) $(gun koltuk-bos 'session_id boş ya da bozuk')"
kapi "N2 kimlik yerine izin atlatma bayrağı → açılmaz (kimlik değil), hal bozuk" "0 bozuk" "$(acilan koltuk-bozuk) $(hal koltuk-bozuk)"
kapi "N3 kayıttaki dizin yok → açılmaz, sebep günlükte" "0 1" "$(acilan koltuk-dizinsiz) $(gun koltuk-dizinsiz 'çalışma dizini yok')"
kapi "N4 konuşma dosyası O DİZİNDE yok (başka dizinde var) → açılmaz" "0 1" "$(acilan koltuk-konusmasiz) $(gun koltuk-konusmasiz 'konuşma dosyası')"
kapi "N5 konuşma başka yerde açık → ikinci kopya açılmaz" "0 baska-yerde" "$(acilan koltuk-baska) $(hal koltuk-baska)"
kapi "N6 ana koltuk bu yoldan HİÇ açılmaz (onar.sh'ın)" "0" "$(acilan sinav-ana)"
kapi "N7 kayda 5. sütunda bypass yazılsa da yok sayılır: auto ile açılır" "1 e" "$(acilan koltuk-izinli) $(grep '^koltuk-izinli|' "$T/acilan.iz" | grep -q -- '--permission-mode auto$' && echo e || echo h)"
yeniden_dog H
SAHTE_CL="$T/dangerously/claude"; mkdir -p "$T/dangerously"; cp "$T/bin/claude" "$SAHTE_CL"
# koltuk-izinli G'de canlıydı (açıldı) → H'de aday; claude yolunda izin atlatma deseni → savunma kapısı açmaz
SAHTE_CL="$SAHTE_CL" TAVAN=20 bekci; SAHTE_CL=""
kapi "N8 savunma kapısı: komut satırında izin atlatma deseni görülürse AÇILMAZ" "1 bozuk" "$(acilan koltuk-izinli) $(hal koltuk-izinli)"
kapi "N9 🔴 bütün sınav boyunca sahte tmux'a giden HİÇBİR komutta izin atlatma yok" "0" \
  "$(n="$(grep -c -e 'skip-permissions' -e 'bypassPermissions' -e 'permission-mode [^a]' "$T/tmux.iz")"; echo "${n:-0}")"
kapi "N10 her açılış komutu tam olarak '--permission-mode auto' ile biter" "$(grep -c . "$T/acilan.iz")" "$(grep -c -- '--permission-mode auto$' "$T/acilan.iz")"
kapi "N11 kaynakta izin atlatma bayrağı yazılı değil (koltuk-kayit.sh · bekci.sh)" "0 0" \
  "$(grep -c 'skip-permissions' "$KOK/scripts/koltuk-kayit.sh") $(grep -c 'skip-permissions' "$KOK/scripts/bekci.sh")"

echo "── G · kayıtlı ama kutu ölürken canlı görülmemiş koltuk (yeni kurulum, dondurulmuş) açılmaz"
kk yaz koltuk-yeni ROLY "$S_E" "$(cwd c)"; yeniden_dog I; bekci; bekci
kapi "G1 önceki doğuşta hiç görülmemiş koltuk açılmaz, günlükte TEK satır" "0 gorulmedi 1" "$(acilan koltuk-yeni) $(hal koltuk-yeni) $(gun koltuk-yeni 'canlı görülmedi')"

echo
echo "koltuk-kayit: GEÇTİ=$gecen KALDI=$kalan"
[ "$kalan" -eq 0 ]
