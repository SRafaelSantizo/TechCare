import { useRef, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Alert } from "../../components/ui/Alert";
import { Button } from "../../components/ui/Button";
import { Field, SelectInput, TextInput } from "../../components/ui/inputs";
import { LoadingState } from "../../components/ui/StateView";
import { type Columna } from "../../components/ui/DataTable";
import { abastecimientoApi as api, type Bodega, type Proveedor, type OfertaProveedor, type RepuestoBodega } from "../../services/abastecimiento";
import { esApiError, mensajeDeError } from "../../services/errors";
import { quetzales } from "../../services/compras";
import { numero } from "../../utils/format";
import { EstadoCatalogo, TablaCatalogo, useActualizarAbastecimiento } from "./compartidos";

type Relacion = OfertaProveedor | RepuestoBodega;
export function RelacionesPanel({ padre, onOcupado }: { padre: Bodega | Proveedor; onOcupado: (v: boolean) => void }) {
  const proveedor = "proveedorId" in padre, id = proveedor ? padre.proveedorId : padre.bodegaId;
  const relaciones = useQuery({ queryKey: ["abastecimiento", proveedor ? "ofertas" : "minimos", id],
    queryFn: ({ signal }): Promise<Relacion[]> => proveedor ? api.ofertas(id, signal) : api.repuestosBodega(id, signal) });
  const repuestos = useQuery({ queryKey: ["abastecimiento", "repuestos", "seleccion"], queryFn: ({ signal }) => api.repuestos("", undefined, undefined, signal) });
  const [actual, setActual] = useState<Relacion | null>(null), [repuesto, setRepuesto] = useState("");
  const [codigo, setCodigo] = useState(""), [minimo, setMinimo] = useState("5"), [retirar, setRetirar] = useState<OfertaProveedor | null>(null);
  const [error, setError] = useState(""), [ok, setOk] = useState(""), [guardando, setGuardando] = useState(false);
  const bloqueo = useRef(false), actualizar = useActualizarAbastecimiento();
  const filas = relaciones.data ?? [];
  const opciones = (repuestos.data ?? []).filter(r => r.repuestoId === actual?.repuestoId || (r.activo && !filas.some(f => f.repuestoId === r.repuestoId)));
  function editar(r: Relacion) {
    setActual(r); setRepuesto(String(r.repuestoId)); setCodigo("codigoProveedor" in r ? r.codigoProveedor ?? "" : ""); setMinimo("stockMinimo" in r ? String(r.stockMinimo) : "5"); setError(""); setRetirar(null);
  }
  function limpiar() { setActual(null); setRepuesto(""); setCodigo(""); setMinimo("5"); setRetirar(null); }
  async function guardar(quitar = false) {
    const objetivo = quitar ? retirar : actual;
    if (bloqueo.current || (!quitar && !repuesto) || (quitar && !retirar)) return;
    if (!proveedor && (!/^\d{1,10}$/.test(minimo) || Number(minimo) > 2147483647)) { setError("El mínimo debe ser un número entero desde cero hasta 2147483647."); return; }
    if (proveedor && codigo.trim() && !/^[0-9A-Za-z._/ \-]+$/.test(codigo.trim())) { setError("Revisá el código del proveedor: letras, números, espacios, puntos, guiones y barras."); return; }
    bloqueo.current = true; setGuardando(true); onOcupado(true); setError("");
    try {
      if (proveedor) await api.guardarOferta(id, quitar ? retirar!.repuestoId : Number(repuesto), quitar ? retirar!.codigoProveedor : codigo.trim() || null, !quitar, objetivo && "revision" in objetivo ? objetivo.revision : null);
      else await api.guardarMinimo(id, Number(repuesto), Number(minimo), actual && "stockMinimo" in actual ? actual.stockMinimo : null);
      await actualizar(); limpiar(); setOk(quitar ? "Repuesto retirado del catálogo ofrecido. Las compras anteriores se conservan." : proveedor ? "Catálogo del proveedor actualizado." : "Repuesto y mínimo guardados. La existencia se conserva.");
    } catch (e) { setError(mensajeDeError(e)); if (esApiError(e) && e.status === 409) void relaciones.refetch(); }
    finally { bloqueo.current = false; setGuardando(false); onOcupado(false); }
  }
  async function cargarActual() {
    if (!actual) return;
    const resultado = await relaciones.refetch(), r = resultado.data?.find(f => f.repuestoId === actual.repuestoId);
    if (r) editar(r); else setError(resultado.isError ? mensajeDeError(resultado.error) : "La asociación ya no existe. Cancelá la edición y revisá la lista.");
  }
  const columnas: Columna<Relacion>[] = [
    { clave: "repuesto", encabezado: "Repuesto", render: r => <><strong>{r.codigo}</strong><div style={{ overflowWrap: "anywhere" }}>{r.nombre}</div></> },
    ...(proveedor ? [{ clave: "referencia", encabezado: "Código del proveedor", render: (r: Relacion) => "codigoProveedor" in r ? r.codigoProveedor || "—" : "—" }] : [
      { clave: "minimo", encabezado: "Mínimo", numerica: true, render: (r: Relacion) => "stockMinimo" in r ? numero(r.stockMinimo) : "—" },
      { clave: "promedio", encabezado: "Costo promedio", numerica: true, render: (r: Relacion) => "costoPromedio" in r ? quetzales(r.costoPromedio, 6) : "—" },
      { clave: "existencia", encabezado: "Existencia", numerica: true, render: (r: Relacion) => "existencia" in r ? numero(r.existencia) : "—" },
    ]),
    { clave: "activo", encabezado: "Estado", render: r => <EstadoCatalogo activo={r.activo} /> },
    { clave: "acciones", encabezado: "Acciones", render: r => <div className="tc-row" style={{ flexWrap: "wrap" }}>
      <Button tamano="sm" disabled={guardando || !padre.activo || !r.activo} onClick={() => editar(r)}>{proveedor ? "Editar código" : "Editar mínimo"}</Button>
      {proveedor && "codigoProveedor" in r ? <Button tamano="sm" disabled={guardando} onClick={() => { setRetirar(r); setError(""); }}>Retirar</Button> : null}</div> },
  ];
  return <div className="tc-stack" style={{ marginTop: 16 }}>
    {error ? <Alert tono="danger">{error}</Alert> : null}{ok ? <Alert tono="ok">{ok}</Alert> : null}
    {!padre.activo ? <Alert tono="warn">Este registro está inactivo. Reactivalo para agregar o editar asociaciones.</Alert> : null}
    {!proveedor ? <Alert tono="info">El mínimo indica cuándo reponer. La existencia aumenta al recibir compras y disminuye al utilizar repuestos en reparaciones.</Alert> : null}
    {repuestos.isError ? <Alert tono="danger" accion={<Button onClick={() => repuestos.refetch()}>Reintentar</Button>}>{mensajeDeError(repuestos.error)}</Alert> : null}
    <form className="tc-stack" onSubmit={e => { e.preventDefault(); void guardar(); }}>
      <h3 className="tc-section-title">{actual ? "Editar asociación" : proveedor ? "Agregar repuesto ofrecido" : "Asociar repuesto a la bodega"}</h3>
      <Field label="Repuesto" htmlFor="asociacion-repuesto" requerido><SelectInput id="asociacion-repuesto" required disabled={guardando || !!actual || !padre.activo || repuestos.isLoading} value={repuesto} onChange={e => setRepuesto(e.target.value)}>
        <option value="">Elegir repuesto activo</option>{opciones.map(r => <option key={r.repuestoId} value={r.repuestoId}>{r.codigo} · {r.nombre}</option>)}</SelectInput></Field>
      {proveedor ? <Field label="Código del proveedor" htmlFor="asociacion-codigo" hint="Opcional: referencia que utiliza el proveedor para este repuesto."><TextInput id="asociacion-codigo" maxLength={50} disabled={guardando || !padre.activo} value={codigo} onChange={e => setCodigo(e.target.value)} /></Field> :
        <Field label="Stock mínimo" htmlFor="asociacion-minimo" requerido><TextInput id="asociacion-minimo" type="number" min="0" max="2147483647" step="1" required disabled={guardando || !padre.activo} value={minimo} onChange={e => setMinimo(e.target.value)} /></Field>}
      <div className="tc-row" style={{ flexWrap: "wrap" }}><Button type="submit" variante="primario" disabled={guardando || !padre.activo || !repuesto || repuestos.isError}>{guardando ? "Guardando…" : actual ? "Guardar asociación" : "Agregar repuesto"}</Button>
        {actual ? <><Button type="button" disabled={guardando} onClick={limpiar}>Cancelar edición</Button><Button type="button" disabled={guardando} onClick={() => void cargarActual()}>Cargar asociación actual</Button></> : null}</div>
    </form>
    {retirar ? <Alert tono="warn" titulo={`Retirar ${retirar.codigo}`} accion={<div className="tc-row" style={{ flexWrap: "wrap" }}><Button disabled={guardando} onClick={() => setRetirar(null)}>Volver</Button><Button disabled={guardando} onClick={() => void guardar(true)}>Confirmar retiro</Button></div>}>Se quitará del catálogo ofrecido por {padre.nombre}. Las compras registradas se conservan; una compra pendiente impide retirarlo.</Alert> : null}
    {relaciones.isLoading ? <LoadingState titulo="Cargando asociaciones…" /> : relaciones.isError ? <Alert tono="danger" accion={<Button onClick={() => relaciones.refetch()}>Reintentar</Button>}>{mensajeDeError(relaciones.error)}</Alert> :
      <TablaCatalogo filas={filas} columnas={columnas} clave={r => r.repuestoId} vacio="No hay repuestos asociados." />}
  </div>;
}
