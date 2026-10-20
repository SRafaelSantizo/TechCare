package com.techcare.backend.administracion;

import com.techcare.backend.seguridad.UsuarioAutenticado;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.UncategorizedSQLException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.RequestPostProcessor;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties = "spring.datasource.url=jdbc:sqlserver://localhost:1433;databaseName=TechCare;encrypt=false")
class UsuarioAdminTests {
    private static final String SQL_ALTA = "EXEC dbo.spRegistrarUsuario ?, ?, ?, ?, ?, ?, ?, ?";
    private static final String CLAVE = "  Contraseña ágil 2026!  ";
    private static final String DATOS = """
            {"nombreUsuario":"  nueva.cuenta  ","contrasena":"  Contraseña ágil 2026!  ",
             "roles":["TECNICO","CAJA"],"empleadoId":null,
             "empleadoNuevo":{"codigo":" EMP-011 ","nombres":" María José ","apellidos":" Pérez López "},
             "usuarioActorID":999,"passwordHash":"valor enviado por el cliente"}
            """;

    @Autowired WebApplicationContext context;
    @Autowired PasswordEncoder encoder;
    @MockitoBean JdbcTemplate jdbc;
    private MockMvc mvc;
    private final List<Object[]> altas = new ArrayList<>();

    @BeforeEach void preparar() {
        reset(jdbc);
        altas.clear();
        mvc = MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
        when(jdbc.queryForList(anyString(), any(Object[].class))).thenAnswer(inv -> {
            String sql = inv.getArgument(0);
            Object[] args = (Object[]) inv.getRawArguments()[1];
            if (sql.equals(SQL_ALTA)) {
                altas.add(args.clone());
                return List.of(fila(args[1] == null ? 77 : ((Number) args[1]).intValue(), (String) args[6]));
            }
            if (sql.equals("EXEC dbo.spListarUsuarios ?, ?")) return List.of(fila(77, "HASH_PRIVADO"));
            if (sql.equals("EXEC dbo.spListarRolesAcceso ?"))
                return List.of(Map.of("Codigo", "TECNICO", "Nombre", "Técnico"));
            if (sql.equals("EXEC dbo.spListarEmpleadosDisponibles ?"))
                return List.of(Map.of("EmpleadoID", 38, "Codigo", "EMP-038", "Nombres", "José", "Apellidos", "Pérez"));
            if (sql.equals("EXEC dbo.spConsultarAcceso ?") && !altas.isEmpty()) {
                Map<String, Object> login = new HashMap<>(fila(77, (String) altas.get(0)[6]));
                login.put("RolCodigo", "TECNICO");
                login.put("AlgoritmoHash", "PBKDF2_SHA256");
                return List.of(login);
            }
            return List.of();
        });
    }

    private Map<String, Object> fila(int empleado, String hash) {
        Map<String, Object> fila = new HashMap<>();
        fila.put("UsuarioID", 21); fila.put("EmpleadoID", empleado); fila.put("EmpleadoCodigo", "EMP-011");
        fila.put("Nombres", "María José"); fila.put("Apellidos", "Pérez López"); fila.put("NombreUsuario", "nueva.cuenta");
        fila.put("UsuarioActivo", true); fila.put("EmpleadoActivo", true);
        fila.put("FechaCreacion", Timestamp.valueOf(LocalDateTime.of(2026, 10, 20, 12, 0)));
        fila.put("Roles", "CAJA,TECNICO"); fila.put("PasswordHash", hash); fila.put("AlgoritmoHash", "PBKDF2_SHA256");
        return fila;
    }

    private RequestPostProcessor actor(String rol) {
        var usuario = new UsuarioAutenticado(42, "administrador", "Admin", "EMP-042", List.of(rol), true, null);
        return authentication(UsernamePasswordAuthenticationToken.authenticated(usuario, null, usuario.getAuthorities()));
    }

    @Test void anonimoNoPuedeConsultarNiCrearCuentas() throws Exception {
        mvc.perform(get("/api/admin/usuarios")).andExpect(status().isUnauthorized());
        mvc.perform(post("/api/admin/usuarios").with(csrf()).contentType("application/json").content(DATOS))
                .andExpect(status().isUnauthorized());
        verifyNoInteractions(jdbc);
    }

    @ParameterizedTest @ValueSource(strings = {"RECEPCION", "TECNICO", "CAJA", "BODEGA"})
    void soloAdminPuedeUsarTodosLosEndpoints(String rol) throws Exception {
        for (String ruta : List.of("/api/admin/usuarios", "/api/admin/usuarios/21", "/api/admin/roles", "/api/admin/empleados-disponibles"))
            mvc.perform(get(ruta).with(actor(rol))).andExpect(status().isForbidden());
        mvc.perform(post("/api/admin/usuarios").with(actor(rol)).with(csrf()).contentType("application/json").content(DATOS))
                .andExpect(status().isForbidden());
        verifyNoInteractions(jdbc);
    }

