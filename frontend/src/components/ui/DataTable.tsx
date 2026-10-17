import type { ReactNode } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { motion, useReducedMotion } from "motion/react";
import { Button } from "./Button";

export interface Columna<T> {
  clave: string;
  encabezado: string;
  render: (fila: T) => ReactNode;
  numerica?: boolean;
  ancho?: string;
}

export function DataTable<T>({
  columnas,
  filas,
  claveFila,
  caption,
  vacio = "Sin resultados.",
  animarFilas = false,
}: {
  columnas: Array<Columna<T>>;
  filas: T[];
  claveFila: (fila: T) => string | number;
  caption?: string;
  vacio?: ReactNode;
  animarFilas?: boolean;
}) {
  const reduce = useReducedMotion();
  const usarAnimacion = animarFilas && !reduce;

  return (
    <div className="tc-table-wrap">
      <table className="tc-table">
        {caption ? <caption>{caption}</caption> : null}
        <thead>
          <tr>
            {columnas.map((c) => (
              <th
                key={c.clave}
                scope="col"
                className={c.numerica ? "tc-table__num" : undefined}
                style={c.ancho ? { width: c.ancho } : undefined}
              >
                {c.encabezado}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {filas.length === 0 ? (
            <tr>
              <td colSpan={columnas.length}>
                <div className="tc-empty-inline" style={{ padding: "18px 4px" }}>
                  {vacio}
                </div>
              </td>
            </tr>
          ) : (
            filas.map((fila, idx) => {
              const trProps: any = usarAnimacion
                ? {
                    initial: { opacity: 0, y: 8 },
                    animate: { opacity: 1, y: 0 },
                    transition: { duration: 0.26, ease: [0.22, 1, 0.36, 1], delay: idx * 0.055 },
                  }
                : {};
              const Tr = usarAnimacion ? (motion.tr as any) : "tr";
              return (
                <Tr key={claveFila(fila)} {...trProps}>
                  {columnas.map((c) => (
                    <td key={c.clave} className={c.numerica ? "tc-table__num" : undefined}>
                      {c.render(fila)}
                    </td>
                  ))}
                </Tr>
              );
            })
          )}
        </tbody>
      </table>
    </div>
  );
}

export function Paginacion({
  pagina,
  totalPaginas,
  total,
  onCambiar,
}: {
  pagina: number;
  totalPaginas: number;
  total: number;
  onCambiar: (pagina: number) => void;
}) {
  if (totalPaginas <= 1) {
    return <div className="tc-field__hint">{total} registro(s).</div>;
  }
  return (
    <div className="tc-row" style={{ justifyContent: "space-between", marginTop: 12 }}>
      <span className="tc-field__hint">
        Pagina {pagina} de {totalPaginas} · {total} registro(s)
      </span>
      <div className="tc-row" style={{ gap: 8 }}>
        <Button
          tamano="sm"
          icono={<ChevronLeft size={16} />}
          onClick={() => onCambiar(pagina - 1)}
          disabled={pagina <= 1}
        >
          Anterior
        </Button>
        <Button
          tamano="sm"
          onClick={() => onCambiar(pagina + 1)}
          disabled={pagina >= totalPaginas}
        >
          Siguiente
          <ChevronRight size={16} />
        </Button>
      </div>
    </div>
  );
}
