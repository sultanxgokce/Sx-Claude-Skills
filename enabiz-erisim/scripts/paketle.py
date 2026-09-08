"""Her çalışma klasörü → <ad>.zip (tüm JPEG) + <ad>_ozet.png (kontakt tablo) → paket/"""
import os, sys, json, zipfile, glob, math
from PIL import Image, ImageDraw, ImageFont
S=os.path.dirname(os.path.abspath(__file__)); G=S+"/goruntu"; P=S+"/paket"; os.makedirs(P, exist_ok=True)
font=ImageFont.truetype("/config/.local/share/fonts/DejaVuSerif.ttf", 22)
sonuc=[]
for sdir in sorted(d for d in glob.glob(G+"/*") if os.path.isdir(d)):
    ad=os.path.basename(sdir); jpgs=sorted(glob.glob(sdir+"/*/*.jpg"))
    if not jpgs: continue
    meta=json.load(open(sdir+".json"))
    zp=f"{P}/{ad}.zip"
    if not os.path.exists(zp):
        with zipfile.ZipFile(zp,"w",zipfile.ZIP_STORED) as z:
            for j in jpgs: z.write(j, os.path.relpath(j, sdir))
            z.write(sdir+".json","_calisma.json")
    # kontakt tablo: her seriden orta kare (en fazla 20 seri), 4 sütun
    seriler=sorted({os.path.dirname(j) for j in jpgs}); orn=[]
    for se in seriler[:20]:
        fs=sorted(glob.glob(se+"/*.jpg")); orn.append((fs[len(fs)//2], os.path.basename(se), len(fs)))
    if len(orn)<4:  # az seri → o serilerden birden çok kare
        fs=sorted(jpgs); adim=max(1,len(fs)//8); orn=[(f, os.path.basename(os.path.dirname(f)), len(fs)) for f in fs[::adim]][:8]
    col=4 if len(orn)>4 else max(1,len(orn)); row=math.ceil(len(orn)/col); W=320; H=320; hdr=70
    sheet=Image.new("RGB",(col*W, hdr+row*(H+34)),"black"); dr=ImageDraw.Draw(sheet)
    dr.text((10,8), f"{meta['StudyDate'][:10]}  {meta.get('ModalitiesInStudy') or ''}  {meta['HospitalName'][:40]}", fill="white", font=font)
    dr.text((10,38), f"Acc {meta['AccessionNumber']} · {len(seriler)} seri · {len(jpgs)} kare · tam set: ZIP", fill=(200,200,200), font=font)
    for i,(f,sname,n) in enumerate(orn):
        try:
            im=Image.open(f).convert("RGB"); im.thumbnail((W-8,H-8)); x=(i%col)*W+4; y=hdr+(i//col)*(H+34)+4
            sheet.paste(im,(x+(W-8-im.width)//2, y+(H-8-im.height)//2)); dr.text((x, y+H-2), f"{sname[:26]} ({n})", fill=(180,180,180), font=ImageFont.truetype("/config/.local/share/fonts/DejaVuSerif.ttf", 15))
        except Exception as e: print("kare hata", f, e)
    pp=f"{P}/{ad}_ozet.png"; sheet.save(pp, optimize=True)
    sonuc.append({"ad":ad,"tarih":meta["StudyDate"][:10],"mod":meta.get("ModalitiesInStudy"),"hastane":meta["HospitalName"],"acc":meta["AccessionNumber"],"seri":len(seriler),"kare":len(jpgs),"zip":zp,"zip_boyut":os.path.getsize(zp),"png":pp,"png_boyut":os.path.getsize(pp),"aciklamalar":[se.get("Description") for se in meta["Series"]][:6]})
    print(ad, "| kare", len(jpgs), "| zip", os.path.getsize(zp)//1024, "KB | png", os.path.getsize(pp)//1024, "KB")
json.dump(sonuc, open(P+"/paket.json","w"), ensure_ascii=False, indent=1)
