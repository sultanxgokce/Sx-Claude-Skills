#!/usr/bin/env python3
"""Gömülebilir, karakter alt kümeli yazı tipi CSS'i üretir (fonttools gerekmez; Google Fonts'un text= parametresi).
Kullanım:  font-altkume.py "Archivo:wght@400;600" cikti.css [--degisken] [--ek "ekstra karakterler"]
  --degisken : modern tarayıcı kimliği → tek değişken woff2 (eksenler kalır, dosya büyür)
  varsayılan : eski tarayıcı kimliği → ağırlık başına sabit woff (en küçük paket)
Ölçüldü (AKAR): Archivo 400+600 + Literata 300 = 57 KB; değişken hâli 194 KB."""
import sys,re,base64,urllib.request,urllib.parse
# Argümansız çağrı ESKİDEN yığın izi basıyordu (IndexError) — kullanım hatası araç arızası gibi
# görünüyordu. Artık düz ileti + rc=2 (MUAVİN, 2026-09-17 paketleme).
if len(sys.argv) < 3:
    print('kullanım: font-altkume.py "Archivo:wght@400;600" cikti.css [--degisken] [--ek "ekstra karakterler"]\n'
          '  ağ gerektirir (Google Fonts); çıkış: 0 yazıldı · 1 kaynak/ağ hatası · 2 kullanım', file=sys.stderr)
    sys.exit(2)
aile,cikti=sys.argv[1],sys.argv[2]; degisken='--degisken' in sys.argv
ek=sys.argv[sys.argv.index('--ek')+1] if '--ek' in sys.argv else ''
metin=''.join(chr(c) for c in range(0x20,0x7f))+'çğıöşüÇĞİÖŞÜâîûÂÎÛ₺€’‘“”–—…·×°‰§«»→↓↑←•'+ek
UA=('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36' if degisken
    else 'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/40.0.2214.85 Safari/537.36')
al=lambda u:urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':UA}),timeout=40).read()
try: css=al('https://fonts.googleapis.com/css2?family='+aile.replace(' ','+')+'&display=swap&text='+urllib.parse.quote(metin)).decode()
except Exception as e: sys.exit('HATA: Google Fonts isteği düştü (%s) — aile adını ve eksenleri denetle: %s'%(e,aile))
bloklar=re.findall(r'@font-face \{.*?\}',css,re.S); toplam=0; out=[]
if not bloklar: sys.exit('HATA: @font-face bloğu dönmedi — aile adını ve eksenleri denetle')
for b in bloklar:
    url=re.search(r'url\((https[^)]+)\)',b).group(1); bic=re.search(r"format\('([^']+)'\)",b).group(1)
    d=al(url); toplam+=len(d); out.append(b.replace(url,'data:font/%s;base64,%s'%(bic,base64.b64encode(d).decode())))
open(cikti,'w').write('\n'.join(out)); print('%s: %d yüz · %d bayt ham · %d bayt gömülü'%(cikti,len(bloklar),toplam,len('\n'.join(out))))
