package com.techcare.backend.abastecimiento;

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

@SpringBootTest(properties="spring.datasource.url=jdbc:sqlserver://localhost:1433;databaseName=TechCare;encrypt=false")
class AbastecimientoApiTests {
    private static final String REV="A".repeat(64);
    private static final String REP="{\"categoriaId\":3,\"codigo\":\" REP-9 \",\"nombre\":\" Fuente ñ 漢字 \",\"descripcion\":\" Descripción ñ \",\"costoReferencia\":12.25,\"precioVenta\":25.50,\"activo\":true,\"usuarioActorId\":999}";
    private static final String PROV="{\"nit\":\" 1234-5 \",\"nombre\":\" Proveedor ñ \",\"email\":\"  \",\"telefono\":\"  \",\"direccion\":\" Dirección ñ \",\"activo\":true,\"usuarioActorId\":999}";
    @Autowired WebApplicationContext context;
    @MockitoBean JdbcTemplate jdbc;
    private MockMvc mvc;
    @BeforeEach void preparar() {
        reset(jdbc);mvc=MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
        var r=new HashMap<String,Object>();
        r.put("RepuestoID",9);r.put("CategoriaID",3);r.put("ProveedorID",5);r.put("BodegaID",2);r.put("Nombre","Fuente ñ 漢字");r.put("Codigo","REP-9");
        r.put("Activo",true);r.put("Revision",REV);r.put("CostoReferencia",new BigDecimal("12.25"));r.put("PrecioVenta",new BigDecimal("25.50"));
        r.put("PasswordHash","PRIVADO");r.put("LoginSQL","LOGIN_PRIVADO");
        when(jdbc.queryForList(anyString(),any(Object[].class))).thenReturn(List.of(r));
    }
    private RequestPostProcessor actor(String rol) {
        var u=new UsuarioAutenticado(42,"bodega","Bodega prueba","EMP-42",List.of(rol),true,null);
        return authentication(UsernamePasswordAuthenticationToken.authenticated(u,null,u.getAuthorities()));
    }
    private String revisado(String body) { return body.substring(0,body.length()-1)+",\"revision\":\""+REV+"\"}"; }
    @ParameterizedTest @ValueSource(strings={"TECNICO","CAJA","RECEPCION"})
    void otrosRolesNoConsultanNiMantienenCatalogosDeBodega(String rol) throws Exception {
        for(String path:List.of("/repuestos","/repuestos/9","/repuestos/9/precios","/repuestos/categorias","/proveedores","/proveedores/5/repuestos","/bodegas","/bodegas/2/repuestos"))
            mvc.perform(get("/api"+path).with(actor(rol))).andExpect(status().isForbidden());
        for(String path:List.of("/repuestos","/proveedores","/bodegas","/repuestos/categorias"))
            mvc.perform(post("/api"+path).with(actor(rol)).with(csrf()).contentType("application/json").content(REP)).andExpect(status().isForbidden());
        for(String path:List.of("/repuestos/9","/proveedores/5","/bodegas/2","/repuestos/categorias/3","/proveedores/5/repuestos/9","/bodegas/2/repuestos/9"))
            mvc.perform(put("/api"+path).with(actor(rol)).with(csrf()).contentType("application/json").content(REP)).andExpect(status().isForbidden());
        verifyNoInteractions(jdbc);
    }
    @Test void todasLasEscriturasExigenSesionYCsrf() throws Exception {
        for(String path:List.of("/repuestos","/proveedores","/bodegas","/repuestos/categorias")) {
            mvc.perform(post("/api"+path).with(csrf()).contentType("application/json").content(REP)).andExpect(status().isUnauthorized());
            mvc.perform(post("/api"+path).with(actor("BODEGA")).contentType("application/json").content(REP)).andExpect(status().isForbidden());
        }
        for(String path:List.of("/repuestos/9","/proveedores/5","/bodegas/2","/repuestos/categorias/3","/proveedores/5/repuestos/9","/bodegas/2/repuestos/9")) {
            mvc.perform(put("/api"+path).with(csrf()).contentType("application/json").content(REP)).andExpect(status().isUnauthorized());
            mvc.perform(put("/api"+path).with(actor("BODEGA")).contentType("application/json").content(REP)).andExpect(status().isForbidden());
        }
        verifyNoInteractions(jdbc);
    }
    @ParameterizedTest @ValueSource(strings={"ADMIN","BODEGA"})
    void crearRepuestoUsaActorAutenticadoYConservaUnicodeYCentavos(String rol) throws Exception {
        mvc.perform(post("/api/repuestos").with(actor(rol)).with(csrf()).contentType("application/json").content(REP))
                .andExpect(status().isCreated()).andExpect(header().string("Location","/api/repuestos/9"))
                .andExpect(jsonPath("$.nombre").value("Fuente ñ 漢字")).andExpect(jsonPath("$.precioVenta").value(25.5))
                .andExpect(content().string(not(containsString("PRIVADO"))));
        verify(jdbc).queryForList("EXEC dbo.spGuardarRepuestoGestion ?, ?, ?, ?, ?, ?, ?, ?, ?, ?",42,null,3,"REP-9","Fuente ñ 漢字","Descripción ñ",new BigDecimal("12.25"),new BigDecimal("25.50"),true,null);
    }
    @Test void actualizacionEnviaLaRevisionLeida() throws Exception {
        mvc.perform(put("/api/repuestos/9").with(actor("BODEGA")).with(csrf()).contentType("application/json").content(revisado(REP))).andExpect(status().isOk());
        verify(jdbc).queryForList("EXEC dbo.spGuardarRepuestoGestion ?, ?, ?, ?, ?, ?, ?, ?, ?, ?",42,9,3,"REP-9","Fuente ñ 漢字","Descripción ñ",new BigDecimal("12.25"),new BigDecimal("25.50"),true,REV);
    }
    @Test void proveedorLimpiaOpcionalesYTomaActorDeSesion() throws Exception {
        mvc.perform(post("/api/proveedores").with(actor("BODEGA")).with(csrf()).contentType("application/json").content(PROV)).andExpect(status().isCreated());
        verify(jdbc).queryForList("EXEC dbo.spGuardarProveedorGestion ?, ?, ?, ?, ?, ?, ?, ?, ?",42,null,"1234-5","Proveedor ñ",null,null,"Dirección ñ",true,null);
    }
    @Test void bodegaYCategoriaSeGuardanPorSusProcedimientos() throws Exception {
        mvc.perform(post("/api/bodegas").with(actor("BODEGA")).with(csrf()).contentType("application/json")
                .content("{\"codigo\":\" B-2 \",\"nombre\":\" Bodega ñ \",\"direccion\":\" Zona 1 \",\"activo\":true}")).andExpect(status().isCreated());
        mvc.perform(post("/api/repuestos/categorias").with(actor("BODEGA")).with(csrf()).contentType("application/json").content("{\"nombre\":\" Categoría ñ 漢字 \"}")).andExpect(status().isCreated());
        verify(jdbc).queryForList("EXEC dbo.spGuardarBodegaGestion ?, ?, ?, ?, ?, ?, ?",42,null,"B-2","Bodega ñ","Zona 1",true,null);
        verify(jdbc).queryForList("EXEC dbo.spGuardarCategoriaRepuesto ?, ?, ?, ?",42,null,"Categoría ñ 漢字",null);
    }
    @Test void asociarYRetirarOfertaPreservanRevisionYNoAceptanOtroActor() throws Exception {
        mvc.perform(put("/api/proveedores/5/repuestos/9").with(actor("BODEGA")).with(csrf()).contentType("application/json")
                .content("{\"codigoProveedor\":\" REF-9 \",\"ofrecido\":true,\"usuarioActorId\":999}")).andExpect(status().isOk());
        mvc.perform(put("/api/proveedores/5/repuestos/9").with(actor("BODEGA")).with(csrf()).contentType("application/json")
                .content("{\"codigoProveedor\":null,\"ofrecido\":false,\"revision\":\""+REV+"\"}")).andExpect(status().isOk());
        verify(jdbc).queryForList("EXEC dbo.spGuardarOfertaProveedor ?, ?, ?, ?, ?, ?",42,5,9,"REF-9",true,null);
        verify(jdbc).queryForList("EXEC dbo.spGuardarOfertaProveedor ?, ?, ?, ?, ?, ?",42,5,9,null,false,REV);
    }
    @Test void configurarMinimoNoEnviaNiModificaExistenciaDesdeElCliente() throws Exception {
        mvc.perform(put("/api/bodegas/2/repuestos/9").with(actor("BODEGA")).with(csrf()).contentType("application/json")
                .content("{\"stockMinimo\":0,\"stockMinimoEsperado\":5,\"existencia\":9999,\"usuarioActorId\":999}")).andExpect(status().isOk());
        verify(jdbc).queryForList("EXEC dbo.spGuardarRepuestoBodega ?, ?, ?, ?, ?",42,2,9,new BigDecimal("0"),new BigDecimal("5"));verifyNoMoreInteractions(jdbc);
    }
    @ParameterizedTest @ValueSource(strings={"-0.01","1.234","10000000000","null"})
    void preciosInvalidosSeRechazanSinLlegarASql(String valor) throws Exception {
        for(String body:List.of(REP.replace("12.25",valor),REP.replace("25.50",valor)))
            mvc.perform(post("/api/repuestos").with(actor("BODEGA")).with(csrf()).contentType("application/json").content(body)).andExpect(status().isBadRequest());
        verifyNoInteractions(jdbc);
    }
    @Test void costoYPrecioCeroSonValidos() throws Exception {
        mvc.perform(post("/api/repuestos").with(actor("BODEGA")).with(csrf()).contentType("application/json").content(REP.replace("12.25","0").replace("25.50","0"))).andExpect(status().isCreated());
    }
    @ParameterizedTest @ValueSource(strings={"-1","1.5","2147483648","null"})
    void minimoFraccionarioOInvalidoNoSeTrunca(String valor) throws Exception {
        mvc.perform(put("/api/bodegas/2/repuestos/9").with(actor("BODEGA")).with(csrf()).contentType("application/json").content("{\"stockMinimo\":"+valor+"}")).andExpect(status().isBadRequest());verifyNoInteractions(jdbc);
    }
    @Test void categoriaFraccionariaNoSeCoaccionaAEntero() throws Exception {
        mvc.perform(post("/api/repuestos").with(actor("BODEGA")).with(csrf()).contentType("application/json").content(REP.replace("\"categoriaId\":3","\"categoriaId\":3.5"))).andExpect(status().isBadRequest());verifyNoInteractions(jdbc);
    }
    @Test void cadenasFueraDeLimiteOCodigosUnicodeNoSeTruncan() throws Exception {
        for(String body:List.of(REP.replace("REP-9","x".repeat(31)),REP.replace("Fuente ñ 漢字","x".repeat(101)),REP.replace("Descripción ñ","x".repeat(501)),REP.replace("REP-9","REP-漢字"),REP.replace("REP-9","REP 9")))
            mvc.perform(post("/api/repuestos").with(actor("BODEGA")).with(csrf()).contentType("application/json").content(body)).andExpect(status().isBadRequest());
        for(String body:List.of(PROV.replace("1234-5","x".repeat(21)),PROV.replace("Proveedor ñ","x".repeat(151)),PROV.replace("Dirección ñ","x".repeat(251)),PROV.replace("\"email\":\"  \"","\"email\":\"correo-invalido\"")))
            mvc.perform(post("/api/proveedores").with(actor("BODEGA")).with(csrf()).contentType("application/json").content(body)).andExpect(status().isBadRequest());
        verifyNoInteractions(jdbc);
    }
    @Test void editarSinRevisionYCrearConRevisionAnteriorSeRechazan() throws Exception {
        mvc.perform(put("/api/repuestos/9").with(actor("BODEGA")).with(csrf()).contentType("application/json").content(REP)).andExpect(status().isBadRequest());
        mvc.perform(post("/api/repuestos").with(actor("BODEGA")).with(csrf()).contentType("application/json").content(revisado(REP))).andExpect(status().isBadRequest());verifyNoInteractions(jdbc);
    }
    @Test void filtrosSeEnvianComoParametrosSinConstruirSql() throws Exception {
        mvc.perform(get("/api/repuestos").with(actor("BODEGA")).param("buscar","%_' OR 1=1").param("categoriaId","3").param("activo","false")).andExpect(status().isOk());
        verify(jdbc).queryForList("EXEC dbo.spListarRepuestosGestion ?, ?, ?, ?",42,"%_' OR 1=1",3,false);
    }
    @Test void consultasDeAsociacionesYPreciosSoloExponenSusDtos() throws Exception {
        when(jdbc.queryForList("EXEC dbo.spPreciosRepuestoGestion ?, ?",42,9)).thenReturn(List.of(Map.of("AuditoriaID",10000000000L,"Fecha",Timestamp.valueOf("2026-10-21 18:30:00"),"LoginSQL","PRIVADO","PrecioNuevo",new BigDecimal("25.50"))));
        when(jdbc.queryForList("EXEC dbo.spRepuestosBodegaGestion ?, ?",42,2)).thenReturn(List.of(Map.of("RepuestoID",9,"Existencia",10000000000L,"StockMinimo",0)));
        mvc.perform(get("/api/repuestos/9/precios").with(actor("BODEGA"))).andExpect(status().isOk()).andExpect(jsonPath("$[0].fecha").value("2026-10-21T18:30:00Z")).andExpect(content().string(not(containsString("PRIVADO"))));
        mvc.perform(get("/api/bodegas/2/repuestos").with(actor("BODEGA"))).andExpect(status().isOk()).andExpect(jsonPath("$[0].existencia").value(10000000000L));
        mvc.perform(get("/api/proveedores/5/repuestos").with(actor("BODEGA"))).andExpect(status().isOk()).andExpect(content().string(not(containsString("LOGIN_PRIVADO"))));
    }
    @ParameterizedTest @CsvSource({"52000,400","52001,400","52002,404","52003,409","52004,403","2627,409","547,409","1205,409","2812,503"})
    void erroresConservanContratoSinExponerDetallesInternos(int codigo,int esperado) throws Exception {
        when(jdbc.queryForList(anyString(),any(Object[].class))).thenThrow(new UncategorizedSQLException("abastecimiento","EXEC",new SQLException("INTERNO_SQL","S0001",codigo)));
        var r=mvc.perform(get("/api/repuestos").with(actor("BODEGA"))).andExpect(status().is(esperado));
        if(esperado==403||esperado==404||esperado==503||codigo==2627||codigo==547||codigo==1205)r.andExpect(content().string(not(containsString("INTERNO_SQL"))));
    }
    @Test void idsInvalidosYBusquedaLargaNoSeEnvianASql() throws Exception {
        mvc.perform(get("/api/repuestos/0").with(actor("BODEGA"))).andExpect(status().isBadRequest());
        mvc.perform(get("/api/repuestos").with(actor("BODEGA")).param("categoriaId","1.5")).andExpect(status().isBadRequest());
        mvc.perform(get("/api/proveedores").with(actor("BODEGA")).param("buscar","x".repeat(151))).andExpect(status().isBadRequest());verifyNoInteractions(jdbc);
    }
}
