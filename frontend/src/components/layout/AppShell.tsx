import { useState } from "react";
import { NavDrawer } from "./NavDrawer";
import { Header } from "./Header";
import { PageTransition } from "../motion/PageTransition";

export function AppShell() {
  const [navAbierto, setNavAbierto] = useState(false);

  return (
    <div className="tc-shell">
      <Header navAbierto={navAbierto} onAbrirNav={() => setNavAbierto(true)} />
      <NavDrawer abierto={navAbierto} onCerrar={() => setNavAbierto(false)} />
      <main className="tc-main" id="contenido">
        <div className="tc-content">
          <PageTransition />
        </div>
      </main>
    </div>
  );
}
