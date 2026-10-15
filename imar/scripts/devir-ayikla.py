#!/usr/bin/env python3
"""devir-ayikla — bir turun çıktısındaki DEVİR bölümünü KİŞİ KATMANINA taşır.

NİÇİN VAR (ölçüldü, 2 Ekim 2026): MÜNECCİM'in ilk insansız turu üç ders ve bir kuyruk yazdı
— ama hepsi günlük dosyasının İÇİNDE kaldı. Ders defteri ve kuyruk boştu. Yani ertesi turun
okuyacağı yere hiçbir şey düşmedi: deneyim birikmedi, yalnız arşiv büyüdü.

Ajana "dosyaya da yaz" demek çözüm DEĞİL — bu evde gönüllü bırakılan her adım ölçüldü ve
yapılmadı. Taşımayı MAKİNE yapar.

Kullanım:
  python3 scripts/devir-ayikla.py <tur-ciktisi.md> [--ev <muneccim-evi>] [--kuru]

Çıkış: 0 taşındı · 2 kullanım · 3 ÖLÇÜLEMEDİ (dosya yok) · 1 DEVİR YOK (tur YARIM)
"""
import os, re, sys, datetime

def oku(y):
    with open(y, encoding="utf-8") as f: return f.read()

def main():
    args = sys.argv[1:]
    if not args or args[0].startswith("-"):
        print(__doc__); return 2
    tur = args[0]; kuru = "--kuru" in args
    ev = os.environ.get("MUNECCIM_EV", "")
    if "--ev" in args: ev = args[args.index("--ev") + 1]
    seri = os.path.join(ev, "arastirma-serisi")
    dersler_y = os.path.join(seri, "DERSLER.md")
    kuyruk_y = os.path.join(seri, "KUYRUK.md")
    if not os.path.isfile(tur): print("ÖLÇÜLEMEDİ: tur çıktısı yok: %s" % tur, file=sys.stderr); return 3
    if not os.path.isdir(seri): print("ÖLÇÜLEMEDİ: seri klasörü yok: %s" % seri, file=sys.stderr); return 3

    metin = oku(tur)
    # başlık yazımı turdan tura kayıyor (ölçüldü 3 Ekim): "## DEVİR" · "## 4 · DEVİR" · "### DEVİR"
    m = re.search(r"^#{1,4}\s*(?:\d+\s*[·.)\-]\s*)?DEV[İI]R[^\n]*$(.*)", metin, re.M | re.S)
    if m: devir = m.group(1)
    else:
        # 🔴 BİÇİM BEŞİNCİ KEZ KAYDI (ölçüldü 12 Ekim): tur dört bölümü de yazdı ("## Ne yaptım / ## Dersler /
        # ## Şu an neredeyim / ## Sıradaki tura kuyruk") ama "# DEVİR" üst başlığı koymadı — şablon zaten onu
        # istemiyor, araç istiyordu. Araç "DEVİR yazmadı" diye SUÇLADI; yanlıştı. Artık sözleşme İÇERİKTİR:
        # dört bölümden ilki ("Ne yaptım") ya da "Dersler" başlığı varsa devir oradan başlar.
        m2 = re.search(r"^#{1,4}\s*(?:\d+\s*[·.)\-]\s*)?(?:Ne yaptım|Dersler)\b[^\n]*$", metin, re.M | re.I)
        if not m2:
            print("DEVİR YOK → tur YARIM sayılır (ne DEVİR başlığı ne 'Ne yaptım/Dersler' bölümü var)", file=sys.stderr)
            return 1
        devir = metin[m2.start():]
        print("not: DEVİR üst başlığı yok, dört-bölüm içeriğinden okundu (biçim kayması, içerik tam)")

    # ——— dersler: "1. **başlık**" ile başlayan bloklar, "- **Alan:**" satırlarıyla
    bolum = re.search(
        r"(?:^#{1,4}\s*(?:\d+\s*[·.)\-]\s*)?|\*\*)Dersler[^\n]*?\**\s*$(.*?)(?=^#{1,4}\s*(?:\d+\s*[·.)\-]\s*)?[ŞS]u an|^\*\*[ŞS]u an|^#{1,4}\s*(?:\d+\s*[·.)\-]\s*)?Sıradaki|^\*\*Sıradaki|\Z)",
        devir, re.S | re.M)
    dersler = []
    if bolum:
        # ders başı iki yazımdan biri: "1. **başlık**"  ya da  "**D-004 · başlık**"
        # 🔴 BİÇİM DÖRDÜNCÜ KEZ KAYDI (ölçüldü 11 Ekim): 10 ve 11 Ekim turları dersi "### D-022 · …"
        # markdown başlığıyla yazdı; kapı yalnız iki yazımı tanıyordu → "taşındı: 0 ders" dedi ve
        # SUSTU. İki günün altı dersi deftere girmedi, ikinci göz damga basacak satır bulamadı.
        for blok in re.split(r"\n(?=(?:\d+\.\s|\*\*D-\d+|#{1,4}\s*D-\d+))", bolum.group(1)):
            blok = blok.strip()
            if not blok or not re.match(r"^(?:\d+\.|\*\*D-\d+|#{1,4}\s*D-\d+)", blok): continue
            baslik = blok.split("\n")[0]
            baslik = re.sub(r"^#{1,4}\s*", "", baslik)
            baslik = re.sub(r"^\d+\.\s*", "", baslik).strip().strip("*").strip()
            vm = re.match(r"^D-(\d+)\s*·\s*", baslik)
            verilen_no = int(vm.group(1)) if vm else None   # ajan kendi numarasını verdiyse KORUNUR (göz o numarayla hüküm verir)
            baslik = re.sub(r"^D-\d+\s*·\s*", "", baslik)
            def alan(ad):
                # 🔴 BİÇİM ÜÇÜNCÜ KEZ KAYDI (ölçüldü 6 Ekim): ajan "- KANIT:" yazdı, kapı
                # yalnız "**Kanıt:**" tanıyordu ve deftere "YAZILMAMIŞ" diye kaydetti —
                # yani masum olanı suçladı ve kanıtı kaybetti. Artık kalın/düz/BÜYÜK harf,
                # Türkçe'li ve Türkçe'siz yazım, iki nokta olan/olmayan hepsi tanınır.
                ad_d = ad.replace("İ","i").replace("ı","i").replace("ü","u").replace("ö","o").replace("ş","s").replace("ç","c").replace("ğ","g")
                desen = r"(?:^|\n)\s*[-*]?\s*\**\s*(?:%s|%s)\s*:?\s*\**\s*:?\s*(.+?)(?=\n\s*[-*]\s|\n\s*\n|\Z)"
                a = re.search(desen % (re.escape(ad), re.escape(ad_d)), blok, re.S | re.I)
                return " ".join(a.group(1).split()) if a else None
            curur = alan("Ne olursa çürür") or alan("NE OLURSA ÇÜRÜR")
            # bilinmeyen ≠ yok: blokta "çürür" geçiyorsa ama okunamadıysa ayrı söylenir
            izi = bool(re.search(r"[çc][üu]r[üu]r", blok, re.I)) and not curur
            dersler.append({"baslik": baslik, "iddia": alan("İddia") or baslik,
                            "kanit": alan("Kanıt") or alan("KANIT"),
                            "curur": curur, "curur_izi": izi, "verilen_no": verilen_no})
        # ——— SESSİZ SIFIR YASAK: bölümde ders başlığı görünüyor ama hiçbiri okunamadıysa bu kayıptır
        aday = len(re.findall(r"(?m)^\s*(?:#{1,4}\s*|\*\*)?D-\d+|^\s*\d+\.\s+\*\*", bolum.group(1)))
        if aday and not dersler:
            print("⚠ DERS KAYBI: devirde %d ders başlığı var, ayıklayıcı HİÇBİRİNİ okuyamadı (biçim kaydı) — tur YARIM" % aday)
            return 2
    elif re.search(r"(?m)^\s*(?:#{1,4}\s*|\*\*)?D-\d{3}", devir):
        print("⚠ DERS KAYBI: devirde D-numaralı ders var ama 'Dersler' bölümü bulunamadı (biçim kaydı) — tur YARIM")
        return 2
    # ——— kuyruk
    k = re.search(r"(?:^#{1,4}\s*(?:\d+\s*[·.)\-]\s*)?|\*\*)Sıradaki tura kuyruk:?\**\s*\n?(.+?)(?=\n#{1,4}\s|\n\*\*|\Z)",
                  devir, re.S | re.M)
    kuyruk = " ".join(k.group(1).split()) if k else None
    # ——— kutu eksiği: insansız tur "bu kutuda şu araç yok" yazdığında o cümle HİÇBİR YERE gitmiyordu
    # (ölçüldü 8 Ekim: iki tur "SERDAR isteği açık" yazdı, giden/'de mektup YOKTU — tur mektup yazamaz).
    # Artık cümle ayrı deftere düşer ve stdout'a basılır (ÇARK kütüğü yakalar); kapatmak insanın işi.
    ke = re.search(r"Kutu eksiği:?\**:?\s*([^\n]+)", devir)   # "**Kutu eksiği:** …" yazımında kalın işareti sızmasın (ölçüldü 12 Ekim)
    kutu_eksigi = " ".join(ke.group(1).split()).strip("* ") if ke else None

    bugun = datetime.date.today().isoformat()
    kaynak = os.path.basename(tur)

    # ——— aynı tur iki kez taşınmasın (cron tekrar koşarsa dersler çoğalırdı) ———
    if os.path.isfile(dersler_y) and ("kaynak tur: " + kaynak) in oku(dersler_y):
        print("zaten taşınmış: %s (ders defterinde kayıtlı) — bir şey yapılmadı" % kaynak)
        return 0

    # ——— mevcut en büyük ders numarası
    mevcut = oku(dersler_y) if os.path.isfile(dersler_y) else ""
    nolar = [int(x) for x in re.findall(r"^### D-(\d+)", mevcut, re.M)]
    sonraki = max(nolar) + 1 if nolar else 1

    satirlar = []; kullanilan = set(nolar); ilk_no = None
    for i, d in enumerate(dersler):
        no = d.get("verilen_no")
        if not no or no in kullanilan:
            no = sonraki
            while no in kullanilan: no += 1
        kullanilan.add(no); sonraki = max(sonraki, no + 1)
        if ilk_no is None: ilk_no = no
        d["no"] = no
        satirlar.append(
            "\n### D-%03d · %s\n- **Kanıt:** %s\n- **Ne olursa çürür:** %s\n- **Son doğrulama:** %s · **atıf:** 0\n- *(kaynak tur: %s%s)*\n"
            % (no, d["iddia"] or d["baslik"], d["kanit"] or "—",
               d["curur"] or ("⚠ ÇÜRÜTME ŞARTI OKUNAMADI — blokta benzer satır var, ayıklayıcı tanımadı"
                              if d.get("curur_izi") else "⚠ ÇÜRÜTME ŞARTI YAZILMAMIŞ — ders eksik"),
               bugun, kaynak, "" if d["curur"] else (" · OKUNAMADI" if d.get("curur_izi") else " · EKSİK")))

    if kuru:
        print("KURU: %d ders · kuyruk %s · ilk no D-%03d"
              % (len(dersler), "VAR" if kuyruk else "YOK", ilk_no or sonraki))
        for d in dersler: print("  - " + (d["iddia"] or d["baslik"])[:90])
        return 0

    if satirlar:
        with open(dersler_y, "a", encoding="utf-8") as f: f.write("".join(satirlar))
    if kuyruk:
        # 🔴 ÖNCEKİ KUSUR (ölçüldü 5 Ekim): yeni kuyruk yazılırken eskisi SİLİNİYORDU.
        # "Kapanan" bölümü dört tur boyunca boş kaldı — yani hangi işin kuyruğa girip
        # çıktığının izi yok oluyordu. Kuyruk bir defterdir; defterden satır silinmez,
        # taşınır. Artık: açık satırlar Kapanan'a taşınır, yenisi Açık'a yazılır.
        mevcut_k = oku(kuyruk_y) if os.path.isfile(kuyruk_y) else "# KUYRUK\n\n## Açık\n\n## Kapanan\n"
        m_acik = re.search(r"## Açık\n(.*?)(?=\n## Kapanan)", mevcut_k, re.S)
        eskiler = []
        if m_acik:
            for satir in m_acik.group(1).strip().splitlines():
                satir = satir.strip()
                if satir.startswith("- [") and "(boş" not in satir:
                    eskiler.append(satir + "  _(kapandı: %s · yerine yeni kuyruk yazıldı)_" % bugun)
        yeni_k = re.sub(r"## Açık\n.*?(?=\n## Kapanan)",
                        "## Açık\n- [%s] %s\n" % (bugun, kuyruk), mevcut_k, count=1, flags=re.S)
        if eskiler:
            yeni_k = re.sub(r"(## Kapanan\n)", lambda mm: mm.group(1) + "\n".join(eskiler) + "\n",
                            yeni_k, count=1)
        with open(kuyruk_y, "w", encoding="utf-8") as f: f.write(yeni_k)

    if kutu_eksigi:
        # 🔴 DEFTER KUTUNUN VERİSİDİR, BECERİNİN DEĞİL (İMAR filo becerisi, 15 Eki).
        #    Eski satır yolu BETİĞİN KENDİ KONUMUNDAN türetiyordu. Bu, araç tek bir kutunun
        #    deposunda yaşarken doğruydu; filo becerisi olarak kurulduğunda beceri dizini BÜTÜN
        #    kutularda ORTAKTIR → bir kutunun eksikleri ötekinin defterine düşerdi (sızıntı), ya da
        #    dizin yoksa araç çökerdi. Yol artık profilden gelir; hiçbiri yoksa bulgu KAYBEDİLMEZ,
        #    ekrana basılır ve tur ÖLÇÜLEMEDİ sayılır (sessizce beceri dizinine yazmaktan iyidir).
        ke_y = os.environ.get("KUTU_EKSIGI_DEFTER")
        if not ke_y:
            repo = os.environ.get("IMAR_REPO", "").strip()
            if repo:
                ke_y = os.path.join(repo, "hafiza", "kutu-eksikleri.md")
        if not ke_y:
            print("⚠ KUTU EKSİĞİ yazılamadı (IMAR_REPO ya da KUTU_EKSIGI_DEFTER yok) — "
                  "bulgu KAYBOLMASIN diye burada: %s" % kutu_eksigi, file=sys.stderr)
            print("ÖLÇÜLEMEDİ: kutu eksikleri defterinin yeri bildirilmedi", file=sys.stderr)
            return 3
        os.makedirs(os.path.dirname(ke_y), exist_ok=True)
        baslik = "# Kutu eksikleri — insansız turların 'bu kutuda yok' dedikleri\n\n> Yazan: devir-ayikla.py (tur DEVİR'indeki `Kutu eksiği:` satırı). Kapatan: insan; satırın altına `  → çözüldü <tarih>: …` yazar.\n\n"
        mevcut = oku(ke_y) if os.path.isfile(ke_y) else ""
        if kutu_eksigi not in mevcut:
            with open(ke_y, "a", encoding="utf-8") as f:
                if not mevcut: f.write(baslik)
                f.write("- [%s · %s] %s\n" % (bugun, kaynak, kutu_eksigi))
            print("⚠ KUTU EKSİĞİ deftere düştü: %s" % kutu_eksigi[:120])
        else:
            print("⚠ kutu eksiği (tekrar, defterde var): %s" % kutu_eksigi[:80])
    eksik = sum(1 for d in dersler if not d["curur"])
    print("✓ taşındı: %d ders (D-%03d…) · kuyruk: %s%s"
          % (len(dersler), ilk_no or sonraki, "yazıldı" if kuyruk else "YOK",
             " · ⚠ %d derste çürütme şartı eksik" % eksik if eksik else ""))
    return 0

sys.exit(main())
