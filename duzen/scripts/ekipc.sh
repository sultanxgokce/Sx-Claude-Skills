#!/usr/bin/env bash
# ekipc.sh — Ekip-OS derleyicisi OMURGASI (GAP-3 D2 · k0146 · mimSerdar §4)
#
# NE: _agents/ekip-modeli.yaml (TEK-KAYNAK, GAP-1 çıktısı) → ekip-artefaktları derleyen ANLAM-katmanı.
#   Fiziksel katman (container/host/CF) BURADA DEĞİL — o `iskan` skill'inin işi; ekipc oraya DELEGE eder
#   (D6 `kur` zincirleyicisi). İki giriş-noktası yok: Sultan/ajan yalnız ekipc çağırır (mimSerdar §4.1).
#
# KAPSAM (D2 omurga + D3 artefakt-genişletme):
#   derle    — artefakt-seti üretir (üç-bölge idempotent; default DRY-RUN): rol-başına AGENT.md (7-başlık)
#              + DEVIR-SINAVI.md iskeleti (yarı-üretim: senaryo İNSAN yazar) · canlı-koltuk-başına
#              kanallar/<kayit>.md iskeleti · model-düzeyi ekip-registry.yaml + bolge-grant.yaml
#              (yaml'de marker '# ' önekli yorum-satırıdır; --rol filtresi model-düzeyi artefaktları atlar)
#   check    — yönetilen dosyalarda drift-raporu (CI-dostu; VAR-olanları denetler, eksik=WARN — bkz. aşağı)
#   benimse  — elle-yazılmış (marker'sız) mevcut kimliği HİÇBİR CÜMLESİNİ değiştirmeden ELLE-bölgesine alır;
#              yönetilen-gövde --rol <AD> (hücre-rolü govde'si) YA DA --baz <tip> (org-persona ortak-temeli, D5)
#   yenile   — ZATEN benimsenmiş (marker'lı) canlı kimliğin YÖNETİLEN-gövdesini bugünkü temelden yeniden
#              üretir (--baz <tip> | --rol <AD>); ELLE + marker-öncesi bayt-aynı. EL-DEGMIS → exit 5.
#              Neden: benimse bir kez koşar; temel (base-charter) değişince canlı kimliklere yayan yol yoktu.
#   envanter — salt-oku retrofit-cetveli: yönetilen/elle kimlik sayımı (mimSerdar §6 iki-hızlı-filo ölçümü)
#   hook-bagla — snippet'i settings.json'a MERGE (D4; event-başına dedupe, hook-dışı anahtar dokunulmaz,
#              idempotent, default DRY-RUN — §4.4 'snippet bırakılıyor merge edilmiyor' tuzağı kapanır)
#   oturum-ac — doğum-kapısı PONG-probu (D4; headless claude -p + session_id round-trip; binary yoksa
#              exit 2 DÜRÜST-KIRMIZI, sahte-yeşil yok; --claude-bin test-dikişi)
#   (roster-yazımı/parity-flip → D7 · iskan-kur zinciri → D6.)
#
# ÜÇ-BÖLGE İDEMPOTENTLİK (mimSerdar §4.3 — tasarımın en değerli mekaniği):
#   <!-- ekipc:uretilen:basla surum=1 hash=<sha256> -->
#   ...manifest'ten render (HASH yalnız bu gövdenin — marker-satırları HARİÇ [öz-gönderim], ELLE HARİÇ)...
#   <!-- ekipc:uretilen:bitti -->
#   ## ELLE (ekipc dokunmaz)      ← rolün biriken hafızası; ekipc bu bölgeye BAYT-DOKUNMAZ
#   Durum-tablosu: dosya-yok→yaz · marker-yok→exit 6 (benimse gerekir) · aynı→no-op ·
#   farklı∧hash-tutar→yalnız üretilen-bölge güncellenir (ELLE bayt-aynı) · farklı∧hash-tutmaz→exit 5 + diff.
#   + MARKER-ÖNCESİ bölge (dosya tepesine insan-notu/rozet) 4. korunan-bölgedir: hash-DIŞI, her yazımda
#   bayt-verbatim başa konur (adversaryal-bulgu: eski sürüm GUNCELLE'de sessiz siliyordu — land-blocker'dı).
#   + Manifest-skalerleri render'da TEK-SATIRA katlanır + sentinel-metin reddedilir (adversaryal-bulgu:
#   çok-satırlı değerle marker-enjeksiyonu) · slug-benzersizliği zorunlu (MÜHÜRDAR/MUHURDAR çakışması exit 3).
#   ❌ Bilinçle reddedilen: AGENT.md'yi bayt-karşılaştırmak (elle-kimlikleri dondururdu). Denetim
#   BAŞLIK-VARLIĞI + üretilen-bölge-bütünlüğü üstünedir, metin-eşitliği değil.
#
# check EKSİK-DOSYA default'u WARN (drift değil): retrofit yapılmadan tüm-eksikler kırmızı olsa CI sonsuza
#   dek kırmızı kalır = roster-parity '2-hafta-sonra-flip hiç-olmadı' hastalığı. --tam bayrağı (D7 flip'i,
#   benimseme-SONRASI) eksikliği de drift sayar. Sıra pazarlıksız: D5 benimseme → D7 flip (mimSerdar §4.5).
#
# ARKA-UÇ (mimSerdar §4.3 İ1): manifest'ten türetilir (çağıran seçmez) — anayasa.baglayici:true→merkezi,
#   false ya da sinif:mahrem-tenant→hafif. D2'de İKİSİ DE roster'a DOKUNMAZ (roster-yazımı D7); hafif
#   arka-uç kalıcı-kural olarak Nexus 4-registry'sine ASLA yazmaz (İ1 negatif-testi: git diff = 0).
#
# GÜVENLİK/SINIR: ekipc yalnız --hedef kökü altına yazar; sır-değeri OKUMAZ/BASMAZ; GO-marker'ı YOK
#   (repo-only, CI-kapılı iş — mimSerdar §4.1). Canlı kimliklere (_agents/<slug>/AGENT.md) DOKUNMAZ;
#   onlar D5-benimseme turunun işi ve benimse bile --apply ister.
#
# Exit: 0 temiz/no-op/yazıldı · 1 check-drift · 2 ortam-eksiği (python3/PyYAML — unknown≠fail) ·
#       3 kullanım · 4 manifest lint-KIRMIZI (bozuk modelden derleme reddi) ·
#       5 üretilen-bölgeye insan yazmış (dosyaya DOKUNULMADI + diff) · 6 marker-yok (benimse gerekir)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

