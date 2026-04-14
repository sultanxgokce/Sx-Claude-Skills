"""
M012 — Feedback & Co-Design Modülü

Kullanıcı geri bildirimi: bug, feature, question, praise.
Screenshot + annotation, chat thread, reaction desteği.
"""

from typing import Optional, TYPE_CHECKING
from datetime import datetime
from enum import Enum
from zoneinfo import ZoneInfo

from sqlmodel import SQLModel, Field, Relationship

if TYPE_CHECKING:
    from .user import User

TZ = ZoneInfo("Europe/Istanbul")


# ── Enum'lar ──────────────────────────────────────────────

class FeedbackType(str, Enum):
    BUG = "bug"
    FEATURE = "feature"
    QUESTION = "question"
    PRAISE = "praise"


class FeedbackPriority(str, Enum):
    LOW = "low"
    NORMAL = "normal"
    HIGH = "high"
    CRITICAL = "critical"


class FeedbackStatus(str, Enum):
    OPEN = "open"
    IN_PROGRESS = "in_progress"
    RESOLVED = "resolved"
    CLOSED = "closed"


# ── Feedback ──────────────────────────────────────────────

class Feedback(SQLModel, table=True):
    __tablename__ = "feedbacks"

    id: int | None = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id", index=True)

    type: str = Field(default=FeedbackType.BUG.value)
    priority: str = Field(default=FeedbackPriority.NORMAL.value)
    status: str = Field(default=FeedbackStatus.OPEN.value, index=True)

    message: str = Field(max_length=5000)
    current_url: str | None = Field(default=None, max_length=500)
    module_tag: str | None = Field(default=None, max_length=100, index=True)

    # Screenshot (TEXT — base64 data URL destekli)
    screenshot_url: str | None = Field(default=None)
    annotated_screenshot_url: str | None = Field(default=None)

    # Context
    browser_info: str | None = Field(default=None, max_length=1000)  # JSON string
    satisfaction_score: int | None = Field(default=None, ge=1, le=5)

    # Timestamps
    created_at: datetime = Field(default_factory=lambda: datetime.now(TZ))
    updated_at: datetime | None = Field(
        default=None,
        sa_column_kwargs={"onupdate": lambda: datetime.now(TZ)},
    )
    resolved_at: datetime | None = Field(default=None)
    resolved_by_id: int | None = Field(default=None, foreign_key="users.id")

    # Relationships
    user: Optional["User"] = Relationship(
        sa_relationship_kwargs={"foreign_keys": "Feedback.user_id"}
    )
    resolved_by: Optional["User"] = Relationship(
        sa_relationship_kwargs={"foreign_keys": "Feedback.resolved_by_id"}
    )
    replies: list["FeedbackReply"] = Relationship(back_populates="feedback")
    reactions: list["FeedbackReaction"] = Relationship(back_populates="feedback")


# ── FeedbackReply ─────────────────────────────────────────

class FeedbackReply(SQLModel, table=True):
    __tablename__ = "feedback_replies"

    id: int | None = Field(default=None, primary_key=True)
    feedback_id: int = Field(foreign_key="feedbacks.id", index=True)
    user_id: int = Field(foreign_key="users.id")

    message: str = Field(max_length=2000)
    attachment_url: str | None = Field(default=None, max_length=1000)
    is_internal: bool = Field(default=False)  # Admin-only dahili not

    created_at: datetime = Field(default_factory=lambda: datetime.now(TZ))

    # Relationships
    feedback: Optional["Feedback"] = Relationship(back_populates="replies")
    user: Optional["User"] = Relationship()


# ── FeedbackReaction ──────────────────────────────────────

class FeedbackReaction(SQLModel, table=True):
    __tablename__ = "feedback_reactions"

    id: int | None = Field(default=None, primary_key=True)
    feedback_id: int = Field(foreign_key="feedbacks.id", index=True)
    user_id: int = Field(foreign_key="users.id")
    emoji: str = Field(max_length=20)  # "upvote" | "me_too" | "heart"

    created_at: datetime = Field(default_factory=lambda: datetime.now(TZ))

    # Relationships
    feedback: Optional["Feedback"] = Relationship(back_populates="reactions")
    user: Optional["User"] = Relationship()


# ── Eski model uyumluluk (archive referansı) ─────────────

class SystemFeedback(SQLModel, table=True):
    """Eski feedback modeli — archive edilecek, yeni kod Feedback kullanır."""
    __tablename__ = "system_feedbacks"

    id: int | None = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id")
    type: str = Field(default="bug")
    message: str
    current_url: str | None = Field(default=None)
    status: str = Field(default="open")
    created_at: datetime = Field(
        default_factory=lambda: datetime.now(TZ)
    )
