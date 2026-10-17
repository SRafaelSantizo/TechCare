import type { ButtonHTMLAttributes, ReactNode } from "react";

type Variante = "primario" | "secundario" | "fantasma" | "peligro";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variante?: Variante;
  tamano?: "normal" | "sm";
  bloque?: boolean;
  icono?: ReactNode;
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
  ...rest
}: ButtonProps) {
  const clases = [
    "tc-btn",
    claseVariante[variante],
    tamano === "sm" ? "tc-btn--sm" : "",
    bloque ? "tc-btn--block" : "",
    className ?? "",
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <button type={type} className={clases} {...rest}>
      {icono}
      {children}
    </button>
  );
}

interface IconButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  etiqueta: string;
  children: ReactNode;
}

export function IconButton({ etiqueta, children, className, type = "button", ...rest }: IconButtonProps) {
  return (
    <button
      type={type}
      className={["tc-icon-btn", className ?? ""].filter(Boolean).join(" ")}
      aria-label={etiqueta}
      title={etiqueta}
      {...rest}
    >
      {children}
    </button>
  );
}
