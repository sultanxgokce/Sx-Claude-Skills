#!/usr/bin/env python3
"""Device Code Flow — Arçelik posta kutusuna BİR KEZ insan onayıyla bağlanır.

🔴 NİÇİN BU AKIŞ: Arçelik tenant'ı üçüncü-taraf consent'i kapatmıştır; MFA zorunludur.
   Device Code, MFA'yı destekleyen ve headless gerektirmeyen TEK yoldur (7 yol elendi — SKILL.md).
🔴 PAROLA YOK: bu akış parola KULLANMAZ. Kod insanın tarayıcısında girilir; ajan parola görmez.
🔴 SIR: refresh_token cortex-access.env'e (600) yazılır; DEĞERİ hiçbir yere BASILMAZ.
"""
import json, os, sys, time, urllib.parse, urllib.request

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/140.0 Safari/537.36")
# Belgede ölçülmüş ÇALIŞAN formül (17 Mart 2026'da gerçek bağlantı bununla kuruldu).
OUTLOOK_DESKTOP = "d3590ed6-52b3-4102-aeff-aad2292ab01c"
SCOPE = "https://outlook.office365.com/EWS.AccessAsUser.All offline_access"
ENVF = os.path.expanduser("~/.config/cortex-access.env")


def _post(url, veri):
    r = urllib.request.Request(url, data=urllib.parse.urlencode(veri).encode(),
                               headers={"Content-Type": "application/x-www-form-urlencoded",
                                        "User-Agent": UA})
    try:
        with urllib.request.urlopen(r, timeout=30) as y:
            return json.loads(y.read().decode())
    except urllib.error.HTTPError as e:
        return json.loads(e.read().decode())


def _env_yaz(anahtar, deger):
    """cortex-access.env'e yazar/günceller. Değer basılmaz."""
    os.makedirs(os.path.dirname(ENVF), exist_ok=True)
    satirlar = []
    if os.path.exists(ENVF):
        with open(ENVF, encoding="utf-8") as f:
            satirlar = [s for s in f.read().splitlines()
                        if not s.startswith(f"export {anahtar}=") and not s.startswith(f"{anahtar}=")]
    satirlar.append(f"export {anahtar}={deger}")
    tmp = ENVF + ".yeni"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("\n".join(satirlar) + "\n")
    os.chmod(tmp, 0o600); os.replace(tmp, ENVF)


def baslat(tenant, client_id):
    d = _post(f"https://login.microsoftonline.com/{tenant}/oauth2/v2.0/devicecode",
              {"client_id": client_id, "scope": SCOPE})
    if "device_code" not in d:
        print(f"✗ KIRMIZI · {d.get('error')} · {(d.get('error_description') or '')[:200]}")
        return None
    return d


def bekle(tenant, client_id, d):
    """Kullanıcı kodu girene kadar bekler. Sadece BEKLER — hiçbir şey zorlamaz."""
    aralik = int(d.get("interval", 5))
    bitis = time.time() + int(d.get("expires_in", 900))
    while time.time() < bitis:
        time.sleep(aralik)
        t = _post(f"https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token",
                  {"grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                   "client_id": client_id, "device_code": d["device_code"]})
        if "access_token" in t:
            _env_yaz("EXCHANGE_ACCESS_TOKEN", t["access_token"])
            if t.get("refresh_token"):
                _env_yaz("EXCHANGE_REFRESH_TOKEN", t["refresh_token"])
            _env_yaz("EXCHANGE_TOKEN_CLIENT_ID", client_id)
            kalan = int(t.get("expires_in", 0)) // 60
            print(f"\n✅ BAĞLANDI · token alındı ({kalan} dk geçerli) · refresh "
                  f"{'VAR (~90 gün)' if t.get('refresh_token') else 'YOK'} · değer basılmadı")
            return 0
        hata = t.get("error")
        if hata == "authorization_pending":
            continue
        if hata == "slow_down":
            aralik += 5; continue
        # Gerçek hatalar — sözlüğe bağla, "bir şey oldu" deme
        aciklama = (t.get("error_description") or "")[:200].replace("\n", " ")
        print(f"\n✗ KIRMIZI · {hata} · {aciklama}")
        for kod, ipucu in (("65001", "admin consent gerekiyor → custom app bırak, first-party kullan"),
                           ("65002", "preauthorization yok → Graph scope bırak, EWS scope kullan"),
                           ("50076", "MFA → ROPC bırak, Device Code kullan"),
                           ("70016", "kod henüz girilmedi / süresi doldu")):
            if kod in aciklama:
                print(f"  → SKILL.md arıza sözlüğü: AADSTS{kod} — {ipucu}")
        return 1
    print("\n✗ süre doldu — kod girilmedi. Yeniden başlat.")
    return 1


def main():
    tenant = os.environ.get("AZURE_TENANT_ID")
    if not tenant:
        print("✗ AZURE_TENANT_ID yok — önce: vault-cek get AZURE_TENANT_ID"); return 3
    # Varsayılan: ölçülmüş çalışan formül. --kasa-client ile kasadaki client denenir.
    client = OUTLOOK_DESKTOP
    etiket = "Outlook Desktop (belgede ölçülmüş ÇALIŞAN formül)"
    if "--kasa-client" in sys.argv:
        client = os.environ.get("AZURE_CLIENT_ID") or client
        etiket = "kasadaki AZURE_CLIENT_ID"
    d = baslat(tenant, client)
    if not d:
        return 1
    print("━" * 62)
    print(f"  client : {etiket}")
    print(f"  ADRES  : {d['verification_uri']}")
    print(f"  KOD    : {d['user_code']}")
    print(f"  süre   : {int(d.get('expires_in', 900)) // 60} dakika")
    print("━" * 62)
    print("  → Sultan bu kodu tarayıcıda girecek. BİR KEZ. Sonrası ~90 gün otonom.")
    print("  → Kod girilene kadar bekliyorum...", flush=True)
    return bekle(tenant, client, d)


if __name__ == "__main__":
    raise SystemExit(main())
