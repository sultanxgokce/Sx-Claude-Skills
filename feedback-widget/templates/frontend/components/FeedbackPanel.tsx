"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { X, MessageSquarePlus, History, ArrowLeft, CheckCircle2 } from "lucide-react";
import { cn } from "@/lib/utils";
import { getSession } from "@/lib/api";
import { useFeedback } from "@/hooks/useFeedback";
import FeedbackForm from "./FeedbackForm";
import FeedbackHistoryList from "./FeedbackHistoryList";
import FeedbackThread from "./FeedbackThread";
import FeedbackStatusBadge from "./FeedbackStatusBadge";
import AnnotationCanvas from "./AnnotationCanvas";
import { FEEDBACK_TYPE_CONFIG, type FeedbackRead, type FeedbackDetail, type FeedbackCreate } from "@/types/feedback";

interface FeedbackPanelProps {
    open: boolean;
    onClose: () => void;
}

type PanelView = "form" | "history" | "thread";

export default function FeedbackPanel({ open, onClose }: FeedbackPanelProps) {
    const session = getSession();
    const isAdmin = session?.role === "admin";
    const currentUserId = session?.userId ?? 0;

    const { feedbacks, loading, fetchFeedbacks, fetchDetail, submitFeedback, uploadScreenshot, addReply } = useFeedback();

    const [view, setView] = useState<PanelView>("form");
    const [selectedFb, setSelectedFb] = useState<FeedbackDetail | null>(null);
    const [screenshots, setScreenshots] = useState<{ blob: Blob; url: string }[]>([]);
    const screenshotsRef = useRef<{ blob: Blob; url: string }[]>([]);
    const [annotatingIndex, setAnnotatingIndex] = useState<number | null>(null);
    const [submitting, setSubmitting] = useState(false);
    const [submitted, setSubmitted] = useState(false);
    const [visible, setVisible] = useState(false);
    const [capturing, setCapturing] = useState(false);

    // screenshotsRef'i her zaman güncel tut (stale closure önlemek için)
    useEffect(() => { screenshotsRef.current = screenshots; }, [screenshots]);

    // Sayfa yenilendiğinde screenshots'ları sessionStorage'dan geri yükle
    useEffect(() => {
        try {
            const saved = sessionStorage.getItem("feedback_screenshots");
            if (saved && screenshots.length === 0) {
                const dataUrls: string[] = JSON.parse(saved);
                const restored: { blob: Blob; url: string }[] = [];
                for (const dataUrl of dataUrls) {
                    const byteString = atob(dataUrl.split(",")[1]);
                    const mimeString = dataUrl.split(",")[0].split(":")[1].split(";")[0];
                    const ab = new ArrayBuffer(byteString.length);
                    const ia = new Uint8Array(ab);
                    for (let i = 0; i < byteString.length; i++) ia[i] = byteString.charCodeAt(i);
                    const blob = new Blob([ab], { type: mimeString });
                    restored.push({ blob, url: URL.createObjectURL(blob) });
                }
                if (restored.length > 0) setScreenshots(restored);
            }
        } catch { /* corrupted data, ignore */ }
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    // Screenshots değiştiğinde sessionStorage'a kaydet (JPEG sıkıştırma)
    useEffect(() => {
        if (screenshots.length === 0) {
            sessionStorage.removeItem("feedback_screenshots");
            return;
        }
        // Her blob'u küçük JPEG'e çevir ve kaydet
        const promises = screenshots.map((s) => new Promise<string>((resolve) => {
            const img = new Image();
            img.onload = () => {
                const canvas = document.createElement("canvas");
                const scale = Math.min(1, 600 / img.width);
                canvas.width = img.width * scale;
                canvas.height = img.height * scale;
                canvas.getContext("2d")!.drawImage(img, 0, 0, canvas.width, canvas.height);
                resolve(canvas.toDataURL("image/jpeg", 0.5));
                URL.revokeObjectURL(img.src);
            };
            img.src = URL.createObjectURL(s.blob);
        }));
        Promise.all(promises).then((dataUrls) => {
            try { sessionStorage.setItem("feedback_screenshots", JSON.stringify(dataUrls)); } catch { /* quota */ }
        });
    }, [screenshots]);

    // Animate in/out
    useEffect(() => {
        if (open) {
            requestAnimationFrame(() => setVisible(true));
            fetchFeedbacks();
        } else {
            setVisible(false);
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [open]);

    const handleClose = useCallback(() => {
        setVisible(false);
        setTimeout(onClose, 200);
    }, [onClose]);

    const handleSelectFeedback = useCallback(async (fb: FeedbackRead) => {
        const detail = await fetchDetail(fb.id);
        setSelectedFb(detail);
        setView("thread");
    }, [fetchDetail]);

    const handleSubmit = useCallback(async (data: FeedbackCreate) => {
        setSubmitting(true);
        try {
            let finalData = { ...data };
            // Tüm blob'ları pCloud'a yükle
            if (screenshots.length > 0) {
                const uploadedUrls: string[] = [];
                let uploadErrors = 0;
                for (const s of screenshots) {
                    try {
                        const url = await uploadScreenshot(s.blob);
                        if (url) uploadedUrls.push(url);
                    } catch (err) {
                        uploadErrors++;
                        console.error("Screenshot upload failed:", err);
                    }
                }
                if (uploadedUrls.length > 0) {
                    finalData.screenshot_url = uploadedUrls[0];
                    if (uploadedUrls.length > 1) {
                        finalData.annotated_screenshot_url = uploadedUrls.slice(1).join("|");
                    }
                }
                if (uploadErrors > 0) {
                    console.warn(`⚠️ ${uploadErrors}/${screenshots.length} görsel yüklenemedi. Yüklenen: ${uploadedUrls.length}`);
                }
                if (uploadedUrls.length === 0 && screenshots.length > 0) {
                    console.error("Tüm görsel yüklemeleri başarısız — görselsiz gönderiliyor");
                }
            }

            await submitFeedback(finalData);
            setSubmitted(true);
            setScreenshots([]);
            sessionStorage.removeItem("feedback_screenshots");
            setTimeout(() => {
                setSubmitted(false);
                setView("history");
                fetchFeedbacks();
            }, 1800);
        } finally {
            setSubmitting(false);
        }
    }, [submitFeedback, fetchFeedbacks, screenshots, uploadScreenshot]);

    // Dosya seçildiğinde — listeye ekle
    const handleScreenshotUpload = useCallback((blob: Blob) => {
        setScreenshots((prev) => [...prev, { blob, url: URL.createObjectURL(blob) }]);
    }, []);

    // Screenshot capture — Screen Capture API
    // 1. İzin al → 2. Panel gizle → 3. Temiz kare yakala → 4. Annotation aç
    const handleScreenshotCapture = useCallback(async () => {
        setCapturing(true);
        try {
            // 1. İzin al (panel hâlâ görünür — kullanıcı neyi yakalayacağını görsün)
            const mediaStream = await navigator.mediaDevices.getDisplayMedia({
                video: { displaySurface: "browser" } as MediaTrackConstraints,
                audio: false,
                preferCurrentTab: true,
            } as DisplayMediaStreamOptions);

            // 2. İzin alındı — paneli tamamen DOM'dan kaldır (display:none)
            //    visibility:hidden yetmez, Screen Capture DOM render'ı yakalar
            const panelEl = document.getElementById("feedback-panel-root");
            const backdropEl = document.getElementById("feedback-panel-backdrop");
            const widgetEl = document.querySelector("[aria-label='Geri bildirim gönder']") as HTMLElement | null;
            if (panelEl) panelEl.style.display = "none";
            if (backdropEl) backdropEl.style.display = "none";
            if (widgetEl) widgetEl.style.display = "none";

            // 3. Video stream başlat ve temiz kare bekle
            const track = mediaStream.getVideoTracks()[0];
            const settings = track.getSettings();
            const w = settings.width || window.innerWidth;
            const h = settings.height || window.innerHeight;

            const video = document.createElement("video");
            video.srcObject = mediaStream;
            video.autoplay = true;
            video.playsInline = true;
            await new Promise<void>((resolve) => {
                video.onloadeddata = () => resolve();
            });

            // Panel gizlendikten sonra birkaç kare bekle — eski frame'ler flush olsun
            // requestVideoFrameCallback ile gerçek yeni kareyi bekle
            if ("requestVideoFrameCallback" in video) {
                await new Promise<void>((resolve) => {
                    let frameCount = 0;
                    const waitFrames = () => {
                        (video as HTMLVideoElement & { requestVideoFrameCallback: (cb: () => void) => void })
                            .requestVideoFrameCallback(() => {
                                frameCount++;
                                if (frameCount >= 3) resolve(); // 3 taze kare bekle
                                else waitFrames();
                            });
                    };
                    waitFrames();
                    // Fallback timeout
                    setTimeout(resolve, 1500);
                });
            } else {
                await new Promise((r) => setTimeout(r, 1200));
            }

            // Güncel (temiz) kareyi yakala
            const canvas = document.createElement("canvas");
            canvas.width = w;
            canvas.height = h;
            const ctx = canvas.getContext("2d")!;
            ctx.drawImage(video, 0, 0, w, h);

            mediaStream.getTracks().forEach((t) => t.stop());

            // Panel'i geri göster
            if (panelEl) panelEl.style.display = "";
            if (backdropEl) backdropEl.style.display = "";
            if (widgetEl) widgetEl.style.display = "";

            const blob = await new Promise<Blob>((resolve, reject) => {
                canvas.toBlob((b) => (b ? resolve(b) : reject(new Error("toBlob null"))), "image/png");
            });

            // 4. Annotation editörünü otomatik aç — yeni capture'ı geçici olarak sakla
            // screenshotsRef kullan: handleScreenshotCapture [] deps ile yaratıldığından
            // screenshots closure'da her zaman [] görünür (stale closure). Ref her zaman günceldir.
            const newIndex = screenshotsRef.current.length;
            setScreenshots((prev) => [...prev, { blob, url: URL.createObjectURL(blob) }]);
            setAnnotatingIndex(newIndex);
        } catch (err: unknown) {
            // Panel'i göster (hata durumunda)
            document.getElementById("feedback-panel-root")?.style.removeProperty("visibility");
            document.getElementById("feedback-panel-backdrop")?.style.removeProperty("visibility");
            document.querySelector("[aria-label='Geri bildirim gönder']")?.removeAttribute("style");

            const msg = err instanceof Error ? err.message : "";
            if (!msg.includes("Permission") && !msg.includes("denied") && !msg.includes("cancel") && !msg.includes("AbortError") && !msg.includes("NotAllowedError")) {
                console.error("Screenshot capture failed:", err);
                alert("Ekran görüntüsü alınamadı. Görsel Ekle ile dosyadan yükleyebilirsiniz.");
            }
        } finally {
            setCapturing(false);
        }
    }, []);

    // Annotation tamamlandığında — ilgili screenshot'ı güncelle
    const handleAnnotationSave = useCallback((annotatedBlob: Blob) => {
        if (annotatingIndex !== null) {
            setScreenshots((prev) => prev.map((s, i) =>
                i === annotatingIndex ? { blob: annotatedBlob, url: URL.createObjectURL(annotatedBlob) } : s
            ));
        }
        setAnnotatingIndex(null);
    }, [annotatingIndex]);

    const handleReply = useCallback(async (message: string, isInternal: boolean) => {
        if (!selectedFb) return;
        const newReply = await addReply(selectedFb.id, message, isInternal);
        setSelectedFb((prev) => prev ? {
            ...prev,
            replies: [...prev.replies, newReply],
        } : null);
    }, [selectedFb, addReply]);

    // Annotation overlay — panel'in üstünde tam ekran
    if (annotatingIndex !== null && screenshots[annotatingIndex]) {
        return (
            <AnnotationCanvas
                imageBlob={screenshots[annotatingIndex].blob}
                onSave={handleAnnotationSave}
                onCancel={() => setAnnotatingIndex(null)}
            />
        );
    }

    if (!open) return null;

    return (
        <>
            {/* Backdrop — sadece desktop'ta */}
            <div
                id="feedback-panel-backdrop"
                className={cn(
                    "fixed inset-0 z-[70] transition-opacity duration-200",
                    "hidden md:block",
                    visible ? "bg-black/20 backdrop-blur-sm" : "bg-transparent"
                )}
                onClick={handleClose}
            />

            {/* Panel */}
            <div
                id="feedback-panel-root"
                className={cn(
                    "fixed inset-0 md:inset-auto md:right-0 md:top-0 md:h-full md:w-full md:max-w-md",
                    "bg-white shadow-2xl z-[71] flex flex-col",
                    "transition-transform duration-200 ease-out",
                    visible ? "translate-x-0" : "translate-x-full"
                )}
            >
                {/* Header */}
                <div
                    className="flex items-center justify-between px-4 pb-3 border-b border-gray-100 shrink-0"
                    style={{ paddingTop: "calc(env(safe-area-inset-top, 0px) + 16px)" }}
                >
                    <div className="flex items-center gap-2">
                        {view === "thread" && (
                            <button
                                type="button"
                                onClick={() => { setView("history"); setSelectedFb(null); }}
                                className="w-8 h-8 rounded-full bg-gray-100 flex items-center justify-center text-gray-500 hover:bg-gray-200 transition-colors active:bg-gray-300"
                            >
                                <ArrowLeft className="w-4 h-4" />
                            </button>
                        )}
                        <h2 className="text-[15px] font-bold text-gray-900">
                            {view === "form" ? "Geri Bildirim" : view === "history" ? "Geçmişim" : (
                                <span className="flex items-center gap-1.5">
                                    {FEEDBACK_TYPE_CONFIG[selectedFb?.type ?? "bug"]?.icon}
                                    #{selectedFb?.id}
                                </span>
                            )}
                        </h2>
                    </div>
                    <button
                        type="button"
                        onClick={handleClose}
                        className="w-10 h-10 -mr-2 rounded-full flex items-center justify-center text-gray-400 hover:bg-gray-100 active:bg-gray-200 transition-colors"
                    >
                        <X className="w-5 h-5" />
                    </button>
                </div>

                {/* Tab Toggle */}
                {view !== "thread" && (
                    <div className="flex border-b border-gray-100 shrink-0">
                        <button
                            type="button"
                            onClick={() => setView("form")}
                            className={cn(
                                "flex-1 flex items-center justify-center gap-1.5 py-2.5 text-[12px] font-semibold transition-all border-b-2",
                                view === "form"
                                    ? "text-blue-600 border-blue-500"
                                    : "text-gray-400 border-transparent hover:text-gray-500"
                            )}
                        >
                            <MessageSquarePlus className="w-3.5 h-3.5" />
                            Yeni Bildirim
                        </button>
                        <button
                            type="button"
                            onClick={() => setView("history")}
                            className={cn(
                                "flex-1 flex items-center justify-center gap-1.5 py-2.5 text-[12px] font-semibold transition-all border-b-2 relative",
                                view === "history"
                                    ? "text-blue-600 border-blue-500"
                                    : "text-gray-400 border-transparent hover:text-gray-500"
                            )}
                        >
                            <History className="w-3.5 h-3.5" />
                            Geçmişim
                            {feedbacks.some(f => f.has_unread_reply) && (
                                <span className="absolute top-2 right-[calc(50%-30px)] w-2 h-2 bg-blue-500 rounded-full" />
                            )}
                        </button>
                    </div>
                )}

                {/* Content */}
                <div
                    className="flex-1 overflow-y-auto px-4 py-4"
                    style={{ paddingBottom: "calc(env(safe-area-inset-bottom, 0px) + 16px)" }}
                >
                    {view === "form" && !submitted && (
                        <FeedbackForm
                            onSubmit={handleSubmit}
                            onScreenshotUpload={handleScreenshotUpload}
                            onScreenshotCapture={handleScreenshotCapture}
                            screenshots={screenshots}
                            onRemoveScreenshot={(i) => setScreenshots((prev) => prev.filter((_, idx) => idx !== i))}
                            onAnnotateScreenshot={(i) => setAnnotatingIndex(i)}
                            submitting={submitting}
                            capturing={capturing}
                        />
                    )}

                    {view === "form" && submitted && (
                        <div className="flex flex-col items-center gap-3 py-12">
                            <div className="w-14 h-14 rounded-full bg-green-50 flex items-center justify-center">
                                <CheckCircle2 className="w-8 h-8 text-green-500" />
                            </div>
                            <div className="text-center">
                                <p className="text-[14px] font-bold text-gray-900">Teşekkürler!</p>
                                <p className="text-[12px] text-gray-400 mt-0.5">Geri bildiriminiz iletildi.</p>
                            </div>
                        </div>
                    )}

                    {view === "history" && (
                        <FeedbackHistoryList
                            feedbacks={feedbacks}
                            onSelect={handleSelectFeedback}
                            loading={loading}
                        />
                    )}

                    {view === "thread" && selectedFb && (
                        <div className="flex flex-col h-full">
                            <div className="pb-3 mb-3 border-b border-gray-100">
                                <div className="flex items-center gap-2 mb-2">
                                    <FeedbackStatusBadge status={selectedFb.status} />
                                    {selectedFb.module_tag && (
                                        <span className="text-[10px] bg-gray-100 text-gray-500 px-2 py-0.5 rounded-full">
                                            {selectedFb.module_tag}
                                        </span>
                                    )}
                                </div>
                                <p className="text-[13px] text-gray-700 leading-relaxed">{selectedFb.message}</p>
                                {(selectedFb.screenshot_url || selectedFb.annotated_screenshot_url) && (() => {
                                    // Tüm görselleri topla (screenshot_url + annotated_screenshot_url pipe-separated)
                                    const allUrls: string[] = [];
                                    if (selectedFb.screenshot_url) allUrls.push(selectedFb.screenshot_url);
                                    if (selectedFb.annotated_screenshot_url) {
                                        allUrls.push(...selectedFb.annotated_screenshot_url.split("|").filter(Boolean));
                                    }
                                    return (
                                        <div className="flex gap-2 mt-2 flex-wrap">
                                            {allUrls.map((url, i) => (
                                                <img
                                                    key={i}
                                                    src={url}
                                                    alt={`Görsel ${i + 1}`}
                                                    className="w-20 h-20 object-cover rounded-lg border border-gray-200 cursor-pointer hover:opacity-80 transition-opacity"
                                                    onClick={() => {
                                                        if (typeof window !== "undefined" && (window as unknown as Record<string, unknown>).openLightbox) {
                                                            (window as unknown as Record<string, unknown> & { openLightbox: (u: string) => void }).openLightbox(url);
                                                        }
                                                    }}
                                                />
                                            ))}
                                        </div>
                                    );
                                })()}
                            </div>
                            <FeedbackThread
                                replies={selectedFb.replies}
                                onReply={handleReply}
                                isAdmin={isAdmin}
                                currentUserId={currentUserId}
                            />
                        </div>
                    )}
                </div>
            </div>
        </>
    );
}
