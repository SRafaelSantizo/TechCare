package com.techcare.backend.administracion;

import com.techcare.backend.administracion.UsuariosAdministracion.EmpleadoDisponible;
import com.techcare.backend.administracion.UsuariosAdministracion.RolAcceso;
import com.techcare.backend.administracion.UsuariosAdministracion.UsuarioResumen;
import com.techcare.backend.seguridad.UsuarioAutenticado;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

import java.net.URI;
import java.util.List;

@RestController
@RequestMapping("/api/admin")
public class UsuarioAdminController {
    private final UsuariosAdministracion usuarios;

    public UsuarioAdminController(UsuariosAdministracion usuarios) { this.usuarios = usuarios; }

    @GetMapping("/usuarios")
    public List<UsuarioResumen> listar(@AuthenticationPrincipal UsuarioAutenticado actor) {
        return usuarios.listar(actor.getUsuarioId(), null);
    }

    @GetMapping("/usuarios/{id}")
    public UsuarioResumen consultar(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable("id") int id) {
        if (id <= 0) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El identificador debe ser positivo.");
        List<UsuarioResumen> filas = usuarios.listar(actor.getUsuarioId(), id);
        if (filas.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "El usuario no existe.");
        return filas.get(0);
    }

    @PostMapping("/usuarios")
    public ResponseEntity<UsuarioResumen> registrar(@AuthenticationPrincipal UsuarioAutenticado actor,
            @Valid @RequestBody RegistroUsuario datos) {
        UsuarioResumen usuario = usuarios.registrar(actor.getUsuarioId(), datos);
        return ResponseEntity.created(URI.create("/api/admin/usuarios/" + usuario.usuarioId())).body(usuario);
    }

    @GetMapping("/roles")
    public List<RolAcceso> roles(@AuthenticationPrincipal UsuarioAutenticado actor) {
        return usuarios.roles(actor.getUsuarioId());
    }

    @GetMapping("/empleados-disponibles")
    public List<EmpleadoDisponible> empleados(@AuthenticationPrincipal UsuarioAutenticado actor) {
        return usuarios.empleados(actor.getUsuarioId());
    }
}
