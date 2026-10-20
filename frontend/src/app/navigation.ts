import type { LucideIcon } from "lucide-react";
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
} from "lucide-react";

export interface NavItem {
  etiqueta: string;
  ruta: string;
  icono: LucideIcon;
  descripcion?: string;
  roles?: string[];
}

export interface NavGrupo {
  etiqueta: string;
  items: NavItem[];
}

export const NAVEGACION: NavGrupo[] = [
  {
    etiqueta: "Inicio",
    items: [
      { etiqueta: "Inicio", ruta: "/", icono: Home, descripcion: "Presentacion del taller." },
      { etiqueta: "Resumen del taller", ruta: "/resumen", icono: Gauge, descripcion: "Estado operativo del servicio." },
    ],
  },
  {
    etiqueta: "Servicio",
    items: [
      {
        etiqueta: "Órdenes de servicio",
        ruta: "/ordenes",
        icono: ClipboardList,
        descripcion: "Ingresos, diagnostico y reparacion en curso.",
      },
      {
        etiqueta: "Nueva orden",
        ruta: "/ordenes/nueva",
        icono: Wrench,
        descripcion: "Registrar el ingreso de un equipo al taller.",
        roles: ["RECEPCION", "ADMIN"],
      },
      {
        etiqueta: "Clientes",
        ruta: "/clientes",
        icono: Users,
        descripcion: "Datos fiscales y de contacto del cliente.",
        roles: ["RECEPCION", "TECNICO", "CAJA", "ADMIN"],
      },
      {
        etiqueta: "Equipos",
        ruta: "/equipos",
        icono: LayoutGrid,
        descripcion: "Equipos por cliente y su historial de ingresos.",
        roles: ["RECEPCION", "TECNICO", "ADMIN"],
      },
    ],
  },
  {
    etiqueta: "Inventario y compras",
    items: [
      {
        etiqueta: "Inventario",
        ruta: "/inventario",
        icono: Boxes,
        descripcion: "Existencias por bodega y minimos.",
      },
      {
        etiqueta: "Repuestos",
        ruta: "/repuestos",
        icono: Package,
        descripcion: "Catalogo de repuestos y costos vigentes.",
      },
      {
        etiqueta: "Compras",
        ruta: "/compras",
        icono: ShoppingCart,
        descripcion: "Registro y recepcion de compras a proveedores.",
        roles: ["BODEGA", "ADMIN"],
      },
      {
        etiqueta: "Proveedores",
        ruta: "/proveedores",
        icono: Truck,
        descripcion: "Proveedores y repuestos que ofrecen.",
        roles: ["BODEGA", "ADMIN"],
      },
    ],
  },
  {
    etiqueta: "Facturación",
    items: [
      {
        etiqueta: "Facturación y caja",
        ruta: "/facturacion",
        icono: FileText,
        descripcion: "Emision de facturas, pagos y saldos.",
        roles: ["CAJA", "ADMIN"],
      },
    ],
  },
  {
    etiqueta: "Reportes",
    items: [
      {
        etiqueta: "Reportes",
        ruta: "/reportes",
        icono: FileBarChart,
        descripcion: "Doce reportes operativos del taller.",
      },
    ],
  },
  {
    etiqueta: "Administración",
    items: [
      {
        etiqueta: "Administración",
        ruta: "/administracion",
        icono: Settings,
        descripcion: "Usuarios, roles y catalogos del sistema.",
        roles: ["ADMIN"],
      },
      {
        etiqueta: "Integración",
        ruta: "/integracion",
        icono: PackageSearch,
        descripcion: "Estado de cada operacion frente al backend.",
      },
    ],
  },
];

export const GRUPOS_SERVICIOS: NavGrupo[] = NAVEGACION.filter((grupo) => grupo.etiqueta !== "Inicio");

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
