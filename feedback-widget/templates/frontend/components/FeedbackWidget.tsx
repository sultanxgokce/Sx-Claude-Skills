"use client";

import { useState, useEffect } from "react";
import { MessageCircle } from "lucide-react";
import { cn } from "@/lib/utils";
import { usePathname } from "next/navigation";
import { getSession } from "@/lib/api";
import { useFeedback } from "@/hooks/useFeedback";
import FeedbackPanel from "./FeedbackPanel";

export default function FeedbackWidget() {
    const pathname = usePathname();
    const session = getSession();
    const { unreadCount, fetchFeedbacks } = useFeedback();
    const [open, setOpen] = useState(false);

    // Login sayfasında ve admin feedback sayfasında gösterme
    const isLoginPage = pathname === "/" || pathname === "/login";
    const isAdminFeedbackPage = pathname === "/yonetim/feedback";
    const hidden = isLoginPage || isAdminFeedbackPage || !session;

    // İlk mount + panel kapandığında feedback'leri yenile (badge güncellemesi)
    const hasSession = !!session;
    useEffect(() => {
        if (!open && hasSession) {
            fetchFeedbacks();
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [open, hasSession]);

    if (hidden) return null;

    return (
        <>
            {/* Floating Button */}
            <button
                onClick={() => setOpen(true)}
                className={cn(
                    "fixed z-[70] w-10 h-10 md:w-12 md:h-12 rounded-full shadow-lg flex items-center justify-center transition-all duration-300 cursor-pointer group",
                    "bg-gradient-to-br from-blue-500 to-indigo-600 text-white",
                    "hover:shadow-xl hover:scale-110 active:scale-95",
                    // Mobilde bottom nav (h-16 + safe-area) üstünde, desktop'ta sağ alt
                    "feedback-widget-bottom right-4 md:right-6",
                    open && "scale-0 opacity-0"
                )}
                aria-label="Geri bildirim gönder"
            >
                <MessageCircle className="w-4 h-4 md:w-5 md:h-5" />

                {/* Unread badge */}
                {unreadCount > 0 && (
                    <span className="absolute -top-1 -right-1 w-5 h-5 bg-red-500 text-white text-[10px] font-bold rounded-full flex items-center justify-center shadow-sm animate-in zoom-in duration-200">
                        {unreadCount > 9 ? "9+" : unreadCount}
                    </span>
                )}

                {/* Tooltip */}
                <span className="pointer-events-none absolute right-full mr-3 px-2.5 py-1.5 bg-gray-900/90 text-white text-xs font-medium rounded-lg opacity-0 group-hover:opacity-100 transition-opacity duration-150 whitespace-nowrap shadow-lg hidden sm:block">
                    Geri Bildirim
                </span>
            </button>

            {/* Panel */}
            <FeedbackPanel open={open} onClose={() => setOpen(false)} />
        </>
    );
}
