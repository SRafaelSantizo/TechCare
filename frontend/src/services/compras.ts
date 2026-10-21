import { http } from "./http";
export interface Compra {
  compraId: number; numeroCompra: string; proveedorId: number; nit: string; proveedor: string; fecha: string; estado: "PENDIENTE" | "RECIBIDA" | "ANULADA";
  fechaRecepcion: string | null; observaciones: string | null; registradaPor: string; recibidaPor: string | null; anuladaPor: string | null;
  fechaAnulacion: string | null; motivoAnulacion: string | null; lineas: number; total: string; revision: string;
}
export interface DetalleCompra {
  linea: number; bodegaId: number; bodega: string; repuestoId: number; codigo: string; repuesto: string; cantidad: number; costoUnitario: string; importe: string;
  existencia: number; costoPromedio: string; movimientoId: number | null; existenciaResultante: number | null; costoAnterior: string | null; costoPosterior: string | null; recibidaPor: string | null;
}
export interface EventoCompra { tipo: string; responsable: string; fecha: string; observacion: string | null }
export interface DocumentoCompra { compra: Compra; detalle: DetalleCompra[]; eventos: EventoCompra[] }
export interface DestinoCompra { repuestoId: number; codigo: string; repuesto: string; bodegaId: number; bodega: string; codigoProveedor: string | null; existencia: number; stockMinimo: number; costoPromedio: string }
export interface CostoBodega { bodegaId: number; codigo: string; bodega: string; activo: boolean; existencia: number; stockMinimo: number; costoPromedio: string }
export interface LineaCompra { bodegaId: number; repuestoId: number; cantidad: number; costoUnitario: string }
export interface RegistroCompra { solicitudId: string; numeroCompra: string; proveedorId: number; observaciones: string | null; detalle: LineaCompra[] }
export interface FiltrosCompra { buscar: string; estado: string; proveedorId: string; desde: string; hasta: string }
export const comprasApi = {
  listar: (f: FiltrosCompra, signal?: AbortSignal) => { const p = new URLSearchParams(); Object.entries(f).forEach(([k, v]) => { if (v) p.set(k, v); }); return http.get<Compra[]>(`/compras${p.size ? `?${p}` : ""}`, signal); },
  consultar: (id: number, signal?: AbortSignal) => http.get<DocumentoCompra>(`/compras/${id}`, signal),
  destinos: (proveedor: number, signal?: AbortSignal) => http.get<DestinoCompra[]>(`/compras/catalogos/destinos?proveedorId=${proveedor}`, signal),
  costos: (repuesto: number, signal?: AbortSignal) => http.get<CostoBodega[]>(`/repuestos/${repuesto}/costos`, signal),
  registrar: (datos: RegistroCompra) => http.post<Compra>("/compras", datos),
  recibir: (id: number, revision: string) => http.post<Compra>(`/compras/${id}/recepcion`, { revision }),
  anular: (id: number, revision: string, motivo: string) => http.post<Compra>(`/compras/${id}/anulacion`, { revision, motivo }),
};
// Se calculan centavos enteros para conservar importes incluso en compras grandes.
export function centavos(valor: string): bigint { const [entero, fraccion = ""] = valor.split("."); return BigInt(entero || "0") * 100n + BigInt((fraccion + "00").slice(0, 2)); }
export function decimalCentavos(valor: bigint): string { return `${valor / 100n}.${(valor % 100n).toString().padStart(2, "0")}`; }
export function quetzales(valor: string | null | undefined, decimales = 2): string {
  if (valor === null || valor === undefined) return "—";
  const [entero, fraccion = ""] = valor.split(".");
  return `Q ${BigInt(entero || "0").toLocaleString("es-GT")}.${(fraccion + "0".repeat(decimales)).slice(0, decimales)}`;
}
