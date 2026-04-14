"""
M012 — Feedback & Co-Design Schema'ları

Request/Response modelleri.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, Field

from backend.models.feedback import FeedbackType, FeedbackPriority, FeedbackStatus


# ── Embedded / Yardımcı ───────────────────────────────────

class UserMinimal(BaseModel):
    id: int
    display_name: str
    avatar_icon: str | None = None


# ── Feedback ──────────────────────────────────────────────

class FeedbackCreate(BaseModel):
    type: str = FeedbackType.BUG.value
    priority: str = FeedbackPriority.NORMAL.value
    message: str = Field(min_length=1, max_length=5000)
    current_url: str | None = None
    screenshot_url: str | None = None
    annotated_screenshot_url: str | None = None
    browser_info: str | None = None
    satisfaction_score: int | None = Field(default=None, ge=1, le=5)


class FeedbackRead(BaseModel):
    id: int
    user_id: int
    type: str
    priority: str
    status: str
    message: str
    current_url: str | None = None
    module_tag: str | None = None
    screenshot_url: str | None = None
    annotated_screenshot_url: str | None = None
    browser_info: str | None = None
    satisfaction_score: int | None = None
    created_at: datetime
    updated_at: datetime | None = None
    resolved_at: datetime | None = None
    resolved_by_id: int | None = None

    # Embedded
    user: UserMinimal | None = None
    resolved_by: UserMinimal | None = None
    reply_count: int = 0
    reaction_counts: dict[str, int] = {}  # {"upvote": 3, "me_too": 1, "heart": 2}
    has_unread_reply: bool = False

    model_config = {"from_attributes": True}


class FeedbackDetail(FeedbackRead):
    replies: list[FeedbackReplyRead] = []
    reactions: list[FeedbackReactionRead] = []


class FeedbackStatusUpdate(BaseModel):
    status: str  # FeedbackStatus value


# ── FeedbackReply ─────────────────────────────────────────

class FeedbackReplyCreate(BaseModel):
    message: str = Field(min_length=1, max_length=2000)
    is_internal: bool = False


class FeedbackReplyRead(BaseModel):
    id: int
    feedback_id: int
    user_id: int
    message: str
    attachment_url: str | None = None
    is_internal: bool = False
    created_at: datetime

    user: UserMinimal | None = None

    model_config = {"from_attributes": True}


# ── FeedbackReaction ──────────────────────────────────────

class FeedbackReactionCreate(BaseModel):
    emoji: str = Field(max_length=20)  # "upvote" | "me_too" | "heart"


class FeedbackReactionRead(BaseModel):
    id: int
    feedback_id: int
    user_id: int
    emoji: str
    created_at: datetime

    user: UserMinimal | None = None

    model_config = {"from_attributes": True}


# ── Stats (Admin Dashboard) ──────────────────────────────

class FeedbackStats(BaseModel):
    total: int = 0
    open: int = 0
    in_progress: int = 0
    resolved: int = 0
    closed: int = 0
    by_type: dict[str, int] = {}     # {"bug": 5, "feature": 3, ...}
    by_module: dict[str, int] = {}   # {"Finans": 2, "Cagrilar": 1, ...}
    avg_resolution_hours: float | None = None
    satisfaction_avg: float | None = None
    this_week_resolved: int = 0
