/**
 * {{InstanceName}} Yapılandırma Sabitleri
 *
 * Tüm magic number'lar burada — değiştirirken etkiyi merkezi gör.
 * Her sabitin yanına "neden bu değer" yorumu zorunlu.
 *
 * Memex v1.0 paketi tarafından üretildi — Sultan'ın Cortex'inden adapte.
 */

// ─── Token / Char bütçeleri ────────────────────────────────────────────
// AI model context'i sınırlı. Sistem prompt'a yer bırakmak için budget'lar.
// Default: 16K char (~4K token) {{InstanceName}} bağlamına ayrılır.
// Chat agresif: 12K char (görev + bridge için pay).

export const {{INSTANCE_NAME_UPPER}}_BUDGETS = {
  /** load{{InstanceName}}Context default char budget */
  default: 16_000,
  /** Chat içi {{InstanceName}} bağlam budget (geri kalan task + bridge için) */
  chat: 12_000,
} as const

// ─── Importance scoring ────────────────────────────────────────────────
// Wiki sistemindeki yıldız mantığıyla birebir uyumlu (oncelik 1-5).

export const IMPORTANCE = {
  min: 1,
  max: 5,
  default: 3,
} as const

export function clampImportance(n: number): number {
  return Math.max(IMPORTANCE.min, Math.min(IMPORTANCE.max, Math.round(n)))
}

// ─── Capture extractor ─────────────────────────────────────────────────
// Excerpt 500 char: kanıt yeterli ama DB şişmesin.
// Conflict overlap: 3+ ortak anahtar kelime → çakışma sinyali.
// Min word length: 3 — Türkçe kısa kelimeler dahil olsun.

export const EXTRACTOR = {
  excerptMaxChars: 500,
  conflictMinOverlap: 3,
  conflictMinWordLength: 3,
} as const

// ─── Federation Bridge (opsiyonel) ─────────────────────────────────────
// Başka bir {{InstanceName}} instance'ından veri çekiyorsa.
// 2.5s: Chat akışında her sorguda fetch. Down ise fail-fast.

export const BRIDGE = {
  timeoutMs: 2_500,
  defaultLimit: 5,
} as const

// ─── Distill ────────────────────────────────────────────────────────────
// Slug çakışma denemesi 5 ile sınırlı; sonsuz döngüye girmesin.

export const DISTILL = {
  slugMaxAttempts: 5,
  /** capture: prefix DB-only (markdown dosyası YOK), sync soft-delete'ten muaf */
  dbOnlySourcePrefix: "capture:",
} as const

// ─── Memex v1.0 — Bi-Temporal & Multi-AI ────────────────────────────────
// Project namespace: hangi proje kapsamında? (default scope)
// Author: hangi AI/insan yazdı? (multi-AI ledger)

export const NAMESPACE = {
  /** Default project scope (env'den override edilebilir) */
  default: process.env.{{INSTANCE_NAME_UPPER}}_DEFAULT_PROJECT ?? "{{nameLower}}_meta",
  /** Bilinen projeler (genişletilebilir) */
  known: ["{{nameLower}}_meta", "personal"] as const,
} as const

export const AUTHORS = {
  user: "user",
  claude: "claude",
  codex: "codex",
  api: "api",
} as const

// ─── Embedding Versioning ──────────────────────────────────────────────
// Hangi model + versiyon. Upgrade'de tüm rebuild zorunlu (Open Brain pattern).

export const EMBEDDING = {
  model: process.env.{{INSTANCE_NAME_UPPER}}_EMBEDDING_MODEL ?? "openai-text-embedding-3-small",
  dimensions: parseInt(process.env.{{INSTANCE_NAME_UPPER}}_EMBEDDING_DIMENSIONS ?? "1536", 10),
  provider: process.env.{{INSTANCE_NAME_UPPER}}_EMBEDDING_PROVIDER ?? "openai",
} as const
