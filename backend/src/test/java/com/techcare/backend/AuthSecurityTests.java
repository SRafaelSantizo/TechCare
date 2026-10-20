package com.techcare.backend;

import com.jayway.jsonpath.JsonPath;
import com.techcare.backend.seguridad.UsuarioAutenticado;
import jakarta.servlet.http.Cookie;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.web.context.HttpSessionSecurityContextRepository;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties="spring.datasource.url=jdbc:sqlserver://localhost:1433;databaseName=TechCare;encrypt=false")
class AuthSecurityTests {
    private static final String HASH="$pbkdf2-sha256$600000$HuxZL8PtNPKcYu8utgbkoQ==$NmPYFGhLXt0tyvkysSHHNFjQMIFqSF/tSTU66h3jzik=";
    @Autowired WebApplicationContext context;
    @MockitoBean JdbcTemplate jdbc;
    private MockMvc mvc;

    @BeforeEach void preparar() {
        reset(jdbc);
        mvc=MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
        when(jdbc.queryForList(anyString(),any(Object[].class))).thenAnswer(inv -> {
            String sql=inv.getArgument(0);
            Object[] args=(Object[])inv.getRawArguments()[1];
            if (sql.equals("EXEC dbo.spConsultarAcceso ?")) {
                String usuario=(String)args[0];
                if (usuario.equals("errorBD")) throw new DataAccessResourceFailureException("Detalle interno no público");
                if (usuario.startsWith("inexistente")) return List.of();
                Map<String,Object> u=usuario(usuario);
                if (usuario.equals("multirrol")) {
                    Map<String,Object> segundo=new HashMap<>(u);segundo.put("RolCodigo","CAJA");
                    return List.of(u,segundo,u);
                }
                return List.of(u);
            }
            if (sql.contains("spRegistrarCliente") || sql.contains("spActualizarCliente") || sql.contains("spConsultarCliente"))
                return List.of(Map.of("ClienteID",7,"Nombre","Prueba","Activo",true));
            if (sql.contains("spRegistrarEquipo") || sql.contains("spActualizarEquipo") || sql.contains("spConsultarEquipo"))
                return List.of(Map.of("EquipoID",7,"Activo",true));
            return List.of();
        });
        when(jdbc.queryForList(anyString())).thenReturn(List.of());
    }

    private Map<String,Object> usuario(String nombre) {
        Map<String,Object> u=new HashMap<>();
        u.put("UsuarioID",2);u.put("EmpleadoID",2);u.put("NombreUsuario",nombre);
        u.put("PasswordHash",HASH);u.put("AlgoritmoHash","PBKDF2_SHA256");
        u.put("UsuarioActivo",!nombre.equals("inactivo"));u.put("EmpleadoActivo",!nombre.equals("empleadoInactivo"));
        u.put("EmpleadoCodigo","EMP-002");u.put("Nombres","Usuario");u.put("Apellidos","Prueba");
        u.put("RolCodigo",nombre.equals("sinRol") ? null : switch(nombre) {
            case "ADMIN","TECNICO","BODEGA","CAJA" -> nombre;
            default -> "RECEPCION";
        });
        return u;
    }

    private record Token(MockHttpSession sesion,String valor) {}
    private Token csrf(MockHttpSession sesion) throws Exception {
        var request=get("/api/auth/csrf");
        if (sesion!=null) request.session(sesion);
        MvcResult r=mvc.perform(request).andExpect(status().isOk()).andReturn();
        return new Token((MockHttpSession)r.getRequest().getSession(false),JsonPath.read(r.getResponse().getContentAsString(),"$.token"));
    }
    private MockHttpSession login(String usuario) throws Exception {
        Token t=csrf(null);
        mvc.perform(post("/api/auth/login").session(t.sesion).header("X-CSRF-TOKEN",t.valor)
                .contentType("application/json").content("{\"nombreUsuario\":\""+usuario+"\",\"contrasena\":\"TechCare2026!\"}"))
                .andExpect(status().isOk());
        return t.sesion;
    }

    @Test void sinSesionResponde401JsonYNoRedirecciona() throws Exception {
        mvc.perform(get("/api/clientes")).andExpect(status().isUnauthorized()).andExpect(jsonPath("$.estado").value(401))
                .andExpect(header().doesNotExist("Location"));
        mvc.perform(get("/api/auth/sesion")).andExpect(status().isUnauthorized());
        verifyNoInteractions(jdbc);
    }

