import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { Pencil, Plus } from "lucide-react";
import { PageHeader, Card } from "../../components/ui/Card";
import { Button, IconButton } from "../../components/ui/Button";
import { Badge } from "../../components/ui/Badge";
import { DataTable, Paginacion, type Columna } from "../../components/ui/DataTable";
import { SearchInput, SelectInput } from "../../components/ui/inputs";
import { Dialog } from "../../components/ui/Dialog";
import { Alert } from "../../components/ui/Alert";
import { EmptyState, ErrorState, LoadingState } from "../../components/ui/StateView";
import { ClienteForm } from "./ClienteForm";
import { useActualizarCliente, useClientes, useCrearCliente } from "./hooks";
import { nombreTipoCliente, TIPOS_CLIENTE } from "../../services/catalogos";
import { mensajeDeError } from "../../services/errors";
import { normalizar, texto } from "../../utils/format";
import type { Cliente, ClienteDatos } from "../../types/api";
import { puedeAcceder, useSession } from "../../app/session";

const TAMANO_PAGINA = 10;

export function ClientesListPage() {
  const puedeEditar = puedeAcceder(useSession(), ["ADMIN", "RECEPCION"]);
  const { data, isLoading, isError, error, refetch } = useClientes();
  const crear = useCrearCliente();
  const actualizar = useActualizarCliente();

  const [textoBusqueda, setTextoBusqueda] = useState("");
  const [tipoFiltro, setTipoFiltro] = useState("");
  const [estadoFiltro, setEstadoFiltro] = useState("");
  const [pagina, setPagina] = useState(1);
  const [dialogo, setDialogo] = useState<{ abierto: boolean; cliente: Cliente | null }>({
    abierto: false,
    cliente: null,
  });
  const [ok, setOk] = useState<string | null>(null);
  const [errorDialogo, setErrorDialogo] = useState<string | null>(null);

  const filtrados = useMemo(() => {
    const q = normalizar(textoBusqueda);
    return (data ?? []).filter((c) => {
      if (tipoFiltro && String(c.TipoClienteID) !== tipoFiltro) return false;
      if (estadoFiltro === "activos" && !c.Activo) return false;
      if (estadoFiltro === "inactivos" && c.Activo) return false;
      if (!q) return true;
      return (
        normalizar(c.Nombre).includes(q) ||
        normalizar(c.NIT).includes(q) ||
        normalizar(c.Email ?? "").includes(q)
      );
    });
  }, [data, textoBusqueda, tipoFiltro, estadoFiltro]);

  const totalPaginas = Math.max(1, Math.ceil(filtrados.length / TAMANO_PAGINA));
  const paginaActual = Math.min(pagina, totalPaginas);
  const visibles = filtrados.slice((paginaActual - 1) * TAMANO_PAGINA, paginaActual * TAMANO_PAGINA);

  const columnas: Array<Columna<Cliente>> = [
    {
      clave: "nombre",
      encabezado: "Cliente",
      render: (c) => (
        <Link to={`/clientes/${c.ClienteID}`} style={{ color: "var(--tc-text)" }}>
          <strong style={{ fontWeight: 500 }}>{c.Nombre}</strong>
          <div className="tc-field__hint">{nombreTipoCliente(c.TipoClienteID)}</div>
        </Link>
      ),
    },
    { clave: "nit", encabezado: "NIT", render: (c) => <span className="tc-tabular">{c.NIT}</span> },
    { clave: "email", encabezado: "Correo", render: (c) => texto(c.Email) },
    { clave: "telefono", encabezado: "Telefono", render: (c) => texto(c.Telefono) },
    {
      clave: "estado",
      encabezado: "Estado",
      render: (c) => <Badge tono={c.Activo ? "ok" : "neutral"}>{c.Activo ? "Activo" : "Inactivo"}</Badge>,
    },
    {
      clave: "acciones",
      encabezado: "Acciones",
      render: (c) => (
        <div className="tc-row" style={{ gap: 4 }}>
          <IconButton
            etiqueta={`Editar ${c.Nombre}`}
            disabled={!puedeEditar}
            onClick={() => {
              setErrorDialogo(null);
              setDialogo({ abierto: true, cliente: c });
            }}
          >
            <Pencil size={16} />
          </IconButton>
        </div>
      ),
    },
  ];

  async function guardar(datos: ClienteDatos) {
    setErrorDialogo(null);
    if (dialogo.cliente) {
      await actualizar.mutateAsync({ id: dialogo.cliente.ClienteID, datos });
      setOk(`Cliente "${datos.nombre}" actualizado.`);
    } else {
      await crear.mutateAsync(datos);
      setOk(`Cliente "${datos.nombre}" registrado.`);
    }
    setDialogo({ abierto: false, cliente: null });
  }

  const guardando = crear.isPending || actualizar.isPending;

  return (
    <>
      <PageHeader
        eyebrow="Servicio"
        titulo="Clientes"
        descripcion="Datos fiscales y de contacto. Desde el cliente se accede a sus equipos e historial de ordenes."
        acciones={
          <Button
            variante="primario"
            disabled={!puedeEditar}
            icono={<Plus size={16} />}
            onClick={() => {
              setErrorDialogo(null);
              setDialogo({ abierto: true, cliente: null });
            }}
          >
            Nuevo cliente
          </Button>
        }
      />

      <div className="tc-stack">
        {ok ? (
          <Alert tono="ok" titulo="Operacion realizada">
            {ok}
          </Alert>
        ) : null}

        <Card flush>
          <div style={{ padding: "24px 24px 16px" }}>
            <div className="tc-row">
              <div style={{ flex: 1, minWidth: 220 }}>
                <SearchInput
                  placeholder="Buscar por nombre, NIT o correo"
                  aria-label="Buscar clientes"
                  value={textoBusqueda}
                  onChange={(e) => {
                    setTextoBusqueda(e.target.value);
                    setPagina(1);
                  }}
                />
              </div>
              <SelectInput
                aria-label="Filtrar por tipo"
                value={tipoFiltro}
                onChange={(e) => {
                  setTipoFiltro(e.target.value);
                  setPagina(1);
                }}
                style={{ width: 190 }}
              >
                <option value="">Todos los tipos</option>
                {TIPOS_CLIENTE.map((t) => (
                  <option key={t.id} value={t.id}>
                    {t.nombre}
                  </option>
                ))}
              </SelectInput>
              <SelectInput
                aria-label="Filtrar por estado"
                value={estadoFiltro}
                onChange={(e) => {
                  setEstadoFiltro(e.target.value);
                  setPagina(1);
                }}
                style={{ width: 170 }}
              >
                <option value="">Todos los estados</option>
                <option value="activos">Solo activos</option>
                <option value="inactivos">Solo inactivos</option>
              </SelectInput>
            </div>
          </div>

          {isLoading ? (
            <LoadingState titulo="Cargando clientes…" />
          ) : isError ? (
            <ErrorState mensaje={mensajeDeError(error, "la lista de clientes")} onRetry={() => refetch()} />
          ) : filtrados.length === 0 ? (
            <EmptyState
              titulo="Sin clientes"
              descripcion={
                data && data.length > 0
                  ? "Ningun cliente coincide con los filtros aplicados."
                  : "Todavia no hay clientes registrados."
              }
            />
          ) : (
            <>
              <DataTable
                columnas={columnas}
                filas={visibles}
                claveFila={(c) => c.ClienteID}
                caption={`Mostrando ${visibles.length} de ${filtrados.length} clientes`}
                animarFilas
              />
              <div style={{ padding: "16px 24px 24px" }}>
                <Paginacion
                  pagina={paginaActual}
                  totalPaginas={totalPaginas}
                  total={filtrados.length}
                  onCambiar={setPagina}
                />
              </div>
            </>
          )}
        </Card>
      </div>

      <Dialog
        abierto={dialogo.abierto}
        titulo={dialogo.cliente ? "Editar cliente" : "Nuevo cliente"}
        descripcion={
          dialogo.cliente
            ? "Actualiza los datos fiscales y de contacto del cliente."
            : "Registra un cliente con sus datos fiscales y de contacto."
        }
        onCerrar={() => setDialogo({ abierto: false, cliente: null })}
      >
        {errorDialogo ? <Alert tono="danger">{errorDialogo}</Alert> : null}
        <ClienteForm
          cliente={dialogo.cliente}
          guardando={guardando}
          onGuardar={guardar}
          onCancelar={() => setDialogo({ abierto: false, cliente: null })}
        />
      </Dialog>
    </>
  );
}
