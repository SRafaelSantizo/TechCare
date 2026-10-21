import { http } from "./http";
export interface CategoriaRepuesto { categoriaId: number; nombre: string; revision: string }
export interface Repuesto { repuestoId: number; categoriaId: number; categoria: string; codigo: string; nombre: string; descripcion: string | null; costoReferencia: number; precioVenta: number; activo: boolean; revision: string }
export interface Proveedor { proveedorId: number; nit: string; nombre: string; email: string | null; telefono: string | null; direccion: string | null; activo: boolean; revision: string }
export interface Bodega { bodegaId: number; codigo: string; nombre: string; direccion: string | null; activo: boolean; revision: string }
export interface OfertaProveedor { proveedorId: number; repuestoId: number; codigo: string; nombre: string; categoriaId: number; categoria: string; activo: boolean; precioVenta: number; codigoProveedor: string | null; revision: string }
export interface RepuestoBodega { bodegaId: number; repuestoId: number; codigo: string; nombre: string; activo: boolean; stockMinimo: number; existencia: number; costoPromedio: string | null }
export interface PrecioRepuesto { auditoriaId: number; fecha: string; costoAnterior: number; costoNuevo: number; precioAnterior: number; precioNuevo: number; registradoPor: string | null }
export type RepuestoDatos = { categoriaId: number; codigo: string; nombre: string; descripcion: string | null; costoReferencia: string; precioVenta: string; activo: boolean; revision: string | null };
export type ProveedorDatos = Omit<Proveedor, "proveedorId" | "revision"> & { revision: string | null };
export type BodegaDatos = Omit<Bodega, "bodegaId" | "revision"> & { revision: string | null };
export type TipoCatalogo = "repuestos" | "proveedores" | "bodegas";
export type RegistroCatalogo = Repuesto | Proveedor | Bodega;
export const idCatalogo = (r: RegistroCatalogo) => "repuestoId" in r ? r.repuestoId : "proveedorId" in r ? r.proveedorId : r.bodegaId;
function filtros(buscar: string, activo?: boolean, categoriaId?: number) {
  const p = new URLSearchParams(); if (buscar) p.set("buscar", buscar);
  if (activo !== undefined) p.set("activo", String(activo)); if (categoriaId) p.set("categoriaId", String(categoriaId));
  return p.size ? `?${p}` : "";
}
export const abastecimientoApi = {
  categorias: (signal?: AbortSignal) => http.get<CategoriaRepuesto[]>("/repuestos/categorias", signal),
  guardarCategoria: (id: number | null, nombre: string, revision: string | null) => id ? http.put<CategoriaRepuesto>(`/repuestos/categorias/${id}`, { nombre, revision }) : http.post<CategoriaRepuesto>("/repuestos/categorias", { nombre, revision }),
  repuestos: (buscar = "", activo?: boolean, categoriaId?: number, signal?: AbortSignal) => http.get<Repuesto[]>(`/repuestos${filtros(buscar, activo, categoriaId)}`, signal),
  repuesto: (id: number) => http.get<Repuesto>(`/repuestos/${id}`),
  guardarRepuesto: (id: number | null, datos: RepuestoDatos) => id ? http.put<Repuesto>(`/repuestos/${id}`, datos) : http.post<Repuesto>("/repuestos", datos),
  precios: (id: number, signal?: AbortSignal) => http.get<PrecioRepuesto[]>(`/repuestos/${id}/precios`, signal),
  proveedores: (buscar = "", activo?: boolean, signal?: AbortSignal) => http.get<Proveedor[]>(`/proveedores${filtros(buscar, activo)}`, signal),
  proveedor: (id: number) => http.get<Proveedor>(`/proveedores/${id}`),
  guardarProveedor: (id: number | null, datos: ProveedorDatos) => id ? http.put<Proveedor>(`/proveedores/${id}`, datos) : http.post<Proveedor>("/proveedores", datos),
  ofertas: (id: number, signal?: AbortSignal) => http.get<OfertaProveedor[]>(`/proveedores/${id}/repuestos`, signal),
  guardarOferta: (id: number, repuesto: number, codigoProveedor: string | null, ofrecido: boolean, revision: string | null) => http.put<OfertaProveedor | null>(`/proveedores/${id}/repuestos/${repuesto}`, { codigoProveedor, ofrecido, revision }),
  bodegas: (buscar = "", activo?: boolean, signal?: AbortSignal) => http.get<Bodega[]>(`/bodegas${filtros(buscar, activo)}`, signal),
  bodega: (id: number) => http.get<Bodega>(`/bodegas/${id}`),
  guardarBodega: (id: number | null, datos: BodegaDatos) => id ? http.put<Bodega>(`/bodegas/${id}`, datos) : http.post<Bodega>("/bodegas", datos),
  repuestosBodega: (id: number, signal?: AbortSignal) => http.get<RepuestoBodega[]>(`/bodegas/${id}/repuestos`, signal),
  guardarMinimo: (id: number, repuesto: number, stockMinimo: number, stockMinimoEsperado: number | null) => http.put<RepuestoBodega>(`/bodegas/${id}/repuestos/${repuesto}`, { stockMinimo, stockMinimoEsperado }),
};