KOMUT="${1:-}"; [ $# -gt 0 ] && shift || true
MANIFEST="$ROOT/_agents/ekip-modeli.yaml"
HEDEF="$ROOT/_agents/ekip-os"
BASE_KATALOG="$ROOT/_agents/ekip-os-base"   # federe base-persona kataloğu (D4/E1): govde ORTAK-TEMEL'i buradan gömer; dizin/base-manifest yoksa enjeksiyon-yok (base'siz tenant → ince-çekirdek = backward-compat)
# PAKET KİPİ (Kuzey Hat E): düzen paketinde betiğin yanında cekirdek/ yaşar; Nexus deposu yoksa (izole kutu) katalog oradan okunur.
PAKET_KIPI=0
if [ ! -d "$BASE_KATALOG" ] && [ -f "$SCRIPT_DIR/../cekirdek/base-manifest.yaml" ]; then BASE_KATALOG="$(cd "$SCRIPT_DIR/../cekirdek" && pwd)"; PAKET_KIPI=1; fi
ROL=""; APPLY=0; TAM=0; AILE=""; DOSYA=""; KOK=""; SETTINGS=""; SNIPPET=""; CLAUDE_BIN=""; ZAMAN=120; BAZ=""

case "$KOMUT" in
  derle|check|benimse|yenile|envanter|hook-bagla|oturum-ac) ;;
  *) echo "kullanım: ekipc.sh derle|check|benimse|yenile|envanter|hook-bagla|oturum-ac [bayraklar] (başlık-yorumuna bak)" >&2; exit 3 ;;
esac

while [ $# -gt 0 ]; do
  case "$1" in
    --manifest) MANIFEST="${2:?--manifest <yaml>}"; shift ;;
    --hedef)    HEDEF="${2:?--hedef <dizin>}"; shift ;;
    --base-katalog) BASE_KATALOG="${2:?--base-katalog <dizin>}"; shift ;;  # federe base-persona kataloğu (test-dikişi + backward-compat)
    --rol)      ROL="${2:?--rol <AD>}"; shift ;;
    --aile)     AILE="${2:?--aile <yaml>}"; shift ;;      # lint'e geçirilir (test-enjeksiyon dikişi; lint K8/K9 kaynağı)
    --dosya)    DOSYA="${2:?--dosya <yol>}"; shift ;;     # benimse hedef-dosyası
    --baz)      BAZ="${2:?--baz <persona-tip>}"; shift ;;  # benimse: org-persona ortak-temeli (base_roller'dan AYRI eksen; --rol ile birlikte verilemez)
    --kok)      KOK="${2:?--kok <dizin>}"; shift ;;       # envanter ek-tarama kökü (ör. _agents)
    --settings) SETTINGS="${2:?--settings <json>}"; shift ;;   # hook-bagla: hedef settings.json
    --snippet)  SNIPPET="${2:?--snippet <json>}"; shift ;;     # hook-bagla: eklenecek hook-parçası
    --claude-bin) CLAUDE_BIN="${2:?--claude-bin <yol>}"; shift ;;  # oturum-ac test-dikişi (fake-bin)
    --zaman-asimi) ZAMAN="${2:?--zaman-asimi <sn>}"; shift ;;
    --apply)    APPLY=1 ;;
    --tam)      TAM=1 ;;                                   # check: eksik-dosya da drift sayılır (D7 flip'i)
    *) echo "bilinmeyen bayrak: $1" >&2; exit 3 ;;
  esac
  shift
done

command -v python3 >/dev/null 2>&1 || { echo "DOĞRULANAMADI: python3 yok (unknown≠fail) — exit 2" >&2; exit 2; }
python3 -c "import yaml" 2>/dev/null || { echo "DOĞRULANAMADI: PyYAML yok (unknown≠fail) — exit 2" >&2; exit 2; }
# --baz ile benimse/yenile ortak temelden üretir, ekip modeli GEREKMEZ (izole kutuda manifest yoktur); öteki komutlar manifest ister.
MANIFESTSIZ=0
if [ ! -f "$MANIFEST" ]; then
  if { [ "$KOMUT" = "benimse" ] || [ "$KOMUT" = "yenile" ]; } && [ -n "$BAZ" ]; then MANIFESTSIZ=1
  else echo "manifest yok: $MANIFEST" >&2; exit 3; fi
fi

# ── ÖN-KAPI: manifest lint'i (bozuk modelden derleme reddi). check/envanter salt-oku olduğundan
#    lint-kırmızıda bile koşar (drift'i GÖREBİLMEK için); derle/benimse YAZAR → temiz-model şart.
if [ "$MANIFESTSIZ" = "0" ] && { [ "$KOMUT" = "derle" ] || [ "$KOMUT" = "benimse" ] || [ "$KOMUT" = "yenile" ]; }; then
  LINT_RC=0
  LINT_ARGS=(--dosya "$MANIFEST" --root "$ROOT")
  [ -n "$AILE" ] && LINT_ARGS+=(--aile "$AILE")
  bash "$SCRIPT_DIR/ekip-modeli-lint.sh" "${LINT_ARGS[@]}" >/dev/null 2>&1 || LINT_RC=$?
  if [ "$LINT_RC" = "1" ]; then
    echo "🔴 manifest lint-KIRMIZI ($MANIFEST) — bozuk modelden derleme reddi. Önce lint'i temizle: bash scripts/ekip-modeli-lint.sh --dosya $MANIFEST" >&2
    exit 4
  elif [ "$LINT_RC" = "2" ]; then
    echo "DOĞRULANAMADI: lint ortam-eksiği bildirdi — exit 2" >&2; exit 2
  elif [ "$LINT_RC" != "0" ]; then
    echo "lint beklenmedik rc=$LINT_RC — kullanım hatası" >&2; exit 3
  fi
fi

export EKIPC_KOMUT="$KOMUT" EKIPC_MANIFEST="$MANIFEST" EKIPC_HEDEF="$HEDEF" EKIPC_ROL="$ROL" \
       EKIPC_APPLY="$APPLY" EKIPC_TAM="$TAM" EKIPC_DOSYA="$DOSYA" EKIPC_KOK="$KOK" EKIPC_ROOT="$ROOT" \
       EKIPC_SETTINGS="$SETTINGS" EKIPC_SNIPPET="$SNIPPET" EKIPC_CLAUDE_BIN="$CLAUDE_BIN" EKIPC_ZAMAN="$ZAMAN" \
       EKIPC_BASE_KATALOG="$BASE_KATALOG" EKIPC_BAZ="$BAZ" EKIPC_MANIFESTSIZ="$MANIFESTSIZ" EKIPC_PAKET_KIPI="$PAKET_KIPI"

python3 - <<'PY'
import difflib, hashlib, os, sys
import yaml

KOMUT   = os.environ["EKIPC_KOMUT"]
MANIFEST= os.environ["EKIPC_MANIFEST"]
HEDEF   = os.environ["EKIPC_HEDEF"]
ROL     = os.environ["EKIPC_ROL"]
APPLY   = os.environ["EKIPC_APPLY"] == "1"
TAM     = os.environ["EKIPC_TAM"] == "1"
DOSYA   = os.environ["EKIPC_DOSYA"]
KOK     = os.environ["EKIPC_KOK"]
SETTINGS= os.environ.get("EKIPC_SETTINGS", "")
SNIPPET = os.environ.get("EKIPC_SNIPPET", "")
CLAUDE_BIN = os.environ.get("EKIPC_CLAUDE_BIN", "")
BASE_KATALOG = os.environ.get("EKIPC_BASE_KATALOG", "")
BAZ     = os.environ.get("EKIPC_BAZ", "")
try:    ZAMAN = int(os.environ.get("EKIPC_ZAMAN", "120"))
except ValueError: ZAMAN = 120

