#!/usr/bin/env bash
# ekip-durum.test.sh — ölçüm PyYAML'a bağımlı OLMASIN + "ölçemedim" ≠ "ekip yok"
#
# NİÇİN VAR (firsthand, 2026-07-30): Sultan tez kutusunda `basla` → "bir ekip üyesine geç"
# seçti; ekran "Ekip listesi okunamadı (YAML-YOK) — bu dizinde ekip tanımı yok" dedi.
# İki şey birden yanlıştı:
#   1) Ekip listesi dosyası VARDI — eksik olan PyYAML'dı (o kutuda kurulu değil).
#   2) Ekran "araç eksik"i "ekip yok"a çeviriyordu → Sultan ekibin kaybolduğunu sandı.
# Bu sınama ikisini de kapıya bağlar. Kutu-farkı (bir kutuda çalışır, öbüründe çalışmaz)
# sınıfının panzehiri: PyYAML'ı BLOKLA ve aynı sonucu bekle.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
E="$HERE/ekip-durum.sh"
B="$HERE/basla"
T="$(mktemp -d)"; trap 'chmod -R u+w "$T" 2>/dev/null; find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null' EXIT
pass=0; fail=0
ok(){ pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
no(){ fail=$((fail+1)); printf 'FAIL  %s — %s\n' "$1" "${2:-}"; }

# Sahte tmux: sınama CANLI masalara bağlı OLMASIN (hem CI'da tmux yok, hem geliştiricinin
# açık masaları sonucu değiştirmemeli — hermetik sınama). Sabit iki masa döndürür.
SAHTEBIN="$T/bin"; mkdir -p "$SAHTEBIN"
cat > "$SAHTEBIN/tmux" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  ls) printf 'ornek-yon\nBIRINCI\n' ;;   # ikinci üye her biçimde KAPALI kalsın
  *)  exit 1 ;;
esac
SH
chmod +x "$SAHTEBIN/tmux"
PATH="$SAHTEBIN:$PATH"; export PATH

# PyYAML'ı bloklayan sahte modül (import ImportError atar → yedek ayrıştırıcı devreye girer)
NOYAML="$T/noyaml"; mkdir -p "$NOYAML"
printf 'raise ImportError("PyYAML yok — sinama")\n' > "$NOYAML/yaml.py"

# fixture: gerçek hayatta görülen İKİ biçim (girintisiz sedir-biçimi + girintili/tırnaklı Nexus-biçimi)
mk_sedir(){ mkdir -p "$1/_agents/handoff"; cat > "$1/_agents/handoff/aile-registry.yaml" <<'YML'
cell_id: ornek
meta:
  aile: ORNEK
  uye_sayisi: 2
uyeler:
- id: ornek-yon
  tmux: ornek-yon:0
  mod: motor
  kanallar:
  - _agents/ornek-yon/AGENT.md
  inbox: ''
- id: ornek-motor1
  tmux: ornek-motor1:0
  mod: motor
  kanallar:
  - _agents/ornek-motor1/AGENT.md
  inbox: ''
YML
}
mk_nexus(){ mkdir -p "$1/_agents/handoff"; cat > "$1/_agents/handoff/aile-registry.yaml" <<'YML'
meta:
  aile: IKINCI
uyeler:
  - id: BIRINCI
    tmux: "cc-abc123:0"   # yorum burada
    session_id: "x-y-z"
    mod: motor
    rol: "kodlayan"
    kanallar: [ _agents/birinci/AGENT.md ]
    inbox: ""

  - id: IKINCI
    tmux: "ikinci:0"
    mod: salt-plan
    kanallar: [ _agents/ikinci/AGENT.md ]
YML
}

# ── G1 · sözdizimi
bash -n "$E" 2>/dev/null && ok "G1 ekip-durum.sh sözdizimi" || no "G1 ekip-durum.sh sözdizimi"
bash -n "$B" 2>/dev/null && ok "G1b basla sözdizimi"        || no "G1b basla sözdizimi"

