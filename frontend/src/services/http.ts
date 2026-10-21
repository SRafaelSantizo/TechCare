import { ApiError, parseApiErrorBody } from "./errors";

const BASE_URL = (import.meta.env.VITE_API_BASE_URL ?? "/api").replace(/\/$/, "");
export const API_BASE_URL = BASE_URL;
export const SESION_EXPIRADA = "techcare:sesion-expirada";
interface TokenCsrf { headerName: string; token: string }
interface RequestOptions { method?: string; body?: unknown; signal?: AbortSignal }
let csrf: TokenCsrf | null = null;
let csrfPendiente: Promise<TokenCsrf> | null = null;
let generacion = 0;

export function reiniciarCsrf() {
  csrf = null;
  csrfPendiente = null;
  generacion++;
}

async function solicitar(url: string, init: RequestInit): Promise<Response> {
  try { return await fetch(url, { ...init, credentials: "include" }); }
  catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") throw error;
    throw new ApiError(0, "No se pudo contactar con el servidor.", {}, error);
  }
}

async function leer(respuesta: Response): Promise<unknown> {
  const texto = await respuesta.text();
  if (!texto) return null;
  try { return JSON.parse(texto); } catch { return texto; }
}

function errorHttp(respuesta: Response, datos: unknown): ApiError {
  const cuerpo = parseApiErrorBody(datos);
  return new ApiError(respuesta.status, cuerpo?.mensaje ?? `La operación falló (HTTP ${respuesta.status}).`, cuerpo?.errores ?? {}, datos);
}

async function obtenerCsrf(): Promise<TokenCsrf> {
  if (csrf) return csrf;
  if (csrfPendiente) return csrfPendiente;
  const actual = generacion;
  const tarea = (async () => {
    const respuesta = await solicitar(`${BASE_URL}/auth/csrf`, { method: "GET" });
    const datos = await leer(respuesta);
    if (!respuesta.ok) throw errorHttp(respuesta, datos);
    const token = datos as TokenCsrf;
    if (!token?.token || token.headerName !== "X-CSRF-TOKEN") throw new ApiError(500, "No se pudo preparar la seguridad de la sesión.");
    if (actual === generacion) csrf = token;
    return token;
  })();
  csrfPendiente = tarea;
  try { return await tarea; }
  finally { if (actual === generacion) csrfPendiente = null; }
}

export async function apiRequest<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { method = "GET", body, signal } = options;
  const escritura = !["GET", "HEAD", "OPTIONS"].includes(method);
  for (let intento = 0; intento < 2; intento++) {
    const headers: Record<string, string> = {};
    if (body !== undefined) headers["Content-Type"] = "application/json";
    if (escritura) {
      const token = await obtenerCsrf();
      headers[token.headerName] = token.token;
    }
    const respuesta = await solicitar(`${BASE_URL}${path}`, {
      method, signal, headers, body: body === undefined ? undefined : JSON.stringify(body),
    });
    const datos = await leer(respuesta);
    const rechazoCsrf = respuesta.status === 403 && datos && typeof datos === "object" && "codigo" in datos && datos.codigo === "CSRF_INVALIDO";
    // Solo se reintenta cuando el filtro de seguridad rechazó antes de ejecutar la operación.
    if (escritura && intento === 0 && rechazoCsrf) { reiniciarCsrf(); continue; }
    if (!respuesta.ok) {
      if (respuesta.status === 401 && !path.startsWith("/auth/")) {
        reiniciarCsrf();
        window.dispatchEvent(new Event(SESION_EXPIRADA));
      }
      throw errorHttp(respuesta, datos);
    }
    return datos as T;
  }
  throw new ApiError(403, "No se pudo verificar la seguridad de la sesión. Volvé a iniciar sesión.");
}

export const http = {
  get: <T>(path: string, signal?: AbortSignal) => apiRequest<T>(path, { signal }),
  post: <T>(path: string, body?: unknown) => apiRequest<T>(path, { method: "POST", body }),
  put: <T>(path: string, body: unknown) => apiRequest<T>(path, { method: "PUT", body }),
};

export async function descargarPdf(path: string): Promise<Blob> {
  const respuesta = await solicitar(`${BASE_URL}${path}`, { method: "GET", headers: { Accept: "application/pdf, application/json" } });
  if (!respuesta.ok) {
    if (respuesta.status === 401) { reiniciarCsrf(); window.dispatchEvent(new Event(SESION_EXPIRADA)); }
    throw errorHttp(respuesta, await leer(respuesta));
  }
  if (!respuesta.headers.get("Content-Type")?.toLowerCase().startsWith("application/pdf"))
    throw new ApiError(502, "El servidor no devolvió una factura PDF válida.");
  return respuesta.blob();
}
