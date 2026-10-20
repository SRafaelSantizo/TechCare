import type { ReactNode } from "react";
import { motion, useReducedMotion } from "motion/react";
import { EASE_SALIDA } from "./motionConfig";

export { EASE_SALIDA } from "./motionConfig";

export function Reveal({
  children,
  delay = 0,
  amount = 0.2,
  className,
  duration = 0.52,
}: {
  children: ReactNode;
  delay?: number;
  amount?: number;
  className?: string;
  duration?: number;
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
      transition={{ duration, ease: EASE_SALIDA, delay }}
    >
      {children}
    </motion.div>
  );
}