    @Test void altaRequiereCsrfInclusoSiEsAdmin() throws Exception {
        mvc.perform(post("/api/admin/usuarios").with(actor("ADMIN")).contentType("application/json").content(DATOS))
                .andExpect(status().isForbidden());
        verifyNoInteractions(jdbc);
    }

    @Test void creaEmpleadoYCuentaConHashRealSalAleatoriaYActorDeLaSesion() throws Exception {
        mvc.perform(post("/api/admin/usuarios").with(actor("ADMIN")).with(csrf()).contentType("application/json").content(DATOS))
                .andExpect(status().isCreated()).andExpect(header().string("Location", "/api/admin/usuarios/21"))
                .andExpect(jsonPath("$.nombreUsuario").value("nueva.cuenta"))
                .andExpect(jsonPath("$.nombres").value("María José"))
                .andExpect(jsonPath("$.roles", contains("CAJA", "TECNICO")))
                .andExpect(content().string(not(containsString("PasswordHash"))))
                .andExpect(content().string(not(containsString("pbkdf2"))))
                .andExpect(content().string(not(containsString(CLAVE))));
        assertEquals(1, altas.size());
        Object[] args = altas.get(0);
        assertEquals(42, args[0]); assertNull(args[1]);
        assertEquals("EMP-011", args[2]); assertEquals("María José", args[3]); assertEquals("Pérez López", args[4]);
        assertEquals("nueva.cuenta", args[5]); assertEquals("TECNICO,CAJA", args[7]);
        String hash = (String) args[6];
        assertTrue(hash.startsWith("$pbkdf2-sha256$600000$"));
        assertTrue(encoder.matches(CLAVE, hash));
        assertFalse(encoder.matches(CLAVE.strip(), hash));
        for (Object arg : args) assertNotEquals(CLAVE, arg);

        mvc.perform(post("/api/admin/usuarios").with(actor("ADMIN")).with(csrf()).contentType("application/json").content(DATOS))
                .andExpect(status().isCreated());
        assertNotEquals(hash, altas.get(1)[6]);
    }

    @Test void cuentaRegistradaPuedeIngresarConElEncoderExistente() throws Exception {
        mvc.perform(post("/api/admin/usuarios").with(actor("ADMIN")).with(csrf()).contentType("application/json").content(DATOS))
                .andExpect(status().isCreated());
        mvc.perform(post("/api/auth/login").with(csrf()).contentType("application/json")
                .content("{\"nombreUsuario\":\"nueva.cuenta\",\"contrasena\":\"" + CLAVE + "\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.roles[0]").value("TECNICO"))
                .andExpect(jsonPath("$.usuario.usuarioId").value(21))
                .andExpect(content().string(not(containsString("pbkdf2"))));
        mvc.perform(post("/api/auth/login").with(csrf()).contentType("application/json")
                .content("{\"nombreUsuario\":\"nueva.cuenta\",\"contrasena\":\"incorrecta\"}"))
                .andExpect(status().isUnauthorized());
    }

    @Test void permiteVincularUnEmpleadoExistenteSinCrearOtro() throws Exception {
        String datos = """
                {"nombreUsuario":"empleado38","contrasena":"Clave segura 2026!","roles":["RECEPCION"],"empleadoId":38}
                """;
        mvc.perform(post("/api/admin/usuarios").with(actor("ADMIN")).with(csrf()).contentType("application/json").content(datos))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.empleadoId").value(38));
        assertEquals(38, altas.get(0)[1]);
        assertNull(altas.get(0)[2]); assertNull(altas.get(0)[3]); assertNull(altas.get(0)[4]);
    }

    @Test void consultaYCatalogosNoExponenHashes() throws Exception {
        mvc.perform(get("/api/admin/usuarios").with(actor("ADMIN"))).andExpect(status().isOk())
                .andExpect(jsonPath("$[0].nombreUsuario").value("nueva.cuenta"))
                .andExpect(content().string(not(containsString("HASH_PRIVADO"))))
                .andExpect(content().string(not(containsString("PasswordHash"))));
        mvc.perform(get("/api/admin/usuarios/21").with(actor("ADMIN"))).andExpect(status().isOk());
        mvc.perform(get("/api/admin/roles").with(actor("ADMIN"))).andExpect(status().isOk())
                .andExpect(jsonPath("$[0].codigo").value("TECNICO"));
        mvc.perform(get("/api/admin/empleados-disponibles").with(actor("ADMIN"))).andExpect(status().isOk())
                .andExpect(jsonPath("$[0].empleadoId").value(38));
        verify(jdbc).queryForList("EXEC dbo.spListarUsuarios ?, ?", 42, null);
        verify(jdbc).queryForList("EXEC dbo.spListarRolesAcceso ?", 42);
        verify(jdbc).queryForList("EXEC dbo.spListarEmpleadosDisponibles ?", 42);
    }

