import { useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { DataTable, Paginacion, type Columna } from "../../components/ui/DataTable";
import { Badge } from "../../components/ui/Badge";

export function EstadoCatalogo({ activo }: { activo: boolean }) { return <Badge tono={activo ? "ok" : "neutral"}>{activo ? "Activo" : "Inactivo"}</Badge>; }
export function TablaCatalogo<T>({ filas, columnas, clave, vacio }: { filas: T[]; columnas: Columna<T>[]; clave: (r: T) => number; vacio?: string }) {
  const [pagina, setPagina] = useState(1), paginas = Math.max(1, Math.ceil(filas.length / 10)), actual = Math.min(pagina, paginas);
  return <><DataTable columnas={columnas} filas={filas.slice((actual - 1) * 10, actual * 10)} claveFila={clave} vacio={vacio} />
    <Paginacion pagina={actual} totalPaginas={paginas} total={filas.length} onCambiar={setPagina} /></>;
}
export function useActualizarAbastecimiento() {
  const qc = useQueryClient();
  return () => Promise.all([qc.invalidateQueries({ queryKey: ["abastecimiento"] }), qc.invalidateQueries({ queryKey: ["orden"] }), qc.invalidateQueries({ queryKey: ["inventario"] })]);
}
