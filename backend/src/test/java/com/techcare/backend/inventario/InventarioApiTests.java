package com.techcare.backend.inventario;

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
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.SimpleTransactionStatus;
import org.springframework.web.context.WebApplicationContext;
import java.math.BigDecimal;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.LocalDate;
import java.util.*;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.*;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties="spring.datasource.url=jdbc:sqlserver://localhost:1433;databaseName=TechCare;encrypt=false")
class InventarioApiTests {
    @Autowired WebApplicationContext context;
    @MockitoBean JdbcTemplate jdbc;
    @MockitoBean PlatformTransactionManager transactions;
    private MockMvc mvc;
    private Map<String,Object> fila,movimiento;
    @BeforeEach void preparar() {
        reset(jdbc,transactions);when(transactions.getTransaction(any())).thenReturn(new SimpleTransactionStatus());
        mvc=MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
        fila=new HashMap<>();fila.putAll(Map.of("BodegaID",2,"RepuestoID",9,"CodigoBodega","B-2","Bodega","Bodega ñ 漢字","Repuesto","Fuente ñ 漢字","Codigo","REP-9","BodegaActiva",true,"RepuestoActivo",false));
        fila.putAll(Map.of("CategoriaID",3,"Categoria","Fuentes","Existencia",9007199254740993L,"StockMinimo",4,"Faltante",0L,"EstadoStock","DISPONIBLE","CostoPromedio",new BigDecimal("16.125678"),"ValorExistencia",new BigDecimal("145000000000000000.123456"),"PasswordHash","PRIVADO","LoginSQL","INTERNO"));
        movimiento=new HashMap<>();movimiento.putAll(Map.of("MovimientoID",9007199254740995L,"Fecha",Timestamp.valueOf("2026-10-23 23:59:59"),"Tipo","E","Cantidad",10,"ExistenciaAnterior",0L,"ExistenciaResultante",10L,"CostoUnitario",new BigDecimal("12.25"),"Importe",new BigDecimal("122.50")));
        movimiento.putAll(Map.of("CostoAnterior",new BigDecimal("0.000000"),"CostoPosterior",new BigDecimal("12.250000"),"ValorExistencia",new BigDecimal("122.500000"),"EsMigracion",false,"CompraID",7,"LineaCompra",1,"NumeroCompra","CP-7","Responsable","Bodega ñ 漢字","NombreHistorico",true,"UsuarioID",42));
        movimiento.put("PasswordHash","PRIVADO");
        when(jdbc.queryForList(anyString(),any(Object[].class))).thenAnswer(i -> {
            String sql=i.getArgument(0);
            if(sql.contains("spResumenInventarioApi"))return List.of(Map.of("Total",60L,"SinExistencia",3L,"StockBajo",4L,"ValorTotal",new BigDecimal("145000000000000000.123456")));
            if(sql.contains("spResumenKardexApi"))return List.of(Map.of("SaldoInicial",5L,"Entradas",10L,"Salidas",2L,"SaldoFinal",13L,"Total",2L));
            return List.of(sql.contains("spListarKardexApi")?movimiento:fila);
        });
    }
    private RequestPostProcessor actor(String rol) {
        var u=new UsuarioAutenticado(42,"bodega","Bodega prueba","EMP-42",List.of(rol),true,null);
        return authentication(UsernamePasswordAuthenticationToken.authenticated(u,null,u.getAuthorities()));
    }
    @ParameterizedTest @ValueSource(strings={"TECNICO","RECEPCION","CAJA"})
    void rolesAjenosNoConsultanInventarioNiKardex(String rol) throws Exception {
        for(String url:List.of("/api/inventario","/api/inventario/2/9/kardex"))mvc.perform(get(url).with(actor(rol))).andExpect(status().isForbidden());
        verifyNoInteractions(jdbc);
    }
    @Test void consultasExigenSesion() throws Exception {
        for(String url:List.of("/api/inventario","/api/inventario/2/9/kardex"))mvc.perform(get(url)).andExpect(status().isUnauthorized());verifyNoInteractions(jdbc);
    }
    @ParameterizedTest @ValueSource(strings={"ADMIN","BODEGA"})
    void inventarioConservaPrecisionUnicodeYResumenDeTodoElFiltro(String rol) throws Exception {
        mvc.perform(get("/api/inventario").with(actor(rol))).andExpect(status().isOk())
            .andExpect(jsonPath("$.filas[0].existencia").value("9007199254740993"))
            .andExpect(jsonPath("$.filas[0].costoPromedio").value("16.125678"))
            .andExpect(jsonPath("$.filas[0].repuesto").value("Fuente ñ 漢字"))
            .andExpect(jsonPath("$.filas[0].repuestoActivo").value(false))
            .andExpect(jsonPath("$.resumen.valorTotal").value("145000000000000000.123456"))
            .andExpect(jsonPath("$.total").value(60)).andExpect(jsonPath("$.totalPaginas").value(3))
            .andExpect(content().string(not(containsString("PRIVADO")))).andExpect(content().string(not(containsString("INTERNO"))));
        verify(transactions).getTransaction(argThat(t->t.isReadOnly()&&t.getIsolationLevel()==TransactionDefinition.ISOLATION_SERIALIZABLE));
        verify(transactions).commit(any());
    }
    @Test void filtrosUsanParametrosYActorDeSesion() throws Exception {
        mvc.perform(get("/api/inventario").with(actor("BODEGA")).param("usuarioActorId","999").param("buscar","%_' OR 1=1").param("bodegaId","2").param("categoriaId","3").param("estadoStock","BAJO").param("activo","false").param("pagina","2").param("tamano","10")).andExpect(status().isOk());
        verify(jdbc).queryForList("EXEC dbo.spResumenInventarioApi ?, ?, ?, ?, ?, ?",42,"%_' OR 1=1",2,3,"BAJO",false);
        verify(jdbc).queryForList("EXEC dbo.spListarInventarioApi ?, ?, ?, ?, ?, ?, ?, ?",42,"%_' OR 1=1",2,3,"BAJO",false,2,10);
    }
    @Test void paginaQueYaNoExisteSeAjustaAlUltimoResultado() throws Exception {
        mvc.perform(get("/api/inventario").with(actor("BODEGA")).param("pagina","2147483647")).andExpect(status().isOk()).andExpect(jsonPath("$.pagina").value(3));
        verify(jdbc).queryForList("EXEC dbo.spListarInventarioApi ?, ?, ?, ?, ?, ?, ?, ?",42,null,null,null,null,null,3,25);
    }
    @Test void inventarioVacioConservaResumenYPrimeraPagina() throws Exception {
        when(jdbc.queryForList(startsWith("EXEC dbo.spResumenInventarioApi"),any(Object[].class))).thenReturn(List.of(Map.of("Total",0L,"SinExistencia",0L,"StockBajo",0L,"ValorTotal",new BigDecimal("0.000000"))));
        when(jdbc.queryForList(startsWith("EXEC dbo.spListarInventarioApi"),any(Object[].class))).thenReturn(List.of());
        mvc.perform(get("/api/inventario").with(actor("ADMIN")).param("pagina","99")).andExpect(status().isOk()).andExpect(jsonPath("$.filas",hasSize(0))).andExpect(jsonPath("$.pagina").value(1)).andExpect(jsonPath("$.total").value(0));
    }
    @ParameterizedTest @ValueSource(strings={"bodegaId=0","bodegaId=1.5","categoriaId=-1","estadoStock=INVENTADO","activo=mal","pagina=0","pagina=-1","pagina=1.5","pagina=2147483648","tamano=0","tamano=101"})
    void filtrosInvalidosNoLleganASql(String query) throws Exception {
        mvc.perform(get("/api/inventario?"+query).with(actor("BODEGA"))).andExpect(status().isBadRequest());verifyNoInteractions(jdbc);
    }
    @Test void busquedaLargaSeRechazaSinTruncarse() throws Exception {
        mvc.perform(get("/api/inventario").with(actor("ADMIN")).param("buscar","x".repeat(151))).andExpect(status().isBadRequest());verifyNoInteractions(jdbc);
    }
    @Test void kardexConservaImportesIDGrandeYFechasUtc() throws Exception {
        mvc.perform(get("/api/inventario/2/9/kardex").with(actor("BODEGA")).param("desde","2026-10-01").param("hasta","2026-10-23").param("tipo","E"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.filas[0].movimientoId").value("9007199254740995"))
            .andExpect(jsonPath("$.filas[0].fecha").value("2026-10-23T23:59:59Z"))
            .andExpect(jsonPath("$.filas[0].importe").value("122.50")).andExpect(jsonPath("$.filas[0].costoPosterior").value("12.250000"))
            .andExpect(jsonPath("$.filas[0].nombreHistorico").value(true)).andExpect(jsonPath("$.resumen.salidas").value("2"))
            .andExpect(jsonPath("$.resumen.saldoFinal").value("13")).andExpect(content().string(not(containsString("PRIVADO"))));
        verify(jdbc).queryForList("EXEC dbo.spListarKardexApi ?, ?, ?, ?, ?, ?, ?, ?",42,2,9,LocalDate.of(2026,10,1),LocalDate.of(2026,10,23),"E",1,25);
    }
    @Test void salidasSinValoracionNoInventanPromedios() throws Exception {
        movimiento.put("Tipo","S");movimiento.put("CostoAnterior",null);movimiento.put("CostoPosterior",null);movimiento.put("EsMigracion",null);
        movimiento.put("NombreHistorico",false);movimiento.put("CompraID",null);movimiento.put("OrdenID",11);movimiento.put("NumeroOrden","OS-11");
        mvc.perform(get("/api/inventario/2/9/kardex").with(actor("ADMIN"))).andExpect(status().isOk()).andExpect(jsonPath("$.filas[0].costoPosterior").doesNotExist())
            .andExpect(jsonPath("$.filas[0].esMigracion").doesNotExist()).andExpect(jsonPath("$.filas[0].ordenId").value(11)).andExpect(jsonPath("$.filas[0].nombreHistorico").value(false));
    }
    @ParameterizedTest @ValueSource(strings={"/0/9/kardex","/2/-1/kardex","/2/9/kardex?desde=2026-10-23&hasta=2026-10-01","/2/9/kardex?desde=2026-02-30","/2/9/kardex?tipo=ENTRADA","/2/9/kardex?tamano=101","/2/9/kardex?desde=0000-01-01"})
    void kardexInvalidoNoConsultaSql(String url) throws Exception {
        mvc.perform(get("/api/inventario"+url).with(actor("BODEGA"))).andExpect(status().isBadRequest());verifyNoInteractions(jdbc);
    }
    @Test void paresInexistentesResponden404() throws Exception {
        when(jdbc.queryForList(startsWith("EXEC dbo.spConsultarInventarioApi"),any(Object[].class))).thenReturn(List.of());
        mvc.perform(get("/api/inventario/2/9/kardex").with(actor("BODEGA"))).andExpect(status().isNotFound());
        verify(jdbc,never()).queryForList(startsWith("EXEC dbo.spResumenKardexApi"),any(Object[].class));
    }
    @Test void noHayEndpointParaEditarExistencia() throws Exception {
        for(String method:List.of("POST","PUT","DELETE"))mvc.perform(request(org.springframework.http.HttpMethod.valueOf(method),"/api/inventario").with(actor("ADMIN")).with(csrf()).contentType("application/json").content("{\"existencia\":999}"))
            .andExpect(status().isForbidden());verifyNoInteractions(jdbc);
    }
    @ParameterizedTest @CsvSource({"52200,400","52202,404","52004,403","1205,409","1222,409","2812,503"})
    void erroresSqlNoExponenDetallesInternos(int codigo,int estado) throws Exception {
        when(jdbc.queryForList(anyString(),any(Object[].class))).thenThrow(new UncategorizedSQLException("inventario","EXEC",new SQLException("INTERNO_SQL","S0001",codigo)));
        mvc.perform(get("/api/inventario").with(actor("BODEGA"))).andExpect(status().is(estado)).andExpect(content().string(not(containsString("INTERNO_SQL"))));
    }
}
