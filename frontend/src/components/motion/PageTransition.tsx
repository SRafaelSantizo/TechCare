import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useLocation, useOutlet } from "react-router-dom";
import { EASE_SALIDA } from "./Reveal";

/**
 * Transicion breve entre rutas. Se anima solo la opacidad para no dejar
 * `transform` en un ancestro (romperia `position: sticky` de las tablas).
 * Con `prefers-reduced-motion` se renderiza la ruta sin animacion.
 */
export function PageTransition() {
  const location = useLocation();
  const outlet = useOutlet();
  const reduce = useReducedMotion();

  if (reduce) {
    return <>{outlet}</>;
  }

  return (
    <AnimatePresence mode="wait" initial={false}>
      <motion.div
        key={location.pathname}
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        transition={{ duration: 0.2, ease: EASE_SALIDA }}
      >
        {outlet}
      </motion.div>
    </AnimatePresence>
  );
}
