#!/usr/bin/env bash
# ekip-modeli-lint.sh — ekip org-modeli bekçisi (Ekip-OS GAP-1 dilim-1 · k0146 · mimSerdar §2.5)
#
# NE: _agents/ekip-modeli.yaml şema + tutarlılık + MEZARLIK-YASAĞI denetimi. İskelet: filo-registry-lint.sh.
#   K1  şema: roller[] + her rolde ad/tek_cumle/oturma_plani/olcek; oturma_plani enum.
#   K5  MEZARLIK YASAĞI (§2.3, modelin omurgası): her yapamaz_makine.dayatan (a) var (b) bir ZORUNLU-YOL'da
#       gerçekten çağrılıyor. Değilse 🔴 'MEZARLIK: <yol> hiçbir zorunlu-yolda çağrılmıyor'.
#   K8  pane-rol ornekler[].kayit → aile-registry'de pane-üye OLMALI.
#   K9  cagri-rol → aile-registry'de pane-üye OLMAMALI (körlük-vetosu mekanikleşir).
#   K13 ornekler varsa: adet == count(ornekler[durum==canli]) ("kanon 2 der sahada 1" driftini imkânsız kılar).
#   K16 ornekler arası worktree ve bolge BENZERSİZ → duplikasyon yapısal-imkânsız.
#   K17 HAYALET-ÜYE (dilim-3): durum:canli ∧ son-kontak >30g → ⚠️ WARN (report-only, BLOKLAMAZ). Son-kontak =
#       üyenin kanallar[] dosyalarının en-son git-commit tarihi = KUSURLU-PROXY → hard-red DEĞİL (aşağıda gerekçe;
#       güvenilir heartbeat gelince kırmızıya terfi). referans-now=--bugun|today; --kontak ile test-enjekte.
#   K23 ŞERİT (L25-W11 · K13): aile-registry'de rol ⟂ şerit eşlemesi — mod motor|kod → kapi ·
#       salt-plan|salt-okur → normal. Gerekçeli `# istisna: …` işareti sapmayı meşrulaştırır, işaretsiz
#       sapma 🔴. Alanı HİÇ olmayan registry kapsam-dışı (⚠️ WARN, bulgu değil). Bekçi: serit-esleme-lint.py.
#   (K21 takvimli-sertleşme · K22 Sultan-onay-damgası → dilim-2. Sevk dispatch-gate = aile-dispatch.sh (b4) exit-8 → dilim-3.)
#
# ZORUNLU-YOL allowlist (K5): scripts/aile-dispatch.sh + scripts/dongu-sayac.sh (dayatma İÇLERİNDE) ·
#   deploy/githooks/** · .github/workflows/** · ayrıca her yapamaz_makine kendi 'cagrildigi' glob'unu ekleyebilir.
#
# Exit: 0 temiz · 1 bulgu(drift/mezarlık) · 2 DOĞRULANAMADI (PyYAML yok = ortam-eksiği, unknown≠fail) · 3 kullanım.
# Report-only DEĞİL: bekçidir, bulguda kırmızı düşer. Sır-değer BASMAZ.
# KULLANIM: ekip-modeli-lint.sh [--dosya <yaml>] [--aile <yaml>] [--root <dizin>] [--onaylar <yaml>] [--kapi ci|pre-commit|sevk] [--bugun <YYYY-MM-DD>] [--kontak <yaml>]
#   Fixture/test-enjeksiyon bayrakları. --bugun EXPLICIT (ambient env DEĞİL) → kapılar üretimde ortam-mirasıyla oynanamaz. --kontak = K17 son-kontak haritası (git-log yerine).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOSYA=""; AILE=""; ONAYLAR=""; KAPI="ci"; BUGUN=""; KONTAK=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dosya)   DOSYA="${2:?--dosya <yaml>}"; shift ;;
    --aile)    AILE="${2:?--aile <yaml>}"; shift ;;
    --root)    ROOT="${2:?--root <dizin>}"; shift ;;
    --onaylar) ONAYLAR="${2:?--onaylar <yaml>}"; shift ;;
    --kapi)    KAPI="${2:?--kapi ci|pre-commit|sevk}"; shift ;;   # K21: hangi çağrı-yeri (K22 flip-tarihi ona göre)
    --bugun)   BUGUN="${2:?--bugun <YYYY-MM-DD>}"; shift ;;       # K21/K17 test-injection: 'bugün'ü (referans-now) EXPLICIT ver. Ambient env DEĞİL
                                                                 # → pre-commit ortam-mirasıyla kapıları git-izsiz susturamaz (adversaryal-hijyen).
    --kontak)  KONTAK="${2:?--kontak <yaml>}"; shift ;;          # K17 test-injection: kayit→son-kontak-ISO haritası (varsa git-log yerine bu kullanılır).
    *) echo "HATA: bilinmeyen bayrak: $1 (kullanım: ekip-modeli-lint.sh [--dosya <yaml>] [--aile <yaml>] [--root <dizin>] [--onaylar <yaml>] [--kapi ci|pre-commit|sevk] [--bugun <YYYY-MM-DD>] [--kontak <yaml>])" >&2; exit 3 ;;
  esac; shift
