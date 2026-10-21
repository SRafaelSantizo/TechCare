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

import java.math.BigDecimal;
import java.sql.SQLException;
import java.sql.Timestamp;
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
class ServicioTecnicoApiTests {
    private static final String DIAGNOSTICO = "{\"descripcion\":\" Revisión ñ 漢字 \",\"costoEstimado\":125.50,\"usuarioTecnicoId\":999}";
    private static final String REPARACION = "{\"descripcionTrabajo\":\" Cambiar fuente ñ \",\"costoManoObra\":125.50,\"autorizacion\":\" María autorizó por teléfono \",\"usuarioActorId\":999}";
    @Autowired WebApplicationContext context;
    @MockitoBean JdbcTemplate jdbc;
    private MockMvc mvc;

    @BeforeEach void preparar() {
        reset(jdbc);
        mvc = MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
        when(jdbc.queryForList(anyString(), any(Object[].class))).thenReturn(List.of(orden()));
    }
    private Map<String, Object> orden() {
        Map<String, Object> r = new HashMap<>();
        r.put("OrdenID", 81); r.put("NumeroOrden", "TC-81"); r.put("UsuarioTecnicoID", 42);
        r.put("EstadoCodigo", "REPARACION"); r.put("Estado", "En reparación"); r.put("EsFinal", false);
        r.put("PasswordHash", "NO_SERIALIZAR"); r.put("CostoReferencia", new BigDecimal("12.00"));
        return r;
    }
    private RequestPostProcessor actor(String rol) {
        var u = new UsuarioAutenticado(42, "cuenta", "Técnico prueba", "EMP-42", List.of(rol), true, null);
        return authentication(UsernamePasswordAuthenticationToken.authenticated(u, null, u.getAuthorities()));
    }

