import { http, reiniciarCsrf } from "./http";

export interface UsuarioSesion {
  usuarioId: number;
  nombreUsuario: string;
  nombreCompleto: string;
  empleadoCodigo: string;
}
export interface SesionActual { autenticado: boolean; usuario: UsuarioSesion | null; roles: string[] }
export const authApi = {
  sesion: (signal?: AbortSignal) => http.get<SesionActual>("/auth/sesion", signal),
  login: async (nombreUsuario: string, contrasena: string) => {
    const sesion = await http.post<SesionActual>("/auth/login", { nombreUsuario, contrasena });
    reiniciarCsrf();
    return sesion;
  },
  logout: async () => {
    await http.post<SesionActual>("/auth/logout");
    reiniciarCsrf();
  },
};
