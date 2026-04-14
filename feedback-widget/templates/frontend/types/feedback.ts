/* M012 — Feedback & Co-Design Types */

export type FeedbackType = "bug" | "feature" | "question" | "praise";
export type FeedbackPriority = "low" | "normal" | "high" | "critical";
export type FeedbackStatus = "open" | "in_progress" | "resolved" | "closed";

export interface UserMinimal {
    id: number;
    display_name: string;
    avatar_icon: string | null;
}

export interface FeedbackRead {
    id: number;
    user_id: number;
    type: FeedbackType;
    priority: FeedbackPriority;
    status: FeedbackStatus;
    message: string;
    current_url: string | null;
    module_tag: string | null;
    screenshot_url: string | null;
    annotated_screenshot_url: string | null;
    browser_info: string | null;
    satisfaction_score: number | null;
    created_at: string;
    updated_at: string | null;
    resolved_at: string | null;
    resolved_by_id: number | null;
    user: UserMinimal | null;
    resolved_by: UserMinimal | null;
    reply_count: number;
    reaction_counts: Record<string, number>;
    has_unread_reply: boolean;
}

export interface FeedbackReplyRead {
    id: number;
    feedback_id: number;
    user_id: number;
    message: string;
    attachment_url: string | null;
    is_internal: boolean;
    created_at: string;
    user: UserMinimal | null;
}

export interface FeedbackReactionRead {
    id: number;
    feedback_id: number;
    user_id: number;
    emoji: string;
    created_at: string;
    user: UserMinimal | null;
}

export interface FeedbackDetail extends FeedbackRead {
    replies: FeedbackReplyRead[];
    reactions: FeedbackReactionRead[];
}

export interface FeedbackCreate {
    type: FeedbackType;
    priority: FeedbackPriority;
    message: string;
    current_url?: string | null;
    screenshot_url?: string | null;
    annotated_screenshot_url?: string | null;
    browser_info?: string | null;
    satisfaction_score?: number | null;
}

export interface FeedbackStats {
    total: number;
    open: number;
    in_progress: number;
    resolved: number;
    closed: number;
    by_type: Record<string, number>;
    by_module: Record<string, number>;
    avg_resolution_hours: number | null;
    satisfaction_avg: number | null;
    this_week_resolved: number;
}

export interface FeedbackListParams {
    status?: string;
    type?: string;
    module_tag?: string;
    q?: string;
    page?: number;
    per_page?: number;
}

/* ── UI Config ──────────────────────────────────────────── */

export const FEEDBACK_TYPE_CONFIG: Record<FeedbackType, { label: string; icon: string; color: string; bg: string; border: string; placeholder: string }> = {
    bug:      { label: "Hata",    icon: "🐛", color: "text-red-600",    bg: "bg-red-50",    border: "border-red-200",    placeholder: "Ne olmasını bekliyordun? Ne oldu?" },
    feature:  { label: "Fikir",   icon: "💡", color: "text-amber-600",  bg: "bg-amber-50",  border: "border-amber-200",  placeholder: "Nasıl olmasını hayal ediyorsun?" },
    question: { label: "Soru",    icon: "❓", color: "text-blue-600",   bg: "bg-blue-50",   border: "border-blue-200",   placeholder: "Neyi merak ediyorsun?" },
    praise:   { label: "Beğeni",  icon: "⭐", color: "text-purple-600", bg: "bg-purple-50", border: "border-purple-200", placeholder: "Neyi beğendin? Neden hoş buldun?" },
};

export const FEEDBACK_PRIORITY_CONFIG: Record<FeedbackPriority, { label: string; icon: string; color: string }> = {
    low:      { label: "Düşük",    icon: "🟢", color: "text-green-600" },
    normal:   { label: "Normal",   icon: "🔵", color: "text-blue-600" },
    high:     { label: "Yüksek",   icon: "🟠", color: "text-orange-600" },
    critical: { label: "Kritik",   icon: "🔴", color: "text-red-600" },
};

export const FEEDBACK_STATUS_CONFIG: Record<FeedbackStatus, { label: string; color: string; bg: string }> = {
    open:        { label: "Açık",        color: "text-green-700",  bg: "bg-green-50" },
    in_progress: { label: "İnceleniyor", color: "text-blue-700",   bg: "bg-blue-50" },
    resolved:    { label: "Çözüldü",     color: "text-purple-700", bg: "bg-purple-50" },
    closed:      { label: "Kapandı",     color: "text-gray-500",   bg: "bg-gray-100" },
};

export const SATISFACTION_EMOJIS = ["😡", "😕", "😐", "🙂", "😍"] as const;
