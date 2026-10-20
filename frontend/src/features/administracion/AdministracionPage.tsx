import { useMemo, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { UserPlus } from "lucide-react";
import { Alert } from "../../components/ui/Alert";
import { Badge } from "../../components/ui/Badge";
import { Button } from "../../components/ui/Button";
import { Card, PageHeader } from "../../components/ui/Card";
import { DataTable, Paginacion, type Columna } from "../../components/ui/DataTable";
import { Dialog } from "../../components/ui/Dialog";
import { Field, SearchInput, SelectInput } from "../../components/ui/inputs";
import { ErrorState, LoadingState } from "../../components/ui/StateView";
import { mensajeDeError } from "../../services/errors";
import { usuariosApi, type RegistroUsuario, type UsuarioAdministracion } from "../../services/usuarios";
import { normalizar } from "../../utils/format";
import { UsuarioForm } from "./UsuarioForm";

const POR_PAGINA = 10;

export function AdministracionPage() {
  const [abierto, setAbierto] = useState(false);
  const [busqueda, setBusqueda] = useState("");
  const [rol, setRol] = useState("");
  const [pagina, setPagina] = useState(1);
  const [mensaje, setMensaje] = useState("");
  const [guardando, setGuardando] = useState(false);
  const qc = useQueryClient();
  const usuarios = useQuery({ queryKey: ["admin", "usuarios"], queryFn: ({ signal }) => usuariosApi.listar(signal) });
  const roles = useQuery({ queryKey: ["admin", "roles"], queryFn: ({ signal }) => usuariosApi.roles(signal) });
  const empleados = useQuery({ queryKey: ["admin", "empleados"], queryFn: ({ signal }) => usuariosApi.empleados(signal), enabled: abierto });
  async function guardar(datos: RegistroUsuario) {
    if (guardando) return;
    setGuardando(true);
    try {
      const usuario = await usuariosApi.registrar(datos);
      setMensaje(`Se creó la cuenta «${usuario.nombreUsuario}». Ya puede iniciar sesión con los roles asignados.`);
      setAbierto(false);
      await Promise.all([qc.invalidateQueries({ queryKey: ["admin", "usuarios"] }), qc.invalidateQueries({ queryKey: ["admin", "empleados"] })]);
    } finally { setGuardando(false); }
  }
  const filtrados = useMemo(() => {
    const texto = normalizar(busqueda);
    return (usuarios.data ?? []).filter(u => (!rol || u.roles.includes(rol)) && (!texto || normalizar(`${u.nombreUsuario} ${u.empleadoCodigo} ${u.nombres} ${u.apellidos}`).includes(texto)));
  }, [usuarios.data, busqueda, rol]);
  const paginas = Math.max(1, Math.ceil(filtrados.length / POR_PAGINA));
  const actual = Math.min(pagina, paginas);
  const nombresRoles = new Map((roles.data ?? []).map(r => [r.codigo, r.nombre]));
  const columnas: Columna<UsuarioAdministracion>[] = [
    { clave: "usuario", encabezado: "Usuario", render: u => <strong>{u.nombreUsuario}</strong> },
    { clave: "empleado", encabezado: "Empleado", render: u => <><div>{u.nombres} {u.apellidos}</div><div className="tc-field__hint">{u.empleadoCodigo}</div></> },
    { clave: "roles", encabezado: "Roles", render: u => <div className="tc-row">{u.roles.map(r => <Badge key={r}>{nombresRoles.get(r) ?? r}</Badge>)}</div> },
    { clave: "estado", encabezado: "Estado", render: u => <Badge tono={u.usuarioActivo && u.empleadoActivo ? "ok" : "neutral"}>{u.usuarioActivo && u.empleadoActivo ? "Activo" : "Inactivo"}</Badge> },
  ];
  const cerrar = () => { if (!guardando) setAbierto(false); };

  return <>
    <PageHeader eyebrow="Personal del taller" titulo="Administración" descripcion="Cuentas de acceso del personal y sus roles."
      acciones={<Button variante="primario" icono={<UserPlus size={16} />} disabled={guardando || !roles.data?.length} onClick={() => { setMensaje(""); setAbierto(true); }}>Nuevo usuario</Button>} />
    <div className="tc-stack">
      {mensaje ? <Alert tono="ok">{mensaje}</Alert> : null}
      {roles.isError ? <Alert tono="danger" accion={<Button onClick={() => roles.refetch()}>Reintentar</Button>}>{mensajeDeError(roles.error, "los roles")}</Alert> : null}
      <Card>
        <div className="tc-grid tc-grid--2">
          <Field label="Buscar usuario o empleado" htmlFor="usuarios-busqueda"><SearchInput id="usuarios-busqueda" value={busqueda} onChange={e => { setBusqueda(e.target.value); setPagina(1); }} placeholder="Nombre, usuario o código" /></Field>
          <Field label="Rol" htmlFor="usuarios-rol"><SelectInput id="usuarios-rol" value={rol} onChange={e => { setRol(e.target.value); setPagina(1); }}><option value="">Todos los roles</option>{(roles.data ?? []).map(r => <option key={r.codigo} value={r.codigo}>{r.nombre}</option>)}</SelectInput></Field>
        </div>
      </Card>
      <Card>
        {usuarios.isPending ? <LoadingState titulo="Cargando usuarios…" /> : usuarios.isError ? <ErrorState mensaje={mensajeDeError(usuarios.error, "los usuarios")} onRetry={() => usuarios.refetch()} /> : <>
          <DataTable columnas={columnas} filas={filtrados.slice((actual - 1) * POR_PAGINA, actual * POR_PAGINA)} claveFila={u => u.usuarioId} vacio="No hay usuarios para esta búsqueda." />
          <Paginacion pagina={actual} totalPaginas={paginas} total={filtrados.length} onCambiar={setPagina} />
        </>}
      </Card>
    </div>
    <Dialog abierto={abierto} titulo="Nuevo usuario" descripcion="Registrá la cuenta y asigná sus roles." onCerrar={cerrar} ancho={640}>
      {empleados.isPending ? <LoadingState titulo="Cargando empleados…" /> : empleados.isError ? <ErrorState mensaje={mensajeDeError(empleados.error, "los empleados")} onRetry={() => empleados.refetch()} /> : abierto && roles.data ?
        <UsuarioForm empleados={empleados.data ?? []} rolesDisponibles={roles.data} guardando={guardando} onGuardar={guardar} onCancelar={cerrar} /> : null}
    </Dialog>
  </>;
}
