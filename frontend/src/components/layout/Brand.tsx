import { Link } from "react-router-dom";

/**
 * Marca de TechCare. Se usa en la cabecera de la pagina de presentacion y en
 * la cabecera del cajon de navegacion.
 */
export function Brand({ enlace = "/" }: { enlace?: string }) {
  return (
    <Link to={enlace} className="tc-brand" aria-label="TechCare, ir al inicio">
      <span className="tc-brand__mark" aria-hidden="true">
        TC
      </span>
      <span>
        <span className="tc-brand__name">TechCare</span>
        <span className="tc-brand__sub">Servicio tecnico</span>
      </span>
    </Link>
  );
}