    @ParameterizedTest @ValueSource(strings = {"corta", "            ", "EXCESIVA"})
    void rechazaContrasenasInvalidasSinEscribir(String clave) throws Exception {
        String valor = clave.equals("EXCESIVA") ? "x".repeat(257) : clave;
        String datos = DATOS.replace(CLAVE, valor);
        mvc.perform(post("/api/admin/usuarios").with(actor("ADMIN")).with(csrf()).contentType("application/json").content(datos))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.errores.contrasena").exists());
        verifyNoInteractions(jdbc);
    }

    @Test void rechazaRolesVaciosRepetidosYCodigosManipulados() throws Exception {
        for (String roles : List.of("[]", "[\"TECNICO\",\"TECNICO\"]", "[\"ADMIN,TECNICO\"]", "[null]")) {
            mvc.perform(post("/api/admin/usuarios").with(actor("ADMIN")).with(csrf()).contentType("application/json")
                    .content(DATOS.replace("[\"TECNICO\",\"CAJA\"]", roles))).andExpect(status().isBadRequest());
        }
        verifyNoInteractions(jdbc);
    }

    @Test void exigeExactamenteUnaOpcionDeEmpleadoYValidaLosNombres() throws Exception {
        List<String> invalidos = List.of(DATOS.replace("\"empleadoId\":null", "\"empleadoId\":38"),
                "{\"nombreUsuario\":\"nuevo\",\"contrasena\":\"Clave segura 2026!\",\"roles\":[\"TECNICO\"]}",
                DATOS.replace(" María José ", " "), DATOS.replace(" Pérez López ", "x".repeat(81)),
                DATOS.replace(" EMP-011 ", "CODIGO".repeat(4)), DATOS.replace("  nueva.cuenta  ", "nombre con espacios"));
        for (String datos : invalidos)
            mvc.perform(post("/api/admin/usuarios").with(actor("ADMIN")).with(csrf()).contentType("application/json").content(datos))
                    .andExpect(status().isBadRequest());
        verifyNoInteractions(jdbc);
    }

    @Test void nombresConTextoSqlViajanComoParametros() throws Exception {
        String nombres = "María'; DROP TABLE Usuario;--";
        mvc.perform(post("/api/admin/usuarios").with(actor("ADMIN")).with(csrf()).contentType("application/json")
                .content(DATOS.replace(" María José ", nombres))).andExpect(status().isCreated());
        assertEquals(nombres, altas.get(0)[3]);
        verify(jdbc).queryForList(eq(SQL_ALTA), any(Object[].class));
    }

    @ParameterizedTest @CsvSource({"51500,400", "51501,400", "51502,404", "51503,409", "51504,403", "547,409", "2601,409", "50000,503"})
    void traduceErroresSqlSinDevolverLaConsultaNiElHash(int codigo, int esperado) throws Exception {
        when(jdbc.queryForList(eq(SQL_ALTA), any(Object[].class))).thenThrow(new UncategorizedSQLException(
                "alta", "EXEC dbo.spRegistrarUsuario", new SQLException("Error de prueba", "S0001", codigo)));
        mvc.perform(post("/api/admin/usuarios").with(actor("ADMIN")).with(csrf()).contentType("application/json").content(DATOS))
                .andExpect(status().is(esperado)).andExpect(content().string(not(containsString("pbkdf2"))))
                .andExpect(content().string(not(containsString("EXEC"))));
    }

    @Test void erroresDeIdYJsonSon400YCuentaAusenteEs404() throws Exception {
        mvc.perform(get("/api/admin/usuarios/0").with(actor("ADMIN"))).andExpect(status().isBadRequest());
        mvc.perform(get("/api/admin/usuarios/abc").with(actor("ADMIN"))).andExpect(status().isBadRequest());
        mvc.perform(post("/api/admin/usuarios").with(actor("ADMIN")).with(csrf()).contentType("application/json").content("{"))
                .andExpect(status().isBadRequest());
        when(jdbc.queryForList("EXEC dbo.spListarUsuarios ?, ?", 42, 99)).thenReturn(List.of());
        mvc.perform(get("/api/admin/usuarios/99").with(actor("ADMIN"))).andExpect(status().isNotFound());
    }
}
