import { useEffect, useRef, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { puedeAcceder, useSession } from "../../app/session";
import { Alert } from "../../components/ui/Alert";
import { Button } from "../../components/ui/Button";
import { DataTable, type Columna } from "../../components/ui/DataTable";
import { Dialog } from "../../components/ui/Dialog";
import { Field, SelectInput, TextArea, TextInput } from "../../components/ui/inputs";
import { EmptyState, LoadingState } from "../../components/ui/StateView";
import type { Orden } from "../../services/ordenes";
import { servicioTecnicoApi as api, type ActividadRealizada, type RepuestoUsado } from "../../services/servicioTecnico";
import { esApiError, mensajeDeError } from "../../services/errors";
import { fechaHora, moneda } from "../../utils/format";

type Accion = "inicio" | "diagnostico" | "reparacion" | "actividad" | "repuesto" | "cierre";
const TITULOS: Record<Accion, string> = {
  inicio: "Iniciar diagnóstico", diagnostico: "Registrar diagnóstico", reparacion: "Autorizar e iniciar reparación",
  actividad: "Registrar actividad", repuesto: "Registrar repuesto utilizado", cierre: "Finalizar reparación",
};
const EXITO: Record<Accion, string> = {
  inicio: "Revisión iniciada. La orden está en diagnóstico.",
  diagnostico: "Diagnóstico registrado. La orden está esperando autorización del cliente.",
  reparacion: "Autorización documentada. La reparación está en proceso.",
  actividad: "Actividad registrada en el expediente.",
  repuesto: "Repuesto registrado y salida de inventario aplicada.",
  cierre: "Reparación terminada. La orden está LISTA para el proceso de facturación y entrega.",
};
const columnasActividades: Columna<ActividadRealizada>[] = [
  { clave: "nombre", encabezado: "Actividad", render: a => a.nombre },
  { clave: "fecha", encabezado: "Fecha", render: a => fechaHora(a.fecha) },
  { clave: "observacion", encabezado: "Trabajo realizado / observación", render: a => a.observacion || "—" },
];
const columnasRepuestos: Columna<RepuestoUsado>[] = [
  { clave: "nombre", encabezado: "Repuesto", render: r => `${r.codigo} · ${r.nombre}` },
  { clave: "bodega", encabezado: "Bodega", render: r => r.bodega },
  { clave: "cantidad", encabezado: "Cantidad", render: r => r.cantidad },
  { clave: "precio", encabezado: "Precio unitario", render: r => moneda(r.precioUnitario) },
  { clave: "importe", encabezado: "Importe", render: r => moneda(r.importe) },
  { clave: "salida", encabezado: "Salida de inventario", render: r => r.movimientoId ? `#${r.movimientoId} · ${fechaHora(r.fecha)}` : "Sin movimiento" },
];

export function ServicioTecnicoPanel({ orden: o, seccion }: { orden: Orden; seccion: "Diagnóstico" | "Reparación" | "Repuestos" }) {
  const sesion = useSession();
  const qc = useQueryClient();
  const propio = puedeAcceder(sesion, ["TECNICO"]) && sesion.usuario?.usuarioId === o.usuarioTecnicoId;
  const enReparacion = o.estadoCodigo === "REPARACION" && o.estadoReparacion === "EN_PROCESO";
  const [accion, setAccion] = useState<Accion | null>(null);
  const [descripcion, setDescripcion] = useState("");
  const [costo, setCosto] = useState("");
  const [autorizacion, setAutorizacion] = useState("");
  const [actividadId, setActividadId] = useState("");
  const [observacion, setObservacion] = useState("");
  const [repuestoKey, setRepuestoKey] = useState("");
  const [cantidad, setCantidad] = useState("1");
  const [confirmado, setConfirmado] = useState(false);
  const [error, setError] = useState("");
  const [mensaje, setMensaje] = useState("");
  const [guardando, setGuardando] = useState(false);
  const enCurso = useRef(false);
  const montado = useRef(true);
  useEffect(() => { montado.current = true; return () => { montado.current = false; }; }, []);

  const actividades = useQuery({ queryKey: ["orden", o.ordenId, "actividades"],
    queryFn: ({ signal }) => api.actividades(o.ordenId, signal), enabled: seccion === "Reparación" });
  const repuestos = useQuery({ queryKey: ["orden", o.ordenId, "repuestos"],
    queryFn: ({ signal }) => api.repuestos(o.ordenId, signal), enabled: seccion === "Repuestos" || seccion === "Reparación" });
  const catActividades = useQuery({ queryKey: ["orden", o.ordenId, "catalogo-actividades"],
    queryFn: ({ signal }) => api.catalogoActividades(o.ordenId, signal), enabled: propio && accion === "actividad" });
  const catRepuestos = useQuery({ queryKey: ["orden", o.ordenId, "catalogo-repuestos"],
    queryFn: ({ signal }) => api.catalogoRepuestos(o.ordenId, signal), enabled: propio && accion === "repuesto" });
  const seleccionado = catRepuestos.data?.find(r => `${r.bodegaId}:${r.repuestoId}` === repuestoKey);
  const pendientes = catActividades.data?.filter(a => !actividades.data?.some(r => r.actividadId === a.actividadId)) ?? [];

  function abrir(tipo: Accion) {
    setAccion(tipo); setError(""); setMensaje(""); setConfirmado(false);
    setDescripcion(tipo === "reparacion" ? o.descripcionDiagnostico ?? "" : "");
    setCosto(tipo === "reparacion" && o.costoEstimado != null ? String(o.costoEstimado) : "");
    setAutorizacion(""); setActividadId(""); setObservacion(""); setRepuestoKey(""); setCantidad("1");
  }
  async function actualizar() {
    await Promise.all([
      qc.invalidateQueries({ queryKey: ["orden", o.ordenId] }),
      qc.invalidateQueries({ queryKey: ["ordenes"] }),
      qc.invalidateQueries({ queryKey: ["equipos"] }),
    ]);
  }
  async function guardar() {
    if (enCurso.current || !accion || !propio) return;
    const tipo = accion;
    if (["diagnostico", "reparacion"].includes(tipo) &&
      (!descripcion.trim() || !/^(?:0|[1-9]\d{0,9})(?:\.\d{1,2})?$/.test(costo))) {
      setError("Ingresá la descripción y un costo válido con hasta dos decimales."); return;
    }
    if (tipo === "reparacion" && !autorizacion.trim()) { setError("Documentá la autorización del cliente."); return; }
    if (tipo === "actividad" && !actividadId) { setError("Elegí una actividad pendiente."); return; }
    if (tipo === "repuesto" && (!seleccionado || !/^\d+$/.test(cantidad) || !Number.isSafeInteger(Number(cantidad)) ||
      Number(cantidad) < 1 || Number(cantidad) > Math.min(seleccionado.existencia, 2147483647))) {
      setError("Elegí un repuesto y una cantidad entera dentro de la existencia disponible."); return;
    }
    if (["diagnostico", "reparacion", "repuesto", "cierre"].includes(tipo) && !confirmado) {
      setError("Revisá los datos y marcá la confirmación."); return;
    }
    enCurso.current = true; setGuardando(true); setError("");
    try {
      let actualizada: Orden;
      switch (tipo) {
        case "inicio": actualizada = await api.iniciarDiagnostico(o.ordenId); break;
        case "diagnostico": actualizada = await api.diagnosticar(o.ordenId, descripcion.trim(), Number(costo)); break;
        case "reparacion": actualizada = await api.reparar(o.ordenId, descripcion.trim(), Number(costo), autorizacion.trim()); break;
        case "actividad": actualizada = await api.agregarActividad(o.ordenId, Number(actividadId), observacion.trim()); break;
        case "repuesto": actualizada = await api.consumir(o.ordenId, seleccionado!, Number(cantidad)); break;
        case "cierre": actualizada = await api.finalizar(o.ordenId); break;
      }
      // No repoblar la caché de una sesión que pudo cerrarse durante la escritura.
      if (montado.current) {
        qc.setQueryData(["orden", o.ordenId], actualizada);
        setMensaje(EXITO[tipo]); setAccion(null);
      }
      await actualizar();
    } catch (e) {
      if (montado.current) {
        setError(mensajeDeError(e));
        setConfirmado(false);
      }
      if (esApiError(e) && [403, 404, 409].includes(e.status)) await actualizar();
    } finally {
      enCurso.current = false;
      if (montado.current) setGuardando(false);
    }
  }
  const ocupado = guardando || !propio || (accion === "actividad" && (catActividades.isFetching || catActividades.isError || actividades.isError || !actividadId))
    || (accion === "repuesto" && (catRepuestos.isFetching || catRepuestos.isError || !seleccionado))
    || (accion === "cierre" && (actividades.isFetching || actividades.isError || repuestos.isFetching || repuestos.isError));
  return <div className="tc-stack">
    {mensaje ? <Alert tono="ok">{mensaje}</Alert> : null}
    {!propio && !o.esFinal && o.estadoCodigo !== "LISTO" ? <Alert tono="info">
      {o.usuarioTecnicoId ? "El técnico asignado realiza el diagnóstico, registra el trabajo y finaliza la reparación desde su sesión."
        : "Recepción debe asignar un técnico antes de iniciar el diagnóstico."}
    </Alert> : null}
    {seccion === "Diagnóstico" ? <>
      {o.diagnosticoId ? <><dl className="tc-dl"><dt>Técnico</dt><dd>{o.tecnico}</dd><dt>Fecha</dt><dd>{fechaHora(o.fechaDiagnostico)}</dd>
        <dt>Descripción</dt><dd className="tc-servicio-texto">{o.descripcionDiagnostico}</dd><dt>Mano de obra estimada</dt><dd>{moneda(o.costoEstimado)}</dd></dl>
        {o.estadoCodigo === "ESPERANDO_AUTORIZACION" ? <Alert tono="info">La reparación puede iniciarse después de documentar la autorización del cliente, en la pestaña Reparación.</Alert> : null}</> :
        <EmptyState titulo={o.estadoCodigo === "DIAGNOSTICO" ? "Revisión en curso" : "Sin diagnóstico registrado"}
          descripcion={`Falla reportada: ${o.problemaReportado}`} />}
      {propio && !o.diagnosticoId && o.estadoCodigo === "RECIBIDO" ? <Button variante="primario" disabled={guardando} onClick={() => abrir("inicio")}>Iniciar diagnóstico</Button> : null}
      {propio && !o.diagnosticoId && o.estadoCodigo === "DIAGNOSTICO" ? <Button variante="primario" disabled={guardando} onClick={() => abrir("diagnostico")}>Registrar diagnóstico y estimación</Button> : null}
    </> : null}
    {seccion === "Reparación" ? <>
      {o.reparacionId ? <dl className="tc-dl"><dt>Estado</dt><dd>{o.estadoReparacion === "EN_PROCESO" ? "En proceso" : "Terminada"}</dd>
        <dt>Técnico</dt><dd>{o.tecnico}</dd><dt>Inicio</dt><dd>{fechaHora(o.fechaInicioReparacion)}</dd>
        <dt>Finalización</dt><dd>{fechaHora(o.fechaFinReparacion)}</dd><dt>Trabajo autorizado</dt><dd className="tc-servicio-texto">{o.descripcionTrabajo}</dd>
        <dt>Mano de obra acordada</dt><dd>{moneda(o.costoManoObra)}</dd></dl> :
        <EmptyState titulo="Sin reparación registrada" descripcion={o.estadoCodigo === "ESPERANDO_AUTORIZACION"
          ? `Mano de obra estimada: ${moneda(o.costoEstimado)}. Registrá el trabajo y la autorización para continuar.`
          : "La reparación requiere diagnóstico y autorización del cliente."} />}
      {propio && o.estadoCodigo === "ESPERANDO_AUTORIZACION" ? <Button variante="primario" disabled={guardando} onClick={() => abrir("reparacion")}>Autorizar e iniciar reparación</Button> : null}
      {o.reparacionId ? <>
        <h3 className="tc-section-title">Actividades realizadas</h3>
        {actividades.isLoading ? <LoadingState titulo="Cargando actividades…" /> : actividades.isError ?
          <Alert tono="danger" accion={<Button onClick={() => actividades.refetch()}>Reintentar</Button>}>{mensajeDeError(actividades.error)}</Alert> :
          <DataTable columnas={columnasActividades} filas={actividades.data ?? []} claveFila={a => a.actividadId} vacio="Sin actividades registradas." />}
        {propio && enReparacion ? <div className="tc-row" style={{ flexWrap: "wrap" }}>
          <Button disabled={guardando || actividades.isLoading || actividades.isError} onClick={() => abrir("actividad")}>Registrar actividad</Button>
          <Button variante="primario" disabled={guardando || actividades.isLoading || actividades.isError || repuestos.isLoading || repuestos.isError} onClick={() => abrir("cierre")}>Finalizar reparación</Button>
        </div> : null}
        {o.estadoCodigo === "LISTO" ? <Alert tono="ok">El trabajo técnico terminó. La orden está lista para facturación y entrega.</Alert> : null}
        {repuestos.isError ? <Alert tono="danger" accion={<Button onClick={() => repuestos.refetch()}>Reintentar</Button>}>No se pudo verificar el listado de repuestos: {mensajeDeError(repuestos.error)}</Alert> : null}
      </> : null}
    </> : null}
    {seccion === "Repuestos" ? <>
      <p className="tc-section-sub">Repuestos utilizados en esta reparación. Cada registro conserva su precio y la salida de inventario.</p>
      {repuestos.isLoading ? <LoadingState titulo="Cargando repuestos utilizados…" /> : repuestos.isError ?
        <Alert tono="danger" accion={<Button onClick={() => repuestos.refetch()}>Reintentar</Button>}>{mensajeDeError(repuestos.error)}</Alert> :
        <DataTable columnas={columnasRepuestos} filas={repuestos.data ?? []} claveFila={r => r.linea} vacio="Sin repuestos utilizados. El servicio puede realizarse solo con mano de obra." />}
      {propio && enReparacion ? <Button variante="primario" disabled={guardando || repuestos.isLoading || repuestos.isError} onClick={() => abrir("repuesto")}>Registrar repuesto utilizado</Button> : null}
    </> : null}
    {accion ? <Dialog abierto titulo={TITULOS[accion]} ancho={680} onCerrar={() => { if (!enCurso.current) setAccion(null); }}>
      <form className="tc-stack" style={{ marginTop: 16 }} onSubmit={e => { e.preventDefault(); void guardar(); }}>
        {error ? <Alert tono="danger">{error}</Alert> : null}
        {!propio ? <Alert tono="danger">La asignación o los permisos cambiaron. Actualizá el expediente.</Alert> : null}
        {accion === "inicio" ? <p>Se registrará el inicio de revisión de {o.numeroOrden} a tu nombre.</p> : null}
        {accion === "diagnostico" || accion === "reparacion" ? <>
          <Field label={accion === "diagnostico" ? "Diagnóstico del equipo" : "Trabajo autorizado"} htmlFor="servicio-descripcion" requerido>
            <TextArea id="servicio-descripcion" required maxLength={2000} rows={5} disabled={guardando} value={descripcion} onChange={e => setDescripcion(e.target.value)} /></Field>
          <Field label={accion === "diagnostico" ? "Mano de obra estimada (Q)" : "Mano de obra acordada (Q)"} htmlFor="servicio-costo" requerido hint="Importe de mano de obra. Los repuestos se registran por separado.">
            <TextInput id="servicio-costo" type="number" min="0" max="9999999999.99" step="0.01" required disabled={guardando} value={costo} onChange={e => setCosto(e.target.value)} /></Field>
          {accion === "reparacion" ? <Field label="Autorización del cliente" htmlFor="servicio-autorizacion" requerido hint="Indicá quién autorizó, la fecha y el medio de contacto.">
            <TextArea id="servicio-autorizacion" required maxLength={500} rows={3} disabled={guardando} value={autorizacion} onChange={e => setAutorizacion(e.target.value)} /></Field> : null}
          <Alert tono="info">Revisá los datos antes de guardar. El registro se conserva como parte del historial del servicio.</Alert>
        </> : null}
        {accion === "actividad" ? <>
          {catActividades.isLoading ? <LoadingState titulo="Cargando catálogo de actividades…" /> : catActividades.isError ?
            <Alert tono="danger" accion={<Button onClick={() => catActividades.refetch()}>Reintentar</Button>}>{mensajeDeError(catActividades.error)}</Alert> :
            <Field label="Actividad" htmlFor="servicio-actividad" requerido><SelectInput id="servicio-actividad" required disabled={guardando} value={actividadId} onChange={e => setActividadId(e.target.value)}>
              <option value="">Elegir actividad</option>{pendientes.map(a => <option key={a.actividadId} value={a.actividadId}>{a.nombre}</option>)}
            </SelectInput></Field>}
          {catActividades.isSuccess && pendientes.length === 0 ? <Alert tono="info">No hay actividades activas pendientes para esta reparación.</Alert> : null}
          <Field label="Trabajo realizado / observación" htmlFor="servicio-observacion"><TextArea id="servicio-observacion" maxLength={500} rows={3} disabled={guardando} value={observacion} onChange={e => setObservacion(e.target.value)} /></Field>
        </> : null}
        {accion === "repuesto" ? <>
          <Button disabled={guardando || catRepuestos.isFetching} onClick={() => { setConfirmado(false); void catRepuestos.refetch(); }}>Actualizar existencias y precios</Button>
          {catRepuestos.isLoading ? <LoadingState titulo="Cargando existencias…" /> : catRepuestos.isError ? <Alert tono="danger">{mensajeDeError(catRepuestos.error)}</Alert> :
            <Field label="Repuesto y bodega" htmlFor="servicio-repuesto" requerido><SelectInput id="servicio-repuesto" required disabled={guardando || catRepuestos.isFetching} value={repuestoKey} onChange={e => { setRepuestoKey(e.target.value); setConfirmado(false); }}>
              <option value="">Elegir repuesto disponible</option>{catRepuestos.data?.map(r => <option key={`${r.bodegaId}:${r.repuestoId}`} value={`${r.bodegaId}:${r.repuestoId}`} disabled={r.existencia <= 0}>
                {r.codigo} · {r.nombre} · {r.bodega} · {r.existencia} disponibles · {moneda(r.precioUnitario)} c/u
              </option>)}
            </SelectInput></Field>}
          <Field label="Cantidad utilizada" htmlFor="servicio-cantidad" requerido><TextInput id="servicio-cantidad" type="number" required min="1" step="1" max={seleccionado ? Math.min(seleccionado.existencia, 2147483647) : 2147483647}
            disabled={guardando} value={cantidad} onChange={e => { setCantidad(e.target.value); setConfirmado(false); }} /></Field>
          {seleccionado ? <p>Precio unitario: {moneda(seleccionado.precioUnitario)}. Existencia consultada: {seleccionado.existencia} unidades en {seleccionado.bodega}.</p> : null}
          <Alert tono="info">Al confirmar se registrará el consumo y se descontarán las unidades de la bodega seleccionada.</Alert>
        </> : null}
        {accion === "cierre" ? <>
          <p>Se finalizará el trabajo de {o.numeroOrden} y la orden pasará a LISTO.</p>
          <dl className="tc-dl"><dt>Actividades registradas</dt><dd>{actividades.data?.length ?? "—"}</dd><dt>Líneas de repuestos</dt><dd>{repuestos.data?.length ?? "—"}</dd>
            <dt>Mano de obra</dt><dd>{moneda(o.costoManoObra)}</dd></dl>
          <Alert tono="info">Verificá que todas las actividades y los repuestos estén registrados. El cierre conserva el expediente y termina la edición del trabajo técnico.</Alert>
        </> : null}
        {["diagnostico", "reparacion", "repuesto", "cierre"].includes(accion) ? <label className="tc-row" style={{ alignItems: "flex-start" }}>
          <input type="checkbox" required disabled={guardando} checked={confirmado} onChange={e => setConfirmado(e.target.checked)} />
          <span>{accion === "reparacion" ? "Confirmo los datos y que el cliente autorizó este trabajo y su mano de obra." : accion === "cierre" ? "Confirmo que el trabajo terminó y el expediente está completo." : "Revisé los datos y confirmo el registro."}</span>
        </label> : null}
        <div className="tc-row tc-row--end"><Button disabled={guardando} onClick={() => setAccion(null)}>Volver</Button>
          <Button type="submit" variante="primario" disabled={ocupado}>{guardando ? "Guardando…" : TITULOS[accion]}</Button></div>
      </form>
    </Dialog> : null}
  </div>;
}
