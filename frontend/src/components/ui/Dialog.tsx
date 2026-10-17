import { useEffect, useRef, type ReactNode } from "react";
import { X } from "lucide-react";
import { IconButton } from "./Button";

/**
 * Dialogo accesible: controla el foco al abrir, lo devuelve al cerrar, cierra
 * con Escape y bloquea el foco dentro del panel.
 */
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

  useEffect(() => {
    if (!abierto) return;
    previoRef.current = document.activeElement as HTMLElement | null;
    const panel = panelRef.current;
    panel?.querySelector<HTMLElement>("[data-autofocus], button, input, select, textarea, a[href]")?.focus();

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
    </div>
  );
}
