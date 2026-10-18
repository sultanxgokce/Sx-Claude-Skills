#!/usr/bin/env python3
"""kanit.py — fabrika 3. adım (KANITLA): kanıtı toplar, manifesti ARAÇ yazar.

Neden araç yazar: "yaptım" beyanı kanıt değildir; elle yazılmış manifest de değildir. Bu araç her kaydı
kendisi üretir (komutu kendi koşar, kareyi kendi çeker, sha'yı kendi hesaplar) ve manifesti imzalar.
`dogrula` imzayı ve dosya sha'larını yeniden hesaplar: elle değişmiş manifest kırmızı (rc=1).

Renkler: yesil (ölçtü, korudu) · kirmizi (ölçtü, korumuyor) · sari (ÖLÇEMEDİ — rc=3; yeşil değildir).

Kullanım:
  kanit.py olcum  <iş> <etiket> --asama once|sonra -- <komut...>     komutu koşar, kırpılmamış çıktı+rc kaydeder
                  BORU DENETİMİ: komut `bash|sh -c '<betik>'` ise çıkış kodunu maskeleyen betik REDDEDİLİR (rc=1, kayıt yok):
                  `|| true` / `|| :` · başka komuttan sonra gelen son echo/printf/true/: · pipefail'siz boruyla biten son komut. Meşru istisna:
                  --boru-izin "<gerekçe ≥15 karakter>" → kayıt alınır, gerekçe manifeste `boru_denetimi` olarak yazılır.
  kanit.py ekran  <iş> <etiket> --asama once|sonra --url U [--urun-imi CSS] [--bekle CSS] [--genislik N]
  kanit.py dosya  <iş> <etiket> <yol> [--asama ...]                    var olan dosyayı (video, rapor) sha ile ekler
  kanit.py canli  <iş> <etiket> --kaynak dosya:<yol>|journal:<birim>|ssh:<sunucu>:<yol>|docker:<kutu>:<yol> --desen <RE> [--en-az N] [--son N]
                  CANLI sınıfı: gerçek ateşleme kaydı (saat damgalı + desenli log satırı); yoksa SARI rc=3 — kapı geçirmez.
                  Okuma komutunu ARAÇ kurar (tail/journalctl, sabit argv); serbest komut YOK (rc=1): kayıt üretilmez, okunur.
  kanit.py gecersiz <iş> <etiket|dosya> --neden "<≥20 kr>" --kim <AJAN> [--karsi <etiket|dosya>]
                  bir ölçümü SONRADAN geçersiz ilan eder: özgün kayda dokunmaz, hedefin ÖLÇÜM KİMLİĞİNE bağlı ilan kaydı EKLER;
                  hedef yeniden ölçülürse ilan o yeni ölçüme uygulanmaz. Geçersiz kayıt yeşil sayılmaz (etkin renk).
  kanit.py dogrula <iş>                                                imza + dosya sha'ları (0 sağlam · 1 bozuk · 3 yok)
  kanit.py ozet   <iş>                                                 PR gövdesi için tablo (markdown; renk = etkin renk)
  kanit.py liste  <iş> [--etkin]                                       --etkin: kayıtlar + etkin_renk, JSON
Ortam: KANIT_DEPO (depo kökü; vars. git toplevel) · KANIT_PLAYWRIGHT_DIR (node_modules'lı dizin)
"""
import argparse, datetime, hashlib, json, os, re, shlex, shutil, subprocess, sys, uuid

SURUM = "kanit.py/0.5.0"   # 0.5.0: `gecersiz` ilanı + etkin renk (18 Eki 2026) · 0.4.0: `canli` sınıfı (17 Eki 2026)
# Sürüm artık GÜVENLE yükseltilebilir: imza gövdesinde değil (yukarıdaki not).
# 0.1.0 → 0.3.0: 0.2.0 denendi ve geri alındı (o gün imza sürüme bağlıydı, yükseltmek
# bütün geçmişi suçluyordu); numarayı atlayarak o denemeyi izlenebilir bırakıyorum.
TUZ = "yazilim-fabrikasi-kanit-2026"  # imza tuzu: elle yazımı yakalar; kriptografik gizlilik iddiası YOK
HERE = os.path.dirname(os.path.abspath(__file__))


def hata(m, rc=1):
    print(f"✗ {m}", file=sys.stderr); sys.exit(rc)


def depo_kok(arg):
    d = arg or os.environ.get("KANIT_DEPO")
    if not d:
        try:
            d = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True, errors="replace", stderr=subprocess.DEVNULL).strip()
        except Exception:
            hata("depo kökü bulunamadı (--depo ver ya da KANIT_DEPO)", 3)
    return d


def kanit_dizin(depo, is_adi):
    return os.path.join(depo, "_agents", "fabrika", "kanit", is_adi)


def sha_dosya(yol):
    h = hashlib.sha256()
    with open(yol, "rb") as f:
        for p in iter(lambda: f.read(1 << 20), b""):
            h.update(p)
    return h.hexdigest()


# 🔴 İMZA SÜRÜMDEN AYRILDI (NÂZIR + RASATÇI bağımsız ölçtü · 8 Eki 2026)
#   ESKİ HÂL: imza gövdesi araç SÜRÜMÜNÜ içeriyordu. Sonuç: aracı güncellemek, eski araçla
#   yazılmış HER manifesti "İMZA TUTMUYOR — manifest elle değişmiş" diye suçluyordu. Mesaj
#   insanı yanlış yere sürüyor: sahtecilik aranır, oysa tek fark sürüm dizgisidir.
#   ÖLÇÜLDÜ: nazir kutusunda 31 manifestin 31'i 0.1.0 damgalı — sürüm artışı 31'ini birden
#   kırmızıya düşürürdü ve hiçbiri "sahte değilim" diyemezdi.
#   NİÇİN GÖÇ DEĞİL: göç = eski manifestleri yeniden imzalamak; o zaman araç KENDİ KOŞMADIĞI
#   koşumlara imza atar ve yeniden-imzalanmış kanıt, araç dışında üretilmişten ayırt edilemez
#   hâle gelir — imzanın var olma sebebi gider. (NÂZIR'ın cümlesi, katılıyorum.)
#   İMZANIN TEK SORUSU: "bu manifest araç DIŞINDA değişti mi". Sürüm bir BİLGİdir, hüküm değil.
#
#   🔴 ÇIKARMANIN KENDİSİ DE KIRAR — ölçtüm: gövdeden sürümü atmak imzayı değiştiriyor, yani
#   "düzeltme" eski manifestleri aynı anda geçersiz kılardı. Bu yüzden doğrulama UYUMLUDUR:
#   önce yeni biçim denenir, tutmazsa manifestin KENDİ kayıtlı sürümüyle eski biçim denenir.
#   Koşan aracın sürümü DEĞİL — manifestin kendi damgası. İkisi de tutmazsa gerçekten bozuktur.
def imza(kayitlar):
    """Yeni biçim: sürüm GÖVDEDE DEĞİL."""
    govde = json.dumps(kayitlar, ensure_ascii=False, sort_keys=True) + TUZ
    return hashlib.sha256(govde.encode()).hexdigest()