SURUM = 1  # üretilen-bölge blok-şema sürümü
BASLA_ON = "<!-- ekipc:uretilen:basla"
BITTI    = "<!-- ekipc:uretilen:bitti -->"
ELLE_BASLIK = "## ELLE (ekipc dokunmaz)"

def oku(p):
    with open(p, encoding="utf-8") as f: return f.read()

def sha(s): return hashlib.sha256(s.encode("utf-8")).hexdigest()

import re as _re
def slug(ad):
    """rol-adı → dizin-adı. GÜVENLİK: yalnız [a-z0-9-] üretir — yol-kaçışı ('../', '/') YAPISAL-imkânsız
    (manifest güvensiz-girdi sayılır; hedef-kökü dışına yazma İ1-sınıfı ihlal olurdu)."""
    t = str.maketrans("ÇĞİÖŞÜçğıöşü", "CGIOSUcgiosu")
    s = str(ad).translate(t).lower().replace(" ", "-")
    if not _re.fullmatch(r"[a-z][a-z0-9-]*", s):
        print(f"rol-adı slug'lanamadı (yalnız harf/rakam/tire): {ad!r} → {s!r}", file=sys.stderr)
        sys.exit(3)
    return s

def t(v):
    """manifest-skalerini render-güvenli TEK-SATIRA indir (adversaryal-bulgu: çok-satırlı değerle
    marker-enjeksiyonu — gövde-içine düşen sahte 'bitti' satırı üç-bölge bütünlüğünü kırar, dosya
    kalıcı EL-DEGMIS'e sıkışır). newline→boşluk-katlama enjeksiyonu YAPISAL-imkânsız kılar (parcala
    sınırları tam-satır eşler; katlanmış metin asla kendi satırını işgal edemez). Sentinel-metni
    içeren değer yine de REDDEDİLİR (hijyen + gelecek-parser değişimlerine dayanıklılık)."""
    s = " ".join(str(v).split())
    if "ekipc:uretilen" in s:
        print(f"manifest-değeri ekipc-sentineli içeriyor — enjeksiyon-reddi: {s[:80]!r}", file=sys.stderr)
        sys.exit(3)
    return s

# ── manifest yükle ──
try:
    model = {} if os.environ.get("EKIPC_MANIFESTSIZ") == "1" else (yaml.safe_load(oku(MANIFEST)) or {})
except Exception as e:
    print(f"manifest parse-hatası: {e}", file=sys.stderr); sys.exit(3)
meta = model.get("meta") or {}
anayasa = meta.get("anayasa") or {}
sert = (model.get("sertlesme") or {}).get("k22_onay_damgasi") or {}
roller = model.get("roller") or []
if ROL:
    roller = [r for r in roller if isinstance(r, dict) and r.get("ad") == ROL]
    if not roller:
        print(f"rol bulunamadı: {ROL}", file=sys.stderr); sys.exit(3)

# arka-uç manifest'ten TÜRETİLİR (çağıran seçmez — mimSerdar §4.3)
if meta.get("sinif") == "mahrem-tenant" or anayasa.get("baglayici") is False:
    ARKA_UC = "hafif"
else:
    ARKA_UC = "merkezi"

# slug-çakışma denetimi — TÜM roller üstünde, --rol filtresinden BAĞIMSIZ (adversaryal-bulgu:
# MÜHÜRDAR/MUHURDAR → aynı 'muhurdar/' yoluna derlenir: sessiz son-kazanır ezme + derle/check
# sonsuz flip-flop. Lint K16 yalnız worktree/bolge dedupe eder — slug-benzersizliği BURANIN işi.)
_slug_haritasi = {}
for _r in (model.get("roller") or []):
    if not isinstance(_r, dict) or not _r.get("ad"): continue
    _s = slug(_r["ad"])
    if _s in _slug_haritasi:
        # aynı slug'a düşen HER 2. rol çakışmadır — AYNI-ad tekrarı dahil (adversaryal-bulgu: eski
        # '!= ad' istisnası aynı-ad iki-kez'i deliyordu → 2. rol 1.'yi sessizce eziyordu, exit 0).
        onceki = _slug_haritasi[_s]
        detay = f"'{onceki}' ve '{_r['ad']}'" if onceki != _r["ad"] else f"'{_r['ad']}' iki kez"
        print(f"slug-ÇAKIŞMASI: {detay} aynı dizine ({_s}/) derlenir — manifest'te adları ayrıştır (exit 3)", file=sys.stderr)
        sys.exit(3)
    _slug_haritasi[_s] = _r["ad"]

# ── federe base-persona kataloğu (D4/E1 · "tek base-katalog" kablosu): rol-adı → ortak-şart metin-dosyası.
#    base-manifest.yaml YOKSA (base-katalog dizini yok / base'siz tenant) → harita boş → enjeksiyon-yok
#    (ince-çekirdek = eski davranış, backward-compat). VARSA → govde() bu metni ORTAK-TEMEL olarak GÖMER:
#    D3'te GO-2 ile onaylanan MÜDÜR-base'i canlı-kimliğe indirir (değişmezler/kanunlar tek-kaynaktan yayılır).
#    Determinizm: dosya-içeriğine bağlı → charter değişirse govde-hash'i değişir (drift-yayılımı istenen).
PAKET_BASLIK = "<!-- kaynak: Sx duzen/cekirdek"
def temel_oku(yol):
    """Ortak temel metnini okur. Düzen paketinin cekirdek/ kopyalarının ilk satırı paket başlığıdır (surum.sh de karşılaştırmadan
    önce atar); kimliğe GÖMÜLMEZ — böylece paketten ve Nexus katalogundan üretilen bölge bayt-aynıdır."""
    t = oku(yol)
    k = t.split("\n", 1)
    return (k[1] if len(k) > 1 else "") if (k[0].startswith(PAKET_BASLIK) and k[0].rstrip().endswith("-->")) else t

def kaynak_etiketi(yol):
    """Üretilen bölgeye giren kaynak etiketi. Katalog depo içindeyse eski göreli yol (bayt-aynı); paket kipinde (katalog betiğin yanındaki cekirdek/ ya da depo dışı)
    ayni MANTIKSAL ad: böylece Nexus'ta ve izole kutuda üretilen bölge bayt-aynıdır, hash'ler uyuşur."""
    rel = os.path.relpath(yol, os.environ.get("EKIPC_ROOT", os.path.dirname(BASE_KATALOG) or "."))
    return "_agents/ekip-os-base/" + os.path.basename(yol) if (rel.startswith("..") or os.environ.get("EKIPC_PAKET_KIPI") == "1") else rel

BASE_ROL = {}       # {rol-adı: charter-dosya-adı} — HÜCRE-ROLÜ base'i (base_roller; govde ORTAK-TEMEL'i buradan)
PERSONA_BAZ = {}    # {persona-tip: charter-dosya-adı} — ORG-PERSONA ortak-temeli (persona_baz; benimse --baz, D5).
                    #   AYRI EKSEN: hücre-rolü ⟂ org-persona; ekip-modeli.yaml'a DOKUNMAZ (taksonomi-çakışma önlenir).