done
case "$KAPI" in ci|pre-commit|sevk) ;; *) echo "HATA: --kapi ci|pre-commit|sevk olmalı: $KAPI" >&2; exit 3 ;; esac
DOSYA="${DOSYA:-$ROOT/_agents/ekip-modeli.yaml}"
AILE="${AILE:-$ROOT/_agents/handoff/aile-registry.yaml}"
ONAYLAR="${ONAYLAR:-$ROOT/_agents/ekip-modeli-onaylar.yaml}"

# K23 bekçisi bu script'in KENDİ dizininden çözülür (--root fixture'a çevrilse de kaybolmaz).
SERIT_LINT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/serit-esleme-lint.py"
export SERIT_LINT
python3 - "$DOSYA" "$AILE" "$ROOT" "$ONAYLAR" "$KAPI" "$BUGUN" "$KONTAK" <<'PY'
import os, re, sys, glob, datetime

dosya, aile, root, onaylar_yol, kapi, bugun_ovr = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6]
kontak_yol = sys.argv[7] if len(sys.argv) > 7 else ""
import subprocess
try:
    import yaml
except Exception:
    print("⚪ doğrulanamadı: PyYAML yok (ortam-eksiği; bulgu DEĞİL)")
    sys.exit(2)

def oku(p):
    return open(p, encoding="utf-8").read()

try:
    ham = oku(dosya)
except Exception:
    print(f"🔴 bulgu: ekip-modeli okunamadı: {dosya}"); sys.exit(1)

try:
    d = yaml.safe_load(ham)
    if not isinstance(d, dict): raise ValueError("kök dict değil")
except Exception:
    print("🔴 bulgu: YAML çözülemedi ya da kök-yapı bozuk"); sys.exit(1)

bulgular = []
OTURMA = {"pane", "cagri", "script", "uyku", "script+cagri"}

roller = d.get("roller")
if not isinstance(roller, list) or not roller:
    print("🔴 bulgu: 'roller' listesi yok/boş"); sys.exit(1)

# aile-registry pane-üyeleri (id + arz_adi; yalnız tmux'lu kayıtlar = pane) — line-based (PyYAML'a zorlamayız)
# + K17 için: her üyenin (id/arz_adi) kanallar[] listesi → son-kontak git-log kaynağı.
pane_kimlikler = set()
uye_kanallar = {}   # kayit (id VE arz_adi) -> [kanal-yolları]  (K17 çözümü kayit→member)
try:
    ah = oku(aile)
    cur = None; cur_arz = None
    for line in ah.splitlines():
        m = re.match(r"\s*-\s*id:\s*(\S+)", line)
        if m: cur = m.group(1); cur_arz = None; continue
        m = re.match(r"\s*arz_adi:\s*\"?([^\"#\s]+)\"?", line)
        if m and cur: cur_arz = m.group(1); pane_kimlikler.add(cur_arz)
        m = re.match(r"\s*tmux:\s*\"?([^\"#\s]+)\"?", line)
        if m and cur: pane_kimlikler.add(cur)   # tmux'lu → pane-üye (id'yle işaretle)
        m = re.match(r"\s*kanallar:\s*\[(.*)\]", line)
        if m and cur:
            kanlar = [x.strip() for x in m.group(1).split(",") if x.strip()]
            uye_kanallar[cur] = kanlar
            if cur_arz: uye_kanallar[cur_arz] = kanlar   # arz_adi ile de erişilebilsin (model kayit=arz_adi kullanabilir)
