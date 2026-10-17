import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from "react";

/**
 * Contexto de sesion.
 *
 * El backend actual NO expone autenticacion: no existe controlador de login ni
 * de "sesion actual". Por eso `autenticacionPendiente` es true y no se simula
 * un usuario administrador ni se verifica la contrasena en el navegador.
 *
 * Cuando el backend agregue /api/auth/sesion y /api/auth/login, reemplazar el
 * cuerpo de `iniciarSesion`/`cargarSesion` por llamadas reales. La funcion
 * `puedeAcceder` ya consume `roles` para las guardas por rol de la navegacion;
 * con la sesion pendiente no oculta modulos porque el servidor no autoriza.
 */

export interface UsuarioSesion {
  usuarioId: number;
  nombreUsuario: string;
  nombreCompleto: string;
  empleadoCodigo: string;
}

export interface SesionActual {
  autenticado: boolean;
  usuario: UsuarioSesion | null;
  roles: string[];
  /** true mientras no exista un endpoint real de autenticacion. */
  autenticacionPendiente: boolean;
}

interface SessionContextValue extends SesionActual {
  iniciarSesion: (nombreUsuario: string, contrasena: string) => Promise<void>;
  continuarSinAutenticar: () => void;
  cerrarSesion: () => void;
}

const SessionContext = createContext<SessionContextValue | null>(null);

const SESION_PENDIENTE: SesionActual = {
  autenticado: false,
  usuario: null,
  roles: [],
  autenticacionPendiente: true,
};

export function SessionProvider({ children }: { children: ReactNode }) {
  const [sesion, setSesion] = useState<SesionActual>(SESION_PENDIENTE);

  const iniciarSesion = useCallback(async (_nombreUsuario: string, _contrasena: string) => {
    // No se llama a una ruta supuesta: /api/auth/login no existe en el backend.
    // Se informa la dependencia en lugar de simular una autenticacion.
    throw new Error(
      "La autenticacion no esta disponible: el backend no expone un endpoint de sesion. " +
        "Registrar /api/auth/login y /api/auth/sesion antes de habilitar el acceso.",
    );
  }, []);

  const continuarSinAutenticar = useCallback(() => {
    setSesion({ autenticado: false, usuario: null, roles: [], autenticacionPendiente: true });
  }, []);

  const cerrarSesion = useCallback(() => setSesion(SESION_PENDIENTE), []);

  const value = useMemo<SessionContextValue>(
    () => ({ ...sesion, iniciarSesion, continuarSinAutenticar, cerrarSesion }),
    [sesion, iniciarSesion, continuarSinAutenticar, cerrarSesion],
  );

  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>;
}

export function useSession(): SessionContextValue {
  const ctx = useContext(SessionContext);
  if (!ctx) {
    throw new Error("useSession debe usarse dentro de SessionProvider.");
  }
  return ctx;
}

/**
 * Guarda de interfaz por rol. Es una ayuda visual y NUNCA sustituye la
 * autorizacion del servidor. Mientras la sesion este pendiente (sin roles) no
 * oculta modulos, para no aparentar una seguridad inexistente.
 */
export function puedeAcceder(sesion: SesionActual, rolesRequeridos?: string[]): boolean {
  if (!rolesRequeridos || rolesRequeridos.length === 0) return true;
  if (sesion.autenticacionPendiente || sesion.roles.length === 0) return true;
  if (sesion.roles.includes("ADMIN")) return true;
  return rolesRequeridos.some((r) => sesion.roles.includes(r));
}
