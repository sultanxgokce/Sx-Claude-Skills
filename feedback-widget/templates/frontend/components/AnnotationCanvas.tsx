"use client";

import { useRef, useState, useEffect, useCallback } from "react";
import { Pencil, MoveRight, Square, Type, Undo2, Trash2, Check, X } from "lucide-react";
import { cn } from "@/lib/utils";

type AnnotationTool = "pen" | "arrow" | "rectangle" | "text";

const COLORS = [
    { name: "Kırmızı", value: "#ef4444" },
    { name: "Sarı", value: "#eab308" },
    { name: "Mavi", value: "#3b82f6" },
    { name: "Yeşil", value: "#22c55e" },
    { name: "Beyaz", value: "#ffffff" },
];

const TOOLS: { id: AnnotationTool; icon: React.ReactNode; label: string }[] = [
    { id: "pen", icon: <Pencil className="w-4 h-4" />, label: "Kalem" },
    { id: "arrow", icon: <MoveRight className="w-4 h-4" />, label: "Ok" },
    { id: "rectangle", icon: <Square className="w-4 h-4" />, label: "Kutu" },
    { id: "text", icon: <Type className="w-4 h-4" />, label: "Metin" },
];

interface AnnotationCanvasProps {
    imageBlob: Blob;
    onSave: (annotatedBlob: Blob) => void;
    onCancel: () => void;
}