def imza_eski(kayitlar, arac_surumu):
    """Eski biçim: gövde sürümü İÇERİR. Yalnız GERİYE UYUM için — yeni yazımda kullanılmaz."""
    govde = json.dumps(kayitlar, ensure_ascii=False, sort_keys=True) + str(arac_surumu) + TUZ
    return hashlib.sha256(govde.encode()).hexdigest()


def imza_tutuyor_mu(m):
    """(tutuyor, bicim) → bicim: 'yeni' | 'eski' | None. Manifestin KENDİ 'arac' damgası esas."""
    kayitlar = m.get("kayitlar", [])
    mevcut = m.get("imza")
    if not mevcut:
        return False, None
    if mevcut == imza(kayitlar):
        return True, "yeni"
    arac = m.get("arac")
    if arac and mevcut == imza_eski(kayitlar, arac):
        return True, "eski"
    return False, None


def manifest_oku(dz):
    yol = os.path.join(dz, "KANIT.json")
    if not os.path.exists(yol):
        return None
    with open(yol, encoding="utf-8") as f:
        return json.load(f)


def manifest_yaz(dz, is_adi, kayitlar):
    m = {"is": is_adi, "arac": SURUM, "guncelleme": simdi(), "kayitlar": kayitlar, "imza": imza(kayitlar)}
    with open(os.path.join(dz, "KANIT.json"), "w", encoding="utf-8") as f:
        json.dump(m, f, ensure_ascii=False, indent=2); f.write("\n")
    return m


def simdi():
    return datetime.datetime.now().astimezone().isoformat(timespec="seconds")


def kayit_ekle(depo, is_adi, kayit):
    dz = kanit_dizin(depo, is_adi); os.makedirs(dz, exist_ok=True)
    m = manifest_oku(dz)
    kayitlar = m["kayitlar"] if m else []
    if m:
        tutuyor, bicim = imza_tutuyor_mu(m)
        if not tutuyor:
            hata("var olan KANIT.json imzası TUTMUYOR — elle değişmiş; yeni kayıt eklenmedi (dogrula ile bak)", 1)
        if bicim == "eski":
            # Manifest eski biçimle imzalanmış ve SAĞLAM. Şimdi ona yeni bir kayıt ekliyoruz,
            # yani bu yazımı ARAÇ yapıyor → yeni biçimle imzalamak meşrudur. Bu bir GÖÇ DEĞİL:
            # dokunulmamış kanıtı yeniden imzalamıyoruz, zaten yazdığımız manifesti imzalıyoruz.
            print(f"↻ manifest eski imza biçimindeydi ({m.get('arac')}) ve sağlamdı — bu yazımla "
                  f"yeni biçime geçiyor", file=sys.stderr)
    # AYNI KANIT DOSYASI = AYNI KAYIT (NÂZIR/MOTOR1, 7 Eki 2026). Ölçüm yeniden koşulunca
    # dosya ÜSTÜNE yazılıyordu ama manifestte eski kayıt kalıyordu → eski kaydın sha'sı artık
    # tutmaz ve `dogrula` KALICI rc=1 verirdi; silme komutu da yoktu, tek çıkış kanıt dizinini
    # komple silmekti (MOTOR1 iki kez yaptı). Kayıt KİMLİĞİ kanıt dosyasının adıdır: aynı
    # dosyaya iki kayıt işaret edemez. Üstüne yazmak SESSİZ olmaz — yüzeye basılır.
    # ÖLÇÜM KİMLİĞİ (4K938 göz tur 1): sha+zaman bir ölçümü TEK BAŞINA tanımlamaz — aynı çıktı aynı saniyede
    # yeniden ölçülünce ikisi de aynı kalır. Her yazımda araç tekil kimlik verir; geçersiz ilanı ona bağlanır.
    kayit.setdefault("olcum_id", uuid.uuid4().hex)
    eski_sira = next((i for i, k in enumerate(kayitlar) if k.get("dosya") == kayit.get("dosya")), None)
    if eski_sira is None:
        kayitlar.append(kayit)
    else:
        onceki = kayitlar[eski_sira]
        kayitlar[eski_sira] = kayit
        print(f"↻ aynı kanıt yeniden ölçüldü: {kayit.get('dosya')} "
              f"(önceki renk={onceki.get('renk')} → {kayit.get('renk')}; kayıt üstüne yazıldı)",
              file=sys.stderr)
    manifest_yaz(dz, is_adi, kayitlar)
    return dz


# ── boru denetimi (görev PTHAQ) ──────────────────────────────────────────────────
#    Araç komutu argv olarak koşar (kabuk yok), rc'yi kendisi ölçer. Ama komut `bash -c '…'` verilince betiğin İÇİNDEKİ
#    maske (son komut `| tail`, `; echo`, `|| true`) asıl çıkış kodunu yutar: kırmızı koşum yeşil kayda düşer ve araç
#    bunu göremez. Bu yüzden kabuk -c betiği koşmadan önce ayrıştırılır; çıkış kodunun SON komuttan geldiği kural:
#      (a) `|| true` / `|| :`  — nerede olursa olsun açık maskedir;
#      (b) son komut echo/printf/true/: VE öncesinde başka komut var  — çıkış kodu artık ölçülen işin değil, o komutun;
#      (c) son komut boru (`a | b`) ve o noktada pipefail AÇIK değil  — çıkış kodu boru SONUNDAKİ süzgecin.
#    Ayrıştırılamayan betik (heredoc, dengesiz tırnak) REDDEDİLMEZ; kayda `boru_denetimi: ayrıştırılamadı` düşer — denetçi görür.
#    Dosya betiği (`bash x.sh`) içeriği denetlenmez; kayda `kapsam-dışı` düşer (sınır dürüstçe beyan edilir).
KABUKLAR = {"bash", "sh", "dash", "zsh", "ksh"}
MASKE_SON = {"echo", "printf", "true", ":", "set"}   # son komut `set …` da 0 döner, öncekinin rc'sini yutar
AYIRAC = {";", "&&", "||", "&", ";;"}
ONEKLER = {"command", "builtin", "exec", "time", "nohup", "noglob"}
# Kabuğu ÇALIŞTIRAN sarmalayıcılar (göz tur 3): kabuk yalnız argv başında ya da bu zincirin arkasında kabuktur;
# `printf bash -c …` içindeki `bash` bir VERİDİR, çalışmaz. Sarmalayıcının seçenekleri (`-…`), VAR=değer ve süre/sayı
# argümanları atlanır; DEĞER ALAN seçeneklerin değeri de atlanır (göz tur 5: `timeout -s KILL 60`, `env -u VAR`);
# tanınmayan argüman zinciri keser → kapsam-dışı.
SARMALAYICI = {"timeout", "nice", "ionice", "env", "nohup", "setsid", "stdbuf", "chrt", "taskset", "command", "exec", "time"}
DEGERLI_SECENEK = {
    "timeout": {"-s", "--signal", "-k", "--kill-after"},
    "env": {"-u", "--unset", "-C", "--chdir", "-S", "--split-string"},
    "nice": {"-n", "--adjustment"},
    "ionice": {"-c", "--class", "-n", "--classdata", "-p", "--pid"},
    "stdbuf": {"-i", "-o", "-e", "--input", "--output", "--error"},
    "exec": {"-a"},
    "time": {"-f", "--format", "-o", "--output"},
}