_base_mf = os.path.join(BASE_KATALOG, "base-manifest.yaml") if BASE_KATALOG else ""
if _base_mf and os.path.isfile(_base_mf):
    try:
        _bm = yaml.safe_load(oku(_base_mf)) or {}
    except Exception as e:
        print(f"base-manifest parse-hatası ({_base_mf}): {e}", file=sys.stderr); sys.exit(3)
    for _br in (_bm.get("base_roller") or []):
        if isinstance(_br, dict) and _br.get("ad") and _br.get("metin"):
            BASE_ROL[str(_br["ad"])] = str(_br["metin"])
    for _pb in (_bm.get("persona_baz") or []):
        if isinstance(_pb, dict) and _pb.get("ad") and _pb.get("metin"):
            PERSONA_BAZ[str(_pb["ad"])] = str(_pb["metin"])

# ── render: rol → AGENT.md üretilen-GÖVDE (deterministik; zaman-damgası YOK = idempotentlik) ──
def govde(r):
    ad = r.get("ad", "?"); L = []
    L.append(f"# {t(ad)} — {t(r.get('tek_cumle',''))}")
    L.append("")
    L.append(f"> ekipc-üretimi kimlik-çekirdeği (model v{t(meta.get('model_surumu','?'))} · örnek={t(meta.get('ornek','?'))} · arka-uç={ARKA_UC}).")
    L.append("> Bu bölge manifest'ten türetilir — elle DÜZENLEME; kalıcı ekleme/hafıza \"## ELLE\" bölgesine.")
    L.append("")
    L.append("## KİMLİK")
    cek = "evet" if r.get("cekirdek") else "hayır"
    L.append(f"- Rol: {t(ad)} · çekirdek: {cek}")
    if r.get("olcek_tetikli"): L.append(f"- Ölçek-tetiği: {t(r['olcek_tetikli'])}")
    L.append(f"- Tek-cümle: {t(r.get('tek_cumle',''))}")
    L.append("")
    L.append("## ÇALIŞMA-MODU")
    L.append(f"- Oturma-planı: {t(r.get('oturma_plani','?'))} (pane=kalıcı-tmux · cagri=çağrı-birimi · script=deterministik-substrat · uyku=park)")
    olcek = r.get("olcek") or {}
    sat = f"- Ölçek: adet={t(olcek.get('adet','?'))}"
    if olcek.get("tavan") is not None: sat += f" · tavan={t(olcek['tavan'])}"
    L.append(sat)
    for o in (olcek.get("ornekler") or []):
        if not isinstance(o, dict): continue
        ek = [f"durum={t(o.get('durum','?'))}"]
        if o.get("bolge"): ek.append(f"bölge={t(o['bolge'])}")
        if o.get("worktree"): ek.append(f"worktree={t(o['worktree'])}")
        L.append(f"- Koltuk: {t(o.get('kayit','?'))} ({' · '.join(ek)})")
    L.append("")
    L.append("## KANUNLAR")
    bag = "evet" if anayasa.get("baglayici") else "hayır"
    L.append(f"- Anayasa: {t(anayasa.get('kaynak','—'))} (bağlayıcı: {bag})")
    if sert:
        L.append(f"- K22 onay-damgası sertleşme: ci={t(sert.get('ci','—'))} · pre-commit={t(sert.get('pre-commit','—'))} · sevk={t(sert.get('sevk','—'))}")
    L.append("")
    L.append("## ASLA-YAPMAZLAR")
    for y in (r.get("yapamaz") or []):
        L.append(f"- {t(y)}")
    for ym in (r.get("yapamaz_makine") or []):
        if not isinstance(ym, dict): continue
        rc = f", rc={t(ym['rc'])}" if ym.get("rc") is not None else ""
        L.append(f"- [MAKİNE] {t(ym.get('kural','?'))} (dayatan: {t(ym.get('dayatan','?'))}{rc})")
    if not (r.get("yapamaz") or r.get("yapamaz_makine")):
        L.append("- (manifest'te yasak tanımlı değil)")
    L.append("")
    L.append("## MODEL-EŞLEMESİ")
    L.append("- Manifest v" + t(meta.get("model_surumu","?")) + " model-ataması taşımaz — model, oturum-başlatıcıda (baslat-claude.sh) belirlenir. (dürüst-boşluk: başlık-varlığı kontratı, metin-uydurma yok)")
    L.append("")
    L.append("## 3-EKSEN SCOPE")
    bolgeler = [t(o.get("bolge")) for o in (olcek.get("ornekler") or []) if isinstance(o, dict) and o.get("bolge")]
    L.append(f"- Bölge: {' · '.join(bolgeler) if bolgeler else 'atanmamış (doğum/retrofit turunda atanır)'}")
    L.append("- Erişim-scope: doğum-kapısında (İSKÂN) atanır — bu çekirdek doğrulanmamış erişim-iddiası TAŞIMAZ (dürüst-3-durum).")
    L.append("")
    L.append("## DEVİR-SINAVI KAPISI")
    L.append("- Koltuk-devri DEVİR-SINAVI'ndan geçmeden tamamlanmaz; senaryo metnini İNSAN yazar (yarı-üretim), makine-oracle'lar İSKÂN kabul-kapılarında koşar.")
    # ── ORTAK-TEMEL (federe base-persona): rol base-katalogda varsa GO-2 charter'ı verbatim GÖMÜLÜR.
    #    Base'siz rol/tenant → bu blok atlanır (byte-aynı eski çıktı). Bildirilmiş-ama-dosyası-yok =
    #    honest-error (sessiz-degrade YASAK: SERDAR charter'ı sessizce kaybetmesin).
    if ad in BASE_ROL:
        _charter_path = os.path.join(BASE_KATALOG, BASE_ROL[ad])
        if not os.path.isfile(_charter_path):
            print(f"base-manifest '{ad}' için metin bildiriyor ama dosya yok: {_charter_path} — federe base tutarsız (exit 3)", file=sys.stderr)
            sys.exit(3)
        _charter = temel_oku(_charter_path).rstrip("\n")
        _rel = kaynak_etiketi(_charter_path)
        L.append("")
        L.append("## ORTAK-TEMEL (federe base-persona · GO-2 onaylı)")
        L.append(f"> Bu rolün TÜM hücrelerde paylaşılan ortak-şartı — kaynak: {_rel} (ekip-os-base-derle üretir).")
        L.append("> Elle-düzenleme YASAK: temel orada değişir → tüm bu-rol kimliklerine birden yayılır. Hücreye-özel = ## ELLE.")
        L.append("")
        L.append(_charter)
    return "\n".join(L) + "\n"

