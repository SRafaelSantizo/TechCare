import type { ReactNode } from "react";
import { motion, useReducedMotion } from "motion/react";
import { EASE_SALIDA } from "../motion/motionConfig";

export function Card({
  children,
  flush = false,
  className,
}: {
  children: ReactNode;
  flush?: boolean;
  className?: string;
}) {
  const reduce = useReducedMotion();

  if (reduce) {
    return (
      <section className={["tc-card", flush ? "tc-card--flush" : "", className ?? ""].filter(Boolean).join(" ")}>
        {children}
      </section>
    );
  }

  return (
    <motion.section
      className={["tc-card", flush ? "tc-card--flush" : "", className ?? ""].filter(Boolean).join(" ")}
      initial={{ opacity: 0, y: 18 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.48, ease: EASE_SALIDA }}
    >
      {children}
    </motion.section>
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
  const reduce = useReducedMotion();

  const content = (
    <div className="tc-page-header">
      <div className="tc-page-header__titles">
        {eyebrow ? <div className="tc-page-header__eyebrow">{eyebrow}</div> : null}
        <h1>{titulo}</h1>
        {descripcion ? <p className="tc-page-header__desc">{descripcion}</p> : null}
      </div>
      {acciones ? <div className="tc-row">{acciones}</div> : null}
    </div>
  );

  if (reduce) {
    return content;
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, ease: EASE_SALIDA }}
    >
      {content}
    </motion.div>
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
