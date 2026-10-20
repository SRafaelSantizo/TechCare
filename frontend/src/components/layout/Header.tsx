import { LogOut, Menu } from "lucide-react";
import { NavLink, useLocation } from "react-router-dom";
import { motion, useReducedMotion } from "motion/react";
import { contextoDeRuta } from "../../app/navigation";
import { useSession } from "../../app/session";
import { IconButton } from "../ui/Button";
import { Brand } from "./Brand";
import { ServicesMenu } from "./ServicesMenu";
import { NAV_DRAWER_ID } from "./NavDrawer";
import { iniciales } from "../../utils/format";
import { EASE_OUT } from "../motion/motionConfig";

function claseNav({ isActive }: { isActive: boolean }): string {
  return ["tc-navbar__link", isActive ? "is-active" : ""].filter(Boolean).join(" ");
}

export function Header({ navAbierto, onAbrirNav }: { navAbierto: boolean; onAbrirNav: () => void }) {
  const ubicacion = useLocation();
  const { grupo, etiqueta } = contextoDeRuta(ubicacion.pathname);
  const sesion = useSession();
  const esInicio = ubicacion.pathname === "/";
  const reduce = useReducedMotion();

  return (
    <header className="tc-header">
      <IconButton
        etiqueta="Abrir navegación"
        className="tc-nav-toggle"
        aria-expanded={navAbierto}
        aria-controls={NAV_DRAWER_ID}
        onClick={onAbrirNav}
      >
        <Menu size={18} />
      </IconButton>

      <Brand />

      <nav className="tc-navbar" aria-label="Navegación principal">
        {reduce ? (
          <>
            <NavLink to="/" end className={claseNav}>
              Inicio
            </NavLink>
            <ServicesMenu />
            <NavLink to="/resumen" className={claseNav}>
              Resumen del taller
            </NavLink>
          </>
        ) : (
          <>
            <motion.div whileHover={{ y: -1 }} whileTap={{ scale: 0.995 }} transition={{ duration: 0.14, ease: EASE_OUT }}>
              <NavLink to="/" end className={claseNav}>
                Inicio
              </NavLink>
            </motion.div>
            <ServicesMenu />
            <motion.div whileHover={{ y: -1 }} whileTap={{ scale: 0.995 }} transition={{ duration: 0.14, ease: EASE_OUT }}>
              <NavLink to="/resumen" className={claseNav}>
                Resumen del taller
              </NavLink>
            </motion.div>
          </>
        )}
      </nav>

      <div className="tc-header__spacer" />

      {!esInicio ? (
        <div className="tc-breadcrumb tc-header__context" aria-label="Ubicación">
          <span>{grupo}</span>
          <span className="tc-breadcrumb__sep" aria-hidden="true">
            /
          </span>
          <span style={{ color: "var(--tc-text)" }}>{etiqueta}</span>
        </div>
      ) : null}

      {sesion.autenticado && sesion.usuario ? (
        <div className="tc-user">
          <span className="tc-user__avatar" aria-hidden="true">
            {iniciales(sesion.usuario.nombreCompleto)}
          </span>
          <span style={{ fontSize: "var(--tc-fs-meta)" }}>{sesion.usuario.nombreCompleto}</span>
          <IconButton etiqueta="Cerrar sesión" onClick={() => void sesion.cerrarSesion()}>
            <LogOut size={16} />
          </IconButton>
        </div>
      ) : (
        <NavLink to="/login" className="tc-session-link">
          <span className="tc-session-note__dot" aria-hidden="true" />
          Iniciar sesión
        </NavLink>
      )}
    </header>
  );
}
