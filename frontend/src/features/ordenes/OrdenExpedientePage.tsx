import { useEffect, useRef, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Link, useLocation, useParams } from "react-router-dom";
import { ArrowLeft, RefreshCw } from "lucide-react";
import { puedeAcceder, useSession } from "../../app/session";
import { PageHeader, Card } from "../../components/ui/Card";
import { Button } from "../../components/ui/Button";
import { EstadoOrdenBadge } from "../../components/ui/Badge";
import { Alert } from "../../components/ui/Alert";
import { Dialog } from "../../components/ui/Dialog";
import { Field, SelectInput, TextArea } from "../../components/ui/inputs";
import { EmptyState, LoadingState, PendingState } from "../../components/ui/StateView";
import { DataTable, type Columna } from "../../components/ui/DataTable";
import { ordenesApi, type EventoOrden } from "../../services/ordenes";
import { esApiError, mensajeDeError } from "../../services/errors";
import { fechaHora, moneda } from "../../utils/format";
import { nombreEstado } from "../../services/catalogos";
import "./ordenes.css";

const SECCIONES = ["Recepción", "Diagnóstico", "Reparación", "Repuestos", "Factura y pagos", "Entrega", "Historial"] as const;
type Seccion = typeof SECCIONES[number];
export function OrdenExpedientePage() {
  const { id } = useParams();
  const ordenId = Number(id);
  const valido = Number.isInteger(ordenId) && ordenId > 0 && ordenId <= 2147483647;
  const sesion = useSession();
  const gestion = puedeAcceder(sesion, ["ADMIN", "RECEPCION"]);
  const location = useLocation();
  const qc = useQueryClient();
  const [seccion, setSeccion] = useState<Seccion>("Recepción");
  const [accion, setAccion] = useState<"asignar" | "cancelar" | null>(null);
  const [tecnicoId, setTecnicoId] = useState("");
  const [observacion, setObservacion] = useState("");
  const [error, setError] = useState("");
  const [mensaje, setMensaje] = useState("");
  const [guardando, setGuardando] = useState(false);
  const enCurso = useRef(false);
  const montado = useRef(true);
  useEffect(() => { montado.current = true; return () => { montado.current = false; }; }, []);
  const orden = useQuery({ queryKey: ["orden", ordenId], queryFn: ({ signal }) => ordenesApi.consultar(ordenId, signal), enabled: valido });
  const historial = useQuery({ queryKey: ["orden", ordenId, "historial"], queryFn: ({ signal }) => ordenesApi.historial(ordenId, signal), enabled: valido && seccion === "Historial" && !!orden.data });
  const tecnicos = useQuery({ queryKey: ["ordenes", "tecnicos"], queryFn: ({ signal }) => ordenesApi.tecnicos(signal), enabled: gestion && accion === "asignar" });
  const o = orden.data;
  async function guardar() {
    if (enCurso.current || !o || !accion) return;
    if (accion === "asignar" && (!tecnicoId || Number(tecnicoId) === o.usuarioTecnicoId)) { setError("Elegí un técnico diferente al actual."); return; }
    if (accion === "cancelar" && !observacion.trim()) { setError("Ingresá el motivo de cancelación."); return; }
    enCurso.current = true; setGuardando(true); setError("");
    try {
      const actualizada = accion === "asignar"
        ? await ordenesApi.asignar(ordenId, Number(tecnicoId), o.usuarioTecnicoId, observacion.trim())
        : await ordenesApi.cancelar(ordenId, observacion.trim());
      if (!montado.current) return;
      qc.setQueryData(["orden", ordenId], actualizada);
      setMensaje(accion === "asignar" ? "Se actualizó el técnico responsable." : "La orden fue cancelada y conservó su historial.");
      setAccion(null);
      await Promise.all([qc.invalidateQueries({ queryKey: ["ordenes"] }), qc.invalidateQueries({ queryKey: ["orden", ordenId] }), qc.invalidateQueries({ queryKey: ["equipos"] })]);
    } catch (e) {
      setError(mensajeDeError(e));
      if (esApiError(e) && e.status === 409) void orden.refetch();
    } finally { enCurso.current = false; setGuardando(false); }
  }
  const columnas: Columna<EventoOrden>[] = [
    { clave: "fecha", encabezado: "Fecha", render: e => fechaHora(e.fecha) },
    { clave: "evento", encabezado: "Evento", render: e => e.tipo === "ASIGNACION" ? `Asignación a ${e.tecnico}` : `${e.estadoAnterior ? nombreEstado(e.estadoAnterior) + " → " : "Ingreso → "}${nombreEstado(e.estadoNuevo || "")}` },
    { clave: "usuario", encabezado: "Registrado por", render: e => e.nombreUsuario },
    { clave: "observacion", encabezado: "Observación", render: e => e.observacion || "—" },
  ];
  return <>
    <PageHeader eyebrow="Servicio / Órdenes / Expediente" titulo={o ? o.numeroOrden : "Expediente de la orden"}
      descripcion="Ingreso, responsable y seguimiento del servicio."
      acciones={<><Link to="/ordenes"><Button variante="fantasma" icono={<ArrowLeft size={16} />}>Volver</Button></Link>
        {valido ? <Button disabled={orden.isFetching || guardando} icono={<RefreshCw size={16} />} onClick={() => { void orden.refetch(); if (seccion === "Historial") void historial.refetch(); }}>Actualizar</Button> : null}</>} />
    {!valido ? <Alert tono="danger">El número de expediente no es válido.</Alert> : orden.isLoading ? <LoadingState titulo="Cargando expediente…" /> : orden.isError ?
      <Alert tono="danger" titulo="No se pudo consultar la orden" accion={<Button onClick={() => orden.refetch()}>Reintentar</Button>}>{mensajeDeError(orden.error)}</Alert> : o ?
      <div className="tc-stack tc-ordenes">
        {(location.state as { nuevaOrden?: boolean } | null)?.nuevaOrden && !mensaje ? <Alert tono="ok">Ingreso registrado. Número de orden: {o.numeroOrden}.</Alert> : null}
        {mensaje ? <Alert tono="ok">{mensaje}</Alert> : null}
        <Card><h2 className="tc-section-title">Resumen del servicio</h2><dl className="tc-dl">
          <dt>Estado</dt><dd><EstadoOrdenBadge codigo={o.estadoCodigo} nombre={o.estado} /></dd>
          <dt>Prioridad</dt><dd>{o.prioridad}</dd><dt>Cliente</dt><dd>{o.cliente} · NIT {o.nit}</dd>
          <dt>Equipo</dt><dd>{o.numeroSerie} · {o.marca} {o.modelo}</dd><dt>Técnico responsable</dt><dd>{o.tecnico || "Sin asignar"}</dd>
          <dt>Ingreso</dt><dd>{fechaHora(o.fechaIngreso)}</dd><dt>Fecha estimada</dt><dd>{fechaHora(o.fechaEstimada)}</dd>
        </dl>
          {gestion ? <div className="tc-row" style={{ flexWrap: "wrap", marginTop: 16 }}>
            {!o.diagnosticoId && ["RECIBIDO", "DIAGNOSTICO"].includes(o.estadoCodigo) ?
              <Button disabled={guardando} onClick={() => { setAccion("asignar"); setTecnicoId(""); setObservacion(""); setError(""); }}>{o.usuarioTecnicoId ? "Reasignar técnico" : "Asignar técnico"}</Button> : null}
            {["RECIBIDO", "DIAGNOSTICO", "ESPERANDO_AUTORIZACION"].includes(o.estadoCodigo) ?
              <Button disabled={guardando} onClick={() => { setAccion("cancelar"); setObservacion(""); setError(""); }}>Cancelar orden</Button> : null}
          </div> : null}
        </Card>
        <div className="tc-row" role="tablist" aria-label="Secciones del expediente" style={{ flexWrap: "wrap" }}>
          {SECCIONES.map(s => <button key={s} type="button" role="tab" aria-selected={s === seccion} className="tc-btn tc-btn--sm"
            style={{ background: s === seccion ? "var(--tc-interactive)" : "transparent" }} onClick={() => setSeccion(s)}>{s}</button>)}
        </div>
        <Card><div role="tabpanel" aria-label={seccion}>
          <h2 className="tc-section-title">{seccion}</h2>
          {seccion === "Recepción" ? <dl className="tc-dl"><dt>Registrado por</dt><dd>{o.recepcionista}</dd>
            <dt>Problema reportado</dt><dd style={{ whiteSpace: "pre-wrap", overflowWrap: "anywhere" }}>{o.problemaReportado}</dd>
            <dt>Descripción del equipo</dt><dd style={{ overflowWrap: "anywhere" }}>{o.equipoDescripcion}</dd>
            <dt>Observaciones</dt><dd style={{ whiteSpace: "pre-wrap", overflowWrap: "anywhere" }}>{o.observaciones || "Sin observaciones"}</dd></dl> : null}
          {seccion === "Diagnóstico" ? o.diagnosticoId ? <dl className="tc-dl"><dt>Fecha</dt><dd>{fechaHora(o.fechaDiagnostico)}</dd>
            <dt>Descripción</dt><dd style={{ whiteSpace: "pre-wrap", overflowWrap: "anywhere" }}>{o.descripcionDiagnostico}</dd><dt>Mano de obra estimada</dt><dd>{moneda(o.costoEstimado)}</dd></dl> :
            <EmptyState titulo="Sin diagnóstico registrado" descripcion="La orden conserva la falla reportada durante la recepción." /> : null}
          {seccion === "Reparación" ? o.reparacionId ? <dl className="tc-dl"><dt>Estado</dt><dd>{o.estadoReparacion}</dd>
            <dt>Inicio</dt><dd>{fechaHora(o.fechaInicioReparacion)}</dd><dt>Finalización</dt><dd>{fechaHora(o.fechaFinReparacion)}</dd>
            <dt>Trabajo realizado</dt><dd style={{ whiteSpace: "pre-wrap", overflowWrap: "anywhere" }}>{o.descripcionTrabajo}</dd><dt>Mano de obra</dt><dd>{moneda(o.costoManoObra)}</dd></dl> :
            <EmptyState titulo="Sin reparación registrada" descripcion="La reparación requiere un diagnóstico y la autorización del cliente." /> : null}
          {seccion === "Historial" ? historial.isLoading ? <LoadingState titulo="Cargando historial…" /> : historial.isError ?
            <Alert tono="danger" accion={<Button onClick={() => historial.refetch()}>Reintentar</Button>}>{mensajeDeError(historial.error)}</Alert> :
            <DataTable columnas={columnas} filas={historial.data ?? []} claveFila={e => e.eventoId} vacio="Sin eventos registrados." /> : null}
          {["Repuestos", "Factura y pagos", "Entrega"].includes(seccion) ? <PendingState titulo="Sección pendiente" descripcion="Esta parte del expediente todavía no está disponible." /> : null}
        </div></Card>
      </div> : null}
    {accion && o ? <Dialog abierto titulo={accion === "asignar" ? "Asignar técnico" : "Cancelar orden"}
      descripcion={accion === "asignar" ? `Responsable actual: ${o.tecnico || "Sin asignar"}.` : "La cancelación conserva el ingreso y su historial."}
      onCerrar={() => { if (!enCurso.current) setAccion(null); }}>
      <form className="tc-stack" style={{ marginTop: 16 }} onSubmit={e => { e.preventDefault(); void guardar(); }}>
        {error ? <Alert tono="danger">{error}</Alert> : null}
        {accion === "asignar" ? tecnicos.isLoading ? <LoadingState titulo="Cargando técnicos…" /> : tecnicos.isError ?
          <Alert tono="danger" accion={<Button type="button" onClick={() => tecnicos.refetch()}>Reintentar</Button>}>{mensajeDeError(tecnicos.error)}</Alert> :
          <Field label="Técnico" htmlFor="asignar-tecnico" requerido><SelectInput id="asignar-tecnico" required disabled={guardando} value={tecnicoId} onChange={e => setTecnicoId(e.target.value)}>
            <option value="">Elegir técnico activo</option>{tecnicos.data?.filter(t => t.usuarioId !== o.usuarioTecnicoId).map(t => <option key={t.usuarioId} value={t.usuarioId}>{t.nombre} · {t.empleadoCodigo}</option>)}
          </SelectInput></Field> : null}
        <Field label={accion === "cancelar" ? "Motivo de cancelación" : "Observación"} htmlFor="orden-observacion" requerido={accion === "cancelar"}>
          <TextArea id="orden-observacion" rows={3} maxLength={500} required={accion === "cancelar"} disabled={guardando} value={observacion} onChange={e => setObservacion(e.target.value)} /></Field>
        <div className="tc-row tc-row--end"><Button type="button" disabled={guardando} onClick={() => setAccion(null)}>Volver</Button>
          <Button type="submit" variante="primario" disabled={guardando || (accion === "asignar" && (tecnicos.isLoading || tecnicos.isError || !tecnicoId))}>
            {guardando ? "Guardando…" : accion === "asignar" ? "Guardar asignación" : "Confirmar cancelación"}</Button></div>
      </form>
    </Dialog> : null}
  </>;
}