def _kabuk_konumu(komut):
    k = 0
    while k < len(komut):
        ad = os.path.basename(komut[k])
        if ad in KABUKLAR:
            return k
        if ad not in SARMALAYICI:
            return None
        k += 1
        degerli = DEGERLI_SECENEK.get(ad, set())
        while k < len(komut) and (komut[k].startswith("-") or re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", komut[k])
                                  or re.fullmatch(r"(0x[0-9a-fA-F]+|[0-9]+(\.[0-9]+)?[smhd]?)", komut[k])):
            k += 2 if komut[k] in degerli else 1
    return None


def _yalin(toklar):
    """Komut başındaki önekleri (command/builtin/exec…) soyar, ilk kelimeyi yoldan arındırır."""
    while len(toklar) > 1 and toklar[0] in ONEKLER:
        toklar = toklar[1:]
    return [os.path.basename(toklar[0])] + toklar[1:] if toklar else toklar

def _pipefail_etkisi(argumanlar, durum):
    """`set`/kabuk argümanlarında `-o pipefail` (ya da `-euo pipefail`) açar, `+o pipefail` kapatır; yoksa durum aynen kalır."""
    for k in range(len(argumanlar) - 1):
        a, sonraki = argumanlar[k], argumanlar[k + 1]
        if sonraki == "pipefail" and len(a) >= 2 and a[0] in "-+" and "o" in a[1:]:
            durum = a[0] == "-"
    return durum

def boru_denetimi(komut):
    """(durum, neden) — durum: temiz | maske | ayristirilamadi | kapsam-disi"""
    # Kabuk argv'nin BAŞINDA olmak zorunda değil (göz tur 2): `timeout 600 bash -c`, `nice bash -c`, `env X=1 bash -c` da kabuktur.
    # -c birleşik seçenek kümesinde de olabilir (`bash -lc`, `bash -ec`). Seçenek kümesi = `-` ile başlayan, harflerden oluşan argüman.
    j = _kabuk_konumu(komut)
    if j is None:
        return "kapsam-disi", None
    # -c yalnız kabuğun SEÇENEK bölgesinde seçenektir (göz tur 4): ilk seçenek-dışı argüman (betik dosyası) ya da `--`
    # bölgeyi bitirir — `bash x.sh -c '…'` içindeki -c betiğe giden argümandır. `-o/+o` (ve `-euo` gibi o ile biten küme) değer alır.
    i = None; k = j + 1
    while k < len(komut):
        t = komut[k]
        if t == "--" or not (t.startswith("-") or t.startswith("+")):
            break
        if re.fullmatch(r"-[A-Za-z]*c[A-Za-z]*", t):
            i = k; break
        k += 2 if re.fullmatch(r"[-+][A-Za-z]*[oO]", t) else 1
    if i is None:
        return "kapsam-disi", None
    if i + 1 >= len(komut):
        return "ayristirilamadi", "-c sonrası betik yok"
    betik = komut[i + 1]
    komut = komut[j:]; i -= j   # aşağıdaki pipefail argüman taraması kabuktan itibaren
    try:
        # yeni satır da komut ayıracıdır: ayrıştırma için `;` sayılır (tırnak içindeki satır sonları da — yalnız analiz)
        lx = shlex.shlex(betik.replace("\n", " ; "), posix=True, punctuation_chars=";&|()<>")
        lx.wordchars += "+"   # `set +o pipefail`: `+o` tek parça kalmalı (yoksa `+` ve `o` diye bölünür, kapatma görülmez)
        jet = list(lx)
    except ValueError as e:
        return "ayristirilamadi", f"betik ayrıştırılamadı ({e})"
    if "<<" in jet or "<<-" in jet:
        return "ayristirilamadi", "heredoc içeren betik denetlenmedi"
    for k in range(len(jet) - 1):
        if jet[k] == "||":
            # göz tur 3: `|| /bin/true`, `|| command true` aynı maskedir → `||` sağındaki komut önekleri/yolu soyularak bakılır
            sag = []
            for t in jet[k + 1:]:
                if t in AYIRAC or t == "|":
                    break
                sag.append(t)
            yalin = _yalin(sag)
            if yalin and yalin[0] in ("true", ":"):
                return "maske", "`|| " + " ".join(sag) + "` çıkış kodunu yutuyor"
    # son anlamlı komut: son ayıracın sağı (sondaki boş ayıraçlar atılır)
    while jet and jet[-1] in AYIRAC:
        jet.pop()
    son = []
    for t in reversed(jet):
        if t in AYIRAC:
            break
        son.insert(0, t)
    if not son:
        return "ayristirilamadi", "son komut bulunamadı"
    oncesi = [t for t in jet[:len(jet) - len(son)] if t not in AYIRAC]
    # Önekler soyulur (göz tur 2): `command echo`, `builtin echo`, `exec true`, `/bin/echo` aynı maskedir.
    son = _yalin(son)
    if son[0] in MASKE_SON and oncesi:   # betiğin TEK komutu echo ise maskelenen bir iş yoktur (ölçülen şey odur)
        return "maske", f"son komut `{son[0]}` — betiğin çıkış kodu ölçülen işin değil `{son[0]}`'nun"
    # pipefail DURUMU sırayla izlenir (göz tur 1: kelimenin geçmesi yetmiyordu — `echo pipefail` ya da `set +o pipefail` geçiyordu).
    # Başlangıç kabuk argümanından (`bash -o pipefail -c`, `bash -euo pipefail -c`); sonra son komuttan ÖNCEKİ her `set` komutu
    # `-…o pipefail` ile açar, `+…o pipefail` ile kapatır. Son komutun kendisi sayılmaz.
    pipefail = _pipefail_etkisi(komut[1:i], False)
    bolum = []
    for t in jet[:len(jet) - len(son)] + [";"]:
        if t in AYIRAC:
            if bolum and bolum[0] == "set":
                pipefail = _pipefail_etkisi(bolum[1:], pipefail)
            bolum = []
        else:
            bolum.append(t)
    if "|" in son and not pipefail:
        suzgec = son[len(son) - 1 - son[::-1].index("|") + 1] if son[-1] != "|" else "?"
        return "maske", f"son komut boruyla bitiyor (`… | {suzgec}`) ve pipefail yok — çıkış kodu süzgecin"
    return "temiz", None

