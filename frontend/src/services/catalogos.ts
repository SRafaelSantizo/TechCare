/**
 * Catalogos de referencia.
 *
 * El backend actual NO expone endpoints de catalogo (TipoCliente, Prioridad,
 * EstadoOrden, etc.). Los valores siguientes provienen del script
 * 01_TechCare_Maestro.sql (seccion 03/CATALOGOS INDISPENSABLES) y se usan solo
 * para presentar y validar en la interfaz. El servidor sigue siendo la
 * autoridad: valida TipoClienteID en cada alta/edicion de Cliente.
 *
 * Cuando el backend exponga estos catalogos, reemplazar estas constantes por
 * consultas reales (ver capacidades en src/app/capabilities.ts).
 */

export interface OpcionCatalogo {
  valor: string;
  etiqueta: string;
}

/** TipoCliente (tinyint): 1=Individual, 2=Empresarial. */
export const TIPOS_CLIENTE: ReadonlyArray<{ id: number; nombre: string }> = [
  { id: 1, nombre: "Individual" },
  { id: 2, nombre: "Empresarial" },
];

export function nombreTipoCliente(id: number): string {
  return TIPOS_CLIENTE.find((t) => t.id === id)?.nombre ?? `Tipo ${id}`;
}

/** Prioridad: BAJA, NORMAL, ALTA, URGENTE (con su nivel 1..4). */
export const PRIORIDADES: ReadonlyArray<{ codigo: string; nombre: string; nivel: number }> = [
  { codigo: "BAJA", nombre: "Baja", nivel: 1 },
  { codigo: "NORMAL", nombre: "Normal", nivel: 2 },
  { codigo: "ALTA", nombre: "Alta", nivel: 3 },
  { codigo: "URGENTE", nombre: "Urgente", nivel: 4 },
];

/** Estados del ciclo de servicio (ver TransicionEstadoOrden en el SQL). */
export const ESTADOS_ORDEN: ReadonlyArray<{ codigo: string; nombre: string; esFinal: boolean }> = [
  { codigo: "RECIBIDO", nombre: "Recibido", esFinal: false },
  { codigo: "DIAGNOSTICO", nombre: "Diagnostico", esFinal: false },
  { codigo: "ESPERANDO_AUTORIZACION", nombre: "Esperando autorizacion", esFinal: false },
  { codigo: "REPARACION", nombre: "En reparacion", esFinal: false },
  { codigo: "LISTO", nombre: "Listo para entregar", esFinal: false },
  { codigo: "ENTREGADO", nombre: "Entregado", esFinal: true },
  { codigo: "CANCELADO", nombre: "Cancelado", esFinal: true },
];

export function nombreEstado(codigo: string): string {
  return ESTADOS_ORDEN.find((e) => e.codigo === codigo)?.nombre ?? codigo;
}

export const TIPOS_EQUIPO: ReadonlyArray<{ id: number; nombre: string }> = [
  { id: 1, nombre: "Laptop" },
  { id: 2, nombre: "Escritorio" },
  { id: 3, nombre: "Impresora" },
  { id: 4, nombre: "Equipo de red" },
  { id: 5, nombre: "Otro dispositivo" },
];

export const METODOS_PAGO: ReadonlyArray<{ id: number; nombre: string }> = [
  { id: 1, nombre: "Efectivo" },
  { id: 2, nombre: "Tarjeta" },
  { id: 3, nombre: "Transferencia" },
];

/** Roles funcionales del modelo (tabla Rol). Una cuenta puede tener varios. */
export const ROLES: ReadonlyArray<{ codigo: string; nombre: string }> = [
  { codigo: "ADMIN", nombre: "Administrador" },
  { codigo: "RECEPCION", nombre: "Recepcion" },
  { codigo: "TECNICO", nombre: "Tecnico" },
  { codigo: "BODEGA", nombre: "Bodega" },
  { codigo: "CAJA", nombre: "Caja" },
];
