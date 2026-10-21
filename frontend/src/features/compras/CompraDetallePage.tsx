import { useRef, useState, type FormEvent } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Link, useParams } from "react-router-dom";
import { PageHeader, Card } from "../../components/ui/Card";
import { Alert } from "../../components/ui/Alert";
import { Button } from "../../components/ui/Button";
import { Dialog } from "../../components/ui/Dialog";
import { Field, TextArea } from "../../components/ui/inputs";
import { LoadingState } from "../../components/ui/StateView";
import { DataTable, type Columna } from "../../components/ui/DataTable";
import { comprasApi, quetzales, type DetalleCompra, type EventoCompra } from "../../services/compras";
import { mensajeDeError } from "../../services/errors";
import { fechaHora, numero } from "../../utils/format";
import { EstadoCompra } from "./ComprasPage";

export function CompraDetallePage() {
  const id = Number(useParams().id), qc = useQueryClient(), bloqueo = useRef(false);
  const [accion, setAccion] = useState<"recepcion" | "anulacion" | null>(null), [motivo, setMotivo] = useState("");
  const [confirmado, setConfirmado] = useState(false), [ocupado, setOcupado] = useState(false), [error, setError] = useState(""), [ok, setOk] = useState("");
  const datos = useQuery({ queryKey: ["compras", "detalle", id], queryFn: ({ signal }) => comprasApi.consultar(id, signal), enabled: Number.isInteger(id) && id > 0 });
  if (!Number.isInteger(id) || id < 1) return <Alert tono="danger">El ID de compra no es válido.</Alert>;
  if (datos.isLoading) return <LoadingState titulo="Cargando expediente de compra…" />;
  if (datos.isError || !datos.data) return <Alert tono="danger" accion={<Button onClick={() => datos.refetch()}>Reintentar</Button>}>{mensajeDeError(datos.error)}</Alert>;
  const { compra: c, detalle, eventos } = datos.data;
  const columnas: Columna<DetalleCompra>[] = [
    { clave: "repuesto", encabezado: "Repuesto", render: d => <><strong>{d.codigo}</strong><div>{d.repuesto}</div></> },
    { clave: "bodega", encabezado: "Bodega", render: d => d.bodega },
    { clave: "cantidad", encabezado: "Cantidad", numerica: true, render: d => numero(d.cantidad) },
    { clave: "costo", encabezado: "Costo unitario", numerica: true, render: d => quetzales(d.costoUnitario) },
    { clave: "importe", encabezado: "Importe", numerica: true, render: d => quetzales(d.importe) },
    { clave: "stock", encabezado: c.estado === "RECIBIDA" ? "Existencia al recibir" : "Existencia actual", numerica: true, render: d => numero(c.estado === "RECIBIDA" ? d.existenciaResultante : d.existencia) },
    { clave: "promedio", encabezado: c.estado === "RECIBIDA" ? "Promedio al recibir" : "Promedio actual", numerica: true, render: d => quetzales(c.estado === "RECIBIDA" ? d.costoPosterior : d.costoPromedio, 6) },
  ];
  const columnasEventos: Columna<EventoCompra>[] = [
    { clave: "tipo", encabezado: "Evento", render: e => e.tipo === "REGISTRO" ? "Registro" : e.tipo === "RECEPCION" ? "Recepción" : "Anulación" },
    { clave: "responsable", encabezado: "Responsable", render: e => e.responsable },
    { clave: "fecha", encabezado: "Fecha", render: e => fechaHora(e.fecha) },
    { clave: "observacion", encabezado: "Observación", render: e => <span style={{ whiteSpace: "pre-wrap", overflowWrap: "anywhere" }}>{e.observacion || "—"}</span> },
  ];
  async function ejecutar(e: FormEvent) {
    e.preventDefault(); if (bloqueo.current || !datos.data || !accion || (accion === "recepcion" && !confirmado)) return;
    bloqueo.current = true; setOcupado(true); setError("");
    try {
      const actual = datos.data.compra;
      if (accion === "recepcion") await comprasApi.recibir(id, actual.revision); else await comprasApi.anular(id, actual.revision, motivo.trim());
      setOk(accion === "recepcion" ? "Compra recibida. Existencias y costos promedio actualizados." : "Compra anulada. El motivo y responsable quedaron registrados.");
      setAccion(null);
      await Promise.all([qc.invalidateQueries({ queryKey: ["compras"] }), qc.invalidateQueries({ queryKey: ["abastecimiento"] }), qc.invalidateQueries({ queryKey: ["orden"] }), qc.invalidateQueries({ queryKey: ["inventario"] })]);
    } catch (e) { setError(mensajeDeError(e)); }
    finally { bloqueo.current = false; setOcupado(false); }
  }
  function abrir(tipo: "recepcion" | "anulacion") { setError(""); setConfirmado(false); setMotivo(""); setAccion(tipo); }
  return <>
    <PageHeader eyebrow="Inventario y compras" titulo={c.numeroCompra} descripcion={`${c.proveedor} · ${c.nit}`} acciones={<><Link className="tc-btn" to="/compras">Volver a compras</Link><Button disabled={ocupado || datos.isFetching} onClick={() => { setAccion(null); setError(""); void datos.refetch(); }}>Actualizar compra</Button></>} />
    <div className="tc-stack">{ok ? <Alert tono="ok">{ok}</Alert> : null}{error && !accion ? <Alert tono="danger">{error}</Alert> : null}
      <Card><dl className="tc-dl"><dt>Estado</dt><dd><EstadoCompra estado={c.estado} /></dd><dt>Total de compra</dt><dd>{quetzales(c.total)}</dd>
        <dt>Registró</dt><dd>{c.registradaPor} · {fechaHora(c.fecha)}</dd>{c.estado === "RECIBIDA" ? <><dt>Recibió</dt><dd>{c.recibidaPor || detalle.find(d => d.recibidaPor)?.recibidaPor || "Registro anterior"} · {fechaHora(c.fechaRecepcion)}</dd></> : null}
        {c.estado === "ANULADA" && c.motivoAnulacion ? <><dt>Anuló</dt><dd>{c.anuladaPor} · {fechaHora(c.fechaAnulacion)}</dd><dt>Motivo</dt><dd style={{ whiteSpace: "pre-wrap", overflowWrap: "anywhere" }}>{c.motivoAnulacion}</dd></> : null}
        <dt>Observaciones de compra</dt><dd style={{ whiteSpace: "pre-wrap", overflowWrap: "anywhere" }}>{c.observaciones || "—"}</dd></dl></Card>
      <DataTable columnas={columnas} filas={detalle} claveFila={d => d.linea} vacio="La compra no tiene líneas." />
      {c.estado === "PENDIENTE" ? <><Alert tono="info">Confirmá la recepción únicamente cuando haya llegado la compra completa. El promedio se calcula con las existencias vigentes al confirmar.</Alert><div className="tc-row" style={{ flexWrap: "wrap" }}><Button variante="primario" onClick={() => abrir("recepcion")}>Recibir compra</Button><Button onClick={() => abrir("anulacion")}>Anular compra</Button></div></> : null}
      {eventos.length ? <Card><h3 className="tc-section-title">Responsables e historial</h3><DataTable columnas={columnasEventos} filas={eventos} claveFila={e => e.tipo} /></Card> : <Alert tono="info">Esta compra es anterior al registro de eventos del módulo. Las entradas conservan su usuario en el kardex.</Alert>}
    </div>
    {accion ? <Dialog abierto titulo={accion === "recepcion" ? "Confirmar recepción completa" : "Anular compra pendiente"} ancho={650} onCerrar={() => { if (!ocupado) setAccion(null); }}>
      <form className="tc-stack" style={{ marginTop: 16 }} onSubmit={e => void ejecutar(e)}>
        {error ? <Alert tono="danger" accion={<Button type="button" disabled={ocupado} onClick={() => { setAccion(null); setError(""); void datos.refetch(); }}>Actualizar compra</Button>}>{error}</Alert> : null}
        <p><strong>{c.numeroCompra}</strong> · {c.proveedor} · {c.lineas} líneas · {quetzales(c.total)}</p>
        {accion === "recepcion" ? <label className="tc-row" style={{ alignItems: "flex-start" }}><input type="checkbox" required disabled={ocupado} checked={confirmado} onChange={e => setConfirmado(e.target.checked)} /><span>Confirmo que recibí todas las unidades detalladas en esta compra.</span></label> :
          <Field label="Motivo de anulación" htmlFor="compra-motivo" requerido><TextArea id="compra-motivo" data-autofocus required maxLength={1000} rows={4} disabled={ocupado} value={motivo} onChange={e => setMotivo(e.target.value)} /></Field>}
        <div className="tc-row" style={{ flexWrap: "wrap" }}><Button type="button" disabled={ocupado} onClick={() => setAccion(null)}>Volver</Button><Button type="submit" variante="primario" disabled={ocupado || (accion === "recepcion" ? !confirmado : !motivo.trim())}>{ocupado ? "Confirmando…" : accion === "recepcion" ? "Confirmar recepción" : "Confirmar anulación"}</Button></div>
      </form>
    </Dialog> : null}
  </>;
}
