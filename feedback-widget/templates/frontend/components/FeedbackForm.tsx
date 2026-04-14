"use client";

import { useState, useRef, useEffect } from "react";
import { Send, Camera, ImagePlus, X as XIcon, Pencil } from "lucide-react";
import { cn } from "@/lib/utils";
import { usePathname } from "next/navigation";
import {
    FEEDBACK_TYPE_CONFIG, FEEDBACK_PRIORITY_CONFIG, SATISFACTION_EMOJIS,
    type FeedbackType, type FeedbackPriority, type FeedbackCreate,
} from "@/types/feedback";

interface FeedbackFormProps {
    onSubmit: (data: FeedbackCreate) => Promise<void>;
    onScreenshotUpload: (blob: Blob) => void;
    onScreenshotCapture: () => void;
    screenshots: { blob: Blob; url: string }[];
    onRemoveScreenshot: (index: number) => void;
    onAnnotateScreenshot: (index: number) => void;
    submitting: boolean;
    capturing: boolean;
}

const TYPES: FeedbackType[] = ["bug", "feature", "question", "praise"];
const PRIORITIES: FeedbackPriority[] = ["low", "normal", "high", "critical"];

export default function FeedbackForm({
    onSubmit, onScreenshotUpload, onScreenshotCapture, screenshots,
    onRemoveScreenshot, onAnnotateScreenshot, submitting, capturing,
}: FeedbackFormProps) {
    const pathname = usePathname();
    const SS_KEY = "feedback_draft";

    const loadDraft = () => {
        try {
            const raw = sessionStorage.getItem(SS_KEY);
            return raw ? JSON.parse(raw) : null;
        } catch { return null; }
    };
    const draft = loadDraft();

    const [type, setType] = useState<FeedbackType>(draft?.type || "bug");
    const [priority, setPriority] = useState<FeedbackPriority>(draft?.priority || "normal");
    const [message, setMessage] = useState(draft?.message || "");
    const [satisfaction, setSatisfaction] = useState<number | null>(draft?.satisfaction ?? null);
    const [uploading, setUploading] = useState(false);
    const fileInputRef = useRef<HTMLInputElement>(null);

    useEffect(() => {
        sessionStorage.setItem(SS_KEY, JSON.stringify({ type, priority, message, satisfaction }));
    }, [type, priority, message, satisfaction]);

    const showPriority = type === "bug" || type === "feature";
    const cfg = FEEDBACK_TYPE_CONFIG[type];

    const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;
        if (file.size > 5 * 1024 * 1024) {
            alert("Dosya 5MB'dan büyük olamaz.");
            return;
        }
        setUploading(true);
        try {
            onScreenshotUpload(file);
        } finally {
            setUploading(false);
            if (fileInputRef.current) fileInputRef.current.value = "";
        }
    };

    const handleSubmit = async () => {
        if (!message.trim() || submitting) return;

        const browserInfo = JSON.stringify({
            userAgent: navigator.userAgent,
            viewport: { w: window.innerWidth, h: window.innerHeight },
            platform: navigator.platform,
        });

        await onSubmit({
            type,
            priority: showPriority ? priority : "normal",
            message: message.trim(),
            current_url: pathname,
            browser_info: browserInfo,
            satisfaction_score: satisfaction,
        });

        setMessage("");
        setSatisfaction(null);
        setType("bug");
        setPriority("normal");
        sessionStorage.removeItem(SS_KEY);
    };

    return (
        <div className="space-y-4">
            {/* ── Tip Seçimi ── */}
            <div className="grid grid-cols-2 gap-2">
                {TYPES.map((t) => {
                    const tc = FEEDBACK_TYPE_CONFIG[t];
                    return (
                        <button
                            key={t}
                            type="button"
                            onClick={() => setType(t)}
                            className={cn(
                                "flex items-center gap-2 px-3 py-2.5 rounded-xl text-[12px] font-semibold transition-all duration-200 border",
                                type === t
                                    ? `${tc.bg} ${tc.color} ${tc.border}`
                                    : "bg-gray-50 text-gray-400 border-transparent hover:bg-gray-100"
                            )}
                        >
                            <span className="text-base">{tc.icon}</span>
                            {tc.label}
                        </button>
                    );
                })}
            </div>

            {/* ── Öncelik (bug/feature) ── */}
            {showPriority && (
                <div>
                    <label className="text-[11px] font-semibold text-gray-500 mb-1.5 block">Öncelik</label>
                    <div className="flex gap-1.5">
                        {PRIORITIES.map((p) => {
                            const pc = FEEDBACK_PRIORITY_CONFIG[p];
                            return (
                                <button
                                    key={p}
                                    type="button"
                                    onClick={() => setPriority(p)}
                                    className={cn(
                                        "flex-1 flex items-center justify-center gap-1 py-1.5 rounded-lg text-[11px] font-medium transition-all border",
                                        priority === p
                                            ? `bg-white ${pc.color} border-current shadow-sm`
                                            : "bg-gray-50 text-gray-400 border-transparent hover:bg-gray-100"
                                    )}
                                >
                                    <span className="text-xs">{pc.icon}</span>
                                    {pc.label}
                                </button>
                            );
                        })}
                    </div>
                </div>
            )}

            {/* ── Mesaj ── */}
            <div>
                <label className="text-[11px] font-semibold text-gray-500 mb-1 block">
                    Mesajınız <span className="text-red-400">*</span>
                </label>
                <textarea
                    value={message}
                    onChange={(e) => setMessage(e.target.value)}
                    rows={4}
                    maxLength={5000}
                    placeholder={cfg.placeholder}
                    className="w-full rounded-xl border border-gray-200 px-3 py-2.5 text-[13px] text-gray-900 placeholder:text-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400 resize-none transition-all"
                />
                <div className="flex items-center justify-between mt-1">
                    <p className="text-[10px] text-gray-300">📍 {pathname}</p>
                    <p className="text-[10px] text-gray-300">{message.length}/5000</p>
                </div>
            </div>

            {/* ── Görseller ── */}
            <div>
                <input
                    ref={fileInputRef}
                    type="file"
                    accept="image/png,image/jpeg,image/webp"
                    className="hidden"
                    onChange={handleFileSelect}
                />

                {/* Eklenen görseller */}
                {screenshots.length > 0 && (
                    <div className="flex gap-2 flex-wrap mb-2">
                        {screenshots.map((s, i) => (
                            <div key={i} className="relative group w-16 h-16">
                                <img
                                    src={s.url}
                                    alt={`Görsel ${i + 1}`}
                                    className="w-16 h-16 rounded-lg object-cover border border-gray-200"
                                />
                                {/* Hover overlay */}
                                <div className="absolute inset-0 bg-black/40 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-1">
                                    <button
                                        type="button"
                                        onClick={() => onAnnotateScreenshot(i)}
                                        className="w-6 h-6 rounded-full bg-blue-500 flex items-center justify-center text-white"
                                        title="İşaretle"
                                    >
                                        <Pencil className="w-3 h-3" />
                                    </button>
                                    <button
                                        type="button"
                                        onClick={() => onRemoveScreenshot(i)}
                                        className="w-6 h-6 rounded-full bg-red-500 flex items-center justify-center text-white"
                                        title="Kaldır"
                                    >
                                        <XIcon className="w-3 h-3" />
                                    </button>
                                </div>
                            </div>
                        ))}
                    </div>
                )}

                {/* Ekleme butonları */}
                <div className="flex gap-2">
                    {/* Ekran Görüntüsü — desktop only */}
                    <button
                        type="button"
                        onClick={onScreenshotCapture}
                        disabled={capturing || uploading}
                        className="hidden md:flex items-center gap-1.5 px-3 py-2 rounded-lg bg-gray-50 text-gray-500 text-[12px] font-medium hover:bg-gray-100 active:bg-gray-200 transition-colors border border-gray-200"
                    >
                        {capturing ? (
                            <>
                                <div className="w-3.5 h-3.5 border-2 border-gray-300 border-t-gray-600 rounded-full animate-spin" />
                                Yakalanıyor...
                            </>
                        ) : (
                            <>
                                <Camera className="w-3.5 h-3.5" />
                                Ekran Görüntüsü
                            </>
                        )}
                    </button>

                    {/* Dosyadan Yükle */}
                    <button
                        type="button"
                        onClick={() => fileInputRef.current?.click()}
                        disabled={uploading || capturing}
                        className="flex items-center gap-1.5 px-3 py-2 rounded-lg bg-gray-50 text-gray-500 text-[12px] font-medium hover:bg-gray-100 active:bg-gray-200 transition-colors border border-gray-200"
                    >
                        {uploading ? (
                            <>
                                <div className="w-3.5 h-3.5 border-2 border-gray-300 border-t-gray-600 rounded-full animate-spin" />
                                Yükleniyor...
                            </>
                        ) : (
                            <>
                                <ImagePlus className="w-3.5 h-3.5" />
                                Görsel Ekle
                            </>
                        )}
                    </button>
                </div>
            </div>

            {/* ── Memnuniyet ── */}
            <div>
                <label className="text-[11px] font-semibold text-gray-500 mb-1.5 block">
                    Genel deneyim puanınız <span className="text-[10px] text-gray-300">(opsiyonel)</span>
                </label>
                <div className="flex gap-2">
                    {SATISFACTION_EMOJIS.map((emoji, idx) => (
                        <button
                            key={idx}
                            type="button"
                            onClick={() => setSatisfaction(satisfaction === idx + 1 ? null : idx + 1)}
                            className={cn(
                                "w-9 h-9 rounded-full flex items-center justify-center text-lg transition-all border-2",
                                satisfaction === idx + 1
                                    ? "border-blue-400 bg-blue-50 scale-110"
                                    : "border-transparent bg-gray-50 hover:bg-gray-100 hover:scale-105"
                            )}
                        >
                            {emoji}
                        </button>
                    ))}
                </div>
            </div>

            {/* ── Gönder ── */}
            <button
                type="button"
                onClick={handleSubmit}
                disabled={!message.trim() || submitting}
                className={cn(
                    "w-full py-2.5 rounded-xl text-[13px] font-bold transition-all duration-200 flex items-center justify-center gap-2",
                    message.trim() && !submitting
                        ? "bg-gradient-to-r from-blue-500 to-blue-600 text-white hover:from-blue-600 hover:to-blue-700 shadow-sm active:scale-[0.98]"
                        : "bg-gray-100 text-gray-300"
                )}
            >
                {submitting ? (
                    <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                ) : (
                    <>
                        <Send className="w-3.5 h-3.5" />
                        Gönder
                    </>
                )}
            </button>
        </div>
    );
}
