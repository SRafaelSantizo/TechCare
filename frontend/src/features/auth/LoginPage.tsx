import { useState, type FormEvent } from "react";
import { Navigate, useLocation, useNavigate } from "react-router-dom";
import { Eye, EyeOff } from "lucide-react";
import { Button } from "../../components/ui/Button";
import { Alert } from "../../components/ui/Alert";
import { Field, TextInput } from "../../components/ui/inputs";
import { LoadingState } from "../../components/ui/StateView";
import { esApiError } from "../../services/errors";
import { useSession } from "../../app/session";

export function LoginPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const sesion = useSession();
  const [nombreUsuario, setNombreUsuario] = useState("");
  const [contrasena, setContrasena] = useState("");
  const [ver, setVer] = useState(false);
  const [enviando, setEnviando] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [errores, setErrores] = useState<Record<string, string>>({});
  const solicitado = (location.state as { from?: string } | null)?.from ?? "/";
  const destino = solicitado.startsWith("/") && !solicitado.startsWith("//") && !solicitado.startsWith("/login") ? solicitado : "/";
  if (sesion.cargando) return <LoadingState titulo="Verificando sesión…" />;
  if (sesion.autenticado) return <Navigate to={destino} replace />;

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (enviando) return;
    setError(null);
    const locales: Record<string, string> = {};
    if (!nombreUsuario.trim() || nombreUsuario.trim().length > 50) locales.nombreUsuario = "Ingresá un usuario de hasta 50 caracteres.";
    if (!contrasena || contrasena.length > 256) locales.contrasena = "Ingresá tu contraseña.";
    setErrores(locales);
    if (Object.keys(locales).length) return;
    setEnviando(true);
    try { await sesion.iniciarSesion(nombreUsuario.trim(), contrasena); navigate(destino, { replace: true }); }
    catch (err) {
      if (esApiError(err)) setErrores(err.fieldErrors);
      setError(err instanceof Error ? err.message : "No se pudo iniciar sesión.");
    } finally { setEnviando(false); }
  }

  return <div className="tc-login"><div className="tc-login__panel">
    <div className="tc-login__brand"><span className="tc-brand__mark" aria-hidden="true">TC</span><div>
      <div className="tc-brand__name">TechCare</div><div className="tc-brand__sub">Servicio técnico, inventario y facturación</div>
    </div></div>
    <h1 style={{ fontSize: "1.6rem", marginBottom: 8 }}>Iniciar sesión</h1>
    <p className="tc-field__hint">Ingresá con tu cuenta del taller.</p>
    {sesion.errorSesion ? <Alert tono="warn" accion={<Button onClick={() => sesion.cargarSesion()}>Reintentar conexión</Button>}>{sesion.errorSesion}</Alert> : null}
    <form onSubmit={onSubmit} noValidate className="tc-stack" style={{ marginTop: 20 }}>
      <Field label="Usuario" htmlFor="login-usuario" requerido error={errores.nombreUsuario}>
        <TextInput id="login-usuario" autoComplete="username" value={nombreUsuario} maxLength={50} onChange={e => setNombreUsuario(e.target.value)} disabled={enviando} />
      </Field>
      <Field label="Contraseña" htmlFor="login-contrasena" requerido error={errores.contrasena}>
        <div className="tc-input-group">
          <TextInput id="login-contrasena" autoComplete="current-password" type={ver ? "text" : "password"} value={contrasena} maxLength={256} onChange={e => setContrasena(e.target.value)} disabled={enviando} />
          <Button variante="fantasma" onClick={() => setVer(v => !v)} icono={ver ? <EyeOff size={16} /> : <Eye size={16} />} aria-label={ver ? "Ocultar contraseña" : "Mostrar contraseña"}>
            <span className="tc-sr-only">{ver ? "Ocultar" : "Mostrar"}</span>
          </Button>
        </div>
      </Field>
      {error ? <Alert tono="danger">{error}</Alert> : null}
      <Button variante="primario" type="submit" bloque disabled={enviando}>{enviando ? "Ingresando…" : "Ingresar"}</Button>
    </form>
  </div></div>;
}