# ── olcum ────────────────────────────────────────────────────────────────────────
def cmd_olcum(a):
    if not a.komut:
        hata("komut gerekiyor: -- <komut...>")
    durum, neden = boru_denetimi(a.komut)
    if durum == "maske":
        if not a.boru_izin:
            hata(f"BORU REDDİ: {neden}. Kayıt ÜRETİLMEDİ. Çare: ölçülen komutun rc'sini değişkene al ve betiği `exit $rc` ile bitir, "
                 f"ya da `set -o pipefail` koy; sayım gerekiyorsa sayıyı değişkene alıp basın, son komut yine `exit` olsun. "
                 f"Meşru istisna: --boru-izin \"<niçin, ≥15 karakter>\" (gerekçe manifeste yazılır)")
        if len(a.boru_izin.strip()) < 15:
            hata("--boru-izin gerekçesi en az 15 karakter olmalı (denetçi okuyacak)")
        boru = f"izinli: {neden} · gerekçe: {a.boru_izin.strip()}"
    elif durum == "ayristirilamadi":
        boru = f"ayrıştırılamadı: {neden}"
    else:
        boru = {"temiz": "temiz", "kapsam-disi": "kapsam-dışı (kabuk -c değil; dosya betiği içeriği denetlenmez)"}[durum]
    depo = depo_kok(a.depo); dz = kanit_dizin(depo, a.is_adi); os.makedirs(dz, exist_ok=True)
    ad = f"olcum-{a.etiket}-{a.asama}.txt"
    yol = os.path.join(dz, ad)
    t0 = datetime.datetime.now()
    p = subprocess.run(a.komut, capture_output=True, text=True, errors="replace")   # boru YOK: çıktı kırpılmadan
    sure = (datetime.datetime.now() - t0).total_seconds()
    with open(yol, "w", encoding="utf-8") as f:
        f.write(f"$ {' '.join(a.komut)}\n# rc={p.returncode} sure={sure:.1f}s zaman={simdi()}\n--- stdout ---\n{p.stdout}--- stderr ---\n{p.stderr}")
    renk = "sari" if p.returncode == 3 else ("yesil" if p.returncode == 0 else "kirmizi")
    kayit = {"tur": "olcum", "etiket": a.etiket, "asama": a.asama, "dosya": ad, "sha256": sha_dosya(yol),
             "komut": a.komut, "rc": p.returncode, "renk": renk, "zaman": simdi(), "sure_sn": round(sure, 1),
             "boru_denetimi": boru}
    kayit_ekle(depo, a.is_adi, kayit)
    print(f"{'✓' if renk=='yesil' else ('◻' if renk=='sari' else '✗')} ölçüm kaydedildi: {ad} rc={p.returncode} renk={renk}")
    print(p.stdout, end="")
    if p.stderr: print(p.stderr, end="", file=sys.stderr)
    sys.exit(0 if renk != "sari" else 3)


# ── ekran ────────────────────────────────────────────────────────────────────────
EKSIK_KITAPLIK = re.compile(r"([\w.+-]+\.so[\w.]*): cannot open shared object file")


def kitaplik_yolu():
    """Tarayıcının sistem kitaplıklarının yolu — ORTAMDAN okunur, ÇİVİLENMEZ.

    🔴 NİÇİN (MEDDAH/TELLAL ölçümü 2026-10-06): o kutuda tarayıcının yedi sistem kitaplığı
       root'suz kurulmuş ve yalnız LD_LIBRARY_PATH verilirse görünüyor. Değişken verilmezse
       kare ALINAMIYOR ve kanıt SARI'ya düşüyor — sebebi "tarayıcı ayağa kalkmadı" değil,
       "kitaplık görünmedi". Yolu buraya çivilemek yanlış olurdu: her kutuda ayrı yer.
       Oda ayarını `KANIT_PW_LIBS` ile verir; varsa LD_LIBRARY_PATH'in ÖNÜNE eklenir
       (mevcut değer korunur — ezmek, kutunun kendi ayarını sessizce silmek olurdu).
    """
    return os.environ.get("KANIT_PW_LIBS", "").strip()


def playwright_dizin():
    aday = [os.environ.get("KANIT_PLAYWRIGHT_DIR")] + [
        os.path.join(d, "node_modules") for d in ("/config/projects/Nexus/ui", "/config/projects/akar", os.getcwd())]
    for d in aday:
        if d and os.path.isdir(os.path.join(d, "playwright")):
            return d
    return None


def cmd_ekran(a):
    depo = depo_kok(a.depo); dz = kanit_dizin(depo, a.is_adi); os.makedirs(dz, exist_ok=True)
    ad = f"ekran-{a.etiket}-{a.asama}.png"; yol = os.path.join(dz, ad)
    pw = playwright_dizin()
    temel = {"tur": "ekran", "etiket": a.etiket, "asama": a.asama, "dosya": ad, "url": a.url, "zaman": simdi()}
    if not pw or not shutil.which("node"):
        kayit = {**temel, "sha256": None, "rc": 3, "renk": "sari", "not": "playwright/node bulunamadı — kare ALINAMADI"}
        kayit_ekle(depo, a.is_adi, kayit)
        print("◻ SARI: kare alınamadı (playwright/node yok) — bu yeşil DEĞİLDİR; manifeste sarı yazıldı")
        sys.exit(3)
    env = {**os.environ, "NODE_PATH": pw}
    libs = kitaplik_yolu()
    if libs:
        onceki = env.get("LD_LIBRARY_PATH", "")
        env["LD_LIBRARY_PATH"] = f"{libs}:{onceki}" if onceki else libs
    argv = ["node", os.path.join(HERE, "kanit-ekran.mjs"), a.url, yol, a.urun_imi or "", a.bekle or "", str(a.genislik)]
    p = subprocess.run(argv, capture_output=True, text=True, errors="replace", env=env)
    if p.returncode == 2:
        kayit = {**temel, "sha256": None, "rc": 2, "renk": "kirmizi", "not": "ÜRÜN İMİ YOK — açılan sayfa ürün değil (giriş/hata sayfası olabilir)"}
        kayit_ekle(depo, a.is_adi, kayit)
        print(f"✗ ürün imi bulunamadı ({a.urun_imi}) — ölçer ürünü görmedi; kare kanıt sayılmaz\n{p.stderr}", file=sys.stderr)
        sys.exit(2)
    if p.returncode != 0 or not os.path.exists(yol):
        # 🔴 SEBEBİ KIRPMA (MEDDAH, 2026-10-06): stderr 300 karakterde kesiliyordu ve asıl
        #    satır ("… .so: cannot open shared object file") ÖNDEKİ gürültünün arkasında
        #    kalıyordu. Ölçülmüş vaka: üstte "Target page, context or browser has been closed"
        #    görünüyor, gerçek sebep altta duruyor. Teşhis edilemeyen sarı, sarı değil sistir.
        tam = (p.stderr or "") + (p.stdout or "")
        eksik = sorted(set(EKSIK_KITAPLIK.findall(tam)))
        gunluk = os.path.join(dz, f"ekran-{a.etiket}-{a.asama}.hata.txt")
        with open(gunluk, "w", encoding="utf-8") as f:
            f.write(f"$ {' '.join(argv)}\nrc={p.returncode} zaman={simdi()}\n"
                    f"LD_LIBRARY_PATH={env.get('LD_LIBRARY_PATH','(yok)')}\n"
                    f"--- stdout ---\n{p.stdout}--- stderr ---\n{p.stderr}")
        kayit = {**temel, "sha256": None, "rc": 3, "renk": "sari",
                 "eksik_kitaplik": eksik, "hata_gunlugu": os.path.basename(gunluk),
                 "ld_library_path": env.get("LD_LIBRARY_PATH", ""),
                 "not": (f"kare alınamadı · EKSİK KİTAPLIK: {', '.join(eksik)}" if eksik
                         else f"kare alınamadı: {p.stderr.strip()[:300]}")}
        kayit_ekle(depo, a.is_adi, kayit)
        if eksik:
            print(f"◻ SARI: kare alınamadı — EKSİK KİTAPLIK: {', '.join(eksik)}")
            print(f"   Bu 'tarayıcı ayağa kalkmadı' DEĞİL: kitaplık görünmüyor. Odanın kitaplık")
            print(f"   dizinini KANIT_PW_LIBS ile ver (şu an: {kitaplik_yolu() or 'verilmemiş'}).")
        else:
            print(f"◻ SARI: kare alınamadı — {p.stderr.strip()[:300]}")
        print(f"   tam çıktı kırpılmadan burada: {os.path.basename(gunluk)}")
        sys.exit(3)
    kayit = {**temel, "sha256": sha_dosya(yol), "rc": 0, "renk": "yesil", "urun_imi": a.urun_imi, "genislik": a.genislik}
    kayit_ekle(depo, a.is_adi, kayit)
    print(f"✓ kare alındı: {ad} ({a.genislik}px{' · ürün imi doğrulandı' if a.urun_imi else ''})")


