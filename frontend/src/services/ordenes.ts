import { http } from "./http";
export interface Orden {
  ordenId: number; numeroOrden: string; equipoId: number; numeroSerie: string;
  equipoDescripcion: string; marca: string; modelo: string; clienteId: number; cliente: string; nit: string;
  usuarioRecepcionId: number; recepcionista: string; fechaIngreso: string; problemaReportado: string;
  prioridadCodigo: string; prioridad: string; estadoCodigo: string; estado: string; esFinal: boolean;
  fechaEstimada: string | null; observaciones: string | null; usuarioTecnicoId: number | null; tecnico: string | null;
  diagnosticoId: number | null; fechaDiagnostico: string | null; descripcionDiagnostico: string | null;
  costoEstimado: number | null; reparacionId: number | null; fechaInicioReparacion: string | null;
  fechaFinReparacion: string | null; descripcionTrabajo: string | null; costoManoObra: number | null;
  estadoReparacion: string | null;
}
export interface EventoOrden {
  eventoId: string; tipo: "ESTADO" | "ASIGNACION"; fecha: string; usuario: string; nombreUsuario: string;
  estadoAnterior: string | null; estadoNuevo: string | null; tecnico: string | null; observacion: string | null;
}
export interface CatalogoOrden { codigo: string; nombre: string; nivel: number | null; esFinal: boolean | null }
export interface TecnicoOrden { usuarioId: number; empleadoCodigo: string; nombre: string }
export interface NuevaOrden { equipoId: number; problema: string; prioridad: string; fechaEstimada: string | null; observaciones: string | null }
export interface FiltrosOrden { buscar: string; estado: string; prioridad: string; tecnicoId: string; desde: string; hasta: string }
export const ordenesApi = {
  listar: (filtros: FiltrosOrden, signal?: AbortSignal) => {
    const parametros = new URLSearchParams();
    Object.entries(filtros).forEach(([clave, valor]) => { if (valor) parametros.set(clave, valor); });
    return http.get<Orden[]>(`/ordenes?${parametros}`, signal);
  },
  consultar: (id: number, signal?: AbortSignal) => http.get<Orden>(`/ordenes/${id}`, signal),
  historial: (id: number, signal?: AbortSignal) => http.get<EventoOrden[]>(`/ordenes/${id}/historial`, signal),
  catalogo: (tipo: "estados" | "prioridades", signal?: AbortSignal) => http.get<CatalogoOrden[]>(`/ordenes/catalogos/${tipo}`, signal),
  tecnicos: (signal?: AbortSignal) => http.get<TecnicoOrden[]>("/ordenes/catalogos/tecnicos", signal),
  crear: (datos: NuevaOrden) => http.post<Orden>("/ordenes", datos),
  asignar: (id: number, tecnicoId: number, tecnicoAnteriorId: number | null, observacion: string) =>
    http.put<Orden>(`/ordenes/${id}/tecnico`, { tecnicoId, tecnicoAnteriorId, observacion }),
  cancelar: (id: number, motivo: string) => http.post<Orden>(`/ordenes/${id}/cancelacion`, { motivo }),
};
