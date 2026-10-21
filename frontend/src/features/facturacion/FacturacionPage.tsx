import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { RefreshCw } from "lucide-react";
import { PageHeader, Card } from "../../components/ui/Card";
import { Button } from "../../components/ui/Button";
import { Alert } from "../../components/ui/Alert";
import { Badge } from "../../components/ui/Badge";
import { DataTable, Paginacion, type Columna } from "../../components/ui/DataTable";
import { Field, SelectInput, TextInput } from "../../components/ui/inputs";
import { LoadingState } from "../../components/ui/StateView";
import { facturacionApi, estadoCobro, type FilaCaja } from "../../services/facturacion";
import { mensajeDeError } from "../../services/errors";
import { moneda } from "../../utils/format";

const columnas: Columna<FilaCaja>[] = [
  { clave: "orden", encabezado: "Orden / equipo", render: f => <><strong>{f.numeroOrden}</strong><br /><span className="tc-field__hint">{f.numeroSerie}</span></> },
  { clave: "cliente", encabezado: "Cliente", render: f => f.cliente },
  { clave: "factura", encabezado: "Factura", render: f => f.numeroFactura || "Sin emitir" },
  { clave: "estado", encabezado: "Cobro", render: f => <Badge tono={f.estadoPago === "PAGADA" ? "ok" : f.estadoPago === "ANULADA" ? "danger" : "warn"}>{estadoCobro(f.estadoPago)}</Badge> },
  { clave: "total", encabezado: "Total", numerica: true, render: f => f.total === null ? "—" : moneda(f.total) },
  { clave: "saldo", encabezado: "Saldo", numerica: true, render: f => f.saldo === null ? "—" : moneda(f.saldo) },
  { clave: "accion", encabezado: "Acción", render: f => <Link className="tc-btn tc-btn--sm" to={`/ordenes/${f.ordenId}?seccion=factura`}>{!f.facturaId ? "Facturar" : (f.saldo ?? 0) > 0 && f.estadoPago !== "ANULADA" ? "Registrar pago" : "Ver factura / PDF"}</Link> },
];
export function FacturacionPage() {
  const [buscar, setBuscar] = useState(""), [estado, setEstado] = useState(""), [pagina, setPagina] = useState(1);
  const [filtros, setFiltros] = useState({ buscar: "", estado: "" });
  const listado = useQuery({ queryKey: ["caja", "listado", filtros], queryFn: ({ signal }) => facturacionApi.listar(filtros.buscar, filtros.estado, signal) });
  const filas = listado.data ?? [], paginas = Math.max(1, Math.ceil(filas.length / 10)), actual = Math.min(pagina, paginas);
  return <>
    <PageHeader eyebrow="Caja" titulo="Facturas y pagos" descripcion="Facturá servicios terminados, registrá abonos y consultá saldos."
      acciones={<Button disabled={listado.isFetching} icono={<RefreshCw size={16} />} onClick={() => listado.refetch()}>Actualizar</Button>} />
    <div className="tc-stack"><Card><form className="tc-row" style={{ flexWrap: "wrap", alignItems: "end" }} onSubmit={e => { e.preventDefault(); setFiltros({ buscar: buscar.trim(), estado }); setPagina(1); }}>
      <Field label="Buscar" htmlFor="caja-buscar"><TextInput id="caja-buscar" maxLength={150} placeholder="Orden, cliente, serie o factura" value={buscar} onChange={e => setBuscar(e.target.value)} /></Field>
      <Field label="Estado de cobro" htmlFor="caja-estado"><SelectInput id="caja-estado" value={estado} onChange={e => setEstado(e.target.value)}><option value="">Todos</option>
        {["SIN_FACTURA", "PENDIENTE", "PARCIAL", "PAGADA", "ANULADA"].map(v => <option key={v} value={v}>{estadoCobro(v)}</option>)}</SelectInput></Field>
      <Button type="submit" variante="primario">Buscar</Button>
    </form></Card>
      {listado.isLoading ? <LoadingState titulo="Cargando caja…" /> : listado.isError ? <Alert tono="danger" accion={<Button onClick={() => listado.refetch()}>Reintentar</Button>}>{mensajeDeError(listado.error)}</Alert> : <>
        <DataTable columnas={columnas} filas={filas.slice((actual - 1) * 10, actual * 10)} claveFila={f => f.ordenId} vacio="No hay órdenes listas ni facturas para estos filtros." />
        <Paginacion pagina={actual} totalPaginas={paginas} total={filas.length} onCambiar={setPagina} />
      </>}
    </div>
  </>;
}