    @Test void loginRotaLaSesionYDevuelveSoloIdentidadYRoles() throws Exception {
        Token t=csrf(null);String anterior=t.sesion.getId();
        mvc.perform(post("/api/auth/login").session(t.sesion).header("X-CSRF-TOKEN",t.valor).contentType("application/json")
                .content("{\"nombreUsuario\":\"  demo02  \",\"contrasena\":\"TechCare2026!\",\"roles\":[\"ADMIN\"],\"usuarioId\":1}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.usuario.usuarioId").value(2))
                .andExpect(jsonPath("$.roles[0]").value("RECEPCION"))
                .andExpect(jsonPath("$.PasswordHash").doesNotExist()).andExpect(jsonPath("$.contrasena").doesNotExist())
                .andExpect(header().string("Cache-Control",org.hamcrest.Matchers.containsString("no-store")));
        assertNotEquals(anterior,t.sesion.getId());
        SecurityContext c=(SecurityContext)t.sesion.getAttribute(HttpSessionSecurityContextRepository.SPRING_SECURITY_CONTEXT_KEY);
        assertNull(((UsuarioAutenticado)c.getAuthentication().getPrincipal()).getPassword());
        verify(jdbc).queryForList("EXEC dbo.spConsultarAcceso ?","demo02");
        verifyNoMoreInteractions(jdbc);
    }

    @Test void restauraSesionYConservaTodosLosRolesSinReenviarCredenciales() throws Exception {
        MockHttpSession s=login("multirrol");
        clearInvocations(jdbc);
        mvc.perform(get("/api/auth/sesion").session(s)).andExpect(status().isOk())
                .andExpect(jsonPath("$.autenticado").value(true)).andExpect(jsonPath("$.roles.length()").value(2));
        verifyNoInteractions(jdbc);
    }

    @ParameterizedTest @ValueSource(strings={"inexistente01","inactivo","empleadoInactivo","sinRol"})
    void noRevelaSiLaCuentaExisteOEstaInactiva(String nombre) throws Exception {
        Token t=csrf(null);
        mvc.perform(post("/api/auth/login").session(t.sesion).header("X-CSRF-TOKEN",t.valor).contentType("application/json")
                .content("{\"nombreUsuario\":\""+nombre+"\",\"contrasena\":\"TechCare2026!\"}"))
                .andExpect(status().isUnauthorized()).andExpect(jsonPath("$.mensaje").value("Usuario o contraseña incorrectos."));
        assertNull(t.sesion.getAttribute(HttpSessionSecurityContextRepository.SPRING_SECURITY_CONTEXT_KEY));
    }

    @Test void contrasenaIncorrectaNoCreaUnaSesionAutenticada() throws Exception {
        Token t=csrf(null);
        mvc.perform(post("/api/auth/login").session(t.sesion).header("X-CSRF-TOKEN",t.valor).contentType("application/json")
                .content("{\"nombreUsuario\":\"demo02\",\"contrasena\":\"incorrecta\"}"))
                .andExpect(status().isUnauthorized()).andExpect(jsonPath("$.mensaje").value("Usuario o contraseña incorrectos."));
        mvc.perform(get("/api/auth/sesion").session(t.sesion)).andExpect(status().isUnauthorized());
    }

    @Test void loginSinCsrfSeRechazaAntesDeConsultarLaBD() throws Exception {
        mvc.perform(post("/api/auth/login").contentType("application/json").content("{\"nombreUsuario\":\"demo02\",\"contrasena\":\"TechCare2026!\"}"))
                .andExpect(status().isForbidden()).andExpect(jsonPath("$.codigo").value("CSRF_INVALIDO"));
        verifyNoInteractions(jdbc);
    }

    @Test void datosInvalidosSeRechazanSinConsultarLaBD() throws Exception {
        Token t=csrf(null);
        mvc.perform(post("/api/auth/login").session(t.sesion).header("X-CSRF-TOKEN",t.valor).contentType("application/json").content("{}"))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.errores.nombreUsuario").exists());
        verifyNoInteractions(jdbc);
    }

    @Test void errorDeBDNoSeConfundeConContrasenaIncorrectaNiExponeDetalle() throws Exception {
        Token t=csrf(null);
        mvc.perform(post("/api/auth/login").session(t.sesion).header("X-CSRF-TOKEN",t.valor).contentType("application/json")
                .content("{\"nombreUsuario\":\"errorBD\",\"contrasena\":\"TechCare2026!\"}"))
                .andExpect(status().isServiceUnavailable()).andExpect(content().string(org.hamcrest.Matchers.not(org.hamcrest.Matchers.containsString("Detalle interno"))));
    }

