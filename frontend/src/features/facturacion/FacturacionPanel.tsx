import { useEffect, useRef, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Download, Receipt, CreditCard, PackageCheck } from "lucide-react";
import { puedeAcceder, useSession } from "../../app/session";
import { Button } from "../../components/ui/Button";
import { Alert } from "../../components/ui/Alert";
import { Badge } from "../../components/ui/Badge";
import { Dialog } from "../../components/ui/Dialog";
import { DataTable, type Columna } from "../../components/ui/DataTable";
import { Field, SelectInput, TextArea, TextInput } from "../../components/ui/inputs";
import { LoadingState } from "../../components/ui/StateView";
import { type Orden } from "../../services/ordenes";
import { facturacionApi, estadoCobro, type Abono, type DetalleFactura, type PagoFactura, type Factura } from "../../services/facturacion";
import { esApiError, mensajeDeError } from "../../services/errors";
import { fechaHora, moneda } from "../../utils/format";

const columnasDetalle: Columna<DetalleFactura>[] = [
  { clave: "concepto", encabezado: "Concepto", render: d => <span style={{ overflowWrap: "anywhere", whiteSpace: "pre-wrap" }}>{d.concepto}</span> },
  { clave: "cantidad", encabezado: "Cantidad", numerica: true, render: d => d.cantidad },
  { clave: "precio", encabezado: "Precio unitario", numerica: true, render: d => moneda(d.precioUnitario) },
  { clave: "importe", encabezado: "Importe", numerica: true, render: d => moneda(d.importe) },
];
const columnasPago: Columna<PagoFactura>[] = [
  { clave: "fecha", encabezado: "Fecha", render: p => fechaHora(p.fecha) },
  { clave: "metodo", encabezado: "Medio de pago", render: p => p.metodoPago },
  { clave: "monto", encabezado: "Monto", numerica: true, render: p => moneda(p.monto) },
  { clave: "referencia", encabezado: "Referencia", render: p => p.referencia || "—" },
  { clave: "usuario", encabezado: "Registró", render: p => p.registradoPor },
];
function leerIntento(clave: string): Abono | null {
  try {
    const v = JSON.parse(sessionStorage.getItem(clave) || "null") as Abono | null;
    return v && typeof v.solicitudId === "string" && typeof v.monto === "string" && typeof v.metodoPagoId === "number" && typeof v.saldoEsperado === "number" ? v : null;
  } catch { return null; }
}

