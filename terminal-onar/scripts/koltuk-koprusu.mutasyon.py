import subprocess, sys, os, tempfile
kaynak = open("koltuk-koprusu.py").read()
M = [
 ("M1 uid kapısı yok", "if uid not in izinli_uidler():", "if False:"),
 ("M2 izin listesi kapısı yok", "if ad not in iz:", "if False:"),
 ("M3 attach salt-okur değil", '"attach-session", "-r", ', '"attach-session", '),
 ("M4 ad süzgeci yok", "if not isinstance(ad, str) or not KOLTUK_DESEN.match(ad):", "if False:"),
 ("M5 sunulmayan şık geçer", "if no not in sunulan:", "if False:"),
 ("M6 soru yokken şık geçer", 'k.get("hal") != "soru" or ', "False or "),
 ("M7 denetim karakteri süzülmez", "    m = m.replace(\"\\r\\n\"", "    return m.strip()\n    m = m.replace(\"\\r\\n\""),
 ("M8 uzunluk tavanı yok", "len(metin) > METIN_TAVAN", "len(metin) > 10**9"),
 ("M9 ham tuş eylemi eklendi", 'elif op == "mesaj":', 'elif op == "tus":\n            subprocess.run([ortam("KOPRU_TMUX","tmux"),"send-keys","-t","="+str(self.koltuk)+":",str(o.get("tus"))])\n        elif op == "mesaj":'),
 ("M10 iz mesaj metnini taşır", "uzunluk=len(metin),", "uzunluk=len(metin), metin=metin,"),
 ("M11 soket kipi gevşek", "os.umask(0o117)", "os.umask(0o000)"),
 ("M12 izleme oturumsuz mesaj", 'if not self.koltuk:\n            return self.ret("once-izle", "mesaj")', "pass"),
 ("M13 sık mesaj sınırı yok", "if simdi - self.son_mesaj < MESAJ_ARALIK:", "if False:"),
 ("M14 boş liste = izin", "if iz is None:\n            return self.ret(\"koltuklar-olculemedi\", \"izle\")", "iz = iz or {}"),
 ("M15 iz kayıtsız", "def iz_yaz(**alanlar):\n    yol = ortam(\"KOPRU_IZ\")", "def iz_yaz(**alanlar):\n    return\n    yol = ortam(\"KOPRU_IZ\")"),
]
kacan = 0
for ad, eski, yeni in M:
    if eski not in kaynak:
        print("✗ MUTANT UYGULANAMADI:", ad); kacan += 1; continue
    d = tempfile.mkdtemp(); y = d + "/m.py"; open(y, "w").write(kaynak.replace(eski, yeni, 1))
    p = subprocess.run([sys.executable, "koltuk-koprusu.test.py"], env=dict(os.environ, KOPRU=y), capture_output=True, text=True, timeout=170)
    oldu = p.returncode != 0
    print(("✓ yakalandı  " if oldu else "✗ KAÇTI      ") + ad)
    kacan += 0 if oldu else 1
print("kaçan/uygulanamayan:", kacan); sys.exit(1 if kacan else 0)
