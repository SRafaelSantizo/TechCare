import { NavLink } from "react-router-dom";
import { NAVEGACION } from "../../app/navigation";
import { puedeAcceder, useSession } from "../../app/session";

/** Lista de destinos autorizados. Se reutiliza dentro del cajon de navegacion. */
export function Sidebar({ onNavegar }: { onNavegar?: () => void }) {
  const sesion = useSession();

  return (
    <nav className="tc-nav" aria-label="Modulos de TechCare">
      {NAVEGACION.map((grupo) => {
        const items = grupo.items.filter((item) => puedeAcceder(sesion, item.roles));
        if (items.length === 0) return null;
        return (
          <div className="tc-nav__group" key={grupo.etiqueta}>
            <div className="tc-nav__group-label">{grupo.etiqueta}</div>
            {items.map((item) => {
              const Icono = item.icono;
              return (
                <NavLink
                  key={item.ruta}
                  to={item.ruta}
                  end={item.ruta === "/" || item.ruta === "/ordenes"}
                  className="tc-nav__item"
                  onClick={onNavegar}
                >
                  <Icono size={17} />
                  {item.etiqueta}
                </NavLink>
              );
            })}
          </div>
        );
      })}
    </nav>
  );
}
