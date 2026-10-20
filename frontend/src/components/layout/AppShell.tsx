import { useState } from "react";
import { Navigate, useLocation } from "react-router-dom";
import { puedeAcceder, useSession } from "../../app/session";
import { NAVEGACION } from "../../app/navigation";
import { LoadingState, PermissionState } from "../ui/StateView";
import { NavDrawer } from "./NavDrawer";
import { Header } from "./Header";
import { PageTransition } from "../motion/PageTransition";

export function AppShell() {
  const [navAbierto, setNavAbierto] = useState(false);
  const sesion = useSession();
  const ubicacion = useLocation();
  if (sesion.cargando) return <LoadingState titulo="Verificando sesión…" />;
  if (!sesion.autenticado) return <Navigate to="/login" replace state={{ from: ubicacion.pathname + ubicacion.search }} />;
  const destino = NAVEGACION.flatMap(g => g.items).filter(i => i.ruta !== "/")
    .sort((a, b) => b.ruta.length - a.ruta.length)
    .find(i => ubicacion.pathname === i.ruta || ubicacion.pathname.startsWith(i.ruta + "/"));
  const permitido = puedeAcceder(sesion, destino?.roles);

  return (
    <div className="tc-shell">
      <Header navAbierto={navAbierto} onAbrirNav={() => setNavAbierto(true)} />
      <NavDrawer abierto={navAbierto} onCerrar={() => setNavAbierto(false)} />
      <main className="tc-main" id="contenido">
        <div className="tc-content">
          {permitido ? <PageTransition /> : <PermissionState />}
        </div>
      </main>
    </div>
  );
}
