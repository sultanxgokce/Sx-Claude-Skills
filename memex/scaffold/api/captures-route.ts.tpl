/**
 * GET /api/{{nameLower}}/captures
 *
 * {{InstanceName}} auto-capture listesi. Memex v1.0:
 * - Project namespace filter
 * - Author tracking filter (multi-AI ledger)
 * - Time-travel sorgu (?as_of=YYYY-MM-DD)
 * - Active-only default (valid_to=NULL)
 *
 * Query params:
 *   status      "raw" (default) | reviewed | distilled | discarded | all
 *   project     {{nameLower}}_meta | personal | (custom)
 *   author      user | claude | codex | api
 *   as_of       ISO date — TIME-TRAVEL
 *   active_only "true" (default)
 *   limit       1-200 (default 50)
 */
import { NextResponse } from "next/server"
import { prisma } from "@/lib/db"
import type { Prisma } from "@/lib/generated/prisma/client"

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url)
    const status = searchParams.get("status") ?? "raw"
    const project = searchParams.get("project")
    const author = searchParams.get("author")
    const asOfRaw = searchParams.get("as_of")
    const activeOnly = (searchParams.get("active_only") ?? "true") === "true"
    const limit = Math.min(parseInt(searchParams.get("limit") ?? "50", 10), 200)

    const where: Prisma.{{InstanceName}}CaptureWhereInput = {}
    if (status !== "all") where.status = status
    if (project && project !== "all") where.project = project
    if (author) where.author = author

    if (asOfRaw) {
      const asOf = new Date(asOfRaw)
      if (isNaN(asOf.getTime())) {
        return NextResponse.json({ error: "Invalid as_of date" }, { status: 400 })
      }
      where.validFrom = { lte: asOf }
      where.OR = [{ validTo: null }, { validTo: { gt: asOf } }]
    } else if (activeOnly) {
      where.validTo = null
    }

    const captures = await prisma.{{nameLower}}Capture.findMany({
      where,
      orderBy: [{ importance: "desc" }, { createdAt: "desc" }],
      take: limit,
    })

    return NextResponse.json({
      captures,
      meta: {
        count: captures.length,
        filters: { status, project, author, as_of: asOfRaw, active_only: activeOnly },
      },
    })
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : "Bilinmeyen hata"
    return NextResponse.json({ error: message }, { status: 500 })
  }
}
