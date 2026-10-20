import { useEffect, useId, useRef, useState, type KeyboardEvent as ReactKeyboardEvent } from "react";
import { Link, useLocation } from "react-router-dom";
import { ChevronDown } from "lucide-react";
import { motion, useReducedMotion } from "motion/react";
import { GRUPOS_SERVICIOS } from "../../app/navigation";
import { puedeAcceder, useSession } from "../../app/session";
import { EASE_SALIDA } from "../motion/motionConfig";

export function ServicesMenu() {
  const [abierto, setAbierto] = useState(false);
  const contenedorRef = useRef<HTMLDivElement>(null);
  const botonRef = useRef<HTMLButtonElement>(null);
  const ubicacion = useLocation();
  const sesion = useSession();
  const panelId = useId();
  const reduce = useReducedMotion();

  const grupos = GRUPOS_SERVICIOS.map((grupo) => ({
    etiqueta: grupo.etiqueta,
    items: grupo.items.filter((item) => puedeAcceder(sesion, item.roles)),
  })).filter((grupo) => grupo.items.length > 0);

  const activo = grupos.some((grupo) =>
    grupo.items.some((item) => ubicacion.pathname === item.ruta || ubicacion.pathname.startsWith(item.ruta + "/")),
  );

  function enfocarPrimero() {
    contenedorRef.current?.querySelector<HTMLElement>("a[data-menu-item]")?.focus();
  }

  function cerrar(devolverFoco = false) {
    setAbierto(false);
    if (devolverFoco) botonRef.current?.focus();
  }

  useEffect(() => {
    setAbierto(false);
  }, [ubicacion.pathname]);

  useEffect(() => {
    if (!abierto) return;

    const frame = window.setTimeout(enfocarPrimero, 0);

    function onPointerDown(event: MouseEvent) {
      if (contenedorRef.current && !contenedorRef.current.contains(event.target as Node)) {
        setAbierto(false);
      }
    }

    function onKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        event.stopPropagation();
        cerrar(true);
      }
    }

    document.addEventListener("mousedown", onPointerDown);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      window.clearTimeout(frame);
      document.removeEventListener("mousedown", onPointerDown);
      document.removeEventListener("keydown", onKeyDown);
    };
  }, [abierto]);

  function onBotonClick() {
    setAbierto((previo) => !previo);
  }

  function onBotonKeyDown(event: ReactKeyboardEvent<HTMLButtonElement>) {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      setAbierto(true);
    }
  }

  function onPanelKeyDown(event: ReactKeyboardEvent<HTMLDivElement>) {
    const items = Array.from(
      contenedorRef.current?.querySelectorAll<HTMLElement>("a[data-menu-item]") ?? [],
    );
    if (items.length === 0) return;
    const actual = items.indexOf(document.activeElement as HTMLElement);

    if (event.key === "ArrowDown") {
      event.preventDefault();
      items[(actual + 1) % items.length]?.focus();
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      items[(actual - 1 + items.length) % items.length]?.focus();
    } else if (event.key === "Home") {
      event.preventDefault();
      items[0]?.focus();
    } else if (event.key === "End") {
      event.preventDefault();
      items[items.length - 1]?.focus();
    }
  }

  return (
    <div className="tc-menu" ref={contenedorRef}>
      <button
        ref={botonRef}
        type="button"
        className={["tc-navbar__link", "tc-navbar__trigger", activo ? "is-active" : ""].filter(Boolean).join(" ")}
        aria-haspopup="true"
        aria-expanded={abierto}
        aria-controls={panelId}
        onClick={onBotonClick}
        onKeyDown={onBotonKeyDown}
      >
        Servicios
        <ChevronDown size={15} className={["tc-navbar__chevron", abierto ? "is-open" : ""].filter(Boolean).join(" ")} aria-hidden="true" />
      </button>

      {reduce ? (
        <div
          id={panelId}
          className="tc-menu__panel"
          data-open={abierto}
          aria-label="Servicios de TechCare"
          onKeyDown={onPanelKeyDown}
        >
          <div className="tc-menu__grid">
            {grupos.map((grupo) => (
              <div className="tc-menu__group" role="group" aria-label={grupo.etiqueta} key={grupo.etiqueta}>
                <div className="tc-menu__group-label" aria-hidden="true">
                  {grupo.etiqueta}
                </div>
                {grupo.items.map((item) => {
                  const Icono = item.icono;
                  return (
                    <Link
                      key={item.ruta}
                      to={item.ruta}
                      className="tc-menu__item"
                      data-menu-item=""
                      onClick={() => cerrar(false)}
                    >
                      <span className="tc-menu__icon" aria-hidden="true">
                        <Icono size={17} />
                      </span>
                      <span className="tc-menu__text">
                        <span className="tc-menu__title">{item.etiqueta}</span>
                        {item.descripcion ? <span className="tc-menu__desc">{item.descripcion}</span> : null}
                      </span>
                    </Link>
                  );
                })}
              </div>
            ))}
          </div>
        </div>
      ) : (
        <motion.div
          id={panelId}
          className="tc-menu__panel"
          data-open={abierto}
          aria-label="Servicios de TechCare"
          onKeyDown={onPanelKeyDown}
          initial={false}
          animate={abierto ? { opacity: 1, y: 0, scale: 1 } : { opacity: 0, y: -6, scale: 0.98 }}
          transition={{ duration: 0.18, ease: EASE_SALIDA }}
          style={{ pointerEvents: abierto ? "auto" : "none", visibility: abierto ? "visible" : "hidden" }}
        >
          <div className="tc-menu__grid">
            {grupos.map((grupo) => (
              <div className="tc-menu__group" role="group" aria-label={grupo.etiqueta} key={grupo.etiqueta}>
                <div className="tc-menu__group-label" aria-hidden="true">
                  {grupo.etiqueta}
                </div>
                {grupo.items.map((item) => {
                  const Icono = item.icono;
                  return (
                    <Link
                      key={item.ruta}
                      to={item.ruta}
                      className="tc-menu__item"
                      data-menu-item=""
                      onClick={() => cerrar(false)}
                    >
                      <span className="tc-menu__icon" aria-hidden="true">
                        <Icono size={17} />
                      </span>
                      <span className="tc-menu__text">
                        <span className="tc-menu__title">{item.etiqueta}</span>
                        {item.descripcion ? <span className="tc-menu__desc">{item.descripcion}</span> : null}
                      </span>
                    </Link>
                  );
                })}
              </div>
            ))}
          </div>
        </motion.div>
      )}
    </div>
  );
}