# ── G2/G3 · PyYAML VARKEN ve YOKKEN sonuç BAYT-AYNI olmalı (iki biçim için de)
for bicim in sedir nexus; do
  d="$T/$bicim"; mkdir -p "$d"; "mk_$bicim" "$d"
  a="$(cd "$d" && bash "$E" 2>/dev/null)"; ra=$?
  b="$(cd "$d" && PYTHONPATH="$NOYAML" bash "$E" 2>/dev/null)"; rb=$?
  if [ "$ra" -eq 0 ] && [ "$rb" -eq 0 ] && [ "$a" = "$b" ] && [ -n "$a" ]; then
    ok "G2-$bicim PyYAML'lı ve PyYAML'sız çıktı bayt-aynı"
  else
    no "G2-$bicim bayt-aynı değil" "rc=$ra/$rb"
    printf '  --- yaml ---\n%s\n  --- yedek ---\n%s\n' "$a" "$b"
  fi
  # iki üye + ÖZET = 3 satır; yedek ayrıştırıcı iç-içe listeyi (kanallar) üye sanmamalı
  n="$(printf '%s\n' "$b" | grep -c .)"
  [ "$n" = "3" ] && ok "G3-$bicim yedek ayrıştırıcı 2 üye buldu (iç-içe liste üye sanılmadı)" \
                 || no "G3-$bicim üye sayısı" "satır=$n (beklenen 3)"
done

# ── G4 · ekip listesi YOKSA jeton EKIP-LISTESI-YOK + exit 3 (araç-eksikliğiyle karışmasın)
bos="$T/bos"; mkdir -p "$bos"
out="$(cd "$bos" && bash "$E" 2>/dev/null)"; rc=$?
[ "$rc" = "3" ] && [ "$out" = "EKIP-LISTESI-YOK" ] \
  && ok "G4 liste yok → EKIP-LISTESI-YOK + exit 3" || no "G4 liste yok" "rc=$rc out=$out"

# ── G5 · ÖLÇEMEDİM (rc=2) "ekip yok" DİYE TERCÜME EDİLMEMELİ — bu bug'ın kendisi
# Ölçümü rc=2 veren sahte bir ekip-durum.sh ile değiştir (basla onu $HERE'den çağırır).
sahte="$T/sahte"; mkdir -p "$sahte"
cp "$B" "$sahte/basla"
printf '#!/usr/bin/env bash\necho "PYTHON-YOK"\nexit 2\n' > "$sahte/ekip-durum.sh"
chmod +x "$sahte/basla" "$sahte/ekip-durum.sh"
mk_sedir "$T/g5"
ekran="$(cd "$T/g5" && BASLA_TEST_SECIM=q bash "$sahte/basla" 2>&1 || true)"
if printf '%s' "$ekran" | grep -q 'ölçemedim'; then
  ok "G5 rc=2 → 'ölçemedim' deniyor"
else
  no "G5 rc=2 mesajı" "'ölçemedim' yok"
fi
if printf '%s' "$ekran" | grep -q 'ekip tanımı yok'; then
  no "G5b rc=2 'ekip tanımı yok' YALANI hâlâ basılıyor" "bug geri geldi"
else
  ok "G5b rc=2'de 'ekip tanımı yok' YALANI basılmıyor"
fi

# ── G6 · tmux'un İÇİNDEYKEN attach DEĞİL switch-client kullanılmalı
# Sultan canlı gördü (tez kutusu, durum çubuğu [tez-yon]): üye seçildi → tmux
# "sessions should be nested with care, unset $TMUX to force" dedi → menüye geri atıldı.
# tmux içinden `attach` çalışmaz; doğru fiil `switch-client`.
g6bin="$T/g6bin"; mkdir -p "$g6bin"
cat > "$g6bin/tmux" <<'SH'
#!/usr/bin/env bash
: > "$TMUX_CAGRI_LOG.tmp"; printf '%s\n' "$*" >> "$TMUX_CAGRI_LOG"
case "${1:-}" in
  ls)          printf 'ornek-yon\n' ;;
  has-session) exit 0 ;;             # hedef masa AYAKTA
  attach)      echo "sessions should be nested with care, unset \$TMUX to force"; exit 1 ;;
  switch-client) exit 0 ;;
  *) exit 0 ;;
esac
SH
chmod +x "$g6bin/tmux"
mk_sedir "$T/g6"
export TMUX_CAGRI_LOG="$T/tmux-cagri.log"; : > "$TMUX_CAGRI_LOG"
g6out="$(cd "$T/g6" && PATH="$g6bin:$PATH" TMUX="/tmp/fake,1,0" \
        BASLA_TEST_SECIM=2 BASLA_TEST_UYE=1 bash "$B" 2>&1 || true)"
if grep -q '^switch-client' "$TMUX_CAGRI_LOG"; then
  ok "G6 tmux içindeyken switch-client çağrıldı"
else
  no "G6 switch-client çağrılmadı" "$(tr '\n' '|' < "$TMUX_CAGRI_LOG")"
fi
if grep -q '^attach' "$TMUX_CAGRI_LOG"; then
  no "G6b tmux içindeyken attach çağrıldı — iç-içe hatası geri gelir" ""