def persona_govde(baz_ad):
    """org-persona ORTAK-TEMELİ → YÖNETİLEN-GÖVDE (benimse --baz, D5). govde(rol) hücre-rolü render eder;
    bu, ADI-OLAN BİREYİN (manuel-Claude / otonom-ajan) paylaşılan ortak-şartını VERBATİM taşır. İKİ-EKSEN
    AYRI: hücre-rolü ⟂ org-persona (ekip-modeli.yaml'a DOKUNMAZ; kaynak = base-manifest persona_baz).
    Deterministik (zaman-damgası yok = idempotent). Charter yazar-kaynağıdır ama sentinel içerirse üç-bölge
    kırılır → savunma-reddi (govde ORTAK-TEMEL'inden bir adım öte hijyen)."""
    yol = os.path.join(BASE_KATALOG, PERSONA_BAZ[baz_ad])
    if not os.path.isfile(yol):
        print(f"persona_baz '{baz_ad}' metin bildiriyor ama dosya yok: {yol} — federe base tutarsız (exit 3)", file=sys.stderr)
        sys.exit(3)
    charter = temel_oku(yol).rstrip("\n")
    if "ekipc:uretilen" in charter:
        print(f"persona-base '{baz_ad}' charter'ı ekipc-sentineli içeriyor — üç-bölge enjeksiyon-reddi (exit 3)", file=sys.stderr)
        sys.exit(3)
    rel = kaynak_etiketi(yol)
    L = []
    L.append(f"# ORTAK-TEMEL: {t(baz_ad)} (federe org-persona base · GO-2 emsali)")
    L.append("")
    L.append(f"> ekipc-üretimi paylaşılan persona-temeli — kaynak: {rel}. TÜM {t(baz_ad)} kimliklerinde ortaktır.")
    L.append("> Elle-düzenleme YASAK: temel orada değişir → bu-tip tüm personalara birden yayılır. Kişiye-özel (kimlik/görev/öz-farkındalık) = ## ELLE.")
    L.append("")
    L.append(charter)
    return "\n".join(L) + "\n"

def registry_govde():
    """ekip-registry.yaml üretilen-gövdesi — manifest'ten takım-roster'ı (D3). YALNIZ manifest'in
    BİLDİĞİ alanlar yazılır; tmux/inbox gibi doğum-anı alanları dürüst-boşluk (İSKÂN ekip-yerlestir
    doldurur — uydurma-değer YASAK, dürüst-3-durum)."""
    L = []
    L.append(f"ekip: {t(meta.get('ornek','?'))}")
    L.append(f"model_surumu: \"{t(meta.get('model_surumu','?'))}\"")
    L.append(f"arka_uc: {ARKA_UC}")
    L.append("uyeler:")
    for r in roller:
        if not isinstance(r, dict): continue
        for o in ((r.get("olcek") or {}).get("ornekler") or []):
            if not isinstance(o, dict) or not o.get("kayit"): continue
            L.append(f"  - id: {t(o['kayit'])}")
            L.append(f"    rol: {t(r.get('ad','?'))}")
            L.append(f"    durum: {t(o.get('durum','?'))}")
            if o.get("bolge"):    L.append(f"    bolge: {t(o['bolge'])}")
            if o.get("worktree"): L.append(f"    worktree: {t(o['worktree'])}")
            L.append(f"    kanallar: [kanallar/{slug(o['kayit'])}.md]")
            L.append("    tmux: null   # doğum-anı alanı — İSKÂN ekip-yerlestir doldurur (uydurma-değer yok)")
    return "\n".join(L) + "\n"

def grant_govde():
    """bolge-grant.yaml üretilen-gövdesi — statik bölge-yetki listesi (SANCAK A2 'dokunulan⊆grant'
    PR-lint deseninin girdi-dosyası; K16 benzersizliği lint'te zaten zorunlu)."""
    L = ["grants:"]
    for r in roller:
        if not isinstance(r, dict): continue
        for o in ((r.get("olcek") or {}).get("ornekler") or []):
            if not isinstance(o, dict) or not o.get("bolge"): continue
            L.append(f"  - kayit: {t(o.get('kayit','?'))}")
            L.append(f"    rol: {t(r.get('ad','?'))}")
            L.append(f"    bolge: {t(o['bolge'])}")
    if len(L) == 1: L.append("  []   # manifest'te bölge-atamalı örnek yok")
    return "\n".join(L) + "\n"

def devir_govde(r):
    """DEVIR-SINAVI.md iskeleti (yarı-üretim — mimSerdar §7/Q11: iskelet makine, senaryo İNSAN).
    Oracle-başlıkları İSKÂN BİTTİ-kontratı ailesinden; senaryolar bilinçli-boş placeholder."""
    ad = t(r.get("ad","?")); L = []
    L.append(f"# DEVİR-SINAVI — {ad} koltuğu")
    L.append("")
    L.append("> yarı-üretim: bu İSKELET makine-üretimi; SENARYO METNİNİ İNSAN YAZAR (sınavın keskinliği")
    L.append("> insan-muhakemesinden gelir — mimSerdar §7). Boş-senaryo = sınav HENÜZ HAZIR DEĞİL demektir;")
    L.append("> boş-senaryo ile devir-onayı VERİLEMEZ (fail-closed).")
    L.append("")
    L.append("## MAKİNE-ORACLE'LAR (deterministik ön-koşullar)")
    L.append(f"- [ ] rol-kimliği okundu-kanıtı: aday {ad} AGENT.md'sinin ASLA-YAPMAZLAR'ını kendi cümleleriyle sayar")
    L.append("- [ ] açılış-smoke: motor-smoke damgası taze (GAP-2 kapısı; pane-rol için)")
    L.append("- [ ] erişim-probu: rolün 3-EKSEN scope'undaki kritik-yetenekler taze-probe'lu (unknown≠fail beyanıyla)")
    L.append("- [ ] kanal-devri: önceki koltuk-sahibinin kanal-son-KONUM'u okundu, devir-notu yazıldı")
    L.append("")
    L.append("## İNSAN-SENARYOLARI (proktör ≠ aday; üreten ≠ doğrulayan)")
    L.append("- (senaryo-1: İNSAN YAZAR — bu satır placeholder'dır, sınav-hazır-değil işareti)")
    L.append("- (senaryo-2: İNSAN YAZAR)")
    L.append("")
    L.append("## VERDİKT")
    L.append("- sonuç: BEKLEMEDE (GEÇTİ/KALDI'yı proktör yazar; boş-senaryo ile GEÇTİ yazılamaz)")
    return "\n".join(L) + "\n"

def kanal_govde(kayit):
    """kanallar/<kayit>.md iskeleti — üyenin biriken kanal-dosyası. Üretilen-kısım YALNIZ 3-satır
    başlık; asıl içerik doğası gereği ELLE-bölgesidir (üyenin kendi günlüğü)."""
    return (f"# {t(kayit)} — kanal\n\n"
            f"> ekip={t(meta.get('ornek','?'))} · bu dosya üyenin biriken kanal-defteridir; girdiler ELLE-bölgesine.\n")

def stil_of(yol):
    """dosya-uzantısı → marker yorum-stili. md=HTML-yorum çıplak; yaml/sh='# ' önekli (D3: yorum-marker
    deseni — json/yaml'de HTML-yorum geçersiz olurdu; kahya-roster haritası 'json/yaml'de yorum-marker')."""
    return "yaml" if yol.endswith((".yaml", ".yml", ".sh")) else "md"

