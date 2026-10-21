import { useRef, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Alert } from "../../components/ui/Alert";
import { Button } from "../../components/ui/Button";
import { Field, TextInput } from "../../components/ui/inputs";
import { LoadingState } from "../../components/ui/StateView";
import { abastecimientoApi as api, type CategoriaRepuesto } from "../../services/abastecimiento";
import { esApiError, mensajeDeError } from "../../services/errors";
import { TablaCatalogo, useActualizarAbastecimiento } from "./compartidos";

export function CategoriasPanel({ onOcupado }: { onOcupado: (v: boolean) => void }) {
  const categorias = useQuery({ queryKey: ["abastecimiento", "categorias"], queryFn: ({ signal }) => api.categorias(signal) });
  const [actual, setActual] = useState<CategoriaRepuesto | null>(null), [nombre, setNombre] = useState("");
  const [guardando, setGuardando] = useState(false), [error, setError] = useState(""), [ok, setOk] = useState("");
  const bloqueo = useRef(false), actualizar = useActualizarAbastecimiento();
  async function guardar() {
    if (bloqueo.current || !nombre.trim()) return; bloqueo.current = true; setGuardando(true); onOcupado(true); setError("");
    try { await api.guardarCategoria(actual?.categoriaId ?? null, nombre.trim(), actual?.revision ?? null); await actualizar(); setActual(null); setNombre(""); setOk("Categoría guardada."); }
    catch (e) { setError(mensajeDeError(e)); if (esApiError(e) && e.status === 409) void categorias.refetch(); } finally { bloqueo.current = false; setGuardando(false); onOcupado(false); }
  }
  return <div className="tc-stack" style={{ marginTop: 16 }}>
    {error ? <Alert tono="danger">{error}</Alert> : null}{ok ? <Alert tono="ok">{ok}</Alert> : null}
    <form className="tc-row" style={{ flexWrap: "wrap", alignItems: "end" }} onSubmit={e => { e.preventDefault(); void guardar(); }}>
      <Field label={actual ? "Editar categoría" : "Nueva categoría"} htmlFor="categoria-nombre" requerido><TextInput id="categoria-nombre" required maxLength={80} disabled={guardando} value={nombre} onChange={e => setNombre(e.target.value)} data-autofocus /></Field>
      <Button type="submit" variante="primario" disabled={guardando}>{guardando ? "Guardando…" : actual ? "Guardar categoría" : "Crear categoría"}</Button>
      {actual ? <Button type="button" disabled={guardando} onClick={() => { setActual(null); setNombre(""); setError(""); }}>Cancelar edición</Button> : null}
    </form>
    {categorias.isLoading ? <LoadingState /> : categorias.isError ? <Alert tono="danger" accion={<Button onClick={() => categorias.refetch()}>Reintentar</Button>}>{mensajeDeError(categorias.error)}</Alert> :
      <TablaCatalogo filas={categorias.data ?? []} clave={c => c.categoriaId} columnas={[{ clave: "nombre", encabezado: "Categoría", render: c => c.nombre }, { clave: "editar", encabezado: "Acción", render: c => <Button tamano="sm" disabled={guardando} onClick={() => { setActual(c); setNombre(c.nombre); setError(""); }}>Editar</Button> }]} />}
  </div>;
}
