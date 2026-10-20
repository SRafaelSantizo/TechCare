import { useRef } from "react";
import { Link } from "react-router-dom";
import { motion, useReducedMotion, useScroll, useTransform } from "motion/react";
import { ArrowRight } from "lucide-react";
import { Badge, type TonoBadge } from "../../components/ui/Badge";
import { Button } from "../../components/ui/Button";
import { EASE_SALIDA } from "../../components/motion/Reveal";

type EstadoSeccion = "conectado" | "parcial" | "preparacion";

function estadoBadge(estado: EstadoSeccion): { tono: TonoBadge; texto: string } {
  if (estado === "conectado") return { tono: "ok", texto: "Conectado" };
  if (estado === "parcial") return { tono: "warn", texto: "Parcial" };
  return { tono: "neutral", texto: "En preparación" };
}

function Captura({ src, alt, etiqueta }: { src: string; alt: string; etiqueta?: string }) {
  return (
    <div className="tc-capture">
      <img src={src} alt={alt} loading="lazy" decoding="async" />
      {etiqueta ? <span className="tc-capture__tag">{etiqueta}</span> : null}
    </div>
  );
}

function Hero({ onConocer }: { onConocer: () => void }) {
  const ref = useRef<HTMLElement>(null);
  const reduce = useReducedMotion();
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start start", "end start"] });

  const copyY = useTransform(scrollYProgress, [0, 1], reduce ? [0, 0] : [0, -72]);
  const copyOpacity = useTransform(scrollYProgress, [0, 0.8], reduce ? [1, 1] : [1, 0.12]);
  const captureScale = useTransform(scrollYProgress, [0, 1], reduce ? [1, 1] : [0.82, 1.08]);
  const captureY = useTransform(scrollYProgress, [0, 1], reduce ? [0, 0] : [0, -48]);
  const decorY = useTransform(scrollYProgress, [0, 1], reduce ? [0, 0] : [0, 160]);

  return (
    <section ref={ref} className="tc-hero2" aria-labelledby="hero-titulo">
      <motion.div className="tc-hero2__decor" style={{ y: decorY as never }} aria-hidden="true">
        <span className="tc-hero2__orb tc-hero2__orb--1" />
        <span className="tc-hero2__orb tc-hero2__orb--2" />
        <span className="tc-hero2__rail" />
      </motion.div>

      <div className="tc-hero2__inner">
        <motion.div className="tc-hero2__copy" style={{ y: copyY as never, opacity: copyOpacity as never }}>
          <p className="tc-hero2__eyebrow">TechCare</p>
          <h1 id="hero-titulo" className="tc-hero2__titulo">
            Tu tecnología, en buenas manos.
          </h1>
          <p className="tc-hero2__desc">
            El sistema integral de servicio técnico, inventario y facturación del taller. Empieza por el módulo de
            Clientes, ya conectado con el backend, y recorre el resto de la aplicación tal como hoy se entrega.
          </p>
          <div className="tc-hero2__acciones">
            <Button variante="primario" onClick={onConocer}>
              Conoce TechCare
              <ArrowRight size={16} aria-hidden="true" />
            </Button>
          </div>
        </motion.div>

        <motion.div className="tc-hero2__capture" style={{ scale: captureScale as never, y: captureY as never }}>
          <div className="tc-capture tc-capture--hero">
            <img
              src="/capturas/clientes.png"
              alt="Listado de clientes de TechCare con datos reales del backend."
              decoding="async"
            />
            <span className="tc-capture__tag">Módulo de Clientes • conectado</span>
          </div>
        </motion.div>
      </div>
    </section>
  );
}

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
  enlace: string;
  etiquetaEnlace: string;
}) {
  const ref = useRef<HTMLElement>(null);
  const reduce = useReducedMotion();
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start end", "end start"] });

  const imgY = useTransform(scrollYProgress, [0, 1], reduce ? [0, 0] : [-26, 26]);
  const textoY = useTransform(scrollYProgress, [0, 1], reduce ? [0, 0] : [10, -12]);
  const marca = estadoBadge(estado);

  return (
    <motion.section
      ref={ref}
      className="tc-show"
      data-invertida={indice % 2 === 1}
      initial={reduce ? false : { opacity: 0, y: 28 }}
      whileInView={reduce ? undefined : { opacity: 1, y: 0 }}
      viewport={{ once: true, amount: 0.15 }}
      transition={{ duration: 0.56, ease: EASE_SALIDA }}
    >
      <div className="tc-show__text" style={{ y: textoY as never }}>
        <div className="tc-show__index">{String(indice + 1).padStart(2, "0")}</div>
        <h2 className="tc-show__title">{titulo}</h2>
        <p className="tc-show__desc">{descripcion}</p>
        <div className="tc-show__meta">
          <Badge tono={marca.tono}>{marca.texto}</Badge>
        </div>
        <Link to={enlace} className="tc-show__link" aria-label={etiquetaEnlace}>
          {etiquetaEnlace}
          <ArrowRight size={15} aria-hidden="true" />
        </Link>
      </div>
      <div className="tc-show__media">
        <motion.div className="tc-show__frame" style={{ y: imgY as never }}>
          <img src={imagen} alt={alt} loading="lazy" decoding="async" />
        </motion.div>
      </div>
    </motion.section>
  );
}

