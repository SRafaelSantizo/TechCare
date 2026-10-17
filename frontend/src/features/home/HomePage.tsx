import { useRef } from "react";
import { Link } from "react-router-dom";
import { motion, useReducedMotion, useScroll, useTransform } from "motion/react";
import { Badge, type TonoBadge } from "../../components/ui/Badge";
import { Button } from "../../components/ui/Button";

const EASE_SALIDA: [number, number, number, number] = [0.22, 1, 0.36, 1];

type EstadoSeccion = "conectado" | "parcial" | "preparacion";

function estadoBadge(estado: EstadoSeccion): { tono: TonoBadge; texto: string } {
  if (estado === "conectado") return { tono: "ok", texto: "Conectado" };
  if (estado === "parcial") return { tono: "warn", texto: "Parcial" };
  return { tono: "neutral", texto: "En preparación" };
}

/**
 * Parallax sutil del marco y del texto de la seccion: la imagen y el texto
 * se desplazan a velocidades distintas y en sentidos coherentes.
 */
function ShowcaseSection({
  indice,
  titulo,
  descripcion,
  estado,
  imagen,
  alt,
  enlace,
  etiquetaEnlace,
}: {
  indice: number;
  titulo: string;
  descripcion: string;
  estado: EstadoSeccion;
  imagen: string;
  alt: string;
  enlace?: string;
  etiquetaEnlace?: string;
}) {
  const ref = useRef<HTMLElement>(null);
  const reduce = useReducedMotion();
  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ["start end", "end start"],
  });

  const imgY = useTransform(scrollYProgress, [0, 1], reduce ? [0, 0] : [-28, 28]);
  const textoY = useTransform(scrollYProgress, [0, 1], reduce ? [0, 0] : [12, -14]);
  const marca = estadoBadge(estado);

  return (
    <motion.section
      ref={ref}
      className="tc-show"
      data-invertida={indice % 2 === 1}
          initial={reduce ? false : { opacity: 0, y: 28 }}
          whileInView={reduce ? undefined : { opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.18 }}
          transition={{ duration: 0.56, ease: EASE_SALIDA }}
        >
          <div className="tc-show__text" style={{ y: textoY as any }}>
            <div className="tc-show__index">0{indice + 1}</div>
            <h2 className="tc-show__title">{titulo}</h2>
            <p className="tc-show__desc">{descripcion}</p>
            <div className="tc-show__meta">
              <Badge tono={marca.tono}>{marca.texto}</Badge>
            </div>
            {enlace ? (
              <Link to={enlace} className="tc-show__link" aria-label={etiquetaEnlace ?? titulo}>
                {etiquetaEnlace ?? "Ver pantalla"}
              </Link>
            ) : null}
          </div>
          <div className="tc-show__media" aria-hidden="true">
            <motion.div className="tc-show__frame" style={{ y: imgY as any }}>
              <img src={imagen} alt={alt} loading="lazy" decoding="async" />
            </motion.div>
          </div>
        </motion.section>
  );
}

