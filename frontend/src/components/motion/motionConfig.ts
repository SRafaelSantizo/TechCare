import type { Transition, Variants } from "motion/react";

export const EASE_OUT: [number, number, number, number] = [0.22, 1, 0.36, 1];
export const EASE_IN_OUT: [number, number, number, number] = [0.25, 0.8, 0.25, 1];

export const DUR_FAST = 0.16;
export const DUR_INTERACT = 0.18;
export const DUR_MED = 0.24;
export const DUR_ROUTE = 0.26;
export const DUR_SECTION = 0.48;
export const DUR_ENTRADA = 0.52;

export const STAGGER_ITEM = 0.05;

export const FADE_UP_VARIANTS: Variants = {
  hidden: { opacity: 0, y: 16 },
  visible: { opacity: 1, y: 0 },
};

export const FADE_VARIANTS: Variants = {
  hidden: { opacity: 0 },
  visible: { opacity: 1 },
};

export const SCALE_IN_VARIANTS: Variants = {
  hidden: { opacity: 0, scale: 0.98 },
  visible: { opacity: 1, scale: 1 },
};

export const LIST_CONTAINER_VARIANTS: Variants = {
  hidden: {},
  visible: {
    transition: {
      staggerChildren: STAGGER_ITEM,
      delayChildren: 0.02,
    },
  },
};

export const LIST_ITEM_VARIANTS: Variants = {
  hidden: { opacity: 0, y: 10 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: DUR_MED, ease: EASE_OUT },
  },
};

export const getTransition = (
  duration: number = DUR_MED,
  delay: number = 0,
  ease: [number, number, number, number] = EASE_OUT
): Transition => ({
  duration,
  ease,
  delay,
});

export { EASE_OUT as EASE_SALIDA };
