#!/usr/bin/env python3
"""
elogo-erisim · e-Logo PostBox SOAP WS yardımcısı (salt-okur odaklı).

Kimlik env'den gelir (elogo.sh cortex-access.env'den yükler):
    ELOGO_WS_USER, ELOGO_WS_PASSWORD, ELOGO_WS_WSDL

Alt komutlar:
    doctor                 → Login testi (3-durum: exit 0 yeşil / 2 kırmızı)
    status  <ETTN>         → getInvoiceStatus (e-Fatura durum)
    get     <ETTN> <out>   → getEArchiveInvoicePdfData → PDF dosyaya
    xml     <ETTN> <out>   → GetDocumentData (UBL XML) dosyaya

⚠️ Sır-hijyeni: parola asla stdout'a basılmaz.
⚠️ Kontör sınırlı + KUYRUK-GÜVENLİ: burada YALNIZ salt-okur, "alındı-işaretlemeyen"
   operasyonlar var (GetDocument/receiveInvoiceDone gibi kuyruk-tüketen çağrı YOK) —
   eski prod'un B2B senkron kuyruğunu bozmaz.
"""
from __future__ import annotations
import os, sys, ssl, warnings
warnings.filterwarnings("ignore")


def _client():
    from zeep import Client
    from zeep.transports import Transport
    from requests import Session
    from requests.adapters import HTTPAdapter
    from urllib3.util.ssl_ import create_urllib3_context

    class LegacySSLAdapter(HTTPAdapter):
        # e-Logo eski SSL renegotiation kullanıyor (Py3.12+ default engeller)
        def init_poolmanager(self, *a, **k):
            ctx = create_urllib3_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
            ctx.options |= 0x4  # OP_LEGACY_SERVER_CONNECT
            k["ssl_context"] = ctx
            return super().init_poolmanager(*a, **k)

    s = Session(); s.verify = False
    s.mount("https://", LegacySSLAdapter())
    wsdl = os.environ.get("ELOGO_WS_WSDL", "https://pb.elogo.com.tr/PostBoxService.svc?wsdl")
    return Client(wsdl, transport=Transport(session=s, timeout=40))


def _login(c):
    user = os.environ.get("ELOGO_WS_USER", "")
    pw = os.environ.get("ELOGO_WS_PASSWORD", "")
    if not user or not pw:
        print("FAIL: ELOGO_WS_USER/ELOGO_WS_PASSWORD env yok", file=sys.stderr)
        sys.exit(2)
    LT = c.get_type("{http://schemas.datacontract.org/2004/07/eFaturaWebService}LoginType")
    r = c.service.Login(login=LT(userName=user, passWord=pw, appStr="", source="", version=""))
    sid = r["sessionID"]
    if not r["LoginResult"] or not sid:
        print("FAIL: login reddedildi", file=sys.stderr)
        sys.exit(2)
    return sid


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "doctor"
    try:
        c = _client()
    except Exception as e:
        print(f"FAIL: WSDL bağlantı hatası: {e!r}", file=sys.stderr)
        sys.exit(2)

    if cmd == "doctor":
        try:
            sid = _login(c)
            try:
                c.service.Logout(sessionID=sid)
            except Exception:
                pass
            print("OK")  # yeşil
            sys.exit(0)
        except SystemExit:
            raise
        except Exception as e:
            print(f"FAIL: {e!r}", file=sys.stderr)
            sys.exit(2)

    ettn = sys.argv[2] if len(sys.argv) > 2 else ""
    out = sys.argv[3] if len(sys.argv) > 3 else ""
    if not ettn:
        print("kullanım: elogo_ws.py <status|get|xml> <ETTN> [out]", file=sys.stderr)
        sys.exit(1)

    sid = _login(c)
    try:
        if cmd == "status":
            r = c.service.getInvoiceStatus(uuid=ettn, sessionID=sid)
            print(f"result={r['getInvoiceStatusResult']} status={r['status']} "
                  f"desc={r['statusDescription']} envelopeId={r['envelopeId']}")
        elif cmd == "get":
            got = False
            for signed in (True, False):
                r = c.service.getEArchiveInvoicePdfData(
                    sessionID=sid, uuid=ettn,
                    allInvoicesOrJustSigned=signed, isCanceled=False)
                if r["getEArchiveInvoicePdfDataResult"] and r["pdfData"]:
                    with open(out or "fatura.pdf", "wb") as f:
                        f.write(r["pdfData"])
                    print(f"OK: {out or 'fatura.pdf'} ({len(r['pdfData'])} bytes, signed={signed})")
                    got = True
                    break
            if not got:
                print("NOTFOUND: bu ETTN için imzalı/kesilmiş e-Arşiv PDF yok "
                      "(taslak olabilir ya da farklı ETTN).", file=sys.stderr)
                sys.exit(3)
        elif cmd == "xml":
            r = c.service.GetDocumentData(
                sessionID=sid, uuid=ettn,
                paramList=["DOCUMENTTYPE=EARCHIVE", "DATAFORMAT=UBL"])
            doc = r["document"]
            data = getattr(doc, "binaryData", None) if doc is not None else None
            raw = getattr(data, "Value", None) if data is not None else None
            if not raw:
                print(f"NOTFOUND: belge yok (resultMsg={r['GetDocumentDataResult']})", file=sys.stderr)
                sys.exit(3)
            with open(out or "fatura.xml", "wb") as f:
                f.write(raw)
            print(f"OK: {out or 'fatura.xml'} ({len(raw)} bytes)")
        else:
            print(f"bilinmeyen komut: {cmd}", file=sys.stderr)
            sys.exit(1)
    finally:
        try:
            c.service.Logout(sessionID=sid)
        except Exception:
            pass


if __name__ == "__main__":
    main()
