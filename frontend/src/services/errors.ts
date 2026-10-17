import type { ApiErrorBody } from "../types/api";

/**
 * Error normalizado de la capa HTTP.
 * Conserva el codigo, el mensaje de negocio del backend y los errores por campo
 * para que la interfaz pueda distinguir sesion vencida, permiso, validacion,
 * conflicto y fallo del servidor sin convertir un fallo en exito.
 */
export class ApiError extends Error {
  readonly status: number;
  readonly fieldErrors: Record<string, string>;
  readonly body: unknown;

  constructor(status: number, message: string, fieldErrors: Record<string, string> = {}, body?: unknown) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.fieldErrors = fieldErrors;
    this.body = body;
  }

  get isNetwork(): boolean {
    return this.status === 0;
  }
  get isUnauthorized(): boolean {
    return this.status === 401;
  }
  get isForbidden(): boolean {
    return this.status === 403;
  }
  get isNotFound(): boolean {
    return this.status === 404;
  }
  get isValidation(): boolean {
    return this.status === 400 && Object.keys(this.fieldErrors).length > 0;
  }
  get isConflict(): boolean {
    return this.status === 409;
  }
  get isServer(): boolean {
    return this.status >= 500;
  }
}

/** Mensaje legible para el usuario final a partir de un error desconocido. */
export function mensajeDeError(error: unknown, contexto = "la operacion"): string {
  if (error instanceof ApiError) {
    if (error.isNetwork) {
      return "No se pudo contactar con el servidor. Verifica que el backend este en ejecucion y que la URL base sea correcta.";
    }
    return error.message;
  }
  if (error instanceof Error && error.message) {
    return error.message;
  }
  return `No se pudo completar ${contexto}.`;
}

export function esApiError(error: unknown): error is ApiError {
  return error instanceof ApiError;
}

export function parseApiErrorBody(body: unknown): ApiErrorBody | null {
  if (body && typeof body === "object" && "mensaje" in body) {
    return body as ApiErrorBody;
  }
  return null;
}
