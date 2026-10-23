import { useMemo, useState } from "react";
import { PageHeader, Card } from "../../components/ui/Card";
import { Alert } from "../../components/ui/Alert";
import { DataTable, type Columna } from "../../components/ui/DataTable";
import { EstadoCapacidadBadge } from "../../components/ui/Badge";
import { SelectInput } from "../../components/ui/inputs";
import { Reveal } from "../../components/motion/Reveal";
import { OPERACIONES, type OperacionApi } from "../../app/capabilities";
import { API_BASE_URL } from "../../services/http";

const columnas: Array<Columna<OperacionApi>> = [
  { clave: "modulo", encabezado: "Modulo", render: (o) => o.modulo },
  { clave: "operacion", encabezado: "Operacion de negocio", render: (o) => o.operacion },
  {
    clave: "http",
    encabezado: "Metodo y ruta reales",
    render: (o) => (
      <span className="tc-tabular" style={{ fontSize: 13 }}>
        {o.metodo !== "Sin endpoint" ? <strong>{o.metodo}</strong> : <em>Sin endpoint</em>} {o.ruta}
      </span>
    ),
  },
  { clave: "entrada", encabezado: "Entrada", render: (o) => <span style={{ fontSize: 12 }}>{o.entrada}</span> },
  { clave: "respuesta", encabezado: "Respuesta", render: (o) => <span style={{ fontSize: 12 }}>{o.respuesta}</span> },
  { clave: "roles", encabezado: "Roles autorizados", render: (o) => o.roles },
  {
    clave: "estado",
    encabezado: "Estado de integracion",
    render: (o) => (
      <div className="tc-stack" style={{ gap: 4 }}>
        <EstadoCapacidadBadge estado={o.estado} />
        {o.procedimiento ? <code style={{ fontSize: 11 }}>{o.procedimiento}</code> : null}
      </div>
    ),
  },
];

export function IntegracionPage() {
  const [filtro, setFiltro] = useState("");
  const [modulo, setModulo] = useState("");

  const modulos = useMemo(() => Array.from(new Set(OPERACIONES.map((o) => o.modulo))).sort(), []);

  const filas = OPERACIONES.filter((o) => {
    if (filtro && o.estado !== filtro) return false;
    if (modulo && o.modulo !== modulo) return false;
    return true;
  });

  const resumen = {
    disponible: OPERACIONES.filter((o) => o.estado === "disponible").length,
    incompleta: OPERACIONES.filter((o) => o.estado === "incompleta").length,
    ausente: OPERACIONES.filter((o) => o.estado === "ausente").length,
  };

  return (
    <>
      <PageHeader
        eyebrow="Administracion"
        titulo="Mapa de integracion"
        descripcion="Contraste de cada operacion de negocio contra el backend real del repositorio. Un procedimiento SQL no equivale a una ruta HTTP."
      />

      <div className="tc-stack">
        <Alert tono="info" titulo="Contrato verificado">
          Acceso, administración, clientes, equipos, órdenes, servicio técnico, caja, factura PDF, entrega, abastecimiento, compras, recepción, inventario, kardex y reportes tienen rutas bajo <code>{API_BASE_URL}</code>.
          Las operaciones requieren sesión, rol y protección CSRF al escribir. El servicio técnico valida además
          el responsable asignado. Los errores mantienen la forma <code>{"{ estado, mensaje, errores? }"}</code>.
        </Alert>

        <div className="tc-grid tc-grid--cards">
          <Reveal delay={0}>
            <Card>
              <div className="tc-metric__label">Conectadas</div>
              <div className="tc-metric__value">{resumen.disponible}</div>
            </Card>
          </Reveal>
          <Reveal delay={0.08}>
            <Card>
              <div className="tc-metric__label">Parciales</div>
              <div className="tc-metric__value">{resumen.incompleta}</div>
            </Card>
          </Reveal>
          <Reveal delay={0.16}>
            <Card>
              <div className="tc-metric__label">Pendientes de API</div>
              <div className="tc-metric__value">{resumen.ausente}</div>
            </Card>
          </Reveal>
        </div>

        <Reveal delay={0.08}>
          <Card>
            <div className="tc-row">
              <SelectInput
                aria-label="Filtrar por estado"
                value={filtro}
                onChange={(e) => setFiltro(e.target.value)}
                style={{ width: 220 }}
              >
                <option value="">Todos los estados</option>
                <option value="disponible">Conectadas</option>
                <option value="incompleta">Parciales</option>
                <option value="ausente">Pendientes de API</option>
              </SelectInput>
              <SelectInput
                aria-label="Filtrar por modulo"
                value={modulo}
                onChange={(e) => setModulo(e.target.value)}
                style={{ width: 220 }}
              >
                <option value="">Todos los modulos</option>
                {modulos.map((m) => (
                  <option key={m} value={m}>
                    {m}
                  </option>
                ))}
              </SelectInput>
            </div>
          </Card>
        </Reveal>

        <DataTable
          columnas={columnas}
          filas={filas}
          claveFila={(o) => o.id}
          caption={`${filas.length} operacion(es)`}
        />
      </div>
    </>
  );
}
