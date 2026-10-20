import { http } from "./http";

export interface UsuarioAdministracion {
  usuarioId: number;
  empleadoId: number;
  empleadoCodigo: string;
  nombres: string;
  apellidos: string;
  nombreUsuario: string;
  usuarioActivo: boolean;
  empleadoActivo: boolean;
  fechaCreacion: string;
  roles: string[];
}
export interface RolAcceso { codigo: string; nombre: string }
export interface EmpleadoDisponible { empleadoId: number; codigo: string; nombres: string; apellidos: string }
export interface RegistroUsuario {
  nombreUsuario: string;
  contrasena: string;
  roles: string[];
  empleadoId: number | null;
  empleadoNuevo: { codigo: string; nombres: string; apellidos: string } | null;
}
export const usuariosApi = {
  listar: (signal?: AbortSignal) => http.get<UsuarioAdministracion[]>("/admin/usuarios", signal),
  roles: (signal?: AbortSignal) => http.get<RolAcceso[]>("/admin/roles", signal),
  empleados: (signal?: AbortSignal) => http.get<EmpleadoDisponible[]>("/admin/empleados-disponibles", signal),
  registrar: (datos: RegistroUsuario) => http.post<UsuarioAdministracion>("/admin/usuarios", datos),
};