def _P(stil): return "# " if stil == "yaml" else ""

def tam_dosya(g, elle_icerik="", onek="", stil="md"):
    """gövde → marker-sarmalı tam dosya. onek (marker-ÖNCESİ insan-bölgesi) + elle_icerik ('## ELLE'den
    itibaren) BAYT-VERBATIM korunur — adversaryal-bulgu: marker-üstü insan-notu (donduruldu-notu, rozet)
    sessizce silinmemeli; marker-öncesi = 4. korunan-bölge (hash-DIŞI, ELLE ile aynı statüde)."""
    P = _P(stil)
    if not elle_icerik:
        if stil == "yaml":
            elle_icerik = f"{P}{ELLE_BASLIK}\n{P}(henüz elle-ek yok — kalıcı elle-girdiler bu çizginin altına)\n"
        else:
            elle_icerik = f"{ELLE_BASLIK}\n\n(henüz elle-not yok — rolün biriken hafızası buraya)\n"
    return (f"{onek}{P}{BASLA_ON} surum={SURUM} hash={sha(g)} -->\n{g}{P}{BITTI}\n\n{elle_icerik}")

def parcala(icerik):
    """dosya → (onek, stored_hash, govde, elle_bayt) ya da None (marker yok). onek = marker-öncesi
    insan-bölgesi, bayt-verbatim. Marker satırları stil-agnostik tanınır (çıplak ya da '# ' önekli)."""
    satirlar = icerik.split("\n")
    b0 = b1 = None
    for i, s in enumerate(satirlar):
        c = s.strip()
        if c.startswith("# "): c = c[2:]
        if b0 is None and c.startswith(BASLA_ON): b0 = i
        elif b0 is not None and c == BITTI: b1 = i; break
    if b0 is None or b1 is None: return None
    onek = ("\n".join(satirlar[:b0]) + "\n") if b0 > 0 else ""
    import re
    m = re.search(r"hash=([0-9a-f]{64})", satirlar[b0])
    stored = m.group(1) if m else ""
    g = "\n".join(satirlar[b0+1:b1]) + ("\n" if b1 > b0+1 else "")
    # ELLE-bölgesi: bitti-satırından SONRAKİ her şey, bayt-verbatim (baştaki boş satırlar dahil korunur;
    # yeniden-birleştirmede tam_dosya '\n\n' + elle kullanır → normalize: baştaki \n'leri kırp)
    elle = "\n".join(satirlar[b1+1:]).lstrip("\n")
    return (onek, stored, g, elle)

def durum_bul(yol, beklenen_govde):
    """(durum, detay) — YOK · MARKERSIZ · TEMIZ · GUNCELLE(safe) · EL-DEGMIS. detay=(onek, govde, elle)."""
    if not os.path.exists(yol): return ("YOK", None)
    icerik = oku(yol)
    p = parcala(icerik)
    if p is None: return ("MARKERSIZ", None)
    onek, stored, mevcut_govde, elle = p
    if sha(mevcut_govde) != stored:
        return ("EL-DEGMIS", (onek, mevcut_govde, elle))
    if mevcut_govde == beklenen_govde: return ("TEMIZ", (onek, mevcut_govde, elle))
    return ("GUNCELLE", (onek, mevcut_govde, elle))

# ── komutlar ──
if KOMUT in ("derle", "check"):
    # artefakt-listesi (D3): rol-başına AGENT.md + DEVIR-SINAVI.md · canlı-koltuk-başına kanal-iskeleti ·
    # model-düzeyi ekip-registry.yaml + bolge-grant.yaml. --rol filtresinde model-düzeyi ATLANIR
    # (tek-rol derlemesi takım-dosyalarını filtrelenmiş yarım-bilgiyle ezmesin — kasıtlı semantik).
    artefaktlar = []  # (etiket, yol, govde, stil)
    gorulen_kayit = set()
    for r in roller:
        if not isinstance(r, dict): continue
        ad = r.get("ad", "?")
        artefaktlar.append((f"{ad}/AGENT.md", os.path.join(HEDEF, slug(ad), "AGENT.md"), govde(r), "md"))
        artefaktlar.append((f"{ad}/DEVIR-SINAVI.md", os.path.join(HEDEF, slug(ad), "DEVIR-SINAVI.md"), devir_govde(r), "md"))
        for o in ((r.get("olcek") or {}).get("ornekler") or []):
            if not isinstance(o, dict) or not o.get("kayit"): continue
            k = o["kayit"]
            if k in gorulen_kayit: continue   # aynı koltuk 2 rolde listelenirse kanal TEK (dedupe)
            gorulen_kayit.add(k)
            artefaktlar.append((f"kanallar/{k}", os.path.join(HEDEF, "kanallar", f"{slug(k)}.md"), kanal_govde(k), "md"))
    if not ROL:
        artefaktlar.append(("ekip-registry.yaml", os.path.join(HEDEF, "ekip-registry.yaml"), registry_govde(), "yaml"))
        artefaktlar.append(("bolge-grant.yaml", os.path.join(HEDEF, "bolge-grant.yaml"), grant_govde(), "yaml"))

    sonuc = []
    for etiket, yol, g, stil in artefaktlar:
        durum, detay = durum_bul(yol, g)
        sonuc.append((etiket, yol, g, stil, durum, detay))

    if KOMUT == "check":
        drift = 0; eksik = 0
        for etiket, yol, g, stil, durum, detay in sonuc:
            isaret = {"TEMIZ":"🟢","YOK":"⚪","GUNCELLE":"🟡","EL-DEGMIS":"🔴","MARKERSIZ":"🟠"}[durum]
            print(f"  {isaret} {etiket}: {durum} ({os.path.relpath(yol, os.environ['EKIPC_ROOT'])})")
            if durum in ("GUNCELLE", "EL-DEGMIS", "MARKERSIZ"): drift += 1
            if durum == "YOK": eksik += 1
        if eksik and not TAM:
            print(f"  ⚠️ {eksik} artefakt henüz yok — drift SAYILMADI (D5-benimseme/D7-flip öncesi normal; --tam ile zorla)")
        toplam_drift = drift + (eksik if TAM else 0)
        if toplam_drift:
            print(f"🔴 ekipc check: {toplam_drift} drift"); sys.exit(1)
        print(f"🟢 ekipc check TEMİZ ({len(sonuc)} artefakt · arka-uç={ARKA_UC})"); sys.exit(0)

    # derle
    yazilacak = []; el_degmis = []; markersiz = []
    for etiket, yol, g, stil, durum, detay in sonuc:
        if durum == "YOK": yazilacak.append((yol, tam_dosya(g, stil=stil), "YENİ"))
        elif durum == "GUNCELLE":
            onek, _, elle = detay
            yazilacak.append((yol, tam_dosya(g, elle if elle.strip() else "", onek, stil), "GÜNCELLE (yalnız üretilen-bölge; önek+ELLE bayt-aynı)"))
        elif durum == "EL-DEGMIS":
            _, mevcut_govde, _ = detay
            el_degmis.append((yol, mevcut_govde, g))
        elif durum == "MARKERSIZ":
            markersiz.append(yol)
        # TEMIZ → no-op
    if el_degmis:
        for yol, mevcut, beklenen in el_degmis:
            print(f"🔴 EL-DEĞMİŞ: {yol} — üretilen-bölgeye insan yazmış; DOKUNULMADI. Diff (beklenen→mevcut):", file=sys.stderr)
            for d in difflib.unified_diff(beklenen.splitlines(), mevcut.splitlines(), "beklenen", "mevcut", lineterm=""):
                print(f"    {d}", file=sys.stderr)
        print("çözüm: değişikliği ELLE-bölgesine taşı ya da manifest'i güncelle; sonra yeniden derle", file=sys.stderr)
        sys.exit(5)
    if markersiz:
        for yol in markersiz:
            print(f"🟠 MARKER-YOK: {yol} — elle-yazılmış kimlik; ÜZERİNE YAZILMAZ. `ekipc.sh benimse --dosya {yol} --rol <AD> --apply` ile ELLE-bölgesine al.", file=sys.stderr)
        sys.exit(6)
    if not yazilacak:
        print(f"🟢 ekipc derle: no-op ({len(sonuc)} rol zaten güncel · arka-uç={ARKA_UC} · roster-yazımı D7'de — bu sürüm roster'a DOKUNMAZ)")
        sys.exit(0)
    for yol, icerik, etiket in yazilacak:
        print(f"  {'✍️' if APPLY else '📋'} {etiket}: {os.path.relpath(yol, os.environ['EKIPC_ROOT'])}")
        if APPLY:
            os.makedirs(os.path.dirname(yol), exist_ok=True)
            with open(yol, "w", encoding="utf-8") as f: f.write(icerik)
    if APPLY:
        print(f"🟢 ekipc derle: {len(yazilacak)} dosya yazıldı (arka-uç={ARKA_UC} · roster-yazımı D7'de)")
    else:
        print(f"📋 DRY-RUN: {len(yazilacak)} dosya yazılacaktı — uygulamak için --apply")
    sys.exit(0)

