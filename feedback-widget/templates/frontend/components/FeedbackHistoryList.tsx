"use client";

import { cn } from "@/lib/utils";
import FeedbackStatusBadge from "./FeedbackStatusBadge";
import { FEEDBACK_TYPE_CONFIG, type FeedbackRead, type FeedbackStatus } from "@/types/feedback";

interface FeedbackHistoryListProps {
    feedbacks: FeedbackRead[];
    onSelect: (fb: FeedbackRead) => void;
    loading: boolean;
}

export default function FeedbackHistoryList({ feedbacks, onSelect, loading }: FeedbackHistoryListProps) {
    if (loading) {
        return (
            <div className="flex items-center justify-center py-12">
                <div className="w-6 h-6 border-2 border-blue-200 border-t-blue-500 rounded-full animate-spin" />
            </div>
        );
    }

    if (feedbacks.length === 0) {
        return (
            <div className="text-center py-12">
                <p className="text-4xl mb-2">💬</p>
                <p className="text-[13px] text-gray-400">Henüz geri bildiriminiz yok</p>
                <p className="text-[11px] text-gray-300 mt-1">Yeni sekmesinden bildirim gönderebilirsiniz</p>
            </div>
        );
    }

    return (
        <div className="space-y-2">
            {feedbacks.map((fb) => {
                const typeCfg = FEEDBACK_TYPE_CONFIG[fb.type];
                return (
                    <button
                        key={fb.id}
                        onClick={() => onSelect(fb)}
                        className="w-full text-left p-3 rounded-xl border border-gray-100 hover:border-gray-200 hover:bg-gray-50/50 transition-all cursor-pointer group"
                    >
                        <div className="flex items-start justify-between gap-2">
                            <div className="flex items-center gap-2 min-w-0">
                                <span className="text-base flex-shrink-0">{typeCfg?.icon || "📝"}</span>
                                <div className="min-w-0">
                                    <p className="text-[13px] font-medium text-gray-900 truncate">
                                        {fb.message.slice(0, 60)}{fb.message.length > 60 ? "..." : ""}
                                    </p>
                                    <div className="flex items-center gap-2 mt-1">
                                        <FeedbackStatusBadge status={fb.status} />
                                        {fb.reply_count > 0 && (
                                            <span className="text-[10px] text-gray-400">
                                                {fb.reply_count} yanıt
                                            </span>
                                        )}
                                    </div>
                                </div>
                            </div>
                            <div className="flex flex-col items-end gap-1 flex-shrink-0">
                                <span className="text-[10px] text-gray-300">
                                    {new Date(fb.created_at).toLocaleDateString("tr-TR", { day: "2-digit", month: "2-digit" })}
                                </span>
                                {fb.has_unread_reply && (
                                    <span className="w-2 h-2 rounded-full bg-blue-500" />
                                )}
                            </div>
                        </div>
                    </button>
                );
            })}
        </div>
    );
}
