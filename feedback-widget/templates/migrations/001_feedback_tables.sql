-- Feedback Widget — Migration v1.0.0
-- Idempotent: Güvenle tekrar çalıştırılabilir.
-- Bağımlılık: "users" tablosu mevcut olmalı.

-- ── feedbacks ──
CREATE TABLE IF NOT EXISTS feedbacks (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    type VARCHAR NOT NULL DEFAULT 'bug',
    priority VARCHAR NOT NULL DEFAULT 'normal',
    status VARCHAR NOT NULL DEFAULT 'open',
    message TEXT NOT NULL,
    current_url VARCHAR(500),
    module_tag VARCHAR(100),
    screenshot_url TEXT,
    annotated_screenshot_url TEXT,
    browser_info VARCHAR(1000),
    satisfaction_score INTEGER,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by_id INTEGER REFERENCES users(id)
);

-- ── feedback_replies ──
CREATE TABLE IF NOT EXISTS feedback_replies (
    id SERIAL PRIMARY KEY,
    feedback_id INTEGER NOT NULL REFERENCES feedbacks(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id),
    message TEXT NOT NULL,
    attachment_url TEXT,
    is_internal BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- ── feedback_reactions ──
CREATE TABLE IF NOT EXISTS feedback_reactions (
    id SERIAL PRIMARY KEY,
    feedback_id INTEGER NOT NULL REFERENCES feedbacks(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id),
    emoji VARCHAR(20) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(feedback_id, user_id, emoji)
);

-- ── Index'ler ──
CREATE INDEX IF NOT EXISTS idx_feedbacks_status ON feedbacks(status);
CREATE INDEX IF NOT EXISTS idx_feedbacks_user_id ON feedbacks(user_id);
CREATE INDEX IF NOT EXISTS idx_feedbacks_created_at ON feedbacks(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feedbacks_module_tag ON feedbacks(module_tag);
CREATE INDEX IF NOT EXISTS idx_feedback_replies_feedback_id ON feedback_replies(feedback_id);
CREATE INDEX IF NOT EXISTS idx_feedback_reactions_feedback_id ON feedback_reactions(feedback_id);
