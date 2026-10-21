package com.techcare.backend.ordenes;

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
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.RequestPostProcessor;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.*;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties = "spring.datasource.url=jdbc:sqlserver://localhost:1433;databaseName=TechCare;encrypt=false")
class OrdenApiTests {
    private static final String ALTA = "EXEC dbo.spRegistrarOrden ?, ?, ?, ?, ?, ?";
    private static final String LISTA = "EXEC dbo.spListarOrdenes ?, ?, ?, ?, ?, ?, ?";
    private static final String ASIGNAR = "EXEC dbo.spAsignarTecnicoOrden ?, ?, ?, ?, ?";
    private static final String DATOS = """
        {"equipoId":7,"problema":" Falla ñ 漢字 ","prioridad":"NORMAL","fechaEstimada":null,
         "observaciones":" María José ","usuarioActorID":999,"usuarioRecepcionId":999,"numeroOrden":"ELEGIDO-POR-CLIENTE"}
        """;
    @Autowired WebApplicationContext context;
    @MockitoBean JdbcTemplate jdbc;
    private MockMvc mvc;
    @BeforeEach void preparar() {
        reset(jdbc);
        mvc = MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
        when(jdbc.queryForList(anyString(), any(Object[].class))).thenAnswer(inv -> {
            String sql = inv.getArgument(0);
            if (sql.contains("spCatalogosOrden")) return List.of(Map.of("Codigo", "NORMAL", "Nombre", "Normal", "Nivel", 2));
            if (sql.contains("spHistorialOrden")) return List.of(Map.of("EventoID", "E-1", "Tipo", "ESTADO", "EstadoNuevo", "RECIBIDO",
                    "Fecha", Timestamp.valueOf("2026-10-20 12:00:00"), "Usuario", "recepcion", "NombreUsuario", "Recepción"));
            if (sql.contains("spHistorialEquipoAcceso")) return List.of();
            return List.of(fila());
        });
    }
    private Map<String, Object> fila() {
        Map<String, Object> r = new HashMap<>();
        r.put("OrdenID", 81); r.put("NumeroOrden", "TC-81"); r.put("EquipoID", 7); r.put("ClienteID", 5);
        r.put("NumeroSerie", "SER-7"); r.put("Cliente", "María José"); r.put("NIT", "CF-5");
        r.put("UsuarioRecepcionID", 42); r.put("FechaIngreso", Timestamp.valueOf("2026-10-20 12:00:00"));
        r.put("ProblemaReportado", "Falla ñ 漢字"); r.put("PrioridadCodigo", "NORMAL"); r.put("Prioridad", "Normal");
        r.put("EstadoCodigo", "RECIBIDO"); r.put("Estado", "Recibido"); r.put("EsFinal", false);
        r.put("PasswordHash", "SECRETO_INTERNO"); r.put("AlgoritmoHash", "PBKDF2_SHA256");
        return r;
    }
    private RequestPostProcessor actor(String rol) {
        var u = new UsuarioAutenticado(42, "cuenta", "Cuenta prueba", "EMP-42", List.of(rol), true, null);
        return authentication(UsernamePasswordAuthenticationToken.authenticated(u, null, u.getAuthorities()));
    }
    @Test void anonimoNoPuedeConsultarNiCrear() throws Exception {
        mvc.perform(get("/api/ordenes")).andExpect(status().isUnauthorized());
        mvc.perform(post("/api/ordenes").with(csrf()).contentType("application/json").content(DATOS)).andExpect(status().isUnauthorized());
        verifyNoInteractions(jdbc);
    }
    @Test void bodegaNoTieneAccesoAOrdenes() throws Exception {
        for (String ruta : List.of("/api/ordenes", "/api/ordenes/81", "/api/ordenes/81/historial", "/api/ordenes/catalogos/estados"))
            mvc.perform(get(ruta).with(actor("BODEGA"))).andExpect(status().isForbidden());
        verifyNoInteractions(jdbc);
    }
    @ParameterizedTest @ValueSource(strings = {"TECNICO", "CAJA", "BODEGA"})
    void rolesSinRecepcionNoPuedenCrearAsignarNiCancelar(String rol) throws Exception {
        mvc.perform(post("/api/ordenes").with(actor(rol)).with(csrf()).contentType("application/json").content(DATOS)).andExpect(status().isForbidden());
        mvc.perform(put("/api/ordenes/81/tecnico").with(actor(rol)).with(csrf()).contentType("application/json").content("{\"tecnicoId\":4}")).andExpect(status().isForbidden());
        mvc.perform(post("/api/ordenes/81/cancelacion").with(actor(rol)).with(csrf()).contentType("application/json").content("{\"motivo\":\"Cliente solicita\"}")).andExpect(status().isForbidden());
        mvc.perform(get("/api/ordenes/catalogos/tecnicos").with(actor(rol))).andExpect(status().isForbidden());
        verifyNoInteractions(jdbc);
    }
    @ParameterizedTest @ValueSource(strings = {"ADMIN", "RECEPCION", "TECNICO", "CAJA"})
    void consultasUsanElActorRealParaFiltrarEnSql(String rol) throws Exception {
        mvc.perform(get("/api/ordenes/81").with(actor(rol))).andExpect(status().isOk())
                .andExpect(jsonPath("$.numeroOrden").value("TC-81"));
        verify(jdbc).queryForList("EXEC dbo.spConsultarOrden ?, ?", 42, 81);
    }
    @ParameterizedTest @ValueSource(strings = {"ADMIN", "RECEPCION"})
    void crearDevuelveIdUnicodeYActorDeSesionIgnorandoElNumeroDelCliente(String rol) throws Exception {
        mvc.perform(post("/api/ordenes").with(actor(rol)).with(csrf()).contentType("application/json").content(DATOS))
                .andExpect(status().isCreated()).andExpect(header().string("Location", "/api/ordenes/81"))
                .andExpect(jsonPath("$.problemaReportado").value("Falla ñ 漢字"))
                .andExpect(jsonPath("$.fechaIngreso").value("2026-10-20T12:00:00Z"))
                .andExpect(content().string(not(containsString("PasswordHash"))))
                .andExpect(content().string(not(containsString("SECRETO_INTERNO"))))
                .andExpect(content().string(not(containsString("ELEGIDO-POR-CLIENTE"))));
        verify(jdbc).queryForList(ALTA, 42, 7, "Falla ñ 漢字", "NORMAL", null, "María José");
        verifyNoMoreInteractions(jdbc);
    }
    @Test void fechaEstimadaSeConvierteAUtcAntesDeLlamarSql() throws Exception {
        mvc.perform(post("/api/ordenes").with(actor("RECEPCION")).with(csrf()).contentType("application/json")
                .content(DATOS.replace("\"fechaEstimada\":null", "\"fechaEstimada\":\"2099-12-31T10:15:00-06:00\"")))
                .andExpect(status().isCreated());
        verify(jdbc).queryForList(ALTA, 42, 7, "Falla ñ 漢字", "NORMAL", LocalDateTime.of(2099, 12, 31, 16, 15), "María José");
    }
    @Test void filtrosDeDiasIncluyenGuatemalaYTextoSeEnviaComoParametro() throws Exception {
        String literal = "100%_'; DROP TABLE dbo.Usuario;--";
        mvc.perform(get("/api/ordenes").with(actor("TECNICO")).param("buscar", literal)
                .param("estado", "RECIBIDO").param("prioridad", "NORMAL").param("tecnicoId", "0")
                .param("desde", "2026-10-20").param("hasta", "2026-10-21")).andExpect(status().isOk());
        verify(jdbc).queryForList(LISTA, 42, literal, "RECIBIDO", "NORMAL", 0,
                LocalDateTime.of(2026, 10, 20, 6, 0), LocalDateTime.of(2026, 10, 22, 6, 0));
    }
    @ParameterizedTest @ValueSource(strings = {"ADMIN", "RECEPCION"})
    void asignacionUsaActorDeSesionYResponsableAnterior(String rol) throws Exception {
        mvc.perform(put("/api/ordenes/81/tecnico").with(actor(rol)).with(csrf()).contentType("application/json")
                .content("{\"tecnicoId\":5,\"tecnicoAnteriorId\":4,\"observacion\":\" Cambio ñ \",\"usuarioActorID\":999}"))
                .andExpect(status().isOk());
        verify(jdbc).queryForList(ASIGNAR, 42, 81, 5, 4, "Cambio ñ");
    }
    @Test void cancelacionNoAceptaUnActorEnviadoPorElCliente() throws Exception {
        mvc.perform(post("/api/ordenes/81/cancelacion").with(actor("RECEPCION")).with(csrf()).contentType("application/json")
                .content("{\"motivo\":\" Cliente José solicita ñ \",\"usuarioActorID\":999}"))
                .andExpect(status().isOk());
        verify(jdbc).queryForList("EXEC dbo.spCancelarOrden ?, ?, ?", 42, 81, "Cliente José solicita ñ");
    }
    @Test void lasTresEscriturasRequierenCsrf() throws Exception {
        mvc.perform(post("/api/ordenes").with(actor("ADMIN")).contentType("application/json").content(DATOS)).andExpect(status().isForbidden());
        mvc.perform(put("/api/ordenes/81/tecnico").with(actor("ADMIN")).contentType("application/json").content("{\"tecnicoId\":4}")).andExpect(status().isForbidden());
        mvc.perform(post("/api/ordenes/81/cancelacion").with(actor("ADMIN")).contentType("application/json").content("{\"motivo\":\"Prueba\"}")).andExpect(status().isForbidden());
        verifyNoInteractions(jdbc);
    }
    @Test void idsYFechasInvalidosSeRechazanAntesDeSql() throws Exception {
        mvc.perform(get("/api/ordenes/0").with(actor("ADMIN"))).andExpect(status().isBadRequest());
        mvc.perform(get("/api/ordenes/texto").with(actor("ADMIN"))).andExpect(status().isBadRequest());
        mvc.perform(get("/api/ordenes").with(actor("ADMIN")).param("desde", "2026-10-22").param("hasta", "2026-10-20")).andExpect(status().isBadRequest());
        mvc.perform(get("/api/ordenes").with(actor("ADMIN")).param("desde", "fecha-invalida")).andExpect(status().isBadRequest());
        verifyNoInteractions(jdbc);
    }
    @Test void limitesYObligatoriosNoLleganASql() throws Exception {
        for (String datos : List.of(DATOS.replace("Falla ñ 漢字", " "), DATOS.replace("Falla ñ 漢字", "a".repeat(1001)),
                DATOS.replace("\"equipoId\":7", "\"equipoId\":0"), DATOS.replace("NORMAL", "a".repeat(11)),
                DATOS.replace("María José", "a".repeat(1001)), DATOS.replace("\"fechaEstimada\":null", "\"fechaEstimada\":\"2000-01-01T00:00:00Z\"")))
            mvc.perform(post("/api/ordenes").with(actor("ADMIN")).with(csrf()).contentType("application/json").content(datos)).andExpect(status().isBadRequest());
        mvc.perform(post("/api/ordenes/81/cancelacion").with(actor("ADMIN")).with(csrf()).contentType("application/json").content("{\"motivo\":\"   \"}"))
                .andExpect(status().isBadRequest());
        mvc.perform(put("/api/ordenes/81/tecnico").with(actor("ADMIN")).with(csrf()).contentType("application/json").content("{\"tecnicoId\":0}"))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(jdbc);
    }
    @ParameterizedTest @CsvSource({"51600,400", "51601,400", "51602,404", "51603,409", "51604,403", "547,409", "2627,409", "2812,503"})
    void erroresSqlSeTraducenSinExponerDetallesInternos(int codigo, int estado) throws Exception {
        when(jdbc.queryForList("EXEC dbo.spConsultarOrden ?, ?", 42, 81)).thenThrow(
                new UncategorizedSQLException("orden", "EXEC dbo.spConsultarOrden ?, ?", new SQLException("Mensaje controlado", "S0001", codigo)));
        var respuesta = mvc.perform(get("/api/ordenes/81").with(actor("ADMIN"))).andExpect(status().is(estado));
        if (estado == 503) respuesta.andExpect(content().string(not(containsString("Mensaje controlado"))));
    }
    @Test void historialYEquiposRecibenElActorParaAplicarLaMismaRestriccion() throws Exception {
        mvc.perform(get("/api/ordenes/81/historial").with(actor("TECNICO"))).andExpect(status().isOk())
                .andExpect(jsonPath("$[0].eventoId").value("E-1"));
        mvc.perform(get("/api/equipos/7/historial").with(actor("TECNICO"))).andExpect(status().isOk());
        verify(jdbc).queryForList("EXEC dbo.spHistorialOrden ?, ?", 42, 81);
        verify(jdbc).queryForList("EXEC dbo.spHistorialEquipoAcceso ?, ?", 42, 7);
    }
    @Test void consultaSinFilasDevuelve404SiLaAsignacionCambioDuranteLaLectura() throws Exception {
        when(jdbc.queryForList("EXEC dbo.spConsultarOrden ?, ?", 42, 81)).thenReturn(List.of());
        mvc.perform(get("/api/ordenes/81").with(actor("TECNICO"))).andExpect(status().isNotFound());
    }
    @Test void catalogosUsanParametrosYNoSeExponenCambiosDeEstadoGenericos() throws Exception {
        mvc.perform(get("/api/ordenes/catalogos/prioridades").with(actor("TECNICO"))).andExpect(status().isOk())
                .andExpect(jsonPath("$[0].codigo").value("NORMAL"));
        verify(jdbc).queryForList("EXEC dbo.spCatalogosOrden ?, ?", 42, "prioridades");
        mvc.perform(get("/api/ordenes/catalogos/desconocido").with(actor("ADMIN"))).andExpect(status().isNotFound());
        mvc.perform(post("/api/ordenes/81/estado").with(actor("ADMIN")).with(csrf()).contentType("application/json").content("{\"estado\":\"ENTREGADO\"}"))
                .andExpect(status().isForbidden());
    }
}
