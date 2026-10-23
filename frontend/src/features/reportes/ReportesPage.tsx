import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { useSearchParams } from "react-router-dom";
import { RefreshCw } from "lucide-react";
import { PageHeader, Card } from "../../components/ui/Card";
import { Alert } from "../../components/ui/Alert";
import { Button } from "../../components/ui/Button";
import { DataTable, Paginacion, type Columna } from "../../components/ui/DataTable";
import { Field, SelectInput } from "../../components/ui/inputs";
import { LoadingState } from "../../components/ui/StateView";
import { reportesApi, formatoReporte, type DefinicionReporte } from "../../services/reportes";
import { mensajeDeError } from "../../services/errors";
import { FiltroReporte } from "./ReporteFiltros";
import { ReporteDetalle } from "./ReporteDetalle";

function ReportePanel({ reporte }: { reporte: DefinicionReporte }) {
  const [params, setParams] = useSearchParams();
  const aplicados = Object.fromEntries(reporte.filtros.map(k => [k, params.get(k) ?? ""]));
  const [entrada, setEntrada] = useState(aplicados), [error, setError] = useState("");
  const [detalle, setDetalle] = useState<Record<string, string | null> | null>(null);
  const consultado = params.get("consultar") === "1", raw = params.get("pagina") ?? "1";
  const pagina = /^[1-9]\d*$/.test(raw) && Number(raw) <= 2147483647 ? Number(raw) : 1;
  useEffect(() => { setEntrada(Object.fromEntries(reporte.filtros.map(k => [k, params.get(k) ?? ""]))); setError(""); setDetalle(null); }, [params, reporte]);
  const datos = useQuery({ queryKey: ["reportes", "consulta", reporte.codigo, aplicados, pagina], queryFn: ({ signal }) => reportesApi.consultar(reporte.codigo, aplicados, pagina, signal), enabled: consultado, staleTime: 0 });
  function aplicar(f: Record<string, string>, p = 1) {
    const q = new URLSearchParams({ reporte: reporte.codigo, consultar: "1" });
    Object.entries(f).forEach(([k, v]) => { if (v.trim()) q.set(k, v.trim()); });
    if (p > 1) q.set("pagina", String(p));
    setParams(q);
  }
  const columnas: Columna<Record<string, string | null>>[] = reporte.columnas.filter(c => c.visible).map(c => ({ clave: c.clave, encabezado: c.titulo, numerica: ["entero", "moneda", "moneda6"].includes(c.tipo), render: r => formatoReporte(r[c.clave], c.tipo) }));
  columnas.push({ clave: "detalle", encabezado: "Detalle", render: r => <Button tamano="sm" onClick={() => setDetalle(r)}>Ver detalle</Button> });
  const pendientes = JSON.stringify(entrada) !== JSON.stringify(aplicados);
  return <div className="tc-stack">
    <Card><h2 className="tc-section-title">{reporte.codigo} · {reporte.titulo}</h2><p className="tc-section-sub">{reporte.descripcion}</p>
      <form className="tc-stack" onSubmit={e => {
        e.preventDefault();
        if (entrada.desde && entrada.hasta && entrada.desde > entrada.hasta) { setError("La fecha inicial no puede ser posterior a la final."); return; }
        setError("");
        const limpio = Object.fromEntries(Object.entries(entrada).map(([k, v]) => [k, v.trim()]));
        if (consultado && pagina === 1 && JSON.stringify(limpio) === JSON.stringify(aplicados)) void datos.refetch();
        else aplicar(limpio);
      }}>
        <div className="tc-grid tc-grid--2">{reporte.filtros.map(k => <FiltroReporte key={k} codigo={reporte.codigo} nombre={k} valor={entrada[k] ?? ""} onChange={v => setEntrada(a => ({ ...a, [k]: v }))} />)}</div>
        <div className="tc-row"><Button type="submit" variante="primario" disabled={datos.isFetching}>Generar reporte</Button><Button onClick={() => { setError(""); setEntrada(Object.fromEntries(reporte.filtros.map(k => [k, ""]))); setParams({ reporte: reporte.codigo }); }}>Limpiar</Button>
          {consultado ? <Button icono={<RefreshCw size={16} />} disabled={datos.isFetching} onClick={() => datos.refetch()}>Actualizar resultados</Button> : null}</div>
      </form>
    </Card>
    {error ? <Alert tono="danger">{error}</Alert> : null}
    {pendientes && consultado ? <Alert tono="info">Tenés filtros sin aplicar. Los resultados corresponden a la última consulta; pulsá Generar reporte para actualizarlos.</Alert> : null}
    {!consultado ? <Alert tono="info">Elegí los filtros y pulsá Generar reporte. Dejar un filtro vacío incluye todos los registros permitidos para tu usuario.</Alert> : datos.isLoading ? <LoadingState titulo="Generando reporte…" /> : datos.isError ? <Alert tono="danger" accion={<Button onClick={() => datos.refetch()}>Reintentar reporte</Button>}>{mensajeDeError(datos.error)}</Alert> : datos.data ? <>
      <div className="tc-grid tc-grid--cards"><Card><div className="tc-metric__label">Filas del filtro completo</div><div className="tc-metric__value">{formatoReporte(datos.data.total, "entero")}</div></Card>
        {datos.data.indicadores.map(i => <Card key={i.titulo}><div className="tc-metric__label">{i.titulo}</div><strong style={{ overflowWrap: "anywhere" }}>{formatoReporte(i.valor, i.tipo)}</strong></Card>)}</div>
      <DataTable columnas={columnas} filas={datos.data.filas} claveFila={r => datos.data!.filas.indexOf(r)} vacio="No hay registros para estos filtros." />
      <Paginacion pagina={datos.data.pagina} totalPaginas={datos.data.totalPaginas} total={datos.data.total} onCambiar={p => aplicar(aplicados, p)} />
      <p className="tc-field__hint">Los resúmenes se calculan sobre todo el filtro. Las fechas de filtro son días UTC incluidos; las horas de las filas se muestran en tu zona horaria.</p>
    </> : null}
    {detalle ? <ReporteDetalle reporte={reporte} fila={detalle} onCerrar={() => setDetalle(null)} /> : null}
  </div>;
}
export function ReportesPage() {
  const [params, setParams] = useSearchParams();
  const catalogo = useQuery({ queryKey: ["reportes", "catalogo"], queryFn: ({ signal }) => reportesApi.catalogo(signal) });
  const codigo = params.get("reporte") ?? catalogo.data?.[0]?.codigo;
  const seleccionado = catalogo.data?.find(r => r.codigo === codigo);
  return <>
    <PageHeader eyebrow="Reportes" titulo="Reportes del taller" descripcion="Consultas de servicio, inventario y caja según los permisos de tu usuario." />
    <div className="tc-stack">{catalogo.isLoading ? <LoadingState titulo="Cargando reportes disponibles…" /> : catalogo.isError ? <Alert tono="danger" accion={<Button onClick={() => catalogo.refetch()}>Reintentar catálogo</Button>}>{mensajeDeError(catalogo.error)}</Alert> : <>
      <Card><Field label="Reporte" htmlFor="reporte-seleccion"><SelectInput id="reporte-seleccion" value={seleccionado?.codigo ?? ""} onChange={e => setParams({ reporte: e.target.value })}>
        {!seleccionado ? <option value="">Elegí un reporte disponible</option> : null}{catalogo.data?.map(r => <option key={r.codigo} value={r.codigo}>{r.codigo} · {r.titulo}</option>)}
      </SelectInput></Field></Card>
      {seleccionado ? <ReportePanel key={seleccionado.codigo} reporte={seleccionado} /> : <Alert tono="danger">El reporte no está disponible para tu usuario. Elegí uno de la lista.</Alert>}
    </>}</div>
  </>;
}