# ── dosya ────────────────────────────────────────────────────────────────────────
def cmd_dosya(a):
    depo = depo_kok(a.depo); dz = kanit_dizin(depo, a.is_adi); os.makedirs(dz, exist_ok=True)
    if not os.path.isfile(a.yol): hata(f"dosya yok: {a.yol}", 3)
    ad = f"dosya-{a.etiket}-{a.asama}{os.path.splitext(a.yol)[1]}"; hedef = os.path.join(dz, ad)
    shutil.copyfile(a.yol, hedef)
    kayit = {"tur": "dosya", "etiket": a.etiket, "asama": a.asama, "dosya": ad, "sha256": sha_dosya(hedef),
             "kaynak": os.path.abspath(a.yol), "rc": 0, "renk": "yesil", "zaman": simdi()}
    kayit_ekle(depo, a.is_adi, kayit)
    print(f"✓ dosya eklendi: {ad}")



# ── canli ────────────────────────────────────────────────────────────────────────
# 🔴 "GİT'TE DÜZELTİLDİ ≠ CANLIDA ÇALIŞIYOR" (haftalık retro 17 Eki 2026 · ders 1 · gorev_01M54APFDAHKN72VKBWTGKSAAM):
#    10-16 Eki 119 işte en büyük bulgu kümesi buydu — 81 bulgu / 41 iş (wa-gecit ×7, terminal-16-kutu-kurulum ×5,
#    donus-zili ×8); muhakkik-zil 5 tur ulaşmadı, 14/15 kutu kapısı eski sürümde kaldı. cron · servis · sunucu içeren
#    işte "dosya yerinde, birim sınavı yeşil" kanıt DEĞİLDİR; kanıt İLK GERÇEK ATEŞLEMEDİR: bir log satırı + saati +
#    nereden okunduğu. Bu alt komut o kaydı ARAÇ eliyle toplar: log komutunu kendisi koşar (stdin kapalı), saat
#    damgalı satırları sayar, ilkini kayda yazar. Saat damgasız satır ateşleme sayılmaz ("servis dosyası var" bir
#    ateşleme değildir). Kaynağa ulaşılamadıysa (komut rc≠0) ya da ateşleme yoksa renk SARI, rc=3 — kırmızı değil
#    (kusur ölçülmedi), yeşil hiç değil. Birleştirme kapısı sarı canlıyı geçirmez; cron/servis/sunucu kartı yeşil
#    canlı kayıt olmadan geçmez (birlestirme-kapisi.sh 2b).
SAAT_RE = re.compile(
    r"\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(?::\d{2}(?:[.,]\d+)?)?(?:Z|[+-]\d{2}:?\d{2})?"      # ISO 8601 · journalctl -o short-iso
    r"|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|Oca|Şub|Nis|Haz|Tem|Ağu|Eyl|Eki|Kas|Ara)\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}"  # syslog · journalctl varsayılan
    r"|\d{1,2}[./]\d{1,2}[./]\d{4}[ T,]+\d{1,2}:\d{2}(?::\d{2})?"                            # 17.10.2026 07:02:11
    r"|\d{2}/[A-Z][a-z]{2}/\d{4}:\d{2}:\d{2}:\d{2}"                                          # apache/nginx erişim günlüğü
)


# 🔴 GÖZ TUR 1-3 (PR #352): "saatli bir echo ile yeşil kayıt" (tur 1) → echo/printf kara listesi (tur 2) → "python/awk ile de
#    üretilir, kara liste tutmaz" (tur 3) — doğru: üreticiyi saymakla bitmez. Yapısal çözüm: SERBEST KOMUT YOK. Kaynak türlüdür ve
#    okuma komutunu ARAÇ kurar: dosya:<yol> → tail · journal:<birim> → journalctl · ssh:<sunucu>:<yol> → ssh … tail · docker:<kutu>:<yol>
#    → docker exec … tail. Hedef ve yol yalnız güvenli karakter (ssh/docker uzak kabuk açar: enjeksiyon yolu kapalı). Geriye kalan
#    tek sahtecilik "log dosyasını elle yazmak"tır — o da manifestte yol olarak görünür ve bağımsız göz onu okur (olcum ile aynı güven).
KAYNAK_RE = re.compile(r"^(dosya|journal|ssh|docker):(.+)$", re.S)
# yedek göz #354: baştaki "-" seçenek enjeksiyonudur (ssh -F…, docker --…) → ilk karakter harf/rakam/./_/@/+ ya da / olmalı
GUVENLI_RE = re.compile(r"^[A-Za-z0-9_.@/+][A-Za-z0-9_.@/+-]*$")


def kaynak_komutu(kaynak, son):
    """--kaynak türünden OKUMA komutunu kurar → (argv, tür, hata). Serbest komut yolu yoktur."""
    m = KAYNAK_RE.match((kaynak or "").strip())
    if not m:
        return None, None, ("--kaynak türü tanınmadı: dosya:<yol> · journal:<birim> · ssh:<sunucu>:<yol> · docker:<kutu>:<yol> "
                            "(serbest komut yok — ateşleme kaydı üretilmez, okunur)")
    tur, geri = m.group(1), m.group(2).strip()
    if tur == "dosya":
        return ["tail", "-n", str(son), "--", geri], tur, None
    parcalar = [geri] if tur == "journal" else geri.split(":", 1)
    if tur != "journal" and len(parcalar) != 2:
        return None, tur, f"{tur}:<hedef>:<yol> bekleniyor"
    for parca in parcalar:
        if not GUVENLI_RE.match(parca):
            return None, tur, f"{tur} kaynağında kabuk metakarakteri ya da boş parça: {parca!r} — yalnız harf/rakam/._@/+- (uzak kabuk enjeksiyonu yok)"
    if tur == "journal":
        return ["journalctl", "-u", geri, "-n", str(son), "--no-pager", "-o", "short-iso"], tur, None
    hedef, yol = parcalar
    if tur == "ssh":
        return ["ssh", "-o", "BatchMode=yes", hedef, "tail", "-n", str(son), "--", yol], tur, None
    return ["docker", "exec", hedef, "tail", "-n", str(son), "--", yol], tur, None


AYLAR = {"jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6, "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
         "oca": 1, "şub": 2, "nis": 4, "haz": 6, "tem": 7, "ağu": 8, "eyl": 9, "eki": 10, "kas": 11, "ara": 12}


