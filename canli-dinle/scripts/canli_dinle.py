#!/usr/bin/env python3
"""canli-dinle: yayın adresi -> 30 sn parça -> Türkçe yazı -> 10 dk özet. Anahtar yalnız süreç içinde okunur, hiçbir yere yazılmaz."""
import argparse, json, os, shlex, shutil, subprocess, sys, time, uuid, urllib.request, urllib.error

GROQ = os.environ.get("CANLI_DINLE_GROQ_URL", "https://api.groq.com/openai/v1")
UA = "canli-dinle/0.1 (curl-compatible)"  # Groq önündeki Cloudflare varsayılan Python-urllib kimliğini 403 ile reddeder
STT_MODEL = "whisper-large-v3-turbo"
OZET_MODEL = os.environ.get("CANLI_DINLE_OZET_MODELI", "openai/gpt-oss-120b")


def arac_sec(path=None):
    """Yakalama aracı: streamlink > yt-dlp > ffmpeg doğrudan."""
    zorla = os.environ.get("CANLI_DINLE_ARAC")
    if zorla:
        return zorla
    for ad in ("streamlink", "yt-dlp"):
        if shutil.which(ad, path=path):
            return ad
    return "ffmpeg"


def yakala_komutu(arac, adres, parca_sn, cikti, sure):
    t = f"-t {int(sure)}" if sure else ""
    seg = (f"ffmpeg -nostdin -loglevel error {t} -i {{girdi}} -vn -ar 16000 -ac 1 -c:a pcm_s16le "
           f"-f segment -segment_time {parca_sn} -reset_timestamps 1 {shlex.quote(cikti + '/parca-%05d.wav')}")
    a = shlex.quote(adres)
    if arac == "streamlink":
        return f"streamlink --stdout --loglevel error {a} best | " + seg.format(girdi="-")
    if arac == "yt-dlp":
        return f"yt-dlp -q -o - -f 'bestaudio/best' {a} | " + seg.format(girdi="-")
    return seg.format(girdi=a)


def anahtar():
    k = os.environ.get("GROQ_API_KEY")
    if k:
        return k
    yol = os.environ.get("CANLI_DINLE_ANAHTAR_DOSYASI", os.path.expanduser("~/.config/cortex-access.env"))
    try:
        for s in open(yol):
            if s.startswith("GROQ_API_KEY="):
                return s.split("=", 1)[1].strip().strip("'\"")
    except OSError:
        pass
    return None


def wav_sure(yol):
    import wave
    with wave.open(yol) as w:
        return w.getnframes() / w.getframerate()


def _multipart(alanlar, dosya_alani, dosya_yolu):
    sinir = uuid.uuid4().hex
    g = []
    for k, vs in alanlar:
        g.append(f'--{sinir}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{vs}\r\n'.encode())
    g.append((f'--{sinir}\r\nContent-Disposition: form-data; name="{dosya_alani}"; filename="p.wav"\r\n'
              'Content-Type: audio/wav\r\n\r\n').encode() + open(dosya_yolu, "rb").read() + b"\r\n")
    g.append(f"--{sinir}--\r\n".encode())
    return b"".join(g), f"multipart/form-data; boundary={sinir}"


def groq_yaz(wav, anh, ofset):
    """[(baslangic_sn_mutlak, metin)] — kelime düzeyinde zaman damgası."""
    veri, ct = _multipart([("model", STT_MODEL), ("language", "tr"), ("response_format", "verbose_json"),
                           ("timestamp_granularities[]", "word")], "file", wav)
    for deneme in range(4):
        r = urllib.request.Request(GROQ + "/audio/transcriptions", data=veri,
                                   headers={"Authorization": "Bearer " + anh, "Content-Type": ct, "User-Agent": UA})
        try:
            j = json.load(urllib.request.urlopen(r, timeout=60))
            return [(ofset + w["start"], w["word"]) for w in j.get("words", [])]
        except urllib.error.HTTPError as e:
            if (e.code == 429 or e.code >= 500) and deneme < 3:
                time.sleep(2 * (deneme + 1))
                continue
            raise
        except (urllib.error.URLError, TimeoutError, ConnectionError):
            if deneme < 3:
                time.sleep(2 * (deneme + 1))
                continue
            raise
    return []


