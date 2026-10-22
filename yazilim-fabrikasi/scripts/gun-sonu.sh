#!/usr/bin/env bash
# gun-sonu.sh — gün sonu özeti DEFTERDEN üretilir, elle yazılmaz (K6-b/c, Sultan 22 Eyl 2026).
#
# Kaynaklar: <depo>/_agents/fabrika/kartlar/*.json (iş kartları) + <depo>/_agents/fabrika/karne.jsonl (denetimler).
# Üç bölüm: SULTAN'A GİDENLER (sınıf işi) · İÇERİDE BİTİRDİKLERİMİZ (Sultan'ın veto hakkı) · TIKANANLAR; ek: açık işler.
# Her satır bir karta bağlıdır; kartta olmayan şey özete giremez.
#
# Kullanım: gun-sonu.sh [--gun YYYY-MM-DD] [--yaz] [--kutu <ad>] [--kapanis]
#   --yaz: <depo>/_agents/fabrika/gun-sonu/<gün>.md dosyasına da yazar · --kutu: görev defteri bölümünü o kutunun işleriyle sınırlar
#   --kapanis: GÜN KAPANIŞI yalnız GÖREV DEFTERİNE göre (Z23WS 2: kart bitti ≠ görev bitti) — çalışılıyor iş varsa rc 1 "gün kapanmaz",
#              defter ölçülemezse rc 3 (yeşil değil); bayraksız koşuda özet üretilir, rc değişmez (cron bozulmaz).
# GÖREV DEFTERİ bölümü (Z23WS 3, kart gun-sonu-gorev-defteri): DEFTER_UC (vars. http://cloudtop-defter:8791) + DEFTER_JETON_YOL
#   (vars. /config/defter-jeton) ile okunur; jeton yoksa / defter cevap vermezse "ölçülemedi" yazılır, 0 DENMEZ. Jeton değeri basılmaz.
# rc: 0 üretildi · 1 (--kapanis) çalışılıyor iş var · 3 defter yok / görev defteri ölçülemedi (--kapanis)
set -uo pipefail
GUN="$(date +%F)"; YAZ=0; KUTU=""; KAPANIS=0
while [ $# -gt 0 ]; do case "$1" in --gun) GUN="$2"; shift 2 ;; --yaz) YAZ=1; shift ;; --kutu) KUTU="$2"; shift 2 ;; --kapanis) KAPANIS=1; shift ;; *) shift ;; esac; done
c="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" && DEPO="${KANIT_DEPO:-$(dirname "$c")}" || DEPO="${KANIT_DEPO:-}"
[ -n "$DEPO" ] || { echo "✗ depo kökü bulunamadı" >&2; exit 3; }
KD="$DEPO/_agents/fabrika/kartlar"; KARNE="$DEPO/_agents/fabrika/karne.jsonl"
ls "$KD"/*.json >/dev/null 2>&1 || { echo "◻ kart defteri yok ($KD) — özet üretilemez (ölçülemedi)"; exit 3; }
OZET="$(python3 - "$KD" "$KARNE" "$GUN" <<'PY'
import json,sys,glob,os
kd,karne,gun=sys.argv[1:]
kartlar=[json.load(open(p)) for p in sorted(glob.glob(os.path.join(kd,"*.json")))]
den={}
if os.path.exists(karne):
    for l in open(karne,encoding="utf-8"):
        if l.strip():
            r=json.loads(l)
            if r.get("olay")=="denetim": den[r["is"]]=r
def bugun(k):  # o gün açılmış YA DA o gün kapanmış
    return k["zaman"][:10]==gun or (k.get("bitis","")[:10]==gun)
g=[k for k in kartlar if bugun(k)]
sultan=[k for k in g if k["sultan"]]
icerde=[k for k in g if not k["sultan"] and k["durum"]=="bitti"]
tik=[k for k in g if k["durum"]=="tikandi"]
acik=[k for k in kartlar if k["durum"]=="acik"]
def puan(k):
    p=k.get("puan"); d=den.get(k["is"])
    if p: return f"{p['kod']}/5 {p['dogru']} · {p['tur']} tur"
    if d: return f"{d['puan']}/5 {d['dogru']} · {d['tur']} tur"
    return "puan YOK"
out=[f"# GÜN SONU · {gun} · {len(g)} iş (kart defterinden üretildi, elle satır yok)",""]
out.append(f"## Sultan'a gidenler ({len(sultan)})")
for k in sultan: out.append(f"- [{k['durum']}] **{k['is']}** — {k['cumle']} · sınıf: {', '.join(k['siniflar'])} · sahip {k['aldi']} · {puan(k)} · kanıt {'var' if k.get('kanit_var') else 'yok'}{' · PR '+k['pr'] if k.get('pr') else ''}")
out.append(""); out.append(f"## İçeride bitirdiklerimiz ({len(icerde)}) — 'bunu bana sormalıydınız' dersen sınıf kuralı bu vakayla düzelir")
for k in icerde: out.append(f"- **{k['is']}** — {k['cumle']} · sahip {k['aldi']} · {puan(k)} · kanıt {'var' if k.get('kanit_var') else '⚠ YOK'}{' · PR '+k['pr'] if k.get('pr') else ''}")
out.append(""); out.append(f"## Tıkananlar ({len(tik)})")
for k in tik: out.append(f"- **{k['is']}** — {k['cumle']} · yol: {k['tikanma']['yol']} · neden: {k['tikanma']['neden']} · sahip {k['aldi']}")
# 🔴 Kaçışlar Sultan'ın önüne gelir (23 Eyl kararı): sessiz delik olmaktan çıkar, kayda geçen istisna olur.
import os as _os

# 🔴 DAMGA DÜNYA SAATİ, SÜZGEÇ YEREL SAAT — her gün 3 saatlik KÖR PENCERE (ölçüldü 8 Eki 2026).
#   Defterler `...Z` ile damgalanıyor (dünya saati), süzgeç ise `date +%F` (yerel) kullanıyordu
#   ve karşılaştırma ham metin üzerindeydi: `satir[:10] == gun`. Yerel saat dünya saatinin
#   3 saat önünde olduğu için, yerel 00:00-03:00 arasında olan her olay BİR ÖNCEKİ günün
#   damgasını taşıyor; o günün özeti çoktan koşmuş oluyor, ertesi günün özeti de onu
#   kendi tarihiyle eşleştiremiyor. Olay iki özetin ARASINA düşüyor.
#   CANLI KANIT: 7 Ekim yerel 00:55 ve 01:11'deki İKİ kapı kaçışı defterde 2026-10-06
#   damgalı; 7 Ekim özetinde hiç görünmedi. İkisi de Sultan'ın VETO hakkı olan bölümler —
#   yani körlük tam da en çok görünmesi gereken yerdeydi.
#   ÇÖZÜM: metin karşılaştırmayı bırak, damgayı YEREL güne çevir. Damgasız ya da
#   çözülemeyen satır SESSİZCE DÜŞMEZ — ayrı sayılır ve söylenir (unknown ≠ yok).
def _yerel_gun(satir):
    """Satırın baştaki zaman damgasını YEREL güne çevirir. Çözemezse None (düşürmez, sayar)."""
    import datetime as _dt, re as _re
    m = _re.match(r"(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}:\d{2})(Z|[+-]\d{2}:?\d{2})?", satir)
    if not m:
        return None
    tarih, saat, dilim = m.groups()
    # 🔴 TÜM çözümleme tek try içinde (bağımsız göz tur 1): eskiden yalnız `fromisoformat`
    #    korunuyordu; aralık dışı bir ofset (ör. +99:00) `timezone()` kurulurken patlıyor ve
    #    ÖZETİN TAMAMINI durduruyordu. Bir satırın bozukluğu, günün raporunu öldüremez.
    try:
        t = _dt.datetime.fromisoformat(f"{tarih}T{saat}")
        if dilim is None:
            return tarih                  # dilimsiz damga zaten yereldir, dokunma
        if dilim == "Z":
            t = t.replace(tzinfo=_dt.timezone.utc)
        else:
            d = dilim.replace(":", "")
            ofs = _dt.timedelta(hours=int(d[1:3]), minutes=int(d[3:5]))
            t = t.replace(tzinfo=_dt.timezone(-ofs if d[0] == "-" else ofs))
        return t.astimezone().strftime("%Y-%m-%d")
    except (ValueError, OverflowError):
        return None                       # çözülemedi → sessizce DÜŞMEZ, sayılır


def _yerel_saat(damga):
    """Ekrana basılan saat de YEREL olmalı — aksi hâlde Sultan 00:55'teki kaçışı 21:55 görür."""
    import datetime as _dt, re as _re
    m = _re.match(r"(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}:\d{2})(Z|[+-]\d{2}:?\d{2})?", damga)
    if not m:
        return damga[11:16] or "?"
    if _yerel_gun(damga) is None:
        return m.group(2)[:5]             # çözülemedi: ham saati bas, uydurma yapma
    tarih, saat, dilim = m.groups()
    # 🔴 AÇIK DİLİM de çevrilir (bağımsız göz tur 1): eskiden yalnız `Z` dalı astimezone
    #    çağırıyordu; `+00:00` taşıyan bir damga dünya saatini YEREL diye basıyordu.
    #    Sınav da bunu örtmüştü — yalnız kendi dilimimizi (+03:00) deniyordu, o da zaten
    #    yerelle aynı olduğu için fark görünmüyordu. Fikstür kendi diliminden SEÇİLMEZ.
    try:
        t = _dt.datetime.fromisoformat(f"{tarih}T{saat}")
        if dilim == "Z":
            t = t.replace(tzinfo=_dt.timezone.utc)
        elif dilim:
            d = dilim.replace(":", "")
            ofs = _dt.timedelta(hours=int(d[1:3]), minutes=int(d[3:5]))
            t = t.replace(tzinfo=_dt.timezone(-ofs if d[0] == "-" else ofs))
        if dilim:
            t = t.astimezone()
    except (ValueError, OverflowError):
        return saat[:5]
    return t.strftime("%H:%M")


def _gunun_satirlari(satirlar, gun):
    """(bugünküler, çözülemeyenler) — çözülemeyen satır YOK sayılmaz, ayrıca raporlanır."""
    bugun, cozulemedi = [], []
    for l in satirlar:
        g = _yerel_gun(l)
        if g is None:
            cozulemedi.append(l)
        elif g == gun:
            bugun.append(l)
    return bugun, cozulemedi

kac=_os.path.join(_os.path.dirname(kd),"kacis-defteri.log")  # kd=<depo>/_agents/fabrika/kartlar
sat=[l.strip() for l in open(kac,encoding="utf-8")] if _os.path.exists(kac) else []
bugun_kac, kac_cozulemedi = _gunun_satirlari(sat, gun)
out.append(""); out.append(f"## Kapı kaçışları ({len(bugun_kac)}) — her biri bir istisnadır, veto hakkın var")
for l in bugun_kac:
    par=[x.strip() for x in l.split("|")]
    out.append(f"- {_yerel_saat(par[0])} · gerekçe: {par[2] if len(par)>2 else '?'} · komut: `{(par[3] if len(par)>3 else '?')[:70]}`")
if not bugun_kac: out.append("- (bugün kapı atlanmadı)")
if kac_cozulemedi: out.append(f"- ⚠ {len(kac_cozulemedi)} satırın tarihi ÇÖZÜLEMEDİ — "
                              "\"yok\" sayılmadı, sayıldı ve söyleniyor")
# 🔴 Tavan açılışları da Sultan'ın önüne gelir (23 Eyl): dönüş tavanı bir kuraldır, onu aşmak
#    bir istisnadır ve istisna görünmezse kural erir. Kaçış defteriyle aynı muamele.
tav=_os.path.join(_os.path.dirname(kd),"tavan-defteri.log")
tsat=[l.strip() for l in open(tav,encoding="utf-8")] if _os.path.exists(tav) else []
bugun_tav, tav_cozulemedi = _gunun_satirlari(tsat, gun)
out.append(""); out.append(f"## Tavan açılışları ({len(bugun_tav)}) — dönüş tavanı bir kararla aşıldı (Sultan ya da sınıfsız işte reis)")
for l in bugun_tav:
    par=[x.strip() for x in l.split("|")]
    kim = "reis kararı (sınıfsız iş)" if len(par)>1 and par[1]=="TAVAN-ACILDI-REIS" else "Sultan kararı"
    out.append(f"- {_yerel_saat(par[0])} · {par[2] if len(par)>2 else '?'} · {kim} · gerekçe: {par[3] if len(par)>3 else '?'}")
if not bugun_tav: out.append("- (bugün tavan açılmadı)")
if tav_cozulemedi: out.append(f"- ⚠ {len(tav_cozulemedi)} satırın tarihi ÇÖZÜLEMEDİ — \"yok\" sayılmadı, sayıldı ve söyleniyor")
out.append(""); out.append(f"## Açık işler ({len(acik)})")
for k in acik: out.append(f"- {k['is']} — sahip {k['aldi']} · açıldı {k['zaman'][:16]}{' · SULTAN' if k['sultan'] else ''}")
print("\n".join(out))
PY
)" || exit 3
# ── GÖREV DEFTERİ (Z23WS): kart defteri "ne inşa ettik" der, görev defteri "Sultan'ın işi bitti mi" der; gün ikincisine göre kapanır ──
GD="$(python3 - "$KUTU" <<'PY'
import json, os, sys, urllib.request, urllib.error, datetime
kutu = sys.argv[1]
UC = os.environ.get("DEFTER_UC") or "http://cloudtop-defter:8791"; JY = os.environ.get("DEFTER_JETON_YOL") or "/config/defter-jeton"
def son(x, n=70): x = str(x or ""); return x if len(x) <= n else x[:n-1] + "…"
def saat(ts):
    try: return datetime.datetime.fromisoformat(str(ts).replace("Z", "+00:00")).astimezone().strftime("%d %b %H:%M")
    except Exception: return "?"
def olculemedi(neden):
    print(f"## Görev defteri — gün kapanışı buna göre (kart bitti ≠ görev bitti)"); print(f"- ⚠ ÖLÇÜLEMEDİ: {neden} — çalışılıyor sayısı 0 DEĞİL, bilinmiyor; gün bu veriyle KAPANMAZ")
    print("#kapanis: olculemedi=1 calisiliyor=-1"); sys.exit(0)
try: jeton = open(JY, encoding="utf-8").read().strip()
except OSError: olculemedi("defter jetonu yok (" + JY + ")")
try:
    with urllib.request.urlopen(urllib.request.Request(UC + "/gorevler", headers={"x-defter-jeton": jeton}), timeout=8) as r: g = json.loads(r.read().decode("utf-8") or "null")
except urllib.error.HTTPError as e: olculemedi(f"defter cevap vermedi (HTTP {e.code})")
except (OSError, ValueError) as e: olculemedi("defterе ulaşılamadı (" + type(e).__name__ + ")")
liste = g.get("gorevler") if isinstance(g, dict) else None
if not isinstance(liste, list): olculemedi("defter cevabı biçimsiz")
kova = {"calisiliyor": [], "acik": [], "sira-bende": [], "onay-bekliyor": []}
for k in liste:
    c = k.get("canli") if isinstance(k, dict) else None
    if not isinstance(c, dict): continue
    if kutu and str(c.get("kutu") or k.get("ekleyen_kutu") or "") != kutu: continue
    d = c.get("gorev_durumu")
    if d == "calisiliyor" or d == "onay-bekliyor" or (d in ("acik", "sira-bende") and c.get("atanan")): kova[d].append(k)
ad = lambda k: (k.get("adlar") or [{}])[0]; ad = lambda k, _ad=ad: (_ad(k).get("deger") if isinstance(_ad(k), dict) else _ad(k)) or ""
print(f"## Görev defteri — gün kapanışı buna göre (kart bitti ≠ görev bitti){' · kutu ' + kutu if kutu else ' · bütün kutular'}")
print(f"- çalışılıyor **{len(kova['calisiliyor'])}** · atanmış açık {len(kova['acik'])} · sıra Sultan'da {len(kova['sira-bende'])} · onay bekleyen {len(kova['onay-bekliyor'])}")
for k in sorted(kova["calisiliyor"], key=lambda x: str(x.get("son_adim") or "")):
    c = k["canli"]; print(f"  - {k.get('id','')[-5:]} · {c.get('atanan') or 'atanmamış'} · {son(ad(k))} · son adım {saat(k.get('son_adim'))}")
if kova["calisiliyor"]: print("- → bu işler bitmeden gün KAPANMAZ: ajan 'bitti' demez, görev defteri der (dilim ≠ görev)")
else: print("- → defterde çalışılan iş yok: gün görev defterine göre kapanabilir")
print(f"#kapanis: olculemedi=0 calisiliyor={len(kova['calisiliyor'])}")
PY
)"
KAP="$(printf '%s\n' "$GD" | sed -n 's/^#kapanis: //p' | tail -1)"; GD="$(printf '%s\n' "$GD" | grep -v '^#kapanis: ')"
OZET="$OZET"$'\n'"$GD"
printf '%s\n' "$OZET"
if [ "$KAPANIS" -eq 1 ]; then
  case "$KAP" in
    *olculemedi=1*) echo "→ KAPANIŞ ÖLÇÜLEMEDİ: görev defteri okunamadı — gün kapandı DENEMEZ (rc 3)"; RC_KAP=3 ;;
    "olculemedi=0 calisiliyor=0") echo "→ GÜN KAPANABİLİR: görev defterinde çalışılan iş yok (rc 0)"; RC_KAP=0 ;;
    *) echo "→ GÜN KAPANMAZ: görev defterinde ${KAP##*calisiliyor=} iş çalışılıyor (rc 1) — kart/PR bitmiş olsa da görev bitmedi"; RC_KAP=1 ;;
  esac
fi
if [ "$YAZ" -eq 1 ]; then mkdir -p "$DEPO/_agents/fabrika/gun-sonu"; printf '%s\n' "$OZET" > "$DEPO/_agents/fabrika/gun-sonu/$GUN.md"; echo "→ yazıldı: _agents/fabrika/gun-sonu/$GUN.md"; fi
exit "${RC_KAP:-0}"
