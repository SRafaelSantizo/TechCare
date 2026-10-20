import { useState } from "react";

import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { Check, Info } from "lucide-react";
import { PageHeader, Card } from "../../components/ui/Card";
import { Button } from "../../components/ui/Button";
import { Alert } from "../../components/ui/Alert";
import { SearchInput, SelectInput, TextArea, Field } from "../../components/ui/inputs";
import { Badge } from "../../components/ui/Badge";
import { EmptyState, LoadingState, PendingState } from "../../components/ui/StateView";
import { useClientes } from "../clientes/hooks";
import { PRIORIDADES, nombreTipoCliente } from "../../services/catalogos";
import { mensajeDeError } from "../../services/errors";
import { normalizar } from "../../utils/format";
import type { Cliente } from "../../types/api";
import { equiposApi } from "../../services/equipos";

const PASOS = ["Cliente", "Equipo", "Problema", "Confirmar"] as const;

/**
 * Flujo guiado de recepcion de un equipo.
 *
 * Cliente y Equipo consultan sus APIs reales. Confirmar el ingreso requiere
 * POST /api/ordenes; permanece deshabilitado hasta integrar ese endpoint.
 */
export function OrdenNuevaPage() {
  const [paso, setPaso] = useState(0);
  const [clienteSeleccionado, setClienteSeleccionado] = useState<Cliente | null>(null);
  const { data, isLoading, isError, error, refetch } = useClientes();
  const [busqueda, setBusqueda] = useState("");
  const [equipoId, setEquipoId] = useState("");
  const equipos = useQuery({
    queryKey: ["equipos", "cliente", clienteSeleccionado?.ClienteID],
    queryFn: ({ signal }) => equiposApi.listar(clienteSeleccionado!.ClienteID, signal),
    enabled: clienteSeleccionado !== null,
  });

  const filtrados = (data ?? []).filter((c) => {
    const q = normalizar(busqueda);
    if (!q) return true;
    return normalizar(c.Nombre).includes(q) || normalizar(c.NIT).includes(q);
  });

  return (
    <>
      <PageHeader
        eyebrow="Servicio / Ordenes"
        titulo="Nueva orden de servicio"
        descripcion="Buscar o registrar el cliente, elegir su equipo y capturar el problema reportado antes de confirmar el ingreso."
      />

      <div className="tc-stack">
        <nav aria-label="Pasos de la recepcion" className="tc-row" style={{ gap: 8 }}>
          {PASOS.map((nombre, i) => {
            const activo = i === paso;
            const completado = i < paso;
            return (
              <div key={nombre} className="tc-row" style={{ gap: 8 }}>
                <Badge tono={activo ? "info" : completado ? "ok" : "neutral"}>
                  {completado ? <Check size={13} /> : null} {i + 1}. {nombre}
                </Badge>
                {i < PASOS.length - 1 ? <span aria-hidden="true" className="tc-field__hint">Ã¢â‚¬Âº</span> : null}
              </div>
            );
          })}
        </nav>

        {paso === 0 ? (
          <Card>
            <h2 className="tc-section-title">Paso 1 Ã‚Â· Cliente</h2>
            <p className="tc-section-sub">
              BuscÃƒÂ¡ el cliente que entrega el equipo. Si todavia no existe, registralo en el modulo de Clientes.
            </p>
            <SearchInput
              placeholder="Buscar por nombre o NIT"
              aria-label="Buscar cliente"
              value={busqueda}
              onChange={(e) => setBusqueda(e.target.value)}
            />
            <div style={{ marginTop: 16 }}>
              {isLoading ? (
                <LoadingState titulo="Cargando clientesÃ¢â‚¬Â¦" />
              ) : isError ? (
                <Alert tono="danger" titulo="No se pudo cargar clientes" accion={<Button onClick={() => refetch()}>Reintentar</Button>}>
                  {mensajeDeError(error, "la lista de clientes")}
                </Alert>
              ) : filtrados.length === 0 ? (
                <EmptyState titulo="Sin coincidencias" descripcion="Proba otro termino o registra un cliente nuevo." />
              ) : (
                <ul style={{ listStyle: "none", padding: 0, margin: 0 }}>
                  {filtrados.slice(0, 8).map((c) => (
                    <li
                      key={c.ClienteID}
                      className="tc-row"
                      style={{ justifyContent: "space-between", padding: "10px 0", borderBottom: "1px solid var(--tc-divider)" }}
                    >
                      <span>
                        <strong style={{ fontWeight: 500 }}>{c.Nombre}</strong>
                        <div className="tc-field__hint">
                          {nombreTipoCliente(c.TipoClienteID)} Ã‚Â· NIT {c.NIT} {c.Activo ? "" : "Ã‚Â· inactivo"}
                        </div>
                      </span>
                      <Button
                        tamano="sm"
                        variante={clienteSeleccionado?.ClienteID === c.ClienteID ? "primario" : "secundario"}
                        onClick={() => { setClienteSeleccionado(c); setEquipoId(""); }}
                        disabled={!c.Activo}
                      >
                        {clienteSeleccionado?.ClienteID === c.ClienteID ? "Seleccionado" : "Elegir"}
                      </Button>
                    </li>
                  ))}
                </ul>
              )}
            </div>
            <div className="tc-row tc-row--end" style={{ marginTop: 16 }}>
              <Link to="/clientes">
                <Button variante="fantasma">Registrar cliente nuevo</Button>
              </Link>
              <Button variante="primario" disabled={!clienteSeleccionado} onClick={() => setPaso(1)}>
                Continuar con el equipo
              </Button>
            </div>
          </Card>
        ) : null}

        {paso === 1 ? (
          <Card>
            <h2 className="tc-section-title">Paso 2 Ã‚Â· Equipo</h2>
            <div className="tc-row" style={{ justifyContent: "space-between", marginBottom: 12 }}>
              <span className="tc-field__hint">
                Cliente: <strong style={{ color: "var(--tc-text)" }}>{clienteSeleccionado?.Nombre}</strong>
              </span>
              <Button tamano="sm" variante="fantasma" onClick={() => setPaso(0)}>
                Cambiar
              </Button>
            </div>
            {equipos.isLoading ? <LoadingState titulo="Cargando equiposâ€¦" /> : equipos.isError ? (
              <Alert tono="danger" accion={<Button onClick={() => equipos.refetch()}>Reintentar</Button>}>{mensajeDeError(equipos.error)}</Alert>
            ) : (
              <Field label="Equipo del cliente" htmlFor="nueva-equipo" requerido>
                <SelectInput id="nueva-equipo" value={equipoId} onChange={(e: any) => setEquipoId(e.target.value)}>
                  <option value="">Elegir equipo</option>
                  {equipos.data?.filter((e: any) => e.Activo).map((e: any) => <option key={e.EquipoID} value={e.EquipoID}>{e.NumeroSerie} Â· {e.Marca} {e.Modelo}</option>)}
                </SelectInput>
              </Field>
            )}
            <Link to={`/equipos?clienteId=${clienteSeleccionado?.ClienteID}`}><Button variante="fantasma">Registrar o consultar equipos</Button></Link>
            <div className="tc-row tc-row--end">
              <Button disabled={!equipoId || equipos.isError} onClick={() => setPaso(2)}>Continuar</Button>
            </div>
          </Card>
        ) : null}

        {paso === 2 ? (
          <Card>
            <h2 className="tc-section-title">Paso 3 Ã‚Â· Problema reportado</h2>
            <div className="tc-stack">
              <Field label="Problema reportado" htmlFor="nueva-problema" requerido hint="Obligatorio (CK_Orden_Problema).">
                <TextArea id="nueva-problema" rows={4} placeholder="Describi la falla tal como la reporta el cliente." />
              </Field>
              <div className="tc-grid tc-grid--2">
                <Field label="Prioridad" htmlFor="nueva-prioridad">
                  <SelectInput id="nueva-prioridad" defaultValue="NORMAL">
                    {PRIORIDADES.map((p) => (
                      <option key={p.codigo} value={p.codigo}>
                        {p.nombre}
                      </option>
                    ))}
                  </SelectInput>
                </Field>
                <Field label="Fecha estimada (opcional)" htmlFor="nueva-fecha">
                  <input id="nueva-fecha" type="datetime-local" className="tc-input" />
                </Field>
              </div>
              <Field label="Observaciones" htmlFor="nueva-obs">
                <TextArea id="nueva-obs" rows={2} />
              </Field>
            </div>
            <div className="tc-row tc-row--end" style={{ marginTop: 16 }}>
              <Button variante="fantasma" onClick={() => setPaso(1)}>
                Atras
              </Button>
              <Button variante="primario" disabled>
                Revisar
              </Button>
            </div>
            <PendingState titulo="CreaciÃ³n de la orden pendiente" descripcion="La selecciÃ³n del cliente y del equipo estÃ¡ disponible. Falta conectar la confirmaciÃ³n del ingreso con el registro de Ã³rdenes." />
          </Card>
        ) : null}

        {paso === 3 ? (
          <Card>
            <h2 className="tc-section-title">Paso 4 Ã‚Â· Confirmar ingreso</h2>
            <p className="tc-inline-note">
              <Info size={16} aria-hidden="true" />
              La confirmacion del ingreso todavia no esta disponible: el servidor debe crear la orden y asignar su
              numero. Cuando exista, aparecera aqui con validacion y manejo de duplicados.
            </p>
          </Card>
        ) : null}
      </div>
    </>
  );
}
