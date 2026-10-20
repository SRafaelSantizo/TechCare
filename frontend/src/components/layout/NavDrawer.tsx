import { useEffect, useRef } from "react";
import { X } from "lucide-react";
import { motion, useReducedMotion } from "motion/react";
import { Sidebar } from "./Sidebar";
import { Brand } from "./Brand";
import { IconButton } from "../ui/Button";
import { EASE_SALIDA } from "../motion/motionConfig";

export const NAV_DRAWER_ID = "tc-navegacion";

export function NavDrawer({ abierto, onCerrar }: { abierto: boolean; onCerrar: () => void }) {
  const panelRef = useRef<HTMLDivElement>(null);
  const previoRef = useRef<HTMLElement | null>(null);
  const cerrarRef = useRef(onCerrar);
  const reduce = useReducedMotion();

  cerrarRef.current = onCerrar;

  useEffect(() => {
    if (!abierto) return;
    previoRef.current = document.activeElement as HTMLElement | null;
    const panel = panelRef.current;
    const focoInicial = window.setTimeout(() => {
      panel?.querySelector<HTMLElement>("button, a[href]")?.focus();
    }, 0);

    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") {
        e.stopPropagation();
        cerrarRef.current();
        return;
      }
      if (e.key === "Tab" && panel) {
        const focusables = panel.querySelectorAll<HTMLElement>(
          'button:not([disabled]), a[href], input:not([disabled]), select:not([disabled]), textarea:not([disabled])',
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
      window.clearTimeout(focoInicial);
      document.removeEventListener("keydown", onKey, true);
      previoRef.current?.focus();
    };
  }, [abierto]);

  return (
    <>
      {reduce ? (
        <div
          ref={panelRef}
          className="tc-drawer"
          data-open={abierto}
          id={NAV_DRAWER_ID}
          role="dialog"
          aria-modal="true"
          aria-label="Navegacion principal"
        >
          <div className="tc-drawer__head">
            <Brand />
            <IconButton etiqueta="Cerrar navegacion" onClick={onCerrar}>
              <X size={18} />
            </IconButton>
          </div>
          <div className="tc-drawer__body">
            <Sidebar onNavegar={onCerrar} />
          </div>
        </div>
      ) : (
        <motion.div
          ref={panelRef}
          className="tc-drawer"
          data-open={abierto}
          id={NAV_DRAWER_ID}
          role="dialog"
          aria-modal="true"
          aria-label="Navegacion principal"
          initial={{ x: "-100%" }}
          animate={{ x: abierto ? 0 : "-100%" }}
          transition={{ duration: 0.24, ease: EASE_SALIDA }}
          style={{ visibility: abierto ? "visible" : "hidden" }}
        >
          <div className="tc-drawer__head">
            <Brand />
            <IconButton etiqueta="Cerrar navegacion" onClick={onCerrar}>
              <X size={18} />
            </IconButton>
          </div>
          <div className="tc-drawer__body">
            <Sidebar onNavegar={onCerrar} />
          </div>
        </motion.div>
      )}

      {abierto ? (
        <button className="tc-scrim" aria-label="Cerrar navegacion" tabIndex={-1} onClick={onCerrar} />
      ) : null}
    </>
  );
}
