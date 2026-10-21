import { useMemo, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { UserPlus } from "lucide-react";
import { Alert } from "../../components/ui/Alert";
import { Badge } from "../../components/ui/Badge";
import { Button } from "../../components/ui/Button";
import { Card, PageHeader } from "../../components/ui/Card";
import { DataTable, Paginacion, type Columna } from "../../components/ui/DataTable";
import { Dialog } from "../../components/ui/Dialog";
import { SearchInput, SelectInput } from "../../components/ui/inputs";
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
      setMensaje(`Se creó la cuenta ${usuario.nombreUsuario}. Ya puede iniciar sesión con los roles asignados.`);
      setAbierto(false);
      await Promise.all([qc.invalidateQueries({ queryKey: ["admin", "usuarios"] }), qc.invalidateQueries({ queryKey: ["admin", "empleados"] })]);
    } finally {
      setGuardando(false);
    }
  }

  const filtrados = useMemo(() => {
    const q = normalizar(busqueda);
    return (usuarios.data ?? []).filter((u) => {
      if (rol && !u.roles.includes(rol)) return false;
      if (!q) return true;
      const nombreCompleto = `${u.nombres} ${u.apellidos}`;
      return (
        normalizar(nombreCompleto).includes(q) ||
        normalizar(u.nombreUsuario).includes(q) ||
        normalizar(u.empleadoCodigo).includes(q)
      );
    });
  }, [usuarios.data, busqueda, rol]);

  const totalPaginas = Math.max(1, Math.ceil(filtrados.length / POR_PAGINA));
  const paginaActual = Math.min(pagina, totalPaginas);
  const visibles = filtrados.slice((paginaActual - 1) * POR_PAGINA, paginaActual * POR_PAGINA);

  const columnas: Array<Columna<UsuarioAdministracion>> = [
    { clave: "usuario", encabezado: "Usuario", render: (u) => <strong style={{ fontWeight: 500 }}>{u.nombreUsuario}</strong> },
    { clave: "nombre", encabezado: "Nombre completo", render: (u) => `${u.nombres} ${u.apellidos}` },
    { clave: "empleado", encabezado: "Código empleado", render: (u) => u.empleadoCodigo },
    { clave: "roles", encabezado: "Roles", render: (u) => (
      <div className="tc-row" style={{ gap: 6, flexWrap: "wrap" }}>
        {u.roles.map((r) => <Badge key={r} tono="neutral">{r}</Badge>)}
      </div>
    ) },
    { clave: "estado", encabezado: "Estado", render: (u) => <Badge tono={u.usuarioActivo && u.empleadoActivo ? "ok" : "neutral"}>{u.usuarioActivo && u.empleadoActivo ? "Activo" : "Inactivo"}</Badge> },
  ];

  return (
    <>
      <PageHeader
        eyebrow="Administración"
        titulo="Usuarios y roles"
        descripcion="Registro de cuentas para el personal. Los roles se aplican en el servidor según la política vigente."
        acciones={
          <Button variante="primario" icono={<UserPlus size={16} />} onClick={() => { setMensaje(""); setAbierto(true); }}>
            Nueva cuenta
          </Button>
        }
      />

      <div className="tc-stack">
        {mensaje ? <Alert tono="ok">{mensaje}</Alert> : null}
        <Card flush>
          <div style={{ padding: "24px 24px 16px" }}>
            <div className="tc-row">
              <div style={{ flex: 1, minWidth: 220 }}>
                <SearchInput placeholder="Buscar por usuario, nombre o código" value={busqueda} onChange={(e) => { setBusqueda(e.target.value); setPagina(1); }} />
              </div>
              <SelectInput value={rol} onChange={(e) => { setRol(e.target.value); setPagina(1); }} style={{ width: 200 }}>
                <option value="">Todos los roles</option>
                {(roles.data ?? []).map((r) => <option key={r.codigo} value={r.codigo}>{r.nombre}</option>)}
              </SelectInput>
            </div>
          </div>

          {usuarios.isLoading ? <LoadingState titulo="Cargando usuarios..." /> : usuarios.isError ? <ErrorState mensaje={mensajeDeError(usuarios.error, "los usuarios")} onRetry={() => usuarios.refetch()} /> : filtrados.length === 0 ? <ErrorState titulo="Sin resultados" mensaje="No hay cuentas que coincidan con los filtros." /> : (
            <>
              <DataTable columnas={columnas} filas={visibles} claveFila={(u) => u.usuarioId} caption={`Mostrando ${visibles.length} de ${filtrados.length} usuarios`} />
              <div style={{ padding: "16px 24px 24px" }}>
                <Paginacion pagina={paginaActual} totalPaginas={totalPaginas} total={filtrados.length} onCambiar={setPagina} />
              </div>
            </>
          )}
        </Card>
      </div>

      <Dialog abierto={abierto} titulo="Nueva cuenta" descripcion="Asigna un empleado sin cuenta, usuario, contraseña y roles." onCerrar={() => setAbierto(false)} ancho={720}>
        {roles.isError ? <Alert tono="danger">{mensajeDeError(roles.error, "los roles")}</Alert> : null}
        {empleados.isError ? <Alert tono="danger">{mensajeDeError(empleados.error, "los empleados sin cuenta")}</Alert> : null}
        <UsuarioForm
          empleados={empleados.data ?? []}
          rolesDisponibles={roles.data ?? []}
          guardando={guardando}
          onGuardar={guardar}
          onCancelar={() => setAbierto(false)}
        />
      </Dialog>
    </>
  );
}

