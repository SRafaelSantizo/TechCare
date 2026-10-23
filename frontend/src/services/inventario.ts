import { http } from "./http";
export interface Existencia {
  bodegaId: number; codigoBodega: string; bodega: string; bodegaActiva: boolean;
  repuestoId: number; codigo: string; repuesto: string; repuestoActivo: boolean;
  categoriaId: number; categoria: string; existencia: string; stockMinimo: number; faltante: string;
  estadoStock: "SIN_EXISTENCIA" | "BAJO" | "DISPONIBLE"; costoPromedio: string; valorExistencia: string;
}
export interface ResumenInventario { total: number; sinExistencia: number; stockBajo: number; valorTotal: string }
export interface Pagina { pagina: number; tamano: number; total: number; totalPaginas: number }
export interface Inventario extends Pagina { filas: Existencia[]; resumen: ResumenInventario }
export interface Movimiento {
  movimientoId: string; fecha: string; tipo: "E" | "S"; cantidad: number;
  existenciaAnterior: string; existenciaResultante: string; costoUnitario: string; importe: string;
  costoAnterior: string | null; costoPosterior: string | null; valorExistencia: string | null;
  esMigracion: boolean | null; compraId: number | null; lineaCompra: number | null; numeroCompra: string | null;
  proveedorId: number | null; proveedor: string | null; ordenId: number | null; numeroOrden: string | null;
  reparacionId: number | null; lineaReparacion: number | null; usuarioId: number; responsable: string; nombreHistorico: boolean;
}
export interface Kardex extends Pagina {
  inventario: Existencia; resumen: { saldoInicial: string; entradas: string; salidas: string; saldoFinal: string }; filas: Movimiento[];
}
export interface FiltrosInventario { buscar: string; bodegaId: string; categoriaId: string; estadoStock: string; activo: string }
export interface FiltrosKardex { desde: string; hasta: string; tipo: string }
function consulta(filtros: FiltrosInventario | FiltrosKardex, pagina: number) {
  const p = new URLSearchParams({ pagina: String(pagina), tamano: "25" });
  Object.entries(filtros).forEach(([k, v]) => { if (v !== "") p.set(k, v); });
  return `?${p}`;
}
export const inventarioApi = {
  listar: (f: FiltrosInventario, pagina: number, signal?: AbortSignal) => http.get<Inventario>(`/inventario${consulta(f, pagina)}`, signal),
  kardex: (bodega: number, repuesto: number, f: FiltrosKardex, pagina: number, signal?: AbortSignal) =>
    http.get<Kardex>(`/inventario/${bodega}/${repuesto}/kardex${consulta(f, pagina)}`, signal),
};
export function unidades(valor: string | number | null | undefined) { return valor === null || valor === undefined ? "—" : BigInt(valor).toLocaleString("es-GT"); }