export function FacturacionPanel({ orden, seccion }: { orden: Orden; seccion: "Factura y pagos" | "Entrega" }) {
  const sesion = useSession();
  const caja = puedeAcceder(sesion, ["CAJA"]), recepcion = puedeAcceder(sesion, ["RECEPCION"]);
  const id = orden.ordenId, qc = useQueryClient();
  const claveIntento = `techcare:pago:${sesion.usuario?.usuarioId}:${id}`;
  const [pendiente, setPendiente] = useState<Abono | null>(() => leerIntento(claveIntento));
  const [accion, setAccion] = useState<"emitir" | "pagar" | "entregar" | null>(null);
  const [error, setError] = useState(""), [mensaje, setMensaje] = useState(""), [errorPdf, setErrorPdf] = useState("");
  const [guardando, setGuardando] = useState(false), [descargando, setDescargando] = useState(false);
  const bloqueo = useRef(false);
  const [confirmado, setConfirmado] = useState(false), [tasa, setTasa] = useState("12.00");
  const [monto, setMonto] = useState(""), [metodo, setMetodo] = useState(""), [referencia, setReferencia] = useState("");
  const [saldoRevisado, setSaldoRevisado] = useState(0);
  const [nombre, setNombre] = useState(""), [documento, setDocumento] = useState(""), [observacion, setObservacion] = useState("");
  const factura = useQuery({ queryKey: ["orden", id, "factura"], queryFn: ({ signal }) => facturacionApi.consultar(id, signal) });
  const f = factura.data;
  const detalles = useQuery({ queryKey: ["orden", id, "factura", "detalles"], queryFn: ({ signal }) => facturacionApi.detalles(id, signal), enabled: !!f });
  const pagos = useQuery({ queryKey: ["orden", id, "factura", "pagos"], queryFn: ({ signal }) => facturacionApi.pagos(id, signal), enabled: !!f });
  const entrega = useQuery({ queryKey: ["orden", id, "entrega"], queryFn: ({ signal }) => facturacionApi.entrega(id, signal) });
  const tasaValida = /^(?:100(?:\.0{1,2})?|\d{1,2}(?:\.\d{1,2})?)$/.test(tasa);
  const tasaDecimal = tasaValida ? (Number(tasa) / 100).toFixed(4) : "";
  const previa = useQuery({ queryKey: ["orden", id, "previa", tasaDecimal], queryFn: ({ signal }) => facturacionApi.previa(id, tasaDecimal, signal), enabled: accion === "emitir" && tasaValida, staleTime: 0 });
  useEffect(() => { setConfirmado(false); }, [previa.data?.revision]);
  const metodos = useQuery({ queryKey: ["caja", "metodos"], queryFn: ({ signal }) => facturacionApi.metodos(signal), enabled: accion === "pagar" });
  async function actualizar() {
    await Promise.all([qc.invalidateQueries({ queryKey: ["orden", id] }), qc.invalidateQueries({ queryKey: ["ordenes"] }),
      qc.invalidateQueries({ queryKey: ["caja"] }), qc.invalidateQueries({ queryKey: ["equipos"] })]);
  }
  async function descargar() {
    if (descargando) return;
    setDescargando(true); setErrorPdf("");
    try {
      const blob = await facturacionApi.pdf(id), url = URL.createObjectURL(blob);
      const a = window.document.createElement("a"); a.href = url;
      a.download = `Factura-${(f?.numeroFactura || orden.numeroOrden).replace(/[^A-Za-z0-9_-]/g, "_")}.pdf`;
      window.document.body.append(a); a.click(); a.remove(); window.setTimeout(() => URL.revokeObjectURL(url), 30000);
    } catch (e) { setErrorPdf(`No se pudo descargar la factura. ${mensajeDeError(e)}`); }
    finally { setDescargando(false); }
  }
  function abrir(tipo: "emitir" | "pagar" | "entregar") {
    setError(""); setConfirmado(false); setAccion(tipo);
    if (tipo === "emitir") setTasa("12.00");
    if (tipo === "pagar") {
      const intento = leerIntento(claveIntento); setPendiente(intento);
      setSaldoRevisado(intento?.saldoEsperado ?? f?.saldo ?? 0);
      setMonto(intento?.monto || ""); setMetodo(intento ? String(intento.metodoPagoId) : ""); setReferencia(intento?.referencia || "");
    }
    if (tipo === "entregar") { setNombre(orden.cliente); setDocumento(""); setObservacion(""); }
  }
  function limpiarIntento() { sessionStorage.removeItem(claveIntento); setPendiente(null); }
  async function guardar() {
    if (bloqueo.current || !confirmado) return;
    if (accion === "emitir" && (!previa.data || previa.isFetching || !tasaValida)) return;
    if (accion === "pagar" && !pendiente && (!/^\d{1,10}(?:\.\d{1,2})?$/.test(monto) || Number(monto) <= 0 || Number(monto) > (f?.saldo ?? 0) || !metodo)) {
      setError("Ingresá un monto positivo, con hasta dos decimales y sin exceder el saldo, y elegí un medio de pago."); return;
    }
    if (accion === "entregar" && !nombre.trim()) { setError("Ingresá el nombre de quien recibe el equipo."); return; }
    bloqueo.current = true; setGuardando(true); setError("");
    const actual = accion;
    try {
      if (actual === "emitir" && previa.data) {
        const emitida = await facturacionApi.emitir(id, previa.data.tasaImpuesto, previa.data.revision);
        qc.setQueryData(["orden", id, "factura"], emitida); setMensaje(`Factura ${emitida.numeroFactura} emitida. Ya podés descargar el PDF y registrar pagos.`);
      }
      if (actual === "pagar" && f) {
        const intento: Abono = pendiente ?? { solicitudId: crypto.randomUUID(), metodoPagoId: Number(metodo), monto, saldoEsperado: saldoRevisado, referencia: referencia.trim() || null };
        // Se conserva antes de enviar: un fallo de red o una recarga reusan la misma solicitud.
        sessionStorage.setItem(claveIntento, JSON.stringify(intento)); setPendiente(intento);
        const pagada = await facturacionApi.abonar(id, intento);
        limpiarIntento(); qc.setQueryData(["orden", id, "factura"], pagada);
        setMensaje(pagada.saldo === 0 ? "Pago confirmado. Saldo cero: recepción ya puede entregar el equipo." : "Abono confirmado. El saldo de la factura fue actualizado.");
      }
      if (actual === "entregar") {
        const registrada = await facturacionApi.entregar(id, nombre.trim(), documento.trim(), observacion.trim());
        qc.setQueryData(["orden", id, "entrega"], registrada); setMensaje("Entrega registrada. Se descargará la factura PDF; también podés volver a descargarla desde este expediente.");
      }
      setAccion(null); await actualizar();
      if (actual === "entregar") await descargar();
    } catch (e) {
      setError(mensajeDeError(e));
      if (actual === "pagar" && esApiError(e) && e.status > 0 && e.status < 500 && e.status !== 408) limpiarIntento();
      if (esApiError(e) && e.status === 409) {
        setConfirmado(false); await actualizar();
        setSaldoRevisado(qc.getQueryData<Factura>(["orden", id, "factura"])?.saldo ?? 0);
      }
    } finally { bloqueo.current = false; setGuardando(false); }
  }
  const lista = orden.estadoCodigo === "LISTO" && orden.estadoReparacion === "TERMINADA";
  const puedeEntregar = recepcion && lista && f?.estado === "EMITIDA" && f.saldo === 0 && entrega.isSuccess && !entrega.data;
  const descargarBoton = f ? <Button disabled={descargando || guardando} icono={<Download size={16} />} onClick={() => void descargar()}>{descargando ? "Preparando PDF…" : "Descargar factura PDF"}</Button> : null;
  if (factura.isLoading || entrega.isLoading) return <LoadingState titulo="Consultando factura y entrega…" />;
  if (factura.isError || entrega.isError) return <Alert tono="danger" accion={<Button onClick={() => void actualizar()}>Reintentar</Button>}>{mensajeDeError(factura.error || entrega.error)}</Alert>;
  return <div className="tc-stack">
    {mensaje ? <Alert tono="ok">{mensaje}</Alert> : null}
    {errorPdf ? <Alert tono="danger" accion={<Button onClick={() => void descargar()}>Reintentar PDF</Button>}>{errorPdf}</Alert> : null}
    {seccion === "Factura y pagos" ? <>
      {!f ? <Alert tono="info" titulo="La orden todavía no tiene factura">{lista ? "Caja puede revisar los conceptos y emitir la factura del servicio." : "Completá la reparación para dejar la orden lista antes de facturar."}</Alert> : <>
        <div className="tc-row" style={{ flexWrap: "wrap", justifyContent: "space-between" }}><strong>{f.numeroFactura}</strong>
          <Badge tono={f.estadoPago === "PAGADA" ? "ok" : f.estado === "ANULADA" ? "danger" : "warn"}>{estadoCobro(f.estadoPago)}</Badge>{descargarBoton}</div>
        <dl className="tc-dl"><dt>Emisión</dt><dd>{fechaHora(f.fecha)} · {f.emitidaPor}</dd><dt>Cliente fiscal</dt><dd>{f.nombreFacturacion} · NIT {f.nitFacturacion}</dd>
          <dt>Dirección fiscal</dt><dd>{f.direccionFacturacion || "—"}</dd><dt>Recibió la orden</dt><dd>{f.recepcionista}</dd><dt>Técnico responsable</dt><dd>{f.tecnico}</dd></dl>
        {detalles.isLoading ? <LoadingState titulo="Cargando conceptos…" /> : detalles.isError ? <Alert tono="danger" accion={<Button onClick={() => detalles.refetch()}>Reintentar</Button>}>{mensajeDeError(detalles.error)}</Alert> :
          <DataTable columnas={columnasDetalle} filas={detalles.data ?? []} claveFila={d => d.linea} />}
        <Totales subtotal={f.subtotal} impuesto={f.impuesto} total={f.total} pagado={f.pagado} saldo={f.saldo} />
        <h3 className="tc-section-title">Pagos registrados</h3>
        {pagos.isLoading ? <LoadingState titulo="Cargando pagos…" /> : pagos.isError ? <Alert tono="danger" accion={<Button onClick={() => pagos.refetch()}>Reintentar</Button>}>{mensajeDeError(pagos.error)}</Alert> :
          <DataTable columnas={columnasPago} filas={pagos.data ?? []} claveFila={p => p.pagoId} vacio="Todavía no hay abonos registrados." />}
      </>}
      <div className="tc-row" style={{ flexWrap: "wrap" }}>
        {caja && !f && lista ? <Button variante="primario" icono={<Receipt size={16} />} onClick={() => abrir("emitir")}>Revisar y emitir factura</Button> : null}
        {caja && f?.estado === "EMITIDA" && (f.saldo > 0 || pendiente) ? <Button variante="primario" icono={<CreditCard size={16} />} onClick={() => abrir("pagar")}>{pendiente ? "Verificar pago pendiente" : "Registrar pago / abono"}</Button> : null}
      </div>
    </> : <>
      {entrega.data ? <><Alert tono="ok" titulo="Equipo entregado">La entrega quedó registrada en el expediente.</Alert><dl className="tc-dl">
        <dt>Fecha</dt><dd>{fechaHora(entrega.data.fecha)}</dd><dt>Recibió el equipo</dt><dd>{entrega.data.nombreRecibe}</dd>
        <dt>Documento</dt><dd>{entrega.data.documentoRecibe || "—"}</dd><dt>Entregó</dt><dd>{entrega.data.entregadaPor}</dd>
        <dt>Observaciones</dt><dd style={{ whiteSpace: "pre-wrap", overflowWrap: "anywhere" }}>{entrega.data.observaciones || "—"}</dd></dl></> :
        <Alert tono={puedeEntregar ? "ok" : "info"} titulo={f?.estado === "EMITIDA" && f.saldo === 0 && lista ? "Saldo cancelado" : "Entrega pendiente"}>
          {!lista ? "La reparación debe estar terminada y la orden en estado Listo." : !f ? "Caja debe emitir la factura antes de entregar." : f.estado === "ANULADA" ? "La factura está anulada; esta orden no permite entrega." : f.saldo > 0 ? `Falta cancelar ${moneda(f.saldo)} para entregar el equipo.` : "Recepción puede registrar a la persona que recibe el equipo y confirmar la entrega."}
        </Alert>}
      <div className="tc-row" style={{ flexWrap: "wrap" }}>{puedeEntregar ? <Button variante="primario" icono={<PackageCheck size={16} />} onClick={() => abrir("entregar")}>Registrar entrega</Button> : null}{descargarBoton}</div>
      {f ? <p className="tc-field__hint">La factura PDF incluye conceptos, cantidades, precios, impuesto, pagos y responsables del servicio.</p> : null}
    </>}
    {accion ? <Dialog abierto titulo={accion === "emitir" ? "Revisar factura antes de emitir" : accion === "pagar" ? "Registrar pago / abono" : "Confirmar entrega del equipo"}
      onCerrar={() => { if (!bloqueo.current) setAccion(null); }}>
      <form className="tc-stack" style={{ marginTop: 16 }} onSubmit={e => { e.preventDefault(); void guardar(); }}>
        {error ? <Alert tono="danger">{error}</Alert> : null}
        {accion === "emitir" ? <>
          <Field label="Impuesto (%)" htmlFor="factura-tasa" requerido hint="Porcentaje aplicado al subtotal. Revisá los datos fiscales antes de emitir.">
            <TextInput id="factura-tasa" type="number" min="0" max="100" step="0.01" required disabled={guardando} value={tasa} onChange={e => { setTasa(e.target.value); setConfirmado(false); }} /></Field>
          {!tasaValida ? <Alert tono="warn">Ingresá un porcentaje entre 0 y 100, con hasta dos decimales.</Alert> : previa.isLoading || previa.isFetching ? <LoadingState titulo="Calculando factura…" /> : previa.isError ?
            <Alert tono="danger" accion={<Button type="button" onClick={() => previa.refetch()}>Actualizar vista previa</Button>}>{mensajeDeError(previa.error)}</Alert> : previa.data ? <>
              <p>{previa.data.nombreFacturacion} · NIT {previa.data.nitFacturacion}<br />{previa.data.direccionFacturacion || "Sin dirección fiscal"}</p>
              <DataTable columnas={columnasDetalle} filas={previa.data.detalles} claveFila={d => d.linea} />
              <Totales subtotal={previa.data.subtotal} impuesto={previa.data.impuesto} total={previa.data.total} />
            </> : null}
        </> : accion === "pagar" ? <>
          <Alert tono="info">Saldo revisado: {moneda(saldoRevisado)}.{pendiente ? " Hay un intento sin confirmar. Reintentá con los mismos datos para verificarlo sin duplicar el abono." : " Registrá el importe recibido; se permiten pagos parciales."}</Alert>
          <Field label="Medio de pago" htmlFor="pago-metodo" requerido><SelectInput id="pago-metodo" required disabled={guardando || !!pendiente || metodos.isLoading} value={metodo} onChange={e => setMetodo(e.target.value)}>
            <option value="">Elegir medio de pago</option>{metodos.data?.map(m => <option key={m.metodoPagoId} value={m.metodoPagoId}>{m.nombre}</option>)}</SelectInput></Field>
          {metodos.isError ? <Alert tono="danger" accion={<Button type="button" onClick={() => metodos.refetch()}>Reintentar</Button>}>{mensajeDeError(metodos.error)}</Alert> : null}
          <Field label="Monto recibido (Q)" htmlFor="pago-monto" requerido><TextInput id="pago-monto" type="number" min="0.01" max={pendiente ? undefined : f?.saldo} step="0.01" required disabled={guardando || !!pendiente} value={monto} onChange={e => setMonto(e.target.value)} /></Field>
          <Field label="Referencia" htmlFor="pago-referencia"><TextInput id="pago-referencia" maxLength={100} disabled={guardando || !!pendiente} value={referencia} onChange={e => setReferencia(e.target.value)} /></Field>
        </> : <>
          <Alert tono="info">Al confirmar, la orden quedará Entregada y se descargará la factura PDF.</Alert>
          <Field label="Nombre de quien recibe" htmlFor="entrega-nombre" requerido><TextInput id="entrega-nombre" required maxLength={150} disabled={guardando} value={nombre} onChange={e => setNombre(e.target.value)} /></Field>
          <Field label="Documento de quien recibe" htmlFor="entrega-documento" hint="Letras, números, espacios o guiones."><TextInput id="entrega-documento" maxLength={30} pattern={"[0-9A-Za-z \\-]*"} disabled={guardando} value={documento} onChange={e => setDocumento(e.target.value)} /></Field>
          <Field label="Observaciones de entrega" htmlFor="entrega-observaciones"><TextArea id="entrega-observaciones" rows={3} maxLength={1000} disabled={guardando} value={observacion} onChange={e => setObservacion(e.target.value)} /></Field>
        </>}
        <label className="tc-row" style={{ alignItems: "flex-start" }}><input type="checkbox" checked={confirmado} disabled={guardando} onChange={e => setConfirmado(e.target.checked)} />
          <span>{accion === "emitir" ? "Revisé los datos fiscales, conceptos e importes de la factura." : accion === "pagar" ? "Confirmo que recibí este pago y revisé los datos." : "Confirmo que entrego el equipo a la persona indicada."}</span></label>
        <div className="tc-row tc-row--end" style={{ flexWrap: "wrap" }}><Button type="button" disabled={guardando} onClick={() => setAccion(null)}>Volver</Button>
          <Button type="submit" variante="primario" disabled={guardando || !confirmado || (accion === "emitir" && (!previa.data || previa.isFetching || previa.isError || !tasaValida)) || (accion === "pagar" && !pendiente && (metodos.isLoading || metodos.isError))}>
            {guardando ? "Guardando…" : accion === "emitir" ? "Emitir factura" : accion === "pagar" ? pendiente ? "Verificar el mismo pago" : "Confirmar pago" : "Confirmar entrega"}</Button></div>
      </form>
    </Dialog> : null}
  </div>;
}
function Totales({ subtotal, impuesto, total, pagado, saldo }: { subtotal: number; impuesto: number; total: number; pagado?: number; saldo?: number }) {
  return <dl className="tc-dl"><dt>Subtotal</dt><dd>{moneda(subtotal)}</dd><dt>Impuesto</dt><dd>{moneda(impuesto)}</dd><dt>Total</dt><dd><strong>{moneda(total)}</strong></dd>
    {pagado !== undefined ? <><dt>Pagado</dt><dd>{moneda(pagado)}</dd><dt>Saldo</dt><dd><strong>{moneda(saldo ?? 0)}</strong></dd></> : null}</dl>;
}
