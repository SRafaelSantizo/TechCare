import { useState } from "react";
import { useLocation } from "react-router-dom";
import { NavDrawer } from "./NavDrawer";
import { Header } from "./Header";
import { PageTransition } from "../motion/PageTransition";

export function AppShell() {
  const [navAbierto, setNavAbierto] = useState(false);
  const { pathname } = useLocation();
  const esInicio = pathname === "/";

  return (
    <div className="tc-shell">
      <Header navAbierto={navAbierto} onAbrirNav={() => setNavAbierto(true)} />
      <NavDrawer abierto={navAbierto} onCerrar={() => setNavAbierto(false)} />
      <main className={["tc-main", esInicio ? "tc-main--flush" : ""].filter(Boolean).join(" ")} id="contenido">
        <div className={["tc-content", esInicio ? "tc-content--flush" : ""].filter(Boolean).join(" ")}>
          <PageTransition />
        </div>
      </main>
    </div>
  );
}
