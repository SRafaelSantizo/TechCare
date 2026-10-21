import type { ReactNode } from "react";
import { motion, useReducedMotion } from "motion/react";
import { LIST_ITEM_VARIANTS } from "./motionConfig";

export function StaggerList({
  children,
  className,
  stagger = 0.05,
  delayChildren = 0.02,
}: {
  children: ReactNode;
  className?: string;
  stagger?: number;
  delayChildren?: number;
}) {
  const reduce = useReducedMotion();

  if (reduce) {
    return <div className={className}>{children}</div>;
  }

  return (
    <motion.div
      className={className}
      initial="hidden"
      whileInView="visible"
      viewport={{ once: true, amount: 0.1 }}
      variants={{
        hidden: {},
        visible: {
          transition: { staggerChildren: stagger, delayChildren },
        },
      }}
    >
      {children}
    </motion.div>
  );
}

export function StaggerItem({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  const reduce = useReducedMotion();

  if (reduce) {
    return <div className={className}>{children}</div>;
  }

  return (
    <motion.div className={className} variants={LIST_ITEM_VARIANTS}>
      {children}
    </motion.div>
  );
}
