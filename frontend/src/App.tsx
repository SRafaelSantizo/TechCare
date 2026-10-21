import { lazy, Suspense } from "react";
import { Navigate, Route, Routes } from "react-router-dom";
import { LoadingState } from "./components/ui/StateView";
import { AppShell } from "./components/layout/AppShell";
import { HomePage } from "./features/home/HomePage";
import { ResumenPage } from "./features/dashboard/ResumenPage";
import { ClientesListPage } from "./features/clientes/ClientesListPage";
import { ClienteDetallePage } from "./features/clientes/ClienteDetallePage";
import { EquiposPage } from "./features/equipos/EquiposPage";
import { OrdenesListPage } from "./features/ordenes/OrdenesListPage";
import { OrdenNuevaPage } from "./features/ordenes/OrdenNuevaPage";
import { OrdenExpedientePage } from "./features/ordenes/OrdenExpedientePage";
import { InventarioPage } from "./features/inventario/InventarioPage";

import { ReportesPage } from "./features/reportes/ReportesPage";
import { AdministracionPage } from "./features/administracion/AdministracionPage";
import { IntegracionPage } from "./features/integracion/IntegracionPage";
import { LoginPage } from "./features/auth/LoginPage";

const ComprasPage = lazy(() => import("./features/compras/ComprasPage").then(m => ({ default: m.ComprasPage })));
const CompraDetallePage = lazy(() => import("./features/compras/CompraDetallePage").then(m => ({ default: m.CompraDetallePage })));

const FacturacionPage = lazy(() => import("./features/facturacion/FacturacionPage").then(m => ({ default: m.FacturacionPage })));

const RepuestosPage = lazy(() => import("./features/repuestos/RepuestosPage").then(m => ({ default: m.RepuestosPage })));
const ProveedoresPage = lazy(() => import("./features/proveedores/ProveedoresPage").then(m => ({ default: m.ProveedoresPage })));
const BodegasPage = lazy(() => import("./features/bodegas/BodegasPage").then(m => ({ default: m.BodegasPage })));

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />

      <Route element={<AppShell />}>
        <Route path="/" element={<HomePage />} />
        <Route path="/resumen" element={<ResumenPage />} />
        <Route path="/dashboard" element={<Navigate to="/" replace />} />

        <Route path="/ordenes" element={<OrdenesListPage />} />
        <Route path="/ordenes/nueva" element={<OrdenNuevaPage />} />
        <Route path="/ordenes/:id" element={<OrdenExpedientePage />} />

        <Route path="/clientes" element={<ClientesListPage />} />
        <Route path="/clientes/:id" element={<ClienteDetallePage />} />

        <Route path="/equipos" element={<EquiposPage />} />

        <Route path="/inventario" element={<InventarioPage />} />
        <Route path="/repuestos" element={<Suspense fallback={<LoadingState titulo="Cargando repuestos…" />}><RepuestosPage /></Suspense>} />
        <Route path="/bodegas" element={<Suspense fallback={<LoadingState titulo="Cargando bodegas…" />}><BodegasPage /></Suspense>} />
        <Route path="/compras" element={<Suspense fallback={<LoadingState titulo="Cargando compras…" />}><ComprasPage /></Suspense>} />
        <Route path="/compras/:id" element={<Suspense fallback={<LoadingState titulo="Cargando compra…" />}><CompraDetallePage /></Suspense>} />
        <Route path="/proveedores" element={<Suspense fallback={<LoadingState titulo="Cargando proveedores…" />}><ProveedoresPage /></Suspense>} />

        <Route path="/facturacion" element={<Suspense fallback={<LoadingState titulo="Cargando caja…" />}><FacturacionPage /></Suspense>} />

        <Route path="/reportes" element={<ReportesPage />} />

        <Route path="/administracion" element={<AdministracionPage />} />
        <Route path="/integracion" element={<IntegracionPage />} />

        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}
