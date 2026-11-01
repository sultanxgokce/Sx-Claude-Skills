#!/usr/bin/env bash
# yargic-kilidi.test.sh — öznel G yargıcı YALNIZ kör istemle karar verir: Claude yolu araçsız/ayarsız, Codex yolu kabuksuz koşar.
#
# ÖLÇÜLMÜŞ VAKA (HENDESE, 22 Eki 2026 · kanarya): kilitsiz 'claude -p' cwd dışındaki bir dosyayı izin reddi olmadan okudu
# (permission_denials []) ve global CLAUDE.md'yi yükleyip "oturum başı mod kontrolü" koşmaya kalktı; kilitli hâli
# (--safe-mode --strict-mcp-config --tools "") istemdeki içerikle GECTI verdi, diske ulaşamadı. Codex: shell_tool=false → exec 0.
#
# HERMETİK: sahte claude/codex (PATH başında) aldıkları argümanları satır satır kaydeder; gerçek model çağrısı YOK.
# Mutantlar geçici kopyada; kontrol kopyası önce gerçek betikle aynı kapıları geçmeli.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null' EXIT
export SICIL_DIZIN="$T/sicil-yok"
GECEN=0; DUSEN=0
g() { if [ "$1" -eq 0 ]; then GECEN=$((GECEN+1)); echo "  ✓ $2"; else DUSEN=$((DUSEN+1)); echo "  ✗ $2"; fi; }
ND="$(dirname "$(command -v node)")"; PY="$(dirname "$(command -v python3)")"
[ -n "$ND" ] || { echo "ÖLÇÜLEMEDİ: node yok"; exit 4; }

W="$T/is"; K="$W/_agents/tescil/k1"; mkdir -p "$K" "$T/bin-claude" "$T/bin-codex" "$T/bin-codex-duser"
git -C "$W" init -q -b main; echo "merhaba dunya" > "$W/cikti.txt"; printf 'kural: dosyada "merhaba" geçmeli\n' > "$K/rubrik.md"
git -C "$W" add -A; git -C "$W" -c user.email=a@b -c user.name=a commit -qm "sinav"
cat > "$K/GEREKLILIK.md" <<EOF
KART: k1
GOAL: çıktı dosyası selam versin
TIP: docs
VITES: TAM
G1: dosya selam içerir
  tur: cmd
  komut: grep -q merhaba cikti.txt
  davranis: evet
G2: selam tonu uygun
  tur: llm-yargi
  rubrik: rubrik.md
  hedef: cikti.txt
