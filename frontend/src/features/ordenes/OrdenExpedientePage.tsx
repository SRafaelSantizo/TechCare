import { useState } from "react";
import { Link, useParams } from "react-router-dom";
import { ArrowLeft, Info } from "lucide-react";
import { PageHeader, Card } from "../../components/ui/Card";
import { Button } from "../../components/ui/Button";
import { Badge } from "../../components/ui/Badge";
import { PendingState } from "../../components/ui/StateView";

type SeccionId = "recepcion" | "diagnostico" | "reparacion" | "repuestos" | "factura" | "entrega" | "historial";

interface Seccion {
  id: SeccionId;
  titulo: string;
  descripcion: string;
}

const SECCIONES: Seccion[] = [
  {
    id: "recepcion",
    titulo: "Recepcion",
    descripcion: "Ingreso del equipo, problema reportado, prioridad y fecha estimada.",
  },
  {
    id: "diagnostico",
    titulo: "Diagnostico",
    descripcion: "Diagnostico de la orden: tecnico, fecha, descripcion y costo estimado.",
  },
  {
    id: "reparacion",
    titulo: "Reparacion",
    descripcion: "Trabajo realizado, actividades, costo de mano de obra y estado de la reparacion.",
  },
  {
    id: "repuestos",
    titulo: "Repuestos",
    descripcion: "Repuestos consumidos con bodega, cantidad y precios historicos.",
  },
  {
    id: "factura",
    titulo: "Factura y pagos",
    descripcion: "Cero o una factura por orden, con mano de obra, repuestos, impuesto, pagado y saldo.",
  },
  {
    id: "entrega",
    titulo: "Entrega",
    descripcion: "Cierre con receptor, documento y observaciones, cuando la orden esta lista.",
  },
  {
    id: "historial",
    titulo: "Historial",
    descripcion: "Eventos de la orden con fecha, usuario y observacion.",
  },
];

const ACCIONES = [
  "Registrar diagnostico",
  "Iniciar reparacion",
  "Registrar actividad",
  "Consumir repuesto",
  "Finalizar reparacion",
  "Emitir factura",
  "Registrar pago",
  "Registrar entrega",
];

export function OrdenExpedientePage() {
  const { id } = useParams();
  const [seccion, setSeccion] = useState<SeccionId>("recepcion");
  const actual = SECCIONES.find((s) => s.id === seccion)!;

  return (
    <>
      <PageHeader
        eyebrow="Servicio / Ordenes / Expediente"
        titulo={`Orden #${id ?? "—"}`}
        descripcion="Recorrido completo del servicio en una sola pantalla."
        acciones={
          <Link to="/ordenes">
            <Button variante="fantasma" icono={<ArrowLeft size={16} />}>
              Volver
            </Button>
          </Link>
        }
      />

      <div className="tc-stack">
        <p className="tc-inline-note">
          <Info size={16} aria-hidden="true" />
          El expediente completo (numero, estado, cliente, equipo, fechas y responsable) se mostrara cuando el
          servidor exponga el detalle de la orden. Abrir esta pantalla no cambia ningun estado.
        </p>

        <Card>
          <h2 className="tc-section-title">Cabecera de la orden</h2>
          <dl className="tc-dl">
            <dt>Numero de orden</dt>
            <dd>{id ?? "—"}</dd>
            <dt>Estado</dt>
            <dd>
              <Badge tono="neutral">En preparacion</Badge>
            </dd>
            <dt>Prioridad</dt>
            <dd className="tc-field__hint">En preparacion</dd>
            <dt>Cliente / Equipo</dt>
            <dd className="tc-field__hint">El cliente se toma del equipo de la orden.</dd>
            <dt>Tecnico responsable</dt>
            <dd className="tc-field__hint">Sin asignar mientras no haya responsable.</dd>
          </dl>
        </Card>

        <div>
          <div className="tc-row" role="tablist" aria-label="Secciones del expediente">
            {SECCIONES.map((s) => (
              <button
                key={s.id}
                role="tab"
                type="button"
                aria-selected={s.id === seccion}
                className="tc-btn tc-btn--sm"
                style={s.id === seccion ? { background: "var(--tc-interactive)" } : { background: "transparent" }}
                onClick={() => setSeccion(s.id)}
              >
                {s.titulo}
              </button>
            ))}
          </div>

          <Card className="tc-stack">
            <div role="tabpanel" aria-label={actual.titulo}>
              <h2 className="tc-section-title">{actual.titulo}</h2>
              <p className="tc-section-sub">{actual.descripcion}</p>
              <PendingState
                titulo="Todavia no disponible"
                descripcion="La ausencia de datos en esta seccion es una situacion valida (por ejemplo, una orden sin diagnostico) y se distingue de un error de consulta."
              />
            </div>
          </Card>
        </div>

        <Card>
          <h2 className="tc-section-title">Acciones segun rol y estado</h2>
          <p className="tc-section-sub">
            Cada accion se habilita cuando existe la conexion con el servidor y el estado de la orden lo permite.
            Mientras tanto permanecen bloqueadas; la interfaz no cambia estados por si sola.
          </p>
          <div className="tc-row">
            {ACCIONES.map((etiqueta) => (
              <Button key={etiqueta} disabled title="Se habilita cuando exista la conexion con el servidor">
                {etiqueta}
              </Button>
            ))}
          </div>
        </Card>
      </div>
    </>
  );
}
