#!/usr/bin/env python3
# baglam-olc.py — bir Claude Code oturumunun bağlam doluluğunu (%) transkriptten ÖLÇER.
#
# NİÇİN: Ajan "/context" komutunu kendisi çalıştıramaz (o bir CLI komutudur, araç değil). Sultan'ın
# kuralı "bağlam %70'te uyar, %80'de compact öner" mekanik bir ölçü olmadan boş sözdür. Bu betik
# ölçüyü verir; kanca (nobet-kancasi.sh) onu her araç çağrısından sonra ajanın önüne koyar.
#
# NASIL: transkript kuyruğundan son assistant-usage okunur (input + cache_read + cache_creation =
# o anki bağlam). Pencere, transkriptteki son `attachment.type=model` kaydının TAM model kimliğinden
# (ör. claude-opus-5[1m]) ve filo kanonundan (/config/.claude/ORTAK-MIMARI.md "Model sozlugu"
# tablosu) çözülür. Kanon dosyası her kutuda aynıdır → pencere için ikinci bir kopya YAZILMAZ (K02).
#
# ÇIKIŞ (stdout, tek satır anahtar=değer):  pct=NN kullanilan=N pencere=N kaynak=... model=...
# ÇIKIŞ KODU: 0 = %70 altı · 1 = %70-79 · 2 = %80 ve üstü · 3 = ÖLÇÜLEMEDİ (transkript/pencere yok)
# Ölçemediğinde yeşil DEMEZ: rc=3 + sebep=... basar.
#
# Ayar: BAGLAM_PENCERE=<tam sayı> (env, her şeyi ezer; per-oturum kalibrasyon)
#       BAGLAM_KANON=<yol>        (varsayılan /config/.claude/ORTAK-MIMARI.md)
#       BAGLAM_ESIK_UYARI=70 · BAGLAM_ESIK_COMPACT=80
import json
import os
import re
import sys

TAIL_BYTES = 262144
KANON_VARSAYILAN = "/config/.claude/ORTAK-MIMARI.md"


def kuyruk_satirlari(tp, tail_bytes=TAIL_BYTES):
    size = os.path.getsize(tp)
    with open(tp, "rb") as f:
        if size > tail_bytes:
            f.seek(size - tail_bytes)
            f.readline()
        return f.read().decode("utf-8", errors="ignore").splitlines()


def son_kullanim_ve_model(satirlar):
    """(ctx_tokens, usage_model, tam_model_kimligi). Bulunamayan None/''."""
    ctx, usage_model, tam_kimlik = None, "", ""
    for line in reversed(satirlar):
        if ctx is None and '"usage"' in line:
            try:
                obj = json.loads(line)
                msg = obj.get("message") or {}
                u = msg.get("usage") or {}
                it = u.get("input_tokens")
                if it is not None:
                    ctx = it + (u.get("cache_read_input_tokens") or 0) + (u.get("cache_creation_input_tokens") or 0)
                    usage_model = str(msg.get("model") or "")
            except Exception:
                pass
        if not tam_kimlik and '"modelId"' in line:
            try:
                obj = json.loads(line)
                att = obj.get("attachment") or {}
                if att.get("type") == "model":
                    tam_kimlik = str((att.get("identity") or {}).get("modelId") or "")
            except Exception:
                pass
        if ctx is not None and tam_kimlik:
            break
    return ctx, usage_model, tam_kimlik


def kanon_tablosu(yol):
    """ORTAK-MIMARI.md 'Model sozlugu' tablosu → ({model: pencere}, ezici_listesi)."""
    tablo, eziciler = {}, []
    try:
        with open(yol, encoding="utf-8") as f:
            metin = f.read()
    except Exception:
        return tablo, eziciler
    for m in re.finditer(r"^\|\s*`([^`]+)`\s*\|[^|]*\|\s*([\d,\.]+)\s*\|", metin, re.M):
        try:
            tablo[m.group(1).strip().lower()] = int(re.sub(r"[^\d]", "", m.group(2)))
        except ValueError:
            continue
    for m in re.finditer(r"`([^`]+)`\s*→\s*([\d,\.]+)", metin):
        try:
            eziciler.append((m.group(1).strip().lower(), int(re.sub(r"[^\d]", "", m.group(2)))))
        except ValueError:
            continue
    return tablo, eziciler


