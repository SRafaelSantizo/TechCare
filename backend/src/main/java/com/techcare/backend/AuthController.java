package com.techcare.backend;

import com.techcare.backend.seguridad.IntentosLogin;
import com.techcare.backend.seguridad.UsuarioAutenticado;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.session.SessionAuthenticationStrategy;
import org.springframework.security.web.context.SecurityContextRepository;
import org.springframework.security.web.csrf.CsrfToken;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

import java.util.List;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
    private final AuthenticationManager manager;
    private final SecurityContextRepository contextRepository;
    private final SessionAuthenticationStrategy sesiones;
    private final IntentosLogin intentos;

    public AuthController(AuthenticationManager manager,SecurityContextRepository contextRepository,
            SessionAuthenticationStrategy sesiones,IntentosLogin intentos) {
        this.manager=manager;
        this.contextRepository=contextRepository;
        this.sesiones=sesiones;
        this.intentos=intentos;
    }

    @GetMapping("/csrf")
    public TokenCsrf csrf(CsrfToken token) { return new TokenCsrf(token.getHeaderName(),token.getToken()); }

    @PostMapping("/login")
    public Sesion login(@Valid @RequestBody LoginDatos datos,HttpServletRequest request,HttpServletResponse response) {
        String direccion=request.getRemoteAddr();
        if (!intentos.permitir(datos.nombreUsuario(),direccion))
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,
                    "Demasiados intentos. Esperá cinco minutos y volvé a intentar.");
        Authentication auth=manager.authenticate(UsernamePasswordAuthenticationToken.unauthenticated(
                datos.nombreUsuario(),datos.contrasena()));
        sesiones.onAuthentication(auth,request,response);
        SecurityContext context=SecurityContextHolder.createEmptyContext();
        context.setAuthentication(auth);
        SecurityContextHolder.setContext(context);
        contextRepository.saveContext(context,request,response);
        intentos.exito(datos.nombreUsuario(),direccion);
        return respuesta((UsuarioAutenticado)auth.getPrincipal());
    }

    @GetMapping("/sesion")
    public Sesion sesion(@AuthenticationPrincipal UsuarioAutenticado usuario) { return respuesta(usuario); }

    private Sesion respuesta(UsuarioAutenticado u) {
        return new Sesion(true,new UsuarioSesion(u.getUsuarioId(),u.getUsername(),
                u.getNombreCompleto(),u.getEmpleadoCodigo()),u.getRoles());
    }

    public record LoginDatos(
            @NotBlank(message="El usuario es obligatorio.") @Size(max=50,message="El usuario admite hasta 50 caracteres.") String nombreUsuario,
            @NotBlank(message="La contraseña es obligatoria.") @Size(max=256,message="La contraseña es demasiado larga.") String contrasena) {
        public LoginDatos { nombreUsuario=nombreUsuario==null ? null : nombreUsuario.strip(); }
    }
    public record TokenCsrf(String headerName,String token) {}
    public record UsuarioSesion(int usuarioId,String nombreUsuario,String nombreCompleto,String empleadoCodigo) {}
    public record Sesion(boolean autenticado,UsuarioSesion usuario,List<String> roles) {}
}
