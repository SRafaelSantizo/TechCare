import type { ReactNode } from "react";

export type TonoBadge = "neutral" | "ok" | "warn" | "danger" | "info";

const claseTono: Record<TonoBadge, string> = {
  neutral: "tc-badge--neutral",
  ok: "tc-badge--ok",
  warn: "tc-badge--warn",
  danger: "tc-badge--danger",
  info: "tc-badge--info",
};

export function Badge({
  children,
  tono = "neutral",
  icono,
}: {
  children: ReactNode;
  tono?: TonoBadge;
  icono?: ReactNode;
}) {
  return (
    <span className={["tc-badge", claseTono[tono]].join(" ")}>
      {icono}
      {children}
    </span>
  );
}

/**
 * Estado de orden con texto ademas de color (nunca solo color).
 */
export function EstadoOrdenBadge({ codigo, nombre }: { codigo: string; nombre: string }) {
  const tono: TonoBadge =
    codigo === "ENTREGADO"
      ? "ok"
      : codigo === "CANCELADO"
        ? "danger"
        : codigo === "LISTO" || codigo === "REPARACION"
          ? "info"
          : "neutral";
  return <Badge tono={tono}>{nombre}</Badge>;
}

export function EstadoCapacidadBadge({ estado }: { estado: "disponible" | "incompleta" | "ausente" }) {
  const mapa = {
    disponible: { tono: "ok" as const, texto: "Conectado" },
    incompleta: { tono: "warn" as const, texto: "Parcial" },
    ausente: { tono: "neutral" as const, texto: "Pendiente de API" },
  };
  const { tono, texto } = mapa[estado];
  return <Badge tono={tono}>{texto}</Badge>;
}
