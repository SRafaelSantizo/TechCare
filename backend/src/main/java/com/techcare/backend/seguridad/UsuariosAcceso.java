package com.techcare.backend.seguridad;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

@Service
public class UsuariosAcceso implements UserDetailsService {
    private final JdbcTemplate jdbc;
    public UsuariosAcceso(JdbcTemplate jdbc) { this.jdbc=jdbc; }

    @Override public UserDetails loadUserByUsername(String nombre) {
        List<Map<String,Object>> filas=jdbc.queryForList("EXEC dbo.spConsultarAcceso ?",nombre);
        if (filas.isEmpty()) throw new UsernameNotFoundException("Acceso no válido.");
        Map<String,Object> u=filas.get(0);
        if (!"PBKDF2_SHA256".equals(u.get("AlgoritmoHash")))
            throw new UsernameNotFoundException("Acceso no válido.");
        List<String> roles=filas.stream().map(f -> (String) f.get("RolCodigo"))
                .filter(r -> r!=null && !r.isBlank()).distinct().sorted().toList();
        return new UsuarioAutenticado(((Number)u.get("UsuarioID")).intValue(),
                (String)u.get("NombreUsuario"),u.get("Nombres")+" "+u.get("Apellidos"),
                (String)u.get("EmpleadoCodigo"),roles,
                Boolean.TRUE.equals(u.get("UsuarioActivo")) && Boolean.TRUE.equals(u.get("EmpleadoActivo")),
                (String)u.get("PasswordHash"));
    }
}