elif KOMUT == "benimse":
    # İKİ MOD: --rol <AD> → hücre-rolü govde'si (mevcut) · --baz <tip> → org-persona ortak-temeli (D5).
    # İkisi de --dosya'nın MEVCUT içeriğini `## ELLE`'ye BAYT-VERBATIM taşır; yalnız yönetilen-gövde farklıdır.
    if not DOSYA: print("benimse --dosya <yol> (--rol <AD> | --baz <tip>) ister", file=sys.stderr); sys.exit(3)
    if not os.path.exists(DOSYA): print(f"dosya yok: {DOSYA}", file=sys.stderr); sys.exit(3)
    if BAZ and ROL:
        print("benimse: --rol ve --baz birlikte verilemez (hücre-rolü ⟂ org-persona — birini seç)", file=sys.stderr); sys.exit(3)
    mevcut = oku(DOSYA)
    if parcala(mevcut) is not None:
        print("dosya zaten ekipc-yönetimli (marker var) — benimse gereksiz", file=sys.stderr); sys.exit(3)
    if BAZ:
        if BAZ not in PERSONA_BAZ:
            print(f"benimse --baz '{BAZ}' base-manifest persona_baz kataloğunda yok (base-katalog: {BASE_KATALOG}). Tanımlı: {sorted(PERSONA_BAZ) or '—'}", file=sys.stderr); sys.exit(3)
        g = persona_govde(BAZ)
    else:
        if not ROL or len(roller) != 1: print("benimse tek --rol <AD> (ya da --baz <tip>) ister", file=sys.stderr); sys.exit(3)
        g = govde(roller[0])
    stil = stil_of(DOSYA)
    elle = f"{_P(stil)}{ELLE_BASLIK}\n\n{mevcut}"   # mevcut içerik BAYT-VERBATIM — hiçbir cümle yeniden yazılmaz
    yeni = tam_dosya(g, elle, stil=stil)
    _kaynak = f"persona-base '{BAZ}'" if BAZ else f"rol '{ROL}'"
    if APPLY:
        with open(DOSYA, "w", encoding="utf-8") as f: f.write(yeni)
        print(f"🟢 benimsendi: {DOSYA} — {_kaynak} çekirdeği eklendi, mevcut içerik ELLE-bölgesinde bayt-verbatim")
    else:
        print(f"📋 DRY-RUN benimse: {DOSYA} → {_kaynak} çekirdeği + ELLE'ye {len(mevcut)} bayt verbatim taşınacak — --apply ile uygula")
    sys.exit(0)

elif KOMUT == "yenile":
    # benimse'nin İKİZİ: benimse marker'sız dosyayı bağlar (bir kez); yenile marker'lı dosyanın yönetilen-
    # gövdesini BUGÜNKÜ temelden yeniden üretir. derle'nin GUNCELLE kuralıyla aynı: önek + ELLE bayt-aynı,
    # hash tutmuyorsa (insan yönetilen-bölgeye yazmış) DOKUNMAZ → exit 5 + diff.
    if not DOSYA: print("yenile --dosya <yol> (--baz <tip> | --rol <AD>) ister", file=sys.stderr); sys.exit(3)
    if not os.path.exists(DOSYA): print(f"dosya yok: {DOSYA}", file=sys.stderr); sys.exit(3)
    if BAZ and ROL:
        print("yenile: --rol ve --baz birlikte verilemez (hücre-rolü ⟂ org-persona — birini seç)", file=sys.stderr); sys.exit(3)
    if BAZ:
        if BAZ not in PERSONA_BAZ:
            print(f"yenile --baz '{BAZ}' base-manifest persona_baz kataloğunda yok. Tanımlı: {sorted(PERSONA_BAZ) or '—'}", file=sys.stderr); sys.exit(3)
        g = persona_govde(BAZ)
    else:
        if not ROL or len(roller) != 1: print("yenile tek --rol <AD> (ya da --baz <tip>) ister", file=sys.stderr); sys.exit(3)
        g = govde(roller[0])
    durum, detay = durum_bul(DOSYA, g)
    if durum == "MARKERSIZ":
        print(f"🟠 MARKER-YOK: {DOSYA} — henüz benimsenmemiş; önce `ekipc.sh benimse` (exit 6)", file=sys.stderr); sys.exit(6)
    if durum == "EL-DEGMIS":
        _, mevcut_govde, _ = detay
        print(f"🔴 EL-DEĞMİŞ: {DOSYA} — üretilen-bölgeye insan yazmış; DOKUNULMADI. Diff (beklenen→mevcut):", file=sys.stderr)
        for d in difflib.unified_diff(g.splitlines(), mevcut_govde.splitlines(), "beklenen", "mevcut", lineterm=""):
            print(f"    {d}", file=sys.stderr)
        sys.exit(5)
    if durum == "TEMIZ":
        print(f"🟢 yenile: no-op — {DOSYA} yönetilen-gövdesi zaten güncel"); sys.exit(0)
    onek, mevcut_govde, elle = detay
    stil = stil_of(DOSYA)
    yeni = tam_dosya(g, elle if elle.strip() else "", onek, stil)
    if APPLY:
        with open(DOSYA, "w", encoding="utf-8") as f: f.write(yeni)
        print(f"🟢 yenilendi: {DOSYA} — yönetilen-gövde bugünkü temelden; önek + ELLE bayt-aynı")
    else:
        _f = sum(1 for d in difflib.unified_diff(mevcut_govde.splitlines(), g.splitlines(), lineterm="") if d[:1] in "+-" and d[:3] not in ("+++", "---"))
        print(f"📋 DRY-RUN yenile: {DOSYA} → yönetilen-gövdede {_f} satır değişecek — --apply ile uygula")
    sys.exit(0)

