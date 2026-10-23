import { useEffect, useRef, type ReactNode } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { motion, useReducedMotion } from "motion/react";
import { EASE_SALIDA } from "../motion/motionConfig";
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
  const seenRef = useRef<Set<string | number>>(new Set());
  const pageKeyRef = useRef<string>("");

  const pageKey = `${filas.map((f, _i) => claveFila(f)).join("|")}|${filas.length}`;
  const isNewPage = pageKeyRef.current !== pageKey && pageKeyRef.current !== "";

  useEffect(() => {
    pageKeyRef.current = pageKey;
  }, [pageKey]);

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
            filas.map((fila, _idx) => {
              const key = claveFila(fila);
              const isNew = !seenRef.current.has(key);
              if (isNew) {
                seenRef.current.add(key);
              }
              const shouldAnimate = usarAnimacion && (isNewPage || isNew);
              const trProps: Record<string, unknown> = shouldAnimate
                ? {
                    initial: { opacity: 0, y: 8 },
                    animate: { opacity: 1, y: 0 },
                    transition: { duration: 0.25, ease: EASE_SALIDA, delay: Math.min(_idx, 12) * 0.05 },
                  }
                : {};
              const Tr = shouldAnimate ? motion.tr : "tr";
              return (
                <Tr key={key} {...trProps}>
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
        Página {pagina} de {totalPaginas} · {total} registro(s)
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
