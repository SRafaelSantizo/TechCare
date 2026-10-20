import { useState, type FormEvent } from "react";
import { Eye, EyeOff } from "lucide-react";
import { Alert } from "../../components/ui/Alert";
import { Button } from "../../components/ui/Button";
import { Field, SelectInput, Switch, TextInput } from "../../components/ui/inputs";
import { esApiError, mensajeDeError } from "../../services/errors";
import type { EmpleadoDisponible, RegistroUsuario, RolAcceso } from "../../services/usuarios";

export function UsuarioForm({ empleados, rolesDisponibles, guardando, onGuardar, onCancelar }: {
  empleados: EmpleadoDisponible[];
  rolesDisponibles: RolAcceso[];
  guardando: boolean;
  onGuardar: (datos: RegistroUsuario) => Promise<void>;
  onCancelar: () => void;
}) {
  const [tipoEmpleado, setTipoEmpleado] = useState("nuevo");
  const [empleadoId, setEmpleadoId] = useState("");
  const [codigo, setCodigo] = useState("");
  const [nombres, setNombres] = useState("");
  const [apellidos, setApellidos] = useState("");
  const [usuario, setUsuario] = useState("");
  const [contrasena, setContrasena] = useState("");
  const [confirmacion, setConfirmacion] = useState("");
  const [ver, setVer] = useState(false);
  const [roles, setRoles] = useState<string[]>([]);
  const [errores, setErrores] = useState<Record<string, string>>({});
  const [mensaje, setMensaje] = useState("");

  async function guardar(e: FormEvent) {
    e.preventDefault();
    if (guardando) return;
    const invalidos: Record<string, string> = {};
    if (!/^[A-Za-z0-9._-]{3,50}$/.test(usuario.trim())) invalidos.nombreUsuario = "Usá de 3 a 50 letras sin tildes, números, puntos o guiones.";
    if (!contrasena.trim() || contrasena.length < 12 || contrasena.length > 256) invalidos.contrasena = "La contraseña debe tener entre 12 y 256 caracteres.";
    if (contrasena !== confirmacion) invalidos.confirmacion = "Las contraseñas no coinciden.";
    if (!roles.length) invalidos.roles = "Seleccioná al menos un rol.";
    if (tipoEmpleado === "existente") {
      if (!empleados.some(e => e.empleadoId === Number(empleadoId))) invalidos.empleadoId = "Elegí un empleado disponible.";
    } else {
      if (!/^[A-Za-z0-9._-]{1,20}$/.test(codigo.trim())) invalidos["empleadoNuevo.codigo"] = "Ingresá un código de hasta 20 letras sin tildes, números, puntos o guiones.";
      if (!nombres.trim() || nombres.trim().length > 80) invalidos["empleadoNuevo.nombres"] = "Ingresá nombres de hasta 80 caracteres.";
      if (!apellidos.trim() || apellidos.trim().length > 80) invalidos["empleadoNuevo.apellidos"] = "Ingresá apellidos de hasta 80 caracteres.";
    }
    setErrores(invalidos);
    setMensaje("");
    if (Object.keys(invalidos).length) { setMensaje("Revisá los campos indicados antes de guardar."); return; }
    try {
      await onGuardar({ nombreUsuario: usuario.trim(), contrasena, roles,
        empleadoId: tipoEmpleado === "existente" ? Number(empleadoId) : null,
        empleadoNuevo: tipoEmpleado === "nuevo" ? { codigo: codigo.trim(), nombres: nombres.trim(), apellidos: apellidos.trim() } : null });
    } catch (error) {
      if (esApiError(error)) setErrores(error.fieldErrors);
      setMensaje(mensajeDeError(error, "el registro del usuario"));
    }
  }

  return <form className="tc-stack" onSubmit={guardar} noValidate>
    {mensaje ? <Alert tono="danger" titulo="No se pudo registrar">{mensaje}</Alert> : null}
    <Field label="Empleado" htmlFor="usuario-tipo-empleado" requerido>
      <SelectInput id="usuario-tipo-empleado" value={tipoEmpleado} disabled={guardando} onChange={e => setTipoEmpleado(e.target.value)}>
        <option value="nuevo">Registrar empleado nuevo</option>
        <option value="existente">Usar empleado existente</option>
      </SelectInput>
    </Field>
    {tipoEmpleado === "existente" ? <Field label="Empleado disponible" htmlFor="usuario-empleado" requerido error={errores.empleadoId}
      hint={empleados.length ? "Empleados activos que todavía no tienen una cuenta." : "No hay empleados activos sin cuenta. Podés registrar uno nuevo."}>
      <SelectInput id="usuario-empleado" value={empleadoId} disabled={guardando} onChange={e => setEmpleadoId(e.target.value)}>
        <option value="">Elegir empleado</option>
        {empleados.map(e => <option key={e.empleadoId} value={e.empleadoId}>{e.nombres} {e.apellidos} · {e.codigo}</option>)}
      </SelectInput>
    </Field> : <>
      <Field label="Código de empleado" htmlFor="usuario-codigo" requerido error={errores["empleadoNuevo.codigo"]} hint="Usá un código único, por ejemplo EMP-011.">
        <TextInput id="usuario-codigo" value={codigo} maxLength={20} disabled={guardando} onChange={e => setCodigo(e.target.value)} autoComplete="off" />
      </Field>
      <div className="tc-grid tc-grid--2">
        <Field label="Nombres" htmlFor="usuario-nombres" requerido error={errores["empleadoNuevo.nombres"]}>
          <TextInput id="usuario-nombres" value={nombres} maxLength={80} disabled={guardando} onChange={e => setNombres(e.target.value)} autoComplete="off" />
        </Field>
        <Field label="Apellidos" htmlFor="usuario-apellidos" requerido error={errores["empleadoNuevo.apellidos"]}>
          <TextInput id="usuario-apellidos" value={apellidos} maxLength={80} disabled={guardando} onChange={e => setApellidos(e.target.value)} autoComplete="off" />
        </Field>
      </div>
    </>}
    <Field label="Nombre de usuario" htmlFor="usuario-nombre" requerido error={errores.nombreUsuario} hint="Será el nombre que esta persona usará para ingresar.">
      <TextInput id="usuario-nombre" value={usuario} maxLength={50} disabled={guardando} onChange={e => setUsuario(e.target.value)} autoComplete="off" autoCapitalize="none" spellCheck={false} />
    </Field>
    <Field label="Contraseña" htmlFor="usuario-contrasena" requerido error={errores.contrasena} hint="De 12 a 256 caracteres; podés usar espacios y letras con tildes.">
      <div className="tc-input-group">
        <TextInput id="usuario-contrasena" type={ver ? "text" : "password"} value={contrasena} maxLength={256} disabled={guardando} onChange={e => setContrasena(e.target.value)} autoComplete="new-password" />
        <Button variante="fantasma" disabled={guardando} onClick={() => setVer(v => !v)} aria-label={ver ? "Ocultar contraseña" : "Mostrar contraseña"} icono={ver ? <EyeOff size={16} /> : <Eye size={16} />} />
      </div>
    </Field>
    <Field label="Confirmar contraseña" htmlFor="usuario-confirmacion" requerido error={errores.confirmacion}>
      <TextInput id="usuario-confirmacion" type={ver ? "text" : "password"} value={confirmacion} maxLength={256} disabled={guardando} onChange={e => setConfirmacion(e.target.value)} autoComplete="new-password" />
    </Field>
    <fieldset className="tc-stack" disabled={guardando} style={{ border: 0, padding: 0, margin: 0 }}>
      <legend className="tc-field__label">Roles <span className="tc-field__req">*</span></legend>
      <div className="tc-grid tc-grid--2">
        {rolesDisponibles.map(r => <Switch key={r.codigo} id={`usuario-rol-${r.codigo}`} etiqueta={r.nombre} checked={roles.includes(r.codigo)}
          onChange={seleccionado => setRoles(actuales => seleccionado ? [...actuales, r.codigo] : actuales.filter(rol => rol !== r.codigo))} />)}
      </div>
      {errores.roles ? <span className="tc-field__error" role="alert">{errores.roles}</span> : <span className="tc-field__hint">Seleccioná uno o varios según las funciones de la persona.</span>}
    </fieldset>
    <div className="tc-row tc-row--end">
      <Button disabled={guardando} onClick={onCancelar}>Cancelar</Button>
      <Button variante="primario" type="submit" disabled={guardando}>{guardando ? "Registrando…" : "Registrar usuario"}</Button>
    </div>
  </form>;
}