export default function AnnotationCanvas({ imageBlob, onSave, onCancel }: AnnotationCanvasProps) {
    const canvasRef = useRef<HTMLCanvasElement>(null);
    const containerRef = useRef<HTMLDivElement>(null);
    const textInputRef = useRef<HTMLInputElement>(null);
    const [tool, setTool] = useState<AnnotationTool>("pen");
    const [color, setColor] = useState(COLORS[0].value);
    const [isDrawing, setIsDrawing] = useState(false);
    const [startPoint, setStartPoint] = useState<{ x: number; y: number } | null>(null);
    const [history, setHistory] = useState<ImageData[]>([]);
    const [bgImage, setBgImage] = useState<HTMLImageElement | null>(null);
    const [textPos, setTextPos] = useState<{ x: number; y: number } | null>(null);
    const [textValue, setTextValue] = useState("");

    // Load image — yeni blob geldiğinde tüm çizim durumunu sıfırla
    useEffect(() => {
        // Yeni görsel gelince drawing state'i temizle (eski çizimler kalmasın)
        setTool("pen");
        setIsDrawing(false);
        setStartPoint(null);
        setTextPos(null);
        setTextValue("");
        setHistory([]);

        const img = new Image();
        img.onload = () => {
            setBgImage(img);
            const canvas = canvasRef.current;
            if (!canvas) return;

            const maxW = window.innerWidth * 0.95;
            const maxH = window.innerHeight * 0.75;
            const scale = Math.min(maxW / img.width, maxH / img.height, 1);
            canvas.width = img.width * scale;
            canvas.height = img.height * scale;

            const ctx = canvas.getContext("2d");
            if (!ctx) return;
            ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
            setHistory([ctx.getImageData(0, 0, canvas.width, canvas.height)]);
        };
        img.src = URL.createObjectURL(imageBlob);
        return () => URL.revokeObjectURL(img.src);
    }, [imageBlob]);

    // Focus text input when it appears
    useEffect(() => {
        if (textPos && textInputRef.current) {
            textInputRef.current.focus();
        }
    }, [textPos]);

    const saveState = useCallback(() => {
        const canvas = canvasRef.current;
        const ctx = canvas?.getContext("2d");
        if (!ctx || !canvas) return;
        const state = ctx.getImageData(0, 0, canvas.width, canvas.height);
        setHistory((prev) => [...prev.slice(-19), state]);
    }, []);

    const getPos = useCallback((e: React.MouseEvent | React.TouchEvent): { x: number; y: number } => {
        const canvas = canvasRef.current;
        if (!canvas) return { x: 0, y: 0 };
        const rect = canvas.getBoundingClientRect();
        const scaleX = canvas.width / rect.width;
        const scaleY = canvas.height / rect.height;

        if ("touches" in e) {
            const touch = e.touches[0] || e.changedTouches[0];
            return {
                x: (touch.clientX - rect.left) * scaleX,
                y: (touch.clientY - rect.top) * scaleY,
            };
        }
        return {
            x: (e.clientX - rect.left) * scaleX,
            y: (e.clientY - rect.top) * scaleY,
        };
    }, []);

    const commitText = useCallback(() => {
        if (!textPos || !textValue.trim()) {
            setTextPos(null);
            setTextValue("");
            return;
        }
        const ctx = canvasRef.current?.getContext("2d");
        if (!ctx) return;

        ctx.font = "bold 18px Inter, system-ui, sans-serif";
        ctx.fillStyle = color;
        ctx.shadowColor = "rgba(0,0,0,0.5)";
        ctx.shadowBlur = 2;
        ctx.fillText(textValue, textPos.x, textPos.y);
        ctx.shadowColor = "transparent";
        ctx.shadowBlur = 0;
        saveState();
        setTextPos(null);
        setTextValue("");
    }, [textPos, textValue, color, saveState]);

    const handlePointerDown = useCallback((e: React.MouseEvent | React.TouchEvent) => {
        // Commit any pending text first
        if (textPos) {
            commitText();
            return;
        }

        const pos = getPos(e);

        if (tool === "text") {
            setTextPos(pos);
            setTextValue("");
            return;
        }

        setIsDrawing(true);
        setStartPoint(pos);

        if (tool === "pen") {
            const ctx = canvasRef.current?.getContext("2d");
            if (!ctx) return;
            ctx.beginPath();
            ctx.moveTo(pos.x, pos.y);
            ctx.strokeStyle = color;
            ctx.lineWidth = 3;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
        }
    }, [tool, color, getPos, textPos, commitText]);

    const handlePointerMove = useCallback((e: React.MouseEvent | React.TouchEvent) => {
        if (!isDrawing) return;
        const pos = getPos(e);

        if (tool === "pen") {
            const ctx = canvasRef.current?.getContext("2d");
            if (!ctx) return;
            ctx.lineTo(pos.x, pos.y);
            ctx.stroke();
        }
    }, [isDrawing, tool, getPos]);

    const handlePointerUp = useCallback((e: React.MouseEvent | React.TouchEvent) => {
        if (!isDrawing || !startPoint) {
            setIsDrawing(false);
            return;
        }

        const pos = getPos(e);
        const canvas = canvasRef.current;
        const ctx = canvas?.getContext("2d");
        if (!ctx || !canvas) { setIsDrawing(false); return; }

        if (tool === "arrow") {
            if (history.length > 0) {
                ctx.putImageData(history[history.length - 1], 0, 0);
            }
            drawArrow(ctx, startPoint.x, startPoint.y, pos.x, pos.y, color);
        } else if (tool === "rectangle") {
            if (history.length > 0) {
                ctx.putImageData(history[history.length - 1], 0, 0);
            }
            ctx.strokeStyle = color;
            ctx.lineWidth = 3;
            ctx.strokeRect(startPoint.x, startPoint.y, pos.x - startPoint.x, pos.y - startPoint.y);
        }

        saveState();
        setIsDrawing(false);
        setStartPoint(null);
    }, [isDrawing, startPoint, tool, color, history, getPos, saveState]);

    const handleUndo = useCallback(() => {
        if (history.length <= 1) return;
        const canvas = canvasRef.current;
        const ctx = canvas?.getContext("2d");
        if (!ctx || !canvas) return;

        const newHistory = history.slice(0, -1);
        ctx.putImageData(newHistory[newHistory.length - 1], 0, 0);
        setHistory(newHistory);
    }, [history]);

    const handleClear = useCallback(() => {
        if (history.length === 0 || !bgImage) return;
        const canvas = canvasRef.current;
        const ctx = canvas?.getContext("2d");
        if (!ctx || !canvas) return;

        ctx.drawImage(bgImage, 0, 0, canvas.width, canvas.height);
        setHistory([ctx.getImageData(0, 0, canvas.width, canvas.height)]);
    }, [history, bgImage]);

    const handleSave = useCallback(() => {
        // Commit pending text
        if (textPos && textValue.trim()) {
            const ctx = canvasRef.current?.getContext("2d");
            if (ctx) {
                ctx.font = "bold 18px Inter, system-ui, sans-serif";
                ctx.fillStyle = color;
                ctx.fillText(textValue, textPos.x, textPos.y);
            }
        }
        const canvas = canvasRef.current;
        if (!canvas) return;
        canvas.toBlob((blob) => {
            if (blob) onSave(blob);
        }, "image/png");
    }, [onSave, textPos, textValue, color]);

    // Compute text input screen position
    const getTextScreenPos = () => {
        if (!textPos || !canvasRef.current) return { left: 0, top: 0 };
        const canvas = canvasRef.current;
        const rect = canvas.getBoundingClientRect();
        return {
            left: (textPos.x / canvas.width) * rect.width,
            top: (textPos.y / canvas.height) * rect.height,
        };
    };

    return (
        <div className="fixed inset-0 z-[9999] bg-gray-900/95 flex flex-col">
            {/* Toolbar */}
            <div className="flex items-center justify-between px-4 py-2 bg-gray-800 shrink-0">
                {/* Tools */}
                <div className="flex items-center gap-1">
                    {TOOLS.map((t) => (
                        <button
                            key={t.id}
                            type="button"
                            onClick={() => { if (textPos) commitText(); setTool(t.id); }}
                            className={cn(
                                "flex items-center gap-1 px-2.5 py-2 rounded-lg text-[11px] font-medium transition-all",
                                tool === t.id
                                    ? "bg-white text-gray-900"
                                    : "text-gray-400 hover:text-white hover:bg-gray-700"
                            )}
                            title={t.label}
                        >
                            {t.icon}
                            <span className="hidden sm:inline">{t.label}</span>
                        </button>
                    ))}

                    <div className="w-px h-6 bg-gray-600 mx-1" />

                    {/* Colors */}
                    <div className="flex items-center gap-1">
                        {COLORS.map((c) => (
                            <button
                                key={c.value}
                                type="button"
                                onClick={() => setColor(c.value)}
                                className={cn(
                                    "w-6 h-6 rounded-full border-2 transition-all",
                                    color === c.value ? "border-white scale-110" : "border-gray-600 hover:border-gray-400"
                                )}
                                style={{ backgroundColor: c.value }}
                                title={c.name}
                            />
                        ))}
                    </div>

                    <div className="w-px h-6 bg-gray-600 mx-1" />

                    <button
                        type="button"
                        onClick={handleUndo}
                        disabled={history.length <= 1}
                        className={cn(
                            "px-2 py-2 rounded-lg transition-all",
                            history.length > 1
                                ? "text-gray-400 hover:text-white hover:bg-gray-700"
                                : "text-gray-600"
                        )}
                        title="Geri Al"
                    >
                        <Undo2 className="w-4 h-4" />
                    </button>
                    <button
                        type="button"
                        onClick={handleClear}
                        className="px-2 py-2 rounded-lg text-gray-400 hover:text-white hover:bg-gray-700 transition-all"
                        title="Temizle"
                    >
                        <Trash2 className="w-4 h-4" />
                    </button>
                </div>

                {/* Save / Cancel */}
                <div className="flex items-center gap-2">
                    <button
                        type="button"
                        onClick={onCancel}
                        className="flex items-center gap-1 px-3 py-1.5 rounded-lg text-gray-400 hover:text-white hover:bg-gray-700 text-[12px] font-medium transition-all"
                    >
                        <X className="w-3.5 h-3.5" />
                        İptal
                    </button>
                    <button
                        type="button"
                        onClick={handleSave}
                        className="flex items-center gap-1 px-4 py-1.5 rounded-lg bg-blue-500 text-white text-[12px] font-bold hover:bg-blue-600 transition-all"
                    >
                        <Check className="w-3.5 h-3.5" />
                        Kaydet
                    </button>
                </div>
            </div>

            {/* Canvas Area */}
            <div className="flex-1 flex items-center justify-center overflow-auto p-4">
                <div ref={containerRef} className="relative inline-block">
                    <canvas
                        ref={canvasRef}
                        className="border border-gray-700 rounded-lg cursor-crosshair block"
                        style={{ touchAction: "none", maxWidth: "100%", maxHeight: "calc(100vh - 80px)" }}
                        onMouseDown={handlePointerDown}
                        onMouseMove={handlePointerMove}
                        onMouseUp={handlePointerUp}
                        onTouchStart={handlePointerDown}
                        onTouchMove={handlePointerMove}
                        onTouchEnd={handlePointerUp}
                    />

                    {/* Text Input — canvas üzerinde tıklanan noktada */}
                    {textPos && (
                        <div
                            className="absolute pointer-events-auto"
                            style={{
                                left: getTextScreenPos().left,
                                top: getTextScreenPos().top - 10,
                            }}
                        >
                            <input
                                ref={textInputRef}
                                type="text"
                                value={textValue}
                                onChange={(e) => setTextValue(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === "Enter") commitText();
                                    if (e.key === "Escape") { setTextPos(null); setTextValue(""); }
                                }}
                                className="bg-black/50 backdrop-blur-sm border-2 border-white/60 text-sm font-bold outline-none min-w-[140px] px-2 py-1 rounded-md shadow-lg"
                                style={{ color }}
                                placeholder="Metin yazın, Enter'a basın"
                            />
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}

/* ── Arrow Drawing Helper ── */
function drawArrow(ctx: CanvasRenderingContext2D, x1: number, y1: number, x2: number, y2: number, color: string) {
    const headLen = 15;
    const dx = x2 - x1;
    const dy = y2 - y1;
    const angle = Math.atan2(dy, dx);

    ctx.strokeStyle = color;
    ctx.fillStyle = color;
    ctx.lineWidth = 3;
    ctx.lineCap = "round";

    ctx.beginPath();
    ctx.moveTo(x1, y1);
    ctx.lineTo(x2, y2);
    ctx.stroke();

    ctx.beginPath();
    ctx.moveTo(x2, y2);
    ctx.lineTo(x2 - headLen * Math.cos(angle - Math.PI / 6), y2 - headLen * Math.sin(angle - Math.PI / 6));
    ctx.lineTo(x2 - headLen * Math.cos(angle + Math.PI / 6), y2 - headLen * Math.sin(angle + Math.PI / 6));
    ctx.closePath();
    ctx.fill();
}
