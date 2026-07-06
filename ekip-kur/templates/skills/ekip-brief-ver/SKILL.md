---
name: ekip-brief-ver
description: Tüm ekibe tek brief duyurusu yayınla — ekip-brief.md'ye yaz + herkese tmux-ping. Yönetici/Sultan-eli.
disable-model-invocation: true
allowed-tools: Bash, Edit, Read
---

# /ekip-brief-ver — yönetici → tüm-ekibe brief

**Kim çağırır:** ekip-yöneticisi ya da Sultan (USER-ONLY — model kendiliğinden çağıramaz).
**Ne yapar:** Bir duyuruyu ortak `_agents/handoff/ekip-brief.md` kanalına düşürür ve üyelerin (self hariç) tmux-oturumuna "oku + gereğini yap" ping'i atar. Kardeş `*-inbox.md`'lere DOKUNMAZ (tek-yazar disiplini — brief BURAYA, ortak kanala iner).

## Adımlar

1. **Brief metni:** `$ARGUMENTS` doluysa onu kullan; boşsa tek-satır sor: "Brief metni?" — kısa-öz iste (diyet; sır-değer ASLA yazma).
2. **Zaman damgası:** `date -Is` çıktısını al (`<ts>`).
3. **Kanala append:** `_agents/handoff/ekip-brief.md` dosyasının SONUNA şu bloğu ekle (append-only):
   ```
   ## BRİF · <ts> · → hepsi

   <brief-metni>
   ```
4. **Ping:** çalıştır →
   ```bash
   bash scripts/ekip-notify.sh all "ekip-brief güncellendi — _agents/handoff/ekip-brief.md son girdiyi oku + gereğini yap"
   ```
5. **Raporla:** script `ozet: gonderildi=N …` basar — kaç üyeye ping gittiğini + eksik/atlanan oturum varsa Sultan'a bildir (sessiz-geçme yok). Oturumu kapalı üye = normaldir, dürüstçe listele.

## Sınırlar
- Yalnız `ekip-brief.md`'ye yazar; başka kanala/inbox'a değil.
- Ping yalnız tetiktir; üye-Claude'un ne zaman yanıtladığı ASENKRON'dur — bekleme garanti değil.
