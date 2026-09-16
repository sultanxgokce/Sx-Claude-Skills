#!/usr/bin/env bash
# iletisim-nabiz.sh — yönetici ⇄ üye iletişim hattının ÜÇ DURUMLU nabzı (salt-oku).
#
# Rol: ekip-iletisim-uzmani (global rol sınıfı). Bu araç ölçer, hüküm verir, ÖNERİR; emir VERMEZ,
# tetik GÖNDERMEZ, dosya DEĞİŞTİRMEZ. Ölçemediğini sağlığa yuvarlamaz: OLCEMEDIM görünür kalır.
#
# Kaynaklar (kutunun kendi dosyaları; hepsi isteğe bağlı, yoksa o eksen OLCEMEDIM):
#   _agents/handoff/ekip-registry.yaml   üyeler (id: satırları)
#   _agents/handoff/ekip-sinyal.log      tetik defteri  id|ts|tür|kimden|kime|durum|mesaj
#   _agents/durum/<AD>.json              üye durum dosyası (durum-raporu becerisi)
#
# Ölçülen sınıflar (NÂZIR isteği 2026-09-16 §"zorunlu davranış"):
#   1 kayip-tetik      durum ∈ {engellendi, oturum-yok, dogrulanamadi} (son PENCERE_SAAT)
#   2 acksiz-tetik     tür=ping, durum=iletildi ama ACK_DK içinde aynı kimeden ack/done yok
#   3 sessiz-uye       registry üyesi; PENCERE_SAAT boyunca ne sinyal göndermiş ne durum yazmış
#   4 bayat-is         durum dosyasında simdi.baslangic BAYAT_SAAT'ten eski ve dosya o zamandan beri değişmemiş
#   5 yonetim-darbogazi durum dosyalarında "bekliyor.kimden" aynı kişiye ≥ DARBOGAZ_ESIK kez
#
# Kullanım: iletisim-nabiz.sh [--repo <yol>] [--porcelain] [--pencere-saat N] [--ack-dk N]
# Çıkış: 0 temiz · 1 kırmızı bulgu var · 3 hiçbir eksen ölçülemedi
set -uo pipefail
export TZ=Europe/Istanbul
. "$(dirname "$0")/repo-bul.sh"
REPO="$(repo_bul)"; PORC=0
PENCERE_SAAT="${NABIZ_PENCERE_SAAT:-24}"; ACK_DK="${NABIZ_ACK_DK:-30}"
BAYAT_SAAT="${NABIZ_BAYAT_SAAT:-48}"; DARBOGAZ_ESIK="${NABIZ_DARBOGAZ_ESIK:-3}"
while [ $# -gt 0 ]; do case "$1" in
  --repo) REPO="$2"; shift 2;; --porcelain) PORC=1; shift;;
  --pencere-saat) PENCERE_SAAT="$2"; shift 2;; --ack-dk) ACK_DK="$2"; shift 2;;
  *) shift;; esac; done
SIMDI="${NABIZ_SIMDI:-$(date +%s)}"   # sınav için sabitlenebilir zaman

REPO="$REPO" SIMDI="$SIMDI" PORC="$PORC" PENCERE_SAAT="$PENCERE_SAAT" ACK_DK="$ACK_DK" \
BAYAT_SAAT="$BAYAT_SAAT" DARBOGAZ_ESIK="$DARBOGAZ_ESIK" python3 - <<'PY'
import os, json, re, sys, datetime
repo=os.environ["REPO"]; simdi=int(os.environ["SIMDI"]); porc=os.environ["PORC"]=="1"
PENCERE=int(os.environ["PENCERE_SAAT"])*3600; ACK=int(os.environ["ACK_DK"])*60
BAYAT=int(os.environ["BAYAT_SAAT"])*3600; DARB=int(os.environ["DARBOGAZ_ESIK"])
def ts2epoch(s):
    try:
        s=s.strip()
        if s.endswith('Z'): s=s[:-1]+'+00:00'
        return int(datetime.datetime.fromisoformat(s).timestamp())
    except Exception: return None

sonuc={"olculen":[], "olculemeyen":[], "bulgular":[]}
def bulgu(sinif, kim, kanit, oneri): sonuc["bulgular"].append({"sinif":sinif,"kim":kim,"kanit":kanit,"oneri":oneri})

# — üyeler —
uyeler=[]
reg=os.path.join(repo,"_agents","handoff","ekip-registry.yaml")
if os.path.isfile(reg):
    for l in open(reg,encoding="utf-8",errors="ignore"):
        m=re.match(r"^\s*-?\s*id:\s*([A-Za-z0-9_-]+)", l)
        if m: uyeler.append(m.group(1))
else: sonuc["olculemeyen"].append("uyeler(registry yok)")

