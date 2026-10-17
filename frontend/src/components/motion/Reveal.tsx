import type { ReactNode } from "react";
import { motion, useReducedMotion } from "motion/react";

/** Curva de aceleracion compartida (ease-out suave, estilo Mercury). */
export const EASE_SALIDA: [number, number, number, number] = [0.22, 1, 0.36, 1];

/**
 * Entrada de una seccion al entrar en pantalla: opacidad 0 -> 1 y
 * desplazamiento vertical de 24px -> 0. Se ejecuta una sola vez y no se
 * repite cuando los datos cambian (la estructura no se vuelve a montar).
 *
 * Con `prefers-reduced-motion` se renderiza sin animacion.
 */
export function Reveal({
  children,
  delay = 0,
  amount = 0.2,
  className,
}: {
  children: ReactNode;
  delay?: number;
  amount?: number;
  className?: string;
}) {
  const reduce = useReducedMotion();

  if (reduce) {
    return <div className={className}>{children}</div>;
  }

  return (
    <motion.div
      className={className}
      initial={{ opacity: 0, y: 24 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, amount }}
      transition={{ duration: 0.58, ease: EASE_SALIDA, delay }}
    >
      {children}
    </motion.div>
  );
}
