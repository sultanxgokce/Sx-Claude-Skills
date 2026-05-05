/**
 * {{InstanceName}} — Memex v1.0 Context Loader
 *
 * Her AI çağrısı için {{InstanceName}} bağlamını DB'den yükler.
 * Kaynak: {{nameLower}}_pages tablosu (markdown wiki mirror'ı)
 *
 * Memex Mimarisi (4 Direk):
 *   1. Bi-Temporal (Graphiti) — valid_from/valid_to/superseded_by
 *   2. Project Namespace — multi-project default scope
 *   3. Embedding Versioning (Open Brain) — model upgrade safety
 *   4. Episodic vs Semantic ayrımı — raw dokunmaz, derived rebuild
 *
 * Endüstri kaynakları: Mem0, Letta (MemGPT), Zep/Graphiti, Cognee.
 */
import { prisma } from "@/lib/db"
import { {{INSTANCE_NAME_UPPER}}_BUDGETS, NAMESPACE } from "@/lib/{{nameLower}}-config"

export type ProjectKey = "{{nameLower}}_meta" | "personal" | string

interface MemexContextOptions {
  /** Görevin ait olduğu proje — wiki branch + namespace eşlemesi */
  project?: ProjectKey
  /** Kullanıcı profilini ekle (varsayılan: true) */
  includeUserProfile?: boolean
  /** Karar/keşif sayfalarını ekle (varsayılan: true — yıldıza göre) */
  includeKararlar?: boolean
  /** Token bütçesi yaklaşık limit (~4 char/token) */
  charBudget?: number
  /** TIME-TRAVEL: o tarihte aktif olan sayfalar (Graphiti pattern) */
  asOf?: Date
}

interface MemexPageRow {
  slug: string
  branch: string
  title: string
  content: string
  oncelik: number
}

/**
 * {{InstanceName}} bağlamını yükle ve sade markdown olarak döndür.
 * Token-aware: charBudget'a sığacak şekilde önceliğe göre keser.
 * Bi-temporal aware: asOf verilirse o tarihteki aktif sayfalar.
 */
export async function load{{InstanceName}}Context(opts: MemexContextOptions = {}): Promise<string> {
  const {
    project = NAMESPACE.default,
    includeUserProfile = true,
    includeKararlar = true,
    charBudget = {{INSTANCE_NAME_UPPER}}_BUDGETS.default,
    asOf,
  } = opts

  const sections: string[] = []
  let used = 0

  const append = (header: string, page: MemexPageRow): boolean => {
    const block = `\n## ${header}: ${page.title}\n\n${page.content}\n`
    if (used + block.length > charBudget) return false
    sections.push(block)
    used += block.length
    return true
  }

  // Bi-temporal where clause
  const temporalWhere = asOf
    ? {
        validFrom: { lte: asOf },
        OR: [{ validTo: null }, { validTo: { gt: asOf } }],
      }
    : { validTo: null } // default: hâlâ aktif olanlar

  // 1. Kullanıcı profili — her zaman önce
  if (includeUserProfile) {
    const profilePages = await prisma.{{nameLower}}Page.findMany({
      where: {
        branch: "user",
        deletedAt: null,
        slug: { not: { contains: "_index" } },
        project,
        ...temporalWhere,
      },
      orderBy: { oncelik: "desc" },
      select: { slug: true, branch: true, title: true, content: true, oncelik: true },
    })
    for (const p of profilePages) {
      if (!append("Profil", p)) break
    }
  }

  // 2. Proje sayfaları — aktif proje öncelikli
  if (project !== NAMESPACE.default) {
    const projectPages = await prisma.{{nameLower}}Page.findMany({
      where: {
        project,
        deletedAt: null,
        slug: { not: { contains: "_index" } },
        ...temporalWhere,
      },
      orderBy: [{ oncelik: "desc" }, { updatedAt: "desc" }],
      select: { slug: true, branch: true, title: true, content: true, oncelik: true },
    })
    for (const p of projectPages) {
      if (!append(`Proje (${project})`, p)) break
    }
  }

  // 3. Kararlar — yıldız 4-5 (mimari/vizyon kararları)
  if (includeKararlar) {
    const kararlar = await prisma.{{nameLower}}Page.findMany({
      where: {
        branch: "kararlar",
        deletedAt: null,
        oncelik: { gte: 4 },
        slug: { not: { contains: "_index" } },
        ...temporalWhere,
      },
      orderBy: { oncelik: "desc" },
      select: { slug: true, branch: true, title: true, content: true, oncelik: true },
    })
    for (const p of kararlar) {
      if (!append("Karar", p)) break
    }
  }

  return sections.join("\n").trim()
}

/**
 * AI sistem prompt'u — {{InstanceName}} bağlamı + davranış kuralları.
 */
export function build{{InstanceName}}SystemPrompt(opts: {
  context: string
  taskContext?: string
  bridgeData?: string | null
  role?: "general" | "morning" | "pipeline"
}): string {
  const { context, taskContext, bridgeData, role = "general" } = opts

  const roleLine = {
    pipeline: "Şu anda bir karar pipeline görevi üzerinde konuşuyorsun.",
    morning: "Şu anda komuta merkezindesin — günlük durum üzerine konuşuyorsun.",
    general: "Asistansın. {{InstanceName}} hafızasından beslenerek konuşuyorsun.",
  }[role]

  return `Sen {{InstanceName}} asistanısın. {{InstanceName}}, kullanıcının yaşayan dijital hafızasıdır.
${roleLine}

## Davranış Kuralları
- Bilmediğin bir konu çıkarsa: "Bunu öğrenip döneyim" de — uydurma.
- Yanıtların kısa, net, doğrudan. 3-5 cümle ideal.
- Yeni karar/keşif çıkarsa farkında ol — {{InstanceName}}'e işlenecek.

## {{InstanceName}} Bağlamı
${context || "(bağlam boş — wiki sync gerekli)"}
${taskContext ? `\n## Aktif Görev\n${taskContext}` : ""}${bridgeData ? `\n\n## Federation Canlı Bilgi\n${bridgeData}` : ""}`
}
