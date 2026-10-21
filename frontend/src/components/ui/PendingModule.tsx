import { Link } from "react-router-dom";
import { Clock } from "lucide-react";
import { Card, PageHeader } from "./Card";
import { Button } from "./Button";
import { Reveal } from "../motion/Reveal";

export function PendingModule({
  modulo,
  titulo,
  descripcion,
}: {
  modulo: string;
  titulo: string;
  descripcion?: string;
}) {
  return (
    <>
      <PageHeader eyebrow={modulo} titulo={titulo} descripcion={descripcion} />
      <Reveal>
        <Card>
          <div className="tc-state">
            <Clock className="tc-state__icon" size={22} aria-hidden="true" />
            <div className="tc-state__title">Modulo en preparacion</div>
            <div className="tc-state__desc">
              Este modulo todavia no tiene conexion con el servidor, por lo que no muestra datos ni permite acciones.
              La interfaz queda lista para conectarse cuando exista la API.
            </div>
            <Link to="/integracion">
              <Button variante="fantasma">Ver estado de integracion</Button>
            </Link>
          </div>
        </Card>
      </Reveal>
    </>
  );
}