except Exception:
    bulgular.append(f"aile-registry okunamadı (K8/K9 doğrulanamadı): {aile}")
    pane_kimlikler = None

# ── ZORUNLU-YOL içerikleri (K5 mezarlık-taraması) — INVOCATION-FARKINDA (adversaryal-sertleştirme) ──
def _dosya_iceren(globlar):
    parcalar = []
    for g in globlar:
        for p in glob.glob(os.path.join(root, g), recursive=True):
            if os.path.isfile(p):
                try: parcalar.append(oku(p))
                except Exception: pass
    return "\n".join(parcalar)

def _clean_zorunlu(content):
    # '#' yorum + YAML TETİK-blokları (on/push/pull_request/paths/branches/tags/concurrency/workflow_dispatch)
    # çıkarılır → geriye YALNIZ gerçek-invocation satırları (run:/bash/exec) kalır. 'paths:' bir tetik-KOŞULU,
    # çağrı DEĞİL — onu içerikte bırakmak "ad geçiyor = wired" yanlış-pozitifini üretiyordu (adversaryal-bulgu).
    TETIK = {"on","push","pull_request","paths","paths-ignore","branches","tags","concurrency","workflow_dispatch"}
    out=[]; skip=None
    for raw in content.splitlines():
        s = raw.strip()
        if not s or s.startswith("#"): continue
        indent = len(raw) - len(raw.lstrip())
        if skip is not None:
            if indent > skip: continue
            skip = None
        key = s.split(":",1)[0].strip().strip('"').strip("'")
        if key in TETIK:
            skip = indent; continue
        out.append(raw)
    return "\n".join(out)

ZORUNLU_CLEAN = _clean_zorunlu(_dosya_iceren(["deploy/githooks/**", ".github/workflows/**"]))
# dayatma-İÇİNDE olan zorunlu-yollar (kendileri sevk/sayaç zinciri → doğuştan canlı; §2.5:200-202)
ICSEL_DAYATAN = {"scripts/aile-dispatch.sh", "scripts/dongu-sayac.sh"}

def _invoked(dayatan):
    # TAM göreli yol, kelime-sınırlı (substring DEĞİL → 'sayac.sh' ⊂ 'dongu-sayac.sh' yanlış-pozitifi kapanır).
    # Baş-sınıra '/' dahil ($ROOT/scripts/x.sh çağrısı da yakalanır); paths/yorum zaten temizlenmiş.
    esc = re.escape(dayatan)
    return re.search(r'(?:^|[\s"\'`(=/])' + esc + r'(?:$|[\s"\'`);])', ZORUNLU_CLEAN, re.M) is not None

def mezarlik_wired(dayatan, rc):
    """dayatan bir zorunlu-yolda GERÇEKTEN çağrılıyor mu (ad-geçmesi yetmez) + iddia edilen rc gerçek mi?"""
    if not (isinstance(dayatan, str) and dayatan.strip()):
        return False, "dayatan boş"
    dpath = os.path.join(root, dayatan)
    if not os.path.isfile(dpath):
        return False, f"dayatan dosyası YOK: {dayatan}"
    # (a) WIRING: içsel-zorunlu-yol YA DA gerçek-invocation (substring/paths DEĞİL)
    if not (dayatan in ICSEL_DAYATAN or _invoked(dayatan)):
        return False, f"MEZARLIK: {dayatan} hiçbir zorunlu-yolda GERÇEKTEN çağrılmıyor (ad-geçmesi yetmez)"
    # (b) RC-DOĞRULAMA: iddia edilen rc dayatan'da 'exit <rc>' (ya da sys.exit(rc)) olarak GERÇEKTEN var mı
    #     → içsel dosyaya bile atfedilen UYDURMA rc (ör. rc:999) burada kırmızı düşer (sahte-dayatma kapanır).
    if rc is not None:
        try: dcontent = oku(dpath)
        except Exception: dcontent = ""
        if not re.search(r'exit[\s(]+%s\b' % re.escape(str(rc)), dcontent):
            return False, f"rc={rc} dayatan'da 'exit {rc}' olarak bulunamadı ({dayatan}) — sahte-dayatma iddiası"
    return True, "wired"