else
  ok "G6b tmux içindeyken attach ÇAĞRILMADI"
fi
if printf '%s' "$g6out" | grep -q 'nested with care'; then
  no "G6c iç-içe hata mesajı ekranda" ""
else
  ok "G6c iç-içe hata mesajı ekranda YOK"
fi

# ── G7 · ekip DIŞI açık masalar (geçici seanslar) listede görünür
# Sultan: "ui adında geçici bir seans açmıştım o da yok — geçiciler altta silik olsun".
g7bin="$T/g7bin"; mkdir -p "$g7bin"
cat > "$g7bin/tmux" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  ls) printf 'ornek-yon\nui\n' ;;    # 'ui' ekip listesinde YOK → geçici
  has-session) exit 0 ;;
  *) exit 0 ;;
esac
SH
chmod +x "$g7bin/tmux"
mk_sedir "$T/g7"
g7out="$(cd "$T/g7" && PATH="$g7bin:$PATH" BASLA_TEST_SECIM=2 BASLA_TEST_UYE=q BASLA_TEST_LISTE=1 \
        bash "$B" 2>&1 || true)"
g7aday="$(printf '%s\n' "$g7out" | grep '^ADAY: ')"
printf '%s' "$g7aday" | grep -q 'ui' \
  && ok "G7 ekip dışı masa ('ui') listede görünüyor" || no "G7 geçici masa listede yok"
printf '%s' "$g7aday" | grep -q 'geçici' \
  && ok "G7b geçici olarak işaretli" || no "G7b 'geçici' etiketi yok"
# demirbaş ÜSTTE, geçici ALTTA olmalı
s_uye="$(printf '%s\n' "$g7aday" | grep -n 'ornek-yon' | tail -1 | cut -d: -f1)"
s_gec="$(printf '%s\n' "$g7aday" | grep -n 'geçici'    | tail -1 | cut -d: -f1)"
if [ -n "$s_uye" ] && [ -n "$s_gec" ] && [ "$s_uye" -lt "$s_gec" ]; then
  ok "G7c demirbaş üstte · geçici altta"
else
  no "G7c sıra yanlış" "uye=$s_uye gecici=$s_gec"
fi

# ── G8 · "Ekibi kontrol et / onar" HAM makine çıktısı DÖKMEZ
# Sultan canlı gördü (tez kutusu): seçenek-1 sekmeyle ayrılmış ölçümü ekrana döktü —
# üye adı iki kez, sonunda "ÖZET 1 3 0". Sultan'a hiçbir şey anlatmıyordu.
# `ekip` aracı olmayan bir kutuyu taklit ediyoruz (PATH'te ekip YOK).
g8bin="$T/g8bin"; mkdir -p "$g8bin"
cat > "$g8bin/tmux" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  ls) printf 'ornek-yon\n' ;;
  new-session) exit 0 ;;
  has-session) exit 0 ;;
  *) exit 0 ;;
esac
SH
chmod +x "$g8bin/tmux"
mk_sedir "$T/g8"
# PATH'i DARALT: yalnız sahte tmux + sistem araçları; `ekip` bulunmasın
g8out="$(cd "$T/g8" && PATH="$g8bin:/usr/bin:/bin" BASLA_TEST_SECIM=1 BASLA_TEST_ONAY=h \
        bash "$B" 2>&1 || true)"
if printf '%s' "$g8out" | grep -q 'ÖZET'; then
  no "G8 ham 'ÖZET' satırı ekranda — makine çıktısı dökülüyor" ""
else
  ok "G8 ham 'ÖZET' satırı ekranda YOK"
fi
printf '%s' "$g8out" | grep -q '1 ayakta' \
  && ok "G8b sayım Sultan-dilinde basıldı" || no "G8b sayım yok"
printf '%s' "$g8out" | grep -q 'masayı şimdi açayım mı' \
  && ok "G8c kapalı masalar için ONARIM teklif edildi" || no "G8c onarım teklifi yok"
printf '%s' "$g8out" | grep -q 'salt-bilgidir' \
  && no "G8d 'salt-bilgidir' pes etme cümlesi hâlâ var" "" || ok "G8d 'salt-bilgi' pes etmesi kalktı"
# onay 'h' verildi → hiçbir masa açılmamalı
printf '%s' "$g8out" | grep -q 'vazgeçildi' \
  && ok "G8e 'h' cevabı yazma YAPMADI" || no "G8e 'h' cevabı saygı görmedi"

printf '\npass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
