import { LogOut, Menu } from "lucide-react";
import { useState } from "react";
import { useLocation } from "react-router-dom";
import { contextoDeRuta } from "../../app/navigation";
import { useSession } from "../../app/session";
import { IconButton } from "../ui/Button";
import { Brand } from "./Brand";
import { NAV_DRAWER_ID } from "./NavDrawer";
import { iniciales } from "../../utils/format";

export function Header({ navAbierto, onAbrirNav }: { navAbierto: boolean; onAbrirNav: () => void }) {
  const ubicacion = useLocation();
  const { grupo, etiqueta } = contextoDeRuta(ubicacion.pathname);
  const sesion = useSession();
  const [saliendo, setSaliendo] = useState(false);
  const [errorSalida, setErrorSalida] = useState("");
  async function salir() {
    setSaliendo(true);
    setErrorSalida("");
    try { await sesion.cerrarSesion(); }
    catch { setErrorSalida("No se pudo cerrar sesión. Intentá nuevamente."); }
    finally { setSaliendo(false); }
  }
  const esInicio = ubicacion.pathname === "/";

  return (
    <header className="tc-header">
      <IconButton
        etiqueta="Abrir navegacion"
        className="tc-nav-toggle"
        aria-expanded={navAbierto}
        aria-controls={NAV_DRAWER_ID}
        onClick={onAbrirNav}
      >
        <Menu size={18} />
      </IconButton>

      {esInicio ? (
        <Brand />
      ) : (
        <div className="tc-breadcrumb" aria-label="Ubicacion">
          <span>{grupo}</span>
          <span className="tc-breadcrumb__sep" aria-hidden="true">
            /
          </span>
          <span style={{ color: "var(--tc-text)" }}>{etiqueta}</span>
        </div>
      )}

      <div className="tc-header__spacer" />

      {sesion.autenticado ? (
        <div className="tc-user">
          <span className="tc-user__avatar" aria-hidden="true">
            {iniciales(sesion.usuario?.nombreCompleto)}
          </span>
          <span style={{ fontSize: "var(--tc-fs-meta)" }}>{sesion.usuario?.nombreCompleto}</span>
          {errorSalida ? <span role="alert" className="tc-field__hint">{errorSalida}</span> : null}
          <IconButton etiqueta="Cerrar sesion" disabled={saliendo} onClick={salir}>
            <LogOut size={16} />
          </IconButton>
        </div>
      ) : (
        <span className="tc-session-note">
          <span className="tc-session-note__dot" aria-hidden="true" />
          Sin sesión
        </span>
      )}
    </header>
  );
}