def pencere_coz(model, tablo, eziciler):
    """(pencere, kaynak). kaynak ∈ env|ezici|kanon|bilinmiyor."""
    env = os.environ.get("BAGLAM_PENCERE", "")
    if env.strip().isdigit() and int(env) > 0:
        return int(env), "env"
    m = (model or "").lower()
    for desen, w in eziciler:
        if desen and desen in m:
            return w, "ezici"
    # en uzun eşleşen kanon adı kazanır (claude-opus-5 ⊂ claude-opus-5-x gibi çakışmalara karşı)
    aday = [(len(ad), w) for ad, w in tablo.items() if ad and ad in m]
    if aday:
        aday.sort(reverse=True)
        return aday[0][1], "kanon"
    return 0, "bilinmiyor"


def geriye_dogru_model_kimligi(tp, parca=1 << 20, azami=64 << 20):
    """Son `attachment.type=model` kaydını dosyanın SONUNDAN geriye doğru parça parça arar.
    Model kimliği yalnız kullanıcı turlarında yazılır; uzun araç dizilerinde son 256KB'ta
    bulunmayabilir. Tüm dosyayı okumak yerine geriye doğru en çok `azami` bayt taranır."""
    try:
        size = os.path.getsize(tp)
        with open(tp, "rb") as f:
            son = size
            kalan = b""
            while son > 0 and (size - son) < azami:
                bas = max(0, son - parca)
                f.seek(bas)
                blok = f.read(son - bas) + kalan
                idx = blok.rfind(b'"modelId"')
                while idx != -1:
                    ls = blok.rfind(b"\n", 0, idx) + 1
                    le = blok.find(b"\n", idx)
                    satir = blok[ls: le if le != -1 else len(blok)]
                    if bas == 0 or ls > 0:
                        try:
                            obj = json.loads(satir.decode("utf-8", errors="ignore"))
                            att = obj.get("attachment") or {}
                            if att.get("type") == "model":
                                return str((att.get("identity") or {}).get("modelId") or "")
                        except Exception:
                            pass
                    idx = blok.rfind(b'"modelId"', 0, idx)
                # bloğun başındaki kısmi satırı bir sonraki (daha eski) parçaya taşı
                nl = blok.find(b"\n")
                kalan = blok[:nl] if nl != -1 else blok
                son = bas
    except Exception:
        return ""
    return ""


def olc(tp, kanon_yolu):
    if not tp or not os.path.isfile(tp):
        return {"rc": 3, "sebep": "transkript-yok", "transkript": tp or ""}
    try:
        satirlar = kuyruk_satirlari(tp)
    except Exception:
        return {"rc": 3, "sebep": "transkript-okunamadi", "transkript": tp}
    ctx, usage_model, tam_kimlik = son_kullanim_ve_model(satirlar)
    if ctx is None:
        return {"rc": 3, "sebep": "usage-yok", "transkript": tp}
    if not tam_kimlik:
        tam_kimlik = geriye_dogru_model_kimligi(tp)
    model = tam_kimlik or usage_model
    tablo, eziciler = kanon_tablosu(kanon_yolu)
    pencere, kaynak = pencere_coz(model, tablo, eziciler)
    if pencere <= 0:
        return {"rc": 3, "sebep": "pencere-bilinmiyor", "model": model, "kullanilan": ctx,
                "kanon": kanon_yolu if tablo else "okunamadi"}
    pct = ctx * 100 // pencere
    uyari = int(os.environ.get("BAGLAM_ESIK_UYARI", "70") or 70)
    compact = int(os.environ.get("BAGLAM_ESIK_COMPACT", "80") or 80)
    rc = 2 if pct >= compact else 1 if pct >= uyari else 0
    return {"rc": rc, "pct": pct, "kullanilan": ctx, "pencere": pencere, "kaynak": kaynak, "model": model}


def main(argv):
    tp = argv[1] if len(argv) > 1 else os.environ.get("BAGLAM_TRANSKRIPT", "")
    kanon = os.environ.get("BAGLAM_KANON", KANON_VARSAYILAN)
    r = olc(tp, kanon)
    rc = r.pop("rc")
    sira = ["pct", "kullanilan", "pencere", "kaynak", "model", "sebep", "kanon", "transkript"]
    print(" ".join(f"{k}={r[k]}" for k in sira if k in r))
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
