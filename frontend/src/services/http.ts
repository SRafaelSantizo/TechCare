import { ApiError, parseApiErrorBody } from "./errors";

/**
 * Capa HTTP centralizada.
 *
 * - URL base desde VITE_API_BASE_URL (por defecto "/api", relativo, resuelto por
 *   el proxy de desarrollo de Vite; ver vite.config.ts).
 * - `credentials: "include"` para reutilizar cookies si el backend agrega sesion.
 *   Hoy ClienteController no exige autenticacion, pero no se asume token/JWT.
 * - No hay ninguna consulta SQL ni credencial de base de datos en el navegador.
 */

const BASE_URL = (import.meta.env.VITE_API_BASE_URL ?? "/api").replace(/\/$/, "");

export const API_BASE_URL = BASE_URL;

interface RequestOptions {
  method?: string;
  body?: unknown;
  signal?: AbortSignal;
}

export async function apiRequest<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { method = "GET", body, signal } = options;

  let respuesta: Response;
  try {
    respuesta = await fetch(`${BASE_URL}${path}`, {
      method,
      signal,
      credentials: "include",
      headers: body === undefined ? undefined : { "Content-Type": "application/json" },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      throw error;
    }
    throw new ApiError(0, "No se pudo contactar con el servidor.", {}, error);
  }

  const texto = await respuesta.text();
  const datos = texto.length > 0 ? safeParse(texto) : null;

  if (!respuesta.ok) {
    const cuerpo = parseApiErrorBody(datos);
    throw new ApiError(
      respuesta.status,
      cuerpo?.mensaje ?? `La operacion fallo (HTTP ${respuesta.status}).`,
      cuerpo?.errores ?? {},
      datos,
    );
  }

  return datos as T;
}

export const http = {
  get: <T>(path: string, signal?: AbortSignal) => apiRequest<T>(path, { signal }),
  post: <T>(path: string, body: unknown) => apiRequest<T>(path, { method: "POST", body }),
  put: <T>(path: string, body: unknown) => apiRequest<T>(path, { method: "PUT", body }),
};

function safeParse(texto: string): unknown {
  try {
    return JSON.parse(texto);
  } catch {
    return texto;
  }
}
