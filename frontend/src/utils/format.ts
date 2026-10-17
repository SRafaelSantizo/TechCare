/**
 * Formatos compartidos.
 *
 * Importes: quetzales (es-GT / GTQ) segun la configuracion del proyecto. Los
 * importes definitivos los calcula el backend; aqui solo se presentan.
 *
 * Fechas: la base guarda UTC (README: "Todas las fechas estan en UTC"). Java
 * puede serializarlas como numero (epoch ms) o como cadena ISO. `aFecha` acepta
 * ambas; si llega una cadena sin zona se interpreta como UTC. Se presentan en
 * America/Guatemala. Confirmar el serializador real del backend antes de
 * confiar en fechas sin zona.
 */

const ZONA = "America/Guatemala";

const formatoMoneda = new Intl.NumberFormat("es-GT", {
  style: "currency",
  currency: "GTQ",
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

const formatoFecha = new Intl.DateTimeFormat("es-GT", {
  timeZone: ZONA,
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

const formatoFechaHora = new Intl.DateTimeFormat("es-GT", {
  timeZone: ZONA,
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
});

export function moneda(valor: number | string | null | undefined): string {
  if (valor === null || valor === undefined || valor === "") return "—";
  const n = typeof valor === "string" ? Number(valor) : valor;
  if (Number.isNaN(n)) return "—";
  return formatoMoneda.format(n);
}

export function numero(valor: number | string | null | undefined): string {
  if (valor === null || valor === undefined || valor === "") return "—";
  const n = typeof valor === "string" ? Number(valor) : valor;
  if (Number.isNaN(n)) return "—";
  return new Intl.NumberFormat("es-GT").format(n);
}

export function aFecha(valor: string | number | null | undefined): Date | null {
  if (valor === null || valor === undefined || valor === "") return null;
  if (typeof valor === "number") return new Date(valor);
  const tieneZona = /(Z|[+-]\d{2}:?\d{2})$/.test(valor);
  const normalizado = tieneZona ? valor : `${valor}Z`;
  const fecha = new Date(normalizado);
  return Number.isNaN(fecha.getTime()) ? null : fecha;
}

export function fecha(valor: string | number | null | undefined): string {
  const f = aFecha(valor);
  return f ? formatoFecha.format(f) : "—";
}

export function fechaHora(valor: string | number | null | undefined): string {
  const f = aFecha(valor);
  return f ? formatoFechaHora.format(f) : "—";
}

export function texto(valor: string | null | undefined): string {
  return valor === null || valor === undefined || valor === "" ? "—" : valor;
}

/** Identificacion corta para avatares o marcas de tabla. */
export function iniciales(nombre: string | null | undefined): string {
  if (!nombre) return "?";
  return nombre
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase() ?? "")
    .join("");
}

/** Normaliza texto para busqueda local (acentos/Mayusculas). */
export function normalizar(texto: string): string {
  return texto
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim();
}
