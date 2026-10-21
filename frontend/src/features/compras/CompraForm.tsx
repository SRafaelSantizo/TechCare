import { useRef, useState, type FormEvent } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Alert } from "../../components/ui/Alert";
import { Button } from "../../components/ui/Button";
import { Field, SelectInput, TextArea, TextInput } from "../../components/ui/inputs";
import { LoadingState } from "../../components/ui/StateView";
import { abastecimientoApi } from "../../services/abastecimiento";
import { comprasApi, centavos, decimalCentavos, quetzales, type Compra, type RegistroCompra } from "../../services/compras";
import { esApiError, mensajeDeError } from "../../services/errors";

type Fila = { clave: string; repuesto: string; bodega: string; cantidad: string; costo: string };
const nueva = (): Fila => ({ clave: crypto.randomUUID(), repuesto: "", bodega: "", cantidad: "1", costo: "" });
const costoValido = (v: string) => /^\d{1,10}(?:\.\d{1,2})?$/.test(v);
const subtotal = (f: Fila) => costoValido(f.costo) && /^\d{1,10}$/.test(f.cantidad) ? centavos(f.costo) * BigInt(f.cantidad) : 0n;
export function CompraForm({ onOcupado, onGuardado, onCancelar }: { onOcupado: (v: boolean) => void; onGuardado: (c: Compra) => void; onCancelar: () => void }) {
  const [numero, setNumero] = useState(""), [proveedor, setProveedor] = useState(""), [observaciones, setObservaciones] = useState("");
  const [filas, setFilas] = useState<Fila[]>(() => [nueva()]), [revision, setRevision] = useState<RegistroCompra | null>(null);
  const [error, setError] = useState(""), [guardando, setGuardando] = useState(false), [incierto, setIncierto] = useState(false);
  const bloqueo = useRef(false), qc = useQueryClient();
  const proveedores = useQuery({ queryKey: ["abastecimiento", "proveedores", "compra"], queryFn: ({ signal }) => abastecimientoApi.proveedores("", true, signal) });
  const destinos = useQuery({ queryKey: ["compras", "destinos", proveedor], queryFn: ({ signal }) => comprasApi.destinos(Number(proveedor), signal), enabled: !!proveedor });
  const opciones = [...new Map((destinos.data ?? []).map(d => [d.repuestoId, d])).values()];
  const total = decimalCentavos(filas.reduce((s, f) => s + subtotal(f), 0n));
  function cambiar(clave: string, datos: Partial<Fila>) { setFilas(fs => fs.map(f => f.clave === clave ? { ...f, ...datos } : f)); }
  function revisar(e: FormEvent) {
    e.preventDefault(); setError("");
    if (!/^[0-9A-Za-z._/\-]{1,30}$/.test(numero.trim()) || !proveedor || !filas.length) { setError("Revisá el número de compra, proveedor y detalle."); return; }
    const pares = new Set<string>();
    for (const f of filas) {
      if (!destinos.data?.some(d => String(d.repuestoId) === f.repuesto && String(d.bodegaId) === f.bodega) || !/^\d{1,10}$/.test(f.cantidad) || Number(f.cantidad) < 1 || Number(f.cantidad) > 2147483647 || !costoValido(f.costo)) { setError("Completá repuesto, bodega, cantidad entera positiva y costo de hasta dos decimales en cada línea."); return; }
      const par = `${f.repuesto}:${f.bodega}`; if (pares.has(par)) { setError("No repitás el mismo repuesto y bodega en dos líneas."); return; } pares.add(par);
    }
    setRevision({ solicitudId: crypto.randomUUID(), numeroCompra: numero.trim(), proveedorId: Number(proveedor), observaciones: observaciones.trim() || null,
      detalle: filas.map(f => ({ repuestoId: Number(f.repuesto), bodegaId: Number(f.bodega), cantidad: Number(f.cantidad), costoUnitario: f.costo })) });
  }
  async function guardar() {
    if (!revision || bloqueo.current) return; bloqueo.current = true; setGuardando(true); onOcupado(true); setError("");
    try {
      const r = await comprasApi.registrar(revision);
      await Promise.all([qc.invalidateQueries({ queryKey: ["compras"] }), qc.invalidateQueries({ queryKey: ["abastecimiento"] })]);
      onGuardado(r);
    } catch (e) { setError(mensajeDeError(e)); setIncierto(!esApiError(e) || e.status === 0 || e.status >= 500); }
    finally { bloqueo.current = false; setGuardando(false); onOcupado(false); }
  }
  return <div className="tc-stack" style={{ marginTop: 16 }}>
    {error ? <Alert tono="danger">{error}</Alert> : null}
    {revision ? <>
      <Alert tono="info">Revisá la compra antes de registrarla. Quedará pendiente hasta confirmar que llegaron todas las unidades.</Alert>
      <dl className="tc-dl"><dt>Número</dt><dd>{revision.numeroCompra}</dd><dt>Proveedor</dt><dd>{proveedores.data?.find(p => p.proveedorId === revision.proveedorId)?.nombre}</dd><dt>Total de compra</dt><dd>{quetzales(total)}</dd><dt>Observaciones</dt><dd style={{ whiteSpace: "pre-wrap", overflowWrap: "anywhere" }}>{revision.observaciones || "—"}</dd></dl>
      {filas.map((f, i) => { const d = destinos.data?.find(d => String(d.repuestoId) === f.repuesto && String(d.bodegaId) === f.bodega); return <div key={f.clave} className="tc-card" style={{ padding: 16 }}><strong>{i + 1}. {d?.codigo} · {d?.repuesto}</strong><div>{d?.bodega} · {f.cantidad} unidades × {quetzales(f.costo)} = {quetzales(decimalCentavos(subtotal(f)))}</div></div>; })}
      {incierto ? <Alert tono="warn">El registro no pudo confirmarse. Reintentá esta misma compra o cerrá y consultá el listado para comprobar si quedó registrada.</Alert> : null}
      <div className="tc-row" style={{ flexWrap: "wrap" }}><Button variante="primario" disabled={guardando} onClick={() => void guardar()}>{guardando ? "Registrando…" : incierto ? "Reintentar registro" : "Registrar compra pendiente"}</Button>
        <Button disabled={guardando || incierto} onClick={() => { setRevision(null); setError(""); }}>Editar compra</Button><Button disabled={guardando} onClick={onCancelar}>Cerrar</Button></div>
    </> : <form className="tc-stack" onSubmit={revisar}>
      <div className="tc-grid tc-grid--2"><Field label="Número de compra" htmlFor="compra-numero" requerido hint="Referencia única, por ejemplo COM-0021."><TextInput id="compra-numero" data-autofocus required maxLength={30} value={numero} onChange={e => setNumero(e.target.value)} /></Field>
        <Field label="Proveedor" htmlFor="compra-proveedor" requerido hint="Cambiar el proveedor limpia las líneas de esta compra."><SelectInput id="compra-proveedor" required disabled={proveedores.isLoading || proveedores.isError} value={proveedor} onChange={e => { setProveedor(e.target.value); setFilas([nueva()]); }}><option value="">Elegir proveedor activo</option>{proveedores.data?.map(p => <option key={p.proveedorId} value={p.proveedorId}>{p.nombre} · {p.nit}</option>)}</SelectInput></Field></div>
      {proveedores.isError ? <Alert tono="danger" accion={<Button type="button" onClick={() => proveedores.refetch()}>Reintentar proveedores</Button>}>{mensajeDeError(proveedores.error)}</Alert> : null}
      {destinos.isLoading && proveedor ? <LoadingState titulo="Cargando repuestos y bodegas…" /> : destinos.isError ? <Alert tono="danger" accion={<Button type="button" onClick={() => destinos.refetch()}>Reintentar destinos</Button>}>{mensajeDeError(destinos.error)}</Alert> : proveedor && destinos.data?.length === 0 ? <Alert tono="warn">No hay destinos disponibles. En Proveedores, agregá los repuestos al catálogo ofrecido; en Bodegas, asocialos a su destino. Proveedor, repuesto y bodega deben estar activos.</Alert> : null}
      {filas.map((f, i) => <div key={f.clave} className="tc-card tc-stack" style={{ padding: 16 }}>
        <div className="tc-row"><strong style={{ flex: 1 }}>Línea {i + 1}</strong><Button type="button" tamano="sm" disabled={filas.length === 1} onClick={() => setFilas(fs => fs.filter(v => v.clave !== f.clave))}>Quitar línea</Button></div>
        <div className="tc-grid tc-grid--2"><Field label={`Repuesto ${i + 1}`} htmlFor={`rep-${f.clave}`} requerido><SelectInput id={`rep-${f.clave}`} required disabled={!proveedor || destinos.isLoading || destinos.isError} value={f.repuesto} onChange={e => cambiar(f.clave, { repuesto: e.target.value, bodega: "" })}><option value="">Elegir repuesto ofrecido</option>{opciones.map(d => <option key={d.repuestoId} value={d.repuestoId}>{d.codigo} · {d.repuesto}</option>)}</SelectInput></Field>
          <Field label={`Bodega ${i + 1}`} htmlFor={`bod-${f.clave}`} requerido><SelectInput id={`bod-${f.clave}`} required disabled={!f.repuesto} value={f.bodega} onChange={e => cambiar(f.clave, { bodega: e.target.value })}><option value="">Elegir bodega asociada</option>{destinos.data?.filter(d => String(d.repuestoId) === f.repuesto).map(d => <option key={d.bodegaId} value={d.bodegaId}>{d.bodega} · Existencia {d.existencia}</option>)}</SelectInput></Field></div>
        <div className="tc-grid tc-grid--2"><Field label={`Cantidad ${i + 1}`} htmlFor={`cant-${f.clave}`} requerido><TextInput id={`cant-${f.clave}`} type="number" required min="1" max="2147483647" step="1" value={f.cantidad} onChange={e => cambiar(f.clave, { cantidad: e.target.value })} /></Field>
          <Field label={`Costo unitario ${i + 1} (Q)`} htmlFor={`costo-${f.clave}`} requerido hint="Costo pagado al proveedor por cada unidad; puede ser cero."><TextInput id={`costo-${f.clave}`} type="number" required min="0" max="9999999999.99" step="0.01" value={f.costo} onChange={e => cambiar(f.clave, { costo: e.target.value })} /></Field></div>
        <div>Importe: <strong>{quetzales(decimalCentavos(subtotal(f)))}</strong></div>
      </div>)}
      <Button type="button" disabled={filas.length >= 200 || !destinos.data?.length} onClick={() => setFilas(fs => [...fs, nueva()])}>Agregar línea</Button>
      <Field label="Observaciones de compra" htmlFor="compra-observaciones"><TextArea id="compra-observaciones" rows={3} maxLength={1000} value={observaciones} onChange={e => setObservaciones(e.target.value)} /></Field>
      <div className="tc-row" style={{ flexWrap: "wrap" }}><strong style={{ flex: 1 }}>Total: {quetzales(total)}</strong><Button type="button" onClick={onCancelar}>Volver</Button><Button type="submit" variante="primario" disabled={!proveedor || destinos.isFetching || destinos.isError || !destinos.data?.length}>Revisar compra</Button></div>
    </form>}
  </div>;
}
