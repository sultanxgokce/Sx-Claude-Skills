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

printf '\npass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
