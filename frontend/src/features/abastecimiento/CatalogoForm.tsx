import { useRef, useState, type FormEvent } from "react";
import { useQuery } from "@tanstack/react-query";
import { Alert } from "../../components/ui/Alert";
import { Button } from "../../components/ui/Button";
import { Field, TextInput, TextArea, SelectInput, Switch } from "../../components/ui/inputs";
import { LoadingState } from "../../components/ui/StateView";
import { abastecimientoApi as api, idCatalogo, type TipoCatalogo, type RegistroCatalogo } from "../../services/abastecimiento";
import { esApiError, mensajeDeError } from "../../services/errors";
import { useActualizarAbastecimiento } from "./compartidos";

export function CatalogoForm({ tipo, registro, onGuardado, onCancelar, onRecargar, onOcupado }: {
  tipo: TipoCatalogo; registro: RegistroCatalogo | null; onGuardado: (r: RegistroCatalogo) => void; onCancelar: () => void; onRecargar: (r: RegistroCatalogo) => void;
  onOcupado: (v: boolean) => void;
}) {
  const [codigo, setCodigo] = useState(registro && "codigo" in registro ? registro.codigo : "");
  const [nombre, setNombre] = useState(registro?.nombre ?? ""), [activo, setActivo] = useState(registro?.activo ?? true);
  const [categoria, setCategoria] = useState(registro && "categoriaId" in registro ? String(registro.categoriaId) : "");
  const [descripcion, setDescripcion] = useState(registro && "descripcion" in registro ? registro.descripcion ?? "" : "");
  const [costo] = useState(registro && "costoReferencia" in registro ? String(registro.costoReferencia) : "0.00");
  const [precio, setPrecio] = useState(registro && "precioVenta" in registro ? String(registro.precioVenta) : "0.00");
  const [nit, setNit] = useState(registro && "nit" in registro ? registro.nit : "");
  const [email, setEmail] = useState(registro && "email" in registro ? registro.email ?? "" : "");
  const [telefono, setTelefono] = useState(registro && "telefono" in registro ? registro.telefono ?? "" : "");
  const [direccion, setDireccion] = useState(registro && "direccion" in registro ? registro.direccion ?? "" : "");
  const [error, setError] = useState(""), [conflicto, setConflicto] = useState(false), [guardando, setGuardando] = useState(false);
  const bloqueo = useRef(false), actualizar = useActualizarAbastecimiento();
  const categorias = useQuery({ queryKey: ["abastecimiento", "categorias"], queryFn: ({ signal }) => api.categorias(signal), enabled: tipo === "repuestos" });
  const id = registro ? idCatalogo(registro) : null;
  async function guardar(e: FormEvent) {
    e.preventDefault(); if (bloqueo.current) return;
    if (tipo !== "proveedores" && !/^[0-9A-Za-z._/\-]+$/.test(codigo.trim())) { setError("El código admite letras, números, puntos, guiones, guiones bajos y barras, sin espacios."); return; }
    if (tipo === "proveedores" && !/^[0-9A-Za-z-]+$/.test(nit.trim())) { setError("El NIT admite letras, números y guiones."); return; }
    if (tipo === "repuestos" && (![costo, precio].every(v => /^\d{1,10}(?:\.\d{1,2})?$/.test(v.trim())) || !categoria)) { setError("Elegí categoría e ingresá un precio desde cero, con hasta dos decimales."); return; }
    bloqueo.current = true; setGuardando(true); onOcupado(true); setError(""); setConflicto(false);
    const revision = registro?.revision ?? null;
    try {
      const datos = { nombre: nombre.trim(), activo, revision };
      const r = tipo === "repuestos" ? await api.guardarRepuesto(id, { ...datos, codigo: codigo.trim(), categoriaId: Number(categoria), descripcion: descripcion.trim() || null, costoReferencia: costo.trim(), precioVenta: precio.trim() })
        : tipo === "proveedores" ? await api.guardarProveedor(id, { ...datos, nit: nit.trim(), email: email.trim() || null, telefono: telefono.trim() || null, direccion: direccion.trim() || null })
          : await api.guardarBodega(id, { ...datos, codigo: codigo.trim(), direccion: direccion.trim() || null });
      await actualizar(); onGuardado(r);
    } catch (e) { setError(mensajeDeError(e)); setConflicto(esApiError(e) && e.status === 409); }
    finally { bloqueo.current = false; setGuardando(false); onOcupado(false); }
  }
  async function recargar() {
    if (!id || bloqueo.current) return; bloqueo.current = true; setGuardando(true); onOcupado(true);
    try { onRecargar(tipo === "repuestos" ? await api.repuesto(id) : tipo === "proveedores" ? await api.proveedor(id) : await api.bodega(id)); }
    catch (e) { setError(mensajeDeError(e)); } finally { bloqueo.current = false; setGuardando(false); onOcupado(false); }
  }
  return <form className="tc-stack" style={{ marginTop: 16 }} onSubmit={e => void guardar(e)}>
    {error ? <Alert tono="danger">{error}</Alert> : null}
    {conflicto && registro ? <Alert tono="warn" accion={<Button type="button" disabled={guardando} onClick={() => void recargar()}>Cargar datos actuales</Button>}>Podés conservar lo escrito o cargar la versión guardada para revisarla. Cargarla reemplaza este formulario.</Alert> : null}
    {tipo === "repuestos" ? categorias.isLoading ? <LoadingState titulo="Cargando categorías…" /> : categorias.isError ? <Alert tono="danger" accion={<Button type="button" onClick={() => categorias.refetch()}>Reintentar</Button>}>{mensajeDeError(categorias.error)}</Alert> :
      <Field label="Categoría" htmlFor="cat-categoria" requerido><SelectInput id="cat-categoria" required disabled={guardando} value={categoria} onChange={e => setCategoria(e.target.value)}><option value="">Elegir categoría</option>{categorias.data?.map(c => <option key={c.categoriaId} value={c.categoriaId}>{c.nombre}</option>)}</SelectInput></Field> : null}
    <div className="tc-grid tc-grid--2">
      {tipo === "proveedores" ? <Field label="NIT" htmlFor="cat-nit" requerido><TextInput id="cat-nit" required maxLength={20} disabled={guardando} value={nit} onChange={e => setNit(e.target.value)} data-autofocus /></Field> :
        <Field label="Código" htmlFor="cat-codigo" requerido hint="Código único, sin espacios."><TextInput id="cat-codigo" required maxLength={tipo === "repuestos" ? 30 : 20} disabled={guardando} value={codigo} onChange={e => setCodigo(e.target.value)} data-autofocus /></Field>}
      <Field label="Nombre" htmlFor="cat-nombre" requerido><TextInput id="cat-nombre" required maxLength={tipo === "proveedores" ? 150 : 100} disabled={guardando} value={nombre} onChange={e => setNombre(e.target.value)} /></Field>
    </div>
    {tipo === "repuestos" ? <>
      <Field label="Descripción" htmlFor="cat-descripcion"><TextArea id="cat-descripcion" maxLength={500} rows={3} disabled={guardando} value={descripcion} onChange={e => setDescripcion(e.target.value)} /></Field>
      <div className="tc-grid tc-grid--2"><Field label="Precio de venta (Q)" htmlFor="cat-precio" requerido><TextInput id="cat-precio" type="number" min="0" max="9999999999.99" step="0.01" required disabled={guardando} value={precio} onChange={e => setPrecio(e.target.value)} /></Field></div>
      <p className="tc-field__hint">El costo promedio se calcula por bodega desde las compras recibidas. Consultalo en Costos por bodega; los consumos y facturas anteriores conservan sus importes.</p>
    </> : <>
      {tipo === "proveedores" ? <div className="tc-grid tc-grid--2"><Field label="Correo" htmlFor="cat-email"><TextInput id="cat-email" type="email" maxLength={254} disabled={guardando} value={email} onChange={e => setEmail(e.target.value)} /></Field>
        <Field label="Teléfono" htmlFor="cat-telefono"><TextInput id="cat-telefono" maxLength={25} disabled={guardando} value={telefono} onChange={e => setTelefono(e.target.value)} /></Field></div> : null}
      <Field label="Dirección" htmlFor="cat-direccion"><TextArea id="cat-direccion" maxLength={250} rows={3} disabled={guardando} value={direccion} onChange={e => setDireccion(e.target.value)} /></Field>
    </>}
    <Switch id="cat-activo" etiqueta={tipo === "repuestos" ? "Repuesto activo" : tipo === "proveedores" ? "Proveedor activo" : "Bodega activa"} checked={activo} onChange={setActivo} disabled={guardando} />
    {!activo ? <Alert tono="warn">Se conserva el historial. Reactivá el registro para utilizarlo en nuevas operaciones.</Alert> : null}
    <div className="tc-row tc-row--end" style={{ flexWrap: "wrap" }}><Button type="button" disabled={guardando} onClick={onCancelar}>Volver</Button>
      <Button type="submit" variante="primario" disabled={guardando || (tipo === "repuestos" && (!categorias.data?.length || categorias.isError))}>{guardando ? "Guardando…" : registro ? "Guardar cambios" : "Registrar"}</Button></div>
  </form>;
}