def saat_coz(s):
    """SAAT_RE eşleşmesini ISO 8601'e çevirir (kapı kart açılışıyla karşılaştırır). Çözülemezse None — yeşil sayılmaz."""
    try:
        d = None
        if re.match(r"\d{4}-\d{2}-\d{2}[T ]", s):
            t = s.replace(" ", "T", 1).replace(",", ".")
            if t.endswith("Z"): t = t[:-1] + "+00:00"
            t = re.sub(r"([+-]\d{2})(\d{2})$", r"\1:\2", t)
            d = datetime.datetime.fromisoformat(t)
        elif re.match(r"[A-Za-zŞşĞğ]{3}\s", s):
            m = re.match(r"([A-Za-zŞşĞğ]{3})\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})", s)
            yil = datetime.datetime.now().year
            d = datetime.datetime(yil, AYLAR[m.group(1).lower()], int(m.group(2)), int(m.group(3)), int(m.group(4)), int(m.group(5)))
            if d > datetime.datetime.now() + datetime.timedelta(days=1): d = d.replace(year=yil - 1)   # yılsız syslog, yılbaşı dönüşü
        elif re.match(r"\d{1,2}[./]\d{1,2}[./]\d{4}", s):
            m = re.match(r"(\d{1,2})[./](\d{1,2})[./](\d{4})[ T,]+(\d{1,2}):(\d{2})(?::(\d{2}))?", s)
            d = datetime.datetime(int(m.group(3)), int(m.group(2)), int(m.group(1)), int(m.group(4)), int(m.group(5)), int(m.group(6) or 0))
        else:
            m = re.match(r"(\d{2})/([A-Z][a-z]{2})/(\d{4}):(\d{2}):(\d{2}):(\d{2})", s)
            d = datetime.datetime(int(m.group(3)), AYLAR[m.group(2).lower()], int(m.group(1)), int(m.group(4)), int(m.group(5)), int(m.group(6)))
        if d.tzinfo is None: d = d.astimezone()   # saat dilimi yoksa kutunun yerel saati
        return d.isoformat(timespec="seconds")
    except Exception:
        return None


def cmd_canli(a):
    if a.komut:
        hata("serbest komut kabul edilmez (-- sonrası): ateşleme kaydı üretilmez, OKUNUR — --kaynak dosya:|journal:|ssh:|docker: ver, okuma komutunu araç kurar", 1)
    if not (a.kaynak or "").strip():
        hata("--kaynak gerekiyor: kaydın NEREDEN okunduğu (kutu/sunucu · log yeri) — kaynaksız ateşleme kaydı kanıt değildir")
    # 🔴 GÖZ TUR 2 (PR #352): "--desen isteğe bağlı → log çıktısındaki HERHANGİ saatli satır ateşleme sayılıyor, ilgili servise
    #    bağlanmıyor" — doğru. Desen ZORUNLU: ateşleme, kartın işine ait servis/olay adıyla eşleşen satırdır; genel saat yetmez.
    if not (a.desen or "").strip():
        hata("--desen gerekiyor: ateşleme hangi servis/olay satırı? (ör. --desen muhakkik-zil) — desensiz saatli satır ateşleme değildir")
    try:
        desen = re.compile(a.desen)
    except re.error as e:
        hata(f"--desen geçersiz: {e}")
    if a.en_az < 1:
        hata("--en-az en az 1 olmalı (0 ateşleme kanıt değildir)")
    if a.son < 1:
        hata("--son en az 1 olmalı")
    komut, tur, sebep = kaynak_komutu(a.kaynak, a.son)
    if sebep:
        hata(sebep, 1)
    depo = depo_kok(a.depo); dz = kanit_dizin(depo, a.is_adi); os.makedirs(dz, exist_ok=True)
    ad = f"canli-{a.etiket}.txt"; yol = os.path.join(dz, ad)
    t0 = datetime.datetime.now()
    # stdin KAPALI: arka planda / cron'dan çağrılınca açık bir socket'te asılı kalmasın (denetçi 68 dk vakası, 0.6.3)
    try:
        p = subprocess.run(komut, capture_output=True, text=True, errors="replace", stdin=subprocess.DEVNULL)
    except OSError as e:
        # komut bu kutuda yok (ör. journalctl konteynerde) → kaynağa ulaşılamadı = SARI; traceback kanıt değildir
        p = subprocess.CompletedProcess(komut, 127, "", f"komut çalıştırılamadı: {e}\n")
    sure = (datetime.datetime.now() - t0).total_seconds()
    ates = []
    for satir in p.stdout.splitlines():
        m = SAAT_RE.search(satir)
        if not m: continue
        if not desen.search(satir): continue
        ates.append((satir, m.group(0)))
    with open(yol, "w", encoding="utf-8") as f:
        f.write(f"$ {' '.join(komut)}\n# kaynak={a.kaynak.strip()} tur={tur} desen={a.desen} en_az={a.en_az} son={a.son} "
                f"atesleme={len(ates)} rc={p.returncode} sure={sure:.1f}s zaman={simdi()}\n--- stdout ---\n{p.stdout}--- stderr ---\n{p.stderr}")
    def _kayit(x): return {"satir": x[0].strip()[:500], "saat": x[1], "saat_iso": saat_coz(x[1])}
    ilk = _kayit(ates[0]) if ates else None; son = _kayit(ates[-1]) if ates else None
    # 🔴 GÖZ TUR 2: geleceğe tarihli log satırı "işe bağlı yeşil" sayılabilirdi. Son ateşleme ölçüm anından 5 dk'dan ileriyse
    #    saat çözümü ya da log şüphelidir → SARI (kapı da ayrıca reddeder: çift çit).
    gelecek = None
    if son and son.get("saat_iso"):
        try:
            _s = datetime.datetime.fromisoformat(son["saat_iso"]); _n = datetime.datetime.now().astimezone()
            if _s > _n + datetime.timedelta(minutes=5): gelecek = son["saat_iso"]
        except Exception:
            pass
    notu = None
    if p.returncode != 0:
        notu = f"log kaynağına ulaşılamadı (rc={p.returncode}) — ateşleme ölçülemedi"
    elif gelecek:
        notu = f"son ateşleme saati GELECEKTE ({gelecek}) — saat çözümü ya da log şüpheli; ateşleme sayılmaz"
    elif len(ates) < a.en_az:
        notu = (f"ateşleme kaydı {'YOK' if not ates else f'{len(ates)} < {a.en_az}'} — yazılmış ≠ çalışıyor; "
                f"saat damgalı log satırı bekleniyordu" + (f" (desen: {a.desen})" if a.desen else ""))
    renk = "sari" if (p.returncode != 0 or len(ates) < a.en_az or gelecek) else "yesil"
    kayit = {"tur": "canli", "etiket": a.etiket, "asama": "canli", "dosya": ad, "sha256": sha_dosya(yol),
             "komut": komut, "rc": p.returncode, "renk": renk, "kaynak": a.kaynak.strip(), "kaynak_turu": tur, "son": a.son, "desen": a.desen,
             "en_az": a.en_az, "atesleme_sayisi": len(ates), "ilk_atesleme": ilk, "son_atesleme": son, "zaman": simdi(), "sure_sn": round(sure, 1)}
    if notu: kayit["not"] = notu
    kayit_ekle(depo, a.is_adi, kayit)
    if renk == "yesil":
        print(f"✓ canlı kayıt: {ad} · {len(ates)} ateşleme · ilk: {ilk['saat']} · kaynak: {a.kaynak.strip()}")
    else:
        print(f"◻ SARI: {notu} — bu yeşil DEĞİLDİR; birleştirme kapısı bu kanıtla geçmez ({ad})")
    if p.stderr: print(p.stderr, end="", file=sys.stderr)
    sys.exit(0 if renk == "yesil" else 3)