def yerel_yaz(wav, ofset):
    """whisper.cpp small-q5: segment düzeyinde zaman damgası."""
    cli = os.environ.get("WHISPER_CLI", "whisper-cli")
    model = os.environ.get("WHISPER_MODEL", os.path.expanduser("~/.cache/canli-dinle/model-small-q5.bin"))
    onek = wav + ".w"
    env = dict(os.environ)
    if os.path.dirname(cli):
        env["LD_LIBRARY_PATH"] = os.path.dirname(cli)
    subprocess.run([cli, "-m", model, "-l", "tr", "-t", "6", "-oj", "-of", onek, "-f", wav],
                   check=True, capture_output=True, env=env)
    j = json.load(open(onek + ".json"))
    return [(t, k) for s in j.get("transcription", []) for t, k in segment_kelimeleri(s, ofset)]


def segment_kelimeleri(s, ofset):
    """Segmenti kelimelere böler; zamanı segmentin [from,to] aralığına eşit paylaştırır (yerelde kelime zamanı yok).
    Sınırı aşan segmentin her kelimesi kendi zamanıyla sahiplenilir: ne kaybolur ne ikilenir."""
    k = s["text"].split()
    if not k:
        return []
    b, e = s["offsets"]["from"] / 1000.0, s["offsets"]["to"] / 1000.0
    adim = (e - b) / len(k) if e > b else 0.0
    return [(ofset + b + n * adim, w) for n, w in enumerate(k)]


def sahip_penceresi(i, parca_sn, ortu_sn, son):
    """Parça i'nin sahip olduğu mutlak zaman aralığı: komşu parçaların örtüşme ortasından bölünür."""
    bas = 0.0 if i == 0 else i * parca_sn - ortu_sn / 2.0
    bit = float("inf") if son else (i + 1) * parca_sn - ortu_sn / 2.0
    return bas, bit


def kirp(sozcukler, i, parca_sn, ortu_sn, son):
    bas, bit = sahip_penceresi(i, parca_sn, ortu_sn, son)
    return [(t, w) for t, w in sozcukler if bas <= t < bit]


def ozetle(metin, anh):
    govde = json.dumps({"model": OZET_MODEL, "messages": [
        {"role": "system", "content": "Türkçe canlı yayın dökümünü 5-8 madde ile özetle. Yalnız metinde geçenleri yaz."},
        {"role": "user", "content": metin}]}).encode()
    r = urllib.request.Request(GROQ + "/chat/completions", data=govde,
                               headers={"Authorization": "Bearer " + anh, "Content-Type": "application/json", "User-Agent": UA})
    return json.load(urllib.request.urlopen(r, timeout=90))["choices"][0]["message"]["content"].strip()


