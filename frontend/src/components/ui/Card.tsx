import type { ReactNode } from "react";

export function Card({
  children,
  flush = false,
  className,
}: {
  children: ReactNode;
  flush?: boolean;
  className?: string;
}) {
  return (
    <section className={["tc-card", flush ? "tc-card--flush" : "", className ?? ""].filter(Boolean).join(" ")}>
      {children}
    </section>
  );
}

export function PageHeader({
  eyebrow,
  titulo,
  descripcion,
  acciones,
}: {
  eyebrow?: string;
  titulo: string;
  descripcion?: ReactNode;
  acciones?: ReactNode;
}) {
  return (
    <div className="tc-page-header">
      <div className="tc-page-header__titles">
        {eyebrow ? <div className="tc-page-header__eyebrow">{eyebrow}</div> : null}
        <h1>{titulo}</h1>
        {descripcion ? <p className="tc-page-header__desc">{descripcion}</p> : null}
      </div>
      {acciones ? <div className="tc-row">{acciones}</div> : null}
    </div>
  );
}

export function SectionTitle({ children }: { children: ReactNode }) {
  return <h2 className="tc-section-title">{children}</h2>;
}

export function Divider() {
  return <hr className="tc-divider" />;
}

export function Stack({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={["tc-stack", className ?? ""].filter(Boolean).join(" ")}>{children}</div>;
}