# ── gecersiz ─────────────────────────────────────────────────────────────────────
# 4K938 (18 Eki 2026): bir ölçüm sonradan yanlış çıkabilir (boru çıkış kodunu maskeledi, yanlış dal ölçüldü).
#   Yol YOKTU: kaydı silmek geçmişi, elle "kirmizi" yazmak imzayı bozar; tek çıkış kanıt dizinini silmekti.
#   Özgün kayda DOKUNULMAZ; hedefin sha'sına ve zamanına bağlı ayrı bir İLAN kaydı eklenir (imza onu da kapsar).
#   Hedef yeniden ölçülürse ilan uygulanmaz: o ilan eski ölçüme aitti. Bağ ÖLÇÜM KİMLİĞİDİR (olcum_id, her yazımda tekil);
#   sha+zaman yalnız kimliksiz (0.10.2 öncesi) kayıtta yedek — aynı çıktı aynı saniyede ikisini de tekrarlar (göz tur 1).
#   Etkin renk TEK yerde hesaplanır (etkin_kayitlar); kapı ve kart.sh aynı fonksiyonu çağırır, kopya yazmaz.
#   🔴 İlan kapıyı hiçbir zaman GEVŞETMEZ: geçersiz yeşil yeşil sayılmaz, geçersiz canlı sarı gibi engeldir.
NEDEN_EN_AZ = 20


def _ayni_olcum(h, g):
    """İlan g, kayıt h'nin BU ölçümüne mi ait? Kimlik varsa yalnız kimlik; kimliksiz eski ilan/kayıtta sha+zaman (geri uyum)."""
    if g.get("hedef_olcum_id"):
        return h.get("olcum_id") == g["hedef_olcum_id"]
    return not h.get("olcum_id") and (h.get("sha256"), h.get("zaman")) == (g.get("hedef_sha256"), g.get("hedef_zaman"))


def gecersiz_ilanlari(kayitlar):
    """hedef dosya → ilan; yalnız hedefin ŞİMDİKİ ölçümüne hâlâ uyan ilanlar."""
    hedefler = {k.get("dosya"): k for k in kayitlar if k.get("tur") != "gecersiz"}
    uyan = {}
    for g in kayitlar:
        if g.get("tur") != "gecersiz":
            continue
        h = hedefler.get(g.get("hedef_dosya"))
        if h is not None and _ayni_olcum(h, g):
            uyan[g["hedef_dosya"]] = g
    return uyan


def etkin_kayitlar(m):
    """Kayıtların kopyası + etkin_renk: geçersiz ilan edilen 'gecersiz', ilanın kendisi 'ilan', gerisi kendi rengi."""
    kayitlar = (m or {}).get("kayitlar", [])
    ilanlar = gecersiz_ilanlari(kayitlar)
    cikti = []
    for k in kayitlar:
        e = dict(k)
        if k.get("tur") == "gecersiz":
            e["etkin_renk"] = "ilan"; e["uygulaniyor"] = ilanlar.get(k.get("hedef_dosya")) is k
        elif k.get("dosya") in ilanlar:
            g = ilanlar[k["dosya"]]
            e["etkin_renk"] = "gecersiz"; e["gecersiz_neden"] = g.get("neden"); e["gecersiz_kim"] = g.get("kim"); e["gecersiz_karsi"] = g.get("karsi")
        else:
            e["etkin_renk"] = k.get("renk")
        cikti.append(e)
    return cikti


def cmd_gecersiz(a):
    depo = depo_kok(a.depo); dz = kanit_dizin(depo, a.is_adi); m = manifest_oku(dz)
    if not m:
        hata(f"{dz}/KANIT.json YOK — geçersiz ilan edilecek ölçüm yok", 3)
    if not imza_tutuyor_mu(m)[0]:
        hata("var olan KANIT.json imzası TUTMUYOR — elle değişmiş; ilan yazılmadı (dogrula ile bak)", 1)
    neden = (a.neden or "").strip(); kim = (a.kim or "").strip()
    if len(neden) < NEDEN_EN_AZ:
        hata(f"--neden en az {NEDEN_EN_AZ} karakter olmalı (verilen {len(neden)}): neyin yanlış ölçüldüğünü yaz")
    if not kim:
        hata("--kim gerekiyor (ilanı kim veriyor)")
    kayitlar = m["kayitlar"]
    ilanlar = gecersiz_ilanlari(kayitlar)

    def coz(ad, ne):
        olcumler = [k for k in kayitlar if k.get("tur") != "gecersiz"]
        aday = [k for k in olcumler if k.get("dosya") == ad] or [k for k in olcumler if k.get("etiket") == ad]
        if not aday:
            hata(f"{ne} bulunamadı: '{ad}' — etiket ya da dosya adı ver (bkz. ozet)")
        if len(aday) > 1:
            hata(f"{ne} belirsiz: '{ad}' etiketi {len(aday)} kayıtta ({', '.join(k['dosya'] for k in aday)}) — dosya adını ver")
        return aday[0]

    h = coz(a.hedef, "hedef")
    if h["dosya"] in ilanlar:
        hata(f"zaten geçersiz ilan edilmiş: {h['dosya']} — {ilanlar[h['dosya']].get('neden')}")
    karsi = None
    if a.karsi:
        kk = coz(a.karsi, "karşı kanıt")
        if kk["dosya"] == h["dosya"]:
            hata("karşı kanıt hedefin kendisi olamaz")
        if kk["dosya"] in ilanlar:
            hata(f"karşı kanıt da geçersiz ilan edilmiş: {kk['dosya']}")
        karsi = kk["dosya"]
    iz = hashlib.sha256(f"{h.get('olcum_id')}|{h.get('sha256')}|{h.get('zaman')}".encode()).hexdigest()[:12]
    ad = f"gecersiz-{os.path.splitext(h['dosya'])[0]}-{iz}.txt"
    zaman = simdi(); yol = os.path.join(dz, ad)
    with open(yol, "w", encoding="utf-8") as f:
        f.write(f"# GEÇERSİZ İLANI — özgün kayda dokunulmadı\nhedef: {h['dosya']}\nhedef_sha256: {h.get('sha256')}\n"
                f"hedef_zaman: {h.get('zaman')}\nhedef_renk: {h.get('renk')}\nneden: {neden}\nkim: {kim}\nkarsi: {karsi or '-'}\nzaman: {zaman}\n")
    kayit = {"tur": "gecersiz", "etiket": h.get("etiket"), "asama": "tek", "dosya": ad, "sha256": sha_dosya(yol),
             "hedef_dosya": h["dosya"], "hedef_olcum_id": h.get("olcum_id"), "hedef_sha256": h.get("sha256"), "hedef_zaman": h.get("zaman"), "hedef_renk": h.get("renk"),
             "neden": neden, "kim": kim, "karsi": karsi, "rc": 0, "renk": "ilan", "zaman": zaman}
    kayit_ekle(depo, a.is_adi, kayit)
    print(f"⛔ geçersiz ilan edildi: {h['dosya']} ({h.get('renk')} → gecersiz) · {kim} · {neden}" + (f" · karşı kanıt: {karsi}" if karsi else ""))


