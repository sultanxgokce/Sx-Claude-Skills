---
name: inplace-chat
type: feature
version: 1.0.0
description: >
  Sayfa değiştirmeden anasayfada chat açan, animasyonlu 2-kolon layout'a geçen sistem.
  history.pushState ile URL güncellenir, sayfa unmount olmaz. Masaüstü + mobil dikey split.
  Next.js App Router için hazır, herhangi bir projeye taşınabilir.
prerequisites:
  frontend: Next.js 14+ (App Router), React 18+, Tailwind CSS v3+
stacks: [nextjs, react]
author: sultanxgokce
source: Vekâtip projesi (HomeWelcome.tsx) + Nexus ChatHub
tags: [chat, inline, animation, split-layout, url-sync, mobile-split, nextjs]
nexus_catalog: "AI Engineer Workbook > Skill Kataloğu"
---

# In-Place Chat Skill

Anasayfadan sayfa geçişi olmadan chat açan, `history.pushState` ile URL'i güncelleyen,
2-kolon layout'a animate eden sistem. Kullanıcı URL'i direkt açarsa aynı session'a
server-side düşer — seamless deneyim.

---

## Bu skill ne yapar?

```
[Welcome modu]              →  Enter  →   [Chat modu]
┌──────────────────────┐          ┌────────────────────────────────┐
│  Başlık              │          │  Sol panel    │  Chat paneli   │
│  Composer input      │          │  (listeler,   │  Mesajlar      │
│  Son konuşmalar      │          │   context)    │  Composer      │
└──────────────────────┘          └────────────────────────────────┘
```

- `useState<null | ChatState>` — tek state ile welcome ↔ chat geçişi
- `history.pushState` — URL değişir, sayfa unmount olmaz
- Masaüstü: yatay 2-kolon, Mobil: dikey 3/4–1/4 flex split
- Browser geri tuşu welcome'a döner
- 320ms `cubic-bezier(0.32, 0.72, 0, 1)` açılış animasyonu

---

## Tasarım Prensipleri (front-end-design kuralları zorunlu)

Bu skill kurulurken aşağıdaki tasarım ilkeleri **zorunlu** uygulanır:

### Genel kural
- Her UI değişikliği yapılmadan önce `/front-end-design` skill context'i aktif edilir
- "Generic AI aesthetics" YASAK: Inter/Roboto/system font, purple gradient, cookie-cutter layout
- Animasyonlar amaçlı: açılış geçişi iyi orchestrate edilmeli, scatter micro-interaction değil

### Tipografi
- Karakterli display font + refined body font çifti
- Başlık → büyük, cesur, memorable
- Input placeholder → distinctive, projeye özel ton

### Renk & Tema
- CSS değişkenleri ile tutarlı palet
- Dominant renk + keskin accent — eşit dağılım değil
- Dark mode varsayılan ise arka plan derinlik katmanları

### Motion
- Welcome → Chat geçişi: `opacity + translateY` ile 320ms ease
- Mobil panel geçişi: `flexGrow` transition 350ms — buttery smooth
- Scroll-trigger veya hover state: bir tane özenli yeter, her yere serpme

### Spatial Composition
- Welcome: dar centered (`max-w-2xl mx-auto`)
- Chat: `fixed inset-0` — tam ekran devralır
- Sol panel sabit genişlik, sağ panel flex-1

---

## Minimum implementasyon (8 adım)

