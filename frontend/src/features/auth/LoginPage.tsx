import { useState, type FormEvent } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { Eye, EyeOff, ShieldAlert } from "lucide-react";
import { Button } from "../../components/ui/Button";
import { Alert } from "../../components/ui/Alert";
import { Field, TextInput } from "../../components/ui/inputs";
import { useSession } from "../../app/session";
import { ROLES } from "../../services/catalogos";
import { Badge } from "../../components/ui/Badge";

export function LoginPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const sesion = useSession();
  const [nombreUsuario, setNombreUsuario] = useState("");
  const [contrasena, setContrasena] = useState("");
  const [ver, setVer] = useState(false);
  const [enviando, setEnviando] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const destino = (location.state as { from?: string } | null)?.from ?? "/dashboard";

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setEnviando(true);
    try {
      await sesion.iniciarSesion(nombreUsuario, contrasena);
      navigate(destino, { replace: true });
    } catch (err) {
      setError(err instanceof Error ? err.message : "No se pudo iniciar sesion.");
    } finally {
      setEnviando(false);
    }
  }

  return (
    <div className="tc-login">
      <div className="tc-login__panel">
        <div className="tc-login__brand">
          <span className="tc-brand__mark" aria-hidden="true">
            TC
          </span>
          <div>
            <div className="tc-brand__name">TechCare</div>
            <div className="tc-brand__sub">Servicio tecnico, inventario y facturacion</div>
          </div>
        </div>

        <Alert tono="info" titulo="Acceso en preparacion">
          El inicio de sesion del personal todavia no esta disponible: el servidor aun no expone el servicio de
          autenticacion. La interfaz queda lista para conectarse.
        </Alert>

        <form onSubmit={onSubmit} noValidate className="tc-stack" style={{ marginTop: 16 }}>
          <Field label="Usuario" htmlFor="login-usuario" requerido>
            <TextInput
              id="login-usuario"
              autoComplete="username"
              value={nombreUsuario}
              onChange={(e) => setNombreUsuario(e.target.value)}
              placeholder="demo01"
              disabled={enviando}
            />
          </Field>

          <Field label="Contrasena" htmlFor="login-contrasena" requerido>
            <div className="tc-input-group">
              <TextInput
                id="login-contrasena"
                type={ver ? "text" : "password"}
                autoComplete="current-password"
                value={contrasena}
                onChange={(e) => setContrasena(e.target.value)}
                disabled={enviando}
              />
              <Button
                variante="fantasma"
                onClick={() => setVer((v) => !v)}
                icono={ver ? <EyeOff size={16} /> : <Eye size={16} />}
                aria-label={ver ? "Ocultar contrasena" : "Mostrar contrasena"}
              >
                <span className="tc-sr-only">{ver ? "Ocultar" : "Mostrar"}</span>
              </Button>
            </div>
          </Field>

          {error ? <Alert tono="danger">{error}</Alert> : null}

          <Button variante="primario" type="submit" bloque disabled={enviando}>
            {enviando ? "Ingresando…" : "Ingresar"}
          </Button>
        </form>

        <hr className="tc-divider" />

        <div className="tc-stack" style={{ gap: 10 }}>
          <div className="tc-row" style={{ gap: 8 }}>
            <ShieldAlert size={16} aria-hidden="true" />
            <span className="tc-field__hint">Roles de la consigna (aun no exigidos por el servidor)</span>
          </div>
          <div className="tc-row" style={{ gap: 6 }}>
            {ROLES.map((r) => (
              <Badge key={r.codigo} tono="neutral">
                {r.nombre}
              </Badge>
            ))}
          </div>
          <Button
            variante="secundario"
            bloque
            onClick={() => {
              sesion.continuarSinAutenticar();
              navigate(destino, { replace: true });
            }}
          >
            Continuar sin autenticar (desarrollo)
          </Button>
          <p className="tc-field__hint">
            El modo sin autenticar no otorga permisos: solo permite revisar la interfaz y los modulos con API
            disponible.
          </p>
        </div>
      </div>
    </div>
  );
}