# ── dogrula ──────────────────────────────────────────────────────────────────────
def cmd_dogrula(a):
    depo = depo_kok(a.depo); dz = kanit_dizin(depo, a.is_adi)
    m = manifest_oku(dz)
    if not m:
        print(f"◻ {dz}/KANIT.json YOK — kanıt yok (ölçülemedi)"); sys.exit(3)
    rc = 0
    tutuyor, bicim = imza_tutuyor_mu(m)
    if m.get("arac") != SURUM:
        # 🔴 BİLGİ satırı — HÜKÜM DEĞİL. Eski araçla yazılmış kanıt, elle değişmediği sürece
        #    SAĞLAMDIR. Bu satır rc'ye dokunmaz; dokunsaydı araç güncellemesi geçmişi suçlardı.
        print(f"· eski araçla yazılmış: {m.get('arac')} (bu: {SURUM}) — sağlamlığı etkilemez")
    if not tutuyor:
        print("✗ İMZA TUTMUYOR — manifest elle değişmiş ya da araç dışında yazılmış"); rc = 1
    elif bicim == "eski":
        print(f"· imza eski biçimde (sürüm gövdede) ve TUTUYOR — ilk yazımda yeni biçime geçer")
    sari = 0; ek = etkin_kayitlar(m)
    for k in ek:
        if k["etkin_renk"] == "sari": sari += 1
        if k.get("sha256"):
            y = os.path.join(dz, k["dosya"])
            if not os.path.exists(y):
                print(f"✗ dosya yok: {k['dosya']}"); rc = 1
            elif sha_dosya(y) != k["sha256"]:
                print(f"✗ sha TUTMUYOR: {k['dosya']}"); rc = 1
    canli = [k for k in ek if k.get("tur") == "canli"]
    if canli:
        cy = sum(1 for k in canli if k["etkin_renk"] == "yesil"); cg = sum(1 for k in canli if k["etkin_renk"] == "gecersiz"); cs = len(canli) - cy - cg
        print(f"· canlı kayıt: {cy} yeşil (ateşleme var) · {cs} sarı (ateşleme yok — kapı geçirmez)"
              + (f" · {cg} geçersiz ilan edilmiş (kapı geçirmez)" if cg else ""))
    gec = [k for k in ek if k["etkin_renk"] == "gecersiz"]
    for k in gec:
        print(f"⛔ GEÇERSİZ: {k['dosya']} ({k.get('renk')} → gecersiz) — {k.get('gecersiz_neden')} · {k.get('gecersiz_kim')}"
              + (f" · karşı kanıt: {k['gecersiz_karsi']}" if k.get("gecersiz_karsi") else ""))
    for k in ek:
        if k.get("tur") == "gecersiz" and not k.get("uygulaniyor"):
            print(f"· ilan artık uygulanmıyor: {k.get('hedef_dosya')} yeniden ölçüldü ya da yok (ilan eski ölçüme aitti)")
    n = len(ek)
    if rc == 0:
        print(f"✓ manifest sağlam: {n} kayıt, imza ve sha'lar tutuyor" + (f" · ⚠ {sari} SARI kayıt (ölçülemedi)" if sari else "")
              + (f" · ⛔ {len(gec)} kayıt GEÇERSİZ ilan edildi (kanıt sayılmaz)" if gec else ""))
    if n == 0:
        print("◻ kayıt yok — kanıt yok"); sys.exit(3)
    sys.exit(rc)


def cmd_ozet(a):
    depo = depo_kok(a.depo); dz = kanit_dizin(depo, a.is_adi); m = manifest_oku(dz)
    if not m: print("_kanıt yok_"); sys.exit(3)
    print(f"| # | tür | etiket | aşama | renk | rc | dosya |\n|---|---|---|---|---|---|---|")
    for i, k in enumerate(etkin_kayitlar(m), 1):
        renk = k["etkin_renk"]
        if renk == "gecersiz":
            renk = f"**GEÇERSİZ** (ölçülen: {k.get('renk')}): {k.get('gecersiz_neden')}"
        elif renk == "ilan":
            renk = f"ilan → `{k.get('hedef_dosya')}`" + ("" if k.get("uygulaniyor") else " (uygulanmıyor: yeniden ölçüldü)")
        print(f"| {i} | {k['tur']} | {k['etiket']} | {k.get('asama','')} | {renk} | {k.get('rc','')} | `{k['dosya']}` |")
    print(f"\nimza `{m['imza'][:16]}` · araç {m['arac']} · dizin `{os.path.relpath(dz, depo)}`")


def cmd_liste(a):
    if not a.etkin:
        return cmd_ozet(a)
    m = manifest_oku(kanit_dizin(depo_kok(a.depo), a.is_adi))
    if not m: print("[]"); sys.exit(3)
    print(json.dumps(etkin_kayitlar(m), ensure_ascii=False, indent=2))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--depo")
    s = p.add_subparsers(dest="cmd", required=True)
    o = s.add_parser("olcum"); o.add_argument("is_adi"); o.add_argument("etiket"); o.add_argument("--asama", default="sonra", choices=["once", "sonra", "tek"]); o.add_argument("--boru-izin", dest="boru_izin", default=None); o.set_defaults(f=cmd_olcum)
    e = s.add_parser("ekran"); e.add_argument("is_adi"); e.add_argument("etiket"); e.add_argument("--asama", default="sonra", choices=["once", "sonra", "tek"]); e.add_argument("--url", required=True); e.add_argument("--urun-imi"); e.add_argument("--bekle"); e.add_argument("--genislik", type=int, default=1280); e.set_defaults(f=cmd_ekran)
    d = s.add_parser("dosya"); d.add_argument("is_adi"); d.add_argument("etiket"); d.add_argument("yol"); d.add_argument("--asama", default="tek"); d.set_defaults(f=cmd_dosya)
    c = s.add_parser("canli"); c.add_argument("is_adi"); c.add_argument("etiket"); c.add_argument("--kaynak", required=True); c.add_argument("--desen", required=True); c.add_argument("--en-az", dest="en_az", type=int, default=1); c.add_argument("--son", type=int, default=2000); c.set_defaults(f=cmd_canli)
    v = s.add_parser("gecersiz"); v.add_argument("is_adi"); v.add_argument("hedef"); v.add_argument("--neden", required=True); v.add_argument("--kim", required=True); v.add_argument("--karsi"); v.set_defaults(f=cmd_gecersiz)
    for ad, f in (("dogrula", cmd_dogrula), ("ozet", cmd_ozet), ("liste", cmd_liste)):
        x = s.add_parser(ad); x.add_argument("is_adi"); x.set_defaults(f=f)
        if ad == "liste": x.add_argument("--etkin", action="store_true")
    # `--` sonrası KOMUTTUR: argparse'a hiç gösterilmez (REMAINDER, seçenekleri de yutuyordu).
    argv = sys.argv[1:]; komut = []
    if "--" in argv:
        i = argv.index("--"); komut = argv[i + 1:]; argv = argv[:i]
    a = p.parse_args(argv); a.komut = komut
    a.f(a)


if __name__ == "__main__":
    main()