def olay(dizin, mesaj):
    """Saat damgalı olay günlüğü (canlı koşu kanıtı): <çıktı>/olay.log; anahtar ve metin yazılmaz."""
    satir = time.strftime("%Y-%m-%dT%H:%M:%S%z") + " " + mesaj
    print(satir, file=sys.stderr)
    with open(os.path.join(dizin, "olay.log"), "a") as f:
        f.write(satir + "\n")


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("adres")
    ap.add_argument("--kaynak", choices=["groq", "yerel"], default="groq")
    ap.add_argument("--ozetsiz", dest="ozetsiz", action="store_true", help="10 dk pencere özetini kapat (varsayılan: açık)")
    ap.add_argument("--sure", type=int, default=0, help="en çok bu kadar sn dinle (0 = yayın bitene dek)")
    ap.add_argument("--parca-sn", type=int, default=30)
    ap.add_argument("--ortu-sn", type=int, default=5)
    ap.add_argument("--pencere-sn", type=int, default=600)
    ap.add_argument("--cikti", default=os.environ.get("CANLI_DINLE_CIKTI", "canli-dinle-cikti"))
    ap.add_argument("--kuru", action="store_true", help="yalnız seçilen aracı ve komutu yaz")
    a = ap.parse_args(argv)

    arac = arac_sec()
    dizin = os.path.join(a.cikti, time.strftime("%Y%m%d-%H%M%S"))
    os.makedirs(dizin, exist_ok=True)
    kom = yakala_komutu(arac, a.adres, a.parca_sn, dizin, a.sure)
    if a.kuru:
        print("arac=" + arac)
        print(kom)
        return 0
    a.notu = not a.ozetsiz
    anh = anahtar()
    if a.kaynak == "groq" and not anh:
        print("✗ GROQ_API_KEY bulunamadı (süreç ortamı ya da ~/.config/cortex-access.env); --kaynak yerel ile anahtarsız çalışır", file=sys.stderr)
        return 3
    if a.notu and not anh:
        print("! GROQ_API_KEY yok: özet kapatıldı, yalnız döküm alınacak", file=sys.stderr)
        a.notu = False
    print(f"yakalama: {arac} · çıktı: {dizin}", file=sys.stderr)
    hata_dosyasi = open(os.path.join(dizin, "yakala.err"), "w")
    yakala = subprocess.Popen(["bash", "-c", kom], stderr=hata_dosyasi, text=True)
    atlanan = 0
    metin_f = open(os.path.join(dizin, "metin.txt"), "a", buffering=1)
    sozluk, i, penc_bas, ozet_no = [], 0, 0, 0

    def parca(n): return os.path.join(dizin, f"parca-{n:05d}.wav")

    def hazir(n):
        # n tamamlandı sayılır: n+1 doğdu ya da yakalama bitti
        return os.path.exists(parca(n)) and (os.path.exists(parca(n + 1)) or yakala.poll() is not None)

    def ozet_yaz(sozler, no):
        if not (a.notu and sozler):
            return
        try:
            z = ozetle(" ".join(w for _, w in sozler), anh)
        except (urllib.error.URLError, KeyError, IndexError) as e:
            print(f"! özet {no} alınamadı ({e}); döküm sürüyor", file=sys.stderr)
            return
        open(os.path.join(dizin, f"ozet-{no:03d}.md"), "w").write(z + "\n")
        open(os.path.join(dizin, "ozet.md"), "a").write(f"## Pencere {no}\n{z}\n\n")

    while True:
        if not hazir(i):
            if yakala.poll() is not None and not os.path.exists(parca(i)):
                break
            time.sleep(0.3)
            continue
        son = yakala.poll() is not None and not os.path.exists(parca(i + 1))
        onceki = parca(i - 1) if i else None
        w = parca(i)
        if i and os.path.exists(onceki):  # örtüşme: önceki parçanın son ortu_sn saniyesi
            birlesik = w + ".ortulu.wav"
            r = subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-sseof", f"-{a.ortu_sn}", "-i", onceki, "-i", w,
                                "-filter_complex", "[0:a][1:a]concat=n=2:v=0:a=1", "-ar", "16000", "-ac", "1", birlesik])
            if r.returncode != 0:
                birlesik = w + ".yok"
            girdi, ofset = birlesik, i * a.parca_sn - a.ortu_sn
        else:
            girdi, ofset = w, i * a.parca_sn
        try:
            if i and os.path.exists(onceki) and not os.path.exists(girdi):
                raise RuntimeError("örtüşme dosyası yok")
            soz = groq_yaz(girdi, anh, ofset) if a.kaynak == "groq" else yerel_yaz(girdi, ofset)
        except (urllib.error.URLError, TimeoutError, ConnectionError, OSError, RuntimeError, subprocess.CalledProcessError, KeyError, ValueError) as e:
            olay(dizin, f"parca {i} ATLANDI hata={type(e).__name__}")
            atlanan += 1
            i += 1
            continue
        soz = kirp(soz, i, a.parca_sn, a.ortu_sn, son)
        for _, kel in soz:
            metin_f.write(kel.strip() + " ")
        sozluk += soz
        if a.notu:
            while sozluk and sozluk[-1][0] >= penc_bas + a.pencere_sn:
                kes = penc_bas + a.pencere_sn
                ozet_yaz([s for s in sozluk if s[0] < kes], ozet_no); ozet_no += 1
                sozluk = [s for s in sozluk if s[0] >= kes]; penc_bas = kes
        olay(dizin, f"parca {i} yazildi kaynak={a.kaynak} sozcuk={len(soz)}")
        i += 1
    if sozluk:
        ozet_yaz(sozluk, ozet_no)
    metin_f.close()
    hata_dosyasi.close()
    rc = yakala.wait()
    hata = open(os.path.join(dizin, "yakala.err")).read()
    if i == 0:
        print("✗ hiç parça gelmedi: " + hata[-300:], file=sys.stderr)
        return 1
    olay(dizin, f"bitti parca={i} atlanan={atlanan} arac={arac} yakalama_rc={rc}")
    # rc = borunun SON halkası (ffmpeg): --sure ile kesilince streamlink/yt-dlp kopan boruyla biter, bu hata değildir;
    # yayın hiç açılmazsa ffmpeg boş girdi görür ve parça gelmez (rc 1 yolu).
    if rc != 0 or atlanan:
        print(f"! yakalama rc={rc}, atlanan parça={atlanan}: döküm eksik olabilir ({dizin}/yakala.err)", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
