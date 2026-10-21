import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Plus, RefreshCw } from "lucide-react";
import { Card, PageHeader } from "../../components/ui/Card";
import { Alert } from "../../components/ui/Alert";
import { Button } from "../../components/ui/Button";
import { Dialog } from "../../components/ui/Dialog";
import { Field, SelectInput, TextInput } from "../../components/ui/inputs";
import { LoadingState } from "../../components/ui/StateView";
import { type Columna } from "../../components/ui/DataTable";
import { abastecimientoApi as api, idCatalogo, type TipoCatalogo, type RegistroCatalogo, type PrecioRepuesto } from "../../services/abastecimiento";
import { mensajeDeError } from "../../services/errors";
import { fechaHora, moneda } from "../../utils/format";
import { EstadoCatalogo, TablaCatalogo } from "./compartidos";
import { CatalogoForm } from "./CatalogoForm";
import { CategoriasPanel } from "./CategoriasPanel";
import { RelacionesPanel } from "./RelacionesPanel";
import { comprasApi, quetzales, type CostoBodega } from "../../services/compras";

type Modal = { tipo: "editor" | "relaciones" | "precios" | "costos"; registro: RegistroCatalogo | null } | { tipo: "categorias" };
const NOMBRES = { repuestos: { titulo: "Repuestos", singular: "repuesto", descripcion: "Catálogo, precios actuales y categorías de los repuestos del taller." },
  proveedores: { titulo: "Proveedores", singular: "proveedor", descripcion: "Datos de contacto y repuestos que ofrece cada proveedor." },
  bodegas: { titulo: "Bodegas", singular: "bodega", descripcion: "Ubicaciones de almacenamiento, repuestos asociados y mínimos de reposición." } };