# ── K21/K22 hazırlık: Sultan-onay damgaları (sidecar) + takvimli-sertleşme flip-tarihi ──
uyarilar = []   # WARN (report-only) — exit'i ETKİLEMEZ; K21 grace-penceresinde K22 buraya düşer.
onaylar = {}
try:
    od = yaml.safe_load(oku(onaylar_yol)) if os.path.isfile(onaylar_yol) else None
    if isinstance(od, dict) and isinstance(od.get("onaylar"), dict):
        onaylar = od["onaylar"]
except Exception:
    onaylar = {}   # sidecar bozuk → damga-yok muamelesi (K22 grace/hard'a göre karar verir)

# K21: bu çağrı-yerinin (kapi) K22-flip tarihi model'deki sertlesme bloğundan; bugün >= tarih → HARD, değilse WARN.
def _tarih(s):
    try: return datetime.date.fromisoformat(str(s))
    except Exception: return None
bugun = _tarih(bugun_ovr) or datetime.date.today()
_sert = (d.get("sertlesme") or {}).get("k22_onay_damgasi") or {}
_flip = _tarih(_sert.get(kapi))
k22_hard = (_flip is not None and bugun >= _flip)   # flip-tarih yoksa → hard DEĞİL (güvenli varsayılan)

def _onay_dolu(ad):
    e = onaylar.get(ad)
    if not isinstance(e, dict): return False
    dm = e.get("damga")
    return isinstance(dm, dict) and bool(dm.get("sha256")) and bool(dm.get("tarih"))

# ── K17 hazırlık: hayalet-üye (durum:canli ∧ son-kontak >30g). Son-kontak = kayit'ın kanallar[] dosyalarının
#    en-son git-commit tarihi (mtime DEĞİL — checkout mtime'ı sıfırlar; git-commit-tarihi güvenilir). Test:
#    --kontak <yaml> {kayit: ISO-tarih} verilirse git-log yerine O kullanılır (deterministik, git-bağımsız). ──
GHOST_ESIK_GUN = 30
kontak_harita = {}
if kontak_yol and os.path.isfile(kontak_yol):
    try:
        kd = yaml.safe_load(oku(kontak_yol))
        if isinstance(kd, dict):
            kontak_harita = kd.get("kontak", kd) if isinstance(kd.get("kontak", kd), dict) else {}
    except Exception:
        kontak_harita = {}

def _git_son_kontak(kanallar):
    """kanallar[] dosyalarının en-son git-commit tarihi (date) ya da None (git-yok/geçmiş-yok)."""
    best = None
    for p in kanallar:
        try:
            out = subprocess.run(["git", "log", "-1", "--format=%ct", "--", p],
                                 capture_output=True, text=True, cwd=root, timeout=10)
            s = out.stdout.strip()
            if s.isdigit():
                dt = datetime.date.fromtimestamp(int(s))
                if best is None or dt > best: best = dt
        except Exception:
            pass
    return best

def _son_kontak(kayit):
    """kayit için son-kontak tarihi: önce --kontak haritası, yoksa git-log(kanallar). None=doğrulanamadı."""
    if kayit in kontak_harita:
        return _tarih(kontak_harita.get(kayit))
    kanlar = uye_kanallar.get(kayit) if isinstance(uye_kanallar, dict) else None
    if not kanlar:
        return None
    return _git_son_kontak(kanlar)

# ── rol-döngüsü: K1 · K5 · K8 · K9 · K13 · K16 · K17 · K22 ──
tum_worktree = {}   # worktree -> rol (K16)
tum_bolge = {}      # bolge -> rol (K16)

