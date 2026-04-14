"use client";

import { useState } from "react";
import { Send, Lock } from "lucide-react";
import { cn } from "@/lib/utils";
import { getSession } from "@/lib/api";
import type { FeedbackReplyRead } from "@/types/feedback";

interface FeedbackThreadProps {
    replies: FeedbackReplyRead[];
    onReply: (message: string, isInternal: boolean) => Promise<void>;
    isAdmin: boolean;
    currentUserId: number;
}

export default function FeedbackThread({ replies, onReply, isAdmin, currentUserId }: FeedbackThreadProps) {
    const [message, setMessage] = useState("");
    const [isInternal, setIsInternal] = useState(false);
    const [sending, setSending] = useState(false);

    const handleSend = async () => {
        if (!message.trim() || sending) return;
        setSending(true);
        try {
            await onReply(message.trim(), isInternal);
            setMessage("");
        } finally {
            setSending(false);
        }
    };

    const handleKeyDown = (e: React.KeyboardEvent) => {
        if (e.key === "Enter" && !e.shiftKey) {
            e.preventDefault();
            handleSend();
        }
    };

    return (
        <div className="flex flex-col h-full">
            {/* Messages */}
            <div className="flex-1 overflow-y-auto space-y-3 px-1 py-2">
                {replies.length === 0 ? (
                    <p className="text-center text-[12px] text-gray-300 py-6">Henüz yanıt yok</p>
                ) : (
                    replies.map((r) => {
                        const isMe = r.user_id === currentUserId;
                        const isAdminReply = r.user?.display_name && !isMe;
                        return (
                            <div
                                key={r.id}
                                className={cn(
                                    "max-w-[85%] rounded-2xl px-3.5 py-2.5",
                                    r.is_internal
                                        ? "bg-amber-50 border border-amber-200 ml-auto"
                                        : isMe
                                            ? "bg-blue-500 text-white ml-auto"
                                            : "bg-gray-100 text-gray-900 mr-auto"
                                )}
                            >
                                {/* Header */}
                                <div className={cn(
                                    "flex items-center gap-1.5 mb-1",
                                    isMe && !r.is_internal ? "text-white/70" : "text-gray-400"
                                )}>
                                    {r.user?.avatar_icon && (
                                        <span className="text-xs">{r.user.avatar_icon}</span>
                                    )}
                                    <span className="text-[10px] font-semibold">
                                        {r.user?.display_name || "Anonim"}
                                    </span>
                                    {r.is_internal && (
                                        <span className="flex items-center gap-0.5 text-[9px] text-amber-600 font-bold">
                                            <Lock className="w-2.5 h-2.5" /> Dahili
                                        </span>
                                    )}
                                    {isAdminReply && !r.is_internal && (
                                        <span className="text-[9px] bg-blue-100 text-blue-600 px-1.5 py-0.5 rounded-full font-bold">
                                            Admin
                                        </span>
                                    )}
                                </div>
                                {/* Body */}
                                <p className={cn(
                                    "text-[13px] leading-relaxed whitespace-pre-wrap",
                                    r.is_internal ? "text-amber-800" : ""
                                )}>
                                    {r.message}
                                </p>
                                {/* Attachment */}
                                {r.attachment_url && (
                                    <a
                                        href={r.attachment_url}
                                        target="_blank"
                                        rel="noopener noreferrer"
                                        className={cn(
                                            "inline-block mt-1.5 text-[11px] font-medium underline",
                                            isMe && !r.is_internal ? "text-white/80" : "text-blue-500"
                                        )}
                                    >
                                        📎 Ek dosya
                                    </a>
                                )}
                                {/* Time */}
                                <p className={cn(
                                    "text-[10px] mt-1",
                                    isMe && !r.is_internal ? "text-white/50" : "text-gray-300"
                                )}>
                                    {new Date(r.created_at).toLocaleString("tr-TR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" })}
                                </p>
                            </div>
                        );
                    })
                )}
            </div>

            {/* Reply Input */}
            <div className="border-t border-gray-100 pt-3 mt-2">
                {isAdmin && (
                    <label className="flex items-center gap-2 mb-2 cursor-pointer">
                        <input
                            type="checkbox"
                            checked={isInternal}
                            onChange={(e) => setIsInternal(e.target.checked)}
                            className="rounded border-amber-300 text-amber-500 focus:ring-amber-200"
                        />
                        <span className="text-[11px] text-amber-600 font-medium flex items-center gap-1">
                            <Lock className="w-3 h-3" /> Dahili Not
                        </span>
                    </label>
                )}
                <div className="flex gap-2">
                    <textarea
                        value={message}
                        onChange={(e) => setMessage(e.target.value)}
                        onKeyDown={handleKeyDown}
                        rows={2}
                        placeholder="Yanıt yazın..."
                        className={cn(
                            "flex-1 rounded-xl border px-3 py-2 text-[13px] resize-none focus:outline-none focus:ring-2 transition-all",
                            isInternal
                                ? "border-amber-200 bg-amber-50/50 focus:ring-amber-200 focus:border-amber-300"
                                : "border-gray-200 focus:ring-blue-200 focus:border-blue-400"
                        )}
                    />
                    <button
                        onClick={handleSend}
                        disabled={!message.trim() || sending}
                        className={cn(
                            "self-end px-3 py-2 rounded-xl transition-all cursor-pointer",
                            message.trim() && !sending
                                ? isInternal
                                    ? "bg-amber-500 text-white hover:bg-amber-600"
                                    : "bg-blue-500 text-white hover:bg-blue-600"
                                : "bg-gray-100 text-gray-300 cursor-not-allowed"
                        )}
                    >
                        {sending ? (
                            <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                        ) : (
                            <Send className="w-4 h-4" />
                        )}
                    </button>
                </div>
            </div>
        </div>
    );
}