elif KOMUT == "hook-bagla":
    # D4: hook-snippet'i settings.json'a MERGE et (tuzak-tablosu §4.4: 'snippet bırakılıyor, merge
    # edilmiyor' → sıfır-otomasyon kapanır). Event-başına dedupe'lu append; hook-DIŞI anahtarlara
    # DOKUNULMAZ; idempotent (re-run no-op). Default DRY-RUN. Settings yoksa boş-{}'tan başlar (yeni-tenant).
    import json
    if not SNIPPET: print("hook-bagla --snippet <json> ister (--settings <json> hedefi; yoksa yeni oluşturulur --apply'da)", file=sys.stderr); sys.exit(3)
    if not SETTINGS: print("hook-bagla --settings <json> ister", file=sys.stderr); sys.exit(3)
    if not os.path.exists(SNIPPET): print(f"snippet yok: {SNIPPET}", file=sys.stderr); sys.exit(3)
    try:
        snip = json.loads(oku(SNIPPET))
    except json.JSONDecodeError as e:
        print(f"snippet JSON-bozuk: {e}", file=sys.stderr); sys.exit(3)
    ayarlar = {}
    if os.path.exists(SETTINGS):
        try:
            ayarlar = json.loads(oku(SETTINGS))
        except json.JSONDecodeError as e:
            print(f"settings JSON-bozuk (DOKUNULMADI): {e}", file=sys.stderr); sys.exit(3)
    if not isinstance(ayarlar, dict) or not isinstance(snip, dict):
        print("settings/snippet kök-objesi dict değil", file=sys.stderr); sys.exit(3)
    snip_hooks = snip.get("hooks", snip)   # snippet ya {hooks:{...}} ya doğrudan {Event:[...]}
    if not isinstance(snip_hooks, dict):
        print("snippet hook-haritası dict değil", file=sys.stderr); sys.exit(3)
    def _norm(x): return json.dumps(x, sort_keys=True, ensure_ascii=False)
    eklenen = 0; zaten = 0
    hooks = ayarlar.setdefault("hooks", {})
    for event, girisler in snip_hooks.items():
        if not isinstance(girisler, list):
            print(f"snippet[{event}] liste değil", file=sys.stderr); sys.exit(3)
        mevcut = hooks.setdefault(event, [])
        mevcut_norm = {_norm(m) for m in mevcut}
        for g_ in girisler:
            if _norm(g_) in mevcut_norm:
                zaten += 1; print(f"  = {event}: zaten-bağlı (dedupe)")
            else:
                eklenen += 1; mevcut.append(g_); mevcut_norm.add(_norm(g_))
                print(f"  + {event}: bağlanacak" if not APPLY else f"  ✍️ {event}: bağlandı")
    if eklenen and APPLY:
        os.makedirs(os.path.dirname(SETTINGS) or ".", exist_ok=True)
        with open(SETTINGS, "w", encoding="utf-8") as f:
            json.dump(ayarlar, f, indent=2, ensure_ascii=False); f.write("\n")
        print(f"🟢 hook-bagla: {eklenen} giriş bağlandı · {zaten} zaten-vardı → {SETTINGS}")
    elif eklenen:
        print(f"📋 DRY-RUN hook-bagla: {eklenen} giriş bağlanacaktı · {zaten} zaten-var — --apply ile uygula")
    else:
        print(f"🟢 hook-bagla: no-op ({zaten} girişin hepsi zaten-bağlı — idempotent)")
    sys.exit(0)

elif KOMUT == "oturum-ac":
    # D4: doğum-kapısı PONG-probu — headless `claude -p` PING→PONG + session_id round-trip.
    # Binary yoksa DÜRÜST-KIRMIZI exit 2 (sahte-yeşil YASAK — mimSerdar §4.4 'claude oturumu' tuzağı).
    # --claude-bin = test-dikişi (fake-bin fixture; DISPATCH_MODEL_LINT_BIN emsali). Sır basmaz.
    import json, shutil, subprocess
    bin_ = CLAUDE_BIN or shutil.which("claude") or ""
    if not bin_ or not (os.path.isfile(bin_) and os.access(bin_, os.X_OK)):
        print("🔴 DOĞRULANAMADI: claude-binary yok/çalıştırılamaz — oturum-kapısı GEÇEMEZ (dürüst-kırmızı, sahte-yeşil yok). exit 2", file=sys.stderr)
        sys.exit(2)
    try:
        p = subprocess.run([bin_, "-p", "Yalnız tek kelimeyle yanıtla: PONG", "--output-format", "json"],
                           capture_output=True, text=True, timeout=ZAMAN)
    except subprocess.TimeoutExpired:
        print(f"🔴 oturum-probu zaman-aşımı ({ZAMAN}s) — PONG alınamadı. exit 1", file=sys.stderr); sys.exit(1)
    if p.returncode != 0:
        print(f"🔴 claude çıkış-kodu {p.returncode} — PONG alınamadı (stderr ilk-satır: {(p.stderr or '').splitlines()[:1]})", file=sys.stderr); sys.exit(1)
    try:
        res = json.loads(p.stdout)
    except json.JSONDecodeError:
        print("🔴 claude çıktısı JSON-parse edilemedi — PONG doğrulanamadı. exit 1", file=sys.stderr); sys.exit(1)
    sid = res.get("session_id") or ""
    metin = str(res.get("result", ""))
    if "PONG" in metin and sid:
        print(f"🟢 PONG — oturum-kapısı GEÇTİ (session_id={sid} · bin={os.path.basename(bin_)})")
        sys.exit(0)
    print(f"🔴 PONG-doğrulaması başarısız (result-önizleme: {metin[:60]!r} · session_id={'var' if sid else 'YOK'}). exit 1", file=sys.stderr)
    sys.exit(1)

elif KOMUT == "envanter":
    # salt-oku: --hedef + (varsa) --kok altında */AGENT.md → yönetilen mi elle mi (mimSerdar §6 cetveli)
    import glob
    kokler = [HEDEF] + ([KOK] if KOK else [])
    yonetilen = []; elle_ = []
    for k in kokler:
        for yol in sorted(glob.glob(os.path.join(k, "*", "AGENT.md"))):
            (yonetilen if parcala(oku(yol)) is not None else elle_).append(yol)
    print(f"ekipc envanter (salt-oku): yönetilen={len(yonetilen)} · elle={len(elle_)}")
    for y in yonetilen: print(f"  🟢 yönetilen: {y}")
    for y in elle_:     print(f"  🟠 elle (benimse-adayı): {y}")
    sys.exit(0)
PY
