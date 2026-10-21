import { useEffect, useRef, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Link, useNavigate } from "react-router-dom";
import { Check } from "lucide-react";
import { PageHeader, Card } from "../../components/ui/Card";
import { Button } from "../../components/ui/Button";
import { Alert } from "../../components/ui/Alert";
import { SearchInput, SelectInput, TextArea, Field, TextInput } from "../../components/ui/inputs";
import { Badge } from "../../components/ui/Badge";
import { EmptyState, LoadingState } from "../../components/ui/StateView";
import { useClientes } from "../clientes/hooks";
import { nombreTipoCliente } from "../../services/catalogos";
import { mensajeDeError } from "../../services/errors";
import { normalizar, fechaHora } from "../../utils/format";
import type { Cliente } from "../../types/api";
import { equiposApi } from "../../services/equipos";
import { ordenesApi } from "../../services/ordenes";
import "./ordenes.css";

const PASOS = ["Cliente", "Equipo", "Problema", "Confirmar"] as const;
export function OrdenNuevaPage() {
  const [paso, setPaso] = useState(0);
  const [cliente, setCliente] = useState<Cliente | null>(null);
  const clientes = useClientes();
  const [busqueda, setBusqueda] = useState("");
  const [equipoId, setEquipoId] = useState("");
  const [problema, setProblema] = useState("");
  const [prioridad, setPrioridad] = useState("NORMAL");
  const [estimada, setEstimada] = useState("");
  const [observaciones, setObservaciones] = useState("");
  const [error, setError] = useState("");
  const [guardando, setGuardando] = useState(false);
  const enCurso = useRef(false);
  const montado = useRef(true);
  useEffect(() => { montado.current = true; return () => { montado.current = false; }; }, []);
  const navegar = useNavigate();
  const qc = useQueryClient();
  const equipos = useQuery({ queryKey: ["equipos", "cliente", cliente?.ClienteID],
    queryFn: ({ signal }) => equiposApi.listar(cliente!.ClienteID, signal), enabled: cliente !== null });
  const prioridades = useQuery({ queryKey: ["ordenes", "prioridades"], queryFn: ({ signal }) => ordenesApi.catalogo("prioridades", signal) });
  const equipo = equipos.data?.find(e => e.EquipoID === Number(equipoId));
  const filtrados = (clientes.data ?? []).filter(c => normalizar(c.Nombre).includes(normalizar(busqueda)) || normalizar(c.NIT).includes(normalizar(busqueda)));
  function fechaEstimadaUtc() { return estimada ? new Date(`${estimada}-06:00`).toISOString() : null; }
  function validar(): boolean {
    if (!cliente?.Activo || !equipo?.Activo || !equipo.ClienteActivo) { setError("Elegí un cliente y un equipo activos."); return false; }
    if (!problema.trim() || problema.trim().length > 1000) { setError("El problema es obligatorio y admite hasta 1000 caracteres."); return false; }
    if (!prioridades.data?.some(p => p.codigo === prioridad)) { setError("Elegí una prioridad válida."); return false; }
    if (observaciones.trim().length > 1000) { setError("Las observaciones admiten hasta 1000 caracteres."); return false; }
    if (estimada && (!Number.isFinite(new Date(`${estimada}-06:00`).getTime()) || new Date(`${estimada}-06:00`).getTime() <= Date.now())) {
      setError("La fecha estimada debe ser posterior al momento actual."); return false;
    }
    setError(""); return true;
  }
  async function confirmar() {
    if (enCurso.current || !validar()) return;
    enCurso.current = true; setGuardando(true);
    try {
      const orden = await ordenesApi.crear({ equipoId: Number(equipoId), problema: problema.trim(), prioridad,
        fechaEstimada: fechaEstimadaUtc(), observaciones: observaciones.trim() || null });
      if (!montado.current) return;
      qc.setQueryData(["orden", orden.ordenId], orden);
      await Promise.all([qc.invalidateQueries({ queryKey: ["ordenes"] }), qc.invalidateQueries({ queryKey: ["equipos"] })]);
      if (!montado.current) return;
      navegar(`/ordenes/${orden.ordenId}`, { replace: true, state: { nuevaOrden: true } });
    } catch (e) {
      setError(`${mensajeDeError(e)} Si la conexión se interrumpió, consultá el listado antes de volver a confirmar.`);
    } finally { enCurso.current = false; setGuardando(false); }
  }
  return <>
    <PageHeader eyebrow="Servicio / Órdenes" titulo="Nueva orden de servicio" descripcion="Elegí el cliente y su equipo, describí la falla y confirmá el ingreso." />
    <div className="tc-stack tc-ordenes">
      <nav aria-label="Pasos de la recepción" className="tc-row" style={{ gap: 8, flexWrap: "wrap" }}>
        {PASOS.map((nombre, i) => <Badge key={nombre} tono={i === paso ? "info" : i < paso ? "ok" : "neutral"}>{i < paso ? <Check size={13} /> : null} {i + 1}. {nombre}</Badge>)}
      </nav>
      {error ? <Alert tono="danger" titulo="No se pudo continuar">{error}</Alert> : null}
      {paso === 0 ? <Card>
        <h2 className="tc-section-title">Paso 1 · Cliente</h2><p className="tc-section-sub">Buscá al cliente que entrega el equipo.</p>
        <SearchInput aria-label="Buscar cliente" placeholder="Buscar por nombre o NIT" value={busqueda} onChange={e => setBusqueda(e.target.value)} />
        {clientes.isLoading ? <LoadingState titulo="Cargando clientes…" /> : clientes.isError ?
          <Alert tono="danger" accion={<Button onClick={() => clientes.refetch()}>Reintentar</Button>}>{mensajeDeError(clientes.error)}</Alert> :
          filtrados.length === 0 ? <EmptyState titulo="Sin coincidencias" descripcion="Probá otro nombre o registrá un cliente nuevo." /> :
          <ul style={{ listStyle: "none", padding: 0 }}>{filtrados.slice(0, 10).map(c =>
            <li key={c.ClienteID} className="tc-row" style={{ justifyContent: "space-between", padding: "12px 0", borderBottom: "1px solid var(--tc-divider)" }}>
              <span><strong>{c.Nombre}</strong><span className="tc-field__hint" style={{ display: "block" }}>{nombreTipoCliente(c.TipoClienteID)} · NIT {c.NIT}{c.Activo ? "" : " · Inactivo"}</span></span>
              <Button tamano="sm" disabled={!c.Activo} variante={cliente?.ClienteID === c.ClienteID ? "primario" : "secundario"}
                onClick={() => { setCliente(c); setEquipoId(""); setError(""); }}>{cliente?.ClienteID === c.ClienteID ? "Seleccionado" : "Elegir"}</Button>
            </li>)}</ul>}
        <div className="tc-row tc-row--end"><Link to="/clientes"><Button variante="fantasma">Registrar cliente nuevo</Button></Link>
          <Button variante="primario" disabled={!cliente || clientes.isError} onClick={() => setPaso(1)}>Continuar con el equipo</Button></div>
      </Card> : null}
      {paso === 1 ? <Card>
        <h2 className="tc-section-title">Paso 2 · Equipo</h2><p className="tc-section-sub">Cliente: {cliente?.Nombre}</p>
        {equipos.isLoading ? <LoadingState titulo="Cargando equipos…" /> : equipos.isError ?
          <Alert tono="danger" accion={<Button onClick={() => equipos.refetch()}>Reintentar</Button>}>{mensajeDeError(equipos.error)}</Alert> :
          <Field label="Equipo del cliente" htmlFor="nueva-equipo" requerido><SelectInput id="nueva-equipo" value={equipoId} onChange={e => setEquipoId(e.target.value)}>
            <option value="">Elegir equipo</option>{(equipos.data ?? []).filter(e => e.Activo && e.ClienteActivo).map(e =>
              <option key={e.EquipoID} value={e.EquipoID}>{e.NumeroSerie} · {e.Marca} {e.Modelo}</option>)}
          </SelectInput></Field>}
        {!equipos.isLoading && !equipos.isError && !equipos.data?.some(e => e.Activo && e.ClienteActivo) ?
          <EmptyState titulo="Sin equipos activos" descripcion="Registrá un equipo para este cliente antes de continuar." /> : null}
        <div className="tc-row" style={{ marginTop: 16 }}><Link to={`/equipos?clienteId=${cliente?.ClienteID}`}><Button variante="fantasma">Registrar o consultar equipos</Button></Link>
          <Button onClick={() => setPaso(0)}>Atrás</Button><Button variante="primario" disabled={!equipo?.Activo || equipos.isError} onClick={() => { setError(""); setPaso(2); }}>Continuar</Button></div>
      </Card> : null}
      {paso === 2 ? <Card>
        <h2 className="tc-section-title">Paso 3 · Problema reportado</h2>
        <form className="tc-stack" onSubmit={e => { e.preventDefault(); if (validar()) setPaso(3); }}>
          <Field label="Problema reportado" htmlFor="nueva-problema" requerido hint={`${problema.length}/1000 caracteres`}>
            <TextArea id="nueva-problema" required rows={4} maxLength={1000} value={problema} onChange={e => setProblema(e.target.value)} /></Field>
          <div className="tc-grid tc-grid--2">
            <Field label="Prioridad" htmlFor="nueva-prioridad" requerido><SelectInput id="nueva-prioridad" required value={prioridad} disabled={prioridades.isLoading || prioridades.isError} onChange={e => setPrioridad(e.target.value)}>
              {(prioridades.data ?? []).map(p => <option key={p.codigo} value={p.codigo}>{p.nombre}</option>)}
            </SelectInput></Field>
            <Field label="Fecha estimada (opcional)" htmlFor="nueva-fecha" hint="Hora de Guatemala."><TextInput id="nueva-fecha" type="datetime-local" value={estimada} onChange={e => setEstimada(e.target.value)} /></Field>
          </div>
          {prioridades.isError ? <Alert tono="danger" accion={<Button type="button" onClick={() => prioridades.refetch()}>Reintentar</Button>}>{mensajeDeError(prioridades.error)}</Alert> : null}
          <Field label="Observaciones" htmlFor="nueva-obs" hint={`${observaciones.length}/1000 caracteres`}><TextArea id="nueva-obs" rows={3} maxLength={1000} value={observaciones} onChange={e => setObservaciones(e.target.value)} /></Field>
          <div className="tc-row tc-row--end"><Button type="button" onClick={() => setPaso(1)}>Atrás</Button><Button type="submit" variante="primario" disabled={prioridades.isLoading || prioridades.isError}>Revisar</Button></div>
        </form>
      </Card> : null}
      {paso === 3 ? <Card>
        <h2 className="tc-section-title">Paso 4 · Confirmar ingreso</h2>
        <dl className="tc-dl"><dt>Cliente</dt><dd>{cliente?.Nombre} · NIT {cliente?.NIT}</dd>
          <dt>Equipo</dt><dd>{equipo?.NumeroSerie} · {equipo?.Marca} {equipo?.Modelo}</dd>
          <dt>Problema reportado</dt><dd style={{ whiteSpace: "pre-wrap", overflowWrap: "anywhere" }}>{problema}</dd>
          <dt>Prioridad</dt><dd>{prioridades.data?.find(p => p.codigo === prioridad)?.nombre}</dd>
          <dt>Fecha estimada</dt><dd>{estimada ? fechaHora(fechaEstimadaUtc()) : "Sin fecha estimada"}</dd>
          <dt>Observaciones</dt><dd style={{ whiteSpace: "pre-wrap", overflowWrap: "anywhere" }}>{observaciones || "Sin observaciones"}</dd></dl>
        <p className="tc-section-sub">Al confirmar se asignará el número de orden y se registrará el ingreso a tu nombre.</p>
        <div className="tc-row tc-row--end"><Button disabled={guardando} onClick={() => { setError(""); setPaso(2); }}>Atrás</Button>
          <Button variante="primario" disabled={guardando} onClick={confirmar}>{guardando ? "Registrando…" : "Confirmar ingreso"}</Button></div>
      </Card> : null}
    </div>
  </>;
}
