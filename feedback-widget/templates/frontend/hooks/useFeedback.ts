"use client";

import { useState, useCallback } from "react";
import { apiFetch, authorizedFetch } from "@/lib/api";
import type {
    FeedbackRead, FeedbackDetail, FeedbackCreate, FeedbackStats,
    FeedbackListParams, FeedbackReplyRead,
} from "@/types/feedback";

const BASE = "/api/v1/feedback";

export function useFeedback() {
    const [feedbacks, setFeedbacks] = useState<FeedbackRead[]>([]);
    const [loading, setLoading] = useState(false);
    const [stats, setStats] = useState<FeedbackStats | null>(null);

    const fetchFeedbacks = useCallback(async (params?: FeedbackListParams) => {
        setLoading(true);
        try {
            const qs = new URLSearchParams();
            if (params?.status) qs.set("status", params.status);
            if (params?.type) qs.set("type", params.type);
            if (params?.module_tag) qs.set("module_tag", params.module_tag);
            if (params?.q) qs.set("q", params.q);
            if (params?.page) qs.set("page", String(params.page));
            if (params?.per_page) qs.set("per_page", String(params.per_page));
            const url = `${BASE}/?${qs.toString()}`;
            const data = await apiFetch<FeedbackRead[]>(url);
            setFeedbacks(data);
            return data;
        } finally {
            setLoading(false);
        }
    }, []);

    const fetchDetail = useCallback(async (id: number): Promise<FeedbackDetail> => {
        return apiFetch<FeedbackDetail>(`${BASE}/${id}`);
    }, []);

    const fetchStats = useCallback(async () => {
        const data = await apiFetch<FeedbackStats>(`${BASE}/stats`);
        setStats(data);
        return data;
    }, []);

    const submitFeedback = useCallback(async (data: FeedbackCreate): Promise<FeedbackRead> => {
        return apiFetch<FeedbackRead>(BASE + "/", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(data),
        });
    }, []);

    const uploadScreenshot = useCallback(async (blob: Blob, filename = "screenshot.png"): Promise<string> => {
        const formData = new FormData();
        formData.append("file", blob, filename);
        const res = await authorizedFetch(`${BASE}/upload-screenshot`, {
            method: "POST",
            body: formData,
        });
        if (!res.ok) throw new Error("Screenshot upload failed");
        const json = await res.json();
        return json.url;
    }, []);

    const addReply = useCallback(async (
        feedbackId: number,
        message: string,
        isInternal = false,
    ): Promise<FeedbackReplyRead> => {
        return apiFetch<FeedbackReplyRead>(`${BASE}/${feedbackId}/reply`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ message, is_internal: isInternal }),
        });
    }, []);

    const updateStatus = useCallback(async (feedbackId: number, status: string): Promise<FeedbackRead> => {
        return apiFetch<FeedbackRead>(`${BASE}/${feedbackId}/status`, {
            method: "PATCH",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ status }),
        });
    }, []);

    const toggleReaction = useCallback(async (feedbackId: number, emoji: string) => {
        return apiFetch<{ action: string; emoji: string }>(`${BASE}/${feedbackId}/react`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ emoji }),
        });
    }, []);

    // Unread count — user'ın has_unread_reply=true olan feedback sayısı
    const unreadCount = feedbacks.filter(f => f.has_unread_reply).length;

    return {
        feedbacks, loading, stats, unreadCount,
        fetchFeedbacks, fetchDetail, fetchStats,
        submitFeedback, uploadScreenshot,
        addReply, updateStatus, toggleReaction,
    };
}
