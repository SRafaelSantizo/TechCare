import type { ReactNode } from "react";
import { AlertTriangle, CheckCircle2, Info } from "lucide-react";

type Tono = "info" | "warn" | "danger" | "ok";

const claseTono: Record<Tono, string> = {
  info: "tc-alert--info",
  warn: "tc-alert--warn",
  danger: "tc-alert--danger",
  ok: "tc-alert--ok",
};

export function Alert({
  tono = "info",
  titulo,
  children,
  accion,
}: {
  tono?: Tono;
  titulo?: string;
  children: ReactNode;
  accion?: ReactNode;
}) {
  const Icono = tono === "ok" ? CheckCircle2 : tono === "info" ? Info : AlertTriangle;
  return (
    <div className={["tc-alert", claseTono[tono]].join(" ")} role={tono === "danger" || tono === "warn" ? "alert" : "status"}>
      <span aria-hidden="true" style={{ marginTop: 2 }}>
        <Icono size={18} />
      </span>
      <div style={{ flex: 1 }}>
        {titulo ? <div className="tc-alert__title">{titulo}</div> : null}
        <div className="tc-alert__body">{children}</div>
        {accion ? <div style={{ marginTop: 10 }}>{accion}</div> : null}
      </div>
    </div>
  );
}
