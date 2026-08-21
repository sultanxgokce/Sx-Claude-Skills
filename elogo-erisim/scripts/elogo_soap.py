#!/usr/bin/env python3
"""
elogo_soap.py — e-Logo PostBox SOAP taşıma katmanı (zeep'siz, curl/urllib'siz saf HTTP).

NİÇİN ZEEP DEĞİL
----------------
Kardeş modül `elogo_ws.py` zeep kullanır ve üretimde çalışır. Bu modül zeep'e BAĞLI DEĞİL:
zeep her kutuda kurulu değil (ölçüldü 2026-08-21: merkez kutuda `ModuleNotFoundError`) ve
WSDL'i her çağrıda indirmek hem yavaş hem kırılgandır. Buradaki zarflar elle kurulur;
şema WSDL'den değil, **çalışan üretim kodumuzdan** doğrulanmıştır.

🔴 ÜÇ DEĞİŞMEZ — üçü de acıyla ölçüldü (2026-08-21), silmeden önce oku
---------------------------------------------------------------------
1. **AD-ALANI:** `Login`/`login` sarmalı `tempuri.org`'dadır ama **alt alanlar**
   `http://schemas.datacontract.org/2004/07/eFaturaWebService`'tedir. Alt alanları
   tempuri ile yazarsan sunucu `userName`/`passWord`'ü **hiç görmez** ve sana
   *"Hatalı kullanıcı adı veya şifre"* der — yani seni kimlik avına yollar.
   İki başarısız giriş bu yüzden yaşandı; şifre baştan beri doğruydu.
2. **ALAN SIRASI ALFABETİK:** DataContract serileştirmesi sıra bekler:
   `appStr · passWord · source · userName · version`.
3. **BOT ENGELİ:** uç Cloudflare arkasındadır. Varsayılan Python User-Agent'ı ile
   **http=403 · "error code: 1010"** döner (kimlik doğru olsa bile). Tarayıcı-benzeri
   `User-Agent` ZORUNLUDUR. Bu bir incelik değil, çalışma şartıdır.

🔴 SIR: parola stdout/log'a ASLA basılmaz. Kimlik ortamdan okunur
   (`ELOGO_*_WS_USER` / `..._WS_PASSWORD` / `..._WS_WSDL`), argv'ye geçmez.

🔴 KUYRUK GÜVENLİĞİ: burada `GetDocument`/`receiveInvoiceDone` gibi **gelen kuyruğu
   tüketen** çağrı YOKTUR — kardeş modülün yasağı burada da geçerlidir.
"""
from __future__ import annotations

import os
import re
import urllib.error
import urllib.request
import xml.sax.saxutils as sx

TEMPURI = "http://tempuri.org/"
DATA_NS = "http://schemas.datacontract.org/2004/07/eFaturaWebService"

#: Bot engelini aşan tarayıcı imzası — Değişmez 3.
UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
      "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36")

#: Login alanları — DataContract alfabetik sırası (Değişmez 2). Üretim kodumuz
#: appStr/source/version'ı BOŞ yollar; doldurmak reddedilmeye yol açıyor.
LOGIN_ALANLARI = ("appStr", "passWord", "source", "userName", "version")


class ELogoHata(RuntimeError):
    """Uç bir SOAP fault döndürdü ya da yanıt beklenen şekli taşımıyor."""


def _cagir(url: str, islem: str, govde: str, zaman_asimi: int = 45) -> str:
    """Tek bir SOAP çağrısı yapar, ham XML yanıtı döndürür.

    Hata durumunda gövdeyi YUTMAZ: fault metnini `ELogoHata` içinde taşır ki
    çağıran "bir şey oldu" değil, **ne olduğunu** görsün.
    """
    zarf = (
        '<?xml version="1.0" encoding="utf-8"?>'
        f'<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"'
        f' xmlns:t="{TEMPURI}" xmlns:d="{DATA_NS}">'
        f"<s:Body>{govde}</s:Body></s:Envelope>"
    )
    istek = urllib.request.Request(
        url,
        data=zarf.encode("utf-8"),
        headers={
            "Content-Type": "text/xml; charset=utf-8",
            "SOAPAction": f"{TEMPURI}IPostBoxService/{islem}",
            "User-Agent": UA,          # ← Değişmez 3; kaldırma
        },
    )
    try:
        with urllib.request.urlopen(istek, timeout=zaman_asimi) as y:
            return y.read().decode("utf-8", "ignore")
    except urllib.error.HTTPError as e:
        ham = e.read().decode("utf-8", "ignore")
        if e.code == 403 and "1010" in ham:
            raise ELogoHata(
                "403 · Cloudflare bot engeli (error code 1010) — User-Agent başlığı "
                "tarayıcı-benzeri olmalı. Bu bir kimlik hatası DEĞİLDİR."
            ) from None
        fault = re.search(r"<(?:\w+:)?(?:faultstring|Message)[^>]*>([^<]{0,300})<", ham)
        raise ELogoHata(f"http={e.code} · {fault.group(1) if fault else ham[:200]}") from None


