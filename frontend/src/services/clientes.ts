import { http } from "./http";
import type { Cliente, ClienteDatos } from "../types/api";

/**
 * ClienteController.java (contrato verificado en el backend actual):
 *   GET    /api/clientes        -> Cliente[]        (sin paginacion)
 *   GET    /api/clientes/{id}   -> Cliente          (404 si no existe)
 *   POST   /api/clientes        -> Cliente (201)    body: ClienteDatos
 *   PUT    /api/clientes/{id}   -> Cliente          body: ClienteDatos
 * No existe DELETE: ClienteController no expone eliminacion fisica.
 * La desactivacion se hace con Activo=false via PUT.
 */
export const clientesApi = {
  listar: (signal?: AbortSignal) => http.get<Cliente[]>("/clientes", signal),
  consultar: (id: number, signal?: AbortSignal) => http.get<Cliente>(`/clientes/${id}`, signal),
  crear: (datos: ClienteDatos) => http.post<Cliente>("/clientes", datos),
  actualizar: (id: number, datos: ClienteDatos) => http.put<Cliente>(`/clientes/${id}`, datos),
};

export const clientesKeys = {
  all: ["clientes"] as const,
  list: () => [...clientesKeys.all, "list"] as const,
  detail: (id: number) => [...clientesKeys.all, "detail", id] as const,
};
