"""
M012 — Feedback & Co-Design API Endpoint'leri

8 endpoint: CRUD + screenshot upload + status + react + stats
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Query
from sqlmodel import Session, select, func, col
from sqlalchemy import and_, or_
from zoneinfo import ZoneInfo

from backend.db.session import get_session
from backend.core.security import get_current_user
from backend.models.user import User, UserRole
from backend.models.feedback import (
    Feedback, FeedbackReply, FeedbackReaction,
    FeedbackType, FeedbackPriority, FeedbackStatus,
)
from backend.schemas.feedback import (
    FeedbackCreate, FeedbackRead, FeedbackDetail, FeedbackStatusUpdate,
    FeedbackReplyCreate, FeedbackReplyRead,
    FeedbackReactionCreate, FeedbackReactionRead,
    FeedbackStats, UserMinimal,
)

logger = logging.getLogger(__name__)
router = APIRouter()

TZ = ZoneInfo("Europe/Istanbul")


# ── Helpers ───────────────────────────────────────────────

MODULE_TAG_MAP = {
    "/cagrilar": "Cagrilar",
    "/musteriler": "Musteriler",
    "/mutabakat": "B2B",
    "/finans": "Finans",
    "/kasa": "Finans",
    "/depo": "Depo",
    "/ik": "IK",
    "/mesai": "IK",
    "/araclar": "Araclar",
    "/aracim": "Araclar",
    "/performans": "Performans",
    "/anket": "Anket",
    "/iletisim": "Iletisim",
    "/yonetim": "Yonetim",
    "/dashboard": "Dashboard",
    "/gorevler": "Gorevler",
}


def _derive_module_tag(url: str | None) -> str | None:
    if not url:
        return None
    for prefix, tag in MODULE_TAG_MAP.items():
        if url.startswith(prefix):
            return tag
    return None


def _user_minimal(user: User | None) -> UserMinimal | None:
    if not user:
        return None
    return UserMinimal(
        id=user.id,
        display_name=user.display_name or user.username,
        avatar_icon=getattr(user, "avatar_icon", None),
    )


def _is_admin(user: User) -> bool:
    role = user.role
    if isinstance(role, str):
        return role == "admin"
    return role.value == "admin" if hasattr(role, "value") else str(role) == "admin"


def _build_feedback_read(fb: Feedback, session: Session, current_user: User | None = None) -> FeedbackRead:
    """Feedback → FeedbackRead dönüşümü (reply_count, reactions dahil)."""
    reply_count = session.exec(
        select(func.count(FeedbackReply.id)).where(FeedbackReply.feedback_id == fb.id)
    ).one()

    # Reaction sayıları
    reactions = session.exec(
        select(FeedbackReaction.emoji, func.count(FeedbackReaction.id))
        .where(FeedbackReaction.feedback_id == fb.id)
        .group_by(FeedbackReaction.emoji)
    ).all()
    reaction_counts = {emoji: count for emoji, count in reactions}

    # Okunmamış yanıt kontrolü — son yanıt admin'den mi ve kullanıcı kendi feedback'ini mi görüyor
    has_unread = False
    if current_user and fb.user_id == current_user.id:
        last_reply = session.exec(
            select(FeedbackReply)
            .where(FeedbackReply.feedback_id == fb.id)
            .where(FeedbackReply.user_id != current_user.id)
            .order_by(FeedbackReply.created_at.desc())
            .limit(1)
        ).first()
        if last_reply:
            has_unread = True  # Basit: admin yanıtı varsa unread

    # User relationships
    user = session.get(User, fb.user_id)
    resolved_by = session.get(User, fb.resolved_by_id) if fb.resolved_by_id else None

    return FeedbackRead(
        id=fb.id,
        user_id=fb.user_id,
        type=fb.type,
        priority=fb.priority,
        status=fb.status,
        message=fb.message,
        current_url=fb.current_url,
        module_tag=fb.module_tag,
        screenshot_url=fb.screenshot_url,
        annotated_screenshot_url=fb.annotated_screenshot_url,
        browser_info=fb.browser_info,
        satisfaction_score=fb.satisfaction_score,
        created_at=fb.created_at,
        updated_at=fb.updated_at,
        resolved_at=fb.resolved_at,
        resolved_by_id=fb.resolved_by_id,
        user=_user_minimal(user),
        resolved_by=_user_minimal(resolved_by),
        reply_count=reply_count,
        reaction_counts=reaction_counts,
        has_unread_reply=has_unread,
    )


# ── 1. POST / — Feedback gönder ──────────────────────────

@router.post("/", response_model=FeedbackRead, status_code=201)
async def submit_feedback(
    body: FeedbackCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    # Type validation
    valid_types = {t.value for t in FeedbackType}
    if body.type not in valid_types:
        raise HTTPException(422, f"type must be one of: {', '.join(valid_types)}")

    valid_priorities = {p.value for p in FeedbackPriority}
    if body.priority not in valid_priorities:
        raise HTTPException(422, f"priority must be one of: {', '.join(valid_priorities)}")

    module_tag = _derive_module_tag(body.current_url)

    feedback = Feedback(
        user_id=current_user.id,
        type=body.type,
        priority=body.priority,
        message=body.message.strip(),
        current_url=body.current_url,
        module_tag=module_tag,
        screenshot_url=body.screenshot_url,
        annotated_screenshot_url=body.annotated_screenshot_url,
        browser_info=body.browser_info,
        satisfaction_score=body.satisfaction_score,
    )
    session.add(feedback)
    session.commit()
    session.refresh(feedback)

    logger.info(
        "Feedback #%d submitted: user=%s type=%s priority=%s module=%s",
        feedback.id, current_user.username, feedback.type, feedback.priority, module_tag,
    )

    # Telegram bildirimi (async değil, fire-and-forget)
    try:
        _notify_feedback_telegram(feedback, current_user)
    except Exception as exc:
        logger.warning("Telegram notification failed: %s", exc)

    # Critical priority → push to admins
    if body.priority == FeedbackPriority.CRITICAL.value:
        try:
            from backend.services.core.push_notification import send_push_to_admins
            send_push_to_admins(
                session,
                title="Kritik Geri Bildirim",
                body=f"{current_user.display_name}: {body.message[:100]}",
                url=f"/yonetim/feedback",
            )
        except Exception as exc:
            logger.warning("Push notification failed: %s", exc)

    return _build_feedback_read(feedback, session, current_user)


# ── 2. GET / — Liste ─────────────────────────────────────

@router.get("/", response_model=list[FeedbackRead])
async def list_feedbacks(
    status: str | None = Query(None),
    type: str | None = Query(None),
    module_tag: str | None = Query(None),
    q: str | None = Query(None),
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    query = select(Feedback)

    # Non-admin: sadece kendi feedback'leri
    if not _is_admin(current_user):
        query = query.where(Feedback.user_id == current_user.id)

    # Filters
    if status:
        query = query.where(Feedback.status == status)
    if type:
        query = query.where(Feedback.type == type)
    if module_tag:
        query = query.where(Feedback.module_tag == module_tag)
    if q:
        query = query.where(Feedback.message.ilike(f"%{q}%"))

    query = query.order_by(Feedback.created_at.desc())
    query = query.offset((page - 1) * per_page).limit(per_page)

    feedbacks = session.exec(query).all()
    return [_build_feedback_read(fb, session, current_user) for fb in feedbacks]


# ── 3. GET /stats — Admin istatistikleri ──────────────────

@router.get("/stats", response_model=FeedbackStats)
async def get_feedback_stats(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    if not _is_admin(current_user):
        raise HTTPException(403, "Admin only")

    all_feedbacks = session.exec(select(Feedback)).all()

    total = len(all_feedbacks)
    open_count = sum(1 for f in all_feedbacks if f.status == FeedbackStatus.OPEN.value)
    in_progress = sum(1 for f in all_feedbacks if f.status == FeedbackStatus.IN_PROGRESS.value)
    resolved = sum(1 for f in all_feedbacks if f.status == FeedbackStatus.RESOLVED.value)
    closed = sum(1 for f in all_feedbacks if f.status == FeedbackStatus.CLOSED.value)

    # By type
    by_type: dict[str, int] = {}
    for f in all_feedbacks:
        by_type[f.type] = by_type.get(f.type, 0) + 1

    # By module
    by_module: dict[str, int] = {}
    for f in all_feedbacks:
        tag = f.module_tag or "Diger"
        by_module[tag] = by_module.get(tag, 0) + 1

    # Avg resolution time
    resolution_hours = []
    for f in all_feedbacks:
        if f.resolved_at and f.created_at:
            delta = f.resolved_at - f.created_at
            resolution_hours.append(delta.total_seconds() / 3600)
    avg_resolution = round(sum(resolution_hours) / len(resolution_hours), 1) if resolution_hours else None

    # Satisfaction average
    scores = [f.satisfaction_score for f in all_feedbacks if f.satisfaction_score]
    satisfaction_avg = round(sum(scores) / len(scores), 1) if scores else None

    # This week resolved
    week_ago = datetime.now(TZ) - timedelta(days=7)
    this_week = sum(
        1 for f in all_feedbacks
        if f.resolved_at and f.resolved_at >= week_ago
    )

    return FeedbackStats(
        total=total,
        open=open_count,
        in_progress=in_progress,
        resolved=resolved,
        closed=closed,
        by_type=by_type,
        by_module=by_module,
        avg_resolution_hours=avg_resolution,
        satisfaction_avg=satisfaction_avg,
        this_week_resolved=this_week,
    )


# ── 4. GET /{id} — Detay + thread ────────────────────────

@router.get("/{feedback_id}", response_model=FeedbackDetail)
async def get_feedback_detail(
    feedback_id: int,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    fb = session.get(Feedback, feedback_id)
    if not fb:
        raise HTTPException(404, "Feedback not found")

    # Non-admin: sadece kendi
    if not _is_admin(current_user) and fb.user_id != current_user.id:
        raise HTTPException(403, "Bu geri bildirimi görme yetkiniz yok")

    base = _build_feedback_read(fb, session, current_user)

    # Replies
    reply_query = select(FeedbackReply).where(FeedbackReply.feedback_id == fb.id)
    # Non-admin: internal notları gösterme
    if not _is_admin(current_user):
        reply_query = reply_query.where(FeedbackReply.is_internal == False)
    reply_query = reply_query.order_by(FeedbackReply.created_at.asc())
    replies = session.exec(reply_query).all()

    reply_reads = []
    for r in replies:
        user = session.get(User, r.user_id)
        reply_reads.append(FeedbackReplyRead(
            id=r.id,
            feedback_id=r.feedback_id,
            user_id=r.user_id,
            message=r.message,
            attachment_url=r.attachment_url,
            is_internal=r.is_internal,
            created_at=r.created_at,
            user=_user_minimal(user),
        ))

    # Reactions
    reactions = session.exec(
        select(FeedbackReaction).where(FeedbackReaction.feedback_id == fb.id)
    ).all()
    reaction_reads = []
    for rx in reactions:
        user = session.get(User, rx.user_id)
        reaction_reads.append(FeedbackReactionRead(
            id=rx.id,
            feedback_id=rx.feedback_id,
            user_id=rx.user_id,
            emoji=rx.emoji,
            created_at=rx.created_at,
            user=_user_minimal(user),
        ))

    return FeedbackDetail(
        **base.model_dump(),
        replies=reply_reads,
        reactions=reaction_reads,
    )


# ── 5. POST /{id}/reply — Yanıt ekle ────────────────────

@router.post("/{feedback_id}/reply", response_model=FeedbackReplyRead, status_code=201)
async def add_reply(
    feedback_id: int,
    body: FeedbackReplyCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    fb = session.get(Feedback, feedback_id)
    if not fb:
        raise HTTPException(404, "Feedback not found")

    # Non-admin: sadece kendi feedback'ine yanıt verebilir, internal not yazamaz
    if not _is_admin(current_user):
        if fb.user_id != current_user.id:
            raise HTTPException(403, "Bu geri bildirimi yanıtlama yetkiniz yok")
        if body.is_internal:
            raise HTTPException(403, "Dahili not sadece admin yazabilir")

    reply = FeedbackReply(
        feedback_id=fb.id,
        user_id=current_user.id,
        message=body.message.strip(),
        is_internal=body.is_internal,
    )
    session.add(reply)

    # Admin yanıt verince status open → in_progress otomatik geçiş
    if _is_admin(current_user) and fb.status == FeedbackStatus.OPEN.value:
        fb.status = FeedbackStatus.IN_PROGRESS.value
        session.add(fb)

    session.commit()
    session.refresh(reply)

    logger.info("Feedback #%d reply by %s (internal=%s)", fb.id, current_user.username, body.is_internal)

    # Push bildirimi: admin yanıtı → kullanıcıya
    if _is_admin(current_user) and fb.user_id != current_user.id and not body.is_internal:
        try:
            from backend.services.core.push_notification import send_push_to_user
            send_push_to_user(
                session,
                user_id=fb.user_id,
                title="Geri Bildiriminize Yanıt",
                body=f"{current_user.display_name}: {body.message[:80]}",
                url=f"/feedback/{fb.id}",
            )
        except Exception as exc:
            logger.warning("Push notification failed: %s", exc)

    user = session.get(User, reply.user_id)
    return FeedbackReplyRead(
        id=reply.id,
        feedback_id=reply.feedback_id,
        user_id=reply.user_id,
        message=reply.message,
        attachment_url=reply.attachment_url,
        is_internal=reply.is_internal,
        created_at=reply.created_at,
        user=_user_minimal(user),
    )


# ── 6. PATCH /{id}/status — Status değiştir ──────────────

@router.patch("/{feedback_id}/status", response_model=FeedbackRead)
async def update_feedback_status(
    feedback_id: int,
    body: FeedbackStatusUpdate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    if not _is_admin(current_user):
        raise HTTPException(403, "Admin only")

    fb = session.get(Feedback, feedback_id)
    if not fb:
        raise HTTPException(404, "Feedback not found")

    valid_statuses = {s.value for s in FeedbackStatus}
    if body.status not in valid_statuses:
        raise HTTPException(422, f"status must be one of: {', '.join(valid_statuses)}")

    old_status = fb.status
    fb.status = body.status

    if body.status == FeedbackStatus.RESOLVED.value:
        fb.resolved_at = datetime.now(TZ)
        fb.resolved_by_id = current_user.id
    elif body.status == FeedbackStatus.OPEN.value:
        fb.resolved_at = None
        fb.resolved_by_id = None

    session.add(fb)
    session.commit()
    session.refresh(fb)

    logger.info("Feedback #%d status: %s → %s by %s", fb.id, old_status, body.status, current_user.username)

    # Push: çözüldü bildirimi
    if body.status == FeedbackStatus.RESOLVED.value and fb.user_id != current_user.id:
        try:
            from backend.services.core.push_notification import send_push_to_user
            send_push_to_user(
                session,
                user_id=fb.user_id,
                title="Geri Bildiriminiz Cozuldu",
                body="Gonderdiginiz geri bildirim incelendi ve cozuldu.",
                url=f"/feedback/{fb.id}",
            )
        except Exception as exc:
            logger.warning("Push notification failed: %s", exc)

    return _build_feedback_read(fb, session, current_user)


# ── 7. POST /{id}/react — Emoji reaction toggle ──────────

@router.post("/{feedback_id}/react", status_code=200)
async def toggle_reaction(
    feedback_id: int,
    body: FeedbackReactionCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    fb = session.get(Feedback, feedback_id)
    if not fb:
        raise HTTPException(404, "Feedback not found")

    valid_emojis = {"upvote", "me_too", "heart"}
    if body.emoji not in valid_emojis:
        raise HTTPException(422, f"emoji must be one of: {', '.join(valid_emojis)}")

    # Toggle: varsa kaldır, yoksa ekle
    existing = session.exec(
        select(FeedbackReaction)
        .where(FeedbackReaction.feedback_id == fb.id)
        .where(FeedbackReaction.user_id == current_user.id)
        .where(FeedbackReaction.emoji == body.emoji)
    ).first()

    if existing:
        session.delete(existing)
        session.commit()
        return {"action": "removed", "emoji": body.emoji}
    else:
        reaction = FeedbackReaction(
            feedback_id=fb.id,
            user_id=current_user.id,
            emoji=body.emoji,
        )
        session.add(reaction)
        session.commit()
        return {"action": "added", "emoji": body.emoji}


# ── 8. POST /upload-screenshot — pCloud screenshot upload ─

@router.post("/upload-screenshot")
async def upload_screenshot(
    file: UploadFile = File(...),
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    import base64

    if not file.filename:
        raise HTTPException(400, "Dosya adı bulunamadı")

    allowed_types = {"image/png", "image/jpeg", "image/webp"}
    content_type = file.content_type or "image/png"
    if content_type not in allowed_types:
        raise HTTPException(400, f"Desteklenmeyen format: {content_type}. PNG, JPEG veya WebP yükleyin.")

    content = await file.read()
    if not content:
        raise HTTPException(400, "Dosya boş")

    if len(content) > 5 * 1024 * 1024:
        raise HTTPException(400, "Dosya 5MB'dan büyük olamaz")

    # Önce pCloud'a yüklemeyi dene
    try:
        from backend.services.integrations.pcloud import PCloudService
        pcloud = PCloudService()
        pub_link, file_id = pcloud.upload_feedback_screenshot(content, file.filename or "screenshot.png")

        if pub_link:
            logger.info("Feedback screenshot uploaded to pCloud: user=%s file_id=%s", current_user.username, file_id)
            return {"url": pub_link, "file_id": file_id}
    except Exception as exc:
        logger.warning("pCloud upload failed, falling back to data URL: %s", exc)

    # Fallback: base64 data URL olarak dön — DB'de TEXT olarak saklanır
    b64 = base64.b64encode(content).decode("utf-8")
    data_url = f"data:{content_type};base64,{b64}"
    logger.info("Feedback screenshot stored as data URL: user=%s size=%d", current_user.username, len(content))
    return {"url": data_url, "file_id": None}


# ── Telegram Bildirim Helper ──────────────────────────────

TYPE_EMOJI = {
    "bug": "🐛",
    "feature": "💡",
    "question": "❓",
    "praise": "⭐",
}

PRIORITY_EMOJI = {
    "low": "🟢",
    "normal": "🔵",
    "high": "🟠",
    "critical": "🔴",
}


def _notify_feedback_telegram(fb: Feedback, user: User) -> bool:
    """Yeni feedback geldiğinde Telegram'a bildirim gönder."""
    try:
        from backend.services.integrations.telegram import send_telegram_message

        type_icon = TYPE_EMOJI.get(fb.type, "📝")
        priority_icon = PRIORITY_EMOJI.get(fb.priority, "🔵")
        module = fb.module_tag or "Genel"
        msg_preview = fb.message[:150] + ("..." if len(fb.message) > 150 else "")

        text = (
            f"{type_icon} <b>Yeni Geri Bildirim</b>\n\n"
            f"👤 {user.display_name or user.username}\n"
            f"📋 Tip: {fb.type.upper()} {priority_icon}\n"
            f"📍 Modül: {module}\n"
            f"💬 {msg_preview}\n\n"
            f"🔗 <a href='https://mme01.up.railway.app/yonetim/feedback'>Yönetim Paneli</a>"
        )
        return send_telegram_message(text)
    except Exception as exc:
        logger.warning("Telegram feedback notification failed: %s", exc)
        return False
