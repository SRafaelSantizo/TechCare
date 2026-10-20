import type { ButtonHTMLAttributes, ReactNode } from "react";
import { motion, useReducedMotion } from "motion/react";
import { EASE_OUT } from "../motion/motionConfig";

type Variante = "primario" | "secundario" | "fantasma" | "peligro";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variante?: Variante;
  tamano?: "normal" | "sm";
  bloque?: boolean;
  icono?: ReactNode;
  whileTapScale?: number;
}

const claseVariante: Record<Variante, string> = {
  primario: "tc-btn--primary",
  secundario: "",
  fantasma: "tc-btn--ghost",
  peligro: "tc-btn--danger",
};

export function Button({
  variante = "secundario",
  tamano = "normal",
  bloque = false,
  icono,
  children,
  className,
  type = "button",
  whileTapScale = 0.995,
  ...rest
}: ButtonProps) {
  const reduce = useReducedMotion();
  const clases = [
    "tc-btn",
    claseVariante[variante],
    tamano === "sm" ? "tc-btn--sm" : "",
    bloque ? "tc-btn--block" : "",
    className ?? "",
  ]
    .filter(Boolean)
    .join(" ");

  if (reduce) {
    return (
      <button type={type} className={clases} {...rest}>
        {icono}
        {children}
      </button>
    );
  }

  return (
    <motion.button
      type={type}
      className={clases}
      whileTap={{ scale: whileTapScale }}
      whileHover={{ scale: 1.002 }}
      transition={{ duration: 0.16, ease: EASE_OUT }}
      {...(rest as any)}
    >
      {icono}
      {children}
    </motion.button>
  );
}

interface IconButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  etiqueta: string;
  children: ReactNode;
}

export function IconButton({ etiqueta, children, className, type = "button", ...rest }: IconButtonProps) {
  const reduce = useReducedMotion();
  const clases = ["tc-icon-btn", className ?? ""].filter(Boolean).join(" ");

  if (reduce) {
    return (
      <button type={type} className={clases} aria-label={etiqueta} title={etiqueta} {...rest}>
        {children}
      </button>
    );
  }

  return (
    <motion.button
      type={type}
      className={clases}
      aria-label={etiqueta}
      title={etiqueta}
      whileTap={{ scale: 0.98 }}
      whileHover={{ scale: 1.02 }}
      transition={{ duration: 0.16, ease: EASE_OUT }}
      {...(rest as any)}
    >
      {children}
    </motion.button>
  );
}