export function HomePage() {
  const reduce = useReducedMotion();
  const introRef = useRef<HTMLElement>(null);
  const showcaseRef = useRef<HTMLElement>(null);
  const { scrollYProgress } = useScroll({
    target: introRef,
    offset: ["start start", "end start"],
  });

  const decorY = useTransform(scrollYProgress, [0, 1], reduce ? [0, 0] : [0, 140]);
  const cuerpoY = useTransform(scrollYProgress, [0, 1], reduce ? [0, 0] : [0, 42]);

  function irAShowcase() {
    showcaseRef.current?.scrollIntoView({ behavior: reduce ? "auto" : "smooth" });
  }

  return (
    <div className="tc-inicio">
      <motion.section ref={introRef} className="tc-intro">
        <motion.div className="tc-intro__decor" style={{ y: decorY as any }} aria-hidden="true">
          <span className="tc-intro__orb tc-intro__orb--1" />
          <span className="tc-intro__orb tc-intro__orb--2" />
          <span className="tc-intro__rail" />
        </motion.div>
        <div className="tc-intro__inner">
          <motion.div className="tc-intro__cuerpo" style={{ y: cuerpoY as any }}>
            <p className="tc-intro__eyebrow">TechCare</p>
            <h1 className="tc-intro__titulo">Tu tecnología, en buenas manos.</h1>
            <p className="tc-intro__desc">
              Una presentación clara del taller: clientes reales, ordenes y estado de las zonas que ya conectamos con el
              backend, marcando de forma honesta lo que aun esta en preparacion.
            </p>
            <div className="tc-intro__acciones">
              <Button variante="primario" onClick={irAShowcase}>
                Explorar TechCare
              </Button>
            </div>
          </motion.div>
        </div>
      </motion.section>

      <section className="tc-showcase" ref={showcaseRef} aria-labelledby="showcase-titulo">
        <div className="tc-showcase__cabezal">
          <motion.h2
            id="showcase-titulo"
            className="tc-showcase__titulo"
            initial={reduce ? false : { opacity: 0, y: 16 }}
            whileInView={reduce ? undefined : { opacity: 1, y: 0 }}
            viewport={{ once: true, amount: 0.3 }}
            transition={{ duration: 0.52, ease: EASE_SALIDA }}
          >
            Pantallas reales de la aplicacion
          </motion.h2>
          <motion.p
            className="tc-showcase__desc"
            initial={reduce ? false : { opacity: 0, y: 16 }}
            whileInView={reduce ? undefined : { opacity: 1, y: 0 }}
            viewport={{ once: true, amount: 0.3 }}
            transition={{ duration: 0.52, ease: EASE_SALIDA, delay: reduce ? 0 : 0.08 }}
          >
            Capturas honestas de lo que funciona hoy (Clientes) y de las zonas en preparacion, sin simular cifras ni
            acciones.
          </motion.p>
        </div>

        <ShowcaseSection
          indice={0}
          titulo="Resumen del taller"
          descripcion="Vista consolidada del servicio: clientes reales y una referencia a las metricas del taller, que permanecen en preparacion hasta contar con su calculo definitivo."
          estado="parcial"
          imagen="/capturas/resumen.png"
          alt="Pantalla de Resumen del taller mostrando bloques de clientes y metricas en preparacion."
          enlace="/resumen"
          etiquetaEnlace="Ir a Resumen del taller"
        />
        <ShowcaseSection
          indice={1}
          titulo="Clientes"
          descripcion="Listado de clientes con datos reales del backend (nombre, tipo, contacto y estado). Integrado y operativo, con validaciones y acciones existentes."
          estado="conectado"
          imagen="/capturas/clientes.png"
          alt="Listado de clientes TechCare con datos reales."
          enlace="/clientes"
          etiquetaEnlace="Ir a Clientes"
        />
        <ShowcaseSection
          indice={2}
          titulo="Ficha de cliente"
          descripcion="Detalle completo del cliente, con rutas limpias y encuadre a sus equipos e historial de ordenes. Usa la integracion real con GET /api/clientes/{id}."
          estado="conectado"
          imagen="/capturas/cliente-detalle.png"
          alt="Ficha de detalle de un cliente con sus datos y secciones de contexto."
          enlace="/clientes/1"
          etiquetaEnlace="Ver ejemplo de ficha de cliente"
        />
        <ShowcaseSection
          indice={3}
          titulo="Órdenes de servicio"
          descripcion="Flujo de ingreso y expediente de ordenes. La interfaz esta preparada; los endpoints especificos se habilitaran segun el contrato, por lo que esta zona se presenta como En preparacion."
          estado="preparacion"
          imagen="/capturas/ordenes.png"
          alt="Pantalla de ordenes de servicio en estado de preparacion."
          enlace="/ordenes"
          etiquetaEnlace="Ir a Ordenes de servicio"
        />
        <ShowcaseSection
          indice={4}
          titulo="Inventario y compras"
          descripcion="Espacio para existencias, repuestos, compras y proveedores. Aun sin endpoints activos para todas las operaciones listadas; se marca En preparacion con indicacion del requisito de integracion."
          estado="preparacion"
          imagen="/capturas/inventario.png"
          alt="Pantalla de inventario y compras en estado de preparacion."
          enlace="/inventario"
          etiquetaEnlace="Ir a Inventario y compras"
        />
        <ShowcaseSection
          indice={5}
          titulo="Facturación y caja"
          descripcion="Zona de facturacion y caja en preparacion: la interfaz permanece estable y se activara cuando el backend exponga los contratos correspondientes."
          estado="preparacion"
          imagen="/capturas/facturacion.png"
          alt="Pantalla de facturacion y caja en estado de preparacion."
          enlace="/facturacion"
          etiquetaEnlace="Ir a Facturacion y caja"
        />
        <ShowcaseSection
          indice={6}
          titulo="Equipos"
          descripcion="Administracion de equipos por cliente en preparacion. Se mantiene la coherencia visual y la navegacion; la accion real requerira endpoints especificos."
          estado="preparacion"
          imagen="/capturas/equipos.png"
          alt="Pantalla de equipos en estado de preparacion."
          enlace="/equipos"
          etiquetaEnlace="Ir a Equipos"
        />
      </section>

      <section className="tc-cierre">
        <motion.div
          className="tc-cierre__contenido"
          initial={reduce ? false : { opacity: 0, y: 18 }}
          whileInView={reduce ? undefined : { opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.2 }}
          transition={{ duration: 0.54, ease: EASE_SALIDA }}
        >
          <h2 className="tc-cierre__titulo">Transparencia primero</h2>
          <p className="tc-cierre__desc">
            Solo mostramos lo que se puede verificar contra el backend que corre hoy. Las zonas en preparacion se presentan
            con ese estado para evitar cifras o acciones simuladas.
          </p>
          <div className="tc-cierre__acciones">
            <Link to="/resumen">
              <Button variante="primario">Ver resumen del taller</Button>
            </Link>
          </div>
        </motion.div>
      </section>
    </div>
  );
}