```ts
// 1. State
const [chat, setChat] = useState<InlineChat | null>(null)

interface InlineChat {
  sessionId: string
  firstMessage: string | null
  history: Message[]
}

// 2. Submit
async function handleSubmit(msg: string) {
  const { sessionId } = await fetch('/api/chat/start', {
    method: 'POST',
    body: JSON.stringify({ firstMessage: msg }),
  }).then(r => r.json())

  history.pushState({}, '', `/chat/${sessionId}`)
  setChat({ sessionId, firstMessage: msg, history: [] })
}

// 3. Close
function closeChat() {
  history.pushState({}, '', '/')
  setChat(null)
}

// 4. Browser back button
useEffect(() => {
  const handle = () => { if (location.pathname === '/') setChat(null) }
  window.addEventListener('popstate', handle)
  return () => window.removeEventListener('popstate', handle)
}, [])

// 5. Layout wrapper — tek div, iki mod
<div className={chat ? 'fixed inset-0 flex overflow-hidden' : 'mx-auto max-w-2xl px-4 pt-8 pb-28'}>

  {/* 6. Sol panel — sadece chat modunda */}
  {chat && (
    <aside className="w-[300px] flex-shrink-0 border-r flex flex-col">
      <RecentsList />
    </aside>
  )}

  {/* 7. Ana alan */}
  <div className={chat ? 'flex-1 flex flex-col min-w-0' : ''}>
    {chat
      ? <ChatView sessionId={chat.sessionId} firstMessage={chat.firstMessage} onClose={closeChat} />
      : <WelcomeContent onSubmit={handleSubmit} />
    }
  </div>
</div>

// 8. Açılış animasyonu
@keyframes chatEnter {
  from { opacity: 0; transform: translateY(8px); }
  to   { opacity: 1; transform: translateY(0); }
}
.animate-chat-enter {
  animation: chatEnter 320ms cubic-bezier(0.32, 0.72, 0, 1) both;
}
```

---

## Mobil dikey split

```tsx
const isMobile = useMediaQuery('(max-width: 768px)')
const [mobileFocus, setMobileFocus] = useState<'top' | 'bottom'>('bottom')

// Chat modu + mobil → dikey split
{chat && isMobile ? (
  <div className="fixed inset-0 flex flex-col">
    {/* Üst: sol panel içeriği */}
    <div
      style={{
        flexGrow: mobileFocus === 'top' ? 3 : 1,
        transition: 'flex-grow 350ms cubic-bezier(0.32, 0.72, 0, 1)',
        overflow: 'hidden',
      }}
      onClick={() => setMobileFocus('top')}
    >
      <RecentsList />
    </div>
    {/* Alt: chat */}
    <div
      style={{
        flexGrow: mobileFocus === 'bottom' ? 3 : 1,
        transition: 'flex-grow 350ms cubic-bezier(0.32, 0.72, 0, 1)',
        overflow: 'hidden',
      }}
      onClick={() => setMobileFocus('bottom')}
    >
      <ChatView ... />
    </div>
  </div>
) : (
  // Masaüstü layout (yukarıdaki 8 adım)
)}
```

---

## URL senkronizasyonu — kaçınılacaklar

| Yapma | Sorun | Doğrusu |
|---|---|---|
| `router.push('/chat')` | Sayfa unmount → state sıfır | `history.pushState` + `useState` |
| `router.replace()` | Next.js re-render tetikler | Native `history.pushState` |
| SSR'da chat state init | Hydration mismatch | `useState(null)` client-only |
| `<Link href="/chat">` | Welcome unmount | Inline render + pushState |

---

## Kurulum Talimatı (Claude'a ver)

```
Sx-Claude-Skills reposundan inplace-chat skill'ini kur.
Repo: /Users/sultan/Desktop/y/001/Sx-Claude-Skills (veya GitHub)

Kaynak referans: Vekâtip HomeWelcome.tsx pattern
Hedef sayfa: [hangi sayfa?]
API endpoint: [mevcut chat endpoint?]
Sol panel içeriği: [ne gösterilecek?]
```

---

## Projeye Göre Adaptasyon

### Nexus
- Welcome → chat geçişinde `/api/v2/chat` endpoint
- Sol panel: son sessions listesi (`/api/chat/sessions`)
- Chat component: `useV2Chat` hook
- Blackboard + Notes pane eklenir (3-kolon mod)

### Vekâtip  
- Sol panel: dava listesi / kaynak listesi
- Chat component: mevcut `ChatView`
- `InlineViewer` entegrasyonu opsiyonel

### Genel Next.js projesi
- `/api/chat/start` → sessionId döner
- ChatView kendi streaming implementasyonunla değişir
- Sol panel içeriğini projeye göre doldur

---

## Dosya yapısı (kurulum sonrası)

```
app/
  (main)/
    page.tsx                ← InlineChat state + layout geçişi
    chat/
      [id]/
        page.tsx            ← Aynı ChatView, server-side session yükleme
components/
  WelcomeContent.tsx        ← Hero + Composer
  ChatView.tsx              ← Streaming chat
  SidePanel.tsx             ← Sol panel (listeler, context)
hooks/
  useMediaQuery.ts          ← Mobil breakpoint hook
```
