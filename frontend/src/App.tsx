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
import { RepuestosPage } from "./features/repuestos/RepuestosPage";
import { ComprasPage } from "./features/compras/ComprasPage";
import { ProveedoresPage } from "./features/proveedores/ProveedoresPage";
import { ReportesPage } from "./features/reportes/ReportesPage";
import { AdministracionPage } from "./features/administracion/AdministracionPage";
import { IntegracionPage } from "./features/integracion/IntegracionPage";
import { LoginPage } from "./features/auth/LoginPage";

const FacturacionPage = lazy(() => import("./features/facturacion/FacturacionPage").then(m => ({ default: m.FacturacionPage })));

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
        <Route path="/repuestos" element={<RepuestosPage />} />
        <Route path="/compras" element={<ComprasPage />} />
        <Route path="/proveedores" element={<ProveedoresPage />} />

        <Route path="/facturacion" element={<Suspense fallback={<LoadingState titulo="Cargando caja…" />}><FacturacionPage /></Suspense>} />

        <Route path="/reportes" element={<ReportesPage />} />

        <Route path="/administracion" element={<AdministracionPage />} />
        <Route path="/integracion" element={<IntegracionPage />} />

        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}
