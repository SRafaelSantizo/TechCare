import { http } from "./http";
import { quetzales } from "./compras";
import { fechaHora } from "../utils/format";
export interface ColumnaReporte { clave: string; titulo: string; tipo: string; visible: boolean }
export interface DefinicionReporte { codigo: string; titulo: string; descripcion: string; filtros: string[]; roles: string[]; columnas: ColumnaReporte[] }
export interface IndicadorReporte { titulo: string; tipo: string; valor: string | null }
export interface ResultadoReporte { codigo: string; titulo: string; filas: Record<string, string | null>[]; indicadores: IndicadorReporte[]; pagina: number; tamano: number; total: number; totalPaginas: number }
export interface OpcionReporte { valor: string; etiqueta: string }
export const reportesApi = {
  catalogo: (signal?: AbortSignal) => http.get<DefinicionReporte[]>("/reportes", signal),
  consultar: (codigo: string, filtros: Record<string, string>, pagina: number, signal?: AbortSignal) => {
    const p = new URLSearchParams({ pagina: String(pagina), tamano: "25" });
    Object.entries(filtros).forEach(([k, v]) => { if (v) p.set(k, v); });
    return http.get<ResultadoReporte>(`/reportes/${codigo}?${p}`, signal);
  },
  opciones: (codigo: string, tipo: string, buscar: string, signal?: AbortSignal) => http.get<OpcionReporte[]>(`/reportes/${codigo}/opciones?${new URLSearchParams({ tipo, buscar })}`, signal),
};
export function formatoReporte(valor: unknown, tipo: string): string {
  if (valor === null || valor === undefined || valor === "") return "—";
  const s = String(valor);
  if (tipo === "moneda" || tipo === "moneda6") return quetzales(s, tipo === "moneda6" ? 6 : 2);
  if (tipo === "entero") return BigInt(s).toLocaleString("es-GT");
  if (tipo === "fechaHora") return fechaHora(s);
  if (tipo === "mes") { const [a, m] = s.split("-"); return `${m}/${a}`; }
  if (tipo === "booleano") return s === "true" || s === "1" ? "Sí" : "No";
  return s;
}
