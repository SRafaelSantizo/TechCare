package com.techcare.backend.compras;

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
import org.springframework.transaction.support.SimpleTransactionStatus;
import org.springframework.web.context.WebApplicationContext;

import java.math.BigDecimal;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.LocalDate;
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

@SpringBootTest(properties="spring.datasource.url=jdbc:sqlserver://localhost:1433;databaseName=TechCare;encrypt=false")
class ComprasApiTests {
    private static final String REV="A".repeat(64),UUID="465a0112-0e98-43ce-b63f-2636e6942b0a";
    private static final String LINEA="{\"bodegaId\":2,\"repuestoId\":9,\"cantidad\":10,\"costoUnitario\":20.25}";
    private static final String BODY="{\"solicitudId\":\""+UUID+"\",\"numeroCompra\":\" CP-9 \",\"proveedorId\":5,\"observaciones\":\" Garantía ñ 漢字 \",\"detalle\":["+LINEA+"],\"usuarioActorId\":999}";
    @Autowired WebApplicationContext context;
    @MockitoBean JdbcTemplate jdbc;
    @MockitoBean PlatformTransactionManager transactions;
    private MockMvc mvc;
    @BeforeEach void preparar() {
        reset(jdbc,transactions);when(transactions.getTransaction(any())).thenReturn(new SimpleTransactionStatus());
        mvc=MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
        var r=new HashMap<String,Object>();
        r.put("CompraID",7);r.put("NumeroCompra","CP-9");r.put("ProveedorID",5);r.put("Proveedor","Proveedor ñ 漢字");r.put("NIT","1234-5");
        r.put("Revision",REV);r.put("Estado","PENDIENTE");r.put("Total",new BigDecimal("21474836469978525163.53"));
        r.put("RegistradaPor","Bodega prueba");r.put("Observaciones","Garantía ñ 漢字");r.put("Fecha",Timestamp.valueOf("2026-10-21 18:00:00"));
        r.put("CostoPromedio",new BigDecimal("16.125000"));r.put("PasswordHash","PRIVADO");r.put("LoginSQL","INTERNO");
        when(jdbc.queryForList(anyString(),any(Object[].class))).thenReturn(List.of(r));
    }
    private RequestPostProcessor actor(String rol) {
        var u=new UsuarioAutenticado(42,"bodega","Bodega prueba","EMP-42",List.of(rol),true,null);
        return authentication(UsernamePasswordAuthenticationToken.authenticated(u,null,u.getAuthorities()));
    }
    @ParameterizedTest @ValueSource(strings={"TECNICO","RECEPCION","CAJA"})
    void rolesAjenosNoLeenNiEscribenCompras(String rol) throws Exception {
        for(String p:List.of("/compras","/compras/7","/compras/catalogos/destinos?proveedorId=5","/repuestos/9/costos"))
            mvc.perform(get("/api"+p).with(actor(rol))).andExpect(status().isForbidden());
        for(String p:List.of("/compras","/compras/7/recepcion","/compras/7/anulacion"))
            mvc.perform(post("/api"+p).with(actor(rol)).with(csrf()).contentType("application/json").content(BODY)).andExpect(status().isForbidden());
        verifyNoInteractions(jdbc);
    }
    @Test void escriturasExigenSesionYCsrf() throws Exception {
        for(String p:List.of("/compras","/compras/7/recepcion","/compras/7/anulacion")) {
            mvc.perform(post("/api"+p).with(csrf()).contentType("application/json").content(BODY)).andExpect(status().isUnauthorized());
            mvc.perform(post("/api"+p).with(actor("BODEGA")).contentType("application/json").content(BODY)).andExpect(status().isForbidden());
        }
        verifyNoInteractions(jdbc);
    }
    @ParameterizedTest @ValueSource(strings={"ADMIN","BODEGA"})
    void registroConservaIdentidadSolicitudActorUnicodeYCentavos(String rol) throws Exception {
        mvc.perform(post("/api/compras").with(actor(rol)).with(csrf()).contentType("application/json").content(BODY)).andExpect(status().isCreated())
            .andExpect(header().string("Location","/api/compras/7")).andExpect(jsonPath("$.total").value("21474836469978525163.53"))
            .andExpect(jsonPath("$.observaciones").value("Garantía ñ 漢字")).andExpect(content().string(not(containsString("PRIVADO"))));
        verify(jdbc).queryForList("EXEC dbo.spRegistrarCompraApi ?, ?, ?, ?, ?, ?",42,UUID,"CP-9",5,"Garantía ñ 漢字","[{\"bodegaId\":2,\"repuestoId\":9,\"cantidad\":10,\"costoUnitario\":20.25}]");
    }
    @Test void reintentoEnviaLaMismaSolicitudSinGenerarOtraEnServidor() throws Exception {
        for(int i=0;i<2;i++)mvc.perform(post("/api/compras").with(actor("BODEGA")).with(csrf()).contentType("application/json").content(BODY)).andExpect(status().isCreated());
        verify(jdbc,times(2)).queryForList(eq("EXEC dbo.spRegistrarCompraApi ?, ?, ?, ?, ?, ?"),eq(42),eq(UUID),eq("CP-9"),eq(5),eq("Garantía ñ 漢字"),anyString());
    }
    @ParameterizedTest @ValueSource(strings={"0","-1","1.5","2147483648","null"})
    void cantidadesInvalidasNoSeTruncan(String valor) throws Exception {
        mvc.perform(post("/api/compras").with(actor("BODEGA")).with(csrf()).contentType("application/json").content(BODY.replace("\"cantidad\":10","\"cantidad\":"+valor))).andExpect(status().isBadRequest());verifyNoInteractions(jdbc);
    }
    @ParameterizedTest @ValueSource(strings={"-0.01","1.234","10000000000","null"})
    void costosInvalidosNoLleganASql(String valor) throws Exception {
        mvc.perform(post("/api/compras").with(actor("BODEGA")).with(csrf()).contentType("application/json").content(BODY.replace("20.25",valor))).andExpect(status().isBadRequest());verifyNoInteractions(jdbc);
    }
    @Test void costoCeroYParesEnBodegasDistintasSonValidos() throws Exception {
        var body=BODY.replace("20.25","0").replace("["+LINEA.replace("20.25","0")+"]","["+LINEA.replace("20.25","0")+","+LINEA.replace("\"bodegaId\":2","\"bodegaId\":3")+"]");
        mvc.perform(post("/api/compras").with(actor("BODEGA")).with(csrf()).contentType("application/json").content(body)).andExpect(status().isCreated());
    }
    @Test void paresRepetidosYDetalleVacioSeRechazan() throws Exception {
        for(String body:List.of(BODY.replace("["+LINEA+"]","[]"),BODY.replace("["+LINEA+"]","["+LINEA+","+LINEA+"]"),BODY.replace("["+LINEA+"]","[null]"),BODY.replace("["+LINEA+"]","[{}]")))
            mvc.perform(post("/api/compras").with(actor("BODEGA")).with(csrf()).contentType("application/json").content(body)).andExpect(status().isBadRequest());verifyNoInteractions(jdbc);
    }
    @Test void idsFraccionariosNoSeCoaccionan() throws Exception {
        for(String body:List.of(BODY.replace("\"proveedorId\":5","\"proveedorId\":5.5"),BODY.replace("\"bodegaId\":2","\"bodegaId\":2.5"),BODY.replace("\"repuestoId\":9","\"repuestoId\":9.5")))
            mvc.perform(post("/api/compras").with(actor("BODEGA")).with(csrf()).contentType("application/json").content(body)).andExpect(status().isBadRequest());verifyNoInteractions(jdbc);
    }
    @Test void solicitudesYTextosInvalidosSeRechazan() throws Exception {
        for(String body:List.of(BODY.replace(UUID,"invalido"),BODY.replace("CP-9","x".repeat(31)),BODY.replace("CP-9","CP 漢字"),BODY.replace("Garantía ñ 漢字","x".repeat(1001))))
            mvc.perform(post("/api/compras").with(actor("BODEGA")).with(csrf()).contentType("application/json").content(body)).andExpect(status().isBadRequest());verifyNoInteractions(jdbc);
    }
    @Test void recepcionYAnulacionUsanRevisionYActorAutenticado() throws Exception {
        mvc.perform(post("/api/compras/7/recepcion").with(actor("BODEGA")).with(csrf()).contentType("application/json").content("{\"revision\":\""+REV+"\",\"usuarioActorId\":999}")).andExpect(status().isOk());
        mvc.perform(post("/api/compras/7/anulacion").with(actor("ADMIN")).with(csrf()).contentType("application/json").content("{\"revision\":\""+REV+"\",\"motivo\":\" Cancelación ñ 漢字 \"}")).andExpect(status().isOk());
        verify(jdbc).queryForList("EXEC dbo.spRecibirCompraApi ?, ?, ?",42,7,REV);
        verify(jdbc).queryForList("EXEC dbo.spAnularCompraApi ?, ?, ?, ?",42,7,REV,"Cancelación ñ 漢字");
    }
    @Test void confirmacionIncompletaYMotivosInvalidosSeRechazan() throws Exception {
        for(String body:List.of("{}","{\"revision\":\"corta\"}"))mvc.perform(post("/api/compras/7/recepcion").with(actor("BODEGA")).with(csrf()).contentType("application/json").content(body)).andExpect(status().isBadRequest());
        for(String motivo:List.of(" ","x".repeat(1001)))mvc.perform(post("/api/compras/7/anulacion").with(actor("BODEGA")).with(csrf()).contentType("application/json").content("{\"revision\":\""+REV+"\",\"motivo\":\""+motivo+"\"}")).andExpect(status().isBadRequest());verifyNoInteractions(jdbc);
    }
    @Test void expedienteComponeUnaLecturaTransaccionalConImportesExactos() throws Exception {
        mvc.perform(get("/api/compras/7").with(actor("BODEGA"))).andExpect(status().isOk()).andExpect(jsonPath("$.compra.total").value("21474836469978525163.53"))
            .andExpect(jsonPath("$.detalle[0].costoPromedio").value("16.125000")).andExpect(content().string(not(containsString("PRIVADO"))));
        verify(jdbc).queryForList("EXEC dbo.spConsultarCompraApi ?, ?",42,7);verify(jdbc).queryForList("EXEC dbo.spDetalleCompraApi ?, ?",42,7);
        verify(jdbc).queryForList("EXEC dbo.spEventosCompraApi ?, ?",42,7);verify(transactions).commit(any());
    }
    @Test void listadosYCatalogosUsanParametros() throws Exception {
        mvc.perform(get("/api/compras").with(actor("ADMIN")).param("buscar","%_' OR 1=1").param("estado","PENDIENTE").param("proveedorId","5").param("desde","2026-10-01").param("hasta","2026-10-21")).andExpect(status().isOk());
        verify(jdbc).queryForList("EXEC dbo.spListarComprasApi ?, ?, ?, ?, ?, ?",42,"%_' OR 1=1","PENDIENTE",5,LocalDate.of(2026,10,1),LocalDate.of(2026,10,21));
        mvc.perform(get("/api/compras/catalogos/destinos").with(actor("BODEGA")).param("proveedorId","5")).andExpect(status().isOk());
        mvc.perform(get("/api/repuestos/9/costos").with(actor("BODEGA"))).andExpect(status().isOk()).andExpect(jsonPath("$[0].costoPromedio").value("16.125000"));
        verify(jdbc).queryForList("EXEC dbo.spDestinosCompraApi ?, ?",42,5);verify(jdbc).queryForList("EXEC dbo.spCostosRepuestoApi ?, ?",42,9);
    }
    @Test void filtrosEIdsInvalidosNoLleganALaBase() throws Exception {
        for(String p:List.of("/compras?estado=INVALIDO","/compras?proveedorId=0","/compras?desde=2026-10-21&hasta=2026-10-01","/compras/0","/compras/catalogos/destinos?proveedorId=1.5","/repuestos/0/costos"))
            mvc.perform(get("/api"+p).with(actor("BODEGA"))).andExpect(status().isBadRequest());verifyNoInteractions(jdbc);
    }
    @ParameterizedTest @CsvSource({"52100,400","52101,400","52102,404","52103,409","52004,403","2627,409","1205,409","51030,409","2812,503"})
    void erroresSqlTienenRespuestaControlada(int codigo,int esperado) throws Exception {
        when(jdbc.queryForList(anyString(),any(Object[].class))).thenThrow(new UncategorizedSQLException("compras","EXEC",new SQLException("INTERNO_SQL","S0001",codigo)));
        var result=mvc.perform(get("/api/compras").with(actor("BODEGA"))).andExpect(status().is(esperado));
        if(codigo!=52100&&codigo!=52101&&codigo!=52103)result.andExpect(content().string(not(containsString("INTERNO_SQL"))));
    }
}