# — sinyal defteri —
sinyal=[]
log=os.path.join(repo,"_agents","handoff","ekip-sinyal.log")
if os.path.isfile(log):
    for l in open(log,encoding="utf-8",errors="ignore"):
        p=l.rstrip("\n").split("|")
        if len(p)<6: continue
        t=ts2epoch(p[1])
        if t is None: continue
        sinyal.append({"id":p[0],"t":t,"tur":p[2],"kimden":p[3],"kime":p[4],"durum":p[5]})
    pencere=[s for s in sinyal if simdi-s["t"]<=PENCERE]
    # 1 kayıp tetik
    kayip=[s for s in pencere if s["durum"] in ("engellendi","oturum-yok","dogrulanamadi")]
    if kayip:
        by={}
        for s in kayip: by.setdefault(s["kime"],[]).append(s)
        for kime,l in sorted(by.items(), key=lambda x:-len(x[1])):
            durumlar=sorted(set(s["durum"] for s in l))
            bulgu("kayip-tetik", kime, f"{len(l)} tetik {'/'.join(durumlar)} (son {PENCERE//3600} sa)",
                  "tetik yolu kırık: ekip-registry tmux adı ve ekip-notify kapısı kontrol; ham send-keys kancaya takılıyor olabilir")
    sonuc["olculen"].append("kayip-tetik")
    # 2 ACK'siz tetik
    ping=[s for s in pencere if s["tur"]=="ping" and s["durum"]=="iletildi"]
    acks=[s for s in sinyal if s["tur"] in ("ack","done")]
    acksiz=[]
    for s in ping:
        if simdi - s["t"] < ACK: continue   # henüz süre dolmadı
        if not any(a["kimden"]==s["kime"] and a["t"]>=s["t"] for a in acks): acksiz.append(s)
    if acksiz:
        by={}
        for s in acksiz: by.setdefault(s["kime"],0); by[s["kime"]]+=1
        for kime,n in sorted(by.items(), key=lambda x:-x[1]):
            bulgu("acksiz-tetik", kime, f"{n} tetik iletildi, {ACK//60} dk içinde ack/done yok", "üye pencerede mi? canlılık + iki-fazlı Enter tuzağı kontrol")
    sonuc["olculen"].append("acksiz-tetik")
else:
    sonuc["olculemeyen"].extend(["kayip-tetik(sinyal defteri yok)","acksiz-tetik(sinyal defteri yok)"])

# — durum dosyaları —
durum_dir=os.path.join(repo,"_agents","durum")
durumlar={}
if os.path.isdir(durum_dir):
    for f in os.listdir(durum_dir):
        if not f.endswith(".json"): continue
        yol=os.path.join(durum_dir,f)
        try: d=json.load(open(yol,encoding="utf-8"))
        except Exception: continue
        d["_mtime"]=int(os.path.getmtime(yol)); durumlar[f[:-5]]=d
    # 4 bayat iş
    for ad,d in durumlar.items():
        b=(d.get("simdi") or {}).get("baslangic")
        t=ts2epoch(b) if isinstance(b,str) else None
        if t and simdi-t>BAYAT and simdi-d["_mtime"]>BAYAT:
            bulgu("bayat-is", ad, f"'{(d.get('simdi') or {}).get('is','?')}' {int((simdi-t)/3600)} saattir 'şimdi'de, dosya o zamandan beri değişmemiş",
                  "üyeye sor: iş takılı mı, bitti de yazılmadı mı; ilerleme yoksa bölünsün")
    sonuc["olculen"].append("bayat-is")
    # 5 yönetim darboğazı
    say={}
    for ad,d in durumlar.items():
        for b in d.get("bekliyor") or []:
            k=b.get("kimden")
            if k: say[k]=say.get(k,0)+1
    for k,n in say.items():
        if n>=DARB: bulgu("yonetim-darbogazi", k, f"{n} üye ondan cevap bekliyor", "yönetici kuyruğu; kararlar toplu alınsın ya da yetki devredilsin")
    sonuc["olculen"].append("yonetim-darbogazi")
else:
    sonuc["olculemeyen"].extend(["bayat-is(durum dizini yok)","yonetim-darbogazi(durum dizini yok)"])

# 3 sessiz üye (registry + sinyal ∪ durum)
if uyeler and (os.path.isfile(log) or os.path.isdir(durum_dir)):
    for u in uyeler:
        son_sinyal=max([s["t"] for s in sinyal if s["kimden"]==u], default=None)
        son_durum=durumlar.get(u,{}).get("_mtime")
        son=max([x for x in (son_sinyal,son_durum) if x], default=None)
        if son is None or simdi-son>PENCERE:
            bulgu("sessiz-uye", u, "son %s sa içinde ne sinyal ne durum yazmış" % (PENCERE//3600) if son is None else f"son iz {int((simdi-son)/3600)} sa önce",
                  "pencere açık mı? açıksa iş yok mu, kapalıysa personeli yeniden canlandır")
    sonuc["olculen"].append("sessiz-uye")
elif not uyeler: sonuc["olculemeyen"].append("sessiz-uye(registry yok)")

if porc:
    print(json.dumps(sonuc, ensure_ascii=False));
else:
    kutu=os.path.basename(repo)
    print(f"İLETİŞİM NABZI · {kutu} · {datetime.datetime.fromtimestamp(simdi).strftime('%Y-%m-%d %H:%M')}")
    print(f"ölçülen: {', '.join(sonuc['olculen']) or '—'}")
    if sonuc["olculemeyen"]: print(f"ÖLÇÜLEMEDİ: {', '.join(sonuc['olculemeyen'])}")
    if not sonuc["bulgular"]: print("bulgu yok (ölçülen eksenlerde)")
    for b in sonuc["bulgular"]:
        print(f"🔴 {b['sinif']} · {b['kim']} · {b['kanit']}\n   → {b['oneri']}")
if not sonuc["olculen"]: sys.exit(3)
sys.exit(1 if sonuc["bulgular"] else 0)
PY
