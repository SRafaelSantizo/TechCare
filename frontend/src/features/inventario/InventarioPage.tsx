import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Link, useSearchParams } from "react-router-dom";
import { RefreshCw } from "lucide-react";
import { Card, PageHeader } from "../../components/ui/Card";
import { Alert } from "../../components/ui/Alert";
import { Badge } from "../../components/ui/Badge";
import { Button } from "../../components/ui/Button";
import { DataTable, Paginacion, type Columna } from "../../components/ui/DataTable";
import { Field, SelectInput, TextInput } from "../../components/ui/inputs";
import { LoadingState } from "../../components/ui/StateView";
import { abastecimientoApi } from "../../services/abastecimiento";
import { inventarioApi, unidades, type Existencia, type FiltrosInventario } from "../../services/inventario";
import { quetzales } from "../../services/compras";
import { mensajeDeError } from "../../services/errors";

const vacios: FiltrosInventario = { buscar: "", bodegaId: "", categoriaId: "", estadoStock: "", activo: "" };
export function EstadoStock({ estado }: { estado: Existencia["estadoStock"] }) {
  return <Badge tono={estado === "SIN_EXISTENCIA" ? "danger" : estado === "BAJO" ? "warn" : "ok"}>
    {estado === "SIN_EXISTENCIA" ? "Sin existencias" : estado === "BAJO" ? "En mínimo o por debajo" : "Disponible"}</Badge>;
}
const columnas: Columna<Existencia>[] = [
  { clave: "bodega", encabezado: "Bodega", render: r => <>{r.bodega}<div className="tc-field__hint">{r.codigoBodega}{!r.bodegaActiva ? " · Inactiva" : ""}</div></> },
  { clave: "repuesto", encabezado: "Repuesto", render: r => <><strong>{r.repuesto}</strong><div className="tc-field__hint">{r.codigo} · {r.categoria}{!r.repuestoActivo ? " · Inactivo" : ""}</div></> },
  { clave: "existencia", encabezado: "Existencias", numerica: true, render: r => unidades(r.existencia) },
  { clave: "minimo", encabezado: "Mínimo", numerica: true, render: r => unidades(r.stockMinimo) },
  { clave: "faltante", encabezado: "Faltan para el mínimo", numerica: true, render: r => unidades(r.faltante) },
  { clave: "estado", encabezado: "Estado", render: r => <EstadoStock estado={r.estadoStock} /> },
  { clave: "costo", encabezado: "Costo promedio", numerica: true, render: r => quetzales(r.costoPromedio, 6) },
  { clave: "valor", encabezado: "Valor a costo promedio", numerica: true, render: r => quetzales(r.valorExistencia, 6) },
  { clave: "accion", encabezado: "Historial", render: r => <Link className="tc-btn tc-btn--sm" to={`/inventario/${r.bodegaId}/${r.repuestoId}/kardex`}>Ver kardex</Link> },
];
export function InventarioPage() {
  const [params, setParams] = useSearchParams();
  const filtros = Object.fromEntries(Object.keys(vacios).map(k => [k, params.get(k) ?? ""])) as unknown as FiltrosInventario;
  const raw = params.get("pagina") ?? "1", pagina = /^[1-9]\d*$/.test(raw) && Number(raw) <= 2147483647 ? Number(raw) : 1;
  const [entrada, setEntrada] = useState(filtros);
  useEffect(() => { setEntrada(Object.fromEntries(Object.keys(vacios).map(k => [k, params.get(k) ?? ""])) as unknown as FiltrosInventario); }, [params]);
  const datos = useQuery({ queryKey: ["inventario", "listado", filtros, pagina], queryFn: ({ signal }) => inventarioApi.listar(filtros, pagina, signal) });
  const bodegas = useQuery({ queryKey: ["abastecimiento", "bodegas", "filtro"], queryFn: ({ signal }) => abastecimientoApi.bodegas("", undefined, signal) });
  const categorias = useQuery({ queryKey: ["abastecimiento", "categorias"], queryFn: ({ signal }) => abastecimientoApi.categorias(signal) });
  function aplicar(f: FiltrosInventario, p = 1) { const q = new URLSearchParams(); Object.entries(f).forEach(([k, v]) => { if (v) q.set(k, v); }); if (p > 1) q.set("pagina", String(p)); setParams(q); }
  const resumen = datos.data?.resumen;
  return <>
    <PageHeader eyebrow="Inventario y compras" titulo="Inventario por bodega" descripcion="Consultá existencias, mínimos y costo promedio de cada repuesto."
      acciones={<Button icono={<RefreshCw size={16} />} disabled={datos.isFetching} onClick={() => datos.refetch()}>Actualizar</Button>} />
    <div className="tc-stack">
      <Card><form className="tc-stack" onSubmit={e => { e.preventDefault(); aplicar({ ...entrada, buscar: entrada.buscar.trim() }); }}>
        <div className="tc-grid tc-grid--2">
          <Field label="Buscar en inventario" htmlFor="inv-buscar"><TextInput id="inv-buscar" maxLength={150} placeholder="Código, repuesto, categoría o bodega" value={entrada.buscar} onChange={e => setEntrada(v => ({ ...v, buscar: e.target.value }))} /></Field>
          <Field label="Bodega" htmlFor="inv-bodega"><SelectInput id="inv-bodega" value={entrada.bodegaId} disabled={bodegas.isLoading || bodegas.isError} onChange={e => setEntrada(v => ({ ...v, bodegaId: e.target.value }))}><option value="">Todas</option>{bodegas.data?.map(b => <option key={b.bodegaId} value={b.bodegaId}>{b.nombre}{!b.activo ? " (inactiva)" : ""}</option>)}</SelectInput></Field>
          <Field label="Categoría" htmlFor="inv-categoria"><SelectInput id="inv-categoria" value={entrada.categoriaId} disabled={categorias.isLoading || categorias.isError} onChange={e => setEntrada(v => ({ ...v, categoriaId: e.target.value }))}><option value="">Todas</option>{categorias.data?.map(c => <option key={c.categoriaId} value={c.categoriaId}>{c.nombre}</option>)}</SelectInput></Field>
          <Field label="Estado de existencias" htmlFor="inv-estado"><SelectInput id="inv-estado" value={entrada.estadoStock} onChange={e => setEntrada(v => ({ ...v, estadoStock: e.target.value }))}><option value="">Todos</option><option value="SIN_EXISTENCIA">Sin existencias</option><option value="BAJO">En mínimo o por debajo, con existencias</option><option value="DISPONIBLE">Por encima del mínimo</option></SelectInput></Field>
          <Field label="Actividad de los catálogos" htmlFor="inv-activo"><SelectInput id="inv-activo" value={entrada.activo} onChange={e => setEntrada(v => ({ ...v, activo: e.target.value }))}><option value="">Activos e inactivos</option><option value="true">Bodega y repuesto activos</option><option value="false">Bodega o repuesto inactivo</option></SelectInput></Field>
        </div><div className="tc-row"><Button type="submit" variante="primario">Buscar</Button><Button type="button" onClick={() => { setEntrada(vacios); aplicar(vacios); }}>Limpiar</Button></div>
      </form></Card>
      {bodegas.isError ? <Alert tono="danger" accion={<Button onClick={() => bodegas.refetch()}>Reintentar bodegas</Button>}>{mensajeDeError(bodegas.error)}</Alert> : null}
      {categorias.isError ? <Alert tono="danger" accion={<Button onClick={() => categorias.refetch()}>Reintentar categorías</Button>}>{mensajeDeError(categorias.error)}</Alert> : null}
      {datos.isLoading ? <LoadingState titulo="Cargando inventario…" /> : datos.isError ? <Alert tono="danger" accion={<Button onClick={() => datos.refetch()}>Reintentar</Button>}>{mensajeDeError(datos.error)}</Alert> : <>
        <div className="tc-grid tc-grid--cards">{[["Pares bodega / repuesto", resumen?.total], ["Sin existencias", resumen?.sinExistencia], ["En mínimo o por debajo, con stock", resumen?.stockBajo]].map(([label, value]) => <Card key={label}><div className="tc-metric__label">{label}</div><div className="tc-metric__value">{value}</div></Card>)}
          <Card><div className="tc-metric__label">Valor a costo promedio</div><strong style={{ overflowWrap: "anywhere" }}>{quetzales(resumen?.valorTotal, 6)}</strong><div className="tc-field__hint">De todos los resultados del filtro.</div></Card></div>
        <DataTable columnas={columnas} filas={datos.data?.filas ?? []} claveFila={r => `${r.bodegaId}:${r.repuestoId}`} vacio="No hay repuestos asociados para estos filtros." />
        <Paginacion pagina={datos.data?.pagina ?? 1} totalPaginas={datos.data?.totalPaginas ?? 1} total={datos.data?.total ?? 0} onCambiar={p => aplicar(filtros, p)} />
        <Alert tono="info">Las entradas se generan al recibir compras y las salidas al consumir repuestos en una reparación. Configurá el mínimo y las asociaciones desde Bodegas.</Alert>
      </>}
    </div>
  </>;
}
