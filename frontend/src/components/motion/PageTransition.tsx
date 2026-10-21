import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useLocation, useOutlet } from "react-router-dom";
import { EASE_SALIDA } from "./motionConfig";

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
        transition={{ duration: 0.26, ease: EASE_SALIDA }}
      >
        {outlet}
      </motion.div>
    </AnimatePresence>
  );
}