def _alan(xml: str, ad: str) -> str | None:
    m = re.search(rf"<(?:\w+:)?{ad}>([^<]*)</(?:\w+:)?{ad}>", xml)
    return m.group(1) if m else None


def kimlik_env(onek: str = "ELOGO_DEMO") -> tuple[str, str, str]:
    """Ortamdan (kullanıcı, parola, uç-adresi) okur. Değer döndürür ama BASMAZ.

    `onek` ile ortam seçilir: `ELOGO_DEMO` (test) ⟂ `ELOGO` (canlı). Ortamı
    çağıranın AÇIKÇA seçmesi bilinçlidir — varsayılanı canlı yapmak, bir gün
    birinin yanlışlıkla gerçek fatura kesmesi demektir.
    """
    eksik = [k for k in (f"{onek}_WS_USER", f"{onek}_WS_PASSWORD", f"{onek}_WS_WSDL")
             if not os.environ.get(k)]
    if eksik:
        raise ELogoHata("ortamda eksik: " + " · ".join(eksik) +
                        "  (vault-cek get ile çekilir; değer basılmaz)")
    return (os.environ[f"{onek}_WS_USER"],
            os.environ[f"{onek}_WS_PASSWORD"],
            os.environ[f"{onek}_WS_WSDL"])


def login(kullanici: str, parola: str, url: str) -> str:
    """Oturum açar, `sessionID` döndürür. Parola hiçbir yere basılmaz."""
    deger = {"appStr": "", "passWord": parola, "source": "", "userName": kullanici,
             "version": ""}
    ic = "".join(f"<d:{a}>{sx.escape(deger[a])}</d:{a}>" for a in LOGIN_ALANLARI)
    yanit = _cagir(url, "Login", f"<t:Login><t:login>{ic}</t:login></t:Login>")

    if (_alan(yanit, "LoginResult") or "").strip().lower() != "true":
        # Sunucu "false" derse sebebi söylemez; en olası üç sebebi ADIYLA say.
        raise ELogoHata(
            "Login reddedildi (LoginResult=false). Sırayla bak: (1) ad-alanı — alt alanlar "
            "datacontract ns'inde mi? (2) appStr/source/version BOŞ mu? (3) parola doğru mu? "
            "İlk ikisi yanlışken sunucu 'hatalı şifre' der — kimlik avına çıkmadan önce zarfı doğrula."
        )
    sid = _alan(yanit, "sessionID")
    if not sid:
        raise ELogoHata("LoginResult=true ama sessionID yok — yanıt şekli değişmiş olabilir")
    return sid


def logout(sid: str, url: str) -> None:
    """Oturumu kapatır. Hata ÖNEMSİZ: kapanmayan oturum kendi süresinde düşer,
    ama kapanış hatası asıl işi geçersiz kılmamalı."""
    try:
        _cagir(url, "Logout", f"<t:Logout><t:sessionID>{sx.escape(sid)}</t:sessionID></t:Logout>")
    except ELogoHata:
        pass


def seri_sayaclari(sid: str, url: str) -> list[dict[str, str]]:
    """`GetPrefixLastNumberList` — tanımlı fatura serilerini ve son sayaçlarını okur.

    NİÇİN İLK GERÇEK ÇAĞRI BU: salt-okur, hiçbir belge üretmez, hiçbir kuyruğu tüketmez —
    yani en güvenli sondadır. Üstelik açık bir sorumuzu kapatır: firmada hangi seri
    önekleri tanımlı? (Numarayı biz üretmiyoruz; bu çağrı yalnız GÖRÜNÜRLÜK içindir.)
    """
    yanit = _cagir(
        url, "GetPrefixLastNumberList",
        f"<t:GetPrefixLastNumberList><t:sessionID>{sx.escape(sid)}</t:sessionID>"
        f"<t:paramList></t:paramList></t:GetPrefixLastNumberList>")
    out: list[dict[str, str]] = []
    for blok in re.findall(r"<(?:\w+:)?PrefixLastNumber>(.*?)</(?:\w+:)?PrefixLastNumber>",
                           yanit, re.S):
        out.append({k: (_alan(blok, k) or "") for k in ("InvoicePrefix", "Counter", "Type")})
    return out


def _main(argv: list[str]) -> int:
    import sys
    onek = argv[1] if len(argv) > 1 else "ELOGO_DEMO"
    print(f"ortam: {onek}")
    try:
        u, p, url = kimlik_env(onek)
        sid = login(u, p, url)
        print(f"✓ giriş başarılı — oturum {len(sid)} karakter (değer basılmadı)")
        try:
            seriler = seri_sayaclari(sid, url)
            if seriler:
                print(f"✓ tanımlı seri: {len(seriler)}")
                for s in seriler:
                    print(f"    {s['InvoicePrefix']:>10s}  son sayaç={s['Counter']}  tip={s['Type']}")
            else:
                print("• tanımlı seri YOK (boş liste) — bu bir hata değil, ÖLÇÜM")
        finally:
            logout(sid, url)
            print("✓ oturum kapatıldı")
        return 0
    except ELogoHata as e:
        print(f"✗ KIRMIZI · {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    import sys
    raise SystemExit(_main(sys.argv))
