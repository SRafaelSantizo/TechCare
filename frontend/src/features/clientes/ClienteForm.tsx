import { useState, type FormEvent } from "react";
import { Field, SelectInput, Switch, TextArea, TextInput } from "../../components/ui/inputs";
import { Button } from "../../components/ui/Button";
import { Alert } from "../../components/ui/Alert";
import { TIPOS_CLIENTE } from "../../services/catalogos";
import { esApiError, mensajeDeError } from "../../services/errors";
import type { Cliente, ClienteDatos } from "../../types/api";

interface FormState {
  tipoClienteId: string;
  nit: string;
  nombre: string;
  email: string;
  telefono: string;
  direccion: string;
  activo: boolean;
}

/** Validacion que replica las restricciones del DTO ClienteDatos del backend. */
function validar(f: FormState): Record<string, string> {
  const errores: Record<string, string> = {};
  const tipo = Number(f.tipoClienteId);
  if (!tipo || tipo < 1 || tipo > 255) errores.tipoClienteId = "Elegi un tipo de cliente valido.";
  if (!f.nit.trim()) errores.nit = "El NIT es obligatorio.";
  else if (f.nit.trim().length > 20) errores.nit = "El NIT admite hasta 20 caracteres.";
  if (!f.nombre.trim()) errores.nombre = "El nombre es obligatorio.";
  else if (f.nombre.trim().length > 150) errores.nombre = "El nombre admite hasta 150 caracteres.";
  if (f.email.trim() && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(f.email.trim()))
    errores.email = "El correo no tiene un formato valido.";
  else if (f.email.trim().length > 254) errores.email = "El correo admite hasta 254 caracteres.";
  if (f.telefono.trim().length > 25) errores.telefono = "El telefono admite hasta 25 caracteres.";
  if (f.direccion.trim().length > 250) errores.direccion = "La direccion admite hasta 250 caracteres.";
  return errores;
}

function aDatos(f: FormState): ClienteDatos {
  return {
    tipoClienteId: Number(f.tipoClienteId),
    nit: f.nit.trim(),
    nombre: f.nombre.trim(),
    email: f.email.trim() || null,
    telefono: f.telefono.trim() || null,
    direccion: f.direccion.trim() || null,
    activo: f.activo,
  };
}

function inicial(cliente?: Cliente | null): FormState {
  return {
    tipoClienteId: cliente ? String(cliente.TipoClienteID) : "1",
    nit: cliente?.NIT ?? "",
    nombre: cliente?.Nombre ?? "",
    email: cliente?.Email ?? "",
    telefono: cliente?.Telefono ?? "",
    direccion: cliente?.Direccion ?? "",
    activo: cliente?.Activo ?? true,
  };
}

export function ClienteForm({
  cliente,
  guardando,
  onGuardar,
  onCancelar,
}: {
  cliente?: Cliente | null;
  guardando: boolean;
  onGuardar: (datos: ClienteDatos) => Promise<void>;
  onCancelar: () => void;
}) {
  const [form, setForm] = useState<FormState>(() => inicial(cliente));
  const [errores, setErrores] = useState<Record<string, string>>({});
  const [mensaje, setMensaje] = useState<string | null>(null);

  function set<K extends keyof FormState>(clave: K, valor: FormState[K]) {
    setForm((prev) => ({ ...prev, [clave]: valor }));
    setErrores((prev) => {
      if (!(clave in prev)) return prev;
      const copia = { ...prev };
      delete copia[clave];
      return copia;
    });
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setMensaje(null);
    const locales = validar(form);
    if (Object.keys(locales).length > 0) {
      setErrores(locales);
      return;
    }
    try {
      // Se conservan los campos si el servidor rechaza la operacion.
      await onGuardar(aDatos(form));
    } catch (error) {
      if (esApiError(error)) {
        setErrores(error.fieldErrors);
        setMensaje(error.message);
      } else {
        setMensaje(mensajeDeError(error, "el registro del cliente"));
      }
    }
  }

  const idBase = cliente ? `cli-${cliente.ClienteID}` : "cli-nuevo";

  return (
    <form onSubmit={onSubmit} noValidate className="tc-stack">
      {mensaje ? <Alert tono="danger" titulo="No se pudo guardar">{mensaje}</Alert> : null}

      <div className="tc-grid tc-grid--2">
        <Field label="Tipo de cliente" htmlFor={`${idBase}-tipo`} requerido error={errores.tipoClienteId}>
          <SelectInput
            id={`${idBase}-tipo`}
            value={form.tipoClienteId}
            invalido={Boolean(errores.tipoClienteId)}
            onChange={(e) => set("tipoClienteId", e.target.value)}
          >
            {TIPOS_CLIENTE.map((t) => (
              <option key={t.id} value={t.id}>
                {t.nombre}
              </option>
            ))}
          </SelectInput>
        </Field>

        <Field
          label="NIT"
          htmlFor={`${idBase}-nit`}
          requerido
          error={errores.nit}
          hint="Unico en el sistema. Hasta 20 caracteres."
        >
          <TextInput
            id={`${idBase}-nit`}
            value={form.nit}
            maxLength={20}
            invalido={Boolean(errores.nit)}
            onChange={(e) => set("nit", e.target.value)}
          />
        </Field>
      </div>

      <Field label="Nombre o razon social" htmlFor={`${idBase}-nombre`} requerido error={errores.nombre}>
        <TextInput
          id={`${idBase}-nombre`}
          value={form.nombre}
          maxLength={150}
          invalido={Boolean(errores.nombre)}
          onChange={(e) => set("nombre", e.target.value)}
        />
      </Field>

      <div className="tc-grid tc-grid--2">
        <Field
          label="Correo electronico"
          htmlFor={`${idBase}-email`}
          error={errores.email}
          hint="Opcional segun el modelo de datos."
        >
          <TextInput
            id={`${idBase}-email`}
            type="email"
            value={form.email}
            maxLength={254}
            invalido={Boolean(errores.email)}
            onChange={(e) => set("email", e.target.value)}
          />
        </Field>

        <Field label="Telefono" htmlFor={`${idBase}-telefono`} error={errores.telefono} hint="Hasta 25 caracteres.">
          <TextInput
            id={`${idBase}-telefono`}
            value={form.telefono}
            maxLength={25}
            invalido={Boolean(errores.telefono)}
            onChange={(e) => set("telefono", e.target.value)}
          />
        </Field>
      </div>

      <Field label="Direccion" htmlFor={`${idBase}-direccion`} error={errores.direccion}>
        <TextArea
          id={`${idBase}-direccion`}
          value={form.direccion}
          maxLength={250}
          rows={2}
          invalido={Boolean(errores.direccion)}
          onChange={(e) => set("direccion", e.target.value)}
        />
      </Field>

      <Switch
        id={`${idBase}-activo`}
        etiqueta="Cliente activo"
        checked={form.activo}
        onChange={(v) => set("activo", v)}
      />

      <div className="tc-row tc-row--end">
        <Button variante="fantasma" onClick={onCancelar} disabled={guardando}>
          Cancelar
        </Button>
        <Button variante="primario" type="submit" disabled={guardando} data-autofocus>
          {guardando ? "Guardando…" : cliente ? "Guardar cambios" : "Registrar cliente"}
        </Button>
      </div>
    </form>
  );
}
