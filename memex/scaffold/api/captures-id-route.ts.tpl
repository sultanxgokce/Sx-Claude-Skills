/**
 * PATCH /api/{{nameLower}}/captures/[id]
 *
 * Memex v1.0 — Capture lifecycle:
 *   approve / reject / edit / distill / wikilestir (mevcut akış)
 *   invalidate / set_validity (Memex v1.0 — bi-temporal)
 */
import { NextResponse } from "next/server"
import { prisma } from "@/lib/db"
import { distillCapture } from "@/lib/{{nameLower}}-distill"

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const body = await request.json() as {
      action: "approve" | "reject" | "edit" | "distill" | "wikilestir" |
              "invalidate" | "set_validity"
      aiSummary?: string
      importance?: number
      targetSlug?: string
      targetBranch?: string
      rejectReason?: string
      // Memex v1.0
      supersededByCaptureId?: string
      validFrom?: string
      validTo?: string | null
    }

    const capture = await prisma.{{nameLower}}Capture.findUnique({ where: { id } })
    if (!capture) return NextResponse.json({ error: "capture bulunamadı" }, { status: 404 })

    if (body.action === "edit") {
      const updated = await prisma.{{nameLower}}Capture.update({
        where: { id },
        data: {
          aiSummary: body.aiSummary ?? capture.aiSummary,
          importance: body.importance !== undefined
            ? Math.max(1, Math.min(5, body.importance))
            : capture.importance,
          targetSlug: body.targetSlug ?? capture.targetSlug,
          targetBranch: body.targetBranch ?? capture.targetBranch,
        },
      })
      return NextResponse.json({ capture: updated })
    }

    if (body.action === "reject") {
      const updated = await prisma.{{nameLower}}Capture.update({
        where: { id },
        data: { status: "discarded", reviewedAt: new Date(), rejectReason: body.rejectReason ?? null },
      })
      return NextResponse.json({ capture: updated })
    }

    if (body.action === "approve") {
      const updated = await prisma.{{nameLower}}Capture.update({
        where: { id },
        data: { status: "reviewed", reviewedAt: new Date() },
      })
      return NextResponse.json({ capture: updated })
    }

    if (body.action === "distill") {
      const result = await distillCapture(id)
      return NextResponse.json(result)
    }

    if (body.action === "wikilestir") {
      const result = await distillCapture(id)
      if (!result.ok) return NextResponse.json(result, { status: 400 })
      await prisma.{{nameLower}}Capture.update({
        where: { id },
        data: { reviewedAt: new Date() },
      })
      return NextResponse.json(result)
    }

    // ── Memex v1.0 — Bi-Temporal Aksiyonlar ──

    if (body.action === "invalidate") {
      const updated = await prisma.{{nameLower}}Capture.update({
        where: { id },
        data: {
          validTo: new Date(),
          supersededBy: body.supersededByCaptureId ?? null,
        },
      })
      return NextResponse.json({
        capture: updated,
        meta: {
          invalidated_at: updated.validTo,
          superseded_by: updated.supersededBy,
          note: "Veri silinmedi. ?as_of= ile zamanda geri görüntülenebilir.",
        },
      })
    }

    if (body.action === "set_validity") {
      const updated = await prisma.{{nameLower}}Capture.update({
        where: { id },
        data: {
          validFrom: body.validFrom ? new Date(body.validFrom) : capture.validFrom,
          validTo: body.validTo === null ? null : (body.validTo ? new Date(body.validTo) : capture.validTo),
        },
      })
      return NextResponse.json({ capture: updated })
    }

    return NextResponse.json({ error: "geçersiz action" }, { status: 400 })
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : "Bilinmeyen hata"
    return NextResponse.json({ error: message }, { status: 500 })
  }
}
