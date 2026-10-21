import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Link, useNavigate } from "react-router-dom";
import { Plus, RefreshCw } from "lucide-react";
import { Card, PageHeader } from "../../components/ui/Card";
import { Alert } from "../../components/ui/Alert";
import { Badge } from "../../components/ui/Badge";
import { Button } from "../../components/ui/Button";
import { Dialog } from "../../components/ui/Dialog";
import { Field, SelectInput, TextInput } from "../../components/ui/inputs";
import { LoadingState } from "../../components/ui/StateView";
import { TablaCatalogo } from "../abastecimiento/compartidos";
import { type Columna } from "../../components/ui/DataTable";
import { comprasApi, quetzales, type Compra, type FiltrosCompra } from "../../services/compras";
import { abastecimientoApi } from "../../services/abastecimiento";
import { mensajeDeError } from "../../services/errors";
import { fechaHora } from "../../utils/format";
import { CompraForm } from "./CompraForm";

export function EstadoCompra({ estado }: { estado: string }) { return <Badge tono={estado === "RECIBIDA" ? "ok" : estado === "ANULADA" ? "danger" : "warn"}>{estado === "RECIBIDA" ? "Recibida" : estado === "ANULADA" ? "Anulada" : "Pendiente"}</Badge>; }
const vacios: FiltrosCompra = { buscar: "", estado: "", proveedorId: "", desde: "", hasta: "" };
const columnas: Columna<Compra>[] = [
  { clave: "numero", encabezado: "Compra", render: c => <><strong>{c.numeroCompra}</strong><div className="tc-field__hint">{fechaHora(c.fecha)}</div></> },
  { clave: "proveedor", encabezado: "Proveedor", render: c => <>{c.proveedor}<div className="tc-field__hint">{c.nit}</div></> },
  { clave: "estado", encabezado: "Estado", render: c => <EstadoCompra estado={c.estado} /> },
  { clave: "total", encabezado: "Total", numerica: true, render: c => quetzales(c.total) },
  { clave: "registro", encabezado: "Registró", render: c => c.registradaPor },
  { clave: "accion", encabezado: "Acción", render: c => <Link className="tc-btn tc-btn--sm" to={`/compras/${c.compraId}`}>Ver compra</Link> },
];
export function ComprasPage() {
  const [entrada, setEntrada] = useState(vacios), [filtros, setFiltros] = useState(vacios), [error, setError] = useState("");
  const [nuevo, setNuevo] = useState(false), [ocupado, setOcupado] = useState(false), navigate = useNavigate();
  const datos = useQuery({ queryKey: ["compras", "listado", filtros], queryFn: ({ signal }) => comprasApi.listar(filtros, signal) });
  const proveedores = useQuery({ queryKey: ["abastecimiento", "proveedores", "filtro"], queryFn: ({ signal }) => abastecimientoApi.proveedores("", undefined, signal) });
  return <>
    <PageHeader eyebrow="Inventario y compras" titulo="Compras y recepción" descripcion="Registrá compras pendientes y confirmá la llegada completa de los repuestos."
      acciones={<><Button variante="primario" icono={<Plus size={16} />} onClick={() => setNuevo(true)}>Nueva compra</Button><Button icono={<RefreshCw size={16} />} disabled={datos.isFetching} onClick={() => datos.refetch()}>Actualizar</Button></>} />
    <div className="tc-stack"><Alert tono="info">Las compras pendientes conservan sus costos y cantidades. Al recibirlas, aumentan las existencias y se calcula el costo promedio de cada bodega.</Alert>
      {error ? <Alert tono="danger">{error}</Alert> : null}
      <Card><form className="tc-stack" onSubmit={e => { e.preventDefault(); if (entrada.desde && entrada.hasta && entrada.desde > entrada.hasta) { setError("La fecha inicial no puede ser posterior a la final."); return; } setError(""); setFiltros({ ...entrada, buscar: entrada.buscar.trim() }); }}>
        <div className="tc-grid tc-grid--2"><Field label="Buscar compra" htmlFor="compras-buscar"><TextInput id="compras-buscar" maxLength={150} placeholder="Número, proveedor o NIT" value={entrada.buscar} onChange={e => setEntrada(v => ({ ...v, buscar: e.target.value }))} /></Field>
          <Field label="Estado de compra" htmlFor="compras-estado"><SelectInput id="compras-estado" value={entrada.estado} onChange={e => setEntrada(v => ({ ...v, estado: e.target.value }))}><option value="">Todos</option><option value="PENDIENTE">Pendientes</option><option value="RECIBIDA">Recibidas</option><option value="ANULADA">Anuladas</option></SelectInput></Field>
          <Field label="Proveedor del listado" htmlFor="compras-proveedor"><SelectInput id="compras-proveedor" disabled={proveedores.isError || proveedores.isLoading} value={entrada.proveedorId} onChange={e => setEntrada(v => ({ ...v, proveedorId: e.target.value }))}><option value="">Todos</option>{proveedores.data?.map(p => <option key={p.proveedorId} value={p.proveedorId}>{p.nombre}</option>)}</SelectInput></Field>
          <div className="tc-grid tc-grid--2"><Field label="Desde" htmlFor="compras-desde"><TextInput id="compras-desde" type="date" value={entrada.desde} onChange={e => setEntrada(v => ({ ...v, desde: e.target.value }))} /></Field><Field label="Hasta" htmlFor="compras-hasta"><TextInput id="compras-hasta" type="date" value={entrada.hasta} onChange={e => setEntrada(v => ({ ...v, hasta: e.target.value }))} /></Field></div></div>
        <div className="tc-row"><Button type="submit" variante="primario">Buscar</Button><Button type="button" onClick={() => { setEntrada(vacios); setFiltros(vacios); setError(""); }}>Limpiar</Button></div>
      </form></Card>
      {proveedores.isError ? <Alert tono="danger" accion={<Button onClick={() => proveedores.refetch()}>Reintentar proveedores</Button>}>{mensajeDeError(proveedores.error)}</Alert> : null}
      {datos.isLoading ? <LoadingState titulo="Cargando compras…" /> : datos.isError ? <Alert tono="danger" accion={<Button onClick={() => datos.refetch()}>Reintentar</Button>}>{mensajeDeError(datos.error)}</Alert> :
        <TablaCatalogo key={JSON.stringify(filtros)} filas={datos.data ?? []} columnas={columnas} clave={c => c.compraId} vacio="No hay compras para estos filtros." />}
    </div>
    {nuevo ? <Dialog abierto titulo="Registrar compra" ancho={900} onCerrar={() => { if (!ocupado) setNuevo(false); }}><CompraForm onOcupado={setOcupado} onCancelar={() => setNuevo(false)} onGuardado={c => navigate(`/compras/${c.compraId}`)} /></Dialog> : null}
  </>;
}
