import type { ReactNode } from "react";
import { AlertTriangle, Inbox, Loader2, Plug, ShieldAlert, WifiOff } from "lucide-react";
import { Button } from "./Button";
import { operacion } from "../../app/capabilities";

export function LoadingState({ titulo = "Cargando…" }: { titulo?: string }) {
  return (
    <div className="tc-state" role="status" aria-live="polite">
      <Loader2 className="tc-state__icon" size={22} aria-hidden="true" />
      <div className="tc-state__title">{titulo}</div>
    </div>
  );
}

export function EmptyState({ titulo, descripcion, accion }: { titulo: string; descripcion?: ReactNode; accion?: ReactNode }) {
  return (
    <div className="tc-state">
      <Inbox className="tc-state__icon" size={22} aria-hidden="true" />
      <div className="tc-state__title">{titulo}</div>
      {descripcion ? <div className="tc-state__desc">{descripcion}</div> : null}
      {accion}
    </div>
  );
}

export function ErrorState({
  titulo = "No se pudo cargar",
  mensaje,
  onRetry,
}: {
  titulo?: string;
  mensaje: string;
  onRetry?: () => void;
}) {
  const esRed = /contactar con el servidor/i.test(mensaje);
  const Icono = esRed ? WifiOff : AlertTriangle;
  return (
    <div className="tc-state" role="alert">
      <Icono className="tc-state__icon" size={22} aria-hidden="true" />
      <div className="tc-state__title">{titulo}</div>
      <div className="tc-state__desc">{mensaje}</div>
      {onRetry ? (
        <Button variante="secundario" onClick={onRetry}>
          Reintentar
        </Button>
      ) : null}
    </div>
  );
}

export function PermissionState({ mensaje }: { mensaje?: string }) {
  return (
    <div className="tc-state" role="alert">
      <ShieldAlert className="tc-state__icon" size={22} aria-hidden="true" />
      <div className="tc-state__title">Sin permiso</div>
      <div className="tc-state__desc">
        {mensaje ?? "Tu cuenta no tiene autorizacion para esta operacion. La validacion definitiva la realiza el servidor."}
      </div>
    </div>
  );
}

/**
 * Estado de una capacidad sin soporte de API. Nunca simula resultados:
 * explica la dependencia y el proceso SQL requerido.
 */
export function PendingState({
  operacionId,
  titulo,
  descripcion,
}: {
  operacionId?: string;
  titulo?: string;
  descripcion?: ReactNode;
}) {
  const op = operacionId ? operacion(operacionId) : undefined;
  return (
    <div className="tc-state">
      <Plug className="tc-state__icon" size={22} aria-hidden="true" />
      <div className="tc-state__title">{titulo ?? "Integracion pendiente"}</div>
      <div className="tc-state__desc">
        {descripcion ??
          "Esta operacion aun no tiene endpoint en el backend. La interfaz esta preparada, pero la accion permanece indisponible hasta exponer el contrato."}
        {op ? (
          <>
            {" "}
            Requiere <strong>{op.metodo} {op.ruta}</strong>
            {op.procedimiento ? (
              <>
                {" "}respaldado por <code>{op.procedimiento}</code>
              </>
            ) : null}
            .
          </>
        ) : null}
      </div>
    </div>
  );
}
