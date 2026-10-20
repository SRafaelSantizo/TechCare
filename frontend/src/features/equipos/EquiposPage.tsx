import { useMemo, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { History, Pencil, Plus } from "lucide-react";
import { Alert } from "../../components/ui/Alert";
import { Badge } from "../../components/ui/Badge";
import { Button, IconButton } from "../../components/ui/Button";
import { Card, PageHeader } from "../../components/ui/Card";
import { DataTable, Paginacion, type Columna } from "../../components/ui/DataTable";
import { Dialog } from "../../components/ui/Dialog";
import { SearchInput, SelectInput } from "../../components/ui/inputs";
import { EmptyState, ErrorState, LoadingState } from "../../components/ui/StateView";
import { equiposApi, type Equipo, type EquipoDatos, type HistorialEquipo } from "../../services/equipos";
import { mensajeDeError } from "../../services/errors";
import { nombreEstado } from "../../services/catalogos";
import { fechaHora, moneda, normalizar } from "../../utils/format";
import { useClientes } from "../clientes/hooks";
import { EquipoForm } from "./EquipoForm";
import { puedeAcceder, useSession } from "../../app/session";

export function EquiposPage() {
  const puedeEditar = puedeAcceder(useSession(), ["ADMIN", "RECEPCION"]);
  const [params] = useSearchParams();
  const [clienteFiltro, setClienteFiltro] = useState(params.get("clienteId") ?? "");
  const [busqueda, setBusqueda] = useState("");
  const [estadoFiltro, setEstadoFiltro] = useState("");
  const [pagina, setPagina] = useState(1);
  const [dialogo, setDialogo] = useState<{ equipo: Equipo | null } | null>(null);
  const [historial, setHistorial] = useState<Equipo | null>(null);
  const [ok, setOk] = useState("");
  const qc = useQueryClient();
  const equipos = useQuery({ queryKey: ["equipos"], queryFn: ({ signal }) => equiposApi.listar(undefined, signal) });
  const clientes = useClientes();
  const catalogos = useQuery({
    queryKey: ["catalogos", "equipos"],
    queryFn: async ({ signal }) => {
      const [marcas, tipos, modelos] = await Promise.all([equiposApi.marcas(signal), equiposApi.tipos(signal), equiposApi.modelos(signal)]);
      return { marcas, tipos, modelos };
    },
  });
  const movimientos = useQuery({
    queryKey: ["equipos", "historial", historial?.EquipoID],
    queryFn: ({ signal }) => equiposApi.historial(historial!.EquipoID, signal),
    enabled: historial !== null,
  });
  const guardar = useMutation({
    mutationFn: ({ equipo, datos }: { equipo: Equipo | null; datos: EquipoDatos }) => equipo
      ? equiposApi.actualizar(equipo.EquipoID, datos) : equiposApi.crear(datos),
    onSuccess: async (equipo) => {
      await qc.invalidateQueries({ queryKey: ["equipos"] });
      setDialogo(null);
      setOk(`Equipo ${equipo.NumeroSerie} guardado.`);
    },
  });
  const filas = useMemo(() => (equipos.data ?? []).filter(e => {
    if (clienteFiltro && String(e.ClienteID) !== clienteFiltro) return false;
    if (estadoFiltro && String(e.Activo) !== estadoFiltro) return false;
    return normalizar(`${e.NumeroSerie} ${e.Cliente} ${e.Marca} ${e.Modelo} ${e.Descripcion}`).includes(normalizar(busqueda));
  }), [equipos.data, clienteFiltro, estadoFiltro, busqueda]);
  const totalPaginas = Math.max(1, Math.ceil(filas.length / 10));
  const paginaActual = Math.min(pagina, totalPaginas);
  const columnas: Columna<Equipo>[] = [
    { clave: "serie", encabezado: "Serie", render: e => <><strong>{e.NumeroSerie}</strong><div className="tc-field__hint">{e.Descripcion}</div></> },
    { clave: "cliente", encabezado: "Cliente", render: e => <Link to={`/clientes/${e.ClienteID}`}>{e.Cliente}</Link> },
    { clave: "modelo", encabezado: "Equipo", render: e => <>{e.Marca} · {e.Modelo}<div className="tc-field__hint">{e.TipoEquipo}</div></> },
    { clave: "estado", encabezado: "Estado", render: e => <Badge tono={e.Activo ? "ok" : "neutral"}>{e.Activo ? "Activo" : "Inactivo"}</Badge> },
    { clave: "acciones", encabezado: "Acciones", render: e => <div className="tc-row">
      <IconButton etiqueta={`Editar ${e.NumeroSerie}`} disabled={!puedeEditar || !catalogos.data || !clientes.data} onClick={() => setDialogo({ equipo: e })}><Pencil size={16} /></IconButton>
      <IconButton etiqueta={`Historial de ${e.NumeroSerie}`} onClick={() => setHistorial(e)}><History size={16} /></IconButton>
    </div> },
  ];
  const historialColumnas: Columna<HistorialEquipo>[] = [
    { clave: "orden", encabezado: "Orden", render: h => h.NumeroOrden },
    { clave: "fecha", encabezado: "Ingreso", render: h => fechaHora(h.FechaIngreso) },
    { clave: "estado", encabezado: "Estado", render: h => nombreEstado(h.EstadoCodigo) },
    { clave: "diagnostico", encabezado: "Diagnóstico", render: h => h.Diagnostico ?? "Pendiente" },
    { clave: "saldo", encabezado: "Saldo", render: h => h.Saldo === null ? "Sin factura" : moneda(h.Saldo) },
  ];
  async function onGuardar(datos: EquipoDatos) {
    await guardar.mutateAsync({ equipo: dialogo?.equipo ?? null, datos });
  }
  return <>
    <PageHeader eyebrow="Servicio" titulo="Equipos" descripcion="Equipos de los clientes y su historial de ingresos al taller."
      acciones={<Button variante="primario" icono={<Plus size={16} />} disabled={!puedeEditar || !catalogos.data || !clientes.data} onClick={() => setDialogo({ equipo: null })}>Nuevo equipo</Button>} />
    <div className="tc-stack">
      {ok ? <Alert tono="ok">{ok}</Alert> : null}
      {catalogos.isError || clientes.isError ? <Alert tono="danger" accion={<Button onClick={() => { catalogos.refetch(); clientes.refetch(); }}>Reintentar</Button>}>No se pudieron cargar los clientes o catálogos. {mensajeDeError(catalogos.error ?? clientes.error)}</Alert> : null}
      <Card>
        <div className="tc-row" style={{ flexWrap: "wrap", marginBottom: 16 }}>
          <SearchInput placeholder="Buscar por serie, cliente o modelo" aria-label="Buscar equipo" value={busqueda} onChange={e => { setBusqueda(e.target.value); setPagina(1); }} />
          <SelectInput aria-label="Filtrar por cliente" value={clienteFiltro} onChange={e => { setClienteFiltro(e.target.value); setPagina(1); }}>
            <option value="">Todos los clientes</option>
            {clientes.data?.map(c => <option key={c.ClienteID} value={c.ClienteID}>{c.Nombre}</option>)}
          </SelectInput>
          <SelectInput aria-label="Filtrar por estado" value={estadoFiltro} onChange={e => { setEstadoFiltro(e.target.value); setPagina(1); }}>
            <option value="">Todos los estados</option><option value="true">Activos</option><option value="false">Inactivos</option>
          </SelectInput>
        </div>
        {equipos.isLoading ? <LoadingState titulo="Cargando equipos…" /> : equipos.isError
          ? <ErrorState mensaje={mensajeDeError(equipos.error)} onRetry={() => equipos.refetch()} />
          : <><DataTable columnas={columnas} filas={filas.slice((paginaActual - 1) * 10, paginaActual * 10)} claveFila={e => e.EquipoID} />
            <Paginacion pagina={paginaActual} totalPaginas={totalPaginas} total={filas.length} onCambiar={setPagina} /></>}
      </Card>
    </div>
    <Dialog abierto={dialogo !== null} titulo={dialogo?.equipo ? "Editar equipo" : "Registrar equipo"} onCerrar={() => { if (!guardar.isPending) setDialogo(null); }}>
      {dialogo && catalogos.data && clientes.data ? <EquipoForm key={dialogo.equipo?.EquipoID ?? "nuevo"} equipo={dialogo.equipo} clientes={clientes.data}
        {...catalogos.data} clienteInicial={clienteFiltro} guardando={guardar.isPending} onGuardar={onGuardar} onCancelar={() => setDialogo(null)} /> : null}
    </Dialog>
    <Dialog abierto={historial !== null} titulo={`Historial · ${historial?.NumeroSerie ?? ""}`} ancho={1000} onCerrar={() => setHistorial(null)}>
      {movimientos.isLoading ? <LoadingState /> : movimientos.isError ? <ErrorState mensaje={mensajeDeError(movimientos.error)} onRetry={() => movimientos.refetch()} />
        : movimientos.data?.length ? <DataTable columnas={historialColumnas} filas={movimientos.data} claveFila={h => h.OrdenID} />
          : <EmptyState titulo="Sin órdenes registradas" descripcion="El equipo todavía no ha ingresado al taller." />}
    </Dialog>
  </>;
}
