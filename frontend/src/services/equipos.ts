import { http } from "./http";

export interface Equipo {
  EquipoID: number;
  ClienteID: number;
  Cliente: string;
  ClienteActivo: boolean;
  ModeloEquipoID: number;
  Modelo: string;
  MarcaID: number;
  Marca: string;
  TipoEquipoID: number;
  TipoEquipo: string;
  NumeroSerie: string;
  Descripcion: string;
  Activo: boolean;
  TieneOrdenes: boolean;
}
export interface EquipoDatos {
  clienteId: number;
  modeloEquipoId: number;
  numeroSerie: string;
  descripcion: string;
  activo: boolean;
}
export interface MarcaEquipo { MarcaID: number; Nombre: string }
export interface TipoEquipo { TipoEquipoID: number; Nombre: string }
export interface ModeloEquipo {
  ModeloEquipoID: number;
  Nombre: string;
  MarcaID: number;
  Marca: string;
  TipoEquipoID: number;
  TipoEquipo: string;
}
export interface HistorialEquipo {
  OrdenID: number;
  NumeroOrden: string;
  FechaIngreso: string | number;
  EstadoCodigo: string;
  Diagnostico: string | null;
  DescripcionTrabajo: string | null;
  FacturaID: number | null;
  Total: number | null;
  Saldo: number | null;
}
export const equiposApi = {
  listar: (clienteId?: number, signal?: AbortSignal) =>
    http.get<Equipo[]>(`/equipos${clienteId ? `?clienteId=${clienteId}` : ""}`, signal),
  consultar: (id: number, signal?: AbortSignal) => http.get<Equipo>(`/equipos/${id}`, signal),
  crear: (datos: EquipoDatos) => http.post<Equipo>("/equipos", datos),
  actualizar: (id: number, datos: EquipoDatos) => http.put<Equipo>(`/equipos/${id}`, datos),
  historial: (id: number, signal?: AbortSignal) => http.get<HistorialEquipo[]>(`/equipos/${id}/historial`, signal),
  tipos: (signal?: AbortSignal) => http.get<TipoEquipo[]>("/catalogos/tipos-equipos", signal),
  marcas: (signal?: AbortSignal) => http.get<MarcaEquipo[]>("/catalogos/marcas", signal),
  modelos: (signal?: AbortSignal) => http.get<ModeloEquipo[]>("/catalogos/modelos-equipos", signal),
};
