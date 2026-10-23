import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Link, useParams, useSearchParams } from "react-router-dom";
import { RefreshCw } from "lucide-react";
import { Card, PageHeader } from "../../components/ui/Card";
import { Alert } from "../../components/ui/Alert";
import { Badge } from "../../components/ui/Badge";
import { Button } from "../../components/ui/Button";
import { Dialog } from "../../components/ui/Dialog";
import { DataTable, Paginacion, type Columna } from "../../components/ui/DataTable";
import { Field, SelectInput, TextInput } from "../../components/ui/inputs";
import { LoadingState } from "../../components/ui/StateView";
import { inventarioApi, unidades, type FiltrosKardex, type Movimiento } from "../../services/inventario";
import { quetzales } from "../../services/compras";
import { mensajeDeError } from "../../services/errors";
import { fechaHora } from "../../utils/format";
import { useSession } from "../../app/session";
import { EstadoStock } from "./InventarioPage";

const vacios: FiltrosKardex = { desde: "", hasta: "", tipo: "" };
export function KardexPage() {
  const ids = useParams(), bodega = Number(ids.bodegaId), repuesto = Number(ids.repuestoId);
  const valido = Number.isInteger(bodega) && bodega > 0 && bodega <= 2147483647 && Number.isInteger(repuesto) && repuesto > 0 && repuesto <= 2147483647;
  const [params, setParams] = useSearchParams(), sesion = useSession();
  const filtros: FiltrosKardex = { desde: params.get("desde") ?? "", hasta: params.get("hasta") ?? "", tipo: params.get("tipo") ?? "" };
  const raw = params.get("pagina") ?? "1", pagina = /^[1-9]\d*$/.test(raw) && Number(raw) <= 2147483647 ? Number(raw) : 1;
  const [entrada, setEntrada] = useState(filtros), [error, setError] = useState(""), [detalle, setDetalle] = useState<Movimiento | null>(null);
  useEffect(() => { setEntrada({ desde: params.get("desde") ?? "", hasta: params.get("hasta") ?? "", tipo: params.get("tipo") ?? "" }); }, [params]);
  const datos = useQuery({ queryKey: ["inventario", "kardex", bodega, repuesto, filtros, pagina], queryFn: ({ signal }) => inventarioApi.kardex(bodega, repuesto, filtros, pagina, signal), enabled: valido });
  function aplicar(f: FiltrosKardex, p = 1) { const q = new URLSearchParams(); Object.entries(f).forEach(([k, v]) => { if (v) q.set(k, v); }); if (p > 1) q.set("pagina", String(p)); setParams(q); }
  const columnas: Columna<Movimiento>[] = [
    { clave: "movimiento", encabezado: "Movimiento", render: m => <><strong>#{m.movimientoId}</strong><div className="tc-field__hint">{fechaHora(m.fecha)}</div><Badge tono={m.tipo === "E" ? "ok" : "info"}>{m.tipo === "E" ? "Entrada" : "Salida"}</Badge></> },
    { clave: "origen", encabezado: "Origen", render: m => m.compraId ? <Link to={`/compras/${m.compraId}`}>{m.numeroCompra}</Link> : sesion.roles.includes("ADMIN") ? <Link to={`/ordenes/${m.ordenId}`}>{m.numeroOrden}</Link> : <span>{m.numeroOrden}</span> },
    { clave: "responsable", encabezado: "Responsable", render: m => m.responsable },
    { clave: "entrada", encabezado: "Entradas", numerica: true, render: m => m.tipo === "E" ? unidades(m.cantidad) : "—" },
    { clave: "salida", encabezado: "Salidas", numerica: true, render: m => m.tipo === "S" ? unidades(m.cantidad) : "—" },
    { clave: "saldo", encabezado: "Saldo histórico", numerica: true, render: m => unidades(m.existenciaResultante) },
    { clave: "costo", encabezado: "Costo unitario histórico", numerica: true, render: m => quetzales(m.costoUnitario) },
    { clave: "promedio", encabezado: "Promedio posterior", numerica: true, render: m => quetzales(m.costoPosterior, 6) },
    { clave: "detalle", encabezado: "Detalle", render: m => <Button tamano="sm" onClick={() => setDetalle(m)}>Ver movimiento</Button> },
  ];
  const i = datos.data?.inventario, r = datos.data?.resumen;
  return <>
    <PageHeader eyebrow="Inventario y compras" titulo="Kardex del repuesto" descripcion={i ? `${i.codigo} · ${i.repuesto} · ${i.bodega}` : "Historial de entradas y salidas por bodega."}
      acciones={<><Link to="/inventario" className="tc-btn">Volver al inventario</Link><Button icono={<RefreshCw size={16} />} disabled={!valido || datos.isFetching} onClick={() => datos.refetch()}>Actualizar</Button></>} />
    <div className="tc-stack">
      {!valido ? <Alert tono="danger">La bodega o el repuesto de la dirección no es válido.</Alert> : <>
        <Card><form className="tc-stack" onSubmit={e => { e.preventDefault(); if (entrada.desde && entrada.hasta && entrada.desde > entrada.hasta) { setError("La fecha inicial no puede ser posterior a la final."); return; } setError(""); aplicar(entrada); }}>
          <div className="tc-grid tc-grid--2"><Field label="Desde (día UTC)" htmlFor="k-desde"><TextInput id="k-desde" type="date" min="0001-01-01" max="9999-12-31" value={entrada.desde} onChange={e => setEntrada(v => ({ ...v, desde: e.target.value }))} /></Field>
            <Field label="Hasta (día UTC, incluido)" htmlFor="k-hasta"><TextInput id="k-hasta" type="date" min="0001-01-01" max="9999-12-31" value={entrada.hasta} onChange={e => setEntrada(v => ({ ...v, hasta: e.target.value }))} /></Field>
            <Field label="Mostrar movimientos" htmlFor="k-tipo"><SelectInput id="k-tipo" value={entrada.tipo} onChange={e => setEntrada(v => ({ ...v, tipo: e.target.value }))}><option value="">Entradas y salidas</option><option value="E">Solo entradas</option><option value="S">Solo salidas</option></SelectInput></Field></div>
          <div className="tc-row"><Button type="submit" variante="primario">Buscar</Button><Button type="button" onClick={() => { setEntrada(vacios); aplicar(vacios); setError(""); }}>Limpiar</Button></div>
        </form></Card>
        {error ? <Alert tono="danger">{error}</Alert> : null}
        {datos.isLoading ? <LoadingState titulo="Cargando kardex…" /> : datos.isError ? <Alert tono="danger" accion={<Button onClick={() => datos.refetch()}>Reintentar</Button>}>{mensajeDeError(datos.error)}</Alert> : i && r ? <>
          <Card><div className="tc-row"><EstadoStock estado={i.estadoStock} />{!i.bodegaActiva ? <Badge>Bodega inactiva</Badge> : null}{!i.repuestoActivo ? <Badge>Repuesto inactivo</Badge> : null}</div>
            <p>Existencias actuales: <strong>{unidades(i.existencia)}</strong> · Mínimo: {unidades(i.stockMinimo)} · Promedio actual: <strong>{quetzales(i.costoPromedio, 6)}</strong></p></Card>
          <div className="tc-grid tc-grid--cards">{[["Saldo inicial del período", r.saldoInicial], ["Entradas del período", r.entradas], ["Salidas del período", r.salidas], ["Saldo al cierre del período", r.saldoFinal]].map(([label, value]) => <Card key={label}><div className="tc-metric__label">{label}</div><div className="tc-metric__value">{unidades(value)}</div></Card>)}</div>
          <Alert tono="info">Los saldos y totales del período incluyen entradas y salidas completas, aunque filtres un tipo o cambies de página. Las horas de cada movimiento se muestran en tu zona horaria.</Alert>
          <DataTable columnas={columnas} filas={datos.data?.filas ?? []} claveFila={m => m.movimientoId} vacio="No hay movimientos para estos filtros." />
          <Paginacion pagina={datos.data?.pagina ?? 1} totalPaginas={datos.data?.totalPaginas ?? 1} total={datos.data?.total ?? 0} onCambiar={p => aplicar(filtros, p)} />
        </> : null}
      </>}
    </div>
    {detalle ? <Dialog abierto titulo={`Movimiento #${detalle.movimientoId}`} onCerrar={() => setDetalle(null)}>
      <div className="tc-stack"><p data-autofocus tabIndex={-1} style={{ margin: 0, outline: "none" }}>{i?.repuesto} · {i?.bodega}</p><dl className="tc-stack">{[
        ["Tipo y fecha", `${detalle.tipo === "E" ? "Entrada" : "Salida"} · ${fechaHora(detalle.fecha)}`],
        ["Documento y línea", `${detalle.numeroCompra ?? detalle.numeroOrden} · línea ${detalle.lineaCompra ?? detalle.lineaReparacion}`],
        ["Proveedor", detalle.proveedor ?? "No corresponde"], ["Responsable", `${detalle.responsable} · usuario #${detalle.usuarioId}`],
        ["Nombre del responsable", detalle.nombreHistorico ? "Conservado al recibir la compra" : "Nombre actual del empleado; el ID y el movimiento son históricos"],
        ["Existencias antes / después", `${unidades(detalle.existenciaAnterior)} / ${unidades(detalle.existenciaResultante)}`],
        ["Cantidad", unidades(detalle.cantidad)], ["Costo unitario histórico", quetzales(detalle.costoUnitario)], ["Importe del movimiento", quetzales(detalle.importe)],
        ["Promedio antes / después", `${quetzales(detalle.costoAnterior, 6)} / ${quetzales(detalle.costoPosterior, 6)}`],
        ["Valor de existencias después", quetzales(detalle.valorExistencia, 6)],
        ["Origen del promedio histórico", detalle.esMigracion === null ? "Sin valoración disponible" : detalle.esMigracion ? "Reconstruido desde los movimientos al instalar costos por bodega" : "Conservado al registrar el movimiento"],
      ].map(([label, value]) => <div key={label}><dt className="tc-field__hint">{label}</dt><dd style={{ margin: 0, overflowWrap: "anywhere" }}>{value}</dd></div>)}</dl>
      <Button onClick={() => setDetalle(null)}>Cerrar</Button></div>
    </Dialog> : null}
  </>;
}