const PENDIENTE =
  "La pantalla existe y navega, pero aún no tiene endpoint en el backend; se marca En preparación y no simula cifras ni acciones.";

export function HomePage() {
  const reduce = useReducedMotion();
  const presentacionRef = useRef<HTMLDivElement>(null);

  function irAPresentacion() {
    const objetivo = presentacionRef.current;
    if (!objetivo) return;
    objetivo.scrollIntoView({ behavior: reduce ? "auto" : "smooth", block: "start" });
  }

  return (
    <div className="tc-inicio">
      <Hero onConocer={irAPresentacion} />

      <div className="tc-presentacion" ref={presentacionRef} id="presentacion">
        <section className="tc-showcase" aria-labelledby="showcase-titulo">
          <div className="tc-showcase__cabezal">
            <motion.h2
              id="showcase-titulo"
              className="tc-showcase__titulo"
              initial={reduce ? false : { opacity: 0, y: 16 }}
              whileInView={reduce ? undefined : { opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.3 }}
              transition={{ duration: 0.52, ease: EASE_SALIDA }}
            >
              Pantallas reales de la aplicación
            </motion.h2>
            <motion.p
              className="tc-showcase__desc"
              initial={reduce ? false : { opacity: 0, y: 16 }}
              whileInView={reduce ? undefined : { opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.3 }}
              transition={{ duration: 0.52, ease: EASE_SALIDA, delay: reduce ? 0 : 0.06 }}
            >
              Empieza por Clientes, que ya es operativo contra el backend, y sigue por las pantallas que hoy se
              entregan en preparación. Cada una enlaza a su módulo real.
            </motion.p>
          </div>

          <ShowcaseSection
            indice={0}
            titulo="Clientes, desde el primer ingreso"
            descripcion="Listado de clientes con datos reales del backend. Es el módulo integrado y operativo, con validaciones, búsqueda, filtros y paginación."
            estado="conectado"
            imagen="/capturas/clientes.png"
            alt="Listado de clientes TechCare con datos reales del backend."
            enlace="/clientes"
            etiquetaEnlace="Ir a Clientes"
          />
          <ShowcaseSection
            indice={1}
            titulo="Cada cliente, con su expediente"
            descripcion="Detalle completo del cliente con rutas limpias y acceso a sus equipos e historial de órdenes."
            estado="conectado"
            imagen="/capturas/cliente-detalle.png"
            alt="Ficha de detalle de un cliente."
            enlace="/clientes/1"
            etiquetaEnlace="Ver ejemplo de ficha"
          />
          <ShowcaseSection
            indice={2}
            titulo="El estado del taller, en una vista"
            descripcion="Resumen con los indicadores del servicio y los clientes recientes. Los indicadores se muestran como pendientes hasta que el backend exponga el cálculo."
            estado="parcial"
            imagen="/capturas/resumen.png"
            alt="Pantalla de Resumen del taller."
            enlace="/resumen"
            etiquetaEnlace="Ir a Resumen del taller"
          />
          <ShowcaseSection
            indice={3}
            titulo="Órdenes de servicio, sin pérdida de contexto"
            descripcion={"Flujo de ingreso y expediente de órdenes. La interfaz está preparada y navega; esta zona se entrega En preparación. " + PENDIENTE}
            estado="preparacion"
            imagen="/capturas/ordenes.png"
            alt="Pantalla de órdenes de servicio en estado de preparación."
            enlace="/ordenes"
            etiquetaEnlace="Ir a Órdenes de servicio"
          />
          <ShowcaseSection
            indice={4}
            titulo="Inventario y compras bajo control"
            descripcion={"Existencias, repuestos, compras y proveedores. Se marca En preparación con la indicación del requisito de integración. " + PENDIENTE}
            estado="preparacion"
            imagen="/capturas/inventario.png"
            alt="Pantalla de inventario y compras en estado de preparación."
            enlace="/inventario"
            etiquetaEnlace="Ir a Inventario y compras"
          />
          <ShowcaseSection
            indice={5}
            titulo="Facturación y caja, con saldos claros"
            descripcion={"Zona de facturación y caja: emisión de facturas, pagos y saldos. Se activará cuando el backend exponga los contratos correspondientes. " + PENDIENTE}
            estado="preparacion"
            imagen="/capturas/facturacion.png"
            alt="Pantalla de facturación y caja en estado de preparación."
            enlace="/facturacion"
            etiquetaEnlace="Ir a Facturación y caja"
          />
          <ShowcaseSection
            indice={6}
            titulo="Equipos, uno por cliente"
            descripcion={"Administración de equipos por cliente en preparación. " + PENDIENTE}
            estado="preparacion"
            imagen="/capturas/equipos.png"
            alt="Pantalla de equipos en estado de preparación."
            enlace="/equipos"
            etiquetaEnlace="Ir a Equipos"
          />
        </section>

        <StickyStage />
      </div>

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
            Solo mostramos lo que se puede verificar contra el backend que corre hoy. Las zonas en preparación se
            presentan con ese estado para evitar cifras o acciones simuladas.
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

function StickyStage() {
  const reduce = useReducedMotion();
  const bloques = [
    {
      titulo: "Datos reales, no de ejemplo",
      texto: "El listado de Clientes se consume de GET /api/clientes. Lo que ves en pantalla proviene del backend de TechCare.",
    },
    {
      titulo: "Integración verificable",
      texto: "Alta y edición usan POST y PUT /api/clientes, con validación por campo y manejo honesto de errores del servidor.",
    },
    {
      titulo: "Lo que falta, marcado",
      texto: "El resto de módulos se entrega navegando pero rotulado En preparación: sin cifras inventadas ni acciones simuladas.",
    },
  ];

  return (
    <section className="tc-stage" aria-labelledby="stage-titulo">
      <div className="tc-stage__text">
        <motion.div
          initial={reduce ? false : { opacity: 0, y: 20 }}
          whileInView={reduce ? undefined : { opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.3 }}
          transition={{ duration: 0.5, ease: EASE_SALIDA }}
        >
          <p className="tc-show__index">Módulo conectado</p>
          <h2 id="stage-titulo" className="tc-showcase__titulo">
            Un taller conectado, paso a paso
          </h2>
          <p className="tc-showcase__desc">
            Clientes es el módulo que hoy conversa con el backend. Estos son los tres criterios que sostienen esa
            integración, y que guían cómo se completará el resto del sistema.
          </p>
        </motion.div>

        <div className="tc-stage__blocks">
          {bloques.map((bloque, i) => (
            <motion.article
              key={bloque.titulo}
              className="tc-stage__block"
              initial={reduce ? false : { opacity: 0, y: 24 }}
              whileInView={reduce ? undefined : { opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.5 }}
              transition={{ duration: 0.48, ease: EASE_SALIDA, delay: reduce ? 0 : i * 0.06 }}
            >
              <h3 className="tc-stage__block-title">{bloque.titulo}</h3>
              <p className="tc-stage__block-text">{bloque.texto}</p>
            </motion.article>
          ))}
        </div>
      </div>

      <div className="tc-stage__media">
        <div className="tc-stage__sticky">
          <Captura
            src="/capturas/clientes.png"
            alt="Listado de clientes TechCare conectado al backend."
          />
        </div>
      </div>
    </section>
  );
}
