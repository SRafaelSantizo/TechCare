package com.techcare.backend;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.dao.UncategorizedDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.validation.beanvalidation.LocalValidatorFactoryBean;

import java.sql.SQLException;
import java.util.List;
import java.util.Map;

import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class EquipoControllerTests {
    private JdbcTemplate jdbc;
    private MockMvc mvc;
    private static final String BODY = """
            {"clienteId":1,"modeloEquipoId":2,"numeroSerie":" SER-001 ","descripcion":" Revisión ñ 漢字 ","activo":true}
            """;
    private static final String LISTAR = "EXEC dbo.spListarEquipos ?, ?, ?";
    private static final String CREAR = "EXEC dbo.spRegistrarEquipo ?, ?, ?, ?, ?";
    private static final String ACTUALIZAR = "EXEC dbo.spActualizarEquipo ?, ?, ?, ?, ?, ?";
    private final Map<String, Object> fila = Map.of("EquipoID", 7, "NumeroSerie", "SER-001", "Descripcion", "Revisión ñ 漢字", "Activo", true);

    @BeforeEach
    void preparar() {
        jdbc = mock(JdbcTemplate.class);
        LocalValidatorFactoryBean validator = new LocalValidatorFactoryBean();
        validator.afterPropertiesSet();
        mvc = MockMvcBuilders.standaloneSetup(new EquipoController(jdbc), new CatalogoEquipoController(jdbc))
                .setControllerAdvice(new EquipoApiErrores()).setValidator(validator).build();
    }

    @Test
    void listaSinFiltrosNoInventaDatos() throws Exception {
        when(jdbc.queryForList(LISTAR, (Object) null, null, null)).thenReturn(List.of());
        mvc.perform(get("/api/equipos")).andExpect(status().isOk()).andExpect(content().json("[]"));
        verify(jdbc).queryForList(LISTAR, (Object) null, null, null);
    }

    @Test
    void filtrosConservanClienteSerieLiteralYFalse() throws Exception {
        when(jdbc.queryForList(LISTAR, 1, "100%_", false)).thenReturn(List.of(fila));
        mvc.perform(get("/api/equipos").param("clienteId", "1").param("serie", "100%_").param("activo", "false"))
                .andExpect(status().isOk()).andExpect(jsonPath("$[0].EquipoID").value(7));
        verify(jdbc).queryForList(LISTAR, 1, "100%_", false);
    }

    @Test
    void consultaConservaContratoPascalCase() throws Exception {
        when(jdbc.queryForList("EXEC dbo.spConsultarEquipo ?", 7)).thenReturn(List.of(fila));
        mvc.perform(get("/api/equipos/7")).andExpect(status().isOk()).andExpect(jsonPath("$.NumeroSerie").value("SER-001"));
    }

    @Test
    void altaUsaUnaLlamadaAlProcedimientoDevuelve201YLocation() throws Exception {
        when(jdbc.queryForList(CREAR, 1, 2, "SER-001", "Revisión ñ 漢字", true)).thenReturn(List.of(fila));
        mvc.perform(post("/api/equipos").contentType("application/json").content(BODY))
                .andExpect(status().isCreated()).andExpect(header().string("Location", "/api/equipos/7"))
                .andExpect(jsonPath("$.Descripcion").value("Revisión ñ 漢字"));
        verify(jdbc).queryForList(CREAR, 1, 2, "SER-001", "Revisión ñ 漢字", true);
        verifyNoMoreInteractions(jdbc);
    }

    @Test
    void actualizarEnviaElIdYPermiteDesactivar() throws Exception {
        when(jdbc.queryForList(ACTUALIZAR, 7, 1, 2, "SER-001", "Revisión ñ 漢字", false))
                .thenReturn(List.of(Map.of("EquipoID", 7, "Activo", false)));
        mvc.perform(put("/api/equipos/7").contentType("application/json").content(BODY.replace("true", "false")))
                .andExpect(status().isOk()).andExpect(jsonPath("$.Activo").value(false));
        verify(jdbc).queryForList(ACTUALIZAR, 7, 1, 2, "SER-001", "Revisión ñ 漢字", false);
        verifyNoMoreInteractions(jdbc);
    }

    @Test
    void camposObligatoriosFallanAntesDeJdbc() throws Exception {
        mvc.perform(post("/api/equipos").contentType("application/json").content("{}"))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.errores.clienteId").exists())
                .andExpect(jsonPath("$.errores.modeloEquipoId").exists()).andExpect(jsonPath("$.errores.activo").exists());
        verifyNoInteractions(jdbc);
    }

    @Test
    void textosLargosSeRechazanSinTruncarlos() throws Exception {
        mvc.perform(post("/api/equipos").contentType("application/json").content(BODY.replace(" SER-001 ", "X".repeat(81))))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.errores.numeroSerie").exists());
        verifyNoInteractions(jdbc);
    }

    @Test
    void jsonInvalidoSeTraduceA400() throws Exception {
        mvc.perform(post("/api/equipos").contentType("application/json").content("{mal"))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.estado").value(400));
        verifyNoInteractions(jdbc);
    }

    @Test
    void filtroNoNumericoSeTraduceA400() throws Exception {
        mvc.perform(get("/api/equipos").param("clienteId", "abc")).andExpect(status().isBadRequest());
        verifyNoInteractions(jdbc);
    }

    @Test
    void erroresDeReglasSqlSeTraducenA400404Y409() throws Exception {
        for (int codigo : new int[]{51300, 51301, 51302, 51303, 51304, 51109}) {
            reset(jdbc);
            SQLException sql = new SQLException("Regla de prueba", "S0001", codigo);
            when(jdbc.queryForList("EXEC dbo.spConsultarEquipo ?", 7)).thenThrow(fallo(sql));
            int esperado = codigo == 51302 ? 404 : (codigo == 51300 || codigo == 51301 ? 400 : 409);
            mvc.perform(get("/api/equipos/7")).andExpect(status().is(esperado)).andExpect(jsonPath("$.estado").value(esperado));
        }
    }

    @Test
    void conflictoEnExcepcionSqlEncadenada() throws Exception {
        SQLException sql = new SQLException("Excepción envolvente");
        sql.setNextException(new SQLException("duplicado", "23000", 2627));
        when(jdbc.queryForList("EXEC dbo.spConsultarEquipo ?", 7)).thenThrow(fallo(sql));
        mvc.perform(get("/api/equipos/7")).andExpect(status().isConflict());
    }

    @Test
    void falloInesperadoNoExponeDetallesSql() throws Exception {
        when(jdbc.queryForList("EXEC dbo.spConsultarEquipo ?", 7)).thenThrow(new DataAccessResourceFailureException("detalle interno"));
        mvc.perform(get("/api/equipos/7")).andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.mensaje").value("No se pudo completar la operación. Revisá el backend."));
    }

    @Test
    void resultadoDeAltaSinIdNoSeReportaComoExito() throws Exception {
        when(jdbc.queryForList(CREAR, 1, 2, "SER-001", "Revisión ñ 漢字", true)).thenReturn(List.of());
        mvc.perform(post("/api/equipos").contentType("application/json").content(BODY)).andExpect(status().isInternalServerError());
    }

    @Test
    void historialVacioEs200YNoFilaNula() throws Exception {
        when(jdbc.queryForList("EXEC dbo.spHistorialEquipo ?", 7)).thenReturn(List.of());
        mvc.perform(get("/api/equipos/7/historial")).andExpect(status().isOk()).andExpect(content().json("[]"));
    }

    @Test
    void historialDeEquipoInexistenteEs404() throws Exception {
        when(jdbc.queryForList("EXEC dbo.spHistorialEquipo ?", 7)).thenThrow(fallo(new SQLException("No existe", "S0001", 51302)));
        mvc.perform(get("/api/equipos/7/historial")).andExpect(status().isNotFound());
    }

    @Test
    void tiposYMarcasUsanSusProcedimientos() throws Exception {
        when(jdbc.queryForList("EXEC dbo.spListarTiposEquipo")).thenReturn(List.of(Map.of("TipoEquipoID", 1, "Nombre", "Laptop")));
        when(jdbc.queryForList("EXEC dbo.spListarMarcas")).thenReturn(List.of(Map.of("MarcaID", 1, "Nombre", "Marca")));
        mvc.perform(get("/api/catalogos/tipos-equipos")).andExpect(status().isOk()).andExpect(jsonPath("$[0].TipoEquipoID").value(1));
        mvc.perform(get("/api/catalogos/marcas")).andExpect(status().isOk()).andExpect(jsonPath("$[0].MarcaID").value(1));
        verify(jdbc).queryForList("EXEC dbo.spListarTiposEquipo");
        verify(jdbc).queryForList("EXEC dbo.spListarMarcas");
        verifyNoMoreInteractions(jdbc);
    }

    @Test
    void modelosConservanLosFiltros() throws Exception {
        when(jdbc.queryForList("EXEC dbo.spListarModelosEquipo ?, ?", 3, 2)).thenReturn(List.of());
        mvc.perform(get("/api/catalogos/modelos-equipos").param("marcaId", "3").param("tipoEquipoId", "2"))
                .andExpect(status().isOk()).andExpect(content().json("[]"));
        verify(jdbc).queryForList("EXEC dbo.spListarModelosEquipo ?, ?", 3, 2);
    }

    private UncategorizedDataAccessException fallo(SQLException sql) {
        return new UncategorizedDataAccessException("Fallo simulado", sql) {};
    }
}
