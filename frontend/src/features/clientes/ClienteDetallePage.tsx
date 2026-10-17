import { useState } from "react";
import { Link, useParams } from "react-router-dom";
import { ArrowLeft, Pencil } from "lucide-react";
import { PageHeader, Card } from "../../components/ui/Card";
import { Button } from "../../components/ui/Button";
import { Badge } from "../../components/ui/Badge";
import { Alert } from "../../components/ui/Alert";
import { Dialog } from "../../components/ui/Dialog";
import { ErrorState, LoadingState, PendingState } from "../../components/ui/StateView";
import { Reveal } from "../../components/motion/Reveal";
import { ClienteForm } from "./ClienteForm";
import { useActualizarCliente, useCliente } from "./hooks";
import { nombreTipoCliente } from "../../services/catalogos";
import { mensajeDeError } from "../../services/errors";
import { texto } from "../../utils/format";
import type { ClienteDatos } from "../../types/api";

export function ClienteDetallePage() {
  const { id } = useParams();
  const clienteId = Number(id);
  const { data, isLoading, isError, error, refetch } = useCliente(Number.isNaN(clienteId) ? null : clienteId);
  const actualizar = useActualizarCliente();
  const [editando, setEditando] = useState(false);
  const [ok, setOk] = useState<string | null>(null);

  if (isLoading) return <LoadingState titulo="Cargando cliente…" />;
  if (isError) return <ErrorState mensaje={mensajeDeError(error, "el cliente")} onRetry={() => refetch()} />;
  if (!data) return <ErrorState titulo="Cliente no encontrado" mensaje="El cliente solicitado no existe." />;

  async function guardar(datos: ClienteDatos) {
    await actualizar.mutateAsync({ id: data!.ClienteID, datos });
    setEditando(false);
    setOk("Cliente actualizado.");
  }

  return (
    <>
      <PageHeader
        eyebrow="Servicio / Clientes"
        titulo={data.Nombre}
        descripcion={
          <span className="tc-row" style={{ gap: 8 }}>
            <Badge tono={data.Activo ? "ok" : "neutral"}>{data.Activo ? "Activo" : "Inactivo"}</Badge>
            <span>{nombreTipoCliente(data.TipoClienteID)}</span>
          </span>
        }
        acciones={
          <>
            <Link to="/clientes">
              <Button variante="fantasma" icono={<ArrowLeft size={16} />}>
                Volver
              </Button>
            </Link>
            <Button variante="primario" icono={<Pencil size={16} />} onClick={() => setEditando(true)}>
              Editar
            </Button>
          </>
        }
      />

      <div className="tc-stack">
        {ok ? <Alert tono="ok">{ok}</Alert> : null}

        <Reveal>
          <Card>
            <h2 className="tc-section-title">Datos del cliente</h2>
            <dl className="tc-dl">
              <dt>NIT</dt>
              <dd className="tc-tabular">{data.NIT}</dd>
              <dt>Nombre</dt>
              <dd>{data.Nombre}</dd>
              <dt>Correo</dt>
              <dd>{texto(data.Email)}</dd>
              <dt>Telefono</dt>
              <dd>{texto(data.Telefono)}</dd>
              <dt>Direccion</dt>
              <dd>{texto(data.Direccion)}</dd>
            </dl>
          </Card>
        </Reveal>

        <Reveal delay={0.08}>
          <Card>
            <h2 className="tc-section-title">Equipos del cliente</h2>
            <PendingState
              titulo="Equipos en preparacion"
              descripcion="Los equipos del cliente se mostraran cuando el servidor exponga su catalogo. No se inventan resultados."
            />
          </Card>
        </Reveal>

        <Reveal delay={0.16}>
          <Card>
            <h2 className="tc-section-title">Historial de ordenes</h2>
            <PendingState
              titulo="Historial en preparacion"
              descripcion="El historial de ordenes del cliente se mostrara cuando el servidor exponga los reportes."
            />
          </Card>
        </Reveal>
      </div>

      <Dialog
        abierto={editando}
        titulo="Editar cliente"
        descripcion="Actualiza los datos fiscales y de contacto del cliente."
        onCerrar={() => setEditando(false)}
      >
        <ClienteForm
          cliente={data}
          guardando={actualizar.isPending}
          onGuardar={guardar}
          onCancelar={() => setEditando(false)}
        />
      </Dialog>
    </>
  );
}
