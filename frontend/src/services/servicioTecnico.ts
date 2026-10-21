import { http } from "./http";
import type { Orden } from "./ordenes";

export interface ActividadDisponible { actividadId: number; nombre: string }
export interface ActividadRealizada extends ActividadDisponible { fecha: string; observacion: string | null }
export interface RepuestoDisponible {
  bodegaId: number; bodega: string; repuestoId: number; codigo: string; nombre: string;
  existencia: number; precioUnitario: number;
}
export interface RepuestoUsado {
  linea: number; repuestoId: number; codigo: string; nombre: string; bodegaId: number; bodega: string;
  cantidad: number; precioUnitario: number; importe: number; movimientoId: number | null; fecha: string | null;
}
export const servicioTecnicoApi = {
  iniciarDiagnostico: (id: number) => http.post<Orden>(`/ordenes/${id}/diagnostico/inicio`),
  diagnosticar: (id: number, descripcion: string, costoEstimado: number) =>
    http.post<Orden>(`/ordenes/${id}/diagnostico`, { descripcion, costoEstimado }),
  reparar: (id: number, descripcionTrabajo: string, costoManoObra: number, autorizacion: string) =>
    http.post<Orden>(`/ordenes/${id}/reparacion`, { descripcionTrabajo, costoManoObra, autorizacion }),
  actividades: (id: number, signal?: AbortSignal) => http.get<ActividadRealizada[]>(`/ordenes/${id}/actividades`, signal),
  agregarActividad: (id: number, actividadId: number, observacion: string) =>
    http.post<Orden>(`/ordenes/${id}/actividades`, { actividadId, observacion }),
  repuestos: (id: number, signal?: AbortSignal) => http.get<RepuestoUsado[]>(`/ordenes/${id}/repuestos`, signal),
  consumir: (id: number, repuesto: RepuestoDisponible, cantidad: number) =>
    http.post<Orden>(`/ordenes/${id}/repuestos`, { bodegaId: repuesto.bodegaId, repuestoId: repuesto.repuestoId,
      cantidad, precioUnitarioEsperado: repuesto.precioUnitario }),
  catalogoActividades: (id: number, signal?: AbortSignal) => http.get<ActividadDisponible[]>(`/ordenes/${id}/catalogos/actividades`, signal),
  catalogoRepuestos: (id: number, signal?: AbortSignal) => http.get<RepuestoDisponible[]>(`/ordenes/${id}/catalogos/repuestos`, signal),
  finalizar: (id: number) => http.post<Orden>(`/ordenes/${id}/reparacion/cierre`),
};
