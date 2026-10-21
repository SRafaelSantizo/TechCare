import { useState } from "react";
import { Navigate, useLocation } from "react-router-dom";
import { puedeAcceder, useSession } from "../../app/session";
import { NAVEGACION } from "../../app/navigation";
import { LoadingState } from "../ui/StateView";
import { Alert } from "../ui/Alert";
import { NavDrawer } from "./NavDrawer";
import { Header } from "./Header";
import { PageTransition } from "../motion/PageTransition";

export function AppShell() {
  const [navAbierto, setNavAbierto] = useState(false);
  const { pathname } = useLocation();
  const sesion = useSession();
  const entrada = NAVEGACION.flatMap(g => g.items).filter(i => i.ruta !== "/")
    .sort((a, b) => b.ruta.length - a.ruta.length)
    .find(i => pathname === i.ruta || pathname.startsWith(i.ruta + "/"));
  const requiereRol = !!entrada?.roles?.length;
  const esInicio = pathname === "/";

  return (
    <div className="tc-shell">
      <Header navAbierto={navAbierto} onAbrirNav={() => setNavAbierto(true)} />
      <NavDrawer abierto={navAbierto} onCerrar={() => setNavAbierto(false)} />
      <main className={["tc-main", esInicio ? "tc-main--flush" : ""].filter(Boolean).join(" ")} id="contenido">
        <div className={["tc-content", esInicio ? "tc-content--flush" : ""].filter(Boolean).join(" ")}>
          {requiereRol && sesion.cargando ? <LoadingState titulo="Verificando sesión…" />
            : requiereRol && !sesion.autenticado ? <Navigate to="/login" replace state={{ from: pathname }} />
            : requiereRol && !puedeAcceder(sesion, entrada?.roles) ? <Alert tono="danger" titulo="Acceso restringido">Tu usuario no tiene permiso para este módulo.</Alert>
            : <PageTransition />}
        </div>
      </main>
    </div>
  );
}
