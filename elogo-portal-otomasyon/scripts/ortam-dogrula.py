#!/usr/bin/env python3
"""Ortam GERÇEKTEN hazır mı? Sessiz-font hatasını ADIYLA yakalar."""
import sys
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    try:
        b = p.chromium.launch(args=["--no-sandbox"])
    except Exception as e:
        print(f"✗ KIRMIZI · Chromium açılmadı: {str(e)[:120]}")
        print("  → LD_LIBRARY_PATH eksik olabilir; ortam.sh'ı source et."); sys.exit(1)
    pg = b.new_page()
    pg.goto("data:text/html,<html><body><h2 id=y>ölçüm</h2><button id=b>tık</button></body></html>")
    bb = pg.locator("#y").bounding_box() or {}
    if not bb.get("height"):
        print("✗ KIRMIZI · FONT YOK — metin yüksekliği 0. Tarayıcı ayakta ama her öğe 'hidden';")
        print("  otomasyon SESSİZCE başarısız olur. → ortam.sh font symlink'ini kurar.")
        b.close(); sys.exit(2)
    try:
        pg.click("#b", timeout=4000)
    except Exception:
        print("✗ KIRMIZI · tıklama çalışmıyor"); b.close(); sys.exit(3)
    print(f"✓ YEŞİL · Chromium ayakta · font render ediyor (h={bb['height']}px) · tıklama çalışıyor")
    b.close()
