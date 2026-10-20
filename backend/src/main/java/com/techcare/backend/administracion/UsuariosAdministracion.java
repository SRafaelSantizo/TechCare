package com.techcare.backend.administracion;

import org.springframework.dao.DataRetrievalFailureException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

@Service
public class UsuariosAdministracion {
    private final JdbcTemplate jdbc;
    private final PasswordEncoder encoder;

    public UsuariosAdministracion(JdbcTemplate jdbc, PasswordEncoder encoder) {
        this.jdbc = jdbc;
        this.encoder = encoder;
    }

    public List<UsuarioResumen> listar(int actor, Integer id) {
        return jdbc.queryForList("EXEC dbo.spListarUsuarios ?, ?", actor, id).stream().map(this::resumen).toList();
    }

    public UsuarioResumen registrar(int actor, RegistroUsuario datos) {
        RegistroUsuario.EmpleadoNuevo empleado = datos.empleadoNuevo();
        String hash = encoder.encode(datos.contrasena());
        List<Map<String, Object>> filas = jdbc.queryForList("EXEC dbo.spRegistrarUsuario ?, ?, ?, ?, ?, ?, ?, ?",
                actor, datos.empleadoId(), empleado == null ? null : empleado.codigo(),
                empleado == null ? null : empleado.nombres(), empleado == null ? null : empleado.apellidos(),
                datos.nombreUsuario(), hash, String.join(",", datos.roles()));
        if (filas.size() != 1) throw new DataRetrievalFailureException("El procedimiento no devolvió el usuario registrado.");
        return resumen(filas.get(0));
    }

    public List<RolAcceso> roles(int actor) {
        return jdbc.queryForList("EXEC dbo.spListarRolesAcceso ?", actor).stream()
                .map(r -> new RolAcceso((String) r.get("Codigo"), (String) r.get("Nombre"))).toList();
    }

    public List<EmpleadoDisponible> empleados(int actor) {
        return jdbc.queryForList("EXEC dbo.spListarEmpleadosDisponibles ?", actor).stream()
                .map(e -> new EmpleadoDisponible(((Number) e.get("EmpleadoID")).intValue(),
                        (String) e.get("Codigo"), (String) e.get("Nombres"), (String) e.get("Apellidos"))).toList();
    }

    private UsuarioResumen resumen(Map<String, Object> fila) {
        if (!(fila.get("UsuarioID") instanceof Number id) || !(fila.get("EmpleadoID") instanceof Number empleado))
            throw new DataRetrievalFailureException("El procedimiento devolvió un usuario incompleto.");
        Object fecha = fila.get("FechaCreacion");
        LocalDateTime creacion = fecha instanceof Timestamp timestamp ? timestamp.toLocalDateTime()
                : fecha instanceof LocalDateTime local ? local : null;
        List<String> roles = fila.get("Roles") instanceof String texto && !texto.isBlank()
                ? Arrays.stream(texto.split(",")).distinct().sorted().toList() : List.of();
        // DTO explícito: jamás serializar PasswordHash, AlgoritmoHash ni una fila JDBC completa.
        return new UsuarioResumen(id.intValue(), empleado.intValue(), (String) fila.get("EmpleadoCodigo"),
                (String) fila.get("Nombres"), (String) fila.get("Apellidos"), (String) fila.get("NombreUsuario"),
                Boolean.TRUE.equals(fila.get("UsuarioActivo")), Boolean.TRUE.equals(fila.get("EmpleadoActivo")),
                creacion, roles);
    }

    public record UsuarioResumen(int usuarioId, int empleadoId, String empleadoCodigo, String nombres,
            String apellidos, String nombreUsuario, boolean usuarioActivo, boolean empleadoActivo,
            LocalDateTime fechaCreacion, List<String> roles) {}
    public record RolAcceso(String codigo, String nombre) {}
    public record EmpleadoDisponible(int empleadoId, String codigo, String nombres, String apellidos) {}
}
