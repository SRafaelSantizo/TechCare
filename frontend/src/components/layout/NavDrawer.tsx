import { useEffect, useRef } from "react";
import { X } from "lucide-react";
import { Sidebar } from "./Sidebar";
import { Brand } from "./Brand";
import { IconButton } from "../ui/Button";

/** Identificador estable para enlazar la hamburguesa con el cajon. */
export const NAV_DRAWER_ID = "tc-navegacion";

/**
 * Cajon de navegacion superpuesto, igual en escritorio y movil.
 *
 * - Nunca reserva espacio horizontal: es `position: fixed` y, cerrado,
 *   permanece trasladado fuera de pantalla y oculto (sin generar scroll).
 * - Cierra con el boton de cerrar, el fondo (backdrop), `Escape` o al
 *   seleccionar un destino.
 * - Al abrir mueve el foco al cajon y lo encierra (`Tab`); al cerrar lo
 *   devuelve al elemento que lo abrio (la hamburguesa).
 */
export function NavDrawer({ abierto, onCerrar }: { abierto: boolean; onCerrar: () => void }) {
  const panelRef = useRef<HTMLDivElement>(null);
  const previoRef = useRef<HTMLElement | null>(null);
  const cerrarRef = useRef(onCerrar);

  cerrarRef.current = onCerrar;

  useEffect(() => {
    if (!abierto) return;
    previoRef.current = document.activeElement as HTMLElement | null;
    const panel = panelRef.current;
    panel?.querySelector<HTMLElement>("button, a[href]")?.focus();

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
      document.removeEventListener("keydown", onKey, true);
      previoRef.current?.focus();
    };
  }, [abierto]);

  return (
    <>
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

      {abierto ? (
        <button className="tc-scrim" aria-label="Cerrar navegacion" tabIndex={-1} onClick={onCerrar} />
      ) : null}
    </>
  );
}
