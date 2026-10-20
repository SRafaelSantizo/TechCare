package com.techcare.backend.seguridad;

import org.springframework.security.core.CredentialsContainer;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.io.Serial;
import java.util.Collection;
import java.util.List;

public final class UsuarioAutenticado implements UserDetails, CredentialsContainer {
    @Serial private static final long serialVersionUID = 1L;
    private final int usuarioId;
    private final String nombreUsuario;
    private final String nombreCompleto;
    private final String empleadoCodigo;
    private final List<String> roles;
    private final boolean habilitado;
    private transient String password;

    public UsuarioAutenticado(int usuarioId, String nombreUsuario, String nombreCompleto,
                              String empleadoCodigo, List<String> roles, boolean habilitado, String password) {
        this.usuarioId=usuarioId;
        this.nombreUsuario=nombreUsuario;
        this.nombreCompleto=nombreCompleto;
        this.empleadoCodigo=empleadoCodigo;
        this.roles=List.copyOf(roles);
        this.habilitado=habilitado;
        this.password=password;
    }

    public int getUsuarioId() { return usuarioId; }
    public String getNombreCompleto() { return nombreCompleto; }
    public String getEmpleadoCodigo() { return empleadoCodigo; }
    public List<String> getRoles() { return roles; }
    @Override public String getUsername() { return nombreUsuario; }
    @Override public String getPassword() { return password; }
    @Override public boolean isEnabled() { return habilitado && !roles.isEmpty(); }
    @Override public Collection<? extends GrantedAuthority> getAuthorities() {
        return roles.stream().map(rol -> new SimpleGrantedAuthority("ROLE_"+rol)).toList();
    }
    @Override public void eraseCredentials() { password=null; }
}
