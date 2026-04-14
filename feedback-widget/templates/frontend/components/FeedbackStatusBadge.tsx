"use client";

import { cn } from "@/lib/utils";
import { FEEDBACK_STATUS_CONFIG, type FeedbackStatus } from "@/types/feedback";

export default function FeedbackStatusBadge({ status }: { status: FeedbackStatus }) {
    const cfg = FEEDBACK_STATUS_CONFIG[status] ?? FEEDBACK_STATUS_CONFIG.open;
    return (
        <span className={cn("inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-semibold", cfg.bg, cfg.color)}>
            {cfg.label}
        </span>
    );
}
