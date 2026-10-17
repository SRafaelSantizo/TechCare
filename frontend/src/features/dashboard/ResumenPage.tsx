import { Link } from "react-router-dom";
import { Info } from "lucide-react";
import { Card, PageHeader } from "../../components/ui/Card";
import { Reveal } from "../../components/motion/Reveal";
import { useSession } from "../../app/session";
import { useClientes } from "../clientes/hooks";
import { nombreTipoCliente } from "../../services/catalogos";
import { mensajeDeError } from "../../services/errors";

/** Las seis metricas obligatorias del taller. El servidor debe calcularlas. */
const INDICADORES = [
  { clave: "ordenes", etiqueta: "Ordenes abiertas" },
  { clave: "diagnostico", etiqueta: "En diagnostico" },
  { clave: "reparacion", etiqueta: "En reparacion" },
  { clave: "listas", etiqueta: "Listas para entregar" },
  { clave: "facturas", etiqueta: "Facturas con saldo" },
  { clave: "stock", etiqueta: "Repuestos en minimo o por debajo" },
];

export function ResumenPage() {
  const sesion = useSession();

  return (
    <>
      <PageHeader
        eyebrow="Inicio"
        titulo="Resumen del taller"
        descripcion="El estado operativo del servicio en un solo lugar: ordenes, clientes, inventario y facturacion."
      />

      <div className="tc-stack">
        <Reveal>
          <section>
            <h2 className="tc-section-title">Resumen del servicio</h2>
            <Card>
              <div className="tc-metrics">
                {INDICADORES.map((m) => (
                  <div className="tc-metric" key={m.clave}>
                    <div className="tc-metric__label">{m.etiqueta}</div>
                    <div className="tc-metric__value" aria-hidden="true">
                      —
                    </div>
                  </div>
                ))}
              </div>
              <p className="tc-inline-note" style={{ marginTop: 28 }}>
                <Info size={16} aria-hidden="true" />
                El resumen de servicios todavia no esta disponible. Se completara cuando esten listas las metricas del
                taller; mientras tanto no se muestra ningun valor calculado ni cero como dato.
              </p>
            </Card>
          </section>
        </Reveal>

        <div className="tc-grid tc-grid--2">
          <Reveal delay={0.08}>
            <BlockClientes />
          </Reveal>
          <Reveal delay={0.16}>
            <BlockActividad />
          </Reveal>
        </div>

        <section className="tc-grid tc-grid--3">
          <Reveal delay={0.08}>
            <Card>
              <h2 className="tc-section-title">Ordenes y equipos</h2>
              <p className="tc-section-sub" style={{ marginBottom: 0 }}>
                Ingresos, diagnosticos y reparaciones del taller.
              </p>
            </Card>
          </Reveal>
          <Reveal delay={0.16}>
            <Card>
              <h2 className="tc-section-title">Inventario y compras</h2>
              <p className="tc-section-sub" style={{ marginBottom: 0 }}>
                Existencias por bodega, repuestos y abastecimiento.
              </p>
            </Card>
          </Reveal>
          <Reveal delay={0.24}>
            <Card>
              <h2 className="tc-section-title">Facturacion y caja</h2>
              <p className="tc-section-sub" style={{ marginBottom: 0 }}>
                Emision de facturas, pagos y saldos pendientes.
              </p>
            </Card>
          </Reveal>
        </section>

        {!sesion.autenticado ? (
          <Reveal delay={0.08}>
            <p className="tc-inline-note">
              <Info size={16} aria-hidden="true" />
              Acceso del personal en preparacion. La sesion y los permisos por rol se habilitaran cuando exista el
              servicio de autenticacion.
            </p>
          </Reveal>
        ) : null}
      </div>
    </>
  );
}

function BlockClientes() {
  const { data, isLoading, isError, error, refetch } = useClientes();
  const total = data?.length ?? 0;
  const seleccion = data?.slice(0, 5) ?? [];

  return (
    <Card>
      <div className="tc-row" style={{ justifyContent: "space-between", alignItems: "baseline" }}>
        <h2 className="tc-section-title" style={{ marginBottom: 0 }}>
          Clientes
        </h2>
        <Link to="/clientes" className="tc-link-accent" style={{ fontSize: "var(--tc-fs-sm)" }}>
          Ver todos
        </Link>
      </div>

      {isLoading ? (
        <p className="tc-inline-note" style={{ marginTop: 20 }}>
          Cargando clientes…
        </p>
      ) : isError ? (
        <div className="tc-inline-note" style={{ marginTop: 20 }}>
          <Info size={16} aria-hidden="true" />
          <span>
            {mensajeDeError(error, "los clientes")}{" "}
            <button type="button" className="tc-link-accent" onClick={() => refetch()}>
              Reintentar
            </button>
          </span>
        </div>
      ) : total === 0 ? (
        <p className="tc-inline-note" style={{ marginTop: 20 }}>
          Todavia no hay clientes registrados.
        </p>
      ) : (
        <>
          <div className="tc-metric" style={{ marginTop: 20 }}>
            <div className="tc-metric__value">{total}</div>
            <div className="tc-metric__label">clientes registrados</div>
          </div>
          <ul className="tc-mini-list" style={{ marginTop: 8 }}>
            {seleccion.map((c) => (
              <li key={c.ClienteID}>
                <Link to={`/clientes/${c.ClienteID}`}>
                  <span>{c.Nombre}</span>
                  <span className="tc-mini-list__meta">{nombreTipoCliente(c.TipoClienteID)}</span>
                </Link>
              </li>
            ))}
          </ul>
        </>
      )}
    </Card>
  );
}

function BlockActividad() {
  return (
    <Card>
      <h2 className="tc-section-title">Actividad reciente</h2>
      <p className="tc-inline-note">
        <Info size={16} aria-hidden="true" />
        Todavia sin conexion a la historia de movimientos. Aqui apareceran los cambios de estado de las ordenes con
        su fecha y responsable.
      </p>
    </Card>
  );
}
