import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { authApi, type SesionActual } from "../services/auth";
import { esApiError, mensajeDeError } from "../services/errors";
import { reiniciarCsrf, SESION_EXPIRADA } from "../services/http";
import { queryClient } from "./queryClient";
export type { SesionActual, UsuarioSesion } from "../services/auth";

interface SessionContextValue extends SesionActual {
  cargando: boolean;
  errorSesion: string | null;
  iniciarSesion: (nombreUsuario: string, contrasena: string) => Promise<void>;
  cerrarSesion: () => Promise<void>;
  cargarSesion: (signal?: AbortSignal) => Promise<void>;
}
const SessionContext = createContext<SessionContextValue | null>(null);
const SIN_SESION: SesionActual = { autenticado: false, usuario: null, roles: [] };

export function SessionProvider({ children }: { children: ReactNode }) {
  const [sesion, setSesion] = useState<SesionActual>(SIN_SESION);
  const [cargando, setCargando] = useState(true);
  const [errorSesion, setErrorSesion] = useState<string | null>(null);

  const limpiar = useCallback(() => {
    setSesion(SIN_SESION);
    reiniciarCsrf();
    void queryClient.cancelQueries();
    queryClient.clear();
  }, []);

  const cargarSesion = useCallback(async (signal?: AbortSignal) => {
    setCargando(true);
    setErrorSesion(null);
    try {
      const actual = await authApi.sesion(signal);
      if (!signal?.aborted) setSesion(actual);
    } catch (error) {
      if (signal?.aborted) return;
      setSesion(SIN_SESION);
      if (!(esApiError(error) && error.isUnauthorized)) setErrorSesion(mensajeDeError(error, "la sesión"));
    } finally { if (!signal?.aborted) setCargando(false); }
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    void cargarSesion(controller.signal);
    return () => controller.abort();
  }, [cargarSesion]);
  useEffect(() => {
    const vencida = () => { limpiar(); setErrorSesion("Tu sesión venció. Iniciá sesión nuevamente."); };
    window.addEventListener(SESION_EXPIRADA, vencida);
    return () => window.removeEventListener(SESION_EXPIRADA, vencida);
  }, [limpiar]);

  const iniciarSesion = useCallback(async (nombreUsuario: string, contrasena: string) => {
    const actual = await authApi.login(nombreUsuario, contrasena);
    await queryClient.cancelQueries();
    queryClient.clear();
    setErrorSesion(null);
    setSesion(actual);
  }, []);
  const cerrarSesion = useCallback(async () => { await authApi.logout(); limpiar(); }, [limpiar]);
  const value = useMemo(() => ({ ...sesion, cargando, errorSesion, iniciarSesion, cerrarSesion, cargarSesion }),
    [sesion, cargando, errorSesion, iniciarSesion, cerrarSesion, cargarSesion]);
  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>;
}

export function useSession(): SessionContextValue {
  const ctx = useContext(SessionContext);
  if (!ctx) throw new Error("useSession debe usarse dentro de SessionProvider.");
  return ctx;
}

export function puedeAcceder(sesion: SesionActual, rolesRequeridos?: string[]): boolean {
  if (!sesion.autenticado || sesion.roles.length === 0) return false;
  if (!rolesRequeridos?.length || sesion.roles.includes("ADMIN")) return true;
  return rolesRequeridos.some(rol => sesion.roles.includes(rol));
}
