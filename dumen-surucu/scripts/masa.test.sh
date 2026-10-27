#!/usr/bin/env bash
# masa.test.sh — masa.mjs sınavı + MUTANTLAR (kapı gevşerse sınav kırmızıya dönmeli). Chromium gerekmez; yalnız node.
# kabuk-testleri: sure=120
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
node "$HERE/masa.test.mjs"; RC=$?
[ "$RC" -eq 0 ] || exit "$RC"
[ "${MASA_MUTANT:-1}" = 0 ] && exit 0
echo "── mutantlar (her biri sınavı KIRMALI)"
T="$(mktemp -d)"; cp "$HERE/masa.mjs" "$HERE/masa.test.mjs" "$HERE/dumen.mjs" "$T/"
MK=0; MS=0
mut() { # mut <ad> <çapa> <yerine>
  cp "$HERE/masa.mjs" "$T/masa.mjs"
  python3 -I -c "import sys;p=sys.argv[1];s=open(p,encoding='utf-8').read();a,b=sys.argv[2],sys.argv[3];assert s.count(a)==1,'çapa '+str(s.count(a));open(p,'w',encoding='utf-8').write(s.replace(a,b))" "$T/masa.mjs" "$2" "$3" || { echo "  ✗ $1: ÇAPA bayat (mutant ÜRETİLEMEDİ)"; MK=$((MK+1)); return; }
  MS=$((MS+1))
  if MASA_LIB="$T/masa.mjs" node "$T/masa.test.mjs" >"$T/o.txt" 2>&1; then echo "  ✗ $1: sınav YEŞİL kaldı (mutant yakalanmadı)"; MK=$((MK+1)); else echo "  ✓ $1: yakalandı ($(grep -c '  ✗' "$T/o.txt") kapı kırmızı)"; fi
}
mut "merkez modu atlanır" "if (mod !== 'ajan') throw await this.#sultanda(\`mod=\${mod}\`);" "if (false) throw await this.#sultanda(\`mod=\${mod}\`);"
mut "merkez cevapsız → devam" "throw new KapiHata('merkez-cevapsiz', String(e.message || e));" "return 'ajan';"
mut "bekçi 423 sultanda sayılmaz" "if (r.status === 423) throw await this.#sultanda('bekçi 423');" "if (false) throw await this.#sultanda('bekçi 423');"
mut "soket düşünce mod bakılmaz" "if (m && m !== 'ajan') throw await this.#sultanda(\`mod=\${m} (bağlantı düştü)\`);" "if (false) throw await this.#sultanda('x');"
mut "yaz: alan zorunlu değil" "if (typeof alan !== 'string' || !alan.trim()) throw new KapiHata('alan-belirtilmedi', \"yaz(" "if (false) throw new KapiHata('alan-belirtilmedi', \"yaz("
mut "yaz: hassas alan kapısı yok" "const HASSAS_ALAN = /(parola" "const HASSAS_ALAN = /(zzz-yok-parola"
mut "tık etiketi kapısı yok" "if (GONDER_ETIKET.test(etiket)) throw" "if (false) throw"
mut "tek karakterli tuş kapısı yok" "if (parcalar[parcalar.length - 1].length === 1 && !duzenleyici) {" "if (false) {"
mut "bekçiye jetonsuz gider" "headers: { 'x-dumen-jeton': jeton, " "headers: { "
mut "durak bildirimi jetonsuz" "...(jeton ? { 'x-defter-jeton': jeton } : {})" "...{}"
find "$T" -mindepth 1 -delete; rmdir "$T"
[ "$MK" -eq 0 ] && echo "MUTANT: $MS/$MS yakalandı" || { echo "MUTANT: $MK kaçtı"; exit 1; }
