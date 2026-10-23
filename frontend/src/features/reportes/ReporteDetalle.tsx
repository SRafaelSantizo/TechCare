import { Dialog } from "../../components/ui/Dialog";
import { Button } from "../../components/ui/Button";
import { DataTable, type Columna } from "../../components/ui/DataTable";
import { Alert } from "../../components/ui/Alert";
import { formatoReporte, type DefinicionReporte } from "../../services/reportes";
const listas: Record<string, [string, string, string][]> = {
  HistorialEstados: [["EstadoAnterior", "Anterior", "texto"], ["EstadoNuevo", "Nuevo", "texto"], ["Fecha", "Fecha", "fechaHora"], ["Responsable", "Responsable", "texto"], ["Observacion", "Observación", "texto"]],
  RepuestosYMovimientos: [["Linea", "Línea", "entero"], ["Codigo", "Código", "texto"], ["Repuesto", "Repuesto", "texto"], ["Bodega", "Bodega", "texto"], ["Cantidad", "Cantidad", "entero"], ["CostoUnitario", "Costo histórico", "moneda"], ["PrecioUnitario", "Precio histórico", "moneda"], ["MovimientoID", "Movimiento", "entero"], ["Fecha", "Fecha", "fechaHora"], ["ExistenciaResultante", "Saldo histórico", "entero"]],
  Pagos: [["PagoID", "Pago", "entero"], ["Fecha", "Fecha", "fechaHora"], ["Monto", "Monto", "moneda"], ["Metodo", "Medio de pago", "texto"], ["Referencia", "Referencia", "texto"]],
};
function Coleccion({ clave, valor }: { clave: string; valor: string | null }) {
  let filas: Record<string, unknown>[];
  try { const parsed: unknown = JSON.parse(valor ?? "[]"); if (!Array.isArray(parsed) || parsed.some(v => !v || typeof v !== "object")) throw new Error(); filas = parsed; }
  catch { return <Alert tono="danger">No se pudo leer esta parte de la trazabilidad. Actualizá el reporte.</Alert>; }
  const columnas: Columna<Record<string, unknown>>[] = (listas[clave] ?? []).map(([k, t, tipo]) => ({ clave: k, encabezado: t, numerica: tipo === "entero" || tipo === "moneda", render: r => <span style={{ whiteSpace: "pre-wrap", overflowWrap: "anywhere" }}>{formatoReporte(r[k], tipo)}</span> }));
  return <DataTable columnas={columnas} filas={filas} claveFila={r => filas.indexOf(r)} vacio="Sin registros en esta etapa." />;
}
export function ReporteDetalle({ reporte, fila, onCerrar }: { reporte: DefinicionReporte; fila: Record<string, string | null>; onCerrar: () => void }) {
  return <Dialog abierto titulo={`${reporte.codigo} · Detalle del registro`} ancho={1100} onCerrar={onCerrar}>
    <div className="tc-stack"><p data-autofocus tabIndex={-1} style={{ margin: 0, outline: "none" }}>{reporte.titulo}</p>
      <dl className="tc-grid tc-grid--2">{reporte.columnas.filter(c => c.tipo !== "coleccion").map(c => <div key={c.clave}><dt className="tc-field__hint">{c.titulo}</dt><dd style={{ margin: 0, whiteSpace: "pre-wrap", overflowWrap: "anywhere" }}>{formatoReporte(fila[c.clave], c.tipo)}</dd></div>)}</dl>
      {reporte.columnas.filter(c => c.tipo === "coleccion").map(c => <section key={c.clave} style={{ minWidth: 0 }}><h3 className="tc-section-title">{c.titulo}</h3><Coleccion clave={c.clave} valor={fila[c.clave]} /></section>)}
      <Button onClick={onCerrar}>Cerrar detalle</Button>
    </div>
  </Dialog>;
}