for i, r in enumerate(roller):
    ad = (r.get("ad") if isinstance(r, dict) else None) or f"<{i}. rol>"
    if not isinstance(r, dict):
        bulgular.append(f"{ad}: rol dict değil"); continue
    # K1 şema
    for alan in ("ad", "tek_cumle", "oturma_plani", "olcek"):
        if alan not in r or r.get(alan) in (None, ""):
            bulgular.append(f"{ad}: K1 zorunlu alan eksik: {alan}")
    op = r.get("oturma_plani")
    if isinstance(op, str) and op not in OTURMA:
        bulgular.append(f"{ad}: K1 oturma_plani enum-dışı: {op} (izin: {sorted(OTURMA)})")
    olcek = r.get("olcek") if isinstance(r.get("olcek"), dict) else {}
    ornekler = olcek.get("ornekler") if isinstance(olcek.get("ornekler"), list) else []

    # K5 mezarlık
    for ym in (r.get("yapamaz_makine") or []):
        if not isinstance(ym, dict):
            bulgular.append(f"{ad}: K5 yapamaz_makine öğesi dict değil"); continue
        if not ym.get("kural"):
            bulgular.append(f"{ad}: K5 yapamaz_makine 'kural' eksik")
        ok, neden = mezarlik_wired(ym.get("dayatan"), ym.get("rc"))
        if not ok:
            bulgular.append(f"{ad}: K5 {neden}")

    # K8/K9 (aile-registry okunabildiyse)
    if pane_kimlikler is not None and isinstance(op, str):
        if "pane" in op:
            for o in ornekler:
                kayit = o.get("kayit") if isinstance(o, dict) else None
                if not kayit:
                    bulgular.append(f"{ad}: K8 pane-rol ornek 'kayit' eksik")
                elif kayit not in pane_kimlikler:
                    bulgular.append(f"{ad}: K8 pane-ornek '{kayit}' aile-registry'de pane-üye DEĞİL")
        if "cagri" in op and ad in pane_kimlikler:
            bulgular.append(f"{ad}: K9 cagri-rol aile-registry'de pane-üye OLARAK var (körlük-vetosu ihlali)")

    # K13 adet == canli-ornek
    if ornekler:
        adet = olcek.get("adet")
        canli = sum(1 for o in ornekler if isinstance(o, dict) and o.get("durum") == "canli")
        if isinstance(adet, int) and adet != canli:
            bulgular.append(f"{ad}: K13 adet={adet} ≠ canlı-ornek={canli} (kanon⟂saha drifti)")

    # K16 benzersizlik toplama
    for o in ornekler:
        if not isinstance(o, dict): continue
        for alan, harita in (("worktree", tum_worktree), ("bolge", tum_bolge)):
            v = o.get(alan)
            if v is None: continue
            if v in harita:
                bulgular.append(f"K16 {alan} ÇİFT: '{v}' hem {harita[v]} hem {ad} (duplikasyon riski)")
            else:
                harita[v] = ad

    # K17 HAYALET-ÜYE: durum:canli örnek + son-kontak >30g → ⚠️ WARN (report-only, exit-etkisiz — BLOKLAMAZ).
    # NEDEN hard-red DEĞİL: son-kontak = kanallar[]'ın git-commit-tarihi = KUSURLU-PROXY, İKİ yönde de yanıltır:
    #   (a) false-red — sessiz-ama-canlı üye (kanalları o pencerede commit-almamış) ölü görünür → BLOKLAYAN kapıda
    #       tehlikeli (canlı çekirdeği durdurur; roster-parity'nin '2-hafta-sonra-flip hiç-olmadı' hastalığının aynası).
    #   (b) false-green — alakasız toplu-commit üyenin dosyasına dokununca ölü-üye taze görünür.
    # Kusurlu-proxy üstüne HARD-gate = tasarımın savaştığı sahte-dayatma → report-only WARN yüzeye çıkarır, iş durmaz.
    # Güvenilir heartbeat (registry son-kontak alanı / nabız-tablosu) gelince kırmızıya TERFİ eder (proxy-değil-ölçüm).
    # Son-kontak resolve edilemezse (kanal-yok ∨ git-geçmişi-yok) → doğrulanamadı → yine WARN (unknown≠fail).
    for o in ornekler:
        if not isinstance(o, dict) or o.get("durum") != "canli": continue
        kayit = o.get("kayit")
        if not kayit: continue   # K8 zaten kayit-eksikliğini yakalar
        sk = _son_kontak(kayit)
        if sk is None:
            uyarilar.append(f"{ad}: K17 '{kayit}' son-kontak doğrulanamadı (kanal/git-geçmişi yok) — ghost-say-MA (unknown≠fail)")
        else:
            yas = (bugun - sk).days
            if yas > GHOST_ESIK_GUN:
                uyarilar.append(f"{ad}: K17 HAYALET-ÜYE? '{kayit}' durum:canli ama son-kontak {yas}g önce (>{GHOST_ESIK_GUN}g; son={sk}; proxy=git-commit) — ölü-üye sinyali, elle-teyit (heartbeat gelince kırmızı)")

    # K22: her pane/cagri rolünün Sultan-onay damgası dolu (§2.6). K21 grace: flip-tarihinden ÖNCE
    # WARN (exit-etkisiz), sonra HARD-bulgu. Sultan `ekip-rol-sunum.sh uygula <rol> --onay <dosya>` ile doldurur.
    if isinstance(op, str) and ("pane" in op or "cagri" in op) and not _onay_dolu(ad):
        msg = f"{ad}: K22 Sultan-onay damgası YOK (ekip-rol-sunum.sh uygula {ad} --onay <dosya>)"
        if k22_hard:
            bulgular.append(msg)
        else:
            uyarilar.append(f"{msg} — GRACE (kapi={kapi}, flip={_sert.get(kapi) or 'yok'}); {bugun}<flip → henüz WARN")

