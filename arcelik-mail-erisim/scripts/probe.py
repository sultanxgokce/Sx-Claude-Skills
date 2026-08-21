#!/usr/bin/env python3
"""arcelik-mail-erisim sondası — prod DB'den SALT-OKUR.

🔴 Değişmez: yalnız SELECT. Bağlantı açılır açılmaz oturum read-only'ye çevrilir;
   yanlışlıkla yazan bir satır eklenirse veritabanı REDDEDER (kendi elimizi bağlıyoruz).
🔴 Sır: bağlantı URL'si argv'ye DEĞİL ortama (MAILDB) konur; hiçbir yere basılmaz.
"""
import os, sys, datetime as dt

def baglan():
    """Prod'a bağlanır ve ÜÇ KATLI salt-okur kilidi kurar.

    🔴 NİÇİN ÜÇ KAT: eldeki kimlik TAM YETKİLİDİR (salt-okur kullanıcı yok — MUAVİN, 2026-08-22).
    Yani "yazmıyoruz" bir niyet değil, ZORLANMASI gereken bir kısıttır. Tek kat yeterli değil:
      1. bağlantı seçeneği — oturum daha ilk komuttan önce read-only doğar (options=-c ...)
      2. oturum ayarı      — 1. katman sürücü/pooler tarafından yutulursa yakalar
      3. her transaction   — psycopg'nin kendi read_only bayrağı
    Üçü de aynı şeyi söyler; biri sessizce düşerse diğer ikisi ayakta kalır.
    Yazma denemesi → PostgreSQL 25006 (read_only_sql_transaction) ile REDDEDİLİR.
    """
    url = os.environ.get("MAILDB")
    if not url:
        print("MAILDB ortam değişkeni yok"); sys.exit(3)
    import psycopg
    # Kat 1 — sunucu oturumu read-only DOĞSUN (mevcut options varsa ezmeden ekle)
    c = psycopg.connect(url, connect_timeout=20,
                        options="-c default_transaction_read_only=on")
    # Kat 2 — oturum ayarı (1. katman bir pooler tarafından yutulmuşsa)
    c.execute("SET default_transaction_read_only = on")
    # Kat 3 — sürücü düzeyi
    c.read_only = True
    # Kanıt: kilidin GERÇEKTEN kurulduğunu sunucuya sor (varsayma, ÖLÇ)
    if (c.execute("show default_transaction_read_only").fetchone()[0]) != "on":
        raise RuntimeError("salt-okur kilidi kurulamadı — bağlanmayı reddediyorum")
    return c

def doctor(c):
    n, fis, son = c.execute(
        "select count(*), count(*) filter (where is_fis_paketi), max(received_at) "
        "from exchange_mail_messages").fetchone()
    print(f"✓ prod DB bağlandı (salt-okur) · mail={n} · fiş_paketi={fis}")
    if son is None:
        print("\033[31m✗ KIRMIZI · hiç mail yok — hat hiç çalışmamış ya da tablo boş\033[0m"); return 1
    yas = (dt.datetime.now(son.tzinfo) - son).days
    print(f"  son mail: {son:%Y-%m-%d %H:%M} ({yas} gün önce)")
    islenmemis = c.execute("select count(*) from exchange_mail_messages "
                           "where is_fis_paketi and not fis_paketi_processed").fetchone()[0]
    print(f"  işlenmemiş fiş paketi: {islenmemis}")
    if yas > 7:
        # Sessiz-bayatlama bu hattın ana arıza modudur: token 90 günde ölür, kimse fark etmez.
        print(f"\033[31m✗ KIRMIZI · hat {yas} GÜNDÜR sessiz — token ölmüş olabilir.\033[0m")
        print("  → SKILL.md 'Arıza sözlüğü' + panelde Sistem > Mail > Exchange Mail Bağla")
        return 1
    if yas > 2:
        print(f"\033[33m• SARI · {yas} gündür yeni mail yok (hafta sonu olabilir; 7 günde kırmızıya döner)\033[0m")
        return 0
    print("\033[32m✓ YEŞİL · hat canlı\033[0m"); return 0

def listele(c, gun):
    print(f"── son {gun} günün fiş paketleri ──")
    rows = list(c.execute("""
        select m.id, m.received_at, m.subject, m.fis_paketi_processed,
               count(a.id) filter (where a.content_bytes is not null)
        from exchange_mail_messages m
        left join exchange_mail_attachments a on a.message_id = m.id
        where m.is_fis_paketi and m.received_at > now() - (%s || ' days')::interval
        group by 1,2,3,4 order by m.received_at desc""", (str(gun),)))
    if not rows:
        print("  (bu aralıkta fiş paketi YOK — bu bir ölçümdür, hata değil)"); return 0
    for r in rows:
        d = "işlendi" if r[3] else "BEKLİYOR"
        print(f"  id={r[0]:<7} {r[1]:%Y-%m-%d %H:%M}  ek={r[4]:<2} {d:<8} {r[2][:56]}")
    print(f"  toplam={len(rows)} · bekleyen={sum(1 for r in rows if not r[3])}")
    return 0

def indir(c, mid, dizin):
    os.makedirs(dizin, exist_ok=True)
    rows = list(c.execute("""select a.filename, a.content_type, a.content_bytes
                             from exchange_mail_attachments a
                             where a.message_id = %s and a.content_bytes is not null
                               and not a.is_inline""", (mid,)))
    if not rows:
        print(f"  mail {mid}: indirilebilir ek YOK (inline görseller sayılmaz)"); return 1
    import hashlib, re
    for i, (ad, tur, icerik) in enumerate(rows, 1):
        ad = re.sub(r"[^\w.\-]", "_", ad or f"ek{i}.pdf")
        yol = os.path.join(dizin, f"{mid}_{ad}")
        with open(yol, "wb") as f: f.write(icerik)
        print(f"  ✓ {yol}  ({len(icerik)} bayt · {tur} · sha256={hashlib.sha256(icerik).hexdigest()[:12]})")
    print(f"  {len(rows)} ek yazıldı → {dizin}")
    return 0

def main(argv):
    komut = argv[1] if len(argv) > 1 else "doctor"
    with baglan() as c:
        if komut == "doctor":  return doctor(c)
        if komut == "listele": return listele(c, int(argv[2]) if len(argv) > 2 else 30)
        if komut == "indir":   return indir(c, argv[2], argv[3] if len(argv) > 3 else "./fis-paketleri")
    print(f"bilinmeyen komut: {komut}"); return 2

if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