EOF
# sahte yargıçlar: argümanları satır satır kaydeder (boş argüman boş satır olarak görünür), GECTI döner
cat > "$T/bin-claude/claude" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$T/arg-claude"; cat > /dev/null; printf '{"structured_output":{"karar":"GECTI","not":"merhaba var"}}'
EOF
cat > "$T/bin-codex/codex" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$T/arg-codex"; o=""; while [ \$# -gt 0 ]; do [ "\$1" = -o ] && o="\$2"; shift; done
printf '%s' '{"karar":"GECTI","not":"codex gördü"}' > "\$o"
EOF
printf '#!/usr/bin/env bash\nexit 1\n' > "$T/bin-codex-duser/codex"
chmod +x "$T"/bin-*/*

_kos() {  # _kos <scripts-dir> <PATH-ön-eki> [ortam…]
  local s="$1" on="$2"; shift 2; local out="$T/out"
  find "$out" -mindepth 1 -delete 2>/dev/null; rm -f "$T"/arg-*
  env PATH="$on$ND:$PY:/usr/bin:/bin" AGENT_NAME=MUHURDAR1 "$@" bash "$s/muhurdar.sh" k1 --worktree "$W" --out "$out" \
    --gereklilik "$K/GEREKLILIK.md" --yazan HENDESE < /dev/null > "$T/son.log" 2>&1
}
_var() { grep -qxF -- "$1" "$2" 2>/dev/null; }                          # tam satır olarak argüman var mı
_ardisik() { python3 -c "import sys;a=open(sys.argv[1]).read().split('\n');print(any(a[i]==sys.argv[2] and a[i+1]==sys.argv[3] for i in range(len(a)-1)))" "$1" "$2" "$3" 2>/dev/null | grep True >/dev/null; }
_verdikt() { grep -m1 '^verdikt: ' "$T/out/MUHUR.md" 2>/dev/null | sed 's/^verdikt: //'; }
_yargic() { grep -m1 '^yargic: ' "$T/out/MUHUR.md" 2>/dev/null | sed 's/^yargic: //'; }

_sen() {  # _sen <scripts-dir> → geçen kapı anahtarları
  local s="$1" o="" A="$T/arg-claude" C="$T/arg-codex"
  # a · Claude yolu: araç yok (--tools "" ardışık boş argüman), MCP yok, CLAUDE.md/kanca yok — ve karar yine verilir (kör istemle)
  _kos "$s" "$T/bin-claude:" MUHURDAR_MODEL=claude
  _var --safe-mode "$A" && _var --strict-mcp-config "$A" && _ardisik "$A" --tools "" && [ "$(_verdikt)" = GECTI ] && o="$o a"
  # b · Codex yolu: kabuk aracı kapalı + salt-okur kum havuzu; karar verilir
  _kos "$s" "$T/bin-codex:$T/bin-claude:"
  _ardisik "$C" -c features.shell_tool=false && _ardisik "$C" -s read-only && [ "$(_verdikt)" = GECTI ] && [ ! -e "$A" ] && o="$o b"
  # c · Codex düşerse devreye giren Claude da KİLİTLİ (yedek yol kilitsiz kaçış olmasın)
  _kos "$s" "$T/bin-codex-duser:$T/bin-claude:"
  _var --safe-mode "$A" && _ardisik "$A" --tools "" && _var --strict-mcp-config "$A" && case "$(_yargic)" in *codex→claude*) true;; *) false;; esac && o="$o c"
  echo "$o"
}
_k() { case " $2 " in *" $1 "*) return 0;; esac; return 1; }

echo "════ yargıç kilidi · yargıç yalnız kör istemle karar verir ════"
S0="$(_sen "$HERE")"
_k a "$S0"; g $? "a Claude yargıcı --safe-mode --strict-mcp-config --tools \"\" ile koşar ve karar verir"
_k b "$S0"; g $? "b Codex yargıcı -s read-only + features.shell_tool=false ile koşar ve karar verir"
_k c "$S0"; g $? "c Codex düşünce devreye giren Claude da kilitli"

echo "── MUTASYON (betik kopyasında, kontrol şartlı) ──"
_kopya() { local d="$T/m-$1"; mkdir -p "$d"; cp -r "$HERE/." "$d/"; echo "$d"; }
k0="$(_kopya kontrol)"; [ "$(_sen "$k0")" = "$S0" ] && [ -n "$S0" ]; g $? "kontrol kopyası gerçek betikle aynı kapıları geçiyor"
_m() {  # _m <anahtar> <eski> <yeni> <açıklama>
  local d; d="$(_kopya "$1-$RANDOM")"
  python3 - "$d/muhurdar.sh" "$2" "$3" <<'PY' || { g 1 "mutant ($4): desen tutmadı"; return; }
import sys; p,a,b=sys.argv[1:]; s=open(p,encoding='utf-8').read(); assert s.count(a)==1; open(p,'w',encoding='utf-8').write(s.replace(a,b))
PY
  ! _k "$1" "$(_sen "$d")"; g $? "mutant ($4) → '$1' kapısı düşüyor"
}
_m a 'CLAUDE_KILIT=(--safe-mode --strict-mcp-config --tools "")' 'CLAUDE_KILIT=(--safe-mode --strict-mcp-config)' "Claude araçları açık"
_m a 'CLAUDE_KILIT=(--safe-mode --strict-mcp-config --tools "")' 'CLAUDE_KILIT=(--strict-mcp-config --tools "")' "CLAUDE.md/kancalar yükleniyor"
_m b 'CODEX_KILIT=(-c features.shell_tool=false)' 'CODEX_KILIT=()' "Codex kabuğu açık"
_m c 'claude -p "${CLAUDE_KILIT[@]}" --output-format json' 'claude -p --output-format json' "yedek Claude kilitsiz"

echo ""; echo "── SONUÇ: $GECEN geçti · $DUSEN kaldı ──"
[ "$DUSEN" -eq 0 ]
