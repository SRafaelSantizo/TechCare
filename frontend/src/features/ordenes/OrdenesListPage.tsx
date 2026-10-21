import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { Plus, RefreshCw } from "lucide-react";
import { puedeAcceder, useSession } from "../../app/session";
import { PageHeader, Card } from "../../components/ui/Card";
import { Button } from "../../components/ui/Button";
import { Alert } from "../../components/ui/Alert";
import { EstadoOrdenBadge } from "../../components/ui/Badge";
import { Field, SearchInput, SelectInput, TextInput } from "../../components/ui/inputs";
import { LoadingState } from "../../components/ui/StateView";
import { DataTable, Paginacion, type Columna } from "../../components/ui/DataTable";
import { ordenesApi, type FiltrosOrden, type Orden } from "../../services/ordenes";
import { mensajeDeError } from "../../services/errors";
import { fechaHora } from "../../utils/format";

const INICIALES: FiltrosOrden = { buscar: "", estado: "", prioridad: "", tecnicoId: "", desde: "", hasta: "" };
export function OrdenesListPage() {
  const sesion = useSession();
  const gestion = puedeAcceder(sesion, ["ADMIN", "RECEPCION"]);
  const [formulario, setFormulario] = useState(INICIALES);
  const [filtros, setFiltros] = useState(INICIALES);
  const [pagina, setPagina] = useState(1);
  const [error, setError] = useState("");
  const ordenes = useQuery({ queryKey: ["ordenes", "lista", filtros], queryFn: ({ signal }) => ordenesApi.listar(filtros, signal) });
  const estados = useQuery({ queryKey: ["ordenes", "estados"], queryFn: ({ signal }) => ordenesApi.catalogo("estados", signal) });
  const prioridades = useQuery({ queryKey: ["ordenes", "prioridades"], queryFn: ({ signal }) => ordenesApi.catalogo("prioridades", signal) });
  const tecnicos = useQuery({ queryKey: ["ordenes", "tecnicos"], queryFn: ({ signal }) => ordenesApi.tecnicos(signal), enabled: gestion });
  function cambiar(clave: keyof FiltrosOrden, valor: string) { setFormulario(f => ({ ...f, [clave]: valor })); }
  const filas = ordenes.data ?? [];
  const paginas = Math.max(1, Math.ceil(filas.length / 10));
  const actual = Math.min(pagina, paginas);
  const columnas: Columna<Orden>[] = [
    { clave: "orden", encabezado: "Orden", render: o => <Link to={`/ordenes/${o.ordenId}`}>{o.numeroOrden}</Link> },
    { clave: "cliente", encabezado: "Cliente", render: o => o.cliente },
    { clave: "equipo", encabezado: "Equipo", render: o => <>{o.numeroSerie}<div className="tc-field__hint">{o.marca} {o.modelo}</div></> },
    { clave: "estado", encabezado: "Estado", render: o => <EstadoOrdenBadge codigo={o.estadoCodigo} nombre={o.estado} /> },
    { clave: "prioridad", encabezado: "Prioridad", render: o => o.prioridad },
    { clave: "tecnico", encabezado: "Técnico", render: o => o.tecnico || "Sin asignar" },
    { clave: "fecha", encabezado: "Ingreso", render: o => fechaHora(o.fechaIngreso) },
  ];
  return <>
    <PageHeader eyebrow="Servicio" titulo="Órdenes de servicio" descripcion={gestion || sesion.roles.includes("CAJA")
      ? "Consultá los ingresos y el avance de cada servicio." : "Consultá las órdenes asignadas a tu usuario."}
      acciones={<>{gestion ? <Link to="/ordenes/nueva"><Button variante="primario" icono={<Plus size={16} />}>Nueva orden</Button></Link> : null}
        <Button icono={<RefreshCw size={16} />} disabled={ordenes.isFetching} onClick={() => ordenes.refetch()}>Actualizar</Button></>} />
    <div className="tc-stack">
      <Card>
        <form className="tc-stack" onSubmit={e => { e.preventDefault();
          if (formulario.desde && formulario.hasta && formulario.desde > formulario.hasta) { setError("La fecha inicial debe ser anterior o igual a la final."); return; }
          setError(""); setPagina(1); setFiltros({ ...formulario, buscar: formulario.buscar.trim() });
        }}>
          <SearchInput aria-label="Buscar órdenes" placeholder="Número de orden, cliente, NIT o serie" maxLength={150} value={formulario.buscar} onChange={e => cambiar("buscar", e.target.value)} />
          <div className="tc-grid tc-grid--3">
            <Field label="Estado" htmlFor="ordenes-estado"><SelectInput id="ordenes-estado" value={formulario.estado} onChange={e => cambiar("estado", e.target.value)}>
              <option value="">Todos los estados</option>{estados.data?.map(o => <option key={o.codigo} value={o.codigo}>{o.nombre}</option>)}
            </SelectInput></Field>
            <Field label="Prioridad" htmlFor="ordenes-prioridad"><SelectInput id="ordenes-prioridad" value={formulario.prioridad} onChange={e => cambiar("prioridad", e.target.value)}>
              <option value="">Todas las prioridades</option>{prioridades.data?.map(o => <option key={o.codigo} value={o.codigo}>{o.nombre}</option>)}
            </SelectInput></Field>
            {gestion ? <Field label="Técnico" htmlFor="ordenes-tecnico"><SelectInput id="ordenes-tecnico" value={formulario.tecnicoId} onChange={e => cambiar("tecnicoId", e.target.value)}>
              <option value="">Todos los técnicos</option><option value="0">Sin asignar</option>{tecnicos.data?.map(t => <option key={t.usuarioId} value={t.usuarioId}>{t.nombre}</option>)}
            </SelectInput></Field> : null}
            <Field label="Ingreso desde" htmlFor="ordenes-desde"><TextInput id="ordenes-desde" type="date" value={formulario.desde} onChange={e => cambiar("desde", e.target.value)} /></Field>
            <Field label="Ingreso hasta" htmlFor="ordenes-hasta" hint="Incluye el día completo en Guatemala."><TextInput id="ordenes-hasta" type="date" value={formulario.hasta} onChange={e => cambiar("hasta", e.target.value)} /></Field>
          </div>
          {error ? <Alert tono="danger">{error}</Alert> : null}
          <div className="tc-row tc-row--end"><Button type="button" onClick={() => { setFormulario(INICIALES); setFiltros(INICIALES); setPagina(1); setError(""); }}>Limpiar filtros</Button>
            <Button type="submit" variante="primario">Buscar</Button></div>
        </form>
      </Card>
      {estados.isError || prioridades.isError || tecnicos.isError ? <Alert tono="warn" titulo="Algunos filtros no se pudieron cargar"
        accion={<Button onClick={() => { void estados.refetch(); void prioridades.refetch(); if (gestion) void tecnicos.refetch(); }}>Reintentar filtros</Button>}>
        {mensajeDeError(estados.error || prioridades.error || tecnicos.error)}
      </Alert> : null}
      <Card>{ordenes.isLoading ? <LoadingState titulo="Cargando órdenes…" /> : ordenes.isError ?
        <Alert tono="danger" titulo="No se pudo cargar el listado" accion={<Button onClick={() => ordenes.refetch()}>Reintentar</Button>}>{mensajeDeError(ordenes.error)}</Alert> : <>
          <DataTable columnas={columnas} filas={filas.slice((actual - 1) * 10, actual * 10)} claveFila={o => o.ordenId} vacio="No hay órdenes disponibles con estos filtros." />
          <Paginacion pagina={actual} totalPaginas={paginas} total={filas.length} onCambiar={setPagina} />
        </>}</Card>
    </div>
  </>;
}
