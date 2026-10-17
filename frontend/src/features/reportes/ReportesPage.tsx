import { useState } from "react";
import { Info } from "lucide-react";
import { PageHeader, Card } from "../../components/ui/Card";
import { Badge } from "../../components/ui/Badge";
import { PendingState } from "../../components/ui/StateView";

interface Reporte {
  codigo: string;
  titulo: string;
  filtros: string;
  descripcion: string;
}

const REPORTES: Reporte[] = [
  { codigo: "R01", titulo: "Ordenes activas por estado, prioridad y tecnico", filtros: "estado, tecnico, rango de fechas", descripcion: "Ordenes no finales con su estado, prioridad, cliente, serie y tecnico responsable." },
  { codigo: "R02", titulo: "Historial completo de ordenes de un cliente", filtros: "cliente", descripcion: "Incluye clientes sin ordenes (LEFT JOIN)." },
  { codigo: "R03", titulo: "Historial tecnico por numero de serie", filtros: "serie", descripcion: "Diagnosticos, reparaciones y tecnico por equipo, incluso sin servicio." },
  { codigo: "R04", titulo: "Diagnosticos y reparaciones por tecnico y fechas", filtros: "tecnico, rango de fechas", descripcion: "Union de diagnosticos y reparaciones con mano de obra." },
  { codigo: "R05", titulo: "Repuestos utilizados por orden, tecnico y bodega", filtros: "orden, tecnico, bodega", descripcion: "Costo y venta historicos por consumo." },
  { codigo: "R06", titulo: "Inventario actual por bodega, categoria y repuesto", filtros: "bodega", descripcion: "Existencia calculada del kardex con minimo y precios de referencia." },
  { codigo: "R07", titulo: "Existencias iguales o inferiores al minimo", filtros: "bodega", descripcion: "Alerta de reposicion con faltante para el minimo." },
  { codigo: "R08", titulo: "Compras por proveedor con detalle y costos historicos", filtros: "proveedor, rango de fechas", descripcion: "Lineas de compra con destino y costo por linea." },
  { codigo: "R09", titulo: "Movimientos de inventario con origen y usuario", filtros: "bodega, rango de fechas", descripcion: "Kardex con documento origen, responsable y existencia resultante." },
  { codigo: "R10", titulo: "Facturas con saldo pendiente y detalle de pagos", filtros: "cliente", descripcion: "Una fila por pago; no sumar Total sobre este resultado (usar vFacturaSaldo)." },
  { codigo: "R11", titulo: "Ingresos facturados por periodo", filtros: "cliente, rango de fechas", descripcion: "Mano de obra, repuestos e impuesto por mes (devengado)." },
  { codigo: "R12", titulo: "Trazabilidad completa de una orden", filtros: "orden, cliente", descripcion: "Una fila por orden con colecciones JSON independientes (estados, repuestos/movimientos, pagos)." },
];

export function ReportesPage() {
  const [seleccionado, setSeleccionado] = useState<Reporte>(REPORTES[0]);

  return (
    <>
      <PageHeader
        eyebrow="Reportes"
        titulo="Reportes del taller"
        descripcion="Doce reportes obligatorios. Cada uno exige una consulta del servidor; el navegador no construye JOIN ni agrega sobre listados incompletos."
      />

      <div className="tc-stack">
        <p className="tc-inline-note">
          <Info size={16} aria-hidden="true" />
          Los reportes se generan en el servidor. Mientras no exista esa conexion, la vista queda preparada y sin
          datos.
        </p>

        <div className="tc-split">
          <Card flush>
            <nav aria-label="Lista de reportes">
              <ul style={{ listStyle: "none", margin: 0, padding: 0 }}>
                {REPORTES.map((r) => (
                  <li key={r.codigo}>
                    <button
                      type="button"
                      onClick={() => setSeleccionado(r)}
                      aria-current={r.codigo === seleccionado.codigo}
                      style={{
                        display: "block",
                        width: "100%",
                        textAlign: "left",
                        background: r.codigo === seleccionado.codigo ? "var(--tc-interactive)" : "transparent",
                        border: 0,
                        borderBottom: "1px solid var(--tc-divider)",
                        padding: "14px 20px",
                        cursor: "pointer",
                      }}
                    >
                      <div className="tc-row" style={{ gap: 8 }}>
                        <Badge tono="neutral">{r.codigo}</Badge>
                      </div>
                      <div style={{ fontSize: 13, marginTop: 4 }}>{r.titulo}</div>
                    </button>
                  </li>
                ))}
              </ul>
            </nav>
          </Card>

          <Card>
            <h2 className="tc-section-title">
              {seleccionado.codigo} · {seleccionado.titulo}
            </h2>
            <p className="tc-section-sub">{seleccionado.descripcion}</p>
            <dl className="tc-dl">
              <dt>Filtros</dt>
              <dd>{seleccionado.filtros}</dd>
            </dl>
            <div style={{ marginTop: 12 }}>
              <PendingState
                titulo="Reporte sin datos"
                descripcion="Cuando el servidor entregue el reporte, aqui se mostraran las filas con carga, vacio y error diferenciados."
              />
            </div>
          </Card>
        </div>
      </div>
    </>
  );
}
