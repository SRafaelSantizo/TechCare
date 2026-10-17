import {
  Boxes,
  ClipboardList,
  FileBarChart,
  FileText,
  Gauge,
  Home,
  LayoutGrid,
  Package,
  PackageSearch,
  Settings,
  ShoppingCart,
  Truck,
  Users,
  Wrench,
  type LucideIcon,
} from "lucide-react";

export interface NavItem {
  etiqueta: string;
  ruta: string;
  icono: LucideIcon;
  /** Roles de la consigna. La guarda final la aplica el servidor. */
  roles?: string[];
}

export interface NavGrupo {
  etiqueta: string;
  items: NavItem[];
}

/** Grupos de navegacion (barra lateral). Las rutas son del frontend. */
export const NAVEGACION: NavGrupo[] = [
  {
    etiqueta: "Inicio",
    items: [
      { etiqueta: "Inicio", ruta: "/", icono: Home },
      { etiqueta: "Resumen del taller", ruta: "/resumen", icono: Gauge },
    ],
  },
  {
    etiqueta: "Servicio",
    items: [
      { etiqueta: "Ordenes", ruta: "/ordenes", icono: ClipboardList },
      { etiqueta: "Nueva orden", ruta: "/ordenes/nueva", icono: Wrench, roles: ["RECEPCION", "ADMIN"] },
      { etiqueta: "Clientes", ruta: "/clientes", icono: Users },
      { etiqueta: "Equipos", ruta: "/equipos", icono: LayoutGrid },
    ],
  },
  {
    etiqueta: "Inventario y compras",
    items: [
      { etiqueta: "Inventario", ruta: "/inventario", icono: Boxes },
      { etiqueta: "Repuestos", ruta: "/repuestos", icono: Package },
      { etiqueta: "Compras", ruta: "/compras", icono: ShoppingCart, roles: ["BODEGA", "ADMIN"] },
      { etiqueta: "Proveedores", ruta: "/proveedores", icono: Truck, roles: ["BODEGA", "ADMIN"] },
    ],
  },
  {
    etiqueta: "Facturacion",
    items: [{ etiqueta: "Caja", ruta: "/facturacion", icono: FileText, roles: ["CAJA", "ADMIN"] }],
  },
  {
    etiqueta: "Reportes",
    items: [{ etiqueta: "Reportes", ruta: "/reportes", icono: FileBarChart }],
  },
  {
    etiqueta: "Administracion",
    items: [
      { etiqueta: "Administracion", ruta: "/administracion", icono: Settings, roles: ["ADMIN"] },
      { etiqueta: "Integracion", ruta: "/integracion", icono: PackageSearch },
    ],
  },
];

/** Mapa ruta -> { titulo, grupo } para la cabecera de contexto. */
export function contextoDeRuta(pathname: string): { grupo: string; etiqueta: string } {
  if (pathname === "/") return { grupo: "TechCare", etiqueta: "Inicio" };
  for (const grupo of NAVEGACION) {
    for (const item of grupo.items) {
      if (item.ruta === "/") continue;
      if (pathname === item.ruta || pathname.startsWith(item.ruta + "/")) {
        return { grupo: grupo.etiqueta, etiqueta: item.etiqueta };
      }
    }
  }
  if (pathname.startsWith("/ordenes/")) return { grupo: "Servicio", etiqueta: "Expediente" };
  return { grupo: "TechCare", etiqueta: "Inicio" };
}
