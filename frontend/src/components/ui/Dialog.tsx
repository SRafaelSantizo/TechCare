import { useEffect, useRef, type ReactNode } from "react";
import { X } from "lucide-react";
import { motion, useReducedMotion } from "motion/react";
import { EASE_SALIDA } from "../motion/motionConfig";
import { IconButton } from "./Button";

export function Dialog({
  abierto,
  titulo,
  descripcion,
  onCerrar,
  children,
  ancho,
}: {
  abierto: boolean;
  titulo: string;
  descripcion?: ReactNode;
  onCerrar: () => void;
  children: ReactNode;
  ancho?: number;
}) {
  const panelRef = useRef<HTMLDivElement>(null);
  const previoRef = useRef<HTMLElement | null>(null);
  const reduce = useReducedMotion();

  useEffect(() => {
    if (!abierto) return;
    previoRef.current = document.activeElement as HTMLElement | null;
    const panel = panelRef.current;
    const timer = window.setTimeout(() => {
      panel?.querySelector<HTMLElement>("[data-autofocus], button:not([aria-label=\"Cerrar\"]):not(.tc-icon-btn), input, select, textarea, a[href]")?.focus();
    }, 10);

    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") {
        e.stopPropagation();
        onCerrar();
      }
      if (e.key === "Tab" && panel) {
        const focusables = panel.querySelectorAll<HTMLElement>(
          'button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), a[href]',
        );
        if (focusables.length === 0) return;
        const primero = focusables[0];
        const ultimo = focusables[focusables.length - 1];
        if (e.shiftKey && document.activeElement === primero) {
          e.preventDefault();
          ultimo.focus();
        } else if (!e.shiftKey && document.activeElement === ultimo) {
          e.preventDefault();
          primero.focus();
        }
      }
    }

    document.addEventListener("keydown", onKey, true);
    return () => {
      window.clearTimeout(timer);
      document.removeEventListener("keydown", onKey, true);
      previoRef.current?.focus();
    };
  }, [abierto, onCerrar]);

  if (!abierto) return null;

  return (
    <div
      className="tc-dialog__backdrop"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onCerrar();
      }}
    >
      {reduce ? (
        <div
          className="tc-dialog"
          role="dialog"
          aria-modal="true"
          aria-label={titulo}
          ref={panelRef}
          style={ancho ? { width: `min(${ancho}px, 100%)` } : undefined}
        >
          <div className="tc-row" style={{ alignItems: "flex-start" }}>
            <div style={{ flex: 1 }}>
              <div className="tc-dialog__title">{titulo}</div>
              {descripcion ? <div className="tc-dialog__desc">{descripcion}</div> : null}
            </div>
            <IconButton etiqueta="Cerrar" onClick={onCerrar}>
              <X size={18} />
            </IconButton>
          </div>
          {children}
        </div>
      ) : (
        <motion.div
          className="tc-dialog"
          role="dialog"
          aria-modal="true"
          aria-label={titulo}
          ref={panelRef}
          initial={{ opacity: 0, scale: 0.98, y: 12 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.98, y: 8 }}
          transition={{ duration: 0.24, ease: EASE_SALIDA }}
          style={ancho ? { width: `min(${ancho}px, 100%)` } : undefined}
        >
          <div className="tc-row" style={{ alignItems: "flex-start" }}>
            <div style={{ flex: 1 }}>
              <div className="tc-dialog__title">{titulo}</div>
              {descripcion ? <div className="tc-dialog__desc">{descripcion}</div> : null}
            </div>
            <IconButton etiqueta="Cerrar" onClick={onCerrar}>
              <X size={18} />
            </IconButton>
          </div>
          {children}
        </motion.div>
      )}
    </div>
  );
}