export function GestionCatalogo({ tipo }: { tipo: TipoCatalogo }) {
  const textos = NOMBRES[tipo];
  const [buscar, setBuscar] = useState(""), [activo, setActivo] = useState(""), [categoria, setCategoria] = useState("");
  const [filtros, setFiltros] = useState({ buscar: "", activo: "", categoria: "" });
  const [modal, setModal] = useState<Modal | null>(null), [ocupado, setOcupado] = useState(false), [ok, setOk] = useState(""), [version, setVersion] = useState(0);
  const listado = useQuery({ queryKey: ["abastecimiento", tipo, filtros], queryFn: ({ signal }): Promise<RegistroCatalogo[]> => {
    const estado = filtros.activo === "" ? undefined : filtros.activo === "true";
    return tipo === "repuestos" ? api.repuestos(filtros.buscar, estado, filtros.categoria ? Number(filtros.categoria) : undefined, signal) : tipo === "proveedores" ? api.proveedores(filtros.buscar, estado, signal) : api.bodegas(filtros.buscar, estado, signal);
  } });
  const categorias = useQuery({ queryKey: ["abastecimiento", "categorias"], queryFn: ({ signal }) => api.categorias(signal), enabled: tipo === "repuestos" });
  function abrir(m: Modal) { setVersion(v => v + 1); setModal(m); }
  const columnas: Columna<RegistroCatalogo>[] = [
    { clave: "codigo", encabezado: tipo === "proveedores" ? "NIT" : "Código", render: r => <strong>{"nit" in r ? r.nit : r.codigo}</strong> },
    { clave: "nombre", encabezado: "Nombre", render: r => <div style={{ overflowWrap: "anywhere" }}>{r.nombre}{"categoria" in r ? <div className="tc-field__hint">{r.categoria}</div> : null}</div> },
    ...(tipo === "repuestos" ? [{ clave: "precio", encabezado: "Precio de venta", numerica: true, render: (r: RegistroCatalogo) => "precioVenta" in r ? moneda(r.precioVenta) : "—" }] :
      [{ clave: "contacto", encabezado: tipo === "proveedores" ? "Contacto" : "Dirección", render: (r: RegistroCatalogo) => "email" in r ? <>{r.email || "—"}<div>{r.telefono || "—"}</div></> : "direccion" in r ? r.direccion || "—" : "—" }]),
    { clave: "estado", encabezado: "Estado", render: r => <EstadoCatalogo activo={r.activo} /> },
    { clave: "acciones", encabezado: "Acciones", render: r => <div className="tc-row" style={{ flexWrap: "wrap" }}>
      <Button tamano="sm" onClick={() => abrir({ tipo: "editor", registro: r })}>Editar</Button>
      <Button tamano="sm" onClick={() => abrir({ tipo: tipo === "repuestos" ? "precios" : "relaciones", registro: r })}>{tipo === "repuestos" ? "Historial de precios" : tipo === "proveedores" ? "Catálogo ofrecido" : "Repuestos y mínimos"}</Button>
      {tipo === "repuestos" ? <Button tamano="sm" onClick={() => abrir({ tipo: "costos", registro: r })}>Costos por bodega</Button> : null}</div> },
  ];
  return <>
    <PageHeader eyebrow="Inventario y compras" titulo={textos.titulo} descripcion={textos.descripcion} acciones={<>
      {tipo === "repuestos" ? <Button onClick={() => abrir({ tipo: "categorias" })}>Categorías</Button> : null}
      <Button variante="primario" icono={<Plus size={16} />} onClick={() => abrir({ tipo: "editor", registro: null })}>{tipo === "bodegas" ? "Nueva bodega" : `Nuevo ${textos.singular}`}</Button>
      <Button icono={<RefreshCw size={16} />} disabled={listado.isFetching} onClick={() => listado.refetch()}>Actualizar</Button>
    </>} />
    <div className="tc-stack">{ok ? <Alert tono="ok">{ok}</Alert> : null}
      {tipo === "repuestos" ? <Alert tono="info">Registrar un repuesto crea su catálogo y precio. Asociá los repuestos a sus proveedores y bodegas para preparar el abastecimiento.</Alert> : null}
      <Card><form className="tc-row" style={{ flexWrap: "wrap", alignItems: "end" }} onSubmit={e => { e.preventDefault(); setFiltros({ buscar: buscar.trim(), activo, categoria }); }}>
        <Field label="Buscar" htmlFor="gestion-buscar"><TextInput id="gestion-buscar" maxLength={150} value={buscar} onChange={e => setBuscar(e.target.value)} placeholder={tipo === "proveedores" ? "NIT, nombre o contacto" : "Código o nombre"} /></Field>
        <Field label="Estado" htmlFor="gestion-estado"><SelectInput id="gestion-estado" value={activo} onChange={e => setActivo(e.target.value)}><option value="">Todos</option><option value="true">Activos</option><option value="false">Inactivos</option></SelectInput></Field>
        {tipo === "repuestos" ? <Field label="Categoría" htmlFor="gestion-categoria"><SelectInput id="gestion-categoria" disabled={categorias.isLoading || categorias.isError} value={categoria} onChange={e => setCategoria(e.target.value)}><option value="">Todas</option>{categorias.data?.map(c => <option key={c.categoriaId} value={c.categoriaId}>{c.nombre}</option>)}</SelectInput></Field> : null}
        <Button type="submit" variante="primario">Buscar</Button><Button type="button" onClick={() => { setBuscar(""); setActivo(""); setCategoria(""); setFiltros({ buscar: "", activo: "", categoria: "" }); }}>Limpiar</Button>
      </form></Card>
      {categorias.isError && tipo === "repuestos" ? <Alert tono="danger" accion={<Button onClick={() => categorias.refetch()}>Reintentar categorías</Button>}>{mensajeDeError(categorias.error)}</Alert> : null}
      {listado.isLoading ? <LoadingState titulo={`Cargando ${tipo}…`} /> : listado.isError ? <Alert tono="danger" accion={<Button onClick={() => listado.refetch()}>Reintentar</Button>}>{mensajeDeError(listado.error)}</Alert> :
        <TablaCatalogo key={JSON.stringify(filtros)} filas={listado.data ?? []} columnas={columnas} clave={idCatalogo} vacio="No hay registros para estos filtros." />}
    </div>
    {modal ? <Dialog abierto ancho={modal.tipo === "editor" ? 720 : 1050} titulo={modal.tipo === "categorias" ? "Categorías de repuestos" : modal.tipo === "editor" ? `${modal.registro ? "Editar" : "Registrar"} ${textos.singular}` : modal.tipo === "precios" ? `Historial de precios · ${modal.registro?.nombre}` : modal.tipo === "costos" ? `Costos por bodega · ${modal.registro?.nombre}` : `${tipo === "proveedores" ? "Catálogo ofrecido" : "Repuestos y mínimos"} · ${modal.registro?.nombre}`}
      onCerrar={() => { if (!ocupado) setModal(null); }}>
      {modal.tipo === "editor" ? <CatalogoForm key={version} tipo={tipo} registro={modal.registro} onOcupado={setOcupado}
        onCancelar={() => { if (!ocupado) setModal(null); }} onGuardado={r => { setOk(`${r.nombre} guardado.`); setModal(null); }}
        onRecargar={r => { setVersion(v => v + 1); setModal({ tipo: "editor", registro: r }); }} /> : modal.tipo === "categorias" ? <CategoriasPanel onOcupado={setOcupado} /> : modal.tipo === "precios" && modal.registro ?
          <PreciosPanel id={idCatalogo(modal.registro)} /> : modal.tipo === "costos" && modal.registro ? <CostosPanel id={idCatalogo(modal.registro)} /> : modal.tipo === "relaciones" && modal.registro && !("repuestoId" in modal.registro) ? <RelacionesPanel padre={modal.registro} onOcupado={setOcupado} /> : null}
    </Dialog> : null}
  </>;
}
function CostosPanel({ id }: { id: number }) {
  const datos = useQuery({ queryKey: ["abastecimiento", "costos", id], queryFn: ({ signal }) => comprasApi.costos(id, signal) });
  const columnas: Columna<CostoBodega>[] = [
    { clave: "bodega", encabezado: "Bodega", render: b => <><strong>{b.codigo}</strong><div>{b.bodega}</div></> },
    { clave: "existencia", encabezado: "Existencia", numerica: true, render: b => b.existencia },
    { clave: "costo", encabezado: "Costo promedio", numerica: true, render: b => quetzales(b.costoPromedio, 6) },
    { clave: "estado", encabezado: "Estado", render: b => <EstadoCatalogo activo={b.activo} /> },
  ];
  return <div className="tc-stack" style={{ marginTop: 16 }}><Alert tono="info">Promedio calculado desde las compras recibidas en cada bodega. Los nuevos consumos conservan ese costo, redondeado a centavos. Al agotar las unidades, el promedio queda en cero.</Alert>
    {datos.isLoading ? <LoadingState /> : datos.isError ? <Alert tono="danger" accion={<Button onClick={() => datos.refetch()}>Reintentar</Button>}>{mensajeDeError(datos.error)}</Alert> : <TablaCatalogo filas={datos.data ?? []} columnas={columnas} clave={b => b.bodegaId} vacio="El repuesto todavía no está asociado a una bodega." />}</div>;
}
function PreciosPanel({ id }: { id: number }) {
  const datos = useQuery({ queryKey: ["abastecimiento", "precios", id], queryFn: ({ signal }) => api.precios(id, signal) });
  const columnas: Columna<PrecioRepuesto>[] = [
    { clave: "fecha", encabezado: "Fecha", render: p => fechaHora(p.fecha) },
    { clave: "costo", encabezado: "Costo anterior → nuevo", render: p => `${moneda(p.costoAnterior)} → ${moneda(p.costoNuevo)}` },
    { clave: "precio", encabezado: "Precio anterior → nuevo", render: p => `${moneda(p.precioAnterior)} → ${moneda(p.precioNuevo)}` },
    { clave: "usuario", encabezado: "Registró", render: p => p.registradoPor || "Registro previo sin usuario de aplicación" },
  ];
  return <div style={{ marginTop: 16 }}>{datos.isLoading ? <LoadingState /> : datos.isError ? <Alert tono="danger" accion={<Button onClick={() => datos.refetch()}>Reintentar</Button>}>{mensajeDeError(datos.error)}</Alert> :
    <TablaCatalogo filas={datos.data ?? []} columnas={columnas} clave={r => r.auditoriaId} vacio="No hay cambios de costo o precio registrados." />}</div>;
}