    @ParameterizedTest @ValueSource(strings = {"RECEPCION", "CAJA", "BODEGA"})
    void losRolesDeConsultaNoEjecutanOperacionesTecnicas(String rol) throws Exception {
        for (String ruta : List.of("diagnostico/inicio", "diagnostico", "reparacion", "actividades", "repuestos", "reparacion/cierre"))
            mvc.perform(post("/api/ordenes/81/" + ruta).with(actor(rol)).with(csrf())
                    .contentType("application/json").content(DIAGNOSTICO)).andExpect(status().isForbidden());
        verifyNoInteractions(jdbc);
    }
    @Test void todasLasEscriturasExigenSesionYCsrf() throws Exception {
        for (String ruta : List.of("diagnostico/inicio", "diagnostico", "reparacion", "actividades", "repuestos", "reparacion/cierre")) {
            mvc.perform(post("/api/ordenes/81/" + ruta).with(csrf()).contentType("application/json").content(DIAGNOSTICO)).andExpect(status().isUnauthorized());
            mvc.perform(post("/api/ordenes/81/" + ruta).with(actor("TECNICO")).contentType("application/json").content(DIAGNOSTICO)).andExpect(status().isForbidden());
        }
        verifyNoInteractions(jdbc);
    }
    @Test void diagnosticoUsaActorDeSesionYConservaUnicodeYDecimales() throws Exception {
        mvc.perform(post("/api/ordenes/81/diagnostico").with(actor("TECNICO")).with(csrf())
                .contentType("application/json").content(DIAGNOSTICO)).andExpect(status().isCreated())
                .andExpect(header().string("Location", "/api/ordenes/81"))
                .andExpect(jsonPath("$.numeroOrden").value("TC-81"))
                .andExpect(content().string(not(containsString("NO_SERIALIZAR"))))
                .andExpect(content().string(not(containsString("costoReferencia"))));
        verify(jdbc).queryForList("EXEC dbo.spRegistrarDiagnosticoOrden ?, ?, ?, ?", 42, 81, "Revisión ñ 漢字", new BigDecimal("125.50"));
        verifyNoMoreInteractions(jdbc);
    }
    @Test void iniciarReparacionEnviaLaAutorizacionYNoAceptaOtroActor() throws Exception {
        mvc.perform(post("/api/ordenes/81/reparacion").with(actor("TECNICO")).with(csrf())
                .contentType("application/json").content(REPARACION)).andExpect(status().isCreated());
        verify(jdbc).queryForList("EXEC dbo.spIniciarReparacionOrden ?, ?, ?, ?, ?", 42, 81,
                "Cambiar fuente ñ", new BigDecimal("125.50"), "María autorizó por teléfono");
    }
    @Test void actividadConsumoInicioYCierreUsanLosProcedimientosProtegidos() throws Exception {
        mvc.perform(post("/api/ordenes/81/diagnostico/inicio").with(actor("TECNICO")).with(csrf())).andExpect(status().isOk());
        mvc.perform(post("/api/ordenes/81/actividades").with(actor("TECNICO")).with(csrf()).contentType("application/json")
                .content("{\"actividadId\":3,\"observacion\":\" Se probó con carga ñ \",\"usuarioId\":999}")).andExpect(status().isOk());
        mvc.perform(post("/api/ordenes/81/repuestos").with(actor("TECNICO")).with(csrf()).contentType("application/json")
                .content("{\"bodegaId\":2,\"repuestoId\":7,\"cantidad\":3,\"precioUnitarioEsperado\":25.50,\"usuarioId\":999}")).andExpect(status().isOk());
        mvc.perform(post("/api/ordenes/81/reparacion/cierre").with(actor("TECNICO")).with(csrf())).andExpect(status().isOk());
        verify(jdbc).queryForList("EXEC dbo.spIniciarDiagnosticoOrden ?, ?", 42, 81);
        verify(jdbc).queryForList("EXEC dbo.spAgregarActividadOrden ?, ?, ?, ?", 42, 81, 3, "Se probó con carga ñ");
        verify(jdbc).queryForList("EXEC dbo.spUsarRepuestoOrden ?, ?, ?, ?, ?, ?", 42, 81, 2, 7, 3, new BigDecimal("25.50"));
        verify(jdbc).queryForList("EXEC dbo.spFinalizarReparacionOrden ?, ?", 42, 81);
        verifyNoMoreInteractions(jdbc);
    }
    @ParameterizedTest @ValueSource(strings = {"ADMIN", "RECEPCION", "TECNICO", "CAJA"})
    void consultasDeleganElFiltroDeAsignacionAlSql(String rol) throws Exception {
        when(jdbc.queryForList("EXEC dbo.spActividadesOrden ?, ?", 42, 81)).thenReturn(List.of(Map.of(
                "ActividadID", 3, "Nombre", "Prueba ñ", "Fecha", Timestamp.valueOf("2026-10-21 12:30:00"))));
        when(jdbc.queryForList("EXEC dbo.spRepuestosOrden ?, ?", 42, 81)).thenReturn(List.of(Map.of(
                "Linea", 1, "RepuestoID", 7, "Cantidad", 3, "PrecioUnitario", new BigDecimal("25.50"),
                "Importe", new BigDecimal("76.50"), "MovimientoID", 10000000000L)));
        mvc.perform(get("/api/ordenes/81/actividades").with(actor(rol))).andExpect(status().isOk())
                .andExpect(jsonPath("$[0].fecha").value("2026-10-21T12:30:00Z"));
        mvc.perform(get("/api/ordenes/81/repuestos").with(actor(rol))).andExpect(status().isOk())
                .andExpect(jsonPath("$[0].importe").value(76.5)).andExpect(jsonPath("$[0].movimientoId").value(10000000000L));
        verify(jdbc).queryForList("EXEC dbo.spActividadesOrden ?, ?", 42, 81);
        verify(jdbc).queryForList("EXEC dbo.spRepuestosOrden ?, ?", 42, 81);
    }
    @Test void catalogosNoExponenCostoDeCompraNiOtrosCamposInternos() throws Exception {
        Map<String, Object> r = new HashMap<>(Map.of("BodegaID", 2, "Bodega", "Principal", "RepuestoID", 7,
                "Codigo", "REP-7", "Nombre", "Fuente", "Existencia", 12L, "PrecioUnitario", new BigDecimal("25.50")));
        r.put("CostoReferencia", new BigDecimal("12.00"));
        when(jdbc.queryForList("EXEC dbo.spCatalogoRepuestosOrden ?, ?", 42, 81)).thenReturn(List.of(r));
        when(jdbc.queryForList("EXEC dbo.spCatalogoActividadesOrden ?, ?", 42, 81)).thenReturn(List.of(Map.of("ActividadID", 3, "Nombre", "Revisión")));
        mvc.perform(get("/api/ordenes/81/catalogos/repuestos").with(actor("TECNICO"))).andExpect(status().isOk())
                .andExpect(jsonPath("$[0].existencia").value(12)).andExpect(content().string(not(containsString("CostoReferencia"))));
        mvc.perform(get("/api/ordenes/81/catalogos/actividades").with(actor("TECNICO"))).andExpect(status().isOk());
        verify(jdbc).queryForList("EXEC dbo.spCatalogoRepuestosOrden ?, ?", 42, 81);
        verify(jdbc).queryForList("EXEC dbo.spCatalogoActividadesOrden ?, ?", 42, 81);
    }
    @ParameterizedTest @ValueSource(strings = {"-0.01", "1.234", "10000000000", "null"})
    void importesInvalidosNoLleganASql(String importe) throws Exception {
        mvc.perform(post("/api/ordenes/81/diagnostico").with(actor("TECNICO")).with(csrf()).contentType("application/json")
                .content(DIAGNOSTICO.replace("125.50", importe))).andExpect(status().isBadRequest());
        mvc.perform(post("/api/ordenes/81/reparacion").with(actor("TECNICO")).with(csrf()).contentType("application/json")
                .content(REPARACION.replace("125.50", importe))).andExpect(status().isBadRequest());
        verifyNoInteractions(jdbc);
    }
    @Test void noSeAceptaAutorizacionVaciaNiTextosFueraDeLimite() throws Exception {
        for (String contenido : List.of(REPARACION.replace("María autorizó por teléfono", " "),
                REPARACION.replace("María autorizó por teléfono", "a".repeat(501)), REPARACION.replace("Cambiar fuente ñ", "a".repeat(2001))))
            mvc.perform(post("/api/ordenes/81/reparacion").with(actor("TECNICO")).with(csrf()).contentType("application/json").content(contenido)).andExpect(status().isBadRequest());
        for (String contenido : List.of(DIAGNOSTICO.replace("Revisión ñ 漢字", " "), DIAGNOSTICO.replace("Revisión ñ 漢字", "a".repeat(2001))))
            mvc.perform(post("/api/ordenes/81/diagnostico").with(actor("TECNICO")).with(csrf()).contentType("application/json").content(contenido)).andExpect(status().isBadRequest());
        verifyNoInteractions(jdbc);
    }
    @ParameterizedTest @ValueSource(strings = {"0", "-1", "1.5", "2147483648", "null"})
    void cantidadNoValidaSeRechazaAntesDeConsumir(String cantidad) throws Exception {
        mvc.perform(post("/api/ordenes/81/repuestos").with(actor("TECNICO")).with(csrf()).contentType("application/json")
                .content("{\"bodegaId\":2,\"repuestoId\":7,\"cantidad\":" + cantidad + ",\"precioUnitarioEsperado\":25.50}"))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(jdbc);
    }
    @ParameterizedTest @CsvSource({"51700,400", "51701,400", "51702,404", "51703,409", "51704,403", "51019,409", "2812,503"})
    void conflictosDeStockAsignacionYEstadoDevuelvenErroresControlados(int codigo, int estado) throws Exception {
        when(jdbc.queryForList("EXEC dbo.spFinalizarReparacionOrden ?, ?", 42, 81)).thenThrow(
                new UncategorizedSQLException("servicio", "EXEC", new SQLException("Detalle interno controlado", "S0001", codigo)));
        var respuesta = mvc.perform(post("/api/ordenes/81/reparacion/cierre").with(actor("TECNICO")).with(csrf())).andExpect(status().is(estado));
        if (estado == 404 || estado == 403 || estado == 503) respuesta.andExpect(content().string(not(containsString("Detalle interno controlado"))));
    }
    @Test void idsInvalidosNoSeEnviaASql() throws Exception {
        mvc.perform(post("/api/ordenes/0/diagnostico/inicio").with(actor("TECNICO")).with(csrf())).andExpect(status().isBadRequest());
        mvc.perform(get("/api/ordenes/texto/repuestos").with(actor("TECNICO"))).andExpect(status().isBadRequest());
        verifyNoInteractions(jdbc);
    }
}
