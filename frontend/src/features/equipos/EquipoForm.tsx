import { useState, type FormEvent } from "react";
import { Alert } from "../../components/ui/Alert";
import { Button } from "../../components/ui/Button";
import { Field, SelectInput, Switch, TextArea, TextInput } from "../../components/ui/inputs";
import { esApiError, mensajeDeError } from "../../services/errors";
import type { MarcaEquipo, TipoEquipo, Equipo, EquipoDatos, ModeloEquipo } from "../../services/equipos";
import type { Cliente } from "../../types/api";

export function EquipoForm({ equipo, clientes, marcas, tipos, modelos, clienteInicial, guardando, onGuardar, onCancelar }: {
  equipo: Equipo | null;
  clientes: Cliente[];
  marcas: MarcaEquipo[];
  tipos: TipoEquipo[];
  modelos: ModeloEquipo[];
  clienteInicial: string;
  guardando: boolean;
  onGuardar: (datos: EquipoDatos) => Promise<void>;
  onCancelar: () => void;
}) {
  const [clienteId, setClienteId] = useState(equipo ? String(equipo.ClienteID) : clienteInicial);
  const [marcaId, setMarcaId] = useState(equipo ? String(equipo.MarcaID) : "");
  const [tipoId, setTipoId] = useState(equipo ? String(equipo.TipoEquipoID) : "");
  const [modeloId, setModeloId] = useState(equipo ? String(equipo.ModeloEquipoID) : "");
  const [serie, setSerie] = useState(equipo?.NumeroSerie ?? "");
  const [descripcion, setDescripcion] = useState(equipo?.Descripcion ?? "");
  const [activo, setActivo] = useState(equipo?.Activo ?? true);
  const [errores, setErrores] = useState<Record<string, string>>({});
  const [mensaje, setMensaje] = useState("");
  const bloqueado = Boolean(equipo?.TieneOrdenes);
  const disponibles = modelos.filter(m => (!marcaId || String(m.MarcaID) === marcaId) && (!tipoId || String(m.TipoEquipoID) === tipoId));

  async function guardar(e: FormEvent) {
    e.preventDefault();
    if (guardando) return;
    const invalidos: Record<string, string> = {};
    if (!Number(clienteId)) invalidos.clienteId = "Elegí un cliente.";
    if (!Number(modeloId)) invalidos.modeloEquipoId = "Elegí un modelo.";
    if (!serie.trim() || serie.trim().length > 80) invalidos.numeroSerie = "Ingresá una serie de hasta 80 caracteres.";
    if (!descripcion.trim() || descripcion.trim().length > 500) invalidos.descripcion = "Ingresá una descripción de hasta 500 caracteres.";
    setErrores(invalidos);
    setMensaje("");
    if (Object.keys(invalidos).length) return;
    try {
      await onGuardar({ clienteId: Number(clienteId), modeloEquipoId: Number(modeloId), numeroSerie: serie.trim(), descripcion: descripcion.trim(), activo });
    } catch (error) {
      if (esApiError(error)) setErrores(error.fieldErrors);
      setMensaje(mensajeDeError(error, "el registro del equipo"));
    }
  }

  return <form className="tc-stack" onSubmit={guardar} noValidate>
    {mensaje ? <Alert tono="danger" titulo="No se pudo guardar">{mensaje}</Alert> : null}
    {bloqueado ? <Alert>Este equipo tiene órdenes registradas. Podés actualizar su descripción y estado; el propietario, la serie y el modelo conservan el historial.</Alert> : null}
    <Field label="Cliente" htmlFor="equipo-cliente" requerido error={errores.clienteId}>
      <SelectInput id="equipo-cliente" value={clienteId} disabled={guardando || bloqueado} onChange={e => setClienteId(e.target.value)}>
        <option value="">Elegir cliente</option>
        {clientes.map(c => <option key={c.ClienteID} value={c.ClienteID} disabled={!c.Activo && c.ClienteID !== equipo?.ClienteID}>
          {c.Nombre} · {c.NIT}{c.Activo ? "" : " · inactivo"}
        </option>)}
      </SelectInput>
    </Field>
    <div className="tc-grid tc-grid--2">
      <Field label="Marca" htmlFor="equipo-marca">
        <SelectInput id="equipo-marca" value={marcaId} disabled={guardando || bloqueado} onChange={e => { setMarcaId(e.target.value); setModeloId(""); }}>
          <option value="">Todas las marcas</option>
          {marcas.map(m => <option key={m.MarcaID} value={m.MarcaID}>{m.Nombre}</option>)}
        </SelectInput>
      </Field>
      <Field label="Tipo" htmlFor="equipo-tipo">
        <SelectInput id="equipo-tipo" value={tipoId} disabled={guardando || bloqueado} onChange={e => { setTipoId(e.target.value); setModeloId(""); }}>
          <option value="">Todos los tipos</option>
          {tipos.map(t => <option key={t.TipoEquipoID} value={t.TipoEquipoID}>{t.Nombre}</option>)}
        </SelectInput>
      </Field>
    </div>
    <Field label="Modelo" htmlFor="equipo-modelo" requerido error={errores.modeloEquipoId}>
      <SelectInput id="equipo-modelo" value={modeloId} disabled={guardando || bloqueado} onChange={e => setModeloId(e.target.value)}>
        <option value="">Elegir modelo</option>
        {disponibles.map(m => <option key={m.ModeloEquipoID} value={m.ModeloEquipoID}>{m.Marca} · {m.Nombre} · {m.TipoEquipo}</option>)}
      </SelectInput>
    </Field>
    {!disponibles.length ? <Alert tono="warn">No hay modelos para estos filtros. Cambiá la marca o el tipo.</Alert> : null}
    <Field label="Número de serie" htmlFor="equipo-serie" requerido error={errores.numeroSerie}>
      <TextInput id="equipo-serie" value={serie} maxLength={80} disabled={guardando || bloqueado} onChange={e => setSerie(e.target.value)} />
    </Field>
    <Field label="Descripción" htmlFor="equipo-descripcion" requerido error={errores.descripcion}>
      <TextArea id="equipo-descripcion" rows={3} value={descripcion} maxLength={500} disabled={guardando} onChange={e => setDescripcion(e.target.value)} />
    </Field>
    <Switch id="equipo-activo" etiqueta="Equipo activo" checked={activo} disabled={guardando} onChange={setActivo} />
    <div className="tc-row tc-row--end">
      <Button onClick={onCancelar} disabled={guardando}>Cancelar</Button>
      <Button variante="primario" type="submit" disabled={guardando}>{guardando ? "Guardando…" : equipo ? "Guardar cambios" : "Registrar equipo"}</Button>
    </div>
  </form>;
}