# ── K23 ŞERİT-EŞLEMESİ (L25-W11 · Sultan-kararı K13) ──────────────────────────────────────────
# Taze doğan ekipler şerit alanını hiç almıyordu → bekçi de ötmüyordu. Üretici artık alanı basıyor;
# bu kural da onu denetler. Uygulama TEK yerde yaşar (scripts/serit-esleme-lint.py) — ekip-serit
# süiti de aynı kapıyı çağırır, iki kopya birbirinden drift edemez.
# GERİ-UYUMLULUK: alanı HİÇ taşımayan registry KAPSAM-DIŞIDIR (rc=3) → bulgu üretilmez, ama sessiz
# de geçilmez: uyarı satırı basılır (eski tenant'lar kırmızıya düşmeden görünür kalır).
# Bekçinin yolu ÇAĞIRANDAN gelir (SERIT_LINT) — `--root` fixture'a çevrilse bile bekçi kaybolmaz.
_serit_lint = os.environ.get("SERIT_LINT", "")
if os.path.isfile(_serit_lint) and os.path.isfile(aile):
    _p = subprocess.run([sys.executable, _serit_lint, aile], capture_output=True, text=True)
    _cikti = (_p.stdout + _p.stderr).strip()
    if _p.returncode == 1:
        for _ln in _cikti.splitlines():
            _ln = _ln.strip()
            if _ln.startswith("•"):
                bulgular.append("K23 ŞERİT: " + _ln.lstrip("• ").strip())
        if not any(b.startswith("K23 ŞERİT:") for b in bulgular):
            bulgular.append("K23 ŞERİT: rol⟂şerit eşlemesinde sapma var — " + _cikti.replace("\n", " | "))
    elif _p.returncode == 3:
        uyarilar.append("K23 ŞERİT: bu registry'de şerit alanı yok (eski şema) — kapsam-dışı, "
                        "yeni doğumlar ekip-modeli-gen.sh ile alanı alır")
    elif _p.returncode not in (0,):
        uyarilar.append(f"K23 ŞERİT: eşleme ÖLÇÜLEMEDİ (rc={_p.returncode}) — {_cikti or 'çıktı yok'}")
elif not os.path.isfile(_serit_lint):
    uyarilar.append("K23 ŞERİT: bekçi bulunamadı (scripts/serit-esleme-lint.py) — eşleme ölçülemedi")

for u in uyarilar:
    print(f"  ⚠️ {u}")

if bulgular:
    print(f"🔴 ekip-modeli-lint: {len(bulgular)} bulgu")
    for b in bulgular: print(f"  · {b}")
    sys.exit(1)

adlar = ", ".join(str(r.get("ad")) for r in roller if isinstance(r, dict))
son = f"🟢 ekip-modeli TEMİZ ({len(roller)} rol: {adlar})"
if uyarilar: son += f" · {len(uyarilar)} K22-GRACE uyarısı (flip öncesi report-only)"
print(son)
sys.exit(0)
PY