    @ParameterizedTest @ValueSource(strings={"ADMIN","RECEPCION","TECNICO","CAJA","BODEGA"})
    void permisosSeCompruebanEnElServidor(String rol) throws Exception {
        MockHttpSession s=login(rol);
        boolean escribe=rol.equals("ADMIN") || rol.equals("RECEPCION");
        boolean leeClientes=!rol.equals("BODEGA");
        boolean leeEquipos=escribe || rol.equals("TECNICO");
        mvc.perform(get("/api/clientes").session(s)).andExpect(status().is(leeClientes ? 200 : 403));
        mvc.perform(get("/api/equipos").session(s)).andExpect(status().is(leeEquipos ? 200 : 403));
        Token t=csrf(s);
        String cliente="{\"tipoClienteId\":1,\"nit\":\"TEST\",\"nombre\":\"Cliente\",\"activo\":true}";
        String equipo="{\"clienteId\":1,\"modeloEquipoId\":1,\"numeroSerie\":\"TEST\",\"descripcion\":\"Prueba\",\"activo\":true}";
        mvc.perform(post("/api/clientes").session(s).header("X-CSRF-TOKEN",t.valor).contentType("application/json").content(cliente))
                .andExpect(status().is(escribe ? 201 : 403));
        mvc.perform(put("/api/clientes/7").session(s).header("X-CSRF-TOKEN",t.valor).contentType("application/json").content(cliente))
                .andExpect(status().is(escribe ? 200 : 403));
        mvc.perform(post("/api/equipos").session(s).header("X-CSRF-TOKEN",t.valor).contentType("application/json").content(equipo))
                .andExpect(status().is(escribe ? 201 : 403));
        mvc.perform(put("/api/equipos/7").session(s).header("X-CSRF-TOKEN",t.valor).contentType("application/json").content(equipo))
                .andExpect(status().is(escribe ? 200 : 403));
    }

    @Test void csrfAnteriorNoSirveDespuesDeIniciarSesion() throws Exception {
        Token t=csrf(null);
        mvc.perform(post("/api/auth/login").session(t.sesion).header("X-CSRF-TOKEN",t.valor).contentType("application/json")
                .content("{\"nombreUsuario\":\"demo02\",\"contrasena\":\"TechCare2026!\"}")).andExpect(status().isOk());
        mvc.perform(post("/api/clientes").session(t.sesion).header("X-CSRF-TOKEN",t.valor).contentType("application/json").content("{}"))
                .andExpect(status().isForbidden()).andExpect(jsonPath("$.codigo").value("CSRF_INVALIDO"));
    }

    @Test void logoutInvalidaLaSesionYExigeCsrf() throws Exception {
        MockHttpSession s=login("demo02");
        mvc.perform(post("/api/auth/logout").session(s)).andExpect(status().isForbidden());
        Token t=csrf(s);
        mvc.perform(post("/api/auth/logout").session(s).header("X-CSRF-TOKEN",t.valor)).andExpect(status().isOk())
                .andExpect(jsonPath("$.autenticado").value(false)).andExpect(cookie().maxAge("JSESSIONID",0));
        assertTrue(s.isInvalid());
        mvc.perform(get("/api/auth/sesion").cookie(new Cookie("JSESSIONID",s.getId()))).andExpect(status().isUnauthorized());
    }

    @Test void demasiadosIntentosDevuelven429() throws Exception {
        Token t=csrf(null);
        for (int i=0;i<10;i++) mvc.perform(post("/api/auth/login").session(t.sesion).header("X-CSRF-TOKEN",t.valor)
                .contentType("application/json").content("{\"nombreUsuario\":\"inexistenteLimite\",\"contrasena\":\"incorrecta\"}"))
                .andExpect(status().isUnauthorized());
        clearInvocations(jdbc);
        mvc.perform(post("/api/auth/login").session(t.sesion).header("X-CSRF-TOKEN",t.valor)
                .contentType("application/json").content("{\"nombreUsuario\":\"inexistenteLimite\",\"contrasena\":\"incorrecta\"}"))
                .andExpect(status().isTooManyRequests());
        verifyNoInteractions(jdbc);
    }
}
